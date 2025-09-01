import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../components/my_appbar.dart';
import '../../../utils/constant.dart';
import '../../../widgets/my_elevated_button.dart';
import '../../../widgets/my_textfield.dart';

class InvFriendsView extends StatelessWidget {
  const InvFriendsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Invite Friend'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              children: [
                Container(
                  color: secoBtnColor,
                  padding: EdgeInsets.symmetric(vertical: 25, horizontal: 40),
                  child: Column(
                    children: [
                      Text("Share Referral Code", style: primaryMedium20),
                      Gap(15),
                      Text(
                        "Share your referral code with your friends &\nfamily and get \$11.00 on first ride\nbooked by them.",
                        style: colorABMedium16,
                        textAlign: TextAlign.center,
                      ),
                      Gap(20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MyElevatedButton(
                            title: 'UD254585',
                            width: 165,
                            height: 60,
                            textStyle: whiteSemiBold22,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Gap(25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enter Promo Code', style: blackMedium20),
                      Gap(10),
                      Text(
                        'Enter promo code to avail exciting offers &\ndiscounts on your rides',
                        style: colorABRegular16,
                      ),
                      Gap(20),
                      MyTextfield(hintText: "Enter code here"),
                      Gap(30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MyElevatedButton(
                            isSecondary: true,
                            title: 'Apply',
                            width: 177,
                            height: 54,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.vertical(top: myRadius(20)),
                boxShadow: [BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))]),
            padding: const EdgeInsets.all(20),
            child: MyElevatedButton(
              title: "Share Code",
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        ],
      ),
    );
  }
}
