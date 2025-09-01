import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sizer/sizer.dart';
import '../../../utils/assets.dart';
import '../../../utils/icon_size.dart';
import 'booking_details.dart';
import '../../../models/booking.dart';

class BookingListView extends StatefulWidget {
  const BookingListView({super.key});

  @override
  State<BookingListView> createState() => _BookingListViewState();
}

class _BookingListViewState extends State<BookingListView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Booking> _allBookings = [];
  bool _isLoading = true;
  String? _error;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    print("🚀 _loadBookings() called");
    try {
      final ownerId = _auth.currentUser?.uid;
      print("👤 Owner ID: $ownerId");

      if (ownerId == null) {
        print("❌ Owner ID is null. Exiting.");
        return;
      }

// 🔍 Fetch current owner's document
      final ownerDoc = await _firestore.collection('owners').doc(ownerId).get();

      if (!ownerDoc.exists) {
        print("❌ Owner document not found.");
        return;
      }

      final ownerData = ownerDoc.data();
      final ownerUserCode = ownerData?['userCode'];
      print("🆔 Logged-in Owner's userCode: $ownerUserCode");

      if (ownerUserCode == null) {
        print("❌ No userCode found in owner document.");
        return;
      }

// ✅ Fetch bookings based on ownerUserCode
      final bhlBookings = await _getOwnerBookingsFromCollection('bhl_bookings', ownerUserCode);
      final truckBookings = await _getOwnerBookingsFromCollection('truck_bookings', ownerUserCode);

      setState(() {
        _allBookings = [...bhlBookings, ...truckBookings];
        _isLoading = false;
      });

      print("🎯 All bookings loaded and set in state.");
    } catch (e) {
      print("❌ Error during booking load: $e");
      setState(() {
        _error = 'Failed to load bookings: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<Booking>> _getOwnerBookingsFromCollection(String collectionName, String ownerUserCode) async {
    final querySnapshot = await _firestore
        .collection(collectionName)
        .where('ownerDetails.userCode', isEqualTo: ownerUserCode)
        .where('status', whereIn: [4, 5, 6]) // You can adjust statuses as needed
        .orderBy('createdAt', descending: true)
        .get();

    print("📄 [$collectionName] Owner bookings fetched: ${querySnapshot.docs.length}");

    return querySnapshot.docs.map((doc) {
      final bookingData = doc.data();
      return Booking.fromMap(bookingData, doc.id);
    }).toList();
  }

  Future<List<Booking>> _getBookingsFromCollection(String collectionName, String captainUserCode) async {
    final querySnapshot = await _firestore
        .collection(collectionName)
        .where('assignedCaptainId', isEqualTo: captainUserCode)
        .where('status', whereIn: [4, 5, 6]) // 4=In Progress, 5=Completed, 6=Cancelled
        .orderBy('createdAt', descending: true)
        .get();

    print("📄 [$collectionName] Bookings fetched: ${querySnapshot.docs.length}");

    return querySnapshot.docs.map((doc) {
      final bookingData = doc.data();
      return Booking.fromMap(bookingData, doc.id);
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: kToolbarHeight + 20,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                  ),
                ),
                const Gap(15),
                const Expanded(child: Text('Booking List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFF2ECC71),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList(_allBookings),
          _buildBookingList(_allBookings.where((b) => b.status == 4).toList()),
          _buildBookingList(_allBookings.where((b) => b.status == 5).toList()),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<Booking> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AssetImages.emptynotification, width: 50.w),
            const Gap(20),
            Text(
              'No bookings found',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(15),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return GestureDetector(
          onTap: () {
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => BookingDetailsView(booking: booking),
            //   ),
            // );
          },
          child: Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking #${booking.bookingCode}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            booking.serviceType ?? 'Service',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: booking.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: booking.statusColor),
                        ),
                        child: Text(
                          booking.statusText,
                          style: TextStyle(
                            color: booking.statusColor,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, thickness: 1),

                  // Vehicle and Captain Info
                  _buildInfoRow('Vehicle Number', booking.vehicleNumber ?? 'Not assigned'),
                  if (booking.captainName != null)
                    _buildInfoRow('Captain', '${booking.captainName} (${booking.captainId})'),


                  Divider(height: 20, thickness: 1),
                  Text('Customer Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  _buildInfoRow('Name', booking.customer?['name'] ?? 'Unknown'),
                  _buildInfoRow('Phone', booking.customer?['phone'] ?? 'Not provided'),

                  // Booking Details
                  Divider(height: 20, thickness: 1),
                  _buildLocationJourney(
                    from: booking.fromLocation?['address'] ?? 'Pickup location not specified',
                    to: booking.toLocation?['address'] ?? 'Destination not specified',
                    bookedOn: _formatDate(booking.createdAt),
                  ),

                  // Price and Payment Info
                  Divider(height: 20, thickness: 1),
                  _buildInfoRow('Total Fare', '₹${booking.fare?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildInfoRow('Payment Method', booking.paymentMethod ?? 'Cash on Delivery'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Date not available';
    final date = timestamp.toDate();
    return '${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]))),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationJourney({required String from, required String to, required String bookedOn}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // From Location
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Image.asset(AssetImages.fromaddress, height: IconSize.small),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                from,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),

        // Vertical dotted line
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
          child: Column(
            children: List.generate(
              3,
                  (index) => Text(
                "\u2022",
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 0.5,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ),
        ),

        // To Location
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Image.asset(AssetImages.toaddress, height: IconSize.small),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                to,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),

        const Gap(8),

        // Booking date
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey[600]),
            const Gap(8),
            Text(
              'Booked On: $bookedOn',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}