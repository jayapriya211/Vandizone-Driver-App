import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:vandizone_caption/utils/assets.dart';
import 'package:sizer/sizer.dart';

import '../../routes/routes.dart';
import '../../utils/constant.dart';

class OnBoardView extends StatelessWidget {
  const OnBoardView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Improved image section
              Expanded(
                flex: 6, // 60% of space
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    AssetImages.bhl,
                    width: double.infinity,
                    fit: BoxFit.contain, // or BoxFit.cover
                  ),
                ),
              ),
              // Content section
              Expanded(
                flex: 4, // 40% of space
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Earn Money With This Captain App',
                            style: primarySemiBold20,
                            textAlign: TextAlign.center,
                          ),
                          const Gap(15),
                          Text(
                            'Accepting available rides nearest your location\nand earn money easily.',
                            style: colorABMedium16.copyWith(height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      CircularPercentIndicator(
                        radius: 38,
                        lineWidth: 4.0,
                        circularStrokeCap: CircularStrokeCap.square,
                        percent: 1,
                        animation: true,
                        animateFromLastPercent: true,
                        progressColor: primary,
                        backgroundColor: colorD9,
                        animateToInitialPercent: false,
                        center: CupertinoButton(
                          pressedOpacity: 0.8,
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).popAndPushNamed(Routes.signIn),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: primary,
                            child: Icon(Icons.arrow_forward, color: white),
                          ),
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