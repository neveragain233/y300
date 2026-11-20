import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' show TonalButtonSize;
import 'package:prism_ui/card_surface.dart' show PressLook;
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:prism_ui/theme_data.dart' as prism_theme;
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 顶栏小按钮的有效触区；玻璃表面与按压范围按同一尺寸绘制。
const double _toolbarTouchTarget = 48;

/// 顶栏与紧凑栏动作的公共尺寸档，沿用 `prism_ui` 的 `TonalButtonSize`。
///
/// 两档共用同一玻璃档位、按压模型和状态色，只改视觉尺寸与图标：
/// `bar` 视觉 44／图标 24，`compact` 视觉 32／图标 20；有效命中区统一 48，
/// 紧凑档的玻璃收在命中区中央，供阅读器工具栏、面板头部与选择态紧凑行复用。
enum AppToolbarButtonSize {
  bar(TonalButtonSize.bar),
  compact(TonalButtonSize.compact);

  const AppToolbarButtonSize(this.tonal);

  final TonalButtonSize tonal;

  /// 玻璃圆底的视觉直径。
  double get visual => tonal.button;

  /// 图标边长。
  double get icon => tonal.icon;

  /// 单按钮玻璃圆底的半径，等半径正圆。
  double get radius => visual / 2;

  /// 与 [TonalButtonSize] 不同，应用内的有效命中区不小于 48 逻辑像素。
  static const double hitTarget = _toolbarTouchTarget;
}

/// 相关动作共用胶囊，末项保留独立圆键；触区沿用原按钮尺寸。
///
/// 每个表面都是一块 [AppGlassSurface]：标准与增强档为有色玻璃，
/// 关闭档与高对比回退主题实色。来源由应用根 `AppGlassEnvironment`
/// 提供，胶囊自身不建立捕获；内部按钮不再叠自绘圆底。
///
/// 按压沿用固定版本 `ElasticPress` 的弹簧模型：任一按钮按下时整个表面膨胀，
/// 按住拖动跟手，松开回弹；内部 Material 按钮只保留前景、禁用与命中区，
/// 不再出现水波纹或按压高亮。系统要求减少动态效果时不做膨胀，
/// 改由内部按钮显示即时状态色。
class AppToolbarActions extends StatelessWidget {
  const AppToolbarActions({
    super.key,
    this.size = AppToolbarButtonSize.bar,
    required this.children,
  });

  /// 胶囊玻璃的视觉高度档；行布局仍按 48 命中区高度排布。
  final AppToolbarButtonSize size;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;
    final reduceMotion = AppMotion.reduceMotion(context);
    final actionTheme = theme.copyWith(
      // 按压反馈归胶囊的弹簧膨胀，Material 子按钮不再起水波纹。
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(foregroundColor: foreground),
      iconButtonTheme: IconButtonThemeData(
        style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? foreground.withValues(alpha: .38)
                : foreground,
          ),
          // 胶囊里的动作按档位收紧视觉，命中区仍由 tap target 保到48。
          minimumSize: WidgetStatePropertyAll(Size.square(size.visual)),
          tapTargetSize: MaterialTapTargetSize.padded,
          // 普通档把按压完全交给胶囊膨胀；减少动态效果时用即时状态色代替。
          backgroundColor: reduceMotion
              ? WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.pressed)
                      ? foreground.withValues(alpha: .10)
                      : Colors.transparent,
                )
              : const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? Colors.transparent
                : null,
          ),
          animationDuration: Duration.zero,
        ),
      ),
    );
    Widget surface(List<Widget> actions) {
      // 行布局保持 48 命中高度，玻璃按尺寸档收在中央。
      final glass = AppGlassSurface(
        baseColor: scheme.surfaceContainerHigh,
        borderRadius: size.radius,
        child: const SizedBox.expand(),
      );
      final content = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              child: SizedBox(
                width: double.infinity,
                height: size.visual,
                child: glass,
              ),
            ),
          ),
          // 胶囊内的公共按钮共用这一层玻璃，不再自画圆底或单独膨胀。
          _ToolbarActionGroup(
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      );
      return Theme(
        data: actionTheme,
        child: IconButtonTheme(
          data: actionTheme.iconButtonTheme,
          child: IconTheme(
            data: IconTheme.of(context).copyWith(color: foreground),
            // 组内的 prism 菜单触发件跟随应用预设，不落到界面库兜底配色。
            child: AppPrismTheme(
              child: reduceMotion
                  ? content
                  : ElasticPress(
                      // 膨胀只改绘制，组内按钮仍各自命中与提交。
                      child: content,
                    ),
            ),
          ),
        ),
      );
    }

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

/// 公共顶栏玻璃单按钮：可配置图标、提示、键与尺寸档。
///
/// 玻璃圆底随 [AppToolbarButtonSize] 的视觉尺寸绘制，命中区仍为 48 逻辑像素；
/// 按下、拖动与松开走 `prism_ui` 的 `ElasticPress` 弹簧模型，按钮自身不出现
/// Material 水波纹。减少动态效果时不做膨胀，改在玻璃层上显示即时状态色。
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
    this.size = AppToolbarButtonSize.bar,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// 落在内部按压按钮上的键，供页面测试与命中定位使用。
  final Key? buttonKey;
  final Color? foregroundColor;
  final Color? baseColor;
  final AppGlassLevel? glassLevel;
  final AppToolbarButtonSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? scheme.onSurface;
    final reduceMotion = AppMotion.reduceMotion(context);
    // 胶囊已提供玻璃与整组膨胀，组内按钮不再叠第二层圆底。
    final grouped = _ToolbarActionGroup.of(context);
    final button = AppPrismTheme(
      child: prism_button.IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        style: _toolbarIconButtonStyle(
          foreground,
          size: size,
          // 普通档的反馈是弹簧膨胀；减少动态效果时改用即时状态色。
          showStateColor: reduceMotion,
        ),
      ),
    );
    if (grouped) {
      return button;
    }
    // 玻璃圆底随尺寸档收在命中区中央，按钮本身仍占满 48 命中区。
    final surface = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: size.visual,
          child: AppGlassSurface(
            level: glassLevel,
            baseColor: baseColor ?? scheme.surfaceContainerHigh,
            borderRadius: size.radius,
            child: const SizedBox.expand(),
          ),
        ),
        button,
      ],
    );
    // 已在动作胶囊或其它弹簧按压内时由整组负责膨胀，不叠第二层。
    if (reduceMotion || ElasticPress.maybeOf(context) != null) {
      return surface;
    }
    return ElasticPress(enabled: onPressed != null, child: surface);
  }
}

/// 公共玻璃图标按钮的按压样式：透明底、48 命中区，按压反馈交给弹簧模型。
///
/// [showStateColor] 用于减少动态效果：按下时直接在玻璃上叠即时状态色。
prism_button.ButtonStyle _toolbarIconButtonStyle(
  Color foreground, {
  required AppToolbarButtonSize size,
  required bool showStateColor,
}) {
  return prism_button.ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: .38)
          : foreground,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => showStateColor && states.contains(WidgetState.pressed)
          ? foreground.withValues(alpha: .10)
          : Colors.transparent,
    ),
    minimumSize: Size.square(size.visual),
    padding: EdgeInsets.zero,
    iconSize: size.icon,
    visualDensity: prism_theme.VisualDensity.standard,
    // 视觉圆底收在 48 命中区中央。
    tapTargetSize: prism_theme.TapTargetSize.padded,
    pressLook: PressLook.none,
  );
}

/// 标记公共按钮已落在动作胶囊内：玻璃与弹簧膨胀由胶囊统一提供。
class _ToolbarActionGroup extends InheritedWidget {
  const _ToolbarActionGroup({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToolbarActionGroup>() != null;

  @override
  bool updateShouldNotify(_ToolbarActionGroup oldWidget) => false;
}

/// 压入页返回键：保留常规安卓返回箭头与返回提示，外加玻璃圆底。
///
/// 内部仍是框架 `BackButton`，tooltip、返回语义和键盘焦点沿用系统实现；
/// 水波纹与按压高亮关闭，按压反馈由外层 `ElasticPress` 的膨胀承担。
class AppToolbarBackButton extends StatelessWidget {
  const AppToolbarBackButton({
    super.key,
    this.onPressed,
    this.foregroundColor,
    this.baseColor,
    this.glassLevel,
    this.size = AppToolbarButtonSize.bar,
  });
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? baseColor;
  final AppGlassLevel? glassLevel;
  final AppToolbarButtonSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? scheme.onSurface;
    final reduceMotion = AppMotion.reduceMotion(context);
    final glassButton = _ToolbarGlassButton(
      size: size,
      level: glassLevel,
      baseColor: baseColor ?? scheme.surfaceContainerHigh,
      child: BackButton(
        style: _materialToolbarButtonStyle(
          foreground,
          size: size,
          reduceMotion: reduceMotion,
        ),
        onPressed: onPressed,
      ),
    );
    return Center(
      child: reduceMotion || ElasticPress.maybeOf(context) != null
          ? glassButton
          : ElasticPress(child: glassButton),
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
    this.size = AppToolbarButtonSize.bar,
  });

  final VoidCallback? onPressed;
  final String? tooltip;
  final Key? buttonKey;
  final Color? foregroundColor;
  final Color? baseColor;
  final AppGlassLevel? glassLevel;
  final AppToolbarButtonSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? scheme.onSurface;
    final reduceMotion = AppMotion.reduceMotion(context);
    final glassButton = _ToolbarGlassButton(
      size: size,
      level: glassLevel,
      baseColor: baseColor ?? scheme.surfaceContainerHigh,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        style: _materialToolbarButtonStyle(
          foreground,
          size: size,
          reduceMotion: reduceMotion,
        ),
        icon: const Icon(Icons.close),
      ),
    );
    return Center(
      child: reduceMotion || ElasticPress.maybeOf(context) != null
          ? glassButton
          : ElasticPress(enabled: onPressed != null, child: glassButton),
    );
  }
}

/// 顶栏玻璃菜单触发键：菜单外壳、来源快照与开合运动都沿用 `AppPopupMenuButton`。
///
/// 触发键本身是 [AppToolbarIconButton]，与返回、关闭共用同一弹簧按压模型；
/// 菜单打开时按下的膨胀由锚定弹层接续释放，不再单独绘制一套按压反馈。
class AppToolbarMenuButton<T> extends StatelessWidget {
  const AppToolbarMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.onCanceled,
    required this.tooltip,
    required this.icon,
    this.size = AppToolbarButtonSize.bar,
    this.enabled = true,
    this.buttonKey,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;

  /// 触发键的提示，同时用作读屏名称。
  final String tooltip;
  final Widget icon;
  final AppToolbarButtonSize size;
  final bool enabled;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return AppPopupMenuButton<T>(
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      onCanceled: onCanceled,
      enabled: enabled,
      targetBuilder: (context, open) => AppToolbarIconButton(
        buttonKey: buttonKey,
        icon: icon,
        tooltip: tooltip,
        size: size,
        onPressed: enabled ? open : null,
      ),
    );
  }
}

/// 玻璃圆底与 48 命中区的叠放：玻璃只画视觉尺寸，按钮保持整块命中。
class _ToolbarGlassButton extends StatelessWidget {
  const _ToolbarGlassButton({
    required this.size,
    this.level,
    this.baseColor,
    required this.child,
  });

  final AppToolbarButtonSize size;
  final AppGlassLevel? level;
  final Color? baseColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: size.visual,
          child: AppGlassSurface(
            level: level,
            baseColor: baseColor ?? scheme.surfaceContainerHigh,
            borderRadius: size.radius,
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

/// 玻璃圆底里的框架按钮只保留前景、禁用与命中区，按压反馈交给弹簧模型。
///
/// 普通档关闭水波纹与按压高亮；减少动态效果时不膨胀，改用即时状态色。
ButtonStyle _materialToolbarButtonStyle(
  Color foreground, {
  required AppToolbarButtonSize size,
  required bool reduceMotion,
}) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: .38)
          : foreground,
    ),
    backgroundColor: reduceMotion
        ? WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? foreground.withValues(alpha: .10)
                : Colors.transparent,
          )
        : const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.pressed) ? Colors.transparent : null,
    ),
    // 视觉圆底按档位收紧，命中区由 padded tap target 保到 48。
    minimumSize: WidgetStatePropertyAll(Size.square(size.visual)),
    tapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: NoSplash.splashFactory,
    animationDuration: Duration.zero,
  );
}
