import 'package:flutter/widgets.dart';

/// 宿主可组合书架入口；独立书架和搜索、选择模式保留各自的标题栏。
class ShelfPageTitleScope extends InheritedWidget {
  const ShelfPageTitleScope({super.key, this.title, required super.child});

  final Widget? title;

  static Widget? titleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShelfPageTitleScope>()?.title;

  @override
  bool updateShouldNotify(ShelfPageTitleScope oldWidget) =>
      oldWidget.title != title;
}
