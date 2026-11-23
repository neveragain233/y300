import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_brand_colors.dart';
import 'package:y300/app/theme/app_component_theme_builder.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
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
    final eInkFlat = baseTheme.colorScheme.shadow == Colors.transparent;
    final Color panelSurface;
    final Color cardSurface;
    final Color controlSurface;
    if (eInkFlat) {
      if (isDark) {
        panelSurface = const Color(0xFF141414);
        cardSurface = const Color(0xFF1E1E1E);
        controlSurface = const Color(0xFF282828);
      } else {
        panelSurface = const Color(0xFFF5F5F5);
        cardSurface = const Color(0xFFFFFFFF);
        controlSurface = const Color(0xFFE8E8E8);
      }
    } else if (isDark) {
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
        (eInkFlat
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? const Color(0xFFF2F2F5) : const Color(0xFF1F1F1F)));
    final resolvedMuted =
        mutedForeground ??
        (eInkFlat
            ? (isDark ? const Color(0xFFD0D0D0) : const Color(0xFF2E2E2E))
            : (isDark ? const Color(0xFFA8A8B2) : const Color(0xFF575757)));
    final resolvedAccent = eInkFlat
        ? resolvedForeground
        : _resolveAccent(
            accent ?? baseTheme.colorScheme.primary,
            brightness: brightness,
          );
    final resolvedOnAccent = eInkFlat
        ? (isDark ? Colors.black : Colors.white)
        : (ThemeData.estimateBrightnessForColor(resolvedAccent) ==
                  Brightness.dark
              ? Colors.white
              : const Color(0xFF1A1A1A));
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
      border: eInkFlat
          ? AppTheme.eInkBorderColor(brightness)
          : edgeBase.withValues(alpha: 0.14),
      divider: eInkFlat
          ? (isDark ? const Color(0xFF6A6A6A) : const Color(0xFF9A9A9A))
          : edgeBase.withValues(alpha: 0.12),
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
    final baseExt = baseTheme.extension<Y300ThemeExtension>();
    final rebuiltExt = _buildThemeExtension(
      baseExt,
      scheme: scheme,
      background: panelSurface,
      card: cardSurface,
      elevatedCard: controlSurface,
    );
    final extensions =
        List<ThemeExtension<dynamic>>.of(
          baseTheme.extensions.values.where(
            (ext) => ext is! Y300BrandColors && ext is! Y300ThemeExtension,
          ),
        )..addAll([
          Y300BrandColors(accent: accent, onAccent: onAccent),
          rebuiltExt,
        ]);
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
      extensions: extensions,
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

  /// 为嵌入阅读器画布的尾部内容（如漫画评论区）派生与画布一致的主题。
  ThemeData applyToReaderContentTheme(ThemeData baseTheme) {
    final panelTheme = applyToTheme(baseTheme);
    final isDark = brightness == Brightness.dark;
    final eInkFlat = baseTheme.colorScheme.shadow == Colors.transparent;
    final contentCard = eInkFlat && !isDark ? Colors.white : panelSurface;
    final contentScheme = panelTheme.colorScheme.copyWith(
      surface: canvasBackground,
      surfaceContainer: contentCard,
    );
    final baseExt = panelTheme.extension<Y300ThemeExtension>();
    final contentExt = _buildThemeExtension(
      baseExt,
      scheme: contentScheme,
      background: canvasBackground,
      card: contentCard,
      elevatedCard: cardSurface,
    );
    final extensions = List<ThemeExtension<dynamic>>.of(
      panelTheme.extensions.values.where((ext) => ext is! Y300ThemeExtension),
    )..add(contentExt);
    return panelTheme.copyWith(
      colorScheme: contentScheme,
      scaffoldBackgroundColor: canvasBackground,
      canvasColor: canvasBackground,
      cardColor: contentCard,
      extensions: extensions,
    );
  }

  Y300ThemeExtension _buildThemeExtension(
    Y300ThemeExtension? baseExt, {
    required ColorScheme scheme,
    required Color background,
    required Color card,
    required Color elevatedCard,
  }) {
    final isDark = brightness == Brightness.dark;
    final native = _buildNativeContentColors(
      scheme: scheme,
      background: background,
      card: card,
      elevatedCard: elevatedCard,
    );
    if (baseExt != null) {
      return baseExt.copyWith(usesDynamicColor: false, nativeContent: native);
    }
    return Y300ThemeExtension(
      usesDynamicColor: false,
      shelfCategoryBarBackground: card,
      shelfCategorySelectedBackground: accent,
      shelfCategorySelectedForeground: onAccent,
      shelfCategoryDivider: divider,
      readerChromeBackground: panelSurface,
      readerChromeForeground: foreground,
      readerProgressTrackBackground: controlSurface,
      readerOverlayScrim: Colors.black.withValues(alpha: isDark ? 0.44 : 0.18),
      contentHighlightBackground: accent.withValues(alpha: 0.24),
      coverPlaceholderBackground: controlSurface,
      nativeContent: native,
    );
  }

  Y300NativeContentColors _buildNativeContentColors({
    required ColorScheme scheme,
    required Color background,
    required Color card,
    required Color elevatedCard,
  }) {
    final isDark = brightness == Brightness.dark;
    return Y300NativeContentColors(
      background: background,
      card: card,
      elevatedCard: elevatedCard,
      metricBackground: controlSurface,
      panelBackground: controlSurface.withValues(alpha: isDark ? 0.35 : 0.45),
      accent: accent,
      onAccent: onAccent,
      title: foreground,
      itemTitle: foreground,
      author: accent,
      body: foreground,
      supportingText: mutedForeground,
      muted: mutedForeground,
      soft: mutedForeground.withValues(alpha: isDark ? 0.80 : 0.84),
      neutralText: mutedForeground.withValues(alpha: isDark ? 0.80 : 0.84),
      tertiaryText: mutedForeground.withValues(alpha: isDark ? 0.74 : 0.78),
      disabled: mutedForeground.withValues(alpha: isDark ? 0.44 : 0.52),
      stateLayer: accent.withValues(alpha: isDark ? 0.10 : 0.07),
      subtleStateLayer: accent.withValues(alpha: isDark ? 0.10 : 0.06),
      avatarBackground: scheme.secondaryContainer,
      avatarForeground: scheme.onSecondaryContainer,
      selectionBackground: scheme.secondaryContainer,
      selectionForeground: scheme.onSecondaryContainer,
      notificationBadgeBackground: scheme.secondaryContainer,
      translucentSurface: card.withValues(alpha: 0.72),
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
