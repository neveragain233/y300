import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/eink/eink_hardware_page_keys.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';

/// 可被硬件翻页键驱动的目标：阅读器或滚动列表。
abstract interface class EInkPageHandler {
  void pageUp();

  void pageDown();
}

class _EInkPageEntry {
  _EInkPageEntry({
    required this.token,
    required this.handler,
    required this.isVisible,
  });

  final Object token;
  final EInkPageHandler handler;
  bool isVisible;
}

/// 硬件翻页键与边缘步进的仲裁器。
///
/// 页面按打开顺序注册，按键只交给最后注册且可见的目标。原生拦截的开关
/// 由用户偏好与“是否存在活动目标”共同决定：列表页注册不会自行打开音量
/// 键拦截，只有阅读器打开开关后才会。
class EInkPagingRouter {
  EInkPagingRouter(this._keys, this._ripple);

  final EInkHardwarePageKeysService _keys;
  final EInkPageRippleService _ripple;
  final List<_EInkPageEntry> _entries = <_EInkPageEntry>[];
  StreamSubscription<HardwarePageKeyDirection>? _subscription;
  bool _hardwareKeysEnabled = false;
  bool? _lastNativeEnabled;

  void _ensureSubscribed() {
    _subscription ??= _keys.directions.listen(_onDirection);
  }

  void setHardwareKeysEnabled(bool enabled) {
    if (_hardwareKeysEnabled == enabled) {
      return;
    }
    _hardwareKeysEnabled = enabled;
    _syncNative();
  }

  void register(
    Object token,
    EInkPageHandler handler, {
    bool isVisible = true,
  }) {
    _entries.removeWhere((entry) => identical(entry.token, token));
    _entries.add(
      _EInkPageEntry(token: token, handler: handler, isVisible: isVisible),
    );
    _syncNative();
  }

  void setVisible(Object token, bool isVisible) {
    final index = _entries.indexWhere((entry) => identical(entry.token, token));
    if (index < 0 || _entries[index].isVisible == isVisible) {
      return;
    }
    _entries[index].isVisible = isVisible;
    _syncNative();
  }

  void unregister(Object token) {
    final before = _entries.length;
    _entries.removeWhere((entry) => identical(entry.token, token));
    if (_entries.length != before) {
      _syncNative();
    }
  }

  EInkPageHandler? get _activeHandler {
    for (var index = _entries.length - 1; index >= 0; index--) {
      if (_entries[index].isVisible) {
        return _entries[index].handler;
      }
    }
    return null;
  }

  void _onDirection(HardwarePageKeyDirection direction) {
    if (!_hardwareKeysEnabled) {
      return;
    }
    final handler = _activeHandler;
    if (handler == null) {
      return;
    }
    if (direction == HardwarePageKeyDirection.previous) {
      handler.pageUp();
    } else {
      handler.pageDown();
    }
  }

  void _syncNative() {
    _ensureSubscribed();
    final enabled = _hardwareKeysEnabled && _activeHandler != null;
    if (_lastNativeEnabled == enabled) {
      return;
    }
    _lastNativeEnabled = enabled;
    unawaited(_keys.setEnabled(enabled));
  }

  /// 为滚动列表创建步进目标；边缘点击与实体键共用同一实现。
  EInkScrollPageHandler createScrollHandler(ScrollController controller) {
    return EInkScrollPageHandler(controller, ripple: _ripple);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _entries.clear();
  }
}

/// 基于滚动控制器的步进目标：每次移动 85% 视口并触发一次 EPDC。
class EInkScrollPageHandler implements EInkPageHandler {
  EInkScrollPageHandler(
    this.controller, {
    required this.ripple,
    this.viewportFraction = 0.85,
  });

  ScrollController controller;
  final EInkPageRippleService ripple;
  final double viewportFraction;

  @override
  void pageUp() {
    _jump(-1);
  }

  @override
  void pageDown() {
    _jump(1);
  }

  void _jump(int direction) {
    if (controller.positions.length != 1) {
      return;
    }
    final position = controller.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return;
    }
    final viewport = position.viewportDimension;
    if (!viewport.isFinite || viewport <= 0) {
      return;
    }
    final step = (viewport * viewportFraction).clamp(120.0, viewport);
    final target = (position.pixels + direction * step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) {
      return;
    }
    controller.jumpTo(target);
    unawaited(
      ripple.triggerPageRipple(
        forward: direction > 0,
        speed: EInkRippleSpeed.standard,
      ),
    );
  }
}

final eInkPagingRouterProvider = Provider<EInkPagingRouter>((ref) {
  final router = EInkPagingRouter(
    ref.watch(einkHardwarePageKeysServiceProvider),
    ref.watch(einkPageRippleServiceProvider),
  );
  ref.onDispose(router.dispose);
  return router;
});
