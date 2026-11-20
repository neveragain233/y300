import 'package:flutter/widgets.dart';

/// 把运行时墨水屏模式投影给不能读取 Riverpod 的子树。
///
/// 应用根在 `MaterialApp.builder` 里包住全部路由；`packages/` 内的组件和
/// 纯组件测试可以直接读取该 scope，不引入第二套全局状态。
class EInkModeScope extends InheritedWidget {
  const EInkModeScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<EInkModeScope>()
            ?.enabled ??
        false;
  }

  @override
  bool updateShouldNotify(EInkModeScope oldWidget) =>
      oldWidget.enabled != enabled;
}
