import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../helper/voice_call.dart';
import '../../../routes/routes.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../utils/key.dart';
import '../../../widgets/my_elevated_button.dart';
import 'package:vandizone_caption/views/start_work/start_work.dart';
import 'package:vandizone_caption/views/start_work/start_work_truck.dart';
import 'package:shimmer/shimmer.dart';

class RideTrackingTruckView extends StatefulWidget {
  final Map<String, dynamic> args;

  const RideTrackingTruckView({Key? key, required this.args}) : super(key: key);

  @override
  State<RideTrackingTruckView> createState() => _RideTrackingTruckViewState();
}

class _RideTrackingTruckViewState extends State<RideTrackingTruckView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _rideStarted = false;
  final Completer<GoogleMapController> _mapController = Completer();
  List<LatLng> _polylineCoordinates = [];
  bool _isExpanded = false;
  String? _bookingId;
  DocumentReference? _bookingRef;

  // Location data
  LatLng? _sourceLocation;
  LatLng? _destination;
  String _fromAddress = 'Loading address...';
  String _toAddress = 'Loading address...';

  // Markers
  final List<Marker> _markers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('Widget args received: ${widget.args}');

    if (widget.args.isNotEmpty) {
      _bookingId = widget.args['bookingId'];
      _bookingRef = widget.args['bookingRef'] as DocumentReference?;
      debugPrint('Booking ID: $_bookingId');
      debugPrint('Booking Ref: $_bookingRef');

      // Initialize data immediately
      _initializeData();
    } else {
      debugPrint('Widget args are empty');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeData() async {
    try {
      // Load booking data first
      await _loadBookingData();

      // Then load polyline and markers
      if (_sourceLocation != null && _destination != null) {
        await _getPolyPoints();
        await _loadMarkers();
      }
    } catch (e) {
      debugPrint('Error initializing data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBookingData() async {
    if (_bookingId == null) return;

    try {
      final bookingDoc = await _firestore.collection('truck_bookings').doc(_bookingId).get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data() as Map<String, dynamic>;
        final fromLoc = data['fromLocation'] as Map<String, dynamic>;
        final toLoc = data['toLocation'] as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _sourceLocation = LatLng(
              fromLoc['latitude'] as double,
              fromLoc['longitude'] as double,
            );
            _fromAddress = fromLoc['address'] as String? ?? 'Unknown address';

            _destination = LatLng(
              toLoc['latitude'] as double,
              toLoc['longitude'] as double,
            );
            _toAddress = toLoc['address'] as String? ?? 'Unknown address';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
      rethrow;
    }
  }

  Future<void> _getPolyPoints() async {
    if (_sourceLocation == null || _destination == null) return;

    _polylineCoordinates.clear();
    final polylinePoints = PolylinePoints();

    try {
      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleMapApiKey,
        request: PolylineRequest(
          origin: PointLatLng(_sourceLocation!.latitude, _sourceLocation!.longitude),
          destination: PointLatLng(_destination!.latitude, _destination!.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _polylineCoordinates = result.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        });

        // Adjust camera position to show both points and the route
        if (_mapController.isCompleted) {
          final controller = await _mapController.future;
          _fitBounds(controller);
        }
      }
    } catch (e) {
      debugPrint('Error getting polyline points: $e');
    }
  }

  Future<void> _fitBounds(GoogleMapController controller) async {
    if (_sourceLocation == null || _destination == null || _polylineCoordinates.isEmpty) return;

    // Create bounds that include all points
    double minLat = _sourceLocation!.latitude;
    double maxLat = _sourceLocation!.latitude;
    double minLng = _sourceLocation!.longitude;
    double maxLng = _sourceLocation!.longitude;

    // Update with destination
    minLat = min(minLat, _destination!.latitude);
    maxLat = max(maxLat, _destination!.latitude);
    minLng = min(minLng, _destination!.longitude);
    maxLng = max(maxLng, _destination!.longitude);

    // Update with all polyline points
    for (final point in _polylineCoordinates) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Add some padding
    const double padding = 100;
    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, padding);

    try {
      await controller.animateCamera(cameraUpdate);
    } catch (e) {
      // Sometimes bounds are too small, fallback to simple zoom
      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      await controller.animateCamera(CameraUpdate.newLatLngZoom(center, 13));
      debugPrint('Error fitting bounds: $e');
    }
  }

  Future<void> _loadMarkers() async {
    _markers.clear();

    if (_sourceLocation == null || _destination == null) return;

    // Load custom marker icons
    final sourceIcon = await _getBitmapDescriptor(AssetImages.youhere, 65);
    final destIcon = await _getBitmapDescriptor(AssetImages.yellowcar, 55);

    setState(() {
      // Add source marker
      _markers.add(
        Marker(
          markerId: const MarkerId('source'),
          position: _sourceLocation!,
          icon: sourceIcon,
          infoWindow: InfoWindow(title: 'Pickup: ${_fromAddress.split(',').first}'),
        ),
      );

      // Add destination marker
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: destIcon,
          infoWindow: InfoWindow(title: 'Destination: ${_toAddress.split(',').first}'),
        ),
      );
    });
  }

  Future<BitmapDescriptor> _getBitmapDescriptor(String assetPath, int size) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: _buildShimmerLoading(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _buildMap(),
          _buildBackButton(),
          _buildDriverInfo(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: _sourceLocation ?? const LatLng(0, 0),
        zoom: 13.5,
      ),
      mapType: MapType.normal,
      onMapCreated: (controller) {
        _mapController.complete(controller);
        if (_sourceLocation != null && _destination != null) {
          // Wait a moment for the map to initialize before fitting bounds
          Future.delayed(const Duration(milliseconds: 500), () => _fitBounds(controller));
        }
      },
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      markers: Set<Marker>.of(_markers),
      polylines: {
        if (_polylineCoordinates.isNotEmpty)
          Polyline(
            polylineId: const PolylineId("route"),
            points: _polylineCoordinates,
            color: primary,
            width: 4,
          ),
      },
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 40,
      left: 20,
      child: SafeArea(
        child: InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [boxShadow1],
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: black,
              size: IconSize.regular,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('truck_bookings').doc(_bookingId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildShimmerLoading();
        }

        final bookingData = snapshot.data!.data() as Map<String, dynamic>;
        final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
        final toLocation = bookingData['toLocation'] as Map<String, dynamic>;
        final customer = bookingData['customer'] as Map<String, dynamic>?;
        final fare = bookingData['fare'] as num;

        return FutureBuilder<QuerySnapshot>(
          future: _firestore.collection('settings').get(),
          builder: (context, settingsSnapshot) {
            if (!settingsSnapshot.hasData) {
              return _buildShimmerLoading();
            }

            final settingsData = settingsSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            // final commission = settingsData['vandizoneCommission'] as num;
            final commissionPercent = settingsData['vandizoneCommission'] as num;
            final commissionAmount = (fare * commissionPercent) / 100;

            return Container(
              width: 100.w,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                color: white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trip Request', style: blackMedium18),
                      Text('Fare: ₹${fare.toStringAsFixed(2)}', style: primarySemiBold14),
                    ],
                  ),
                  const Gap(20),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(customer?['name'] ?? 'Customer Name', style: primaryMedium18),
                              Text(customer?['phone'] ?? '+91 XXXXX XXXXX', style: colorABMedium16),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                print("📞 Call button pressed");

                                final user = FirebaseAuth.instance.currentUser;
                                final idToken = await user?.getIdToken();
                                print("🔐 Firebase ID Token: ${idToken != null ? 'Retrieved' : 'Null'}");

                                final customerId = bookingData['customer']?['uid'];
                                final captainName = bookingData['captainDetails']?['name'];
                                final bookingCode = bookingData['bookingCode'];
                                final channelName = getChannelName(bookingCode);

                                print("📦 Data:");
                                print("- customerId: $customerId");
                                print("- captainName: $captainName");
                                print("- bookingCode: $bookingCode");
                                print("- channelName: $channelName");

                                if (idToken != null && customerId != null) {
                                  print("🚀 Sending call notification...");
                                  await sendCustomerCallNotification(
                                    customerId: customerId,
                                    bookingCode: bookingCode,
                                    captainName: captainName,
                                    channelName: channelName,
                                    idToken: idToken,
                                  );
                                  print("✅ Notification function called");
                                } else {
                                  print("❌ Missing required data. Notification not sent.");
                                }

                                print("📞 Navigating to VoiceCallScreen");
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VoiceCallScreen(
                                      isCaller: true,
                                      initialChannel: channelName,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(8), // Adjust padding as needed
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  // You can add color if needed: color: Colors.green.withOpacity(0.2)
                                ),
                                child: Icon(Icons.phone, color: Colors.green),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const Gap(25),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(AssetImages.fromaddress, height: IconSize.regular),
                          const Gap(5),
                          Expanded(child: Text(fromLocation['address'] ?? 'N/A', style: blackRegular16)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10, top: 5),
                        child: Column(
                          children: List.generate(
                              3, (index) => Text("•", style: blackRegular16.copyWith(height: 0.5))),
                        ),
                      ),
                      Row(
                        children: [
                          Image.asset(AssetImages.toaddress, height: IconSize.regular),
                          const Gap(5),
                          Expanded(child: Text(toLocation['address'] ?? 'N/A', style: blackRegular16)),
                        ],
                      ),
                      const Gap(20),
                      const Divider(),
                      InkWell(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Fare Breakdown', style: blackMedium18),
                            Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            children: [
                              // _buildFareRow('Customer Fare:', '₹${fare.toStringAsFixed(2)}'),
                              // _buildFareRow('Commission:', '₹${commission.toStringAsFixed(2)}'),
                              // _buildFareRow('Your Earnings:', '₹${(fare - commission).toStringAsFixed(2)}', isBold: true),
                              _buildFareRow('Customer Fare:', '₹${fare.toStringAsFixed(2)}'),
                              _buildFareRow('Commission (${commissionPercent.toStringAsFixed(0)}%):', '₹${commissionAmount.toStringAsFixed(2)}'),
                              _buildFareRow('Your Earnings:', '₹${(fare - commissionAmount).toStringAsFixed(2)}', isBold: true),
                            ],
                          ),
                        ),
                        crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                      const Gap(20),
                      MyElevatedButton(
                        title: !_rideStarted ? 'Proceed' : 'View Details',
                        onPressed: _handleProceedButton,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> sendCustomerCallNotification({
    required String customerId,
    required String bookingCode,
    required String captainName,
    required String channelName,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      "https://us-central1-vandizone-admin.cloudfunctions.net/sendCustomerCallNotification",
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'customerId': customerId,
        'bookingCode': bookingCode,
        'captainName': captainName,
        'channelName': channelName,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Notification sent to customer.");
    } else {
      print("❌ Failed to send notification: ${response.body}");
    }
  }

  String getChannelName(String bookingCode) => "call_channel_$bookingCode";

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          // Map placeholder
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            color: Colors.white,
          ),

          // Bottom sheet placeholder
          Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip request row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(width: 100, height: 20, color: Colors.white),
                          Container(width: 80, height: 16, color: Colors.white),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Driver info row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 150, height: 20, color: Colors.white),
                                SizedBox(height: 8),
                                Container(width: 120, height: 16, color: Colors.white),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              CircleAvatar(radius: 20, backgroundColor: Colors.white),
                              SizedBox(width: 5),
                              CircleAvatar(radius: 20, backgroundColor: Colors.white),
                            ],
                          )
                        ],
                      ),
                      SizedBox(height: 25),

                      // Address placeholders
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 20, height: 20, color: Colors.white),
                              SizedBox(width: 5),
                              Container(width: 200, height: 16, color: Colors.white),
                            ],
                          ),
                          SizedBox(height: 15),
                          Row(
                            children: [
                              Container(width: 20, height: 20, color: Colors.white),
                              SizedBox(width: 5),
                              Container(width: 200, height: 16, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      Divider(),

                      // Fare breakdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(width: 120, height: 20, color: Colors.white),
                          Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Button placeholder
                    ]
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? blackSemiBold16 : blackRegular16),
          Text(value, style: isBold ? primarySemiBold14 : primaryRegular14),
        ],
      ),
    );
  }

  Future<void> sendCustomerBookingNotification({
    required String collection,
    required String bookingCode,
    required String eventType,
    required String title,
    required String body,
  }) async {
    try {
      debugPrint("[NOTIFICATION] Preparing to send $eventType notification for booking $bookingCode");

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("[NOTIFICATION] ❌ Failed - User not authenticated");
        throw Exception("Not authenticated");
      }

      final idToken = await user.getIdToken();
      debugPrint("[NOTIFICATION] Retrieved user ID token");

      final uri = Uri.parse("https://us-central1-vandizone-admin.cloudfunctions.net/sendCustomCustomerNotification");
      debugPrint("[NOTIFICATION] Target URL: $uri");

      final payload = jsonEncode({
        'collection': collection,
        'bookingCode': bookingCode,
        'eventType': eventType,
        'title': title,
        'body': body,
      });
      debugPrint("[NOTIFICATION] Payload: $payload");

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        debugPrint("[NOTIFICATION] ✅ Successfully sent $eventType notification");
        debugPrint("[NOTIFICATION] Response: ${response.body}");
      } else {
        debugPrint("[NOTIFICATION] ❌ Failed with status ${response.statusCode}");
        debugPrint("[NOTIFICATION] Error response: ${response.body}");
      }
    } catch (e) {
      debugPrint("[NOTIFICATION] ❌ Exception occurred: $e");
      rethrow;
    }
  }

  Future<void> _handleProceedButton() async {
    try {

      // 1. Get booking details
      final bookingDoc = await _firestore.collection('truck_bookings').doc(_bookingId).get();
      final bookingData = bookingDoc.data() as Map<String, dynamic>;

      // 2. Update booking status

      await sendCustomerBookingNotification(
        collection: 'truck_bookings',
        bookingCode: _bookingId ?? '',
        eventType: 'booking_started',
        title: 'Trip Started',
        body: 'Captain has started your trip.',
      );

      await _firestore.collection('truck_bookings').doc(_bookingId).update({
        'status': 4, // Assuming 4 means "in progress"
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 3. Navigate to work screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StartWorkTruckView(bookingData: bookingData),
        ),
      );

      // 4. Update UI state
      if (mounted) {
        setState(() => _rideStarted = true);
      }
    } catch (e) {
      debugPrint('Error proceeding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to proceed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch $phoneUri';
    }
  }

  @override
  void dispose() {
    _markers.clear();
    _polylineCoordinates.clear();
    super.dispose();
  }
}