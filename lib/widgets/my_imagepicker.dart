import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/constant.dart';

class MyImagePickerField extends StatelessWidget {
  final String? header;
  final TextStyle? headerStyle;
  final String? imageName;
  final VoidCallback? onTap;

  const MyImagePickerField({
    super.key,
    this.header,
    this.headerStyle,
    this.imageName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(header!, style: headerStyle ?? blackRegular18),
          ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: white,
              borderRadius: myBorderRadius(10),
              boxShadow: [boxShadow1],
            ),
            child: Text(
              imageName ?? "Select image",
              style: imageName != null ? blackRegular16 : colorABRegular16,
            ),
          ),
        ),
      ],
    );
  }
}
