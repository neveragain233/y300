import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 在原提示队列的布局处避让覆盖层，不重新创建提示或改变其时限。
class TransientFeedbackLayout extends StatefulWidget {
  const TransientFeedbackLayout({
    super.key,
    required this.bottomOverlap,
    required this.child,
  });

  final double bottomOverlap;
  final Widget child;

  @override
  State<TransientFeedbackLayout> createState() =>
      _TransientFeedbackLayoutState();
}

class _TransientFeedbackLayoutState extends State<TransientFeedbackLayout> {
  final _obstacles = <Object, double>{};

  void update(Object owner, double bottom) {
    if (!mounted || (_obstacles[owner] ?? 0) == bottom) return;
    setState(() {
      if (bottom == 0) {
        _obstacles.remove(owner);
      } else {
        _obstacles[owner] = bottom;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final overlap = keyboard
        ? 0.0
        : _obstacles.values.fold(
            widget.bottomOverlap,
            (value, next) => math.max(value, next),
          );
    final theme = SnackBarTheme.of(context);
    final margin =
        theme.insetPadding ?? const EdgeInsets.fromLTRB(15, 5, 15, 10);
    return _FeedbackScope(
      host: this,
      child: SnackBarTheme(
        data: theme.copyWith(
          behavior: SnackBarBehavior.floating,
          insetPadding: margin.copyWith(
            bottom:
                margin.bottom +
                math.max(0, overlap - MediaQuery.viewPaddingOf(context).bottom),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// 由页面报告原生 Scaffold 无法感知的内部浮层；独立路由沿原生避让。
class TransientFeedbackObstacle extends StatefulWidget {
  const TransientFeedbackObstacle({
    super.key,
    required this.bottom,
    required this.child,
  });

  final double bottom;
  final Widget child;

  @override
  State<TransientFeedbackObstacle> createState() =>
      _TransientFeedbackObstacleState();
}

class _TransientFeedbackObstacleState extends State<TransientFeedbackObstacle> {
  _TransientFeedbackLayoutState? _host;
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_FeedbackScope>()
        ?.host;
    final active =
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    final previous = _host;
    _host = host;
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      if (previous != host) previous?.update(this, 0);
      host?.update(this, active ? widget.bottom : 0);
    });
    return widget.child;
  }

  @override
  void dispose() {
    final host = _host;
    WidgetsBinding.instance.addPostFrameCallback((_) => host?.update(this, 0));
    super.dispose();
  }
}

class _FeedbackScope extends InheritedWidget {
  const _FeedbackScope({required this.host, required super.child});
  final _TransientFeedbackLayoutState host;
  @override
  bool updateShouldNotify(_FeedbackScope oldWidget) => oldWidget.host != host;
}
