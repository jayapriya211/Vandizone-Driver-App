import 'package:flutter/material.dart';

class DrawerItem {
  final String title;
  final String icon;
  final String? navigateTo;
  final VoidCallback? onPressed;

  const DrawerItem({required this.title, required this.icon, this.navigateTo, this.onPressed});
}
