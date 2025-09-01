// import 'package:flutter/material.dart';
// import 'package:gap/gap.dart';
// import 'package:sizer/sizer.dart';
// import '../../../utils/assets.dart';
// import '../../../utils/icon_size.dart';
// import '../../../utils/constant.dart';
// import '../../../components/my_appbar.dart';
// import 'package:vandizone_caption/models/booking.dart';
//
// class BookingDetailsView extends StatelessWidget {
//   final Booking booking; // ✅ Make sure this is a Booking type
//
//   const BookingDetailsView({Key? key, required this.booking}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     int selectedTab = 0;
//     return Scaffold(
//       appBar: MyAppBar(title: 'Booking Details'),
//       body: SingleChildScrollView(
//         physics: const BouncingScrollPhysics(),
//         padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 8.sp),
//         child: Column(
//           children: [
//             // Main Card Container
//             Container(
//               decoration: BoxDecoration(
//                 color: white,
//                 borderRadius: myBorderRadius(10),
//                 boxShadow: [boxShadow1],
//               ),
//               child: Padding(
//                 padding: EdgeInsets.all(16.sp),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Status and Quick Actions
//                     _buildStatusHeader(context),
//                     Gap(20.sp),
//
//                     // Customer Details Section
//                     _buildSection(
//                       title: 'Customer Details',
//                       icon: Icons.person_outline,
//                       children: [
//                         _buildDetailRow(
//                           label: 'Name',
//                           value: booking.customerName ,
//                         ),
//                         _buildDetailRow(
//                           label: 'Phone',
//                           value: booking['customerPhone'],
//                           isPhone: true,
//                         ),
//                       ],
//                     ),
//                     Divider(),
//                     // Booking Details Section
//                     _buildSection(
//                       title: 'Booking Details',
//                       icon: Icons.calendar_today_outlined,
//                       children: [
//                         _buildDetailRow(
//                           label: 'Date',
//                           value: booking['bookingDate'],
//                         ),
//                         _buildDetailRow(
//                           label: 'Time',
//                           value: '10:30 AM',
//                         ),
//                         _buildDetailRow(
//                           label: 'Payment Mode',
//                           value: 'Online',
//                         ),
//                         Gap(12.sp),
//                         Divider(),
//                         _buildLocationJourney(
//                           from: booking['fromLocation'],
//                           to: booking['toLocation'],
//                         ),
//                       ],
//                     ),
//                     Divider(),
//                     // Vehicle Details Section
//                     _buildSection(
//                       title: 'Vehicle Details',
//                       icon: Icons.directions_car_outlined,
//                       children: [
//                         _buildDetailRow(
//                           label: 'Vehicle Number',
//                           value: booking['vehicleNumber'],
//                         ),
//                         _buildDetailRow(
//                           label: 'Vehicle Type',
//                           value: 'Truck',
//                         ),
//                         _buildDetailRow(
//                           label: 'Make & Model',
//                           value: 'Tata Prima 5530.S',
//                         ),
//                         _buildDetailRow(
//                           label: 'Capacity',
//                           value: '15 Tons',
//                         ),
//                       ],
//                     ),
//                     Divider(),
//                     // Captain Details Section
//                     _buildSection(
//                       title: 'Captain Details',
//                       icon: Icons.person_outline,
//                       children: [
//                         _buildDetailRow(
//                           label: 'Name',
//                           value: booking['captainName'],
//                         ),
//                         _buildDetailRow(
//                           label: 'ID',
//                           value: booking['captainId'],
//                         ),
//                         _buildDetailRow(
//                           label: 'Phone',
//                           value: '9876543210',
//                           isPhone: true,
//                         ),
//                         _buildDetailRow(
//                           label: 'Experience',
//                           value: '5 Years',
//                         ),
//                       ],
//                     ),
//                     Divider(),
//                     // Owner Details Section
//                     _buildSection(
//                       title: 'Owner Details',
//                       icon: Icons.business_outlined,
//                       children: [
//                         _buildDetailRow(
//                           label: 'Name',
//                           value: 'Ramesh Kumar',
//                         ),
//                         _buildDetailRow(
//                           label: 'Phone',
//                           value: '8765432109',
//                           isPhone: true,
//                         ),
//                         _buildDetailRow(
//                           label: 'Address',
//                           value: 'Bangalore, Karnataka',
//                           isMultiline: true,
//                         ),
//                       ],
//                     ),
//                     Divider(),
//                     // Charges & Tax Section
//                     _buildSection(
//                       title: 'Payment Breakdown',
//                       icon: Icons.receipt_outlined,
//                       children: [
//                         _buildPaymentRow('Base Fare', '₹5,000'),
//                         _buildPaymentRow('Distance Charge', '₹2,500'),
//                         _buildPaymentRow('Waiting Charges', '₹500'),
//                         _buildPaymentRow('Toll Tax', '₹350'),
//                         _buildPaymentRow('GST (18%)', '₹1,530'),
//                         Divider(height: 24.sp, thickness: 0.5.sp),
//                         _buildPaymentRow(
//                           'Total Amount',
//                           '₹9,880',
//                           isTotal: true,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             // Custom Tab Row
//             Gap(16.sp),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: List.generate(3, (index) {
//                 final titles = [ 'Vehicle', 'Captain','Customer'];
//                 final isSelected = selectedTab == index;
//                 return Expanded(
//                   child: GestureDetector(
//                     onTap: () {
//                         selectedTab = index;
//                     },
//                     child: Card(
//                       color: isSelected ? primary : Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Padding(
//                         padding: EdgeInsets.symmetric(vertical: 10.sp),
//                         child: Center(
//                           child: Text(
//                             titles[index],
//                             style: blackRegular16.copyWith(
//                               color: isSelected ? Colors.white : Colors.black,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }),
//             ),
//             Gap(12.sp),
//
// // Show selected review
//             Container(
//               decoration: BoxDecoration(
//                 color: white,
//                 borderRadius: BorderRadius.circular(10),
//                 boxShadow: [boxShadow1],
//               ),
//               child: Padding(
//                 padding: EdgeInsets.all(16.sp),
//                 child: Builder(
//                   builder: (context) {
//                     switch (selectedTab) {
//                       case 0:
//                         return _buildCaptainReviewTab();
//                       case 1:
//                         return _buildVehicleReviewTab();
//                       case 2:
//                         return _buildCustomerReviewTab();
//                       default:
//                         return SizedBox();
//                     }
//                   },
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatusHeader(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 10.sp),
//       decoration: BoxDecoration(
//         color: _getStatusColor(booking['status']).withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8.sp),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             _getStatusIcon(booking['status']),
//             size: 18.sp,
//             color: _getStatusColor(booking['status']),
//           ),
//           Gap(12.sp),
//           Expanded(
//             child: Text(
//               booking['status'].toUpperCase(),
//               style: blackRegular16.copyWith(
//                 color: _getStatusColor(booking['status']),
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSection({
//     required String title,
//     required IconData icon,
//     required List<Widget> children,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Gap(12.sp),
//         Row(
//           children: [
//             Icon(icon, size: 18.sp, color: primary),
//             Gap(8.sp),
//             Text(
//               title,
//               style: blackRegular16.copyWith(
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey[800],
//               ),
//             ),
//           ],
//         ),
//         Gap(12.sp),
//         ...children,
//         Gap(12.sp),
//         Divider(
//           height: 1.sp,
//           thickness: 1.sp,
//           color: Colors.grey[200],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDetailRow({
//     required String label,
//     required String value,
//     bool isPhone = false,
//     bool isMultiline = false,
//   }) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 8.sp),
//       child: Row(
//         crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
//         children: [
//           SizedBox(
//             width: 30.w,
//             child: Text(
//               label,
//               style: blackRegular16.copyWith(
//                 color: Colors.grey[600],
//               ),
//             ),
//           ),
//           Gap(8.sp),
//           Expanded(
//             child: isPhone
//                 ? InkWell(
//               onTap: () => _makePhoneCall(value),
//               child: Text(
//                 value,
//                 style: blackRegular16.copyWith(
//                   fontWeight: FontWeight.w500,
//                   color: Colors.blue,
//                 ),
//               ),
//             )
//                 : Text(
//               value,
//               style: blackRegular16.copyWith(
//                 fontWeight: FontWeight.w500,
//               ),
//               maxLines: isMultiline ? 2 : 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPaymentRow(String label, String value, {bool isTotal = false}) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 6.sp),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: blackRegular16.copyWith(
//               color: isTotal ? Colors.grey[800] : Colors.grey[600],
//               fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
//             ),
//           ),
//           Text(
//             value,
//             style: blackRegular16.copyWith(
//               color: isTotal ? primary : Colors.grey[800],
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLocationJourney({required String from, required String to}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Image.asset(AssetImages.fromaddress, height: IconSize.regular),
//             Gap(5),
//             Text(from, style: blackRegular16),
//           ],
//         ),
//         Padding(
//           padding: const EdgeInsets.only(left: 10, top: 5),
//           child: Column(
//             children: List.generate(
//                 3, (index) => Text("\u2022", style: blackRegular16.copyWith(height: 0.5))),
//           ),
//         ),
//         Row(
//           children: [
//             Image.asset(AssetImages.toaddress, height: IconSize.regular),
//             Gap(5),
//             Text(to, style: blackRegular16),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildCaptainReviewTab() {
//     return _buildReviewCard(
//       reviewList: [
//         {'name': 'John Smith', 'date': '5/15/2023', 'message': 'Excellent service! Very professional captain.', 'rating': 5},
//       ],
//     );
//   }
//
//   Widget _buildVehicleReviewTab() {
//     return _buildReviewCard(
//       reviewList: [
//         {'name': 'Sarah Wilson', 'date': '5/22/2023', 'message': 'Comfortable and well-maintained boat.', 'rating': 4},
//       ],
//     );
//   }
//
//   Widget _buildCustomerReviewTab() {
//     return _buildReviewCard(
//       reviewList: [
//         {'name': 'John Smith', 'date': '5/15/2023', 'message': 'Excellent service! Very professional captain.', 'rating': 5},
//       ],
//     );
//   }
//   Widget _buildReviewCard({
//     required List<Map<String, dynamic>> reviewList,
//   }) {
//     return Padding(
//       padding: EdgeInsets.all(12.sp),
//       child: ListView.separated(
//         shrinkWrap: true,
//         physics: NeverScrollableScrollPhysics(),
//         itemCount: reviewList.length,
//         separatorBuilder: (_, __) => Divider(),
//         itemBuilder: (context, index) {
//           final review = reviewList[index];
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(review['name'], style: blackMedium16),
//               Text(review['date'], style: blackRegular16),
//               Text(review['message'], style: blackRegular16),
//               Row(
//                 children: List.generate(5, (i) {
//                   return Icon(
//                     i < review['rating']
//                         ? Icons.star
//                         : Icons.star_border,
//                     size: 14,
//                     color: Colors.amber,
//                   );
//                 }),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Color _getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'in progress':
//         return Colors.orange;
//       case 'completed':
//         return Colors.green;
//       case 'cancelled':
//         return Colors.red;
//       default:
//         return Colors.blue;
//     }
//   }
//
//   IconData _getStatusIcon(String status) {
//     switch (status.toLowerCase()) {
//       case 'in progress':
//         return Icons.access_time;
//       case 'completed':
//         return Icons.check_circle;
//       case 'cancelled':
//         return Icons.cancel;
//       default:
//         return Icons.info;
//     }
//   }
//
//   void _makePhoneCall(String phoneNumber) {
//     // Implement phone call functionality
//   }
// }