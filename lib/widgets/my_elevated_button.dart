import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../utils/constant.dart';
import '../utils/icon_size.dart';

class MyElevatedButton extends StatelessWidget {
  final String title;
  final Color? bgColor;
  final String? icon;
  final String? navigateTo;
  final double? width;
  final double? height;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isSecondary;
  final TextStyle? textStyle;
  const MyElevatedButton({
    super.key,
    required this.title,
    this.bgColor,
    this.icon,
    this.navigateTo,
    this.onPressed,
    this.isEnabled = true,
    this.width,
    this.height,
    this.textStyle,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = this.textStyle ?? (isSecondary ? primarySemiBold20 : whiteSemiBold20);
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bgColor ?? (isSecondary ? secoBtnColor : primary),
          minimumSize: Size(width ?? 100.w, height ?? 54),
          shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
          overlayColor: textStyle.color,
        ),
        onPressed: isEnabled
            ? navigateTo != null
                ? () => Navigator.of(context).pushNamed(navigateTo!)
                : onPressed ?? () {}
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Image.asset(icon!, height: IconSize.regular),
              ),
            Text(title, style: textStyle),
          ],
        ));
  }
}
