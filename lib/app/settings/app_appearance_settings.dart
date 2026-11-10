import 'package:flutter/material.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/app/theme/app_theme_family.dart';

enum AppBrightnessPreference {
  light,
  dark,
  system;

  ThemeMode get themeMode {
    return switch (this) {
      AppBrightnessPreference.light => ThemeMode.light,
      AppBrightnessPreference.dark => ThemeMode.dark,
      AppBrightnessPreference.system => ThemeMode.system,
    };
  }
}

enum AppLanguage { system, simplifiedChinese, traditionalChinese }

class AppAppearanceSettings {
  const AppAppearanceSettings({
    this.colorSource = AppThemeColorSource.preset,
    this.themeFamily = AppThemeFamily.warmPaper,
    this.navigationBarStyle = AppNavigationBarStyle.immersive,
    this.navigationSwipeEnabled = true,
    this.brightnessPreference = AppBrightnessPreference.light,
    required this.languagePreference,
  });

  factory AppAppearanceSettings.defaults() {
    return const AppAppearanceSettings(
      themeFamily: AppThemeFamily.warmPaper,
      navigationBarStyle: AppNavigationBarStyle.immersive,
      navigationSwipeEnabled: true,
      brightnessPreference: AppBrightnessPreference.light,
      languagePreference: AppLanguage.system,
    );
  }

  final AppThemeFamily themeFamily;
  final AppThemeColorSource colorSource;
  final AppNavigationBarStyle navigationBarStyle;
  final bool navigationSwipeEnabled;
  final AppBrightnessPreference brightnessPreference;
  final AppLanguage languagePreference;

  ThemeMode get themeMode => brightnessPreference.themeMode;

  AppAppearanceSettings copyWith({
    AppThemeColorSource? colorSource,
    AppThemeFamily? themeFamily,
    AppNavigationBarStyle? navigationBarStyle,
    bool? navigationSwipeEnabled,
    AppBrightnessPreference? brightnessPreference,
    AppLanguage? languagePreference,
  }) {
    return AppAppearanceSettings(
      colorSource: colorSource ?? this.colorSource,
      themeFamily: themeFamily ?? this.themeFamily,
      navigationBarStyle: navigationBarStyle ?? this.navigationBarStyle,
      navigationSwipeEnabled:
          navigationSwipeEnabled ?? this.navigationSwipeEnabled,
      brightnessPreference: brightnessPreference ?? this.brightnessPreference,
      languagePreference: languagePreference ?? this.languagePreference,
    );
  }
}
