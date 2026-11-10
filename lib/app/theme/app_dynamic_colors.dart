import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// 保留根导航身份，只在启动、返回前台或系统明暗变化时重新读取系统色板。
class AppDynamicColorBuilder extends StatefulWidget {
  const AppDynamicColorBuilder({super.key, required this.builder});

  final Widget Function(ColorScheme? light, ColorScheme? dark) builder;

  @override
  State<AppDynamicColorBuilder> createState() => _AppDynamicColorBuilderState();
}

class _AppDynamicColorBuilderState extends State<AppDynamicColorBuilder>
    with WidgetsBindingObserver {
  final _key = GlobalKey<DynamicColorBuilderState>();
  Future<void> _refreshTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void didChangePlatformBrightness() => _refresh();

  void _refresh() {
    _refreshTail = _refreshTail.then((_) async {
      if (mounted) await _key.currentState?.initPlatformState();
    });
    unawaited(_refreshTail);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      DynamicColorBuilder(key: _key, builder: widget.builder);
}

class AppDynamicColors extends InheritedWidget {
  const AppDynamicColors({
    super.key,
    required this.light,
    required this.dark,
    required super.child,
  });

  final ColorScheme? light;
  final ColorScheme? dark;

  static AppDynamicColors? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppDynamicColors>();

  bool available(Brightness brightness) =>
      (brightness == Brightness.light ? light : dark) != null;

  @override
  bool updateShouldNotify(AppDynamicColors oldWidget) =>
      oldWidget.light != light || oldWidget.dark != dark;
}
