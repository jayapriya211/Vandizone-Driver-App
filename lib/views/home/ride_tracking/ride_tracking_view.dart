import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class RideTrackingView extends StatefulWidget {
  final Map<String, dynamic>? args;

  const RideTrackingView({Key? key, this.args}) : super(key: key);

  @override
  State<RideTrackingView> createState() => _RideTrackingViewState();
}

class _RideTrackingViewState extends State<RideTrackingView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int? _currentStatus;  // booking status
  bool _rideStarted = false; // controls button state
  final Completer<GoogleMapController> googleMapController = Completer();
  List<LatLng> polylineCoordinates = [];
  bool _isExpanded = false;
  String? bookingId;
  DocumentReference? bookingRef;

  // Location data
  LatLng? sourceLocation;
  LatLng? destination;
  String fromAddress = 'Loading address...';
  String toAddress = 'Loading address...';

  // Markers
  final List<Marker> _markers = [];
  final List<Uint8List> _markerIcons = [];
  bool _isLoading = true;
  bool _isCallButtonPressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.args != null) {
      bookingId = widget.args!['bookingId'];
      bookingRef = widget.args!['bookingRef'];
    }
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadBookingData();
    if (sourceLocation != null && destination != null) {
      await _getPolyPoints();
      await _loadMarkerIcons();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }

  }

  Future<void> _loadBookingData() async {
    if (bookingId == null) return;

    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bhl_bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data();
        final fromLoc = data?['fromLocation'] as Map<String, dynamic>?;
        final toLoc = data?['toLocation'] as Map<String, dynamic>?;

        if (mounted) {
          setState(() {
            if (fromLoc != null) {
              sourceLocation = LatLng(
                fromLoc['latitude'] as double,
                fromLoc['longitude'] as double,
              );
              fromAddress = fromLoc['address'] as String? ?? 'Unknown address';
            }
            if (toLoc != null) {
              destination = LatLng(
                toLoc['latitude'] as double,
                toLoc['longitude'] as double,
              );
              toAddress = toLoc['address'] as String? ?? 'Unknown address';
            }
          });
        }
      }
      final data = bookingDoc.data();

      if (mounted) {
        setState(() {
          _currentStatus = data?['status'] as int?;
          _rideStarted = _currentStatus == 4;
        });
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
    }
  }

  // In your _getPolyPoints method, ensure you're using the correct locations:
  Future<void> _getPolyPoints() async {
    if (sourceLocation == null || destination == null) return;

    polylineCoordinates.clear();
    final polylinePoints = PolylinePoints();
    final result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleMapApiKey,
      request: PolylineRequest(
        origin: PointLatLng(sourceLocation!.latitude, sourceLocation!.longitude),
        destination: PointLatLng(destination!.latitude, destination!.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      setState(() {
        polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      });

      // Adjust camera position to show both points and the route
      if (googleMapController.isCompleted) {
        final controller = await googleMapController.future;
        _fitBounds(controller);
      }
    }
  }

// Update the _fitBounds method to properly show the entire route:
  Future<void> _fitBounds(GoogleMapController controller) async {
    if (sourceLocation == null || destination == null || polylineCoordinates.isEmpty) return;

    // Create bounds that include all polyline points
    double minLat = sourceLocation!.latitude;
    double maxLat = sourceLocation!.latitude;
    double minLng = sourceLocation!.longitude;
    double maxLng = sourceLocation!.longitude;

    // Include destination in bounds
    minLat = min(minLat, destination!.latitude);
    maxLat = max(maxLat, destination!.latitude);
    minLng = min(minLng, destination!.longitude);
    maxLng = max(maxLng, destination!.longitude);

    // Include all polyline points in bounds
    for (final point in polylineCoordinates) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _loadMarkerIcons() async {
    _markerIcons.clear();
    _markers.clear();

    // Load source marker icon
    final sourceIcon = await getBytesFromAssets(AssetImages.youhere, 65);
    // Load destination marker icon
    final destIcon = await getBytesFromAssets(AssetImages.yellowcar, 55);

    setState(() {
      _markerIcons.addAll([sourceIcon, destIcon]);

      if (sourceLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('source'),
            position: sourceLocation!,
            icon: BitmapDescriptor.fromBytes(sourceIcon),
            infoWindow: InfoWindow(title: 'Pickup: ${fromAddress.split(',').first}'),
          ),
        );
      }

      if (destination != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: destination!,
            icon: BitmapDescriptor.fromBytes(destIcon),
            infoWindow: InfoWindow(title: 'Destination: ${toAddress.split(',').first}'),
          ),
        );
      }
    });
  }

  Future<void> sendCaptainCallNotification({
    required String captainId,
    required String bookingCode,
    required String customerName,
    required String channelName,
    required String idToken,
  }) async {
    final uri = Uri.parse(
        "https://us-central1-vandizone-admin.cloudfunctions.net/sendCaptainCallNotification");

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'captainId': captainId,
        'bookingCode': bookingCode,
        'customerName': customerName,
        'channelName': channelName,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Notification sent to captain.");
    } else {
      print("❌ Failed to send notification: ${response.body}");
    }
  }

  Future<Uint8List> getBytesFromAssets(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
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
          _map(),
          // _backButton(),
          _driverInfo(bookingId ?? ''),
        ],
      ),
    );
  }

  // Update your GoogleMap widget to show the polyline:
  Widget _map() {
    return GoogleMap(
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: sourceLocation ?? const LatLng(0, 0),
        zoom: 13.5,
      ),
      mapType: MapType.normal,
      onMapCreated: (controller) {
        googleMapController.complete(controller);
        if (sourceLocation != null && destination != null) {
          // Wait a moment for the map to initialize before fitting bounds
          Future.delayed(Duration(milliseconds: 500), () => _fitBounds(controller));
        }
      },
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      markers: Set<Marker>.of(_markers),
      polylines: {
        if (polylineCoordinates.isNotEmpty)
          Polyline(
            color: primary,
            width: 4,
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
          ),
      },
    );
  }

  Widget _backButton() {
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
              borderRadius: myBorderRadius(10),
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

  Widget _driverInfo(String bookingId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('bhl_bookings').doc(bookingId).get(),
      builder: (context, bookingSnapshot) {
        if (!bookingSnapshot.hasData) {
          return Center(child: _buildShimmerLoading());
        }

        final bookingData = bookingSnapshot.data!.data() as Map<String, dynamic>;
        final fromLocation = bookingData['fromLocation'] as Map<String, dynamic>;
        final toLocation = bookingData['toLocation'] as Map<String, dynamic>;
        final distance = bookingData['distance'] as String;
        final distanceValue = bookingData['distanceValue'] as num;
        final duration = bookingData['duration'] as String;
        final fare = bookingData['fare'] as num;
        final tollCost = bookingData['tollCost'] as num? ?? 0.0;
        final workHours = bookingData['workHours'] as int?;
        final workIntensity = bookingData['workIntensity'] as String?;
        final customer = bookingData['customer'] as Map<String, dynamic>?;
        final customerName = customer?['name'] ?? '';
        final bookingCode = bookingData['bookingCode'] ?? '';

        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('settings').get(),
          builder: (context, settingsSnapshot) {
            if (!settingsSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            if (settingsSnapshot.data!.docs.isEmpty) {
              return Center(child: Text("No settings found"));
            }

            final docData = settingsSnapshot.data!.docs.first.data();
            final vandizoneCommission = docData['vandizoneCommission'] as num;

            return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('vehicleOwnerCharges').get(),
              builder: (context, vehicleSnapshot) {
                if (!vehicleSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final vehicleDoc = vehicleSnapshot.data!.docs.first.data();
                final bhlUpCharge = (vehicleDoc['bhl_up_charge'] as num?)?.toDouble() ?? 0.0;
                final bhlDownCharge = (vehicleDoc['bhl_down_charge'] as num?)?.toDouble() ?? 0.0;

                // Calculations using the actual booking data
                final upCost = (bhlUpCharge * distanceValue.toDouble());
                final downCost = (bhlDownCharge * distanceValue.toDouble());
                final upDownTotal = upCost + downCost;
                final commissionAmount = ((fare * vandizoneCommission) / 100).round();
                final grossProfit = fare - (upDownTotal + tollCost + commissionAmount);
                String getChannelName(String bookingCode) => "call_channel_$bookingCode";

                return Container(
                  width: 100.w,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.vertical(top: myRadius(20)),
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
                          Text('$distance ($duration)', style: primarySemiBold14),
                        ],
                      ),
                      Gap(20),
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
                                  onTap: _isCallButtonPressed
                                      ? null
                                      : () async {
                                    setState(() => _isCallButtonPressed = true);
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
                                    ).then((_) {
                                      // Reset the flag when returning from the call screen
                                      if (mounted) {
                                        setState(() => _isCallButtonPressed = false);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.phone,
                                      color: _isCallButtonPressed ? Colors.grey : Colors.green,
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                      Gap(25),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(AssetImages.fromaddress, height: IconSize.regular),
                              Gap(5),
                              Expanded(child: Text(fromLocation['address'] ?? 'N/A', style: blackRegular16)),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, top: 5),
                            child: Column(
                              children: List.generate(
                                  3, (index) => Text("\u2022", style: blackRegular16.copyWith(height: 0.5))),
                            ),
                          ),
                          Row(
                            children: [
                              Image.asset(AssetImages.toaddress, height: IconSize.regular),
                              Gap(5),
                              Expanded(child: Text(toLocation['address'] ?? 'N/A', style: blackRegular16)),
                            ],
                          ),
                          if (workHours != null) ...[
                            Gap(20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Approximate Hrs', style: blackMedium18),
                                Text(workHours.toString(), style: primarySemiBold16),
                              ],
                            ),
                          ],
                          if (workIntensity != null) ...[
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Workload Intensity', style: blackMedium18),
                                Text(workIntensity, style: primarySemiBold16),
                              ],
                            ),
                          ],
                          Gap(20),
                          Divider(),
                          Gap(20),
                          MyElevatedButton(
                            title: _currentStatus == 2 ? 'Proceed' : 'View Details',
                            onPressed: (_currentStatus == 2 || _currentStatus == 4)
                                ? () {
                              if (_currentStatus == 2) {
                                _handleProceedButton();
                              } else if (_currentStatus == 4) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StartWorkView(bookingData: bookingData),
                                  ),
                                );
                              }
                            }
                                : null,
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

  Widget _fareRow(String label, String value, {bool isBold = false}) {
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
    if (_rideStarted) return; // prevent multiple presses
    setState(() => _rideStarted = true);

    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bhl_bookings')
          .doc(bookingId)
          .get();

      final bookingData = bookingDoc.data();
      final latestStatus = bookingData?['status'] as int?;

      // if (latestStatus != ) {
      //   if (mounted) {
      //     setState(() => _rideStarted = false);
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(content: Text('Trip already started or unavailable')),
      //     );
      //   }
      //   return;
      // }

      await sendCustomerBookingNotification(
        collection: 'bhl_bookings',
        bookingCode: bookingId ?? '',
        eventType: 'booking_started',
        title: 'Trip Started',
        body: 'Captain has started your trip.',
      );

      await FirebaseFirestore.instance
          .collection('bhl_bookings')
          .doc(bookingId)
          .update({
        'status': 4,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Optional: update other collection or documents if needed

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final now = DateTime.now();

      final captainDoc = await _firestore.collection('captains').doc(uid).get();
      final captainName = captainDoc.data()?['name'] ?? 'Captain';

      final customerId = bookingData?['customerId'];
      final ownerDetails = bookingData?['vehicleDetails']?['owner'] as Map<String, dynamic>?;

      final batch = _firestore.batch();

      if (customerId != null) {
        batch.set(_firestore.collection('customer_notifications').doc(), {
          'userId': customerId,
          'type': 'trip_started',
          'bookingId': bookingId,
          'title': 'Trip Started',
          'message': 'Captain $captainName has started your trip.',
          'createdAt': now,
          'read': false,
          'relatedUserId': uid,
          'relatedUserType': 'captain',
        });
      }

      if (ownerDetails?['uid'] != null) {
        batch.set(_firestore.collection('owner_notifications').doc(), {
          'userId': ownerDetails!['uid'],
          'type': 'trip_started',
          'bookingId': bookingId,
          'title': 'Trip Started',
          'message': 'Your vehicle booking has been started by Captain $captainName.',
          'createdAt': now,
          'read': false,
          'relatedUserId': uid,
          'relatedUserType': 'captain',
          'vehicleId': ownerDetails['id'],
        });
      }

      batch.set(_firestore.collection('captain_notifications').doc(), {
        'userId': uid,
        'type': 'trip_started',
        'bookingId': bookingId,
        'title': 'Trip Started',
        'message': 'You have started the trip for booking ID $bookingId.',
        'createdAt': now,
        'read': false,
      });

      await batch.commit();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StartWorkView(bookingData: bookingData),
        ),
      );

      if (mounted) {
        setState(() {
          _rideStarted = true;
          _currentStatus = 4;
        });
      }
    } catch (e) {
      debugPrint('Error in proceed: $e');
      if (mounted) {
        setState(() => _rideStarted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }


  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }


  @override
  void dispose() {
    _markers.clear();
    polylineCoordinates.clear();
    super.dispose();
  }
}

double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b;