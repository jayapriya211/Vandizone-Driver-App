import 'package:flutter/material.dart';
import '../utils/constant.dart';

class MyDropdownField<T> extends StatelessWidget {
  final String? header;
  final TextStyle? headerStyle;
  final String? hintText;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;

  const MyDropdownField({
    super.key,
    this.header,
    this.headerStyle,
    this.hintText,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(header!, style: headerStyle ?? blackRegular18),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: white,
            borderRadius: myBorderRadius(10),
            boxShadow: [boxShadow1],
          ),
          child: DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: InputDecoration(
              isDense: true, // reduces height
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // tighter padding
              hintText: hintText ?? "Select ${header?.toLowerCase()}",
              hintStyle: colorABRegular16,
            ),
            items: items,
            onChanged: onChanged,
            validator: validator,
            style: blackRegular16,
            dropdownColor: white,
          ),
        ),
      ],
    );
  }
}
