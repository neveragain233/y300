import 'package:flutter/material.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/settings/app_navigation_lens_motion.dart';
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
    this.navigationLensMotion = AppNavigationLensMotion.followPress,
    this.glassLevel = AppGlassLevel.standard,
    this.brightnessPreference = AppBrightnessPreference.light,
    required this.languagePreference,
    this.boldFont = false,
    this.volumePaging = true,
    this.edgeTapPaging = false,
    this.ireaderRipple = true,
  });

  factory AppAppearanceSettings.defaults() {
    return const AppAppearanceSettings(
      themeFamily: AppThemeFamily.warmPaper,
      navigationBarStyle: AppNavigationBarStyle.immersive,
      navigationSwipeEnabled: true,
      navigationLensMotion: AppNavigationLensMotion.followPress,
      glassLevel: AppGlassLevel.standard,
      brightnessPreference: AppBrightnessPreference.light,
      languagePreference: AppLanguage.system,
      boldFont: false,
      volumePaging: true,
      edgeTapPaging: false,
      ireaderRipple: true,
    );
  }

  final AppThemeFamily themeFamily;
  final AppThemeColorSource colorSource;
  final AppNavigationBarStyle navigationBarStyle;
  final bool navigationSwipeEnabled;

  /// 底栏透镜的跟随方式；默认按下即跟随，对齐 FlClash。
  final AppNavigationLensMotion navigationLensMotion;
  final AppGlassLevel glassLevel;
  final AppBrightnessPreference brightnessPreference;
  final AppLanguage languagePreference;
  final bool boldFont;
  final bool volumePaging;
  final bool edgeTapPaging;
  final bool ireaderRipple;

  ThemeMode get themeMode => brightnessPreference.themeMode;

  AppAppearanceSettings copyWith({
    AppThemeColorSource? colorSource,
    AppThemeFamily? themeFamily,
    AppNavigationBarStyle? navigationBarStyle,
    bool? navigationSwipeEnabled,
    AppNavigationLensMotion? navigationLensMotion,
    AppGlassLevel? glassLevel,
    AppBrightnessPreference? brightnessPreference,
    AppLanguage? languagePreference,
    bool? boldFont,
    bool? volumePaging,
    bool? edgeTapPaging,
    bool? ireaderRipple,
  }) {
    return AppAppearanceSettings(
      colorSource: colorSource ?? this.colorSource,
      themeFamily: themeFamily ?? this.themeFamily,
      navigationBarStyle: navigationBarStyle ?? this.navigationBarStyle,
      navigationSwipeEnabled:
          navigationSwipeEnabled ?? this.navigationSwipeEnabled,
      navigationLensMotion: navigationLensMotion ?? this.navigationLensMotion,
      glassLevel: glassLevel ?? this.glassLevel,
      brightnessPreference: brightnessPreference ?? this.brightnessPreference,
      languagePreference: languagePreference ?? this.languagePreference,
      boldFont: boldFont ?? this.boldFont,
      volumePaging: volumePaging ?? this.volumePaging,
      edgeTapPaging: edgeTapPaging ?? this.edgeTapPaging,
      ireaderRipple: ireaderRipple ?? this.ireaderRipple,
    );
  }
}
