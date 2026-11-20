import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_brand_colors.dart';
import 'package:y300/app/theme/app_component_theme_builder.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/app/theme/app_theme_palette.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/app/theme/forum_thread_badge_theme.dart';

/// Y300 全局主题入口。
final class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return build(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    return build(family: AppThemeFamily.warmPaper, brightness: Brightness.dark);
  }

  static ThemeData build({
    required AppThemeFamily family,
    required Brightness brightness,
    AppThemeColorSource colorSource = AppThemeColorSource.preset,
    ColorScheme? dynamicScheme,
    bool boldFont = false,
    bool eInkMode = false,
  }) {
    // 墨水屏模式固定使用灰阶色板，忽略手机主题预设和动态色。
    if (eInkMode) {
      return _buildTheme(
        brightness == Brightness.dark
            ? AppThemePalette.eInkDark()
            : AppThemePalette.eInk(),
        boldFont: boldFont,
        eInk: true,
      );
    }
    if (colorSource == AppThemeColorSource.dynamic &&
        dynamicScheme != null &&
        dynamicScheme.brightness == brightness) {
      return _buildTheme(
        AppThemePalette.dynamic(dynamicScheme, family),
        scheme: dynamicScheme,
        boldFont: boldFont,
      );
    }
    return _buildTheme(
      AppThemePalette.resolve(family, brightness),
      boldFont: boldFont,
    );
  }

  static ThemeData _buildTheme(
    AppThemePalette palette, {
    ColorScheme? scheme,
    bool boldFont = false,
    bool eInk = false,
  }) {
    final colorScheme =
        scheme ??
        _buildColorScheme(palette).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          surface: palette.surface,
          onSurface: palette.onSurface,
          surfaceContainerLowest: palette.surfaceContainerLowest,
          surfaceContainer: palette.surfaceContainer,
          surfaceContainerHighest: palette.surfaceContainerHighest,
          onSurfaceVariant: palette.onSurfaceVariant,
          outlineVariant: palette.outlineVariant,
          secondaryContainer: palette.secondaryContainer,
          onSecondaryContainer: palette.onSecondaryContainer,
        );
    // 墨水屏构建去掉 Material 3 的表面着色与阴影色，避免灰阶上叠出偏色。
    final resolvedScheme = eInk
        ? colorScheme.copyWith(
            outline: palette.outlineVariant,
            surfaceTint: Colors.transparent,
            shadow: Colors.transparent,
            scrim: Colors.transparent,
          )
        : colorScheme;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: resolvedScheme,
      pageTransitionsTheme: eInk ? _eInkPageTransitions : null,
      scaffoldBackgroundColor: palette.scaffoldBackground,
      appBarTheme: AppComponentThemeBuilder.appBarTheme(palette),
      navigationBarTheme: AppComponentThemeBuilder.navigationBarTheme(palette),
      popupMenuTheme: AppComponentThemeBuilder.popupMenuTheme(colorScheme),
      menuTheme: AppComponentThemeBuilder.menuTheme(colorScheme),
      dropdownMenuTheme: AppComponentThemeBuilder.dropdownMenuTheme(
        colorScheme,
      ),
      bottomSheetTheme: AppComponentThemeBuilder.bottomSheetTheme(colorScheme),
      dialogTheme: AppComponentThemeBuilder.dialogTheme(colorScheme),
      snackBarTheme: AppComponentThemeBuilder.snackBarTheme(colorScheme),
      segmentedButtonTheme: AppComponentThemeBuilder.segmentedButtonTheme(
        colorScheme,
      ),
      sliderTheme: AppComponentThemeBuilder.sliderTheme(colorScheme),
      filledButtonTheme: AppComponentThemeBuilder.filledButtonTheme(),
      textButtonTheme: AppComponentThemeBuilder.textButtonTheme(),
      outlinedButtonTheme: AppComponentThemeBuilder.outlinedButtonTheme(),
      listTileTheme: AppComponentThemeBuilder.listTileTheme(colorScheme),
      dividerTheme: AppComponentThemeBuilder.dividerTheme(colorScheme),
      iconButtonTheme: AppComponentThemeBuilder.iconButtonTheme(colorScheme),
      inputDecorationTheme: AppComponentThemeBuilder.inputDecorationTheme(
        colorScheme,
      ),
      chipTheme: AppComponentThemeBuilder.chipTheme(colorScheme),
      cardTheme: AppComponentThemeBuilder.cardTheme(colorScheme)
          .copyWith(color: palette.surfaceContainer),
      extensions: <ThemeExtension<dynamic>>[
        Y300BrandColors.fromPalette(palette, highContrast: eInk),
        ForumThreadBadgeTheme.fromColorScheme(
          colorScheme,
          standardBackground: eInk ? palette.primary : palette.appBarBackground,
          standardForeground: eInk
              ? palette.onPrimary
              : palette.appBarForeground,
        ),
        palette.brightness == Brightness.dark
            ? Y300ThemeExtension.dark(palette)
            : Y300ThemeExtension.light(palette),
      ],
    );
    var result = theme;
    if (eInk) {
      result = _flattenEInkSurfaces(result, palette);
    }
    if (boldFont) {
      result = result.copyWith(textTheme: _boldTextTheme(result.textTheme));
    }
    return result;
  }

  /// 墨水屏上阴影与抬升会产生整块重绘和残影，统一压平为实色描边表面。
  static ThemeData _flattenEInkSurfaces(
    ThemeData theme,
    AppThemePalette palette,
  ) {
    const shadow = Colors.transparent;
    // 选中/命中高亮在灰阶屏上不能靠彩色区分，改为中性遮罩。
    final highlight = palette.brightness == Brightness.dark
        ? const Color(0x33FFFFFF)
        : const Color(0x22000000);
    final extensions = theme.extensions.values
        .map<ThemeExtension<dynamic>>(
          (extension) => extension is Y300ThemeExtension
              ? extension.copyWith(contentHighlightBackground: highlight)
              : extension,
        )
        .toList(growable: false);
    const noAnimationButton = ButtonStyle(animationDuration: Duration.zero);
    return theme.copyWith(
      extensions: extensions,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: shadow,
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        elevation: 0,
        modalElevation: 0,
      ),
      cardTheme: theme.cardTheme.copyWith(elevation: 0, shadowColor: shadow),
      dialogTheme: theme.dialogTheme.copyWith(
        elevation: 0,
        shadowColor: shadow,
      ),
      popupMenuTheme: theme.popupMenuTheme.copyWith(
        elevation: 0,
        shadowColor: shadow,
      ),
      snackBarTheme: theme.snackBarTheme.copyWith(elevation: 0),
      expansionTileTheme: theme.expansionTileTheme.copyWith(
        expansionAnimationStyle: AnimationStyle.noAnimation,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: noAnimationButton.merge(theme.filledButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: noAnimationButton.merge(theme.textButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: noAnimationButton.merge(theme.outlinedButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: noAnimationButton.merge(theme.iconButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: noAnimationButton.merge(theme.elevatedButtonTheme.style),
      ),
      segmentedButtonTheme: theme.segmentedButtonTheme.copyWith(
        style: noAnimationButton.merge(theme.segmentedButtonTheme.style),
      ),
    );
  }

  /// 全局加粗：逐级提升现有字重，保留字号、行高与字体族。
  static TextTheme _boldTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: _bumpWeight(base.displayLarge),
      displayMedium: _bumpWeight(base.displayMedium),
      displaySmall: _bumpWeight(base.displaySmall),
      headlineLarge: _bumpWeight(base.headlineLarge),
      headlineMedium: _bumpWeight(base.headlineMedium),
      headlineSmall: _bumpWeight(base.headlineSmall),
      titleLarge: _bumpWeight(base.titleLarge),
      titleMedium: _bumpWeight(base.titleMedium),
      titleSmall: _bumpWeight(base.titleSmall),
      bodyLarge: _bumpWeight(base.bodyLarge),
      bodyMedium: _bumpWeight(base.bodyMedium),
      bodySmall: _bumpWeight(base.bodySmall),
      labelLarge: _bumpWeight(base.labelLarge),
      labelMedium: _bumpWeight(base.labelMedium),
      labelSmall: _bumpWeight(base.labelSmall),
    );
  }

  static TextStyle? _bumpWeight(TextStyle? style) {
    if (style == null) {
      return null;
    }
    final next = switch (style.fontWeight ?? FontWeight.w400) {
      FontWeight.w100 => FontWeight.w200,
      FontWeight.w200 => FontWeight.w300,
      FontWeight.w300 => FontWeight.w400,
      FontWeight.w400 => FontWeight.w500,
      FontWeight.w500 => FontWeight.w600,
      FontWeight.w600 => FontWeight.w700,
      FontWeight.w700 => FontWeight.w800,
      FontWeight.w800 || FontWeight.w900 => FontWeight.w900,
      _ => FontWeight.w900,
    };
    return style.copyWith(fontWeight: next);
  }

  /// eink 构建没有路由过渡：页面直接切换，避免每次导航整屏渐变重绘。
  static const PageTransitionsTheme _eInkPageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: _NoTransitionsBuilder(),
      TargetPlatform.iOS: _NoTransitionsBuilder(),
      TargetPlatform.macOS: _NoTransitionsBuilder(),
      TargetPlatform.linux: _NoTransitionsBuilder(),
      TargetPlatform.windows: _NoTransitionsBuilder(),
    },
  );

  static ColorScheme _buildColorScheme(AppThemePalette palette) {
    return ColorScheme.fromSeed(
      seedColor: palette.seedColor,
      brightness: palette.brightness,
    );
  }
}

/// 无过渡的页面构建器，供墨水屏变体使用。
final class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
