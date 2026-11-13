import 'package:flutter/material.dart';
import 'package:prism_ui/color_scheme.dart' as prism;
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';

/// 应用共享的液态玻璃外壳，材质由 prism_ui 的 LiquidGlass 提供。
///
/// 玻璃层只负责背景采样、着色、折射和边缘光学；[child] 在其上独立绘制，
/// 文字与图标不参与模糊或形变。关闭档与高对比模式退回主题实色。
///
/// 使用前提：上层存在 `LiquidGlassScope` 与 `LiquidGlassHost`，且只由主壳
/// 页面宿主提供一次，避免同一页面重复捕获背景。
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.level,
    required this.borderRadius,
    required this.child,
    this.baseColor,
    this.elevation = 3,
  });

  final AppGlassLevel level;
  final double borderRadius;
  final Widget child;

  /// 关闭档使用的着色底，通常取所在区域的导航栏或表面色。
  final Color? baseColor;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final resolved = media.highContrast && level.enabled
        ? AppGlassLevel.off
        : level;
    final shape = BorderRadius.circular(borderRadius);
    if (!resolved.enabled) {
      return Material(
        color:
            baseColor ??
            Theme.of(context).navigationBarTheme.backgroundColor ??
            scheme.surfaceContainer,
        elevation: elevation,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    return LiquidGlass(
      // 导航条用带色玻璃：0.82 的着色底压住后方正文，保证标签可读，
      // 同时保留折射和边缘高光。
      style: LiquidGlassStyle.tinted(
        _prismScheme(scheme),
        scheme.surfaceContainerHigh,
      ),
      borderRadius: shape,
      shadows: [
        BoxShadow(
          color: scheme.shadow.withValues(
            alpha: scheme.brightness == Brightness.dark ? 0.22 : 0.10,
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      // InkWell 仍需要 Material 祖先提供水波纹层；透明 Material 不遮挡玻璃。
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// prism_ui 使用自己的 ColorScheme 类型；从应用主题映射同一组颜色角色，
/// 让玻璃沿用当前预设或动态色的色调，而不是另建一套配色。
prism.ColorScheme _prismScheme(ColorScheme scheme) {
  return prism.ColorScheme(
    brightness: scheme.brightness,
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    onPrimaryContainer: scheme.onPrimaryContainer,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    secondaryContainer: scheme.secondaryContainer,
    onSecondaryContainer: scheme.onSecondaryContainer,
    tertiary: scheme.tertiary,
    onTertiary: scheme.onTertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    onTertiaryContainer: scheme.onTertiaryContainer,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    onErrorContainer: scheme.onErrorContainer,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceDim: scheme.surfaceDim,
    surfaceBright: scheme.surfaceBright,
    surfaceContainerLowest: scheme.surfaceContainerLowest,
    surfaceContainerLow: scheme.surfaceContainerLow,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHigh: scheme.surfaceContainerHigh,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    onSurfaceVariant: scheme.onSurfaceVariant,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    shadow: scheme.shadow,
    scrim: scheme.scrim,
    inverseSurface: scheme.inverseSurface,
    onInverseSurface: scheme.onInverseSurface,
    inversePrimary: scheme.inversePrimary,
    surfaceTint: scheme.surfaceTint,
  );
}
