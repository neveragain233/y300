import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_component_theme_builder.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 跟随阅读画布派生出的面板调色板。
///
/// 阅读器面板覆盖在正文之上，与画布和内部卡片之间保持可区分的层次对比：
/// 纯黑与深色画布提升为深实色表面，纸面画布保留纸色调并与卡片分离。
@immutable
final class ReaderPanelPalette {
  const ReaderPanelPalette({
    required this.brightness,
    required this.canvasBackground,
    required this.panelSurface,
    required this.cardSurface,
    required this.controlSurface,
    required this.foreground,
    required this.mutedForeground,
    required this.accent,
    required this.onAccent,
    required this.border,
    required this.divider,
  });

  final Brightness brightness;
  final Color canvasBackground;
  final Color panelSurface;
  final Color cardSurface;
  final Color controlSurface;
  final Color foreground;
  final Color mutedForeground;
  final Color accent;
  final Color onAccent;
  final Color border;
  final Color divider;

  /// 根据当前生效的阅读器画布背景派生面板色板。
  factory ReaderPanelPalette.fromCanvas({
    required Color canvasBackground,
    required ThemeData baseTheme,
    Color? accent,
    Color? foreground,
    Color? mutedForeground,
  }) {
    final brightness = ThemeData.estimateBrightnessForColor(canvasBackground);
    final isDark = brightness == Brightness.dark;
    final Color panelSurface;
    final Color cardSurface;
    final Color controlSurface;
    if (isDark) {
      panelSurface = Color.lerp(canvasBackground, Colors.white, 0.09)!;
      cardSurface = Color.lerp(canvasBackground, Colors.white, 0.15)!;
      controlSurface = Color.lerp(canvasBackground, Colors.white, 0.22)!;
    } else if (canvasBackground.computeLuminance() >= 0.94) {
      // 近白画布统一拉开面板底与纯白分组卡的层次。
      panelSurface = const Color(0xFFF3F3F5);
      cardSurface = const Color(0xFFFFFFFF);
      controlSurface = const Color(0xFFE5E5EA);
    } else {
      panelSurface = Color.lerp(
        canvasBackground,
        const Color(0xFF1F1F1F),
        0.055,
      )!;
      cardSurface = Color.lerp(canvasBackground, Colors.white, 0.55)!;
      controlSurface = Color.lerp(
        canvasBackground,
        const Color(0xFF1F1F1F),
        0.12,
      )!;
    }

    final resolvedForeground =
        foreground ??
        (isDark ? const Color(0xFFF2F2F5) : const Color(0xFF1F1F1F));
    final resolvedMuted =
        mutedForeground ??
        (isDark ? const Color(0xFFA8A8B2) : const Color(0xFF575757));
    final resolvedAccent = _resolveAccent(
      accent ?? baseTheme.colorScheme.primary,
      brightness: brightness,
    );
    final resolvedOnAccent =
        ThemeData.estimateBrightnessForColor(resolvedAccent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);
    final edgeBase = isDark ? Colors.white : const Color(0xFF1F1F1F);

    return ReaderPanelPalette(
      brightness: brightness,
      canvasBackground: canvasBackground,
      panelSurface: panelSurface,
      cardSurface: cardSurface,
      controlSurface: controlSurface,
      foreground: resolvedForeground,
      mutedForeground: resolvedMuted,
      accent: resolvedAccent,
      onAccent: resolvedOnAccent,
      border: edgeBase.withValues(alpha: 0.14),
      divider: edgeBase.withValues(alpha: 0.12),
    );
  }

  /// 从小说阅读器的色彩参数派生面板色板（不依赖 novel 模块类型）。
  factory ReaderPanelPalette.fromNovelPalette({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color foreground,
    required Color muted,
    required Color accent,
    required ThemeData baseTheme,
  }) {
    final canvasBrightness = ThemeData.estimateBrightnessForColor(background);
    final effectiveAccent = accent;
    final palette = ReaderPanelPalette.fromCanvas(
      canvasBackground: background,
      baseTheme: baseTheme,
      accent: effectiveAccent,
      foreground: foreground,
      mutedForeground: muted,
    );
    if (canvasBrightness == brightness) {
      return palette;
    }
    return ReaderPanelPalette.fromCanvas(
      canvasBackground: background,
      baseTheme: baseTheme,
      accent: effectiveAccent,
    );
  }

  ThemeData applyToTheme(ThemeData baseTheme) {
    final isDark = brightness == Brightness.dark;
    final eInkFlat = baseTheme.colorScheme.shadow == Colors.transparent;
    // 以面板目标明暗重新派生完整 ColorScheme，避免异明暗主题的容器与文字色残留在衍生表面上。
    var scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
        .copyWith(
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: Color.lerp(
            cardSurface,
            accent,
            isDark ? 0.24 : 0.18,
          ),
          onPrimaryContainer: foreground,
          secondary: accent,
          onSecondary: onAccent,
          secondaryContainer: Color.lerp(
            cardSurface,
            accent,
            isDark ? 0.22 : 0.16,
          ),
          onSecondaryContainer: foreground,
          surface: panelSurface,
          surfaceDim: canvasBackground,
          surfaceBright: controlSurface,
          surfaceContainerLowest: cardSurface,
          surfaceContainerLow: panelSurface,
          surfaceContainer: cardSurface,
          surfaceContainerHigh: controlSurface,
          surfaceContainerHighest: controlSurface,
          onSurface: foreground,
          onSurfaceVariant: mutedForeground,
          outline: border,
          outlineVariant: divider,
        );
    if (eInkFlat) {
      scheme = scheme.copyWith(
        surfaceTint: Colors.transparent,
        shadow: Colors.transparent,
        scrim: Colors.transparent,
      );
    }
    final textTheme = baseTheme.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );
    final primaryTextTheme = baseTheme.primaryTextTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );
    return baseTheme.copyWith(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: panelSurface,
      canvasColor: panelSurface,
      cardColor: cardSurface,
      dividerColor: divider,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      iconTheme: baseTheme.iconTheme.copyWith(color: foreground),
      primaryIconTheme: baseTheme.primaryIconTheme.copyWith(color: foreground),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.30),
        selectionHandleColor: accent,
      ),
      listTileTheme: AppComponentThemeBuilder.listTileTheme(scheme),
      iconButtonTheme: AppComponentThemeBuilder.iconButtonTheme(scheme),
      dividerTheme: AppComponentThemeBuilder.dividerTheme(scheme),
      inputDecorationTheme: AppComponentThemeBuilder.inputDecorationTheme(
        scheme,
      ),
      chipTheme: AppComponentThemeBuilder.chipTheme(scheme),
      cardTheme: AppComponentThemeBuilder.cardTheme(scheme),
      dialogTheme: AppComponentThemeBuilder.dialogTheme(scheme),
      bottomSheetTheme: AppComponentThemeBuilder.bottomSheetTheme(scheme),
      popupMenuTheme: AppComponentThemeBuilder.popupMenuTheme(scheme),
      menuTheme: AppComponentThemeBuilder.menuTheme(scheme),
      dropdownMenuTheme: AppComponentThemeBuilder.dropdownMenuTheme(scheme),
      segmentedButtonTheme: AppComponentThemeBuilder.segmentedButtonTheme(
        scheme,
      ),
      sliderTheme: AppComponentThemeBuilder.sliderTheme(scheme),
      snackBarTheme: AppComponentThemeBuilder.snackBarTheme(scheme),
    );
  }

  static Color _resolveAccent(Color raw, {required Brightness brightness}) {
    if (brightness == Brightness.dark) {
      if (raw.computeLuminance() >= 0.35) {
        return raw;
      }
      final lifted = Color.lerp(raw, Colors.white, 0.55)!;
      if (lifted.computeLuminance() >= 0.35) {
        return lifted;
      }
      return Color.lerp(raw, Colors.white, 0.72)!;
    }
    if (raw.computeLuminance() <= 0.16) {
      return raw;
    }
    final darkened = Color.lerp(raw, Colors.black, 0.55)!;
    if (darkened.computeLuminance() <= 0.16) {
      return darkened;
    }
    return Color.lerp(raw, Colors.black, 0.72)!;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderPanelPalette &&
            other.brightness == brightness &&
            other.canvasBackground == canvasBackground &&
            other.panelSurface == panelSurface &&
            other.cardSurface == cardSurface &&
            other.controlSurface == controlSurface &&
            other.foreground == foreground &&
            other.mutedForeground == mutedForeground &&
            other.accent == accent &&
            other.onAccent == onAccent &&
            other.border == border &&
            other.divider == divider;
  }

  @override
  int get hashCode => Object.hash(
    brightness,
    canvasBackground,
    panelSurface,
    cardSurface,
    controlSurface,
    foreground,
    mutedForeground,
    accent,
    onAccent,
    border,
    divider,
  );
}

/// 将 [ReaderPanelPalette] 注入阅读面板局部 [Theme] 与 [AppPrismTheme]。
class ReaderPanelTheme extends StatelessWidget {
  const ReaderPanelTheme({
    super.key,
    required this.palette,
    required this.child,
  });

  final ReaderPanelPalette palette;
  final Widget child;

  static ReaderPanelPalette? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ReaderPanelPaletteScope>()
        ?.palette;
  }

  @override
  Widget build(BuildContext context) {
    final derivedTheme = palette.applyToTheme(Theme.of(context));
    return _ReaderPanelPaletteScope(
      palette: palette,
      child: Theme(
        data: derivedTheme,
        child: AppPrismTheme(child: child),
      ),
    );
  }
}

class _ReaderPanelPaletteScope extends InheritedWidget {
  const _ReaderPanelPaletteScope({required this.palette, required super.child});

  final ReaderPanelPalette palette;

  @override
  bool updateShouldNotify(_ReaderPanelPaletteScope oldWidget) =>
      palette != oldWidget.palette;
}
