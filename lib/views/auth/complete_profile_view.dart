import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sizer/sizer.dart';
import '../../routes/routes.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../widgets/my_elevated_button.dart';
import '../../widgets/my_textfield.dart';

class CompleteProfileView extends StatelessWidget {
  const CompleteProfileView({super.key});

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
                          Text('Complete profile', style: whiteSemiBold22),
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
                            Text('Complete Your Profile', style: blackMedium20),
                            Gap(10),
                            Text(
                              'Dont worry it will be safe no one can change this.',
                              style: colorC4Regular16,
                            ),
                            Gap(40),
                            MyTextfield(header: 'Cab Brand'),
                            Gap(15),
                            MyTextfield(header: 'Cab Model'),
                            Gap(15),
                            MyTextfield(header: 'Vehicle Number'),
                            Gap(15),
                            MyTextfield(header: 'Government Id'),
                            Gap(15),
                            MyTextfield(header: 'Driving License'),
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
                          title: "Continue",
                          onPressed: () {
                            dismissKeyBoard(context);
                            Navigator.pushNamedAndRemoveUntil(
                                context, Routes.home, (route) => false);
                          },
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
