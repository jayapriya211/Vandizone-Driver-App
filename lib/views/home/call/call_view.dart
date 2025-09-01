import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:sizer/sizer.dart';

import '../../../utils/assets.dart';
import '../../../utils/constant.dart';

class CallView extends StatelessWidget {
  const CallView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          height: 100.h,
          width: double.maxFinite,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ExactAssetImage(AssetImages.callbg),
              fit: BoxFit.cover,
            ),
          ),
          child: ClipRRect(
            // make sure we apply clip it properly
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22.5, sigmaY: 22.5),
              child: Container(
                alignment: Alignment.center,
                color: black.withValues(alpha: 0.25),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text("Easther Howard", style: whiteSemiBold25),
                          Gap(10),
                          Text("15:30", style: whiteMedium20),
                          Gap(50),
                        ],
                      ),
                      Gap(33.h),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              3,
                              (index) {
                                return CircleAvatar(
                                  radius: 40,
                                  backgroundColor: black.withValues(alpha: 0.5),
                                  child: Image.asset(
                                    index == 0
                                        ? AssetImages.microphone
                                        : index == 1
                                            ? AssetImages.videocall
                                            : AssetImages.volume,
                                  ),
                                );
                              },
                            ),
                          ),
                          Gap(40),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Color(0xffFF0202),
                              child: Image.asset(AssetImages.callend),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
