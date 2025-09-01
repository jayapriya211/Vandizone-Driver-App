//* Spinkit Loader
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:sizer/sizer.dart';

final primaryLoader = SpinKitRing(color: primary, lineWidth: 2.5, size: 4.25.h);

//* Colors
const Color white = Color(0xffFFFFFF);
const Color amber = Color(0xffFAB41D);
const Color grey = Colors.grey;
const Color red = Color(0xffBD2E2E);
const Color green = Colors.green;
const Color black = Color(0xff333333);
const Color transparent = Colors.transparent;
// const Color primary = Color(Color(0xFFC91515)); //owner
Color get primary => role == 0 ? const Color(0xFF2ECC71) : const Color(0xFFC91515);
const Color secondaryColor = Color(0xffCEE9E6);
const Color secoBtnColor = Color(0xFFD5E8D4);
const Color scaffoldColor = Color(0xffF6F6F6);
const Color colorC4 = Color(0xffC4C4C4);
const Color colorD4 = Color(0xffD4D4D4);
const Color color94 = Color(0xff949494);
const Color colorAB = Color(0xffABABAB);
const Color colorE9 = Color(0xffE9E5E5);
const Color colorB4 = Color(0xffB4B4B4);
const Color colorF6 = Color(0xffF6F6F6);
const Color colorD9 = Color(0xffD9D9D9);
const Color colorF2 = Color(0xffF2F2F2);
Color bgColor = Color(0xffeaeaea);

// Regular
TextStyle primaryRegular14 = TextStyle(fontFamily: 'R', fontSize: 14.45.sp, color: primary);
TextStyle colorABRegular14 = TextStyle(fontFamily: 'R', fontSize: 14.45.sp, color: colorAB);
TextStyle colorABRegular15 = TextStyle(fontFamily: 'R', fontSize: 14.95.sp, color: colorAB);
TextStyle colorC4Regular16 = TextStyle(fontFamily: 'R', fontSize: 15.40.sp, color: colorC4);
TextStyle color94Regular16 = TextStyle(fontFamily: 'R', fontSize: 15.40.sp, color: color94);
TextStyle blackRegular16 = TextStyle(fontFamily: 'R', fontSize: 15.40.sp, color: black);
TextStyle colorABRegular16 = TextStyle(fontFamily: 'R', fontSize: 15.40.sp, color: colorAB);
TextStyle blackRegular18 = TextStyle(fontFamily: 'R', fontSize: 16.35.sp, color: black);
// Medium
TextStyle colorABMedium14 = TextStyle(fontFamily: 'M', fontSize: 14.45.sp, color: colorAB);
TextStyle blackMedium14 = TextStyle(fontFamily: 'M', fontSize: 14.45.sp, color: black);
TextStyle redMedium14 = TextStyle(fontFamily: 'M', fontSize: 14.45.sp, color: red);
TextStyle primaryMedium14 = TextStyle(fontFamily: 'M', fontSize: 14.45.sp, color: primary);
TextStyle whiteMedium14 = TextStyle(fontFamily: 'M', fontSize: 14.45.sp, color: white);
TextStyle whiteMedium15 = TextStyle(fontFamily: 'M', fontSize: 14.95.sp, color: white);
TextStyle colorABMedium15 = TextStyle(fontFamily: 'M', fontSize: 14.95.sp, color: colorAB);
TextStyle blackMedium15 = TextStyle(fontFamily: 'M', fontSize: 14.95.sp, color: black);
TextStyle redMedium16 = TextStyle(fontFamily: 'M', fontSize: 15.40.sp, color: red);
TextStyle colorABMedium16 = TextStyle(fontFamily: 'M', fontSize: 15.40.sp, color: colorAB);
TextStyle whiteMedium16 = TextStyle(fontFamily: 'M', fontSize: 15.40.sp, color: white);
TextStyle primaryMedium16 = TextStyle(fontFamily: 'M', fontSize: 15.40.sp, color: primary);
TextStyle primaryMedium17 = TextStyle(fontFamily: 'M', fontSize: 15.80.sp, color: primary);
TextStyle primaryMedium18 = TextStyle(fontFamily: 'M', fontSize: 16.35.sp, color: primary);
TextStyle blackMedium16 = TextStyle(fontFamily: 'M', fontSize: 15.40.sp, color: black);
TextStyle colorABMedium18 = TextStyle(fontFamily: 'M', fontSize: 16.35.sp, color: colorAB);
TextStyle whiteMedium18 = TextStyle(fontFamily: 'M', fontSize: 16.35.sp, color: white);
TextStyle blackMedium18 = TextStyle(fontFamily: 'M', fontSize: 16.35.sp, color: black);
TextStyle blackMedium20 = TextStyle(fontFamily: 'M', fontSize: 17.15.sp, color: black);
TextStyle whiteMedium20 = TextStyle(fontFamily: 'M', fontSize: 17.15.sp, color: white);
TextStyle primaryMedium20 = TextStyle(fontFamily: 'M', fontSize: 17.15.sp, color: primary);
TextStyle colorABMedium20 = TextStyle(fontFamily: 'M', fontSize: 17.15.sp, color: colorAB);
// SemiBold
TextStyle appNameStyle = TextStyle(fontFamily: 'SB', fontSize: 21.sp, color: white);
TextStyle colorC4SemiBold14 = TextStyle(fontFamily: 'SB', fontSize: 14.45.sp, color: colorC4);
TextStyle colorABSemiBold14 = TextStyle(fontFamily: 'SB', fontSize: 14.45.sp, color: colorAB);
TextStyle blackSemiBold14 = TextStyle(fontFamily: 'SB', fontSize: 14.45.sp, color: black);
TextStyle whiteSemiBold14 = TextStyle(fontFamily: 'SB', fontSize: 14.45.sp, color: white);
TextStyle primarySemiBold14 = TextStyle(fontFamily: 'SB', fontSize: 14.45.sp, color: primary);
TextStyle primarySemiBold15 = TextStyle(fontFamily: 'SB', fontSize: 14.95.sp, color: primary);
TextStyle whiteSemiBold15 = TextStyle(fontFamily: 'SB', fontSize: 14.95.sp, color: white);
TextStyle colorABSemiBold15 = TextStyle(fontFamily: 'SB', fontSize: 14.95.sp, color: colorAB);
TextStyle colorABSemiBold16 = TextStyle(fontFamily: 'SB', fontSize: 15.40.sp, color: colorAB);
TextStyle whiteSemiBold16 = TextStyle(fontFamily: 'SB', fontSize: 15.40.sp, color: white);
TextStyle primarySemiBold16 = TextStyle(fontFamily: 'SB', fontSize: 15.40.sp, color: primary);
TextStyle blackSemiBold16 = TextStyle(fontFamily: 'SB', fontSize: 15.40.sp, color: black);
TextStyle whiteSemiBold18 = TextStyle(fontFamily: 'SB', fontSize: 16.35.sp, color: white);
TextStyle blackSemiBold18 = TextStyle(fontFamily: 'SB', fontSize: 16.35.sp, color: black);
TextStyle colorABSemiBold18 = TextStyle(fontFamily: 'SB', fontSize: 16.35.sp, color: colorAB);
TextStyle primarySemiBold18 = TextStyle(fontFamily: 'SB', fontSize: 16.35.sp, color: primary);
TextStyle primarySemiBold20 = TextStyle(fontFamily: 'SB', fontSize: 17.15.sp, color: primary);
TextStyle whiteSemiBold20 = TextStyle(fontFamily: 'SB', fontSize: 17.15.sp, color: white);
TextStyle blackSemiBold20 = TextStyle(fontFamily: 'SB', fontSize: 17.15.sp, color: black);
TextStyle whiteSemiBold22 = TextStyle(fontFamily: 'SB', fontSize: 17.95.sp, color: white);
TextStyle blackSemiBold22 = TextStyle(fontFamily: 'SB', fontSize: 17.95.sp, color: black);
TextStyle primarySemiBold25 = TextStyle(fontFamily: 'SB', fontSize: 19.25.sp, color: primary);
TextStyle whiteSemiBold25 = TextStyle(fontFamily: 'SB', fontSize: 19.25.sp, color: white);

Radius myRadius(double radius) => Radius.circular(radius);
BorderRadius myBorderRadius(double radius) => BorderRadius.circular(radius);

BoxShadow boxShadow1 = BoxShadow(
  color: black.withValues(alpha: 0.15),
  blurRadius: 6,
);

String getControllerText(TextEditingController textEditC) => textEditC.text.trim();

void dismissKeyBoard(BuildContext context) => FocusManager.instance.primaryFocus?.unfocus();

bool isbackhoe = true;

int role = 0;