import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppSystemUi {
  static SystemUiOverlayStyle onSurfaces({
    required Color top,
    required Color bottom,
  }) {
    final topBrightness = ThemeData.estimateBrightnessForColor(top);
    final bottomBrightness = ThemeData.estimateBrightnessForColor(bottom);
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: topBrightness,
      statusBarIconBrightness: _icons(topBrightness),
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: _icons(bottomBrightness),
    );
  }

  static Brightness _icons(Brightness surface) =>
      surface == Brightness.dark ? Brightness.light : Brightness.dark;
}
