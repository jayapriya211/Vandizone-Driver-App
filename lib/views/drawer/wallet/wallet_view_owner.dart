import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../components/my_appbar.dart';
import '../../../routes/routes.dart';
import '../../../utils/constant.dart';
import '../../../widgets/my_elevated_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

import '../../../utils/assets.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _balance = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return DateTime.now();
    }
  }

  Future<void> _fetchWalletData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get wallet balance
      final walletDoc =
      await _firestore.collection('owner_wallets').doc(userId).get();

      if (walletDoc.exists) {
        setState(() {
          _balance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      setState(() {
        // _errorMessage = 'Failed to load wallet data: ${e.toString()}';
        print('Failed to load wallet data: ${e.toString()}');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: "Wallet"),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.all(20).copyWith(top: 5),
        children: [
          Center(
            child: _isLoading
                ? Shimmer.fromColors(
              baseColor: Colors.grey[100]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 209,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: myBorderRadius(10),
                  boxShadow: [boxShadow1],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 20,
                      color: Colors.white,
                    ),
                    Gap(10),
                    Container(
                      width: 100,
                      height: 30,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            )
                : Container(
              width: 209,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: white,
                borderRadius: myBorderRadius(10),
                boxShadow: [boxShadow1],
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: AssetImage(AssetImages.walletbg),
                ),
              ),
              child: Column(
                children: [
                  Text('Total Amount', style: colorABMedium20),
                  Gap(10),
                  Text('₹${_balance.toStringAsFixed(2)}',
                      style: primarySemiBold25),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25),
            child: Row(
              children: [
                Expanded(
                  child: MyElevatedButton(
                    isSecondary: true,
                    title: 'Send To Bank',
                    onPressed: () async {
                      await Navigator.pushNamed(context, Routes.sendToBankOwner);
                      _fetchWalletData(); // Refresh on return
                    },
                    textStyle: primarySemiBold18,
                  ),
                ),
                Gap(20),
                Expanded(
                  child: MyElevatedButton(
                    isSecondary: true,
                    title: 'Add Money',
                    textStyle: primarySemiBold18,
                    onPressed: () async {
                      await Navigator.pushNamed(context, Routes.addMoneyOwner);
                      _fetchWalletData(); // Refresh on return
                    },
                  ),
                ),
              ],
            ),
          ),
          Text('Recent Transactions', style: blackMedium18),
          Gap(20),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ),
          _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('owner_wallet_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerTransactions();
        }

        if (snapshot.hasError) {
          return Text(
            'Error loading transactions: ${snapshot.error}',
            style: TextStyle(color: Colors.red),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text('No transactions found', style: colorABRegular16);
        }

        final transactions = snapshot.data!.docs;

        return ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (_, __) =>
              Divider(height: 40, color: colorF2, thickness: 2),
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;
            final isCredit = data['type'] == 'credit';
            final amount = (data['amount'] as num).toDouble();
            final timestamp = _parseTimestamp(data['timestamp']);

            String title;
            if (isCredit) {
              title = "Added to wallet";
            } else if (data['type'] == 'withdrawal') {
              title = "Withdrawal request";
              if (data['status'] == 1) {
                title = "Withdrawal Approved";
              } else if (data['status'] == 2) {
                title = "Withdrawal Rejected";
              } else if (data['status'] == 3) {
                title = "Vandizone Charge";
              }
            } else {
              title = "Wallet Transaction";
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: primaryMedium17),
                      Gap(5),
                      Text(
                        _formatDateTime(timestamp),
                        style: colorABRegular16,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                  style: primaryMedium17.copyWith(
                    color: isCredit ? Color(0xff397646) : Color(0xffE41717),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerTransactions() {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: 7, // Show 5 shimmer items while loading
      separatorBuilder: (_, __) =>
          Divider(height: 40, color: colorF2, thickness: 2),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[100]!,
          highlightColor: Colors.grey[500]!,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 150,
                      height: 20,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 100,
                      height: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 80,
                  height: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget _buildTransactionList() {
  //   final userId = _auth.currentUser?.uid;
  //   if (userId == null) return SizedBox();
  //
  //   return StreamBuilder<QuerySnapshot>(
  //     stream: _firestore
  //         .collection('owner_wallet_transactions')
  //         .where('userId', isEqualTo: userId)
  //         .orderBy('timestamp', descending: true)
  //         .limit(20)
  //         .snapshots(),
  //     builder: (context, snapshot) {
  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return Center(child: CircularProgressIndicator());
  //       }
  //
  //       if (snapshot.hasError) {
  //         return Text(
  //           'Error loading transactions: ${snapshot.error}',
  //           style: TextStyle(color: Colors.red),
  //         );
  //       }
  //
  //       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
  //         return Text('No transactions found', style: colorABRegular16);
  //       }
  //
  //       final transactions = snapshot.data!.docs;
  //
  //       return ListView.separated(
  //         shrinkWrap: true,
  //         physics: NeverScrollableScrollPhysics(),
  //         itemCount: transactions.length,
  //         separatorBuilder: (_, __) => Divider(height: 40, color: colorF2, thickness: 2),
  //         itemBuilder: (context, index) {
  //           final doc = transactions[index];
  //           final data = doc.data() as Map<String, dynamic>;
  //           final isCredit = data['type'] == 'credit';
  //           final amount = (data['amount'] as num).toDouble();
  //           // final timestamp = (data['timestamp'] as Timestamp).toDate();
  //           final timestamp = _parseTimestamp(data['timestamp']);
  //
  //           String title;
  //           if (isCredit) {
  //             title = "Added to wallet";
  //           } else if (data['type'] == 'withdrawal') {
  //             title = "Withdrawal request";
  //           } else {
  //             title = "Payment for ride";
  //           }
  //
  //           return Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(title, style: primaryMedium17),
  //                     Gap(5),
  //                     Text(
  //                       _formatDateTime(timestamp),
  //                       style: colorABRegular16,
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               Text(
  //                 '${isCredit ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
  //                 style: primaryMedium17.copyWith(
  //                   color: isCredit ? Color(0xff397646) : Color(0xffE41717),
  //                 ),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return 'Today | ${_formatTime(dateTime)}';
    } else {
      return '${_formatDate(dateTime)} | ${_formatTime(dateTime)}';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12;
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

