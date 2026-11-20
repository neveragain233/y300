import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_theme_palette.dart';

/// 品牌强调色，独立于顶栏表面色。
///
/// 界面焕新后顶栏使用页面表面，论坛标记、帖子标题等仍需原预设强调色；
/// 把强调色收敛为独立语义角色，避免再经 `appBarTheme` 间接推断。
@immutable
final class Y300BrandColors extends ThemeExtension<Y300BrandColors> {
  const Y300BrandColors({required this.accent, required this.onAccent});

  factory Y300BrandColors.fromPalette(
    AppThemePalette palette, {
    bool highContrast = false,
  }) {
    // 墨水屏模式没有彩色强调：浅色用黑底白字，深色用白底黑字。
    if (highContrast) {
      return Y300BrandColors(
        accent: palette.primary,
        onAccent: palette.onPrimary,
      );
    }
    return Y300BrandColors(
      accent: palette.appBarBackground,
      onAccent: palette.appBarForeground,
    );
  }

  final Color accent;
  final Color onAccent;

  @override
  Y300BrandColors copyWith({Color? accent, Color? onAccent}) {
    return Y300BrandColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  Y300BrandColors lerp(ThemeExtension<Y300BrandColors>? other, double t) {
    if (other is! Y300BrandColors) {
      return this;
    }
    return Y300BrandColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension Y300BrandColorsData on ThemeData {
  Y300BrandColors get y300BrandColors {
    return extension<Y300BrandColors>() ??
        Y300BrandColors(
          accent: appBarTheme.backgroundColor ?? colorScheme.primary,
          onAccent: appBarTheme.foregroundColor ?? colorScheme.onPrimary,
        );
  }
}
