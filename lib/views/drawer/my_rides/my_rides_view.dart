import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';
import '../../../routes/routes.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';

class Rides {
  final String id;
  final String profilePic;
  final String carName;
  final String price;
  final String from;
  final String to;
  final String paymentType;
  final String date;
  final int status;
  final String customerFare;
  final String fuelCost;
  final String tollCost;
  final String commission;
  final String wages;
  final String grossProfit;
  final String vehicleType; // Added to distinguish between Truck and BHL

  Rides({
    required this.id,
    required this.profilePic,
    required this.carName,
    required this.price,
    required this.from,
    required this.to,
    required this.paymentType,
    required this.date,
    required this.status,
    required this.customerFare,
    required this.fuelCost,
    required this.tollCost,
    required this.commission,
    required this.wages,
    required this.grossProfit,
    required this.vehicleType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Rides && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MyRidesView extends StatefulWidget {
  const MyRidesView({super.key});

  @override
  State<MyRidesView> createState() => _MyRidesViewState();
}

class _MyRidesViewState extends State<MyRidesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Separated lists for different categories
  List<Rides> _allRideList = [];
  List<Rides> _truckRideList = [];
  List<Rides> _bhlRideList = [];
  List<Rides> _inProgressRideList = [];
  List<Rides> _upComingRideList = [];
  List<Rides> _pastRideList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // Changed to 6 tabs
    _loadBookings().then((_) {
      _printAllData();
    });
  }

  void _printAllData() {
    print('===== ALL RIDES =====');
    _printRideList(_allRideList);

    print('\n===== TRUCK RIDES =====');
    _printRideList(_truckRideList);

    print('\n===== BHL RIDES =====');
    _printRideList(_bhlRideList);

    print('\n===== IN PROGRESS RIDES =====');
    _printRideList(_inProgressRideList);

    print('\n===== UPCOMING RIDES =====');
    _printRideList(_upComingRideList);

    print('\n===== PAST RIDES =====');
    _printRideList(_pastRideList);
  }

  void _printRideList(List<Rides> rides) {
    if (rides.isEmpty) {
      print('No rides found');
      return;
    }

    for (var ride in rides) {
      print('''
ID: ${ride.id}
Vehicle Type: ${ride.vehicleType}
Vehicle: ${ride.carName}
From: ${ride.from}
To: ${ride.to}
Price: ${ride.price}
Payment: ${ride.paymentType}
Date: ${ride.date}
Status: ${ride.status}
Customer Fare: ${ride.customerFare}
Fuel Cost: ${ride.fuelCost}
Toll Cost: ${ride.tollCost}
Commission: ${ride.commission}
Wages: ${ride.wages}
Gross Profit: ${ride.grossProfit}
-----------------------------
''');
    }
  }

  Future<void> _loadBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('Loading bookings for captain: ${user.uid}');

      final userSnapshot = await _firestore.collection('captains')
          .doc(user.uid)
          .get();

      final userCode = userSnapshot.data()?['userCode'] ?? '';

      if (userCode.isEmpty) return;

      final bhlQuery = await _firestore
          .collection('bhl_bookings')
          .where('assignedCaptainId', isEqualTo: userCode)
          .get();

      final truckQuery = await _firestore
          .collection('truck_bookings')
          .where('assignedCaptainId', isEqualTo: userCode)
          .get();

      List<Rides> allBookings = [];

      // Process BHL bookings
      for (var doc in bhlQuery.docs) {
        print('BHL Booking Data: ${doc.data()}');
        final data = doc.data();
        allBookings.add(_mapBookingToRide(data, 'BHL'));
      }

      // Process Truck bookings
      for (var doc in truckQuery.docs) {
        print('Truck Booking Data: ${doc.data()}');
        final data = doc.data();
        allBookings.add(_mapBookingToRide(data, 'Truck'));
      }

      print('Total bookings found: ${allBookings.length}');

      // Sort by date (newest first)
      allBookings.sort((a, b) => b.date.compareTo(a.date));

      // Categorize bookings
      setState(() {
        _allRideList = allBookings;

        // Separate by vehicle type
        _truckRideList = allBookings
            .where((ride) => ride.vehicleType == 'Truck')
            .toList();
        _bhlRideList = allBookings
            .where((ride) => ride.vehicleType == 'BHL')
            .toList();

        // Separate by status
        _inProgressRideList = allBookings
            .where((ride) => ride.status == 4 || ride.status == 8)
            .toList();
        _upComingRideList = allBookings
            .where((ride) => ride.status == 2 || ride.status == 3)
            .toList();
        _pastRideList = allBookings.where((ride) => ride.status == 5).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Rides _mapBookingToRide(Map<String, dynamic> data, String vehicleType) {
    try {
      // Extract vehicle details
      final vehicleDetails =
          data['vehicleDetails'] as Map<String, dynamic>? ?? {};
      final assignCaptains =
          vehicleDetails['assignCaptains'] as List<dynamic>? ?? [];

      // Determine vehicle name based on type
      String vehicleName;
      String profilePic;
      if (vehicleType == 'BHL') {
        vehicleName =
            vehicleDetails['vehicleType']?.toString() ?? 'Backhoe Loader';
        profilePic = AssetImages.pastride2; // BHL icon
      } else {
        vehicleName = vehicleDetails['makeModel']?.toString() ?? 'Truck';
        profilePic = AssetImages.pastride1; // Truck icon
      }

      // Calculate financials - ensure all values are numbers
      final fare = (data['fare'] ?? 0).toDouble();
      final fuelCost = (data['fuelCost'] ?? 0).toDouble();
      final tollCost = (data['tollCost'] ?? 0).toDouble();
      final commission = (data['commission'] ?? 0).toDouble();
      final wages = (data['wages'] ?? 0).toDouble();
      final grossProfit = fare - (fuelCost + tollCost + commission + wages);

      // Handle location data
      final fromLocation = data['fromLocation'] as Map<String, dynamic>? ?? {};
      final toLocation = data['toLocation'] as Map<String, dynamic>? ?? {};

      return Rides(
        id: data['bookingCode']?.toString() ?? 'N/A',
        profilePic: profilePic,
        carName: vehicleName,
        price: "₹${fare.toStringAsFixed(2)}",
        from: fromLocation['address']?.toString() ?? 'Unknown location',
        to: toLocation['address']?.toString() ?? 'Unknown location',
        paymentType: _getPaymentType(data['paymentMethod']?.toString()),
        date: _formatDate(data['createdAt']),
        status: (data['status'] as int?) ?? 0,
        customerFare: "₹${fare.toStringAsFixed(2)}",
        fuelCost: "₹${fuelCost.toStringAsFixed(2)}",
        tollCost: "₹${tollCost.toStringAsFixed(2)}",
        commission: "₹${commission.toStringAsFixed(2)}",
        wages: "₹${wages.toStringAsFixed(2)}",
        grossProfit: "₹${grossProfit.toStringAsFixed(2)}",
        vehicleType: vehicleType, // Store the vehicle type
      );
    } catch (e) {
      print('Error mapping booking to ride: $e');
      // Return a default ride with error information
      return Rides(
        id: 'error',
        profilePic: AssetImages.pastride1,
        carName: 'Error',
        price: "₹0.00",
        from: 'Error',
        to: 'Error',
        paymentType: 'Cash',
        date: 'Error date',
        status: 0,
        customerFare: "₹0.00",
        fuelCost: "₹0.00",
        tollCost: "₹0.00",
        commission: "₹0.00",
        wages: "₹0.00",
        grossProfit: "₹0.00",
        vehicleType: vehicleType,
      );
    }
  }

  String _getPaymentType(String? method) {
    switch (method?.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'card':
        return 'Card';
      case 'gpay':
        return 'GPay';
      case 'phonepay':
        return 'PhonePe';
      default:
        return 'Cash';
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return 'Unknown date';

      Timestamp timestamp;
      if (date is Timestamp) {
        timestamp = date;
      } else if (date is DateTime) {
        return '${date.day}/${date.month}/${date.year} | ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return 'Invalid date format';
      }

      final dateTime = timestamp.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} | ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Date error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: _isLoading ? _buildLoading() : _body(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Column _body() {
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: [
              _all(),
              // _trucks(),
              // _bhl(),
              _inProgress(),
              _upComingRides(),
              _pastRides()
            ],
          ),
        )
      ],
    );
  }

  Widget _all() {
    return _buildRidesList(_allRideList);
  }

  Widget _trucks() {
    return _buildRidesList(_truckRideList);
  }

  Widget _bhl() {
    return _buildRidesList(_bhlRideList);
  }

  Widget _inProgress() {
    return _buildRidesList(_inProgressRideList);
  }

  Widget _upComingRides() {
    return _buildRidesList(_upComingRideList);
  }

  Widget _pastRides() {
    return _buildRidesList(_pastRideList);
  }

  Widget _buildRidesList(List<Rides> rideList) {
    return rideList.isEmpty
        ? _buildEmptyState()
        : ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(20).copyWith(top: 25),
      itemBuilder: (context, index) {
        final item = rideList[index];
        return _buildRideItem(item);
      },
      separatorBuilder: (_, __) => const Gap(25),
      itemCount: rideList.length,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AssetImages.cancelride, height: 90),
            const Gap(25),
            Text('No Any Booked Rides', style: colorABMedium20)
          ],
        ),
      ),
    );
  }

  Widget _buildRideItem(Rides item) {
    return InkWell(
      onTap: () {
        if (item.status == 4 || item.status == 8) {
          if (item.vehicleType == 'Truck') {
            Navigator.pushNamed(context, Routes.rideTrackingTruck);
          } else {
            Navigator.pushNamed(context, Routes.rideTracking); // Assuming this is for BHL
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: white,
          boxShadow: [boxShadow1],
          borderRadius: myBorderRadius(10),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Image.asset(item.profilePic, height: 40, width: 40),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(item.id, style: blackRegular18),
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.vehicleType == 'Truck' ? Colors.blue.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.vehicleType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: item.vehicleType == 'Truck' ? Colors.blue.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(2),
                        Text(item.carName, style: colorABRegular16)
                      ],
                    ),
                  ),
                  Text(item.grossProfit, style: primaryMedium18)
                ],
              ),
            ),
            Divider(height: 0, color: colorF2, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(AssetImages.fromaddress,
                          height: IconSize.regular),
                      const Gap(5),
                      Expanded(child: Text(item.from, style: blackRegular16)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 5),
                    child: Column(
                      children: List.generate(
                          3,
                              (index) => Text("\u2022",
                              style: blackRegular16.copyWith(height: 0.5))),
                    ),
                  ),
                  Row(
                    children: [
                      Image.asset(AssetImages.toaddress,
                          height: IconSize.regular),
                      const Gap(5),
                      Expanded(child: Text(item.to, style: blackRegular16)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 0, color: colorF2, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment', style: blackRegular16),
                      Text(item.paymentType, style: colorABRegular16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Customer Fare:", style: blackRegular16),
                      Text(item.customerFare, style: colorABRegular16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Fuel Cost", style: blackRegular16),
                      Text(item.fuelCost, style: colorABRegular16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Toll Cost:", style: blackRegular16),
                      Text(item.tollCost, style: colorABRegular16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Commission:", style: blackRegular16),
                      Text(item.commission, style: colorABRegular16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Wages:", style: blackRegular16),
                      Text(item.wages, style: colorABRegular16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Gross Profit:", style: blackRegular16),
                      Text(item.grossProfit, style: colorABRegular16),
                    ],
                  ),
                  const Gap(10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date Time', style: blackRegular16),
                      Text(item.date, style: colorABRegular16),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: white,
      elevation: 0,
      toolbarHeight: kToolbarHeight + 50,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
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
                  const Gap(15),
                  Text('My Jobs', style: blackMedium20)
                ],
              ),
              const Gap(12),
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 100.w,
                      height: 2,
                      color: colorF2,
                    ),
                    TabBar(
                      isScrollable: true, // Made scrollable to fit all tabs
                      labelStyle: primaryMedium18.copyWith(fontSize: 12),
                      unselectedLabelStyle:
                      primaryMedium18.copyWith(fontSize: 12),
                      indicatorWeight: 4,
                      unselectedLabelColor: primary.withAlpha(102),
                      controller: _tabController,
                      onTap: (v) => setState(() => _tabController.index = v),
                      tabs: const [
                        Tab(text: 'All'),
                        // Tab(text: 'Trucks'),
                        // Tab(text: 'BHL'),
                        Tab(text: 'Inprogress'),
                        Tab(text: 'Upcoming'),
                        Tab(text: 'Completed'),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}