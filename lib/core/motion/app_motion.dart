import 'package:flutter/widgets.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';

/// 全局动效策略：墨水屏模式下统一关闭动画，其余模式跟随系统。
///
/// 主题、页面与组件都从这里取时长，不再各自判断构建变体。阅读器内部
/// 用 [MediaQuery.disableAnimations] 恢复翻页动画，所以这里只回答
/// “当前是否要求减少动效”，不替代阅读器自己的动画开关。
abstract final class AppMotion {
  static bool reduceMotion(BuildContext context) => EInkModeScope.of(context);

  static Duration duration(BuildContext context, Duration value) =>
      reduceMotion(context) ? Duration.zero : value;
}
