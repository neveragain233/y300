import 'package:flutter/material.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

/// 顶栏小按钮的有效触区；玻璃表面与按压范围按同一尺寸绘制。
const double _toolbarTouchTarget = 48;

/// 胶囊与单按钮共用的圆角：48 高时为等半径胶囊与正圆。
const double _toolbarGlassRadius = _toolbarTouchTarget / 2;

/// 相关动作共用胶囊，末项保留独立圆键；触区沿用原按钮尺寸。
///
/// 每个表面都是一块 [AppGlassSurface]：标准与增强档为有色玻璃，
/// 关闭档与高对比回退主题实色。来源由应用根 `AppGlassEnvironment`
/// 提供，胶囊自身不建立捕获；内部按钮不再叠自绘圆底。
class AppToolbarActions extends StatelessWidget {
  const AppToolbarActions({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;
    final actionTheme = theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(foregroundColor: foreground),
      iconButtonTheme: IconButtonThemeData(
        style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? foreground.withValues(alpha: .38)
                : foreground,
          ),
          // 胶囊里的动作统一至少48逻辑像素命中区，右侧动作不因视觉收紧变小。
          minimumSize: const WidgetStatePropertyAll(Size.square(48)),
        ),
      ),
    );
    Widget surface(List<Widget> actions) => Theme(
      data: actionTheme,
      child: IconButtonTheme(
        data: actionTheme.iconButtonTheme,
        child: IconTheme(
          data: IconTheme.of(context).copyWith(color: foreground),
          child: AppGlassSurface(
            baseColor: scheme.surfaceContainerHigh,
            borderRadius: _toolbarGlassRadius,
            // 顶栏按钮关闭档保持原有平面外壳，阴影只来自玻璃档本身。
            elevation: 0,
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ),
      ),
    );
    return Padding(
      // 右侧动作与屏幕边缘留出可单手触达的余量，也避免最右键压到手势区。
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (children.length > 1) ...[
            surface(children.take(children.length - 1).toList()),
            const SizedBox(width: 8),
          ],
          surface([children.last]),
        ],
      ),
    );
  }
}

/// 公共顶栏玻璃单按钮：可配置图标、提示与键，有效触区至少48逻辑像素。
///
/// 只绘制玻璃圆底一层；前景、按压、焦点与禁用由内部 [IconButton] 提供，
/// 读屏沿用 [tooltip] 或图标自身的语义。宿主未启用玻璃时退回实色圆底。
class AppToolbarIconButton extends StatelessWidget {
  const AppToolbarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.buttonKey,
    this.foregroundColor,
    this.baseColor,
    this.glassLevel,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// 落在内部 [IconButton] 上的键，供页面测试与命中定位使用。
  final Key? buttonKey;
  final Color? foregroundColor;
  final Color? baseColor;
  final AppGlassLevel? glassLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = foregroundColor ?? theme.colorScheme.onSurface;
    return AppGlassSurface(
      level: glassLevel,
      baseColor: baseColor ?? theme.colorScheme.surfaceContainerHigh,
      borderRadius: _toolbarGlassRadius,
      elevation: 0,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        style: _toolbarButtonStyle(foreground),
        icon: icon,
      ),
    );
  }
}

/// 压入页返回键：保留常规安卓返回箭头与 [BackButton] 语义，外加玻璃圆底。
class AppToolbarBackButton extends StatelessWidget {
  const AppToolbarBackButton({
    super.key,
    this.onPressed,
    this.foregroundColor,
    this.baseColor,
    this.glassLevel,
  });
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? baseColor;
  final AppGlassLevel? glassLevel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: AppGlassSurface(
        level: glassLevel,
        baseColor: baseColor ?? scheme.surfaceContainerHigh,
        borderRadius: _toolbarGlassRadius,
        elevation: 0,
        child: BackButton(
          style: _toolbarButtonStyle(foregroundColor ?? scheme.onSurface),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// 顶栏关闭键：与返回键同规格的玻璃圆底，图标与提示按调用方语义。
class AppToolbarCloseButton extends StatelessWidget {
  const AppToolbarCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.buttonKey,
    this.foregroundColor,
    this.baseColor,
    this.glassLevel,
  });

  final VoidCallback? onPressed;
  final String? tooltip;
  final Key? buttonKey;
  final Color? foregroundColor;
  final Color? baseColor;
  final AppGlassLevel? glassLevel;

  @override
  Widget build(BuildContext context) => Center(
    child: AppToolbarIconButton(
      buttonKey: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      foregroundColor: foregroundColor,
      baseColor: baseColor,
      glassLevel: glassLevel,
      icon: const Icon(Icons.close),
    ),
  );
}

ButtonStyle _toolbarButtonStyle(Color foreground) => IconButton.styleFrom(
  foregroundColor: foreground,
  disabledForegroundColor: foreground.withValues(alpha: .38),
  // 表面只由外层玻璃圆底提供，按钮自身不叠第二层实色。
  backgroundColor: Colors.transparent,
  minimumSize: const Size.square(_toolbarTouchTarget),
);
