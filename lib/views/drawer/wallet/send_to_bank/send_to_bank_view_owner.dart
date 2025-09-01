import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../routes/routes.dart';
import '../../../../widgets/my_textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../components/my_appbar.dart';
import '../../../../utils/assets.dart';
import '../../../../utils/constant.dart';
import '../../../../widgets/my_elevated_button.dart';

class SendToBankView extends StatefulWidget {
  const SendToBankView({super.key});

  @override
  State<SendToBankView> createState() => _SendToBankViewState();
}

class _SendToBankViewState extends State<SendToBankView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController =
  TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _bankCodeController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _branchNameController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final WalletService _walletService = WalletService();
  bool _isProcessing = false;
  bool _showBankFields = true; // Show bank fields by default
  bool _showUPIFields = false; // Show UPI fields when toggled
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _balance = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

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

  Future<void> _processWithdrawal() async {
    if (_amountController.text.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    // Validate that at least one payment method has details
    final hasBankDetails = _showBankFields &&
        _accountNumberController.text.isNotEmpty &&
        _accountNameController.text.isNotEmpty &&
        (_bankCodeController.text.isNotEmpty ||
            _bankNameController.text.isNotEmpty);

    final hasUPIDetails = _showUPIFields &&
        _upiIdController.text.isNotEmpty &&
        _upiIdController.text.contains('@');

    if (!hasBankDetails && !hasUPIDetails) {
      _showError('Please enter either bank details or UPI details');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      // First check if user has sufficient balance
      final walletDoc = await FirebaseFirestore.instance
          .collection('owner_wallets')
          .doc(userId)
          .get();

      final currentBalance = walletDoc.data()?['balance'] ?? 0.0;
      if (currentBalance < amount) {
        _showError('Insufficient balance');
        return;
      }

      // Create withdrawal request
      await _walletService.createWithdrawalRequest(
        userId: userId,
        amount: amount,
        accountNumber: _accountNumberController.text,
        accountName: _accountNameController.text,
        bankCode: _bankCodeController.text,
        bankName: _bankNameController.text,
        branchName: _branchNameController.text,
        upiId: _upiIdController.text,
      );

      // Navigate to success screen
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.pushNamed(context, Routes.successTransferOwner);
      }
    } catch (e) {
      _showError('Failed to process withdrawal: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    setState(() => _isProcessing = false);
  }

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: "Send To Bank"),
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                        Text('₹${_balance.toStringAsFixed(2)}', style: primarySemiBold25),
                      ],
                    ),
                  ),
                ),
                Gap(35),
                MyTextfield(
                  controller: _amountController,
                  header: "Amount To Transfer",
                  keyboardType: TextInputType.number,
                ),
                Gap(25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _showBankFields ? primary : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showBankFields = true;
                            _showUPIFields = false;
                          });
                        },
                        child: Text('Bank Transfer'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _showUPIFields ? primary : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showBankFields = false;
                            _showUPIFields = true;
                          });
                        },
                        child: Text('UPI Transfer'),
                      ),
                    ),
                  ],
                ),
                Gap(25),

                if (_showBankFields) ...[
                  MyTextfield(
                    controller: _accountNumberController,
                    header: "Account Number",
                    keyboardType: TextInputType.number,
                  ),
                  Gap(25),
                  MyTextfield(
                    controller: _accountNameController,
                    header: "Account Holder Name",
                  ),
                  Gap(25),
                  MyTextfield(
                    controller: _bankCodeController,
                    header: "Bank Code (IFSC/SWIFT)",
                  ),
                  Gap(25),
                  MyTextfield(
                    controller: _bankNameController,
                    header: "Bank Name",
                  ),
                  Gap(25),
                  MyTextfield(
                    controller: _branchNameController,
                    header: "Branch Name",
                  ),
                ],

                if (_showUPIFields) ...[
                  MyTextfield(
                    controller: _upiIdController,
                    header: "UPI ID",
                    hintText: "example@upi",
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.vertical(top: myRadius(20)),
              boxShadow: [
                BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: _isProcessing
                ? Center(child: CircularProgressIndicator())
                : MyElevatedButton(
              title: "Proceed",
              onPressed: _processWithdrawal,
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
    final counterRef =
    _firestore.collection('counters').doc('wallet_transactions');
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
    return 'VWOC$year${counter.toString().padLeft(4, '0')}';
  }

  Future<void> createWithdrawalRequest({
    required String userId,
    required double amount,
    String accountNumber = '',
    String accountName = '',
    String bankCode = '',
    String bankName = '',
    String branchName = '',
    String upiId = '',
  }) async {
    final transactionId = await _generateTransactionId();
    final withdrawalData = {
      'transactionId': transactionId,
      'userId': userId,
      'amount': amount,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'bankCode': bankCode,
      'bankName': bankName,
      'branchName': branchName,
      'upiId': upiId,
      'status': 0, // 0 for pending
      'timestamp': DateTime.now(),
      'type': 'withdrawal',
    };

    final batch = _firestore.batch();
    final withdrawalRef =
    _firestore.collection('owner_wallet_transactions').doc();
    batch.set(withdrawalRef, withdrawalData);
    final walletRef = _firestore.collection('owner_wallets').doc(userId);
    batch.update(walletRef, {
      'balance': FieldValue.increment(-amount),
      'lockedBalance': FieldValue.increment(amount),
    });
    await batch.commit();
  }
}