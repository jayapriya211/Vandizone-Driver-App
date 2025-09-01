import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:vandizone_caption/routes/routes.dart';
import 'package:sizer/sizer.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../widgets/my_elevated_button.dart';
import '../../widgets/my_textfield.dart';
import '../../widgets/uppercase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../helper/ui_helper.dart';

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  PhoneNumber initialValue = PhoneNumber(isoCode: 'IN');
  int selectedRole = 0; // 0 = Captain, 1 = Owner
  final TextEditingController captainIdController = TextEditingController();
  final TextEditingController ownerIdController = TextEditingController();
  final TextEditingController vehicleNumberController = TextEditingController();

  bool isSigningIn = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loginWithCode() async {

    if (isSigningIn) return;

    setState(() {
      isSigningIn = true;
    });

    final input = selectedRole == 0
        ? captainIdController.text.trim()
        : ownerIdController.text.trim();
    print("captain${captainIdController.text}");
    print("owner${ownerIdController.text}");

    if (input.isEmpty) {
      UiHelper.showSnackBar(context, "Please enter your ${selectedRole == 0 ? 'Captain' : 'Owner'} ID");
      return;
    }

    UiHelper.showLoadingDialog(context, message: "Verifying...");

    try {
      String? phoneNumber;
      final isCaptain = selectedRole == 0;

      // Determine the Firestore collection based on prefix
      if (isCaptain && input.startsWith('VD')) {
        final snapshot = await FirebaseFirestore.instance
            .collection('captains')
            .where('userCode', isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          Navigator.pop(context);
          UiHelper.showSnackBar(context, "No captain found with this ID");
          return;
        }

        phoneNumber = snapshot.docs.first['mobile'];
        print("Phone number used: +91$phoneNumber");
        setState(() => isSigningIn = false);
      } else if (!isCaptain && input.startsWith('VO')) {
        final snapshot = await FirebaseFirestore.instance
            .collection('owners')
            .where('userCode', isEqualTo: input)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          Navigator.pop(context);
          UiHelper.showSnackBar(context, "No owner found with this ID");
          return;
        }

        phoneNumber = snapshot.docs.first['mobile'];
        print("Phone number used: +91$phoneNumber");
        setState(() => isSigningIn = false);
      } else {
        Navigator.pop(context);
        UiHelper.showSnackBar(context, "Invalid ID format");
        setState(() {
          isSigningIn = false;
        });
        return;
      }

      // Trigger phone verification
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phoneNumber',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {
          // print("Auto-verification completed.");
        },
        verificationFailed: (FirebaseAuthException e) {
          Navigator.pop(context);
          UiHelper.showSnackBar(context, "Verification failed: ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.pop(context);
          setState(() {
            isSigningIn = false;
          });
          // print("phoneeee${verificationId}");
          Navigator.pushNamed(
            context,
            Routes.otpSignin,
            arguments: {
              'verificationId': verificationId,
              'mobile': phoneNumber,
              'resendToken': resendToken,
              'selectedRole': selectedRole,
            },
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("Auto-retrieval timeout.");
        },
      );
    } catch (e) {
      Navigator.pop(context);
      setState(() {
        isSigningIn = false;
      });
      UiHelper.showSnackBar(context, "Error: ${e.toString()}");
    }
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => dismissKeyBoard(context),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
                              // onTap: () => Navigator.pop(context),
                              child: Icon(Icons.arrow_back_ios_new, color: white),
                            ),
                          ),
                          Text('Sign In to Vandizone', style: whiteSemiBold22),
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
                          padding: const EdgeInsets.all(10),
                          physics: BouncingScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedRole = 0;
                                          role = 0;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: selectedRole == 0 ? primary.withOpacity(0.1) : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selectedRole == 0 ? primary : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Icon(Icons.person, color: selectedRole == 0 ? primary : Colors.grey),
                                            Image.asset(
                                              AssetImages.driver,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Captain',
                                              style: TextStyle(
                                                color: selectedRole == 0 ? primary : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedRole = 1;
                                          role = 1;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: selectedRole == 1 ? primary.withOpacity(0.1) : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selectedRole == 1 ? primary : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Icon(Icons.business, color: selectedRole == 1 ? primary : Colors.grey),
                                            Image.asset(
                                              AssetImages.owner1,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Owner',
                                              style: TextStyle(
                                                color: selectedRole == 1 ? primary : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome to the app', style: blackMedium20),
                                Gap(10),
                                Text(
                                  'Sign in with ${selectedRole == 0 ? 'Captain ID' : 'Owner ID'}',
                                  style: colorC4Regular16,
                                ),
                                Gap(40),

                                // Show Captain ID and Vehicle Number if selectedRole == 0
                                if (selectedRole == 0) ...[
                                  MyTextfield(
                                    header: 'Captain ID',
                                    controller: captainIdController,
                                    inputFormatters: [
                                      UpperCaseTextFormatter(),
                                    ],
                                    onTap: () {
                                      if (vehicleNumberController.text.isNotEmpty) {
                                        vehicleNumberController.clear();
                                      }
                                    },
                                  ),
                                  Gap(20),
                                  MyTextfield(
                                    header: 'Enter Vehicle Number',
                                    controller: vehicleNumberController,
                                    onTap: () {
                                      if (captainIdController.text.isNotEmpty) {
                                        captainIdController.clear();
                                      }
                                    },
                                  ),
                                ],

                                // Show only Owner ID if selectedRole != 0
                                if (selectedRole != 0) ...[
                                  MyTextfield(header: 'Owner ID',
                                    controller: ownerIdController,
                                    inputFormatters: [
                                      UpperCaseTextFormatter(),
                                    ],
                                  )
                                ],
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
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // MyElevatedButton(
                            //   title: "Sign In",
                            //   onPressed: () {
                            //     dismissKeyBoard(context);
                            //     Navigator.pushNamed(context, Routes.otp);
                            //   },
                            // ),
                            MyElevatedButton(
                              title: isSigningIn ? "Signing In..." : "Sign In",
                              onPressed: isSigningIn ? null : () async {
                                dismissKeyBoard(context);
                                await _loginWithCode();
                              },
                            ),
                            const SizedBox(height: 16), // Spacing between button and text
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "If you don’t have a Unique ID yet, please register below.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Click here to", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                                    TextButton(
                                      onPressed: () {
                                        dismissKeyBoard(context);
                                        Navigator.pushNamed(context, Routes.signUp);
                                      },
                                      child: Text(
                                        "Register",
                                        style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )

                          ],
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

  void _onInputChanged(v) {
    initialValue = v;
    setState(() {});
  }
}
