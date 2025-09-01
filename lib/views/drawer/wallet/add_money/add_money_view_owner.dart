import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../components/my_appbar.dart';
import '../../../../helper/ui_helper.dart';
import '../../../../models/payment_method.dart';
import '../../../../utils/assets.dart';
import '../../../../utils/constant.dart';
import '../../../../widgets/my_elevated_button.dart';
import '../../../../widgets/my_textfield.dart';
class AddMoneyView extends StatefulWidget {
  const AddMoneyView({super.key});

  @override
  State<AddMoneyView> createState() => _AddMoneyViewState();
}

class _AddMoneyViewState extends State<AddMoneyView> {
  late Razorpay _razorpay;
  int _selectedMethod = 0;
  final TextEditingController _amountController = TextEditingController();
  int? _selectedAmountIndex;
  final List<int> _amountOptions = [1, 300, 500, 1000];
  final WalletService _walletService = WalletService();
  bool _isProcessing = false;
  String? _razorpayKey;
  String? _userUniqueCode;
  String? _userPhone;
  String? _userEmail;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchRazorpayConfig();
    _fetchUserUniqueCode();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  // Future<void> _fetchUserUniqueCode() async {
  //   try {
  //     // Get current user ID from Firebase Auth
  //     final userId = FirebaseAuth.instance.currentUser?.uid;
  //     if (userId == null) return;
  //
  //     final doc = await FirebaseFirestore.instance
  //         .collection('owners')
  //         .doc(userId)
  //         .get();
  //
  //     if (doc.exists) {
  //       setState(() {
  //         _userUniqueCode = doc.data()?['userCode']; // Changed from uniqueCode to userCode
  //         _userPhone = doc.data()?['mobile'];
  //         _userEmail = doc.data()?['email'];
  //         _userName = doc.data()?['name'];
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint('Error fetching user details: $e');
  //   }
  // }
  Future<void> _fetchUserUniqueCode() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('User not authenticated');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('owners')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _userUniqueCode = data?['userCode'];
          _userPhone = data?['mobile'];
          _userEmail = data?['email'];
          _userName = data?['name'];
        });

        // Print all fetched user details
        debugPrint('Fetched user details:');
        debugPrint('User ID: $userId');
        debugPrint('User Code: $_userUniqueCode');
        debugPrint('Name: $_userName');
        debugPrint('Phone: $_userPhone');
        debugPrint('Email: $_userEmail');

        // Print the entire document data
        debugPrint('Complete user document: ${data.toString()}');
      } else {
        debugPrint('User document does not exist');
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
    }
  }

  Future<void> _fetchRazorpayConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('platformSettings')
          .get();

      if (doc.exists) {
        final key = doc.data()?['razorpayKeyId'];
        debugPrint('Razorpay Key: $key'); // More specific log
        setState(() {
          _razorpayKey = key;
        });
      } else {
        debugPrint('platformSettings document does not exist');
      }
    } catch (e) {
      debugPrint('Error fetching Razorpay config: $e');
    }
  }


  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Payment succeeded, now add money to wallet
    final amount = double.tryParse(_amountController.text) ?? 0;
    _completeWalletTransaction(amount, response.paymentId!);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    UiHelper.showSnackBar(context, 'Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessing = false);
    UiHelper.showSnackBar(context, 'External wallet selected: ${response.walletName}');
  }

  Future<void> _completeWalletTransaction(double amount, String paymentId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        UiHelper.showSnackBar(context, 'User not authenticated');
        return;
      }

      await _walletService.addMoneyToWallet(
        userId: userId,
        userCode: _userUniqueCode,
        amount: amount,
        razortransactionId: paymentId,
        name: _userName,
        phone: _userPhone, // <-- Pass phone here
      );
      UiHelper.showSnackBar(context, '₹$amount added to your wallet successfully!');

      Navigator.pop(context);
    } catch (e) {
      UiHelper.showSnackBar(context, 'Failed to complete transaction: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _addMoney() async {
    if (_amountController.text.isEmpty) {
      UiHelper.showTopSnackBar(context, 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      UiHelper.showSnackBar(context, 'Please enter a valid amount');
      return;
    }

    if (_razorpayKey == null) {
      UiHelper.showSnackBar(context, 'Payment gateway not configured');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      var options = {
        'key': _razorpayKey!,
        'amount': (amount * 100).toInt(),
        'name': 'Vandizone Owner',
        'description': 'Wallet Top-up',
        'prefill': {
          'contact': _userPhone, // Use user's phone if available
          'email': _userEmail ?? 'indianvandizone@gmail.com', // Use user's email if available
        },
        'external': {
          'wallets': ['gpay']
        }
      };

      if (_userUniqueCode != null) {
        options['notes'] = {
          'user_unique_code': _userUniqueCode // Using userCode as both
        };
      }

      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      UiHelper.showSnackBar(context, 'Error initiating payment: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: "Add Money"),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(20).copyWith(top: 10),
              children: [
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: List.generate(_amountOptions.length, (index) {
                      final amount = _amountOptions[index];
                      final isSelected = _selectedAmountIndex == index;
                      return Padding(
                        padding: EdgeInsets.only(right: 15),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAmountIndex = index;
                              _amountController.text = amount.toString();
                            });
                          },
                          child: Container(
                            width: 80,
                            decoration: BoxDecoration(
                              color: isSelected ? primary : white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? primary : Colors.grey.shade300,
                              ),
                              boxShadow: [boxShadow1],
                            ),
                            child: Center(
                              child: Text(
                                '₹$amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Gap(20),
                MyTextfield(
                  controller: _amountController,
                  header: 'Amount',
                  headerStyle: blackMedium18,
                  hintText: "Enter amount to add",
                  keyboardType: TextInputType.number,
                ),
                Gap(30),
                // Text('Payment Methods', style: blackMedium18),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.vertical(top: myRadius(20)),
              boxShadow: [BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))],
            ),
            padding: const EdgeInsets.all(20),
            child: _isProcessing
                ? Center(child: CircularProgressIndicator())
                : MyElevatedButton(
              title: "Continue",
              onPressed: _addMoney,
            ),
          )
        ],
      ),
    );
  }
}
class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> _generateTransactionId() async {
    // First try to increment the counter
    final counterRef = _firestore.collection('counters').doc('wallet_transactions');
    final counterSnapshot = await counterRef.get();

    int counter = 1;
    if (counterSnapshot.exists) {
      counter = (counterSnapshot.data()?['count'] ?? 0) + 1;
      await counterRef.update({'count': counter});
    } else {
      await counterRef.set({'count': counter});
    }

    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    return 'VWIO$year${counter.toString().padLeft(4, '0')}';
  }

  Future<void> addMoneyToWallet({
    required String userId,
    required double amount,
    required String razortransactionId,
    required String? userCode,
    required String? phone, // <-- Add phone as a parameter
    String? razorpayPaymentId,required String? name,
  }) async {
    final transactionId = await _generateTransactionId();
    final transaction = WalletTransaction(
      transactionId: transactionId,
      userId: userId,
      userCode: userCode, // Pass userCode
      amount: amount,
      razortransactionId: razortransactionId,
      timestamp: DateTime.now(),
      razorpayPaymentId: razorpayPaymentId,
    );

    final batch = _firestore.batch();

    // Add transaction record
    final transactionRef = _firestore.collection('owner_wallet_transactions').doc();
    batch.set(transactionRef, transaction.toMap());

    // Update user's wallet balance
    final walletRef = _firestore.collection('owner_wallets').doc(userId);
    batch.set(walletRef, {
      'balance': FieldValue.increment(amount),
      'userCode': userCode,
      'phone': phone,
      'name':name,
      'lastUpdated': DateTime.now(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}

class WalletTransaction {
  final String transactionId;
  final String userId;
  final String? userCode; // Added userCode
  final double amount;
  final String razortransactionId;
  final DateTime timestamp;
  final String status;
  final String type;
  final String? razorpayPaymentId;

  WalletTransaction({
    required this.transactionId,
    required this.userId,
    this.userCode,
    required this.amount,
    required this.razortransactionId,
    required this.timestamp,
    this.status = "completed",
    this.type = "credit",
    this.razorpayPaymentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'userId': userId,
      'userCode': userCode, // Include userCode in the map
      'amount': amount,
      'razortransactionId': razortransactionId,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'type': type,
      if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      transactionId: map['transactionId'],
      userId: map['userId'],
      userCode: map['userCode'], // Include in fromMap
      amount: map['amount'].toDouble(),
      razortransactionId: map['razortransactionId'],
      timestamp: DateTime.parse(map['timestamp']),
      status: map['status'],
      type: map['type'],
      razorpayPaymentId: map['razorpayPaymentId'],
    );
  }
}