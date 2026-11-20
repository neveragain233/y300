import 'package:flutter/widgets.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';

/// 全局动效策略：墨水屏模式与系统减少动态效果统一收口为同一开关。
abstract final class AppMotion {
  static bool reduceMotion(BuildContext context) =>
      EInkModeScope.of(context) ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  static Duration duration(BuildContext context, Duration value) =>
      reduceMotion(context) ? Duration.zero : value;
}
