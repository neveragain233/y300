import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 沉浸式主壳覆盖层在屏幕底部占用的总高度（含系统手势区）。
///
/// 主壳不压缩正文视口，只把该高度提供给滚动内容作为尾部预留；没有该作用域
/// 的页面（旧式底栏、宽屏侧栏、独立路由）按零处理，保持原有布局。
class MainShellBottomInset extends InheritedWidget {
  const MainShellBottomInset({
    super.key,
    required this.bottom,
    this.fabBottom,
    required super.child,
  });

  final double bottom;
  final double? fabBottom;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MainShellBottomInset>()
          ?.bottom ??
      0;

  static double fabBottomOf(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<MainShellBottomInset>();
    return widget?.fabBottom ?? widget?.bottom ?? 0;
  }

  @override
  bool updateShouldNotify(MainShellBottomInset oldWidget) =>
      oldWidget.bottom != bottom || oldWidget.fabBottom != fabBottom;
}

/// 滚动内容尾部应为覆盖层预留的空间。
///
/// 沉浸式正文铺到屏幕底部，按覆盖层总高度预留；独立路由和旧式布局没有覆盖
/// 层时退回系统底部安全区，避免末项贴住手势区。
double mainShellBottomScrollInset(BuildContext context) {
  return math.max(
    MediaQuery.paddingOf(context).bottom,
    MainShellBottomInset.of(context),
  );
}

/// 悬浮操作按钮距屏幕底部的基准偏移，使详情页按钮与书架保持同一高度。
double mainShellFabBottomInset(BuildContext context) {
  return math.max(
    MediaQuery.paddingOf(context).bottom,
    MainShellBottomInset.fabBottomOf(context),
  );
}
