import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../routes/routes.dart';
import '../../../utils/constant.dart';
import '../../utils/assets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    // Future.delayed(const Duration(seconds: 3), () {
    //   if (!mounted) return;
    //   Navigator.popAndPushNamed(context, Routes.onBoard);
    // });
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getString('userCode');
    final selectedRole = prefs.getInt('selectedRole') ?? 0;
    setState(() {
      role = selectedRole;
    });
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && userCode != null) {
      try {
        // Check based on userCode instead of UID
        if (selectedRole == 0) { // Captain
          final captainSnapshot = await FirebaseFirestore.instance
              .collection('captains')
              .where('userCode', isEqualTo: userCode)
              .limit(1)
              .get();

          if (captainSnapshot.docs.isNotEmpty) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.mainhome,
                  (route) => false,
            );
            return;
          }
        } else { // Owner
          final ownerSnapshot = await FirebaseFirestore.instance
              .collection('owners')
              .where('userCode', isEqualTo: userCode)
              .limit(1)
              .get();

          if (ownerSnapshot.docs.isNotEmpty) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.homeowner,
                  (route) => false,
            );
            return;
          }
        }

        // If userCode not found in the expected collection
        _navigateToOnboarding();
      } catch (e) {
        print('Error checking user role: $e');
        _navigateToOnboarding();
      }
    } else {
      // No user logged in or no userCode found
      _navigateToOnboarding();
    }
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.onBoard,
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: primary,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("------- Driver App -------", style: whiteMedium18),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Center _body() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(AssetImages.logosplash, height: 12.5.h),
        ],
      ),
    );
  }
}
