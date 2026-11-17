import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/navigation_dock.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/app/settings/app_glass_level.dart';

@immutable
class MainNavigationItem {
  const MainNavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String id;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

class MainNavigationRail extends StatelessWidget {
  const MainNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelected,
  });
  final List<MainNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    // 宽屏侧栏沿用导航表面，不铺预设强调色。
    color:
        Theme.of(context).navigationBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetHeight =
              items.length *
                  (64 + MediaQuery.textScalerOf(context).scale(14) * 2) +
              32;
          return SingleChildScrollView(
            child: SizedBox(
              height: math.max(constraints.maxHeight, targetHeight),
              child: NavigationRail(
                key: const Key('main-shell-navigation-rail'),
                minWidth: 80,
                backgroundColor: Theme.of(context)
                    .navigationBarTheme
                    .backgroundColor,
                labelType: NavigationRailLabelType.all,
                indicatorColor: Theme.of(context).colorScheme.primary,
                selectedIconTheme: IconThemeData(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// 沉浸式主壳的悬浮导航胶囊。
///
/// 外观与运动来自 prism_ui 的 [FloatingNavigationBar]：选中层是同源活动透镜，
/// 按压膨胀、跟手拉伸、越界回弹和抬起／落位弹簧都随指针变化。Y300 的提交
/// 规则保持不变：拖动只移动候选，松手按落点提交一次，取消回到原项，速度不
/// 改变落点；[swipeEnabled] 关闭时点按是唯一入口。透镜在按下时先落位还是从
/// 当前选中项跟手由 [dragFromSelection] 决定。
class MainNavigationCapsule extends StatefulWidget {
  const MainNavigationCapsule({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelected,
    this.swipeEnabled = false,
    this.dragFromSelection = true,
    this.glassLevel = AppGlassLevel.off,
  }) : assert(items.length >= 1 && items.length <= 5);

  final List<MainNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  /// 拖动期间只移动候选，页面切换和语义选中态在松手后才提交。
  final bool swipeEnabled;

  /// 拖动时透镜是否从当前选中项按相对位移移动。
  ///
  /// 默认 true 保持既有拖动行为；外观快照选择“按下即跟随”时传 false，
  /// 由 prism_ui 先把透镜移到按下的入口再从按压点跟手。
  final bool dragFromSelection;

  /// 沉浸式胶囊的玻璃档位；关闭时保持主题实色。
  final AppGlassLevel glassLevel;

  @override
  State<MainNavigationCapsule> createState() => _MainNavigationCapsuleState();
}

class _MainNavigationCapsuleState extends State<MainNavigationCapsule> {
  /// 入口、成员、显隐或交互模式变化时重建导航栏，退役未提交的拖动意图。
  late String _intentSignature;
  int _intentGeneration = 0;

  static String _signatureOf(MainNavigationCapsule widget) {
    final ids = widget.items.map((item) => item.id).join('\u0000');
    return '$ids\u0001${widget.swipeEnabled}\u0001'
        '${widget.dragFromSelection}\u0001${widget.onSelected != null}';
  }

  @override
  void initState() {
    super.initState();
    _intentSignature = _signatureOf(widget);
  }

  @override
  void didUpdateWidget(covariant MainNavigationCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signatureOf(widget);
    if (signature != _intentSignature) {
      _intentSignature = signature;
      _intentGeneration++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 关闭档与高对比使用实色表面，标准／增强只区分玻璃质量；
    // 共享背景仍由主壳的玻璃宿主提供，胶囊内部不再嵌套捕获。
    final glassEnabled = widget.glassLevel.enabled && !media.highContrast;
    final quality = widget.glassLevel == AppGlassLevel.enhanced
        ? LiquidGlassQuality.ultra
        : LiquidGlassQuality.standard;
    return LiquidGlassScope(
      enabled: glassEnabled,
      quality: quality,
      child: _buildCapsule(context),
    );
  }

  Widget _buildCapsule(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final region = AppWindowLayout(
          size: Size(constraints.maxWidth, media.size.height),
          displayFeatures: media.displayFeatures,
        ).readingRegion;
        // 窄屏 5 项仍保留 48 逻辑像素触区：不足时沿用横向滚动，
        // 绘制形变不改变真实触区。
        final minimum = FloatingNavigationBar.minimumWidthFor(
          widget.items.length,
        );
        final margin = math.min(
          16.0,
          math.max(0.0, (region.width - minimum) / 2),
        );
        final width = math.max(
          minimum,
          math.min(560.0, region.width - margin * 2),
        );
        final height = math.max(56.0, NavigationDock.heightOf(context));
        return Padding(
          padding: EdgeInsets.only(
            left: region.left,
            right: constraints.maxWidth - region.right,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: Center(
                heightFactor: 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: widget.swipeEnabled
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: margin),
                    child: SizedBox(
                      key: const Key('main-shell-immersive-navigation'),
                      width: width,
                      height: height,
                      child: KeyedSubtree(
                        key: ValueKey<int>(_intentGeneration),
                        child: _DockTheme(
                          child: FloatingNavigationBar(
                            destinations: _destinations(),
                            selectedIndex: widget.selectedIndex,
                            onSelected: (index) =>
                                widget.onSelected?.call(index),
                            commitOnDrag: widget.swipeEnabled,
                            projectVelocity: false,
                            dragFromSelection: widget.dragFromSelection,
                            reduceMotion: media.disableAnimations,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<NavigationDockDestination> _destinations() {
    return [
      for (final item in widget.items)
        NavigationDockDestination(
          key: ValueKey(item.id),
          icon: item.icon,
          selectedIcon: item.selectedIcon,
          label: item.label,
        ),
    ];
  }
}

/// 把应用主题桥接给 prism_ui 导航栏：颜色角色沿用当前预设与动态色，
/// 实色表面取主壳导航表面。公共映射见 `app_prism_theme.dart`，不在此重复
/// 维护第二份主题色表。
class _DockTheme extends StatelessWidget {
  const _DockTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface =
        theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;
    return AppPrismTheme(navigationSurface: surface, child: child);
  }
}
