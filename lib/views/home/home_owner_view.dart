import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vandizone_caption/helper/ui_helper.dart';
import 'package:vandizone_caption/routes/routes.dart';
import 'package:vandizone_caption/widgets/my_elevated_button.dart';
import 'package:sizer/sizer.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../utils/icon_size.dart';
import '../drawer/drawer_view.dart';
import '../../models/vehicleList.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeOwnerView extends StatefulWidget {
  const HomeOwnerView({super.key});

  @override
  State<HomeOwnerView> createState() => _HomeOwnerViewState();
}

class _HomeOwnerViewState extends State<HomeOwnerView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<String> _getCurrentOwnerUserCode() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Query owners collection where uid matches current user's uid
      final querySnapshot = await FirebaseFirestore.instance
          .collection('owners')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Owner document not found');
      }

      final ownerData = querySnapshot.docs.first.data();
      final userCode = ownerData['userCode'] as String?;

      if (userCode == null || userCode.isEmpty) {
        throw Exception('userCode not found in owner document');
      }

      return userCode;
    } catch (e) {
      print('Error getting owner userCode: $e');
      rethrow; // Rethrow to handle in the calling function
    }
  }

  Future<int> _getOwnerVehicleCount() async {
    try {
      // Get current owner's code (you'll need to implement how you get this)
      String ownerCode = await _getCurrentOwnerUserCode();

      // Query BHL vehicles
      var bhlQuery = FirebaseFirestore.instance
          .collection('bhl')
          .where('ownerCode', isEqualTo: ownerCode);

      // Query trucks
      var trucksQuery = FirebaseFirestore.instance
          .collection('trucks')
          .where('ownerCode', isEqualTo: ownerCode);

      // Execute both queries in parallel
      var results = await Future.wait([
        bhlQuery.get(),
        trucksQuery.get(),
      ]);

      // Sum the counts from both collections
      int bhlCount = results[0].size;
      int trucksCount = results[1].size;

      return bhlCount + trucksCount;
    } catch (e) {
      print('Error getting vehicle count: $e');
      return 0; // or rethrow if you want to handle the error in the FutureBuilder
    }
  }

  Future<int> _getActiveCaptainsCount() async {
    try {
      // Get current owner's user code
      String ownerUserCode = await _getCurrentOwnerUserCode();

      // Query my_captains collection
      var query = FirebaseFirestore.instance
          .collection('my_captains')
          .where('ownerUserCode', isEqualTo: ownerUserCode);

      // If you have an 'isActive' field, add this filter
      // .where('isActive', isEqualTo: true);

      var querySnapshot = await query.get();

      return querySnapshot.size;
    } catch (e) {
      print('Error getting captains count: $e');
      return 0; // or rethrow if you want to handle the error in the FutureBuilder
    }
  }

  Future<int> _getAvailableVehiclesCount() async {
    try {
      final ownerUserCode = await _getCurrentOwnerUserCode();

      // Query for available BHL vehicles (status = 0)
      final bhlAvailable = await FirebaseFirestore.instance
          .collection('bhl')
          .where('ownerCode', isEqualTo: ownerUserCode)
          .where('status', isEqualTo: 0)
          .get();

      // Query for available trucks (status = 0)
      final trucksAvailable = await FirebaseFirestore.instance
          .collection('trucks')
          .where('ownerCode', isEqualTo: ownerUserCode)
          .where('status', isEqualTo: 0)
          .get();

      return bhlAvailable.size + trucksAvailable.size;
    } catch (e) {
      print('Error getting available vehicles count: $e');
      return 0;
    }
  }

  Future<int> _getBookedVehiclesCount() async {
    try {
      final ownerUserCode = await _getCurrentOwnerUserCode();

      // Query for booked BHL vehicles (status != 0)
      final bhlBooked = await FirebaseFirestore.instance
          .collection('bhl')
          .where('ownerCode', isEqualTo: ownerUserCode)
          .where('status', isNotEqualTo: 0)
          .get();

      // Query for booked trucks (status != 0)
      final trucksBooked = await FirebaseFirestore.instance
          .collection('trucks')
          .where('ownerCode', isEqualTo: ownerUserCode)
          .where('status', isNotEqualTo: 0)
          .get();

      return bhlBooked.size + trucksBooked.size;
    } catch (e) {
      print('Error getting booked vehicles count: $e');
      return 0;
    }
  }

  Future<List<Vehicle>> _getLastThreeVehicles() async {
    try {
      final ownerUserCode = await _getCurrentOwnerUserCode();

      final [bhlSnapshot, trucksSnapshot] = await Future.wait([
        FirebaseFirestore.instance
            .collection('bhl')
            .where('ownerCode', isEqualTo: ownerUserCode)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
        FirebaseFirestore.instance
            .collection('trucks')
            .where('ownerCode', isEqualTo: ownerUserCode)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
      ]);

      List<Vehicle> bhlVehicles = bhlSnapshot.docs.map((doc) {
        final data = doc.data();
        return Vehicle(
          id: doc.id,
          make: data['make']?.toString() ?? '',
          licensePlate: data['vehicleNumber']?.toString() ?? '',
          model: data['makeModel']?.toString() ?? '',
          color: data['color']?.toString() ?? '',
          year: data['year'] is int ? data['year'] : int.tryParse(data['year']?.toString() ?? '0') ?? 0,
          vehicleType: data['vehicleType']?.toString() ?? '',
          vehicleCategory: data['vehicleCategory']?.toString() ?? '',
          bodyType: data['bodyType']?.toString() ?? '',
          vehicleNumber: data['vehicleNumber']?.toString() ?? '',
          numberOfAxles: data['numberOfAxles']?.toString() ?? '',
          engineNumber: data['engineNumber']?.toString() ?? '',
          chassisNumber: data['chassisNumber']?.toString() ?? '',
          insuredValue: data['insuredValue']?.toString() ?? '',
          numberOfTyres: data['numberOfTyres']?.toString() ?? '',
          payload: data['payload']?.toString() ?? '',
          gcw: data['gcw']?.toString() ?? '',
          truckDimensions: data['truckDimensions']?.toString() ?? '',
          isActive: data['isActive'] ?? false,
          imageUrl: data['imageUrl']?.toString() ?? '',
          vehicleCode: data['vehicleCode']?.toString() ?? '',
          rcUrl: data['rcUrl']?.toString() ?? '',
          insuranceUrl: data['insuranceUrl']?.toString() ?? '',
          permitAccess: data['permitAccess']?.toString() ?? '',
          registeringDistrict: data['registeringDistrict']?.toString() ?? '',
          isTruck: false,
          isBackhoe: true,
        );
      }).toList();

      List<Vehicle> truckVehicles = trucksSnapshot.docs.map((doc) {
        final data = doc.data();
        return Vehicle(
          id: doc.id,
          make: data['make']?.toString() ?? '',
          licensePlate: data['vehicleNumber']?.toString() ?? '',
          model: data['makeModel']?.toString() ?? '',
          color: data['color']?.toString() ?? '',
          year: data['year'] is int ? data['year'] : int.tryParse(data['year']?.toString() ?? '0') ?? 0,
          vehicleType: data['vehicleType']?.toString() ?? '',
          vehicleCategory: data['vehicleCategory']?.toString() ?? '',
          bodyType: data['bodyType']?.toString() ?? '',
          vehicleNumber: data['vehicleNumber']?.toString() ?? '',
          numberOfAxles: data['numberOfAxles']?.toString() ?? '',
          engineNumber: data['engineNumber']?.toString() ?? '',
          chassisNumber: data['chassisNumber']?.toString() ?? '',
          insuredValue: data['insuredValue']?.toString() ?? '',
          numberOfTyres: data['numberOfTyres']?.toString() ?? '',
          payload: data['payload']?.toString() ?? '',
          gcw: data['gcw']?.toString() ?? '',
          truckDimensions: data['truckDimensions']?.toString() ?? '',
          isActive: data['isActive'] ?? false,
          imageUrl: data['imageUrl']?.toString() ?? '',
          vehicleCode: data['vehicleCode']?.toString() ?? '',
          rcUrl: data['rcUrl']?.toString() ?? '',
          insuranceUrl: data['insuranceUrl']?.toString() ?? '',
          permitAccess: data['permitAccess']?.toString() ?? '',
          registeringDistrict: data['registeringDistrict']?.toString() ?? '',
          isTruck: true,
          isBackhoe: false,
        );
      }).toList();

      // Combine and return top 3
      return [...bhlVehicles, ...truckVehicles].take(3).toList();
    } catch (e) {
      print('Error getting last 3 vehicles: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const DrawerView(),
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar Section
          SliverAppBar(
            expandedHeight: 25.h,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Gap(60),
                        Text(
                          'Welcome, Owner!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manage your fleet efficiently',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stats Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                children: [
                  // Stats Row 1
                  Row(
                    children: [
                      FutureBuilder(
                        future: _getOwnerVehicleCount(),
                        builder: (context, snapshot) {
                          return _buildStatCard(
                            icon: Icons.directions_car,
                            title: 'Total Vehicles',
                            value: snapshot.data.toString(),
                            color: Colors.blueAccent,
                          );
                        },
                      ),
                      const Gap(15),
                      FutureBuilder(
                        future: _getActiveCaptainsCount(),
                        builder: (context, snapshot) {
                          return _buildStatCard(
                            icon: Icons.person,
                            title: 'Active Captains',
                            value: snapshot.data.toString(),
                            color: Colors.green,
                          );
                        },
                      ),
                    ],
                  ),
                  const Gap(15),
                  // Stats Row 2
                  Row(
                    children: [
                      FutureBuilder(
                        future: _getAvailableVehiclesCount(),
                        builder: (context, snapshot) {
                          return _buildStatCard(
                            icon: Icons.event_busy,
                            title: 'Available Vehicles',
                            value: snapshot.data.toString(),
                            color: Colors.purple,
                          );
                        },
                      ),
                      const Gap(15),
                      FutureBuilder(
                        future: _getBookedVehiclesCount(),
                        builder: (context, snapshot) {
                          return _buildStatCard(
                            icon: Icons.event_available,
                            title: 'Booked Vehicles',
                            value: snapshot.data.toString(),
                            color: Colors.orange,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Vehicles List Section
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vehicles List',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.vehicleList),
                    child: Row(
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            color: primary,
                            fontSize: 16.sp,
                          ),
                        ),
                        const Gap(5),
                        Icon(Icons.arrow_forward_ios, size: 12.sp, color: primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vehicles List
          // Replace your _vehicles.isEmpty check with this:
          FutureBuilder<List<Vehicle>>(
            future: _getLastThreeVehicles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car, size: 50.sp, color: Colors.grey[300]),
                        const Gap(20),
                        Text(
                          snapshot.hasError ? 'Error loading vehicles' : 'No vehicles added yet',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey,
                          ),
                        ),
                        const Gap(10),
                        ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, Routes.vehicleList),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          ),
                          child: Text(
                            'Add Vehicle',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final vehicle = snapshot.data![index];
                    return _buildVehicleCard(vehicle, index);
                  },
                  childCount: snapshot.data!.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18.sp),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Gap(10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle, int index) {
    return GestureDetector(
      onTap:(){
        Navigator.pushNamed(context, Routes.vehicleList);
      },
      child: Padding(
        padding: const EdgeInsets.only(left:20.0, right:20.0),
        child: Container(
          margin: EdgeInsets.only(bottom: 15, top: index == 0 ? 10 : 0),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: primary,
                      size: 20.sp,
                    ),
                  ),
                  const Gap(15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehicle.vehicleType}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Text(
                        //   '${vehicle.year} • ${vehicle.color}',
                        //   style: TextStyle(
                        //     fontSize: 12.sp,
                        //     color: Colors.grey[600],
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Text(
                    '${vehicle.chassisNumber}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width:70),
                  Chip(
                    backgroundColor: index % 2 == 0 ? Colors.green[100] : Colors.blue[100],
                    label: Text(
                      index % 2 == 0 ? 'Available' : 'In Service',
                      style: TextStyle(
                        color: index % 2 == 0 ? Colors.green : Colors.blue,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(15),
              const Divider(height: 1, color: Colors.grey),
              const Gap(15),
              // Vehicle Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem('Plate', vehicle.licensePlate),
                  _buildDetailItem('Model', vehicle.model),
                  _buildDetailItem('Category', vehicle.vehicleCategory),
                ],
              ),
              const Gap(15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
        const Gap(5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}