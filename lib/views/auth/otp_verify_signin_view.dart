import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pinput/pinput.dart';
import 'package:sizer/sizer.dart';
import 'package:timer_count_down/timer_controller.dart';
import 'package:timer_count_down/timer_count_down.dart';
import '../../helper/ui_helper.dart';
import '../../routes/routes.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../widgets/my_elevated_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerOtpVerfiyView extends StatefulWidget {
  final Map<String, dynamic>? args;

  const OwnerOtpVerfiyView({super.key, this.args});

  @override
  State<OwnerOtpVerfiyView> createState() => _OwnerOtpVerfiyViewState();
}

final PinTheme defaultPinTheme = PinTheme(
  width: 5.25.h,
  height: 5.25.h,
  textStyle: primaryMedium18,
  decoration: BoxDecoration(
    color: white,
    borderRadius: myBorderRadius(10),
    boxShadow: [boxShadow1],
  ),
  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
);

class _OwnerOtpVerfiyViewState extends State<OwnerOtpVerfiyView> {
  final cdController = CountdownController(autoStart: true);
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  String? _phoneNumber;
  int? _resendToken;
  int? _selectedRole;

  @override
  void initState() {
    super.initState();
    final args = widget.args ?? {};
    _verificationId = args['verificationId'];
    _phoneNumber = args['mobile'];
    _resendToken = args['resendToken'];
    _selectedRole = args['selectedRole'];
    print('Verification ID: $_verificationId');
    print('Phone number: $_phoneNumber');
    print('Resend token: $_resendToken');
    print('_selectedRole: $_selectedRole');
    // Only send OTP if we don't already have a verificationId
    if (_verificationId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendOtp();
      });
    } else {
      // If we have verificationId, start the timer
      cdController.start();
    }
  }

  Future<void> _resendOtp() async {
    try {
      setState(() => _isLoading = true);
      await _sendOtp(); // This will use the existing phone number and resend token
      cdController.restart(); // Restart the countdown timer
      _showSuccessSnackbar('OTP resent successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to resend OTP: ${_getUserFriendlyError(e)}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      _showErrorSnackbar('Phone number is missing');
      return;
    }

    try {
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$_phoneNumber',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _verifyWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          if (e.code != 'invalid-verification-code') {
            _showErrorSnackbar('Verification failed: ${_getUserFriendlyError(e)}');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isLoading = false;
          });
          cdController.restart();
          _showSuccessSnackbar('OTP sent successfully');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Error: ${_getUserFriendlyError(e)}');
    }
  }

  void _verify(BuildContext context) {
    if (_otpController.text.length != 6) {
      print("❌ Invalid OTP entered: ${_otpController.text}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    _verifyWithOtp(_otpController.text);
  }

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    try {
      setState(() => _isLoading = true);
      final authResult = await FirebaseAuth.instance.signInWithCredential(credential);

      final prefs = await SharedPreferences.getInstance();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('🔐 FCM Token: $fcmToken');

      // Determine the collection name based on selected role
      final collectionName = _selectedRole == 0 ? 'captains' : 'owners';

      // Query Firestore to get user details
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('mobile', isEqualTo: _phoneNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final userDoc = snapshot.docs.first;
        final userData = userDoc.data();

        // Save all required user details to SharedPreferences
        await prefs.setString('userCode', userData['userCode'] ?? '');
        await prefs.setString('name', userData['name'] ?? '');
        await prefs.setString('mobile', _phoneNumber ?? '');
        await prefs.setInt('role', _selectedRole ?? 0);
        await prefs.setInt('selectedRole', _selectedRole ?? 0);

        // Update FCM token in Firestore if available
        if (fcmToken != null) {
          await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(userDoc.id)
              .update({
            'fcmToken': fcmToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        print("✅ User details saved to SharedPreferences");

        if (mounted) {
          setState(() {
            role = _selectedRole == 0 ? 0: 1;
          });
          Navigator.pushNamedAndRemoveUntil(
            context,
            _selectedRole == 0 ? Routes.mainhome : Routes.homeowner,
                (route) => false,
          );
        }
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackbar('User not found in database');
      }
    } catch (e) {
      print("❌ OTP verification failed: $e");
      setState(() => _isLoading = false);
      if (e != 'invalid-verification-code') {
        _showErrorSnackbar('Verification failed: ${_getUserFriendlyError(e)}');
      }
    }
  }


  Future<void> _verifyWithOtp(String smsCode) async {
    try {
      setState(() => _isLoading = true);
      dismissKeyBoard(context);

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _verifyWithCredential(credential);
    } catch (e) {
      print("❌ OTP verification failed: $e");
      setState(() => _isLoading = false);
      if (e != 'invalid-verification-code') {
        _showErrorSnackbar('Verification failed: ${_getUserFriendlyError(e)}');
      }    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'Invalid OTP. Please try again.';
        case 'quota-exceeded':
          return 'Quota exceeded. Please try again later.';
        case 'missing-client-identifier':
          return 'App verification failed. Please reinstall the app.';
        default:
          return error.message ?? 'Unknown error occurred';
      }
    }
    return error.toString();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => dismissKeyBoard(context),
      child: Scaffold(
        body: SizedBox(
          height: 100.h,
          width: 100.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // appBar
              Positioned(
                top: 0,
                child: Container(
                  width: 100.w,
                  height: 23.h,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: primary,
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: AssetImage(AssetImages.authbg),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image.asset(
                      //   AssetImages.logosplash, // Make sure this path is correct in your assets
                      //   height: 50, // Adjust as needed
                      //   width: 150, // Adjust as needed
                      //   fit: BoxFit.contain,
                      // ),
                      // SizedBox(height: 10),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Icon(Icons.arrow_back_ios_new, color: white),
                            ),
                          ),
                          Text('Verification', style: whiteSemiBold22),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // form
              Positioned.fill(
                top: 19.h,
                child: Container(
                  height: 80.h,
                  width: 100.w,
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.vertical(top: myRadius(20)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20).copyWith(top: 40),
                          physics: BouncingScrollPhysics(),
                          children: [
                            Text('Otp Verification', style: blackMedium20),
                            Gap(10),
                            Text('Enter OTP we will sent you', style: colorC4Regular16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Pinput(
                                  controller: _otpController,
                                  length: 6,
                                  defaultPinTheme: defaultPinTheme,
                                  focusedPinTheme: defaultPinTheme,
                                  submittedPinTheme: defaultPinTheme,
                                  onCompleted: (value) => _verify(context),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                        text: "Don’t receive?",
                                        style: colorABRegular15,
                                        children: [
                                          TextSpan(
                                            text: " Resend",
                                            style: primarySemiBold15,
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                if (!_isLoading) {
                                                  _resendOtp();
                                                }
                                              },
                                          )
                                        ]),
                                  ),
                                ),
                                Countdown(
                                  controller: cdController,
                                  seconds: 60,
                                  build: (_, double time) => Text(
                                    '00 : ${time.toStringAsFixed(0).padLeft(2, '0')}',
                                    style: primarySemiBold15,
                                  ),
                                  interval: const Duration(milliseconds: 100),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.vertical(top: myRadius(20)),
                            boxShadow: [
                              BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))
                            ]),
                        padding: const EdgeInsets.all(20),
                        child: MyElevatedButton(
                          title: "Verify",
                          onPressed: () => _verify(context),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
