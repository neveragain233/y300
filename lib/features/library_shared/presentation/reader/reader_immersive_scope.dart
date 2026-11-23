import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_system_ui_controller.dart';

/// 跨阅读器实例协调沉浸全屏系统栏状态，避免嵌套阅读器互相覆盖。
///
/// 例如小说阅读器内点开插图进入图片阅读器时，底层与顶层阅读器各有自己的
/// owner；只要仍有任一阅读器处于激活态，系统栏就保持沉浸，直到最后一个
/// 激活阅读器退出或失焦才恢复系统栏。
final class ReaderImmersiveCoordinator {
  ReaderImmersiveCoordinator(this._controller);

  final ReaderSystemUiController _controller;
  final Set<Object> _activeOwners = <Object>{};

  void setActive(Object owner, bool active) {
    final wasEmpty = _activeOwners.isEmpty;
    final changed = active
        ? _activeOwners.add(owner)
        : _activeOwners.remove(owner);
    if (!changed) {
      return;
    }
    final isEmpty = _activeOwners.isEmpty;
    if (wasEmpty && !isEmpty) {
      unawaited(_controller.enterImmersive().catchError((Object _) {}));
    } else if (!wasEmpty && isEmpty) {
      unawaited(_controller.restore().catchError((Object _) {}));
    }
  }
}

final readerImmersiveCoordinatorProvider = Provider<ReaderImmersiveCoordinator>(
  (ref) =>
      ReaderImmersiveCoordinator(ref.watch(readerSystemUiControllerProvider)),
);

/// 根据开关、生命周期、路由栈位置与 Ticker 状态自动驱动阅读器沉浸全屏。
class ReaderImmersiveScope extends ConsumerStatefulWidget {
  const ReaderImmersiveScope({
    super.key,
    required this.enabled,
    this.holdWhenRouteCovered = false,
    required this.child,
  });

  /// 用户偏好开关；为 false 时不进入沉浸全屏。
  final bool enabled;

  /// 当阅读器自身的设置抽屉等浮层盖住路由时保持沉浸态，以便实时预览开关变化。
  final bool holdWhenRouteCovered;

  final Widget child;

  @override
  ConsumerState<ReaderImmersiveScope> createState() =>
      _ReaderImmersiveScopeState();
}

class _ReaderImmersiveScopeState extends ConsumerState<ReaderImmersiveScope>
    with WidgetsBindingObserver {
  late final ReaderImmersiveCoordinator _coordinator;
  bool _resumed = true;
  bool _routeCurrent = true;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(readerImmersiveCoordinatorProvider);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(covariant ReaderImmersiveScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.holdWhenRouteCovered != widget.holdWhenRouteCovered) {
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_resumed == resumed) {
      return;
    }
    _resumed = resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.setActive(this, false);
    super.dispose();
  }

  void _sync() {
    final active =
        widget.enabled &&
        _resumed &&
        _tickerEnabled &&
        (_routeCurrent || widget.holdWhenRouteCovered);
    _coordinator.setActive(this, active);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
