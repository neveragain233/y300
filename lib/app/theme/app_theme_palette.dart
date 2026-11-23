import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_tokens.dart';

/// Concrete light/dark color palette used to build Material semantics.
///
/// Keep stable shell colors in [AppThemeTokens]; this palette is where those
/// baselines are expanded into the Material color roles used by ThemeData.
@immutable
final class AppThemePalette {
  const AppThemePalette({
    this.isDynamic = false,
    this.isEInk = false,
    required this.family,
    required this.brightness,
    required this.seedColor,
    required this.scaffoldBackground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.navigationBarBackground,
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
  });

  factory AppThemePalette.dynamic(ColorScheme scheme, AppThemeFamily fallback) {
    return AppThemePalette(
      family: fallback,
      isDynamic: true,
      brightness: scheme.brightness,
      seedColor: scheme.primary,
      scaffoldBackground: scheme.surface,
      appBarBackground: scheme.surfaceContainer,
      appBarForeground: scheme.onSurface,
      navigationBarBackground: scheme.surfaceContainer,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      surfaceContainerLowest: scheme.surfaceContainerLowest,
      surfaceContainerLow: scheme.surfaceContainerLow,
      surfaceContainer: scheme.surfaceContainerLow,
      surfaceContainerHigh: scheme.surfaceContainerHigh,
      surfaceContainerHighest: scheme.surfaceContainerHigh,
      surfaceBright: scheme.surfaceBright,
      surfaceDim: scheme.surfaceDim,
      onSurfaceVariant: scheme.onSurfaceVariant,
      outlineVariant: scheme.outlineVariant,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      secondaryContainer: scheme.secondaryContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
    );
  }

  factory AppThemePalette.resolve(
    AppThemeFamily family,
    Brightness brightness,
  ) {
    return switch ((family, brightness)) {
      (AppThemeFamily.warmPaper, Brightness.light) => AppThemePalette.light(),
      (AppThemeFamily.warmPaper, Brightness.dark) => AppThemePalette.dark(),
      (AppThemeFamily.moonWhite, Brightness.light) =>
        AppThemePalette.moonWhiteLight(),
      (AppThemeFamily.moonWhite, Brightness.dark) =>
        AppThemePalette.moonWhiteDark(),
      (AppThemeFamily.plumPurple, Brightness.light) =>
        AppThemePalette.plumPurpleLight(),
      (AppThemeFamily.plumPurple, Brightness.dark) =>
        AppThemePalette.plumPurpleDark(),
    };
  }

  /// 墨水屏高对比色板：纯白底黑字，深色模式纯黑底白字。
  ///
  /// 与手机端三套预设无关。正文、标题、图标与选中态使用纯黑/纯白两档，
  /// 次级表面保留少量中性灰以区分卡片、面板与分隔线，不引入任何彩色。
  factory AppThemePalette.eInk() {
    return const AppThemePalette(
      family: AppThemeFamily.warmPaper,
      isEInk: true,
      brightness: Brightness.light,
      seedColor: Color(0xFF000000),
      scaffoldBackground: Color(0xFFFFFFFF),
      appBarBackground: Color(0xFFFFFFFF),
      appBarForeground: Color(0xFF000000),
      navigationBarBackground: Color(0xFFFFFFFF),
      primary: Color(0xFF000000),
      onPrimary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF000000),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFFFFFF),
      surfaceContainer: Color(0xFFF5F5F5),
      surfaceContainerHigh: Color(0xFFE8E8E8),
      surfaceContainerHighest: Color(0xFFE8E8E8),
      surfaceBright: Color(0xFFFFFFFF),
      surfaceDim: Color(0xFFE8E8E8),
      onSurfaceVariant: Color(0xFF2E2E2E),
      outlineVariant: Color(0xFF9A9A9A),
      primaryContainer: Color(0xFFFFFFFF),
      onPrimaryContainer: Color(0xFF000000),
      secondaryContainer: Color(0xFFE4E4E4),
      onSecondaryContainer: Color(0xFF000000),
      tertiaryContainer: Color(0xFFE8E8E8),
      onTertiaryContainer: Color(0xFF000000),
    );
  }

  factory AppThemePalette.eInkDark() {
    return const AppThemePalette(
      family: AppThemeFamily.warmPaper,
      isEInk: true,
      brightness: Brightness.dark,
      seedColor: Color(0xFF000000),
      scaffoldBackground: Color(0xFF000000),
      appBarBackground: Color(0xFF000000),
      appBarForeground: Color(0xFFFFFFFF),
      navigationBarBackground: Color(0xFF000000),
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      surfaceContainerLowest: Color(0xFF000000),
      surfaceContainerLow: Color(0xFF000000),
      surfaceContainer: Color(0xFF141414),
      surfaceContainerHigh: Color(0xFF242424),
      surfaceContainerHighest: Color(0xFF242424),
      surfaceBright: Color(0xFF000000),
      surfaceDim: Color(0xFF242424),
      onSurfaceVariant: Color(0xFFD0D0D0),
      outlineVariant: Color(0xFF6A6A6A),
      primaryContainer: Color(0xFF000000),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF2A2A2A),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF242424),
      onTertiaryContainer: Color(0xFFFFFFFF),
    );
  }

  factory AppThemePalette.light() {
    return const AppThemePalette(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.light,
      seedColor: AppThemeTokens.seedColor,
      scaffoldBackground: AppThemeTokens.scaffoldBackground,
      appBarBackground: AppThemeTokens.appBarBackground,
      appBarForeground: AppThemeTokens.appBarForeground,
      navigationBarBackground: AppThemeTokens.navigationBarBackground,
      primary: AppThemeTokens.seedColor,
      onPrimary: Color(0xFFFFF8EE),
      surface: AppThemeTokens.scaffoldBackground,
      onSurface: Color(0xFF2F2117),
      surfaceContainerLowest: Color(0xFFFFFCF0),
      surfaceContainerLow: Color(0xFFFFF6E4),
      surfaceContainer: AppThemeTokens.forumWebviewSectionBackground,
      surfaceContainerHigh: Color(0xFFF6E9D2),
      surfaceContainerHighest: Color(0xFFEFE1CD),
      surfaceBright: Color(0xFFFFFCF0),
      surfaceDim: Color(0xFFE8DAC4),
      onSurfaceVariant: Color(0xFF6F5B46),
      outlineVariant: Color(0xFFE0C9A8),
      primaryContainer: Color(0xFFF7DFB8),
      onPrimaryContainer: Color(0xFF3F230F),
      secondaryContainer: AppThemeTokens.navigationBarBackground,
      onSecondaryContainer: Color(0xFF3F230F),
      tertiaryContainer: Color(0xFFE9DFC9),
      onTertiaryContainer: Color(0xFF3E3222),
    );
  }

  factory AppThemePalette.dark() {
    return const AppThemePalette(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.dark,
      seedColor: AppThemeTokens.seedColor,
      scaffoldBackground: Color(0xFF17110F),
      appBarBackground: Color(0xFF2A0903),
      appBarForeground: Color(0xFFFFEDE0),
      navigationBarBackground: Color(0xFF241412),
      primary: Color(0xFFE8B884),
      onPrimary: Color(0xFF3A1604),
      surface: Color(0xFF17110F),
      onSurface: Color(0xFFF6E8DD),
      surfaceContainerLowest: Color(0xFF100B09),
      surfaceContainerLow: Color(0xFF1D1512),
      surfaceContainer: Color(0xFF241916),
      surfaceContainerHigh: Color(0xFF2F221D),
      surfaceContainerHighest: Color(0xFF3A2A25),
      surfaceBright: Color(0xFF3A2A25),
      surfaceDim: Color(0xFF120D0B),
      onSurfaceVariant: Color(0xFFD7C2B6),
      outlineVariant: Color(0xFF5A453D),
      primaryContainer: Color(0xFF5C3B1E),
      onPrimaryContainer: Color(0xFFFFE6C8),
      secondaryContainer: Color(0xFF4A342C),
      onSecondaryContainer: Color(0xFFFFE1D2),
      tertiaryContainer: Color(0xFF3B3126),
      onTertiaryContainer: Color(0xFFE8DCCB),
    );
  }

  factory AppThemePalette.moonWhiteLight() {
    return const AppThemePalette(
      family: AppThemeFamily.moonWhite,
      brightness: Brightness.light,
      seedColor: Color(0xFF4E6D93),
      scaffoldBackground: Color(0xFFF3F6FA),
      appBarBackground: Color(0xFF2E3F5A),
      appBarForeground: Color(0xFFF8FAFD),
      navigationBarBackground: Color(0xFFE4EAF2),
      primary: Color(0xFF4E6D93),
      onPrimary: Color(0xFFFFFFFF),
      surface: Color(0xFFF3F6FA),
      onSurface: Color(0xFF202934),
      surfaceContainerLowest: Color(0xFFFCFDFE),
      surfaceContainerLow: Color(0xFFF6F9FC),
      surfaceContainer: Color(0xFFF8FAFC),
      surfaceContainerHigh: Color(0xFFEDF2F7),
      surfaceContainerHighest: Color(0xFFE4EAF2),
      surfaceBright: Color(0xFFFCFDFE),
      surfaceDim: Color(0xFFDCE4EE),
      onSurfaceVariant: Color(0xFF667487),
      outlineVariant: Color(0xFFCAD4E0),
      primaryContainer: Color(0xFFD9E6F4),
      onPrimaryContainer: Color(0xFF1B3048),
      secondaryContainer: Color(0xFFDFE8F2),
      onSecondaryContainer: Color(0xFF263C55),
      tertiaryContainer: Color(0xFFE2E8F0),
      onTertiaryContainer: Color(0xFF2B384A),
    );
  }

  factory AppThemePalette.moonWhiteDark() {
    return const AppThemePalette(
      family: AppThemeFamily.moonWhite,
      brightness: Brightness.dark,
      seedColor: Color(0xFFAFC8E6),
      scaffoldBackground: Color(0xFF121820),
      appBarBackground: Color(0xFF1B2A3D),
      appBarForeground: Color(0xFFF2F6FB),
      navigationBarBackground: Color(0xFF1D2B3A),
      primary: Color(0xFFAFC8E6),
      onPrimary: Color(0xFF18324D),
      surface: Color(0xFF121820),
      onSurface: Color(0xFFEAF0F7),
      surfaceContainerLowest: Color(0xFF0D131A),
      surfaceContainerLow: Color(0xFF151D26),
      surfaceContainer: Color(0xFF19222D),
      surfaceContainerHigh: Color(0xFF202B38),
      surfaceContainerHighest: Color(0xFF263444),
      surfaceBright: Color(0xFF263444),
      surfaceDim: Color(0xFF0E141B),
      onSurfaceVariant: Color(0xFFB6C2D0),
      outlineVariant: Color(0xFF3D4D60),
      primaryContainer: Color(0xFF28415D),
      onPrimaryContainer: Color(0xFFDEEBF8),
      secondaryContainer: Color(0xFF293D53),
      onSecondaryContainer: Color(0xFFDDEAF6),
      tertiaryContainer: Color(0xFF26313E),
      onTertiaryContainer: Color(0xFFD6E0EC),
    );
  }

  factory AppThemePalette.plumPurpleLight() {
    return const AppThemePalette(
      family: AppThemeFamily.plumPurple,
      brightness: Brightness.light,
      seedColor: Color(0xFF8B5D70),
      scaffoldBackground: Color(0xFFF8F1F4),
      appBarBackground: Color(0xFF67404F),
      appBarForeground: Color(0xFFFFF8FA),
      navigationBarBackground: Color(0xFFEBDDE3),
      primary: Color(0xFF8B5D70),
      onPrimary: Color(0xFFFFFFFF),
      surface: Color(0xFFF8F1F4),
      onSurface: Color(0xFF34252B),
      surfaceContainerLowest: Color(0xFFFFFCFD),
      surfaceContainerLow: Color(0xFFFFF5F8),
      surfaceContainer: Color(0xFFFFF8FA),
      surfaceContainerHigh: Color(0xFFF5E8ED),
      surfaceContainerHighest: Color(0xFFF0E1E7),
      surfaceBright: Color(0xFFFFFCFD),
      surfaceDim: Color(0xFFE7D6DD),
      onSurfaceVariant: Color(0xFF7D6871),
      outlineVariant: Color(0xFFDCC8D0),
      primaryContainer: Color(0xFFF2DBE4),
      onPrimaryContainer: Color(0xFF472534),
      secondaryContainer: Color(0xFFECDDE3),
      onSecondaryContainer: Color(0xFF52323F),
      tertiaryContainer: Color(0xFFECE0E6),
      onTertiaryContainer: Color(0xFF453039),
    );
  }

  factory AppThemePalette.plumPurpleDark() {
    return const AppThemePalette(
      family: AppThemeFamily.plumPurple,
      brightness: Brightness.dark,
      seedColor: Color(0xFFD9AFC0),
      scaffoldBackground: Color(0xFF1A1216),
      appBarBackground: Color(0xFF3A2430),
      appBarForeground: Color(0xFFFFF4F8),
      navigationBarBackground: Color(0xFF2B1C23),
      primary: Color(0xFFD9AFC0),
      onPrimary: Color(0xFF472634),
      surface: Color(0xFF1A1216),
      onSurface: Color(0xFFF4E8ED),
      surfaceContainerLowest: Color(0xFF110C0F),
      surfaceContainerLow: Color(0xFF20161B),
      surfaceContainer: Color(0xFF261A20),
      surfaceContainerHigh: Color(0xFF302128),
      surfaceContainerHighest: Color(0xFF3A2931),
      surfaceBright: Color(0xFF3A2931),
      surfaceDim: Color(0xFF130D10),
      onSurfaceVariant: Color(0xFFCDB8C1),
      outlineVariant: Color(0xFF5A414B),
      primaryContainer: Color(0xFF563242),
      onPrimaryContainer: Color(0xFFF8E1EB),
      secondaryContainer: Color(0xFF49323C),
      onSecondaryContainer: Color(0xFFF2DCE5),
      tertiaryContainer: Color(0xFF372830),
      onTertiaryContainer: Color(0xFFEADAE2),
    );
  }

  final AppThemeFamily family;
  final bool isDynamic;

  /// 运行时墨水屏模式的高对比色板；与手机端预设区分，品牌色与原生正文
  /// 语义据此选择纯黑/纯白映射。
  final bool isEInk;
  final Brightness brightness;
  final Color seedColor;
  final Color scaffoldBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color navigationBarBackground;
  final Color primary;
  final Color onPrimary;
  final Color surface;
  final Color onSurface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceBright;
  final Color surfaceDim;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
}
