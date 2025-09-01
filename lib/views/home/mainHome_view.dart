// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
//
// import 'home_view.dart';         // BHL
// import 'truck_home_view.dart';  // Truck
//
// class MainHomePage extends StatefulWidget {
//   const MainHomePage({Key? key}) : super(key: key);
//
//   @override
//   State<MainHomePage> createState() => _MainHomePageState();
// }
//
// class _MainHomePageState extends State<MainHomePage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   @override
//   void initState() {
//     super.initState();
//     _redirectBasedOnVehicle();
//   }
//
//   Future<void> _redirectBasedOnVehicle() async {
//     final user = _auth.currentUser;
//     if (user == null) {
//       debugPrint('[ERROR] No authenticated user found');
//       return;
//     }
//
//     final userCode = await _getUserCode(user.uid);
//     if (userCode == null) {
//       debugPrint('[ERROR] No userCode found for user: ${user.uid}');
//       return;
//     }
//
//     debugPrint('[INFO] Logged-in captain userCode: $userCode');
//
//     // First check trucks
//     final truckDocs = await _firestore.collection('trucks').get();
//     for (var doc in truckDocs.docs) {
//       if (!doc.data().containsKey('assignCaptains')) continue; // ✅ skip if missing
//       final assignCaptains = doc['assignCaptains'] as List<dynamic>?;
//
//       if (assignCaptains?.any((c) => c is Map && c['id'] == userCode) ?? false) {
//         debugPrint('[ROUTE] Assigned to TRUCK → Navigating to TruckHomePage');
//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const TruckHomePage()),
//           );
//         }
//         return;
//       }
//     }
//
//
//     // Then check BHL
//     final bhlDocs = await _firestore.collection('bhl').get();
//     for (var doc in bhlDocs.docs) {
//       if (!doc.data().containsKey('assignCaptains')) continue; // ✅ skip if missing
//       final assignCaptains = doc['assignCaptains'] as List<dynamic>?;
//
//       if (assignCaptains?.any((c) => c is Map && c['id'] == userCode) ?? false) {
//         debugPrint('[ROUTE] Assigned to BHL → Navigating to HomeView');
//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const HomeView()),
//           );
//         }
//         return;
//       }
//     }
//
//     debugPrint('[ROUTE] Captain not assigned to any vehicle');
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No vehicle assigned to your account')),
//       );
//     }
//   }
//
//   Future<String?> _getUserCode(String uid) async {
//     try {
//       final doc = await _firestore.collection('captains').doc(uid).get();
//       return doc.exists ? doc['userCode'] as String? : null;
//     } catch (e) {
//       debugPrint('[ERROR] Failed to fetch userCode: $e');
//       return null;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(child: CircularProgressIndicator()),
//     );
//   }
// }

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';
import '../../utils/constant.dart';
import '../drawer/drawer_view.dart';
import 'truck_home_view.dart';
import 'home_view.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};

  bool _isOnline = true;
  bool _isUnassigned = false;
  bool _findRequest = false;
  Map<String, dynamic>? _vehicleData;
  String? _userCode;
  Timer? _bookingCheckTimer;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(12.9716, 77.5946), // Default to Bangalore
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _redirectBasedOnVehicle();
  }

  Future<void> _redirectBasedOnVehicle() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _userCode = await _getUserCode(user.uid);
    if (_userCode == null) return;

    // Check TRUCK
    final truckDocs = await _firestore.collection('trucks').get();
    for (var doc in truckDocs.docs) {
      final assignCaptains = doc.data()['assignCaptains'] as List<dynamic>?;
      if (assignCaptains?.any((c) => c is Map && c['id'] == _userCode) ?? false) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TruckHomePage()));
        return;
      }
    }

    // Check BHL
    final bhlDocs = await _firestore.collection('bhl').get();
    for (var doc in bhlDocs.docs) {
      final assignCaptains = doc.data()['assignCaptains'] as List<dynamic>?;
      if (assignCaptains?.any((c) => c is Map && c['id'] == _userCode) ?? false) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeView()));
        return;
      }
    }

    setState(() {
      _isUnassigned = true;
    });

    _startBookingCheck(); // Start polling
  }

  Future<String?> _getUserCode(String uid) async {
    try {
      final doc = await _firestore.collection('captains').doc(uid).get();
      return doc.exists ? doc['userCode'] as String? : null;
    } catch (e) {
      debugPrint('Error fetching userCode: $e');
      return null;
    }
  }

  void _startBookingCheck() {
    if (_bookingCheckTimer != null) return;

    _bookingCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _userCode == null) return;

      final truckSnap = await _firestore
          .collection('trucks')
          .where('assignCaptains', arrayContainsAny: [{'id': _userCode}])
          .get();

      if (truckSnap.docs.isNotEmpty) {
        _bookingCheckTimer?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TruckHomePage()));
        return;
      }

      final bhlSnap = await _firestore
          .collection('bhl')
          .where('assignCaptains', arrayContainsAny: [{'id': _userCode}])
          .get();

      if (bhlSnap.docs.isNotEmpty) {
        _bookingCheckTimer?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeView()));
      }
    });
  }

  @override
  void dispose() {
    _bookingCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const DrawerView(),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            GoogleMap(
              initialCameraPosition: _initialPosition,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              myLocationEnabled: false,
              markers: _markers,
              onMapCreated: (controller) => _mapController.complete(controller),
            ),
            _buildUpperInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUpperInfo(BuildContext context) {
    if (!_isUnassigned) return const SizedBox();

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
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      child: Container(
                        height: 40,
                        width: 40,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.menu), // replace with your drawer icon
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.person, color: primary),
                            InkWell(
                              onTap: () async {
                                final newStatus = !_isOnline;
                                final confirm = await _showStatusChangeDialog(context, newStatus);
                                if (confirm == true) {
                                  setState(() => _isOnline = newStatus);
                                  // Optionally update status to Firestore
                                }
                              },
                              child: Container(
                                width: 97,
                                padding: EdgeInsets.symmetric(vertical: 7).copyWith(
                                  right: !_isOnline ? 10 : 6,
                                  left: !_isOnline ? 6 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _isOnline ? Colors.green.shade50 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!_isOnline)
                                      Container(
                                        height: 20,
                                        width: 20,
                                        margin: const EdgeInsets.only(right: 11),
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white),
                                        ),
                                      ),
                                    Text(_isOnline ? "Online" : "Offline", style: TextStyle(color: primary)),
                                    if (_isOnline)
                                      Container(
                                        height: 20,
                                        width: 18,
                                        margin: const EdgeInsets.only(left: 11),
                                        decoration: BoxDecoration(
                                          color: primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white),
                                        ),
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
                        if (_isOnline)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: _vehicleData?['vehiclePhotoUrl'] != null
                                      ? NetworkImage(_vehicleData!['vehiclePhotoUrl'])
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _vehicleData == null
                                      ? const Text('No assigned vehicle', style: TextStyle(color: Colors.grey))
                                      : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _vehicleData!['vehicleType'] ?? 'Vehicle',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _vehicleData!['vehicleNumber'] ?? '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600, color: primary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_vehicleData!['vehicleCategory'] ?? '',
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text('Completed Jobs',
                                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                                    SizedBox(height: 4),
                                    Text('0',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: primary)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    const Text('Status', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isOnline ? 'Available' : 'Not Available',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _isOnline ? Colors.green : Colors.red,
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showStatusChangeDialog(BuildContext context, bool newStatus) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Status"),
        content: Text("Are you sure you want to go ${newStatus ? 'Online' : 'Offline'}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );
  }
}
