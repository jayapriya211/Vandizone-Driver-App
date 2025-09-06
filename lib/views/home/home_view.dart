import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vandizone_caption/helper/ui_helper.dart';
import 'package:vandizone_caption/routes/routes.dart';
import 'package:vandizone_caption/utils/key.dart';
import 'package:vandizone_caption/widgets/my_elevated_button.dart';
import 'package:sizer/sizer.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../utils/icon_size.dart';
import '../drawer/drawer_view.dart';
import '../../../widgets/my_textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  bool _isOnline = true;
  bool _findRequest = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> mapController = Completer();
  final List _imageList = [AssetImages.bhl];
  static const CameraPosition _sourceLocation =
  CameraPosition(target: LatLng(11.7905, 78.7047), zoom: 13.5);
  List<LatLng> _latlng = [LatLng(11.7905, 78.7047)];
  final Set<Marker> _markers = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statusSubscription;

  // StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statusSubscription;
  String? bargainAmount;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isMuted = false;
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAlarmAnimating = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _vehicleData;
  Map<String, dynamic>? _currentBooking;
  Timer? _bookingCheckTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vehicleStatusSubscription;
  bool _showBookingArrivedPopup = false;
  bool _isBookingDialogShowing = false;
  late AudioPlayer _audioPlayer;
  bool _isSoundPlaying = false;
  bool _isBookingSoundEnabled = true;
  double? tollCost;
  double? fuelCosts;
  int _completedJobs = 0;

  StreamSubscription<Position>? _positionStream;

  Future<BitmapDescriptor> _getCustomMarkerFromAsset(String assetPath, {int width = 80}) async {
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

        final assignCaptains = data['assignCaptains'] as List<dynamic>;

        return assignCaptains.any((c) =>
        c is Map<String, dynamic> && c['id'] == userCode);
      });


      if (matchedDoc != null) {
        await _firestore.collection('bhl').doc(matchedDoc.id).update({
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint('[LOCATION] BHL location updated: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('[ERROR] Failed to update BHL location: $e');
    }
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

  Future<int> _getCompletedBookingCount(String captainUserCode) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('bhl_bookings')
        .where('captainDetails.userCode', isEqualTo: captainUserCode)
        .where('status', isEqualTo: 5)
        .get();

    print('[DEBUG] Found ${querySnapshot.docs.length} completed bookings for captain $captainUserCode');
    for (var doc in querySnapshot.docs) {
      print('[DEBUG] Booking ID: ${doc.id}');
      print('[DEBUG] Booking Data: ${doc.data()}');
    }

    return querySnapshot.docs.length;
  }

  Future<void> _loadAssignedVehicleMarkers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('bhl').get();
      final BitmapDescriptor customIcon = await _getCustomMarkerFromAsset(AssetImages.bhl);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('assignCaptains')) continue;

        final assignCaptains = data['assignCaptains'];
        final vehicleNumber = data['vehicleNumber'] ?? 'Unknown';
        final lat = data['lat'];
        final lng = data['lng'];

        if (assignCaptains is List && lat != null && lng != null) {
          for (var captain in assignCaptains) {
            if (captain is Map<String, dynamic>) {
              final id = captain['id'];
              final name = captain['name'];

              _markers.add(Marker(
                markerId: MarkerId(id),
                position: LatLng(lat, lng),
                icon: customIcon,
                infoWindow: InfoWindow(
                  title: 'Captain: $name',
                  snippet: 'Vehicle: $vehicleNumber',
                ),
              ));

              debugPrint('[MAP] Marker added at: $lat, $lng for captain: $name');

              if (mounted) {
                setState(() {});
              }

              final GoogleMapController controller = await mapController.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: 15.0,
                  ),
                ),
              );

              return; // Stop after first match
            }
          }
        }
      }

      debugPrint('[MAP] No matching vehicle with assigned captain found');

    } catch (e) {
      debugPrint('[ERROR] Failed to load assigned vehicle markers: $e');
    }
  }


  void _startLiveLocationTracking(String bookingId) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only trigger when moved 10 meters
      ),
    ).listen((Position position) async {
      debugPrint('[TRACKING] New position: ${position.latitude}, ${position.longitude}');

      await FirebaseFirestore.instance
          .collection('bhl_bookings')
          .doc(bookingId)
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


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LIFECYCLE] App state changed: $state');
    if (state == AppLifecycleState.resumed) {
      debugPrint('[LIFECYCLE] App resumed, reattaching listeners');
      _vehicleStatusSubscription?.cancel();
      _startCentralBookingListener();
      // _setupStatusListener();
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[INIT] Initializing HomeView');

    _loadData();
    _loadVehicleData();
    _fetchCompletedJobs();
    _loadAssignedVehicleMarkers();

    // Initialize audio player
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();

    debugPrint('[ANIMATION] Setting up animation controller');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fetchBookingAndEstimateToll();
    // _startBookingCheckTimer();
    // _startBookingAssignmentListener();
    _startCentralBookingListener();
    debugPrint('[INIT] HomeView initialization complete');
  }

  // void _startBookingAssignmentListener() async {
  //   debugPrint('[LISTENER] Starting booking assignment listener');
  //
  //   final user = _auth.currentUser;
  //   if (user == null) return;
  //
  //   final userCode = await _getUserCode(user.uid);
  //   if (userCode == null) return;
  //
  //   _vehicleStatusSubscription?.cancel();
  //
  //   _vehicleStatusSubscription = _firestore
  //       .collection('bhl')
  //       .snapshots()
  //       .listen((querySnapshot) async {
  //     for (final doc in querySnapshot.docs) {
  //       final data = doc.data();
  //       final assignCaptains = data['assignCaptains'] as List<dynamic>?;
  //
  //       if (assignCaptains == null) continue;
  //
  //       final isMatch = assignCaptains.any(
  //             (captain) => captain is Map && captain['id'] == userCode,
  //       );
  //
  //       if (!isMatch) continue;
  //
  //       final bookingId = data['currentBooking'];
  //
  //       if (data['status'] == 1 && bookingId != null) {
  //         debugPrint('[BHL] Assigned booking detected: $bookingId');
  //
  //         if (!_findRequest || _currentBooking?['id'] != bookingId) {
  //           setState(() {
  //             _currentBooking = {'id': bookingId};
  //             _showBookingArrivedPopup = true;
  //           });
  //
  //           _listenToBookingStatus(bookingId);
  //         }
  //       }
  //     }
  //   }, onError: (e) {
  //     debugPrint('[BHL LISTENER ERROR] $e');
  //   });
  // }

  void _listenToBookingStatus(String bookingId) {
    debugPrint('[BOOKING STATUS LISTENER] Listening to bookingId: $bookingId');

    _statusSubscription?.cancel();
    final bookingRef = _firestore.collection('bhl_bookings').doc(bookingId);

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
    });

    // ✅ Cancel this listener after 60 seconds
    Future.delayed(const Duration(seconds: 60), () {
      debugPrint('[LISTENER TIMEOUT] Automatically cancelling booking status listener after 60 seconds');
      _statusSubscription?.cancel();
      _statusSubscription = null;
    });
  }

  Future<void> _setupAudioPlayer() async {
    try {
      debugPrint('[AUDIO] Setting audio source...');
      await _audioPlayer.setSource(AssetSource('sound/notification.mp3'));
      debugPrint('[AUDIO] Source set successfully');
      await _audioPlayer.resume();
      // debugPrint('[AUDIO] Setting audio source...');
      // await _audioPlayer.setSource(AssetSource('sound/notification.mp3'));
      // debugPrint('[AUDIO] Source set successfully');

      await _audioPlayer.setVolume(1.0); // Full volume
      debugPrint('[AUDIO] Audio player initialized');
    } catch (e) {
      debugPrint('[AUDIO ERROR] Failed to initialize audio player: $e');
    }
  }

  void _restartBookingListenerIfNeeded() {
    if (!_showBookingArrivedPopup && !_findRequest) {
      debugPrint('[LISTENER] Restarting booking listener...');
      _startCentralBookingListener();
      // _startBookingAssignmentListener();
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

    final querySnapshot = await FirebaseFirestore.instance.collection('bhl').get();

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
          .collection('bhl_bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        debugPrint('[TOLL GURU] Booking not found');
        return;
      }

      final bookingData = bookingDoc.data()!;
      final fromLocation = bookingData['fromLocation'];
      final toLocation = bookingData['toLocation'];

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
          "type": "2AxlesTruck",
          "axles": 4,
          "weight": 8500,
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

      final uri = Uri.parse("https://apis.tollguru.com/toll/v2/origin-destination-waypoints");
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

        final upAndDownCost = (fuelCosts! + tollCosts) * 2;
        tollCost = tollCosts;
        debugPrint('[TOLL GURU] Fuel Cost (One Way): \$${fuelCosts?.toStringAsFixed(2)}');
        debugPrint('[TOLL GURU] Toll Cost (One Way): \$${tollCosts.toStringAsFixed(2)}');
        debugPrint('[TOLL GURU] Total Round Trip Cost: \$${upAndDownCost.toStringAsFixed(2)}');
      } else {
        debugPrint('[TOLL GURU] Failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[TOLL GURU] Error sending route estimation request: $e');
    }
  }

  void _startBookingCheckTimer() {
    debugPrint('[TIMER] Starting booking check timer');

    _bookingCheckTimer?.cancel();

    _bookingCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) {
        debugPrint('[TIMER] Widget not mounted, skipping check');
        return;
      }

      if (!_isOnline) {
        debugPrint('[TIMER] Captain is offline, skipping check');
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[TIMER] No authenticated user');
        return;
      }

      final userCode = await _getUserCode(user.uid);
      if (userCode == null) {
        debugPrint('[TIMER] No user code found');
        return;
      }

      try {
        debugPrint('[FIRESTORE] Checking for BHL with assigned captain: $userCode');

        final querySnapshot = await _firestore.collection('bhl').get();

        final matchedDoc = querySnapshot.docs.firstWhereOrNull((doc) {
          final assignCaptains = doc['assignCaptains'] as List<dynamic>?;
          if (assignCaptains == null) return false;

          return assignCaptains.any((captain) =>
          captain is Map<String, dynamic> && captain['id'] == userCode);
        });

        if (matchedDoc != null) {
          final bhlData = matchedDoc.data();
          debugPrint('[BHL DATA] Status: ${bhlData['status']}, Booking: ${bhlData['currentBooking']}');

          if (bhlData['status'] == BookingStatus.assigned && bhlData['currentBooking'] != null) {
            final bookingId = bhlData['currentBooking'] as String;
            debugPrint('[BOOKING] New booking found: $bookingId');

            if (!_findRequest || _currentBooking?['id'] != bookingId) {
              debugPrint('[UI] New booking found, showing popup and stopping listener');

              _bookingCheckTimer?.cancel();

              if (mounted) {
                setState(() {
                  _showBookingArrivedPopup = true;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showBookingArrivedDialog(context, bookingId);
                  _isBookingSoundEnabled = true;
                  _startTimer();
                  _audioPlayer.resume(); // 🔊 Play notification sound
                });
              }
            }
          } else {
            debugPrint('[INFO] No new booking or not assigned');
          }
        } else {
          debugPrint('[FIRESTORE] No BHL documents matched this captain');
        }
      } catch (e) {
        debugPrint('[ERROR] Error checking for bookings: $e');
      }
    });
  }


  void _showBookingArrivedDialog(BuildContext context, String bookingId) {
    debugPrint('[BOTTOM SHEET] Showing booking arrived bottom sheet for booking: $bookingId');

    setState(() {
      _isBookingDialogShowing = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('bhl_bookings').doc(bookingId).get(),
        builder: (context, bookingSnapshot) {
          if (!bookingSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final bookingData = bookingSnapshot.data!.data() as Map<String, dynamic>;
          final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
          final toLocation = bookingData['toLocation'] as Map<String, dynamic>;
          final distance = bookingData['distance'] as String;
          final duration = bookingData['duration'] as String;
          final fare = bookingData['fare'] as num;
          final workHours = bookingData['workHours'] as int;
          final workIntensity = bookingData['workIntensity'] as String;
          final upCharge = bookingData['upCharge'] as num? ?? 0;
          final downCharge = bookingData['downCharge'] as num? ?? 0;
          final discount = bookingData['discount'] as num? ?? 0;
          final baseAmount = bookingData['baseamount'] as num? ?? fare;

          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('settings').get(),
              builder: (context, settingsSnapshot) {
                if (!settingsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (settingsSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No settings found"));
                }

                final docData = settingsSnapshot.data!.docs.first.data();
                final vandizoneCommission = docData['vandizoneCommission'] as num? ?? 0;
                final commissionAmount = ((fare * vandizoneCommission) / 100).round();

                return StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 100.w,
                          padding: const EdgeInsets.symmetric(horizontal: 20)
                              .copyWith(top: 25, bottom: 30),
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.vertical(top: myRadius(20)),
                            boxShadow: [boxShadow1],
                          ),
                          child: Column(
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
                                  Text('$distance ($duration)', style: primarySemiBold16),
                                ],
                              ),
                              Gap(20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(AssetImages.fromaddress, height: IconSize.regular),
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
                                      Image.asset(AssetImages.toaddress, height: IconSize.regular),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Approximate Hrs', style: blackMedium18),
                                  Text(workHours.toString(), style: primarySemiBold16),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Workload Intensity', style: blackMedium18),
                                  Text(workIntensity, style: primarySemiBold16),
                                ],
                              ),
                              SizedBox(height: 8),
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Base Amount:', style: blackMedium18),
                                        Text('₹$baseAmount', style: primarySemiBold16),
                                      ],
                                    ),
                                    if (discount > 0) SizedBox(height: 10),
                                    if (discount > 0)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Discount:', style: blackMedium18),
                                          Text('-₹$discount', style: primarySemiBold16),
                                        ],
                                      ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Up & Down Charge:', style: blackMedium18),
                                        Text('₹${upCharge + downCharge}', style: TextStyle(color: Colors.red,fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Toll Cost:', style: blackMedium18),
                                        Text('₹${tollCost?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    if (bookingData['taxes'] != null && bookingData['taxes'] is List) ...[
                                      SizedBox(height: 10),
                                      Text("Taxes", style: blackMedium18),
                                      SizedBox(height: 8),
                                      Column(
                                        children: (bookingData['taxes'] as List<dynamic>).map((tax) {
                                          final taxMap = tax as Map<String, dynamic>;
                                          return Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("${taxMap['name']} (${taxMap['value']}%)", style: blackMedium18),
                                              Text("₹${taxMap['amount']}", style: primarySemiBold16),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Commission:', style: blackMedium18),
                                        Text('₹$commissionAmount', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total Fare:', style: blackMedium18),
                                        Text('₹$fare', style: primarySemiBold16),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Gross Profit:', style: blackMedium18),
                                        Text('₹${(fare - (tollCost ?? 0) - commissionAmount - (fuelCosts ?? 0)).toStringAsFixed(2)}',
                                            style: primarySemiBold16),
                                      ],
                                    ),
                                  ],
                                ),
                                crossFadeState: _isExpanded
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: Duration(milliseconds: 300),
                              ),
                              Gap(20),
                              Row(
                                children: [
                                  Expanded(
                                    child: MyElevatedButton(
                                      title: 'Decline',
                                      isSecondary: true,
                                      onPressed: () async {
                                        _audioPlayer.pause();
                                        final shouldDecline = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: white,
                                            shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text("Decline Ride", style: blackSemiBold20),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                                  child: Image.asset(AssetImages.cancelride, height: 85),
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
                                                        onPressed: () => Navigator.pop(context, false),
                                                      ),
                                                    ),
                                                    Gap(20),
                                                    Expanded(
                                                      child: MyElevatedButton(
                                                        title: "Sure",
                                                        onPressed: () => Navigator.pop(context, true),
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
                                            Navigator.pop(context);
                                            await FirebaseFirestore.instance
                                                .collection('bhl_bookings')
                                                .doc(bookingId)
                                                .update({
                                              'status': 3,
                                              'updated_at': FieldValue.serverTimestamp(),
                                            });

                                            final querySnapshot = await FirebaseFirestore.instance
                                                .collection('bhl')
                                                .where('currentBooking', isEqualTo: bookingId)
                                                .limit(1)
                                                .get();

                                            if (querySnapshot.docs.isNotEmpty) {
                                              await FirebaseFirestore.instance
                                                  .collection('bhl')
                                                  .doc(querySnapshot.docs.first.id)
                                                  .update({
                                                'status': 0,
                                                'updated_at': FieldValue.serverTimestamp(),
                                                'currentBooking': FieldValue.delete(),
                                              });
                                            }

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Ride declined and vehicle released.')),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to decline ride: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  Gap(20),
                                  Expanded(
                                      child: MyElevatedButton(
                                          title: 'Accept',
                                          onPressed: () async {
                                            _timer?.cancel();
                                            _audioPlayer.release();
                                            _cancelAllListeners();
                                            final navigator = Navigator.of(context);
                                            Navigator.pop(context);

                                            final uid = FirebaseAuth.instance.currentUser?.uid;
                                            if (uid == null) return;

                                            try {
                                              final captainDoc = await _firestore.collection('captains').doc(uid).get();
                                              final captainData = captainDoc.data();

                                              final bhlSnapshot = await _firestore.collection('bhl').get();
                                              final matchedBhlDoc = bhlSnapshot.docs.firstWhereOrNull((doc) {
                                                final assignCaptains = doc.data()['assignCaptains'] as List<dynamic>?;
                                                return assignCaptains?.any((c) =>
                                                c is Map<String, dynamic> && c['id'] == (captainData?['userCode'] ?? '')) ?? false;
                                              });

                                              if (matchedBhlDoc == null) return;

                                              final bhlData = matchedBhlDoc.data();
                                              final captainDetails = {
                                                ...?captainData,
                                                'id': uid,
                                                'documentId': captainDoc.id,
                                              };

                                              final vehicleDetails = {
                                                ...bhlData,
                                                'vehicleId': matchedBhlDoc.id,
                                                'documentId': matchedBhlDoc.id,
                                              };

                                              Map<String, dynamic>? ownerDetails;
                                              final ownerCode = bhlData['ownerCode'];
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

                                              final bookingRef = _firestore.collection('bhl_bookings').doc(bookingId);
                                              final bookingSnapshot = await bookingRef.get();
                                              final bookingData = bookingSnapshot.data();
                                              final customerId = bookingData?['customer']['uid'];

                                              await bookingRef.update({
                                                'captainDetails': captainDetails,
                                                'vehicleDetails': vehicleDetails,
                                                'ownerDetails': ownerDetails,
                                                'status': BookingStatus.accepted,
                                                'updatedAt': FieldValue.serverTimestamp(),
                                              });

                                              _startLiveLocationTracking(bookingId);

                                              final now = DateTime.now();
                                              final captainName = captainData?['name'] ?? 'a captain';
                                              final batch = _firestore.batch();

                                              if (customerId != null) {
                                                final customerNotificationRef = _firestore.collection('customer_notifications').doc();
                                                batch.set(customerNotificationRef, {
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
                                                final ownerNotificationRef = _firestore.collection('owner_notifications').doc();
                                                batch.set(ownerNotificationRef, {
                                                  'userId': ownerDetails['uid'],
                                                  'type': 'booking_accepted',
                                                  'bookingId': bookingId,
                                                  'title': 'Booking Accepted',
                                                  'message': 'Your vehicle booking has been accepted by Captain $captainName',
                                                  'createdAt': now,
                                                  'read': false,
                                                  'relatedUserId': uid,
                                                  'relatedUserType': 'captain',
                                                  'vehicleId': matchedBhlDoc.id,
                                                });
                                              }

                                              if (uid != null) {
                                                final captainNotificationRef = _firestore.collection('captain_notifications').doc();
                                                batch.set(captainNotificationRef, {
                                                  'userId': uid,
                                                  'type': 'booking_accepted',
                                                  'bookingId': bookingId,
                                                  'title': 'Booking Confirmed',
                                                  'message': 'You have accepted a booking successfully.',
                                                  'createdAt': now,
                                                  'read': false,
                                                });
                                              }

                                              await batch.commit();
                                              navigator.pushNamed(
                                                Routes.rideTracking,
                                                arguments: {
                                                  'bookingId': bookingId,
                                                  'bookingRef': bookingRef,
                                                },
                                              );

                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Failed to accept booking: ${e.toString()}')),
                                              );
                                            }
                                          }
                                      )
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              });
        },
      ),
    ).then((_) {
      setState(() => _isBookingDialogShowing = false);
      if (!_findRequest) {
        _startCentralBookingListener();
      }
    });
  }

  Future<void> _showBookingDetails(String bookingId) async {
    debugPrint('[BOOKING] Showing details for booking: $bookingId');

    try {
      final bookingDoc = await _firestore.collection('bhl_bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        debugPrint('[BOOKING] Booking document does not exist');
        return;
      }

      if (!mounted) {
        debugPrint('[BOOKING] Widget not mounted');
        return;
      }

      final bookingData = bookingDoc.data()!;
      debugPrint('[BOOKING] Status: ${bookingData['status']}');

      // Only show if booking is pending or searching
      if (bookingData['status'] != BookingStatus.searching &&
          bookingData['status'] != BookingStatus.assigned &&
          bookingData['status'] != BookingStatus.accepted) {
        debugPrint('[BOOKING] Booking status is not searchable/assignable');
        if (_findRequest) _clearBooking();
        return;
      }


      final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
      final toLocation = bookingData['toLocation'] as Map<String, dynamic>;

      debugPrint('[BOOKING] From: ${fromLocation['address']}');
      debugPrint('[BOOKING] To: ${toLocation['address']}');

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
          'bhlSubType': bookingData['bhlSubType'],
          'load': bookingData['load'] ?? 'Not specified',
        };

        _findRequest = true;
        _secondsRemaining = 60;
        _isAlarmAnimating = true;
        _controller.repeat(reverse: true);
        _showBookingArrivedPopup = false;

        // Update map markers
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

        // Update polyline if needed
        if (_latlng.length > 1) {
          _latlng[1] = LatLng(fromLocation['latitude'], fromLocation['longitude']);
        } else {
          _latlng.add(LatLng(fromLocation['latitude'], fromLocation['longitude']));
        }
      });

      if (!_isMuted) {
        debugPrint('[AUDIO] Notification sound should play here');
        _playNotificationSound();
      }
    } catch (e) {
      debugPrint('[ERROR] Error showing booking details: $e');
    }
  }

  // void _setupStatusListener() async {
  //   if (_isBookingDialogShowing || _findRequest) {
  //     debugPrint('[LISTENER] Not setting up listener - booking dialog is showing');
  //     return;
  //   }
  //
  //   debugPrint('[LISTENER] Setting up status listener');
  //
  //   final user = _auth.currentUser;
  //   if (user == null) {
  //     debugPrint('[AUTH] No authenticated user');
  //     return;
  //   }
  //
  //   final userCode = await _getUserCode(user.uid);
  //   if (userCode == null) {
  //     debugPrint('[AUTH] User code not found');
  //     return;
  //   }
  //
  //   // Cancel any existing subscription
  //   _statusSubscription?.cancel();
  //
  //   _statusSubscription = _firestore.collection('bhl')
  //       .where('assignCaptains', arrayContains: {'id': userCode})
  //       .snapshots()
  //       .listen((querySnapshot) async {
  //     if (!mounted) {
  //       debugPrint('[LISTENER] Widget not mounted, ignoring update');
  //       return;
  //     }
  //     debugPrint('📡 Listening for bhl where assignCaptains contains id: $userCode');
  //
  //     // Clear any existing booking if no documents found
  //     if (querySnapshot.docs.isEmpty) {
  //       debugPrint('[LISTENER] No matching documents found');
  //       if (_findRequest) {
  //         setState(() {
  //           _findRequest = false;
  //           _currentBooking = null;
  //           _markers.removeWhere((m) => m.markerId.value == 'pickup');
  //           if (_latlng.length > 1) _latlng.removeAt(1);
  //         });
  //       }
  //       return;
  //     }
  //
  //     // Get the first matching BHL document (assuming one vehicle per captain)
  //     final bhlDoc = querySnapshot.docs.first;
  //     final bhlData = bhlDoc.data();
  //     debugPrint('[BHL DATA] Status: ${bhlData['status']}, Booking: ${bhlData['currentBooking']}');
  //
  //     // Check if status is active (1) and has a current booking
  //     if (bhlData['status'] == BookingStatus.assigned && bhlData['currentBooking'] != null) {
  //       final bookingId = bhlData['currentBooking'] as String;
  //       debugPrint('[BOOKING] New booking detected: $bookingId');
  //
  //       try {
  //         final bookingDoc = await _firestore.collection('bhl_bookings').doc(bookingId).get();
  //
  //         if (bookingDoc.exists) {
  //           final bookingData = bookingDoc.data()!;
  //           debugPrint('[BOOKING] Booking data loaded');
  //
  //           // Verify the booking hasn't already been accepted by another captain
  //           if (bookingData['status'] == BookingStatus.searching ||
  //               bookingData['status'] == BookingStatus.assigned) {
  //             final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
  //             final toLocation = bookingData['toLocation'] as Map<String, dynamic>;
  //
  //             debugPrint('[BOOKING] From: ${fromLocation['address']}');
  //             debugPrint('[BOOKING] To: ${toLocation['address']}');
  //
  //             setState(() {
  //               _currentBooking = {
  //                 'id': bookingId,
  //                 'fromAddress': fromLocation['address'],
  //                 'fromLat': fromLocation['latitude'],
  //                 'fromLng': fromLocation['longitude'],
  //                 'toAddress': toLocation['address'],
  //                 'toLat': toLocation['latitude'],
  //                 'toLng': toLocation['longitude'],
  //                 'fare': bookingData['fare'] ?? '0',
  //                 'paymentMethod': bookingData['paymentMethod'] ?? 'Unknown',
  //                 'workHours': bookingData['workHours'] ?? 'Not specified',
  //                 'workIntensity': bookingData['workIntensity'],
  //                 'bhlSubType': bookingData['bhlSubType'],
  //                 'load': bookingData['load'] ?? 'Not specified',
  //               };
  //
  //               _findRequest = true;
  //               _secondsRemaining = 60;
  //               _isAlarmAnimating = true;
  //               _controller.repeat(reverse: true);
  //
  //               // Update map markers
  //               _markers.removeWhere((m) => m.markerId.value == 'pickup');
  //               _markers.add(Marker(
  //                 markerId: const MarkerId('pickup'),
  //                 position: LatLng(fromLocation['latitude'], fromLocation['longitude']),
  //                 icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
  //                 infoWindow: InfoWindow(
  //                   title: 'Pickup Location',
  //                   snippet: fromLocation['address'],
  //                 ),
  //               ));
  //
  //               // Update polyline if needed
  //               if (_latlng.length > 1) {
  //                 _latlng[1] = LatLng(fromLocation['latitude'], fromLocation['longitude']);
  //               } else {
  //                 _latlng.add(LatLng(fromLocation['latitude'], fromLocation['longitude']));
  //               }
  //             });
  //
  //             if (!_isMuted) {
  //               debugPrint('[AUDIO] Notification sound should play here');
  //               // _playNotificationSound();
  //             }
  //           } else {
  //             debugPrint('[BOOKING] Booking already accepted by someone else');
  //             if (_findRequest) {
  //               setState(() {
  //                 _findRequest = false;
  //                 _currentBooking = null;
  //                 _markers.removeWhere((m) => m.markerId.value == 'pickup');
  //                 if (_latlng.length > 1) _latlng.removeAt(1);
  //               });
  //             }
  //           }
  //         } else {
  //           debugPrint('[BOOKING] Booking document does not exist');
  //         }
  //       } catch (e) {
  //         debugPrint('[ERROR] Error fetching booking details: $e');
  //       }
  //     } else if (_findRequest) {
  //       debugPrint('[BOOKING] Clearing current booking due to status change');
  //       setState(() {
  //         _findRequest = false;
  //         _currentBooking = null;
  //         _markers.removeWhere((m) => m.markerId.value == 'pickup');
  //         if (_latlng.length > 1) _latlng.removeAt(1);
  //       });
  //     }
  //   }, onError: (error) {
  //     debugPrint('[ERROR] Status listener error: $error');
  //   });
  // }

  void _startCentralBookingListener() async {
    debugPrint('[LISTENER] Starting central booking listener');

    final user = _auth.currentUser;
    if (user == null) return;

    final userCode = await _getUserCode(user.uid);
    if (userCode == null) return;

    _cancelAllListeners(); // Ensure no duplicates

    _vehicleStatusSubscription = _firestore
        .collection('bhl')
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


  Future<bool?> _showBookingConfirmationDialog(BuildContext context, String bookingId) async {
    debugPrint('[DIALOG] Showing booking confirmation dialog');

    try {
      // First get the booking details
      final bookingDoc = await _firestore.collection('bhl_bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        debugPrint('[BOOKING] Booking document does not exist');
        return false;
      }

      final bookingData = bookingDoc.data()!;
      final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
      final toLocation = bookingData['toLocation'] as Map<String, dynamic>;

      debugPrint('[BOOKING] Showing confirmation for booking: $bookingId');

      return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: white,
          contentPadding: EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New Booking Request', style: blackSemiBold20),
              Gap(20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: primary, size: 20),
                      Gap(5),
                      Expanded(child: Text(fromLocation['address'], style: blackRegular16)),
                    ],
                  ),
                  Gap(10),
                  Row(
                    children: [
                      Icon(Icons.location_pin, color: Colors.red, size: 20),
                      Gap(5),
                      Expanded(child: Text(toLocation['address'], style: blackRegular16)),
                    ],
                  ),
                ],
              ),
              Gap(15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fare:', style: blackMedium18),
                  Text('₹${bookingData['fare']}', style: primarySemiBold16),
                ],
              ),
              Gap(15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vehicle Type:', style: blackMedium18),
                  Text(bookingData['workIntensity'], style: primarySemiBold16),
                ],
              ),
              Gap(25),
              Row(
                children: [
                  Expanded(
                    child: MyElevatedButton(
                      title: 'Reject',
                      isSecondary: true,
                      onPressed: () {
                        debugPrint('[BOOKING] User rejected booking');
                        Navigator.pop(context, false);
                      },
                    ),
                  ),
                  Gap(20),
                  Expanded(
                    child: MyElevatedButton(
                      title: 'Accept',
                      onPressed: () {
                        debugPrint('[BOOKING] User accepted booking');
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ERROR] Error showing booking dialog: $e');
      return false;
    }
  }

  Future<void> _handleNewBookingAssignment(String bookingId) async {
    debugPrint('[BOOKING] Handling new booking assignment: $bookingId');

    try {
      final bookingDoc = await _firestore.collection('bhl_bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        debugPrint('[BOOKING] Booking document does not exist');
        return;
      }

      final bookingData = bookingDoc.data()!;
      debugPrint('[BOOKING] Booking data loaded');

      setState(() {
        _currentBooking = {
          'fromAddress': bookingData['fromLocation']['address'],
          'fromLat': bookingData['fromLocation']['latitude'],
          'fromLng': bookingData['fromLocation']['longitude'],
          'toAddress': bookingData['toLocation']['address'],
          'toLat': bookingData['toLocation']['latitude'],
          'toLng': bookingData['toLocation']['longitude'],
          'fare': bookingData['fare'],
          'paymentMethod': bookingData['paymentMethod'],
          'workHours': bookingData['workHours'],
          'workIntensity': bookingData['workIntensity'],
          'bhlSubType': bookingData['bhlSubType'],
          'id': bookingId,
        };

        _findRequest = true;
        _secondsRemaining = 60;

        _updateMapMarkers(
          bookingData['fromLocation']['latitude'],
          bookingData['fromLocation']['longitude'],
          bookingData['fromLocation']['address'],
        );
      });

      debugPrint('[FIRESTORE] Updating booking status to assigned');
      // Update the booking status to assigned
      await _firestore.collection('bhl_bookings').doc(bookingId).update({
        'status': BookingStatus.assigned,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!_isMuted) {
        debugPrint('[AUDIO] Notification sound should play here');
        // _playNotificationSound();
      }
    } catch (e) {
      debugPrint('[ERROR] Error handling booking assignment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept booking: ${e.toString()}')),
      );
    }
  }

  void _updateMapMarkers(double lat, double lng, String address) {
    debugPrint('[MAP] Updating markers with pickup location: $lat,$lng');

    _latlng = [
      _latlng[0],
      LatLng(lat, lng),
    ];

    _markers.removeWhere((m) => m.markerId.value == 'pickup');
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'Pickup Location',
        snippet: address,
      ),
    ));

    debugPrint('[MAP] Markers updated successfully');
  }

  void _clearBooking() {
    debugPrint('[BOOKING] Clearing current booking data');

    setState(() {
      _findRequest = false;
      _currentBooking = null;
      _markers.removeWhere((m) => m.markerId.value == 'pickup');
      if (_latlng.length > 1) _latlng.removeAt(1);
    });

    debugPrint('[UI] Booking data cleared from state');
  }

  @override
  void dispose() {
    debugPrint('[DISPOSE] Cleaning up resources');
    _cancelAllListeners(); // instead of individual cancel calls
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    debugPrint('[MAP] Loading map marker data');

    for (int i = 0; i < _imageList.length; i++) {
      bool isMyLocation = i == 1;
      debugPrint('[MAP] Processing marker ${i + 1}/${_imageList.length}');

      final Uint8List markerIcon =
      await getBytesFromAssets(_imageList[i], isMyLocation ? 35 : 55);
      _markers.add(Marker(
        icon: BitmapDescriptor.bytes(markerIcon),
        markerId: MarkerId(i.toString()),
        position: _latlng[i],
        rotation: isMyLocation ? 0 : i * 45,
        infoWindow: InfoWindow(
          title: isMyLocation ? 'You are here' : null,
        ),
      ));

      debugPrint('[MAP] Marker $i added successfully');
    }

    if (mounted) {
      setState(() {});
      debugPrint('[UI] Map markers updated in UI');
    }
  }

  Future<Uint8List> getBytesFromAssets(String path, int width) async {
    debugPrint('[ASSETS] Loading image from assets: $path');

    try {
      ByteData data = await rootBundle.load(path);
      ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
          targetHeight: width);
      ui.FrameInfo fi = await codec.getNextFrame();

      debugPrint('[ASSETS] Image loaded successfully');
      return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
    } catch (e) {
      debugPrint('[ERROR] Failed to load image from assets: $e');
      rethrow;
    }
  }

  void _startTimer() {
    debugPrint('[TIMER] Starting 60-second countdown');
    _secondsRemaining = 60;

    // Start playing sound if not muted
    if (!_isMuted) {
      _playNotificationSound(loop: true);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
        debugPrint('[TIMER] Countdown: $_secondsRemaining seconds remaining');
      } else {
        debugPrint('[TIMER] Countdown completed');
        timer.cancel();
        _stopNotificationSound();

        // Mark booking as timeout and clean up
        _handleBookingTimeout();
      }
    });
  }

  Future<void> _handleBookingTimeout() async {
    final bookingId = _currentBooking?['id'];
    if (bookingId == null) {
      debugPrint('[TIMEOUT] No current booking to timeout');
      return;
    }

    // Double-check the current booking status from Firestore
    final bookingDoc = await _firestore.collection('bhl_bookings').doc(bookingId).get();
    final status = bookingDoc.data()?['status'];
    if (status == BookingStatus.accepted) {
      debugPrint('[TIMEOUT] Booking already accepted. Skipping timeout logic.');
      return;
    }

    try {

      final querySnapshot = await _firestore
          .collection('bhl')
          .where('currentBooking', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final bhlDoc = querySnapshot.docs.first;
        await _firestore.collection('bhl').doc(bhlDoc.id).update({
          'status': BookingStatus.searching,
          'currentBooking': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Vehicle released: ${bhlDoc.id}');
      }

      // 3. Close bottom sheet if visible
      if (_isBookingDialogShowing) {
        Navigator.of(context).pop();
      }

      // 4. Clear booking state
      _clearBooking();

      // Optionally show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking timed out and released')),
      );
    } catch (e) {
      debugPrint('❌ Failed to handle booking timeout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error handling booking timeout: ${e.toString()}')),
      );
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

  Future<void> _playNotificationSound({bool loop = false}) async {
    if (_isMuted) return;

    try {
      debugPrint('[AUDIO] Playing notification sound (loop: $loop)');

      await _audioPlayer.stop();
      debugPrint('[AUDIO] Setting audio source...');
      await _audioPlayer.setSource(AssetSource('sound/notification.mp3'));
      debugPrint('[AUDIO] Source set successfully');
      await _audioPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
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
          await _updateBhlLocation(position);
        }
      }
    } catch (e) {
      debugPrint('[ERROR] Failed to update online status: $e');

      if (e is FirebaseException) {
        debugPrint('[FIREBASE] Error details - code: ${e.code}, message: ${e.message}');
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

      Future<Map<String, dynamic>?> _findMatchingVehicle(QuerySnapshot query) async {
        debugPrint('[VEHICLE] Searching in collection: ${query.size} documents');

        for (final doc in query.docs) {
          final data = doc.data() as Map<String, dynamic>;

          final assignCaptains = data['assignCaptains'] as List<dynamic>?;

          if (assignCaptains != null) {
            final match = assignCaptains.any((captain) =>
            captain is Map<String, dynamic> && captain['id'] == userCode);

            if (match) {
              debugPrint('[VEHICLE] Found matching vehicle: ${doc.id}');
              debugPrint('[VEHICLE] 🚛 Full matching vehicle data:\n$data');
              return {
                'vehicleType': data['vehicleType'],
                'vehicleNumber': data['vehicleNumber'],
                'vehicleCategory': data['vehicleCategory'],
                'vehiclePhotoUrl': data['vehiclePhotoUrl'],
                'docId': doc.id,
              };
            }
          }
        }
        return null;
      }

      // Check in bhl
      debugPrint('[VEHICLE] Checking BHL collection');
      final bhlQuery = await _firestore.collection('bhl').get();
      final bhlMatch = await _findMatchingVehicle(bhlQuery);
      if (bhlMatch != null) {
        debugPrint('[VEHICLE] BHL vehicle found $_vehicleData');
        setState(() => _vehicleData = bhlMatch);
        return;
      }

      // Check in trucks
      debugPrint('[VEHICLE] Checking trucks collection');
      final trucksQuery = await _firestore.collection('trucks').get();
      final truckMatch = await _findMatchingVehicle(trucksQuery);
      if (truckMatch != null) {
        debugPrint('[VEHICLE] Truck found');
        setState(() => _vehicleData = truckMatch);
        return;
      }

      debugPrint('[VEHICLE] No assigned vehicle found');
      setState(() => _vehicleData = null);
    } catch (e) {
      debugPrint('[ERROR] Error loading vehicle data: $e');
      setState(() => _vehicleData = null);
    }
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
            Text(newStatus ? "Go Online" : "Go Offline", style: blackSemiBold20),
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

  @override
  Widget build(BuildContext context) {
    debugPrint('[BUILD] Rebuilding HomeView');

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: DrawerView(),
        body: SizedBox(
          height: 100.h,
          width: 100.w,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              GoogleMap(
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                initialCameraPosition: _sourceLocation,
                mapType: MapType.normal,
                onMapCreated: (c) => mapController.complete(c),
                myLocationEnabled: false,
                markers: Set<Marker>.of(_markers),
              ),
              _upperInfo(context),
            ],
          ),
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
                                debugPrint('[BUTTON] Online/offline toggle pressed');
                                final newStatus = !_isOnline;
                                await _showStatusChangeDialog(
                                  context,
                                  newStatus,
                                      () {
                                    debugPrint('[STATUS] User confirmed status change');
                                    setState(() => _isOnline = newStatus);
                                    _updateOnlineStatus(newStatus);
                                  },
                                );
                              },
                              child: Container(
                                width: 97,
                                padding: EdgeInsets.symmetric(vertical: 7).copyWith(
                                  right: !_isOnline ? 10 : 6,
                                  left: !_isOnline ? 6 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _isOnline ? secoBtnColor : colorF2,
                                  borderRadius: myBorderRadius(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    Text(_isOnline ? "Online" : "Offline", style: primaryMedium16),
                                    if (_isOnline)
                                      Container(
                                        height: 20,
                                        width: 20,
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
                                        color: _isOnline
                                            ? primary
                                            : Colors.red,
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