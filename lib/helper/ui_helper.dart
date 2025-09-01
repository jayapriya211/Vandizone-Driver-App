import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:vandizone_caption/utils/icon_size.dart';
import '../routes/routes.dart';
import '../utils/assets.dart';
import '../utils/constant.dart';
import '../widgets/my_elevated_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class UiHelper {
  static void showLoadingDialog(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        content: PopScope(
          canPop: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                primaryLoader,
                const Gap(20),
                Text('Please wait', style: primarySemiBold18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> sendCustomerBookingNotification({
    required String collection,
    required String bookingCode,
    required String eventType, // e.g. booking_started, booking_ended
    required String title,
    required String body,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not authenticated");

      final idToken = await user.getIdToken();

      final uri = Uri.parse("https://us-central1-vandizone-admin.cloudfunctions.net/sendBookingEventNotification");

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'collection': collection,
          'bookingCode': bookingCode,
          'eventType': eventType,
          'title': title,
          'body': body,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Notification sent successfully: $eventType");
      } else {
        print("❌ Notification failed: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      print("❌ Error sending notification: $e");
    }
  }


  static Future<bool?> showDeclinedRideDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Decline Ride", style: blackSemiBold20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Image.asset(AssetImages.cancelride, height: 85),
            ),
            Text(
              "Are you sure you want to\ndecline the ride",
              textAlign: TextAlign.center,
              style: colorABMedium18,
            ),
            Gap(25),
            Row(
              children: [
                Expanded(
                    child: MyElevatedButton(
                  isSecondary: true,
                  title: "Cancel",
                  onPressed: () => Navigator.pop(context),
                )),
                Gap(20),
                Expanded(
                    child: MyElevatedButton(
                  title: "Sure",
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                )),
              ],
            )
          ],
        ),
      ),
    );
  }

  static Future<void> showTripCompletedDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        contentPadding: const EdgeInsets.all(0),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Trip Completed", style: blackSemiBold20),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Image.asset(AssetImages.tripcompleted, height: 100),
              ),
              Text(
                "Trip completed review your trip now.",
                textAlign: TextAlign.center,
                style: colorABMedium18,
              ),
              Gap(25),
              MyElevatedButton(
                title: "Ok",
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  // static void changeProfileSheet(BuildContext context) {
  //   showModalBottomSheet(
  //     backgroundColor: transparent,
  //     context: context,
  //     builder: (context) {
  //       return Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Container(
  //             decoration: BoxDecoration(
  //               color: white,
  //               borderRadius: myBorderRadius(10),
  //             ),
  //             padding: const EdgeInsets.symmetric(vertical: 25),
  //             margin: const EdgeInsets.all(20),
  //             child: Column(
  //               children: [
  //                 Text('Choose Option', style: blackMedium20),
  //                 Gap(25),
  //                 Column(
  //                   children: List.generate(
  //                     3,
  //                     (index) {
  //                       bool isFirst = index == 0;
  //                       bool isSec = index == 1;
  //                       bool isLast = index == 2;
  //                       String icon = isFirst
  //                           ? AssetImages.option1
  //                           : isSec
  //                               ? AssetImages.option2
  //                               : AssetImages.option3;
  //                       String title = isFirst
  //                           ? 'Camera'
  //                           : isSec
  //                               ? 'Gallery'
  //                               : 'Delete';
  //                       return Column(
  //                         children: [
  //                           InkWell(
  //                             onTap: () => Navigator.pop(context),
  //                             child: Padding(
  //                               padding: const EdgeInsets.symmetric(horizontal: 20),
  //                               child: Row(
  //                                 children: [
  //                                   Image.asset(icon, height: IconSize.regular),
  //                                   Gap(15),
  //                                   Text(title, style: primaryMedium18)
  //                                 ],
  //                               ),
  //                             ),
  //                           ),
  //                           if (!isLast) const Divider(height: 30, color: colorF2, thickness: 1)
  //                         ],
  //                       );
  //                     },
  //                   ),
  //                 )
  //               ],
  //             ),
  //           ),
  //           Padding(
  //             padding: const EdgeInsets.all(20).copyWith(top: 0, bottom: 25),
  //             child: MyElevatedButton(
  //               title: 'Cancel',
  //               bgColor: white,
  //               textStyle: primaryMedium18,
  //               onPressed: () => Navigator.pop(context),
  //             ),
  //           )
  //         ],
  //       );
  //     },
  //   );
  // }
  static void changeProfileSheet(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: transparent,
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: myBorderRadius(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 25),
              margin: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Choose Option', style: blackMedium20),
                  Gap(25),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        // Do something with the image
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Image.asset(AssetImages.option2, height: IconSize.regular),
                          Gap(15),
                          Text('Gallery', style: primaryMedium18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20).copyWith(top: 0, bottom: 25),
              child: MyElevatedButton(
                title: 'Cancel',
                bgColor: white,
                textStyle: primaryMedium18,
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        );
      },
    );
  }


  static Future<void> showLogoutDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: white,
        contentPadding: EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Logout", style: blackSemiBold20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Image.asset(AssetImages.logout, height: 80),
            ),
            Text("Are you sure you want to logout?", style: colorABMedium18),
            Gap(25),
            Row(
              children: [
                Expanded(
                    child: MyElevatedButton(
                  title: 'Cancel',
                  isSecondary: true,
                  onPressed: () => Navigator.pop(context),
                )),
                Gap(20),
                Expanded(
                    child: MyElevatedButton(
                  title: 'Logout',
                  onPressed: () async{
                    // Navigator.pushNamedAndRemoveUntil(context, Routes.signIn, (route) => false);
                    await _performLogout(context);
                  },
                )),
              ],
            )
          ],
        ),
      ),
    );
  }

  static Future<void> _performLogout(BuildContext context) async {
    try {
      // Clear Firebase Auth session
      await FirebaseAuth.instance.signOut();

      // Clear all saved data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear any FCM tokens if needed (silently handle any errors)
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        print('Error deleting FCM token: $e');
        // Silently ignore FCM token deletion errors
      }

      // Navigate to sign in screen and remove all routes
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.signIn,
              (route) => false,
        );
      }
    } catch (e) {
      print('Logout error: $e');
      // Silently navigate to sign in even if there was an error
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.signIn,
              (route) => false,
        );
      }
    }
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: white),
        ),
        backgroundColor: isError ? Colors.red : primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: myBorderRadius(10),
        ),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showTopSnackBar(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry; // Declare it first

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isError ? Colors.red : primary,
              borderRadius: myBorderRadius(10),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (overlayEntry.mounted) {
                      overlayEntry.remove();
                    }
                  },
                  child: Text('OK', style: TextStyle(color: white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Show the snack bar
    overlay.insert(overlayEntry);

    // Auto-remove after 3 seconds
    Future.delayed(Duration(seconds: 3)).then((_) {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
