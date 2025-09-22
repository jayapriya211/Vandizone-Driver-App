import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';
import 'package:vandizone_caption/utils/key.dart';
import '../../routes/routes.dart';
import '../../widgets/my_elevated_button.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../utils/icon_size.dart';
import '../../widgets/my_textfield.dart';
import '../../helper/ui_helper.dart';
import '../drawer/drawer_view.dart';
import 'package:gap/gap.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class TruckHomePage extends StatefulWidget {
  const TruckHomePage({super.key});

  @override
  State<TruckHomePage> createState() => _TruckHomePageState();
}

class _TruckHomePageState extends State<TruckHomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _mapController = Completer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const CameraPosition _initialPosition =
      CameraPosition(target: LatLng(10.7905, 78.7047), zoom: 13.5);
  final Set<Marker> _markers = {};
  List<LatLng> _latlng = [];

  Map<String, dynamic>? _currentBooking;
  Map<String, dynamic>? _vehicleData;
  int _completedJobs = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vehicleStatusSubscription;

  // StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statusSubscription;

  bool _isOnline = true;
  bool _findRequest = false;
  bool _isMuted = false;
  bool _tollEstimationStarted = false;

  Timer? _bookingCheckTimer;
  int? bargainAmount;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _showBookingArrivedPopup = false;
  bool _isBookingDialogShowing = false;
  late AudioPlayer _audioPlayer;
  bool _isSoundPlaying = false;
  bool _isBookingSoundEnabled = true;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAlarmAnimating = true;
  bool _isExpanded = false;
  double? tollCost;
  String? _lastShownBookingId;
  StreamSubscription<Position>? _positionStream;
  double? fuelCosts;
  String? _lastHandledBookingId;

  void _startLiveLocationTracking(String bookingId) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only trigger when moved 10 meters
      ),
    ).listen((Position position) async {
      debugPrint(
          '[TRACKING] New position: ${position.latitude}, ${position.longitude}');

      await FirebaseFirestore.instance
          .collection('truck_bookings')
          .doc(bookingId.toString())
          .update({
        'captainLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  void _stopLiveLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    debugPrint('[TRACKING] Live location tracking stopped');
  }

  Future<BitmapDescriptor> _getCustomMarkerFromAsset(String assetPath,
      {int width = 80}) async {
    ByteData data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final fi = await codec.getNextFrame();
    final byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<int> _getCompletedBookingCount(String captainUserCode) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('truck_bookings')
        .where('captainDetails.userCode', isEqualTo: captainUserCode)
        .where('status', isEqualTo: 5) // BookingStatus.completed
        .get();

    print(
        '[DEBUG] Found ${querySnapshot.docs.length} completed bookings for captain $captainUserCode');
    for (var doc in querySnapshot.docs) {
      print('[DEBUG] Booking ID: ${doc.id}');
      print('[DEBUG] Booking Data: ${doc.data()}');
    }

    return querySnapshot.docs.length;
  }

  Future<void> _handleBookingAcceptance(
      String bookingId, Map<String, dynamic> bookingData) async {
    final navigator = Navigator.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final captainDoc = await _firestore.collection('captains').doc(uid).get();
    final captainData = captainDoc.data();
    if (captainData == null) return;

    final trucksSnapshot = await _firestore.collection('trucks').get();
    final matchedTrucksDoc = trucksSnapshot.docs.firstWhereOrNull((doc) {
      final assignCaptains = doc['assignCaptains'] as List<dynamic>?;
      return assignCaptains?.any((c) =>
              c is Map<String, dynamic> &&
              c['id'] == captainData['userCode']) ??
          false;
    });
    if (matchedTrucksDoc == null) return;

    final trucksData = matchedTrucksDoc.data();
    final captainDetails = {
      ...captainData,
      'id': uid,
      'documentId': captainDoc.id
    };
    final vehicleDetails = {
      ...trucksData,
      'vehicleId': matchedTrucksDoc.id,
      'documentId': matchedTrucksDoc.id
    };
    final ownerCode = trucksData['ownerCode'];
    Map<String, dynamic>? ownerDetails;

    if (ownerCode != null) {
      final ownerSnapshot = await _firestore
          .collection('owners')
          .where('userCode', isEqualTo: ownerCode)
          .limit(1)
          .get();
      if (ownerSnapshot.docs.isNotEmpty) {
        ownerDetails = ownerSnapshot.docs.first.data();
        ownerDetails['documentId'] = ownerSnapshot.docs.first.id;
      }
    }

    final bookingRef = _firestore.collection('truck_bookings').doc(bookingId);
    await bookingRef.update({
      'captainDetails': captainDetails,
      'vehicleDetails': vehicleDetails,
      'ownerDetails': ownerDetails,
      'status': BookingStatus.accepted,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _startLiveLocationTracking(bookingId);

    final customerId = bookingData['customer']['uid'];
    final now = DateTime.now();
    final captainName = captainData['name'] ?? 'a captain';
    final batch = _firestore.batch();

    if (customerId != null) {
      final ref = _firestore.collection('customer_notifications').doc();
      batch.set(ref, {
        'userId': customerId,
        'type': 'booking_accepted',
        'bookingId': bookingId,
        'title': 'Booking Accepted',
        'message': 'Your booking has been accepted by Captain $captainName',
        'createdAt': now,
        'read': false,
        'relatedUserId': uid,
        'relatedUserType': 'captain',
      });
    }

    if (ownerDetails != null && ownerDetails['uid'] != null) {
      final ref = _firestore.collection('owner_notifications').doc();
      batch.set(ref, {
        'userId': ownerDetails['id'],
        'type': 'booking_accepted',
        'bookingId': bookingId,
        'title': 'Booking Accepted',
        'message':
            'Your vehicle booking has been accepted by Captain $captainName',
        'createdAt': now,
        'read': false,
        'relatedUserId': uid,
        'relatedUserType': 'captain',
        'vehicleId': matchedTrucksDoc.id,
      });
    }

    final captainNotificationRef =
        _firestore.collection('captain_notifications').doc();
    batch.set(captainNotificationRef, {
      'userId': uid,
      'type': 'booking_accepted',
      'bookingId': bookingId,
      'title': 'Booking Confirmed',
      'message': 'You have accepted a booking successfully.',
      'createdAt': now,
      'read': false,
    });

    await batch.commit();

    navigator.pushNamed(Routes.rideTrackingTruck, arguments: {
      'bookingId': bookingId,
      'bookingRef': bookingRef,
    });
  }

  Future<void> _loadAssignedVehicleMarkers() async {
    debugPrint('[MARKER] Loading assigned vehicle markers...');

    try {
      final truckSnapshot =
          await FirebaseFirestore.instance.collection('trucks').get();
      final truckTypeSnapshot =
          await FirebaseFirestore.instance.collection('truckTypes').get();

      debugPrint('[MARKER] Total trucks found: ${truckSnapshot.docs.length}');
      debugPrint(
          '[MARKER] Total truckTypes found: ${truckTypeSnapshot.docs.length}');

      // Build bodyType -> imageAsset map
      final Map<String, String> bodyTypeToImageMap = {
        for (var doc in truckTypeSnapshot.docs)
          (doc.data()['name'] as String).toLowerCase():
              doc.data()['imageAsset'] ?? ''
      };

      for (var doc in truckSnapshot.docs) {
        debugPrint('[MARKER] Truck Document ID: ${doc.id}');
        final data = doc.data();
        debugPrint('[MARKER] Raw data: $data');
        final BitmapDescriptor customIcon =
            await _getCustomMarkerFromAsset(AssetImages.bhl);

        final assignCaptains = data['assignCaptains'];
        final vehicleNumber = data['vehicleNumber'] ?? 'Unknown';
        final lat = data['lat'];
        final lng = data['lng'];
        final bodyType = (data['bodyType'] ?? '').toString().toLowerCase();

        if (assignCaptains is List && lat != null && lng != null) {
          for (var captain in assignCaptains) {
            if (captain is Map<String, dynamic>) {
              final id = captain['id'];
              final name = captain['name'];

              debugPrint('[MARKER] Assigned Captain - ID: $id, Name: $name');
              debugPrint('[MARKER] Body Type: $bodyType');

              String? iconUrl = bodyTypeToImageMap[bodyType];
              Uint8List markerIcon;

              if (iconUrl != null && iconUrl.isNotEmpty) {
                debugPrint('[MARKER] Found image URL for bodyType: $iconUrl');
                markerIcon = await _getNetworkImageAsBytes(iconUrl, 60);
              } else {
                debugPrint(
                    '[MARKER] No image URL found for bodyType "$bodyType", using fallback icon.');
                markerIcon = customIcon as Uint8List;
              }

              _markers.add(
                Marker(
                  markerId: MarkerId("truck_${doc.id}"),
                  position: LatLng(lat.toDouble(), lng.toDouble()),
                  icon: BitmapDescriptor.fromBytes(markerIcon),
                  infoWindow: InfoWindow(
                    title: 'Captain: $name',
                    snippet: 'Vehicle: $vehicleNumber',
                  ),
                ),
              );

              final GoogleMapController controller =
                  await _mapController.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(lat.toDouble(), lng.toDouble()),
                    zoom: 15.0,
                  ),
                ),
              );

              debugPrint(
                  '[MARKER] Marker added and camera animated to ($lat, $lng)');
              break; // only add one captain’s vehicle for now
            } else {
              debugPrint(
                  '[MARKER] Captain entry not a Map<String, dynamic>: $captain');
            }
          }
          break;
        } else {
          debugPrint(
              '[MARKER] No assignCaptains or lat/lng missing in doc ${doc.id}');
        }
      }

      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('[ERROR] Failed to load assigned vehicle markers: $e');
      debugPrint('[ERROR] Stacktrace: $stack');
    }
  }

  Future<Uint8List> _getNetworkImageAsBytes(String url, int width) async {
    final response = await http.get(Uri.parse(url));
    final codec = await ui.instantiateImageCodec(
      response.bodyBytes,
      targetHeight: width,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
    _loadVehicleData();
    // _startBookingCheckTimer();
    _audioPlayer = AudioPlayer(); // already declared
    _setupAudioPlayer();
    _fetchCompletedJobs();
    // _startBookingAssignmentListener();
    _startTruckBookingListener();
    _loadAssignedVehicleMarkers();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> _fetchCompletedJobs() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userCode = await _getUserCode(user.uid);
    if (userCode == null) return;

    final count = await _getCompletedBookingCount(userCode);
    setState(() {
      _completedJobs = count;
    });
  }

  Future<void> sendTollEstimationsForAssignedTrucks() async {
    final truckSnapshot =
        await FirebaseFirestore.instance.collection('trucks').get();

    for (var doc in truckSnapshot.docs) {
      final truckData = doc.data();
      final bookingId = truckData['currentBooking'];

      if (bookingId == null) continue;

      final bookingDoc = await FirebaseFirestore.instance
          .collection('truck_bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) continue;

      final bookingData = bookingDoc.data();
      if (bookingData == null) continue;

      final fromLocation = bookingData['fromLocation'];
      final toLocation = bookingData['toLocation'];

      if (fromLocation == null || toLocation == null) continue;

      final payload = truckData['payload'] ?? 10000; // default if missing
      final axles =
          int.tryParse(truckData['numberOfAxles']?.toString() ?? '2') ?? 2;
      final bodyType = truckData['bodyType'] ?? 'Truck';

      final payloadToSend = {
        "from": {
          "lat": fromLocation['latitude'],
          "lng": fromLocation['longitude'],
        },
        "to": {
          "lat": toLocation['latitude'],
          "lng": toLocation['longitude'],
        },
        "vehicle": {
          "type": bodyType,
          "axles": axles,
          "weight": payload,
          "fuel": {
            "type": "diesel",
            "averageConsumption": 3.5,
          }
        },
        "roundTrip": true,
        "serviceProvider": "tollguru",
        "getPathPolygon": true,
        "getVehicleStops": true,
      };

      final uri = Uri.parse(
          "https://apis.tollguru.com/toll/v2/origin-destination-waypoints");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "x-api-key": tollGuruApiKey, // Set your API key securely
        },
        body: jsonEncode(payloadToSend),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final toll = result['routes']?[0]?['costs']?['tag'];
        final fuel = result['routes']?[0]?['costs']?['fuel'];
        debugPrint(
            "[TOLL] Truck ${truckData['vehicleNumber']} — Toll: ₹$toll | Fuel: ₹$fuel");
      } else {
        debugPrint(
            "[TOLL] Failed for truck ${truckData['vehicleNumber']}: ${response.body}");
      }
    }
  }

  Future<void> _setupAudioPlayer() async {
    try {
      debugPrint('[AUDIO] Setting audio source...');
      await _audioPlayer.setSource(AssetSource('sound/notification.mp3'));
      await _audioPlayer.setVolume(1.0); // full volume
      debugPrint('[AUDIO] Audio player initialized');
    } catch (e) {
      debugPrint('[AUDIO ERROR] Failed to initialize audio player: $e');
    }
  }

  StreamSubscription<QuerySnapshot>? _statusSubscription;

  void _startTruckBookingListener() async {
    debugPrint('[TRUCKS LISTENER] Activated');

    debugPrint('[DEBUG] Should show sheet? popup: $_showBookingArrivedPopup, last: $_lastShownBookingId');

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[TRUCKS LISTENER] No user logged in');
      return;
    }

    final userCode = await _getUserCode(user.uid);
    if (userCode == null) {
      debugPrint('[TRUCKS LISTENER] No userCode found for user: ${user.uid}');
      return;
    }

    _statusSubscription?.cancel();

    _statusSubscription = _firestore.collection('trucks').snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) async {
        debugPrint(
            '[TRUCKS LISTENER] Snapshot received: ${snapshot.docs.length} documents');

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final truckId = doc.id;

          final assignCaptains = data['assignCaptains'] as List<dynamic>?;
          final bookingId = data['currentBooking'];
          final status = data['status'];

          if (assignCaptains == null || bookingId == null) {
            debugPrint(
                '[TRUCKS LISTENER] Skipped truck [$truckId] — missing assignCaptains or bookingId');
            continue;
          }

          if (status == BookingStatus.assigned &&
              (!_showBookingArrivedPopup || _lastShownBookingId != bookingId)) {
            debugPrint('[TRIGGER] Should show booking: $bookingId');
          }

          final isAssignedToMe = assignCaptains.any(
            (captain) => captain is Map && captain['id'] == userCode,
          );

          if (!isAssignedToMe) {
            debugPrint(
                '[TRUCKS LISTENER] Skipped truck [$truckId] — not assigned to me ($userCode)');
            continue;
          }

          debugPrint(
              '[TRUCKS LISTENER] 🚚 Booking assigned to me: $bookingId (truck: $truckId, status: $status)');

          if (status == BookingStatus.assigned &&
              (!_showBookingArrivedPopup || _lastShownBookingId != bookingId)) {
            _lastShownBookingId = bookingId;
            if (mounted) {
              setState(() {
                _showBookingArrivedPopup = true;
                _currentBooking = {'id': bookingId};
                _findRequest = true;
              });

              WidgetsBinding.instance.addPostFrameCallback((_) {
                debugPrint('[DEBUG] >>> Showing bottom sheet for bookingId: $bookingId');
                // await Future.delayed(Duration(milliseconds: 100));
                _showBookingArrivedDialog(context, bookingId); // 🛑 likely failing here
                _audioPlayer.resume();
                _startTimer();
                _startSingleBookingListener(bookingId);
              });
            }
          }
        }
      },
      onError: (e) {
        debugPrint('[TRUCKS LISTENER ERROR] $e');
      },
    );
  }

  StreamSubscription<DocumentSnapshot>? _bookingStatusSubscription;

  void _startSingleBookingListener(String bookingId) {
    debugPrint('[BOOKING LISTENER] Listening to booking: $bookingId');

    _bookingStatusSubscription?.cancel();

    _bookingStatusSubscription = FirebaseFirestore.instance
        .collection('truck_bookings')
        .doc(bookingId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) async {
      if (!snapshot.exists) {
        debugPrint(
            '[BOOKING LISTENER] Booking document does not exist: $bookingId');
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'];

      debugPrint(
          '[BOOKING LISTENER] Booking [$bookingId] updated. Status: $status');

      if (status == BookingStatus.accepted &&
          _lastHandledBookingId != bookingId) {
        _lastHandledBookingId = bookingId;

        await _handleBookingAcceptance(bookingId, data);

        debugPrint('[BOOKING LISTENER] ✅ Bargain accepted');

        _timer?.cancel();
        _audioPlayer.stop();

        _startLiveLocationTracking(bookingId);

        if (mounted) {
          setState(() {
            _showBookingArrivedPopup = false;
            _isBookingDialogShowing = false;
            _findRequest = false;
            _currentBooking = {'id': bookingId};
            _lastShownBookingId = null;
          });

          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Bargain accepted. Starting trip...')),
          // );
          UiHelper.showTopSnackBar(_scaffoldKey.currentContext!, 'Bargain accepted. Starting trip...');
        }
      } else if ([
        BookingStatus.completed,
        BookingStatus.rejected,
        BookingStatus.timeout,
        BookingStatus.cancelled,
      ].contains(status)) {
        debugPrint('[BOOKING LISTENER] Booking ended or cancelled');
        _audioPlayer.pause();

        if (mounted) {
          setState(() {
            _showBookingArrivedPopup = false;
            _currentBooking = null;
            _findRequest = false;
            _isBookingDialogShowing = false;
            _lastShownBookingId = null;
          });
        }

        if (mounted) {
          setState(() {
            _showBookingArrivedPopup = false;
            _currentBooking = null;
            _findRequest = false;
            _lastShownBookingId = null;
          });
        }

        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        }

        _restartTruckBookingListenerIfNeeded();
      } else {
        debugPrint('[BOOKING LISTENER] Ignored status: $status');
      }
    }, onError: (e) {
      debugPrint('[BOOKING LISTENER ERROR] $e');
    });
  }

  Future<void> _loadVehicleData() async {
    debugPrint('[VEHICLE] Loading vehicle data');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[AUTH] No authenticated user');
        setState(() => _vehicleData = null);
        return;
      }

      if (!_isOnline) {
        debugPrint('[STATUS] Captain is offline - skipping load');
        setState(() => _vehicleData = null);
        return;
      }

      final userCode = await _getUserCode(user.uid);
      if (userCode == null) {
        debugPrint('[AUTH] User code not found');
        setState(() => _vehicleData = null);
        return;
      }

      debugPrint(
          '[VEHICLE] Searching for vehicle assigned to userCode: $userCode');

      Future<Map<String, dynamic>?> _findMatchingVehicle(
          QuerySnapshot query) async {
        debugPrint(
            '[VEHICLE] Searching in collection: ${query.size} documents');

        for (final doc in query.docs) {
          final assignCaptains = doc['assignCaptains'] as List<dynamic>?;

          if (assignCaptains != null) {
            final match = assignCaptains.any((captain) =>
                captain is Map<String, dynamic> && captain['id'] == userCode);

            if (match) {
              debugPrint('[VEHICLE] Found matching vehicle: ${doc.id}');
              return {
                'vehicleType': doc['vehicleType'],
                'vehicleNumber': doc['vehicleNumber'],
                'vehicleCategory': doc['vehicleCategory'],
                'vehiclePhotoUrl': doc['vehiclePhotoUrl'],
                'docId': doc.id,
              };
            }
          }
        }
        return null;
      }

      debugPrint('[VEHICLE] Checking Truck collection');
      final trucksQuery = await _firestore.collection('trucks').get();
      final trucksMatch = await _findMatchingVehicle(trucksQuery);
      if (trucksMatch != null) {
        debugPrint('[VEHICLE] Truck vehicle found');
        setState(() => _vehicleData = trucksMatch);
        return;
      }

      debugPrint('[VEHICLE] No assigned vehicle found');
      setState(() => _vehicleData = null);
    } catch (e) {
      debugPrint('[ERROR] Error loading vehicle data: $e');
      setState(() => _vehicleData = null);
    }
  }

  Future<void> _fetchBookingAndEstimateToll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[TOLL] No user logged in');
      return;
    }

    final userCode = await _getUserCode(user.uid);
    if (userCode == null) {
      debugPrint('[TOLL] No user code found');
      return;
    }

    final querySnapshot =
        await FirebaseFirestore.instance.collection('trucks').get();

    final matchedDoc = querySnapshot.docs.firstWhereOrNull((doc) {
      final assignCaptains = doc['assignCaptains'] as List<dynamic>?;
      if (assignCaptains == null) return false;
      return assignCaptains.any((captain) =>
          captain is Map<String, dynamic> && captain['id'] == userCode);
    });

    if (matchedDoc != null) {
      final bhlData = matchedDoc.data();
      final bookingId = bhlData['currentBooking'];
      if (bookingId != null) {
        debugPrint('[TOLL] Found bookingId: $bookingId');
        await _sendTollGuruRouteEstimation(bookingId);
      } else {
        debugPrint('[TOLL] No currentBooking found in BHL');
      }
    } else {
      debugPrint('[TOLL] No matching BHL document found');
    }
  }

  Future<void> _sendTollGuruRouteEstimation(String bookingId) async {
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('truck_bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        debugPrint('[TOLL GURU] Booking not found');
        return;
      }

      final bookingData = bookingDoc.data()!;
      final fromLocation = bookingData['fromLocation'];
      final toLocation = bookingData['toLocation'];
      final bodyType = bookingData['bodyType'];
      final numberOfAxles = bookingData['numberOfAxles'];
      final payloadweight = bookingData['payload'];

      final payload = {
        "from": {
          "lat": fromLocation['latitude'],
          "lng": fromLocation['longitude'],
        },
        "to": {
          "lat": toLocation['latitude'],
          "lng": toLocation['longitude'],
        },
        "vehicle": {
          "type": bodyType,
          "axles": numberOfAxles,
          "weight": payloadweight,
          "fuel": {
            "type": "diesel",
            "averageConsumption": 3.5,
          }
        },
        "roundTrip": true,
        "serviceProvider": "tollguru",
        "getPathPolygon": true,
        "getVehicleStops": true,
      };

      final uri = Uri.parse(
          "https://apis.tollguru.com/toll/v2/origin-destination-waypoints");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "x-api-key": tollGuruApiKey
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        final prettyResponse = encoder.convert(result);
        debugPrint('[TOLL GURU] Full Response:\n$prettyResponse');
        fuelCosts = result['routes']?[0]?['costs']?['fuel']?.toDouble() ?? 0.0;
        final tollCosts = result['routes']?[0]?['costs']?['tag']?.toDouble() ?? 0.0;

        final upAndDownCost =
            (fuelCosts! + tollCosts) * 2;
        tollCost = tollCosts;
        debugPrint(
            '[TOLL GURU] Fuel Cost (One Way): \$${fuelCosts?.toStringAsFixed(2)}');
        debugPrint(
            '[TOLL GURU] Toll Cost (One Way): \$${tollCosts.toStringAsFixed(2)}');
        debugPrint(
            '[TOLL GURU] Total Round Trip Cost: \$${upAndDownCost.toStringAsFixed(2)}');
        setState(() {
          tollCost = tollCosts;
          fuelCosts = fuelCosts;
        });
      } else {
        debugPrint(
            '[TOLL GURU] Failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[TOLL GURU] Error sending route estimation request: $e');
    }
  }

  Future<String?> _getUserCode(String uid) async {
    debugPrint('[FIRESTORE] Fetching userCode for uid: $uid');

    try {
      final doc = await _firestore.collection('captains').doc(uid).get();
      if (!doc.exists) {
        debugPrint('[FIRESTORE] No document found for user: $uid');
        return null;
      }

      final userCode = doc['userCode'] as String?;
      debugPrint('[FIRESTORE] Retrieved userCode: $userCode');
      return userCode;
    } catch (e) {
      debugPrint("[ERROR] Failed to get userCode: $e");
      return null;
    }
  }

  Future<bool> _checkLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      return true;
    } else {
      return false;
    }
  }

  void _updateOnlineStatus(bool isOnline) async {
    debugPrint('[STATUS] Updating online status to: $isOnline');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[AUTH] No authenticated user');
        return;
      }

      debugPrint('[FIRESTORE] Updating status for user: ${user.uid}');

      await _firestore.collection('captains').doc(user.uid).update({
        'is_active': isOnline,
        'updated_at': FieldValue.serverTimestamp(),
      });

      debugPrint('[FIRESTORE] Status updated successfully');

      bool granted = await _checkLocationPermission();
      if(granted) {
        // ✅ If going online, update BHL location
        if (isOnline) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await _updateTruckLocation(position);
        }
      }

    } catch (e) {
      debugPrint('[ERROR] Failed to update online status: $e');

      if (e is FirebaseException) {
        debugPrint(
            '[FIREBASE] Error details - code: ${e.code}, message: ${e.message}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: ${e.toString()}')),
      );

      setState(() {
        _isOnline = !isOnline;
      });

      debugPrint('[UI] Reverted online status due to error');
    }
  }
  Future<void> _updateTruckLocation(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userCode = await _getUserCode(user.uid);
      if (userCode == null) return;

      // 🔎 Look only in trucks collection
      final querySnapshot = await _firestore.collection('trucks').get();

      final matchedDoc = querySnapshot.docs.firstWhereOrNull((doc) {
        final data = doc.data();
        if (!data.containsKey('assignCaptains')) return false;

        final assignCaptains =
        List<Map<String, dynamic>>.from(data['assignCaptains']);
        debugPrint('[CHECK] Truck ${doc.id} captains: $assignCaptains');

        return assignCaptains.any((c) {
          debugPrint('[CHECK] Comparing captain id=${c['id']} with userCode=$userCode');
          return c['id'].toString().trim() == userCode.toString().trim();
        });
      });

      if (matchedDoc != null) {
        await _firestore.collection('trucks').doc(matchedDoc.id).update({
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint('[LOCATION] Truck location updated: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('[WARNING] No truck found for captain $userCode');
      }
    } catch (e) {
      debugPrint('[ERROR] Failed to update Truck location: $e');
    }
  }

  Future<void> _updateBhlLocation(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userCode = await _getUserCode(user.uid);
      if (userCode == null) return;

      final querySnapshot = await _firestore.collection('bhl').get();

      final matchedDoc = querySnapshot.docs.firstWhereOrNull((doc) {
        final data = doc.data();
        if (!data.containsKey('assignCaptains')) return false;

        final assignCaptains = List<Map<String, dynamic>>.from(data['assignCaptains']);
        debugPrint('[CHECK] Truck ${doc.id} captains: $assignCaptains');

        return assignCaptains.any((c) {
          debugPrint('[CHECK] Comparing captain id=${c['id']} with userCode=$userCode');
          return c['id'].toString().trim() == userCode.toString().trim();
        });
      });

      if (matchedDoc != null) {
        await _firestore.collection('trucks').doc(matchedDoc.id).update({
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint('[LOCATION] Trucks location updated: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('[ERROR] Failed to update BHL location: $e');
    }
  }
  // Future<void> _updateBhlLocation(Position position) async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) return;
  //
  //     final userCode = await _getUserCode(user.uid);
  //     if (userCode == null) return;
  //
  //     final querySnapshot = await _firestore.collection('trucks').get();
  //
  //     final matchedDoc = querySnapshot.docs.firstWhereOrNull((doc) {
  //       final data = doc.data();
  //       if (!data.containsKey('assignCaptains')) return false;
  //
  //       final assignCaptains = List<Map<String, dynamic>>.from(data['assignCaptains']);
  //       debugPrint('[CHECK] Truck ${doc.id} captains: $assignCaptains');
  //
  //       return assignCaptains.any((c) {
  //         debugPrint('[CHECK] Comparing captain id=${c['id']} with userCode=$userCode');
  //         return c['id'].toString().trim() == userCode.toString().trim();
  //       });
  //     });
  //
  //     if (matchedDoc != null) {
  //       await matchedDoc.reference.update({
  //         'lat': position.latitude,
  //         'lng': position.longitude,
  //         'updated_at': FieldValue.serverTimestamp(),
  //       });
  //
  //       debugPrint('[LOCATION] ✅ Truck ${matchedDoc.id} location updated: ${position.latitude}, ${position.longitude}');
  //     } else {
  //       debugPrint('[LOCATION] ❌ No truck found for userCode=$userCode');
  //     }
  //   } catch (e) {
  //     debugPrint('[ERROR] Failed to update truck location: $e');
  //   }
  // }


  void _restartTruckBookingListenerIfNeeded() {
    debugPrint('[LISTENER] Restarting truck booking listener if needed...');

    _statusSubscription?.cancel();
    _bookingStatusSubscription?.cancel();
    _startTruckBookingListener();
  }


  static Future<void> _showStatusChangeDialog(
    BuildContext context,
    bool newStatus,
    VoidCallback onConfirm,
  ) async {
    debugPrint('[DIALOG] Showing status change dialog');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: white,
        contentPadding: EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(newStatus ? "Go Online" : "Go Offline",
                style: blackSemiBold20),
            Text(
              "Are you sure you want to go ${newStatus ? 'online' : 'offline'}?",
              style: colorABMedium18,
              textAlign: TextAlign.center,
            ),
            Gap(25),
            Row(
              children: [
                Expanded(
                    child: MyElevatedButton(
                  title: 'Cancel',
                  isSecondary: true,
                  onPressed: () {
                    debugPrint('[DIALOG] User cancelled status change');
                    Navigator.pop(context);
                  },
                )),
                Gap(20),
                Expanded(
                    child: MyElevatedButton(
                  title: newStatus ? 'Go Online' : 'Go Offline',
                  onPressed: () {
                    debugPrint('[DIALOG] User confirmed status change');
                    Navigator.pop(context); // Close dialog
                    onConfirm(); // Execute the callback
                  },
                )),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showBookingArrivedDialog(BuildContext context, String bookingId) {
    debugPrint(
        '[BOTTOM SHEET] Showing booking arrived bottom sheet for booking: $bookingId');

    if (_isBookingDialogShowing) {
      debugPrint('[BOTTOM SHEET] Already showing, skipping...');
      return;
    }

    _statusSubscription?.cancel();
    setState(() {
      _isBookingDialogShowing = true;
    });

    // if (Navigator.canPop(context)) {
    //   debugPrint('[DEBUG] Closing previous sheet before opening new one...');
    //   Navigator.pop(context);
    // }

    if (_isBookingDialogShowing && Navigator.of(context, rootNavigator: true).canPop()) {
      debugPrint('[BOTTOM SHEET] Closing previous sheet...');
      Navigator.of(context, rootNavigator: true).pop();
    }


    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('truck_bookings').doc(bookingId).get(),
            builder: (context, bookingSnapshot) {
              if (!_tollEstimationStarted) {
                _tollEstimationStarted = true;
                _sendTollGuruRouteEstimation(bookingId).then((_) {
                  if (mounted) setState(() {});
                });
              }

              debugPrint('[DEBUG] 🧾 Got snapshot for $bookingId: hasData=${bookingSnapshot.hasData}, exists=${bookingSnapshot.data?.exists}');
              if (!bookingSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              if (!bookingSnapshot.data!.exists) {
                return Container(
                  padding: EdgeInsets.all(20),
                  child: Text('Booking not found', style: blackMedium18),
                );
              }

              final bookingData =
                  bookingSnapshot.data!.data() as Map<String, dynamic>;

              // _sendTollGuruRouteEstimation(bookingId);

              final fromLocation =
                  bookingData['fromLocation'] as Map<String, dynamic>;
              final toLocation =
                  bookingData['toLocation'] as Map<String, dynamic>;
              final customer = bookingData['customer'] as Map<String, dynamic>;
              final pricing =
                  bookingData['pricing'] as Map<String, dynamic>? ?? {};
              final taxes = bookingData['taxes'] as List<dynamic>? ?? [];
              final loadWeight = bookingData['loadWeight'] ?? 0.0;
              final material = bookingData['material'] ?? 'N/A';
              final extras = bookingData['extras'] ?? 'N/A';
              final bargainAmount = bookingData['bargainAmount'] as double?;

              // Calculate totals
              final baseFare = (pricing['rate'] ?? 0.0).toDouble();
              final loadingCharges = (pricing['loading'] ?? 0.0).toDouble();
              final unloadingCharges = (pricing['unloading'] ?? 0.0).toDouble();
              final taxAmount = taxes
                  .fold(0.0, (sum, tax) => sum + (tax['amount'] ?? 0.0))
                  .toDouble();
              final totalFare = (pricing['totalFare'] ?? 0.0).toDouble();

              return StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20)
                        .copyWith(top: 25, bottom: 30),
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.vertical(top: myRadius(20)),
                      boxShadow: [boxShadow1],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Trip Request', style: blackMedium18),
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isAlarmAnimating
                                      ? _animation.value
                                      : 1.0,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isAlarmAnimating
                                          ? primary.withOpacity(0.2)
                                          : Colors.transparent,
                                    ),
                                    child: Text(
                                      '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              child: IconButton(
                                icon: Icon(_isMuted
                                    ? Icons.volume_off
                                    : Icons.volume_up),
                                onPressed: _toggleMute,
                                color: _isMuted ? Colors.grey : primary,
                              ),
                            ),
                          ],
                        ),
                        Gap(20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Trip Route', style: blackMedium18),
                          ],
                        ),
                        Gap(20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(AssetImages.fromaddress,
                                    height: IconSize.regular),
                                Gap(5),
                                Expanded(
                                  child: Text(
                                    fromLocation['address'] ?? 'N/A',
                                    style: blackRegular16,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 10, top: 5),
                              child: Column(
                                children: List.generate(
                                  3,
                                  (index) => Text(
                                    "\u2022",
                                    style: blackRegular16.copyWith(height: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Image.asset(AssetImages.toaddress,
                                    height: IconSize.regular),
                                Gap(5),
                                Expanded(
                                  child: Text(
                                    toLocation['address'] ?? 'N/A',
                                    style: blackRegular16,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Gap(25),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () {
                              final rootContext = context;
                              debugPrint('[BUTTON] Bargain pressed');
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  TextEditingController _amountController =
                                      TextEditingController();

                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    title: Text('Enter Bargain Amount'),
                                    content: TextField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                          hintText: 'Enter amount'),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          String enteredAmount =
                                              _amountController.text.trim();
                                          double? enteredValue =
                                              double.tryParse(enteredAmount);

                                          if (enteredValue == null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Please enter a valid amount.')),
                                            );
                                            return;
                                          }

                                          if (enteredValue < totalFare) {
                                            UiHelper.showTopSnackBar(_scaffoldKey.currentContext!, 'Bargain amount cannot be less then total fare ₹${totalFare.toStringAsFixed(2)}.');
                                            return;
                                          }

                                          await FirebaseFirestore.instance
                                              .collection('truck_bookings')
                                              .doc(bookingId)
                                              .update({
                                            'bargainAmount': enteredValue,
                                            'bargain_status': 1,
                                          });

                                          if (_timer != null &&
                                              _timer!.isActive) {
                                            _timer!.cancel();
                                          }
                                          _startTimer();

                                          Navigator.of(context).pop();
                                          UiHelper.showTopSnackBar(_scaffoldKey.currentContext!, 'Bargain offer sent!');
                                          // ScaffoldMessenger.of(context)
                                          //     .showSnackBar(
                                          //   SnackBar(
                                          //       content: Text(
                                          //           'Bargain offer sent!')),
                                          // );
                                        },
                                        child: Text('Send'),
                                      )
                                    ],
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text('Bargain',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Load', style: blackMedium18),
                            Text(
                              '${loadWeight.toStringAsFixed(2)} Tons',
                              style: primarySemiBold16,
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Divider(),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Fare Breakdown',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Icon(_isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        AnimatedCrossFade(
                          firstChild: Container(),
                          secondChild: Column(
                            children: [
                              // Base Fare
                              _buildFareRow('Base Fare:',
                                  '₹${baseFare.toStringAsFixed(2)}'),

                              // Loading Charges (if applicable) - Updated with sign
                              if (loadingCharges > 0)
                                _buildFareRow(
                                    'Loading Charges (${pricing['loadHelp'] ?? 'N/A'}):',
                                    '${pricing['loadingSign'] ?? '+'}₹${loadingCharges.toStringAsFixed(2)}',valueColor: Colors.red,),

                              // Unloading Charges (if applicable) - Updated with sign
                              if (unloadingCharges > 0)
                                _buildFareRow(
                                    'Unloading Charges (${pricing['loadHelp'] ?? 'N/A'}):',
                                    '${pricing['unloadingSign'] ?? '+'}₹${unloadingCharges.toStringAsFixed(2)}',valueColor: Colors.red,),

                              // Load Material
                              _buildFareRow(
                                  'Load Material:', material.toString()),

                              // Extra Requirements
                              _buildFareRow(
                                  'Extra Requirements:', extras.toString()),

                              // Taxes
                              if (fuelCosts != null)
                                _buildFareRow('Fuel Cost:',
                                    '₹${fuelCosts!.toStringAsFixed(2)}', valueColor: Colors.red,),
                              if (tollCost != null)
                                _buildFareRow('Toll Cost:',
                                    '₹${tollCost!.toStringAsFixed(2)}', valueColor: Colors.red,),

                              ...taxes.map((tax) => _buildFareRow(
                                  '${tax['name']} (${tax['value']}%):',
                                  '₹${(tax['amount'] ?? 0.0).toStringAsFixed(2)}')),

                              Divider(thickness: 1),

                              // Total Fare (existing)
                              _buildFareRow('Total Fare:',
                                  '₹${totalFare.toStringAsFixed(2)}',
                                  isBold: true),

                              // New: Calculation breakdown
                              if (_isExpanded) ...[
                                Divider(thickness: 1),
                                // Subtotal before taxes
                                // _buildFareRow('Subtotal before taxes:',
                                //     '₹${(baseFare + (pricing['loadingSign'] == '-' ? -loadingCharges : loadingCharges) + (pricing['unloadingSign'] == '-' ? -unloadingCharges : unloadingCharges)).toStringAsFixed(2)}'),

                                // Total taxes
                                _buildFareRow('Total Taxes:',
                                    '₹${taxAmount.toStringAsFixed(2)}'),

                                // Bargain adjustment if exists
                                if (bargainAmount != null)
                                  _buildFareRow('Bargain Adjustment:',
                                      '₹${(bargainAmount - totalFare).toStringAsFixed(2)}',
                                      isBold: true),

                                // Final Gross Profit
                                _buildFareRow(
                                  'Gross Profit:',
                                  '₹${(
                                      (bargainAmount ?? totalFare)
                                          - loadingCharges
                                          - unloadingCharges
                                          - (fuelCosts ?? 0)
                                          - (tollCost ?? 0)
                                          - taxAmount
                                  ).toStringAsFixed(2)}',
                                  isBold: true,
                                  isProfit: true,
                                ),
                              ],
                            ],
                          ),
                          crossFadeState: _isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: Duration(milliseconds: 300),
                        ),
                        if (bargainAmount != null)
                          Card(
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Bargain Amount:', style: blackMedium18),
                                  Text('₹${bargainAmount.toStringAsFixed(2)}',
                                      style: primarySemiBold16),
                                ],
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: MyElevatedButton(
                                title: 'Decline',
                                isSecondary: true,
                                onPressed: () async {
                                  final shouldDecline = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: myBorderRadius(10)),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("Decline Ride",
                                              style: blackSemiBold20),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15),
                                            child: Image.asset(
                                                AssetImages.cancelride,
                                                height: 85),
                                          ),
                                          Text(
                                            "Are you sure you want to\ndecline the ride",
                                            textAlign: TextAlign.center,
                                            style: colorABMedium18,
                                          ),
                                          Gap(25),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: MyElevatedButton(
                                                  isSecondary: true,
                                                  title: "Cancel",
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                ),
                                              ),
                                              Gap(20),
                                              Expanded(
                                                child: MyElevatedButton(
                                                  title: "Sure",
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  );

                                  if (shouldDecline == true) {
                                    try {
                                      _audioPlayer.pause();
                                      Navigator.pop(context);

                                      await FirebaseFirestore.instance
                                          .collection('truck_bookings')
                                          .doc(bookingId)
                                          .update({
                                        'status': 3,
                                        'updated_at':
                                            FieldValue.serverTimestamp(),
                                      });

                                      print(
                                          '📌 Booking marked as declined (status = 3) in truck_bookings for ID: $bookingId');

                                      final querySnapshot =
                                          await FirebaseFirestore.instance
                                              .collection('trucks')
                                              .where('currentBooking',
                                                  isEqualTo: bookingId)
                                              .limit(1)
                                              .get();

                                      if (querySnapshot.docs.isNotEmpty) {
                                        final trucksDoc =
                                            querySnapshot.docs.first;

                                        await FirebaseFirestore.instance
                                            .collection('trucks')
                                            .doc(trucksDoc.id)
                                            .update({
                                          'status': 0,
                                          'updated_at':
                                              FieldValue.serverTimestamp(),
                                          'currentBooking': FieldValue.delete(),
                                        });

                                        print(
                                            '✅ trucks doc [${trucksDoc.id}] updated: status = 0, currentBooking removed');
                                      } else {
                                        print(
                                            '⚠️ No trucks document found with currentBooking = $bookingId');
                                      }

                                      // ScaffoldMessenger.of(context)
                                      //     .showSnackBar(
                                      //   SnackBar(
                                      //       content: Text(
                                      //           'Ride declined and vehicle released.')),
                                      // );
                                    } catch (e) {
                                      print(
                                          '❌ Error updating booking status: $e');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to decline ride: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            Gap(20),
                            // Expanded(
                            //   child: MyElevatedButton(
                            //     title: 'Accept',
                            //     onPressed: () async {
                            //       debugPrint(
                            //           '[BOTTOM SHEET] User chose "Accept"');
                            //       final navigator = Navigator.of(context);
                            //       Navigator.pop(context);
                            //       _audioPlayer.release();
                            //
                            //       final uid =
                            //           FirebaseAuth.instance.currentUser?.uid;
                            //       if (uid == null) {
                            //         debugPrint(
                            //             '[ERROR] Current user UID is null.');
                            //         return;
                            //       }
                            //
                            //       try {
                            //         final captainDoc = await _firestore
                            //             .collection('captains')
                            //             .doc(uid)
                            //             .get();
                            //         final captainData = captainDoc.data();
                            //
                            //         if (captainData == null) {
                            //           debugPrint(
                            //               '[ERROR] Captain document not found for UID: $uid');
                            //           return;
                            //         }
                            //
                            //         debugPrint(
                            //             '[DEBUG] Captain userCode: ${captainData['userCode']}');
                            //
                            //         final trucksSnapshot = await _firestore
                            //             .collection('trucks')
                            //             .get();
                            //         final matchedTrucksDoc = trucksSnapshot.docs
                            //             .firstWhereOrNull((doc) {
                            //           final assignCaptains =
                            //               doc['assignCaptains']
                            //                   as List<dynamic>?;
                            //           if (assignCaptains == null) return false;
                            //
                            //           return assignCaptains.any((c) =>
                            //               c is Map<String, dynamic> &&
                            //               c['id'] ==
                            //                   (captainData['userCode'] ?? ''));
                            //         });
                            //
                            //         if (matchedTrucksDoc == null) {
                            //           debugPrint(
                            //               '[ERROR] No trucks assigned to captain with userCode: ${captainData['userCode']}');
                            //           return;
                            //         }
                            //
                            //         final trucksData = matchedTrucksDoc.data();
                            //         debugPrint(
                            //             '[DEBUG] Found trucks doc ID: ${matchedTrucksDoc.id}');
                            //         debugPrint(
                            //             '[DEBUG] trucks data: $trucksData');
                            //
                            //         final captainDetails = {
                            //           ...captainData,
                            //           'id': uid,
                            //           'documentId': captainDoc.id,
                            //         };
                            //
                            //         final vehicleDetails = {
                            //           ...trucksData,
                            //           'vehicleId': matchedTrucksDoc.id,
                            //           'documentId': matchedTrucksDoc.id,
                            //         };
                            //
                            //         final ownerCode = trucksData['ownerCode'];
                            //         debugPrint(
                            //             '[DEBUG] ownerCode from trucks: $ownerCode');
                            //
                            //         Map<String, dynamic>? ownerDetails;
                            //
                            //         if (ownerCode != null) {
                            //           final ownerSnapshot = await _firestore
                            //               .collection('owners')
                            //               .where('userCode',
                            //                   isEqualTo: ownerCode)
                            //               .limit(1)
                            //               .get();
                            //
                            //           debugPrint(
                            //               '[DEBUG] Found ${ownerSnapshot.docs.length} matching owner(s)');
                            //
                            //           if (ownerSnapshot.docs.isNotEmpty) {
                            //             ownerDetails =
                            //                 ownerSnapshot.docs.first.data();
                            //             ownerDetails['documentId'] =
                            //                 ownerSnapshot.docs.first.id;
                            //             debugPrint(
                            //                 '[DEBUG] Owner details: $ownerDetails');
                            //           } else {
                            //             debugPrint(
                            //                 '[WARNING] No owner found with userCode: $ownerCode');
                            //           }
                            //         } else {
                            //           debugPrint(
                            //               '[WARNING] ownerCode is null in trucks document');
                            //         }
                            //
                            //         final bookingRef = _firestore
                            //             .collection('truck_bookings')
                            //             .doc(bookingId);
                            //
                            //         await bookingRef.update({
                            //           'captainDetails': captainDetails,
                            //           'vehicleDetails': vehicleDetails,
                            //           'ownerDetails': ownerDetails,
                            //           'status': BookingStatus.accepted,
                            //           'updatedAt': FieldValue.serverTimestamp(),
                            //         });
                            //
                            //         _startLiveLocationTracking(bookingId);
                            //         debugPrint(
                            //             '[FIRESTORE] Live Location updated successfully');
                            //
                            //         debugPrint(
                            //             '[FIRESTORE] Captain, vehicle, and owner details updated successfully.');
                            //         debugPrint('Booking ID: $bookingId');
                            //         debugPrint('Booking Ref: $bookingRef');
                            //         debugPrint(
                            //             '[FIRESTORE] Booking updated successfully');
                            //         final customerId =
                            //             bookingData['customer']['uid'];
                            //         final now = DateTime.now();
                            //         final captainName =
                            //             captainData['name'] ?? 'a captain';
                            //
                            //         final batch = _firestore.batch();
                            //
                            //         if (customerId != null) {
                            //           final customerNotificationRef = _firestore
                            //               .collection('customer_notifications')
                            //               .doc();
                            //           batch.set(customerNotificationRef, {
                            //             'userId': customerId,
                            //             'type': 'booking_accepted',
                            //             'bookingId': bookingId,
                            //             'title': 'Booking Accepted',
                            //             'message':
                            //                 'Your booking has been accepted by Captain $captainName',
                            //             'createdAt': now,
                            //             'read': false,
                            //             'relatedUserId': uid,
                            //             'relatedUserType': 'captain',
                            //           });
                            //         }
                            //
                            //         if (ownerDetails != null &&
                            //             ownerDetails['uid'] != null) {
                            //           final ownerNotificationRef = _firestore
                            //               .collection('owner_notifications')
                            //               .doc();
                            //           batch.set(ownerNotificationRef, {
                            //             'userId': ownerDetails['id'],
                            //             'type': 'booking_accepted',
                            //             'bookingId': bookingId,
                            //             'title': 'Booking Accepted',
                            //             'message':
                            //                 'Your vehicle booking has been accepted by Captain $captainName',
                            //             'createdAt': now,
                            //             'read': false,
                            //             'relatedUserId': uid,
                            //             'relatedUserType': 'captain',
                            //             'vehicleId': matchedTrucksDoc.id,
                            //           });
                            //         }
                            //
                            //         if (uid != null) {
                            //           final captainNotificationRef = _firestore
                            //               .collection('captain_notifications')
                            //               .doc();
                            //           batch.set(captainNotificationRef, {
                            //             'userId': uid,
                            //             'type': 'booking_accepted',
                            //             'bookingId': bookingId,
                            //             'title': 'Booking Confirmed',
                            //             'message':
                            //                 'You have accepted a booking successfully.',
                            //             'createdAt': now,
                            //             'read': false,
                            //           });
                            //         }
                            //
                            //         await batch.commit();
                            //         debugPrint(
                            //             '[NOTIFICATIONS] Notifications created successfully');
                            //
                            //         navigator.pushNamed(
                            //           Routes.rideTrackingTruck,
                            //           arguments: {
                            //             'bookingId': bookingId,
                            //             'bookingRef': bookingRef,
                            //           },
                            //         );
                            //       } catch (e) {
                            //         debugPrint(
                            //             '[ERROR] Failed to update booking: $e');
                            //         ScaffoldMessenger.of(context).showSnackBar(
                            //           SnackBar(
                            //               content: Text(
                            //                   'Failed to accept booking: ${e.toString()}')),
                            //         );
                            //       }
                            //     },
                            //   ),
                            // ),
                            Expanded(
                              child: MyElevatedButton(
                                title: 'Accept',
                                onPressed: () async {
                                  debugPrint('[BOTTOM SHEET] User chose "Accept"');

                                  // ✅ use rootNavigator before popping
                                  final navigator = Navigator.of(context, rootNavigator: true);
                                  Navigator.pop(context);
                                  _audioPlayer.release();

                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) {
                                    debugPrint('[ERROR] Current user UID is null.');
                                    return;
                                  }

                                  try {
                                    // --- Captain Doc ---
                                    final captainDoc =
                                    await _firestore.collection('captains').doc(uid).get();
                                    final captainData = captainDoc.data();

                                    if (captainData == null) {
                                      debugPrint('[ERROR] Captain document not found for UID: $uid');
                                      return;
                                    }

                                    debugPrint('[DEBUG] Captain userCode: ${captainData['userCode']}');

                                    // --- Find Truck with assignCaptains ---
                                    final trucksSnapshot = await _firestore.collection('trucks').get();
                                    final matchedTrucksDoc = trucksSnapshot.docs.firstWhereOrNull((doc) {
                                      final data = doc.data();
                                      final assignCaptains = data['assignCaptains'] as List<dynamic>?;

                                      if (assignCaptains == null) return false;

                                      return assignCaptains.any((c) =>
                                      c is Map<String, dynamic> &&
                                          c['id'] == (captainData['userCode'] ?? ''));
                                    });

                                    if (matchedTrucksDoc == null) {
                                      debugPrint(
                                          '[ERROR] No trucks assigned to captain with userCode: ${captainData['userCode']}');
                                      return;
                                    }

                                    final trucksData = matchedTrucksDoc.data();
                                    debugPrint('[DEBUG] Found trucks doc ID: ${matchedTrucksDoc.id}');
                                    debugPrint('[DEBUG] trucks data: $trucksData');

                                    final captainDetails = {
                                      ...captainData,
                                      'id': uid,
                                      'documentId': captainDoc.id,
                                    };

                                    final vehicleDetails = {
                                      ...trucksData,
                                      'vehicleId': matchedTrucksDoc.id,
                                      'documentId': matchedTrucksDoc.id,
                                    };

                                    final ownerCode = trucksData['ownerCode'];
                                    debugPrint('[DEBUG] ownerCode from trucks: $ownerCode');

                                    Map<String, dynamic>? ownerDetails;

                                    if (ownerCode != null) {
                                      final ownerSnapshot = await _firestore
                                          .collection('owners')
                                          .where('userCode', isEqualTo: ownerCode)
                                          .limit(1)
                                          .get();

                                      debugPrint(
                                          '[DEBUG] Found ${ownerSnapshot.docs.length} matching owner(s)');

                                      if (ownerSnapshot.docs.isNotEmpty) {
                                        ownerDetails = ownerSnapshot.docs.first.data();
                                        ownerDetails['documentId'] = ownerSnapshot.docs.first.id;
                                        debugPrint('[DEBUG] Owner details: $ownerDetails');
                                      } else {
                                        debugPrint(
                                            '[WARNING] No owner found with userCode: $ownerCode');
                                      }
                                    } else {
                                      debugPrint(
                                          '[WARNING] ownerCode is null in trucks document');
                                    }

                                    // --- Update Booking ---
                                    final bookingRef =
                                    _firestore.collection('truck_bookings').doc(bookingId);

                                    await bookingRef.update({
                                      'captainDetails': captainDetails,
                                      'vehicleDetails': vehicleDetails,
                                      'ownerDetails': ownerDetails,
                                      'status': BookingStatus.accepted,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                    _startLiveLocationTracking(bookingId);
                                    debugPrint('[FIRESTORE] Booking updated successfully');

                                    // --- Notifications ---
                                    final customerId = bookingData['customer']['uid'];
                                    final now = DateTime.now();
                                    final captainName = captainData['name'] ?? 'a captain';

                                    final batch = _firestore.batch();

                                    if (customerId != null) {
                                      final customerNotificationRef =
                                      _firestore.collection('customer_notifications').doc();
                                      batch.set(customerNotificationRef, {
                                        'userId': customerId,
                                        'type': 'booking_accepted',
                                        'bookingId': bookingId,
                                        'title': 'Booking Accepted',
                                        'message':
                                        'Your booking has been accepted by Captain $captainName',
                                        'createdAt': now,
                                        'read': false,
                                        'relatedUserId': uid,
                                        'relatedUserType': 'captain',
                                      });
                                    }

                                    if (ownerDetails != null && ownerDetails['uid'] != null) {
                                      final ownerNotificationRef =
                                      _firestore.collection('owner_notifications').doc();
                                      batch.set(ownerNotificationRef, {
                                        'userId': ownerDetails['id'],
                                        'type': 'booking_accepted',
                                        'bookingId': bookingId,
                                        'title': 'Booking Accepted',
                                        'message':
                                        'Your vehicle booking has been accepted by Captain $captainName',
                                        'createdAt': now,
                                        'read': false,
                                        'relatedUserId': uid,
                                        'relatedUserType': 'captain',
                                        'vehicleId': matchedTrucksDoc.id,
                                      });
                                    }

                                    final captainNotificationRef =
                                    _firestore.collection('captain_notifications').doc();
                                    batch.set(captainNotificationRef, {
                                      'userId': uid,
                                      'type': 'booking_accepted',
                                      'bookingId': bookingId,
                                      'title': 'Booking Confirmed',
                                      'message': 'You have accepted a booking successfully.',
                                      'createdAt': now,
                                      'read': false,
                                    });

                                    await batch.commit();
                                    debugPrint('[NOTIFICATIONS] Notifications created successfully');

                                    // --- Navigate to tracking ---
                                    navigator.pushNamed(
                                      Routes.rideTrackingTruck,
                                      arguments: {
                                        'bookingId': bookingId,
                                        'bookingRef': bookingRef,
                                      },
                                    );
                                  } catch (e) {
                                    debugPrint('[ERROR] Failed to update booking: $e');

                                    // ✅ safe snackbar (use navigator.context, not bottom sheet context)
                                    ScaffoldMessenger.of(navigator.context).showSnackBar(
                                      SnackBar(content: Text('Failed to accept booking: $e')),
                                    );
                                  }
                                },
                              ),
                            )

                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ).whenComplete(() {
      debugPrint('[BOTTOM SHEET] Dismissed');
      if (mounted) {
        setState(() {
          _isBookingDialogShowing = false;
        });
      }
    })
    .then((_) {

      debugPrint('[DEBUG] 📥 Bottom sheet closed by user or timeout');

      if (mounted) {
        setState(() {
          _isBookingDialogShowing = false;
        });

        // Only set up listener if the booking was completed or declined
        if (_currentBooking == null && !_findRequest) {
          // _setupStatusListener();
          _restartTruckBookingListenerIfNeeded();
        } else {
          debugPrint('[BOTTOM SHEET] Sheet closed manually, skipping status listener re-setup.');
        }
      }
    });
  }

// Helper widget for consistent fare row styling
//   Widget _buildFareRow(
//     String label,
//     String value, {
//     bool isBold = false,
//     bool isProfit = false,
//   }) {
//     final textStyle = TextStyle(
//       fontSize: 14, // Reduced from 16
//       fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//       color: isProfit ? Colors.green : (isBold ? primary : Colors.black87),
//     );
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2), // Reduced from 4
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Flexible(
//             child: Text(
//               label,
//               style: textStyle,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             value,
//             style: textStyle,
//           ),
//         ],
//       ),
//     );
//   }
  Widget _buildFareRow(
      String label,
      String value, {
        bool isBold = false,
        bool isProfit = false,
        Color? valueColor, // ✅ New parameter
      }) {
    final textStyle = TextStyle(
      fontSize: 14,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? primary : Colors.black87,
    );

    final valueTextStyle = textStyle.copyWith(
      color: valueColor ?? (isProfit ? Colors.green : textStyle.color),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: valueTextStyle,
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    debugPrint('[TIMER] Starting 60-second countdown');
    _secondsRemaining = 60;

    if (!_isMuted) _playNotificationSound(loop: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _stopNotificationSound();

        // ✅ Auto close bottom sheet
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Timeout: Booking auto declined")),
          );
        }

        // ✅ Clear booking in Firestore
        try {
          final bookingId = _currentBooking?['id'];
          if (bookingId == null) return;

          // debugPrint('[TIMEOUT] Booking ID: $bookingId timed out');
          //
          // // 1. Mark booking as timed out
          // await FirebaseFirestore.instance
          //     .collection('truck_bookings')
          //     .doc(bookingId)
          //     .update({
          //   'status': BookingStatus.timeout,
          //   'updated_at': FieldValue.serverTimestamp(),
          // });

          // 2. Clear from trucks
          final trucksQuery = await FirebaseFirestore.instance
              .collection('trucks')
              .where('currentBooking', isEqualTo: bookingId)
              .limit(1)
              .get();

          if (trucksQuery.docs.isNotEmpty) {
            final docId = trucksQuery.docs.first.id;
            await FirebaseFirestore.instance
                .collection('trucks')
                .doc(docId)
                .update({
              'status': 0,
              'currentBooking': FieldValue.delete(),
              'updated_at': FieldValue.serverTimestamp(),
            });
            debugPrint(
                '[TIMEOUT] Cleared booking from truck document [$docId]');
          }

          // ✅ Optionally reset local state
          setState(() {
            _currentBooking = null;
            _findRequest = false;
            _showBookingArrivedPopup = false;  // <-- add this
            _lastShownBookingId = null;        // <-- add this
          });

          _restartTruckBookingListenerIfNeeded(); // <-- add this

        } catch (e) {
          debugPrint('[TIMEOUT ERROR] Failed to clear booking: $e');
        }
      }
    });
  }

  Future<void> _playNotificationSound({bool loop = false}) async {
    if (_isSoundPlaying || _isMuted) return;

    try {
      debugPrint('[AUDIO] Playing notification sound (loop: $loop)');

      await _audioPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );

      // If already playing, stop first to restart
      if (_isSoundPlaying) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.resume();

      setState(() {
        _isSoundPlaying = true;
      });
    } catch (e) {
      debugPrint('[AUDIO ERROR] Failed to play sound: $e');
      setState(() {
        _isSoundPlaying = false;
      });
    }
  }

  Future<void> _stopNotificationSound() async {
    if (!_isSoundPlaying) return;

    try {
      debugPrint('[AUDIO] Stopping notification sound');
      await _audioPlayer.stop();

      setState(() {
        _isSoundPlaying = false;
      });
    } catch (e) {
      debugPrint('[AUDIO ERROR] Failed to stop sound: $e');
    }
  }

  void _toggleMute() {
    debugPrint('[AUDIO] Toggling mute. Current state: $_isMuted');

    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      _stopNotificationSound();
    } else if (_secondsRemaining > 0) {
      // If timer is running and we're unmuting, restart the sound
      _playNotificationSound(loop: true);
    }
  }

  void _setupStatusListener() async {
    if (_isBookingDialogShowing || _findRequest) {
      debugPrint('[LISTENER] Not setting up listener - booking dialog is showing');
      return;
    }

    debugPrint('[LISTENER] Setting up status listener');

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[AUTH] No authenticated user');
      return;
    }

    final userCode = await _getUserCode(user.uid);
    if (userCode == null) {
      debugPrint('[AUTH] User code not found');
      return;
    }

    _statusSubscription?.cancel(); // cancel previous listener

    _statusSubscription = _firestore.collection('trucks').snapshots().listen(
          (querySnapshot) async {
        if (!mounted) return;

        debugPrint('[LISTENER] Checking trucks for userCode: $userCode');

        final matchingTruck = querySnapshot.docs.firstWhereOrNull(
              (doc) {
            final data = doc.data();
            final assignCaptains = data['assignCaptains'] as List?;
            return assignCaptains?.any(
                  (c) => c is Map && c['id'] == userCode,
            ) ??
                false;
          },
        );


        if (matchingTruck == null) {
          debugPrint('[LISTENER] No matching truck found for $userCode');
          if (_findRequest) {
            setState(() {
              _findRequest = false;
              _currentBooking = null;
              _markers.removeWhere((m) => m.markerId.value == 'pickup');
              if (_latlng.length > 1) _latlng.removeAt(1);
            });
          }
          return;
        }

        final trucksData = matchingTruck.data();
        final status = trucksData['status'];
        final bookingId = trucksData['currentBooking'];

        debugPrint('[TRUCK] Found: ${matchingTruck.id}, Status: $status, Booking: $bookingId');

        if (status == BookingStatus.assigned && bookingId != null) {
          // 👇 Fetch booking and handle like before
          try {
            final bookingDoc = await _firestore.collection('truck_bookings').doc(bookingId).get();
            if (bookingDoc.exists) {
              final bookingData = bookingDoc.data()!;
              if (bookingData['status'] == BookingStatus.searching ||
                  bookingData['status'] == BookingStatus.assigned) {
                final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
                final toLocation = bookingData['toLocation'] as Map<String, dynamic>;

                setState(() {
                  _currentBooking = {
                    'id': bookingId,
                    'fromAddress': fromLocation['address'],
                    'fromLat': fromLocation['latitude'],
                    'fromLng': fromLocation['longitude'],
                    'toAddress': toLocation['address'],
                    'toLat': toLocation['latitude'],
                    'toLng': toLocation['longitude'],
                    'fare': bookingData['fare'] ?? '0',
                    'paymentMethod': bookingData['paymentMethod'] ?? 'Unknown',
                    'workHours': bookingData['workHours'] ?? 'Not specified',
                    'workIntensity': bookingData['workIntensity'],
                    'trucksSubType': bookingData['trucksSubType'],
                    'load': bookingData['load'] ?? 'Not specified',
                  };

                  _findRequest = true;
                  _secondsRemaining = 60;
                  _isAlarmAnimating = true;
                  _controller.repeat(reverse: true);

                  _markers.removeWhere((m) => m.markerId.value == 'pickup');
                  _markers.add(Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(fromLocation['latitude'], fromLocation['longitude']),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    infoWindow: InfoWindow(
                      title: 'Pickup Location',
                      snippet: fromLocation['address'],
                    ),
                  ));

                  if (_latlng.length > 1) {
                    _latlng[1] = LatLng(fromLocation['latitude'], fromLocation['longitude']);
                  } else {
                    _latlng.add(LatLng(fromLocation['latitude'], fromLocation['longitude']));
                  }
                });

                if (!_isMuted) {
                  debugPrint('[AUDIO] Notification sound should play here');
                  // _playNotificationSound();
                }
              } else {
                debugPrint('[BOOKING] Already accepted');
                if (_findRequest) {
                  setState(() {
                    _findRequest = false;
                    _currentBooking = null;
                    _markers.removeWhere((m) => m.markerId.value == 'pickup');
                    if (_latlng.length > 1) _latlng.removeAt(1);
                  });
                }
              }
            } else {
              debugPrint('[BOOKING] Booking document not found');
            }
          } catch (e) {
            debugPrint('[ERROR] Failed to fetch booking: $e');
          }
        } else if (_findRequest) {
          debugPrint('[BOOKING] No active booking, clearing state');
          setState(() {
            _findRequest = false;
            _currentBooking = null;
            _markers.removeWhere((m) => m.markerId.value == 'pickup');
            if (_latlng.length > 1) _latlng.removeAt(1);
          });
        }
      },
      onError: (error) {
        debugPrint('[ERROR] Status listener error: $error');
      },
    );
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LIFECYCLE] App state changed: $state');
    if (state == AppLifecycleState.resumed) {
      debugPrint('[LIFECYCLE] App resumed, reattaching listeners');
      _statusSubscription?.cancel();
      _startCentralBookingListener();
      // _setupStatusListener(); // or _startBookingAssignmentListener()
    }
  }

  void _startCentralBookingListener() async {
    debugPrint('[LISTENER] Starting central booking listener');

    final user = _auth.currentUser;
    if (user == null) return;

    final userCode = await _getUserCode(user.uid);
    if (userCode == null) return;

    _cancelAllListeners(); // Ensure no duplicates

    _vehicleStatusSubscription = _firestore
        .collection('truck')
        .snapshots()
        .listen((querySnapshot) async {
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final assignCaptains = data['assignCaptains'] as List<dynamic>?;

        if (assignCaptains == null) continue;

        final isMatch = assignCaptains.any(
              (captain) => captain is Map && captain['id'] == userCode,
        );

        if (!isMatch) continue;

        final bookingId = data['currentBooking'];

        if (data['status'] == 1 && bookingId != null) {
          debugPrint('[CENTRAL LISTENER] Assigned booking detected: $bookingId');

          if (bookingId != null) {
            _listenToBookingStatus(bookingId);
          }
          break; // ✅ Only process one matching BHL document
        }
      }
    }, onError: (e) {
      debugPrint('[LISTENER ERROR] $e');
    });
  }

  void _listenToBookingStatus(String bookingId) {
    debugPrint('[BOOKING STATUS LISTENER] Listening to bookingId: $bookingId');

    _statusSubscription?.cancel();
    final bookingRef = _firestore.collection('truck_bookings').doc(bookingId);

    _statusSubscription = bookingRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      debugPrint('[BOOKING STATUS] Booking status is $status');

      if ([BookingStatus.accepted, BookingStatus.inProgress].contains(status)) {
        debugPrint('[AUTO-NAVIGATE] Going to ride tracking');
        _cancelAllListeners();
        Navigator.pushNamed(
          context,
          Routes.rideTracking,
          arguments: {
            'bookingId': bookingId,
            'bookingRef': bookingRef,
          },
        );
      } else if ([BookingStatus.rejected, BookingStatus.timeout, BookingStatus.cancelled, BookingStatus.completed].contains(status)) {
        debugPrint('[CLEANUP] Booking ended or rejected');
        if (mounted) {
          setState(() {
            _showBookingArrivedPopup = false;
            _currentBooking = null;
            _findRequest = false;
          });
        }
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        }
        _restartBookingListenerIfNeeded();
      } else if ([BookingStatus.assigned].contains(status)) {
        debugPrint('[ASSIGNED] New booking assigned');
        await _sendTollGuruRouteEstimation(bookingId);
        setState(() {
          _currentBooking = {'id': bookingId};
          _showBookingArrivedPopup = true;
          _isBookingDialogShowing = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showBookingArrivedDialog(context, bookingId);
          _startTimer();
          if (_isBookingSoundEnabled && !_isMuted) {
            _audioPlayer.resume();
          }
        });
      }
    }) as StreamSubscription<QuerySnapshot<Object?>>?;

    // ✅ Cancel this listener after 60 seconds
    Future.delayed(const Duration(seconds: 60), () {
      debugPrint('[LISTENER TIMEOUT] Automatically cancelling booking status listener after 60 seconds');
      _statusSubscription?.cancel();
      _statusSubscription = null;
    });
  }

  void _restartBookingListenerIfNeeded() {
    if (!_showBookingArrivedPopup && !_findRequest) {
      debugPrint('[LISTENER] Restarting booking listener...');
      _startCentralBookingListener();
      // _startBookingAssignmentListener();
    }
  }

  void _cancelAllListeners() {
    debugPrint('[LISTENER] Cancelling all active listeners...');

    _statusSubscription?.cancel();
    _vehicleStatusSubscription?.cancel();
    _positionStream?.cancel();
    _timer?.cancel();

    _statusSubscription = null;
    _vehicleStatusSubscription = null;
    _positionStream = null;
    _timer = null;

    // Stop and release the audio player instead
    _audioPlayer.stop();
    _audioPlayer.release();

    debugPrint('[AUDIO] Audio player stopped and released');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
    _statusSubscription?.cancel();
    _bookingCheckTimer?.cancel();
    _audioPlayer.dispose();
    _bookingStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: DrawerView(),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialPosition,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              markers: Set<Marker>.of(_markers),
              onMapCreated: (controller) => _mapController.complete(controller),
            ),
            _upperInfo(context),
          ],
        ),
      ),
    );
  }

  Positioned _upperInfo(BuildContext context) {
    debugPrint('[BUILD] Building upper info section');

    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        child: SizedBox(
          width: 100.w,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        debugPrint('[BUTTON] Drawer button pressed');
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Container(
                          height: 40,
                          width: 40,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: myBorderRadius(10),
                            boxShadow: [boxShadow1],
                          ),
                          child: Image.asset(AssetImages.homedrawer)),
                    ),
                    Gap(15),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        height: 46,
                        decoration: BoxDecoration(
                          color: white,
                          boxShadow: [boxShadow1],
                          borderRadius: myBorderRadius(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.person, color: primary),
                            InkWell(
                              onTap: () async {
                                debugPrint(
                                    '[BUTTON] Online/offline toggle pressed');
                                final newStatus = !_isOnline;
                                await _showStatusChangeDialog(
                                  context,
                                  newStatus,
                                  () {
                                    debugPrint(
                                        '[STATUS] User confirmed status change');
                                    setState(() => _isOnline = newStatus);
                                    _updateOnlineStatus(newStatus);
                                  },
                                );
                              },
                              child: Container(
                                width: 97,
                                padding:
                                    EdgeInsets.symmetric(vertical: 7).copyWith(
                                  right: !_isOnline ? 10 : 6,
                                  left: !_isOnline ? 6 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _isOnline ? secoBtnColor : colorF2,
                                  borderRadius: myBorderRadius(20),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!_isOnline)
                                      Container(
                                        height: 20,
                                        width: 20,
                                        margin: EdgeInsets.only(right: 11),
                                        decoration: BoxDecoration(
                                            color: colorD9,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: white)),
                                      ),
                                    Text(_isOnline ? "Online" : "Offline",
                                        style: primaryMedium16),
                                    if (_isOnline)
                                      Container(
                                        height: 20,
                                        width: 18,
                                        margin: EdgeInsets.only(left: 11),
                                        decoration: BoxDecoration(
                                            color: primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: white)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_findRequest)
                  Padding(
                    padding: const EdgeInsets.only(top: 25),
                    child: Column(
                      children: [
                        // Full width vehicle card
                        if (_isOnline)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: _vehicleData != null &&
                                            _vehicleData!['vehiclePhotoUrl'] !=
                                                null
                                        ? NetworkImage(
                                            _vehicleData!['vehiclePhotoUrl'])
                                        : null),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _vehicleData == null
                                      ? const Text('No assigned vehicle',
                                          style: TextStyle(color: Colors.grey))
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                    _vehicleData![
                                                            'vehicleType'] ??
                                                        'Vehicle',
                                                    style: blackMedium14),
                                                const SizedBox(width: 8),
                                                Text(
                                                    _vehicleData![
                                                            'vehicleNumber'] ??
                                                        '',
                                                    style: primarySemiBold14),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                                _vehicleData![
                                                        'vehicleCategory'] ??
                                                    '',
                                                style: blackMedium14),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Two equal cards row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('Completed Jobs',
                                        style: colorABMedium16),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_completedJobs',
                                      style: primarySemiBold16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('Status', style: colorABMedium16),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isOnline ? "Available" : "Not Available",
                                      style: primarySemiBold16.copyWith(
                                        color: _isOnline ? primary : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingStatus {
  static const int searching = 0;
  static const int assigned = 1;
  static const int accepted = 2;
  static const int rejected = 3;
  static const int inProgress = 4;
  static const int cancelled = 6;
  static const int completed = 5;
  static const int timeout = 7;
}
