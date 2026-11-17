import 'package:flutter/material.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 应用共享的液态玻璃外壳，材质由 prism_ui 的 LiquidGlass 提供。
///
/// 玻璃层只负责背景采样、着色、折射和边缘光学；[child] 在其上独立绘制，
/// 文字与图标不参与模糊或形变。关闭档与高对比模式退回主题实色。
///
/// 使用前提：上层存在启用中的 `LiquidGlassScope` 与 `LiquidGlassHost`。宿主
/// 由应用根 `AppGlassEnvironment` 在 Navigator 之上统一提供一次，普通路由、
/// 菜单、模态面板与分栏详情共用，组件自身不再重复建立捕获。
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.borderRadius,
    required this.child,
    this.level,
    this.baseColor,
    this.elevation = 3,
  });

  /// 玻璃档位；null 时按应用根宿主解析，未启用捕获即视为关闭档。
  final AppGlassLevel? level;

  final double borderRadius;
  final Widget child;

  /// 关闭档使用的着色底，通常取所在区域的导航栏或表面色。
  final Color? baseColor;
  final double elevation;

  /// 当前环境实际生效的档位：根宿主未启用时返回关闭档。
  static AppGlassLevel levelOf(BuildContext context) {
    if (!LiquidGlassScope.of(context)) {
      return AppGlassLevel.off;
    }
    return LiquidGlassScope.qualityOf(context) == LiquidGlassQuality.ultra
        ? AppGlassLevel.enhanced
        : AppGlassLevel.standard;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final level = this.level ?? levelOf(context);
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
        prismColorSchemeOf(scheme),
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
