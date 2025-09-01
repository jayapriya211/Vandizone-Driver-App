import 'package:flutter/material.dart';
import '../utils/constant.dart';
import 'package:flutter/services.dart';

class MyTextfield extends StatelessWidget {
  final String? header;
  final TextStyle? headerStyle;
  final FocusNode? focusNode;
  final String? hintText;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const MyTextfield({
    super.key,
    this.header,
    this.headerStyle,
    this.maxLines,
    this.focusNode,
    this.hintText,
    this.textInputAction,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.controller,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(header.toString(), style: headerStyle ?? blackRegular18),
          ),
        Container(
            padding: EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: white,
              borderRadius: myBorderRadius(10),
              boxShadow: [boxShadow1],
            ),
            child: TextFormField(
              maxLines: maxLines,
              focusNode: focusNode,
              style: blackRegular16,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              maxLength: maxLength,
              controller: controller,
              inputFormatters: inputFormatters,
              validator: validator,
              onChanged: onChanged,
              readOnly: readOnly,
              onTap: onTap,
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true, // helps tightly wrap the content
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                // contentPadding: maxLines != null
                //     ? const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                //     : const EdgeInsets.symmetric(horizontal: 20),
                hintText: hintText ?? "Enter ${header?.toLowerCase()}",
                hintStyle: colorABRegular16,
                suffixIcon: suffixIcon,
              ),
            )),
      ],
    );
  }
}
