import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pinput/pinput.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:timer_count_down/timer_controller.dart';
import 'package:timer_count_down/timer_count_down.dart';
import '../../helper/ui_helper.dart';
import '../../routes/routes.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../widgets/my_elevated_button.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

class OtpVerfiyView extends StatefulWidget {
  final Map<String, dynamic>? args;
  const OtpVerfiyView({this.args, Key? key}) : super(key: key);

  @override
  State<OtpVerfiyView> createState() => _OtpVerfiyViewState();
}

// Update your PinTheme configuration
final PinTheme defaultPinTheme = PinTheme(
  width: 15.w,  // Increased from 5.25.h to 15.w (percentage of screen width)
  height: 6.h,  // Keep height as is or adjust if needed
  textStyle: primaryMedium18,
  decoration: BoxDecoration(
    color: white,
    borderRadius: myBorderRadius(10),
    boxShadow: [boxShadow1],
  ),
  margin: const EdgeInsets.symmetric(horizontal: 8),  // Increased horizontal margin
);

class _OtpVerfiyViewState extends State<OtpVerfiyView> {
  final cdController = CountdownController(autoStart: true);
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtp();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    // cdController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  late Razorpay _razorpay;
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print("💰 Payment Success: ${response.paymentId}");
    _finalizeCaptainRegistration();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("❌ Payment Failed: ${response.code} | ${response.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed. Please try again.')),
    );
    setState(() => _isLoading = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("💳 External Wallet Selected: ${response.walletName}");
  }

  Future<void> _finalizeCaptainRegistration() async {
    final args = widget.args ?? {};
    final mobileNumber = args['mobile'];
    final userType = args['userType'];
    final doc = await FirebaseFirestore.instance.collection('temp_registrations').doc(mobileNumber).get();

    if (!doc.exists) return;

    final userData = doc.data()!;
    final userCredential = FirebaseAuth.instance.currentUser;
    final fcmToken = await FirebaseMessaging.instance.getToken();

    await FirebaseFirestore.instance
        .collection('captains')
        .doc(userCredential!.uid)
        .set({
      'uid': userCredential.uid,
      'mobile': mobileNumber,
      'name': userData['name'],
      'role': userType,
      'userCode': userData['userCode'],
      'district': userData['district'],
      'dob': userData['dob'],
      'licenseNumber': userData['licenseNumber'],
      'profileImage': userData['profileImage'],
      'is_active': true,
      'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('temp_registrations').doc(mobileNumber).delete();

    // Show success dialog
    await _showSuccessDialog(userData['userCode']);

    Navigator.pushNamedAndRemoveUntil(context, Routes.mainhome, (route) => false);
  }

  Future<void> _startCaptainPayment(double amount, String userCode) async {
    try {
      final settingsQuery = await FirebaseFirestore.instance
          .collection('settings')
          .where('razorpayKeyId', isNotEqualTo: null)
          .limit(1)
          .get();

      if (settingsQuery.docs.isEmpty) {
        throw 'Razorpay key not found in settings';
      }

      final razorpayKey = settingsQuery.docs.first.data()['razorpayKeyId'];
      final args = widget.args ?? {};
      final mobileNumber = args['mobile'];

      var options = {
        'key': razorpayKey,
        'amount': (amount * 100).toInt(),
        'name': 'Vandizone Captain Registration',
        'description': 'Registration fee for code $userCode',
        'prefill': {
          'contact': mobileNumber,
        },
        'currency': 'INR',
      };

      _razorpay.open(options);
    } catch (e) {
      print("⚠️ Razorpay error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment setup failed: $e')),
      );
    }
  }

  Future<void> _sendOtp() async {
    try {
      print("🔄 Step 1: Starting OTP send process...");
      setState(() => _isLoading = true);

      // final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final args = widget.args ?? {};
      final mobileNumber = args['mobile'];
      print("📞 Step 2: Mobile number: +91$mobileNumber");

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$mobileNumber',
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("✅ Step 3: Auto verification completed.");
          await _verifyOtp(credential.smsCode!);
        },
        verificationFailed: (FirebaseAuthException e) {
          print("❌ Step 3: Verification failed: ${e.message}");
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print("📩 Step 4: OTP code sent. verificationId = $verificationId");
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          cdController.start(); // Countdown
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("⌛ Step 5: Auto-retrieval timeout. ID = $verificationId");
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print("❌ Step 6: Error during OTP send: ${e.toString()}");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }


  // Future<void> _verify(BuildContext context) async {
  //   if (_otpController.text.length != 6) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Please enter a valid 4-digit OTP')),
  //     );
  //     return;
  //   }
  //
  //   await _verifyOtp(_otpController.text);
  // }

  Future<void> _verify(BuildContext context) async {
    print("🔄 Step 7: Verifying OTP input...");
    if (_otpController.text.length != 6) {
      print("❌ Invalid OTP entered: ${_otpController.text}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    await _verifyOtp(_otpController.text);
  }


  // Future<void> _verifyOtp(String smsCode) async {
  //   try {
  //     setState(() => _isLoading = true);
  //     dismissKeyBoard(context);
  //
  //     // Create credential with verification ID and OTP
  //     final credential = PhoneAuthProvider.credential(
  //       verificationId: _verificationId!,
  //       smsCode: smsCode,
  //     );
  //
  //     // Sign in with credential
  //     final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
  //
  //     // Get the temporary registration data
  //     final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  //     final mobileNumber = args['mobile'];
  //     final userType = args['userType'];
  //
  //     final doc = await FirebaseFirestore.instance
  //         .collection('temp_registrations')
  //         .doc(mobileNumber)
  //         .get();
  //
  //     if (!doc.exists) {
  //       throw 'Registration data not found. Please try signing up again.';
  //     }
  //
  //     final userData = doc.data() as Map<String, dynamic>;
  //
  //     await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(userCredential.user!.uid)
  //         .set({
  //       'uid': userCredential.user!.uid,
  //       'mobile': mobileNumber,
  //       'name': userData['name'],
  //       'role': userType,
  //       'userCode': userData['userCode'],
  //       'district': userData['district'],
  //       if (userType == 'captain') ...{
  //         'dob': userData['dob'],
  //         'licenseNumber': userData['licenseNumber'],
  //         'selfieUrl': userData['selfieUrl'],
  //       },
  //       'createdAt': FieldValue.serverTimestamp(),
  //     });
  //
  //     // Delete temporary registration data
  //     await FirebaseFirestore.instance
  //         .collection('temp_registrations')
  //         .doc(mobileNumber)
  //         .delete();
  //
  //     // Navigate to home screen
  //     if (mounted) {
  //       Navigator.pushNamedAndRemoveUntil(
  //         context,
  //         Routes.home,
  //             (route) => false,
  //       );
  //     }
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     print(e.toString());
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Verification failed: ${e.toString()}')),
  //     );
  //   }
  // }

  // Future<void> _verifyOtp(String smsCode) async {
  //   try {
  //     print("🔐 Step 8: Verifying OTP code: $smsCode");
  //     setState(() => _isLoading = true);
  //     dismissKeyBoard(context);
  //
  //     final credential = PhoneAuthProvider.credential(
  //       verificationId: _verificationId!,
  //       smsCode: smsCode,
  //     );
  //
  //     final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
  //     print("✅ Step 9: Phone number verified. UID: ${userCredential.user?.uid}");
  //     String? fcmToken = await FirebaseMessaging.instance.getToken();
  //     // final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  //     final args = widget.args ?? {};
  //     final mobileNumber = args['mobile'];
  //     final userType = args['userType'];
  //     print("📦 Step 10: Fetching temp registration for $mobileNumber");
  //
  //     final doc = await FirebaseFirestore.instance
  //         .collection('temp_registrations')
  //         .doc(mobileNumber)
  //         .get();
  //
  //     if (!doc.exists) {
  //       print("❌ Step 11: temp_registrations doc not found for $mobileNumber");
  //       throw 'Registration data not found. Please try signing up again.';
  //     }
  //
  //     final userData = doc.data() as Map<String, dynamic>;
  //     print("📄 Step 12: Temp data found: ${userData}");
  //
  //     final targetCollection = userType == 'captain' ? 'captains' : 'owners';
  //
  //     // await FirebaseFirestore.instance
  //     //     .collection(targetCollection)
  //     //     .doc(userCredential.user!.uid)
  //     //     .set({
  //     //   'uid': userCredential.user!.uid,
  //     //   'mobile': mobileNumber,
  //     //   'name': userData['name'],
  //     //   'role': userType,
  //     //   'userCode': userData['userCode'],
  //     //   'district': userData['district'],
  //     //   'fcmToken': fcmToken,
  //     //   if (userType == 'captain') ...{
  //     //     'dob': userData['dob'],
  //     //     'licenseNumber': userData['licenseNumber'],
  //     //     'selfieUrl': userData['selfieUrl'],
  //     //     'is_active':true,
  //     //   },
  //     //   'createdAt': FieldValue.serverTimestamp(),
  //     // });
  //     //
  //     // print("✅ Step 13: User data saved to Firestore");
  //     //
  //     // await FirebaseFirestore.instance
  //     //     .collection('temp_registrations')
  //     //     .doc(mobileNumber)
  //     //     .delete();
  //     //
  //     // print("🧹 Step 14: Deleted temp_registrations/$mobileNumber");
  //     // print("✅ Step 13: User data saved to Firestore");
  //     //
  //     // await FirebaseFirestore.instance
  //     //     .collection('temp_registrations')
  //     //     .doc(mobileNumber)
  //     //     .delete();
  //     //
  //     // print("🧹 Step 14: Deleted temp_registrations/$mobileNumber");
  //
  //     // final userData = doc.data() as Map<String, dynamic>;
  //     final userCode = userData['userCode'];
  //     // final fcmToken = await FirebaseMessaging.instance.getToken();
  //
  //     if (userType == 'owner') {
  //       // Skip payment, move directly
  //       await FirebaseFirestore.instance
  //           .collection('owners')
  //           .doc(userCredential.user!.uid)
  //           .set({
  //         'uid': userCredential.user!.uid,
  //         'mobile': mobileNumber,
  //         'name': userData['name'],
  //         'role': userType,
  //         'userCode': userCode,
  //         'district': userData['district'],
  //         'fcmToken': fcmToken,
  //         'createdAt': FieldValue.serverTimestamp(),
  //       });
  //
  //       await FirebaseFirestore.instance.collection('temp_registrations').doc(mobileNumber).delete();
  //       await _showSuccessDialog(userCode);
  //       Navigator.pushNamedAndRemoveUntil(context, Routes.homeowner, (route) => false);
  //     } else {
  //       // Captain – fetch fee from Firestore and start Razorpay
  //       final feeDoc = await FirebaseFirestore.instance.collection('registrationFeeCharges').limit(1).get();
  //       if (feeDoc.docs.isEmpty) throw 'Registration fee not set.';
  //       final fee = feeDoc.docs.first.data()['captain_registration_fee'];
  //
  //       _startCaptainPayment(fee.toDouble(), userCode);
  //     }
  //
  //     // await showDialog(
  //     //   context: context,
  //     //   barrierDismissible: false,
  //     //   builder: (BuildContext context) {
  //     //     return AlertDialog(
  //     //       shape: RoundedRectangleBorder(
  //     //         borderRadius: BorderRadius.circular(20),
  //     //       ),
  //     //       contentPadding: EdgeInsets.zero,
  //     //       content: Container(
  //     //         width: 350,
  //     //         padding: EdgeInsets.all(32),
  //     //         decoration: BoxDecoration(
  //     //           borderRadius: BorderRadius.circular(20),
  //     //           color: Colors.white,
  //     //         ),
  //     //         child: Column(
  //     //           mainAxisSize: MainAxisSize.min,
  //     //           crossAxisAlignment: CrossAxisAlignment.center,
  //     //           children: [
  //     //             // Header section
  //     //             Container(
  //     //               width: 64,
  //     //               height: 64,
  //     //               decoration: BoxDecoration(
  //     //                 color: Colors.green.shade50,
  //     //                 shape: BoxShape.circle,
  //     //               ),
  //     //               child: Icon(
  //     //                 Icons.check_circle_outline,
  //     //                 size: 32,
  //     //                 color: Colors.green.shade600,
  //     //               ),
  //     //             ),
  //     //             SizedBox(height: 20),
  //     //
  //     //             // Title
  //     //             Text(
  //     //               "Welcome!",
  //     //               style: TextStyle(
  //     //                 fontSize: 24,
  //     //                 fontWeight: FontWeight.w700,
  //     //                 color: Colors.grey.shade800,
  //     //                 letterSpacing: -0.5,
  //     //               ),
  //     //             ),
  //     //             SizedBox(height: 8),
  //     //
  //     //             // Subtitle
  //     //             Text(
  //     //               "Your account has been created successfully",
  //     //               style: TextStyle(
  //     //                 fontSize: 16,
  //     //                 color: Colors.grey.shade600,
  //     //                 fontWeight: FontWeight.w400,
  //     //               ),
  //     //               textAlign: TextAlign.center,
  //     //             ),
  //     //             SizedBox(height: 32),
  //     //
  //     //             // User Code Section
  //     //             Container(
  //     //               width: double.infinity,
  //     //               padding: EdgeInsets.all(20),
  //     //               decoration: BoxDecoration(
  //     //                 color: Colors.grey.shade50,
  //     //                 borderRadius: BorderRadius.circular(12),
  //     //                 border: Border.all(
  //     //                   color: Colors.grey.shade200,
  //     //                   width: 1,
  //     //                 ),
  //     //               ),
  //     //               child: Column(
  //     //                 children: [
  //     //                   Text(
  //     //                     "Your User Code",
  //     //                     style: TextStyle(
  //     //                       fontSize: 14,
  //     //                       fontWeight: FontWeight.w600,
  //     //                       color: Colors.grey.shade700,
  //     //                       letterSpacing: 0.5,
  //     //                     ),
  //     //                   ),
  //     //                   SizedBox(height: 12),
  //     //                   SelectableText(
  //     //                     userData['userCode'] ?? '',
  //     //                     textAlign: TextAlign.center,
  //     //                     style: TextStyle(
  //     //                       fontSize: 20,
  //     //                       color: primary,
  //     //                       fontWeight: FontWeight.w800,
  //     //                       letterSpacing: 1.2,
  //     //                       fontFamily: 'monospace',
  //     //                     ),
  //     //                   ),
  //     //                   SizedBox(height: 16),
  //     //                   OutlinedButton.icon(
  //     //                     onPressed: () {
  //     //                       Clipboard.setData(ClipboardData(text: userData['userCode']));
  //     //                       ScaffoldMessenger.of(context).showSnackBar(
  //     //                         SnackBar(
  //     //                           content: Row(
  //     //                             children: [
  //     //                               Icon(Icons.check_circle, color: Colors.white, size: 20),
  //     //                               SizedBox(width: 8),
  //     //                               Text('User Code copied to clipboard'),
  //     //                             ],
  //     //                           ),
  //     //                           backgroundColor: Colors.green.shade600,
  //     //                           behavior: SnackBarBehavior.floating,
  //     //                           shape: RoundedRectangleBorder(
  //     //                             borderRadius: BorderRadius.circular(10),
  //     //                           ),
  //     //                         ),
  //     //                       );
  //     //                     },
  //     //                     icon: Icon(Icons.copy, size: 18),
  //     //                     label: Text(
  //     //                       "Copy Code",
  //     //                       style: TextStyle(
  //     //                         fontSize: 14,
  //     //                         fontWeight: FontWeight.w600,
  //     //                       ),
  //     //                     ),
  //     //                     style: OutlinedButton.styleFrom(
  //     //                       foregroundColor: primary,
  //     //                       side: BorderSide(color: primary),
  //     //                       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  //     //                       shape: RoundedRectangleBorder(
  //     //                         borderRadius: BorderRadius.circular(8),
  //     //                       ),
  //     //                     ),
  //     //                   ),
  //     //                 ],
  //     //               ),
  //     //             ),
  //     //             SizedBox(height: 32),
  //     //
  //     //             // Action Button
  //     //             SizedBox(
  //     //               width: double.infinity,
  //     //               child: ElevatedButton(
  //     //                 onPressed: () => Navigator.of(context).pop(),
  //     //                 style: ElevatedButton.styleFrom(
  //     //                   backgroundColor: primary,
  //     //                   foregroundColor: Colors.white,
  //     //                   elevation: 0,
  //     //                   padding: EdgeInsets.symmetric(vertical: 16),
  //     //                   shape: RoundedRectangleBorder(
  //     //                     borderRadius: BorderRadius.circular(12),
  //     //                   ),
  //     //                 ),
  //     //                 child: Text(
  //     //                   "Continue",
  //     //                   style: TextStyle(
  //     //                     fontSize: 16,
  //     //                     fontWeight: FontWeight.w600,
  //     //                     letterSpacing: 0.5,
  //     //                   ),
  //     //                 ),
  //     //               ),
  //     //             ),
  //     //           ],
  //     //         ),
  //     //       ),
  //     //     );
  //     //   },
  //     // );
  //
  //     if (mounted) {
  //       // setState(() {
  //       //   role = userType == 'captain' ? 0 : 1;
  //       // });
  //       print("🚀 Step 15: Navigating to home");
  //       // Navigator.pushNamedAndRemoveUntil(context, Routes.home, (route) => false);
  //       Navigator.pushNamedAndRemoveUntil(
  //         context,
  //         userType == 'captain' ? Routes.mainhome : Routes.homeowner,
  //             (route) => false,
  //       );
  //     }
  //
  //   } catch (e) {
  //     print("❌ Step X: Error in verification flow: ${e.toString()}");
  //     setState(() => _isLoading = false);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Verification failed: ${e.toString()}')),
  //     );
  //   }
  // }

  Future<void> _verifyOtp(String smsCode) async {
    try {
      print("🔐 Step 8: Verifying OTP code: $smsCode");
      setState(() => _isLoading = true);
      dismissKeyBoard(context);

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print("✅ Step 9: Phone number verified. UID: ${userCredential.user?.uid}");
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      final args = widget.args ?? {};
      final mobileNumber = args['mobile'];
      final userType = args['userType'];
      print("📦 Step 10: Fetching temp registration for $mobileNumber");

      final doc = await FirebaseFirestore.instance
          .collection('temp_registrations')
          .doc(mobileNumber)
          .get();

      if (!doc.exists) {
        print("❌ Step 11: temp_registrations doc not found for $mobileNumber");
        throw 'Registration data not found. Please try signing up again.';
      }

      final userData = doc.data() as Map<String, dynamic>;
      final userCode = userData['userCode'];

      if (userType == 'owner') {
        // Owner – create user and navigate
        await FirebaseFirestore.instance
            .collection('owners')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'mobile': mobileNumber,
          'name': userData['name'],
          'role': userType,
          'userCode': userCode,
          'district': userData['district'],
          'fcmToken': fcmToken,
          'createdAt': FieldValue.serverTimestamp(),
          'bankName': userData['bankName'] ?? "",
          'branchName': userData['branchName'] ?? "",
          'accountNumber': userData['accountNumber'] ?? "",
          'ifscCode': userData['ifscCode'] ?? "",
          'accountHolderName': userData['accountHolderName'] ?? "",
        });

        await FirebaseFirestore.instance.collection('temp_registrations').doc(mobileNumber).delete();
        await _showSuccessDialog(userCode);
        Navigator.pushNamedAndRemoveUntil(context, Routes.homeowner, (route) => false);
      } else if (userType == 'captain') {
        // Captain – start Razorpay payment
        final feeDoc = await FirebaseFirestore.instance
            .collection('registrationFeeCharges')
            .limit(1)
            .get();
        if (feeDoc.docs.isEmpty) throw 'Registration fee not set.';

        final fee = feeDoc.docs.first.data()['captain_registration_fee'];
        _startCaptainPayment(fee.toDouble(), userCode);
        // ❗️ DO NOT navigate yet — handled in payment success
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print("❌ Step X: Error in verification flow: ${e.toString()}");
      setState(() => _isLoading = false);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Verification failed: ${e.toString()}')),
      // );
    }
  }


  Future<void> _showSuccessDialog(String userCode) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 350,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header section
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 32,
                    color: Colors.green.shade600,
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  "Welcome!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),

                // Subtitle
                Text(
                  "Your account has been created successfully",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),

                // User Code Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Your User Code",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 12),
                      SelectableText(
                        userCode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: userCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text('User Code copied to clipboard'),
                                ],
                              ),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, size: 18),
                        label: Text(
                          "Copy Code",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Continue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                            Text('OTP Verification', style: blackMedium20),
                            Gap(10),
                            Text('Enter OTP sent to your mobile number', style: colorC4Regular16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Pinput(
                                  length: 6, // Changed to 6 digits (standard for Firebase)
                                  controller: _otpController,
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
                                        text: "Didn't receive OTP? ",
                                        style: colorABRegular15,
                                        children: [
                                          TextSpan(
                                            text: "Resend",
                                            style: primarySemiBold15,
                                            recognizer: TapGestureRecognizer()..onTap = () {
                                              cdController.restart();
                                              _sendOtp();
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
                                  onFinished: () {
                                    // Optional: Handle when countdown finishes
                                  },
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
                        child: _isLoading
                            ? CircularProgressIndicator()
                            : MyElevatedButton(
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