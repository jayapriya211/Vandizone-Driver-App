import 'package:flutter/material.dart';
import '../utils/constant.dart';
import '../utils/icon_size.dart';

class MyTheme {
  static final lightTheme = ThemeData(
    splashColor: transparent,
    highlightColor: transparent,
    iconTheme: IconThemeData(color: black, size: IconSize.regular),
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    scaffoldBackgroundColor: white,
    useMaterial3: false,
    
  );
}
