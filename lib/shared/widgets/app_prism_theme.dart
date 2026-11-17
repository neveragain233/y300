import 'package:flutter/material.dart';
import 'package:prism_ui/theme_data.dart' as prism;

/// 把应用主题桥接给 prism_ui 组件。
///
/// 界面焕新阶段二的菜单、开关、对话框和面板使用 prism_ui 实现，但应用仍以
/// Material `ThemeData` 为唯一主题来源。这里逐项映射颜色角色，让同源组件跟随
/// 当前预设、明暗和动态色，而不是另建一套配色或硬编码色值。
///
/// 页面、路由与弹层宿主自行决定挂载点；菜单、对话框这类脱离页面树的浮层
/// 需要在浮层内部重新挂一次，避免读取到 Navigator 之上不含 prism 主题的上下文。
class AppPrismTheme extends StatelessWidget {
  const AppPrismTheme({super.key, required this.child, this.navigationSurface});

  final Widget child;

  /// 导航表面色；实色底栏、侧栏和底栏示意需要与页面表面区分时传入。
  final Color? navigationSurface;

  @override
  Widget build(BuildContext context) {
    return prism.Theme(
      data: prism.ThemeData(
        colorScheme: prismColorSchemeOf(
          Theme.of(context).colorScheme,
          navigationSurface: navigationSurface,
        ),
      ),
      child: child,
    );
  }
}

/// prism_ui 使用自己的 [prism.ColorScheme] 类型；从应用 [ColorScheme] 映射
/// 同一组颜色角色，保证同源组件与应用主题一致。
prism.ColorScheme prismColorSchemeOf(
  ColorScheme scheme, {
  Color? navigationSurface,
}) {
  final light = scheme.brightness == Brightness.light;
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
    // 实色底栏取导航表面，与旧式底栏和主壳侧栏同一层表面。
    surfaceBright: navigationSurface != null && light
        ? navigationSurface
        : scheme.surfaceBright,
    surfaceContainerLowest: scheme.surfaceContainerLowest,
    surfaceContainerLow: scheme.surfaceContainerLow,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHigh: navigationSurface != null && !light
        ? navigationSurface
        : scheme.surfaceContainerHigh,
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
