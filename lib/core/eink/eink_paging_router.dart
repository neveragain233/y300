import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/eink/eink_hardware_page_keys.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';

/// 可被硬件翻页键与角标驱动的目标：阅读器、横向分页或滚动列表。
///
/// [canPageUp] 与 [canPageDown] 供角标与边缘层决定是否出现、是否禁用；
/// 实体键仍直接调用 [pageUp]/[pageDown]，由实现自行在边界上退化为无操作。
abstract interface class EInkPageHandler {
  bool get canPageUp;

  bool get canPageDown;

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

  /// 同一次按键回弹内只放行一次；墨水屏上连续重复事件既无意义又会重绘。
  static const Duration _keyDebounce = Duration(milliseconds: 180);

  final EInkHardwarePageKeysService _keys;
  final EInkPageRippleService _ripple;
  final List<_EInkPageEntry> _entries = <_EInkPageEntry>[];
  StreamSubscription<HardwarePageKeyDirection>? _subscription;
  DateTime? _lastKeyAt;
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
    if (enabled) {
      // 只有用户打开开关才接触宿主通道；默认关闭时不订阅方向也不发消息。
      _ensureSubscribed();
    }
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

  /// 文本输入聚焦时实体翻页键让位给光标移动与输入法。
  ///
  /// 主焦点自身是 [EditableText]，或挂在 [EditableText] 内部（例如选择手柄）
  /// 都算文本输入。
  bool get _isTextInputFocused {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) {
      return false;
    }
    if (focusContext.widget is EditableText) {
      return true;
    }
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _onDirection(HardwarePageKeyDirection direction) {
    if (!_hardwareKeysEnabled || _isTextInputFocused) {
      return;
    }
    final handler = _activeHandler;
    if (handler == null) {
      return;
    }
    final now = DateTime.now();
    final last = _lastKeyAt;
    if (last != null && now.difference(last) < _keyDebounce) {
      return;
    }
    _lastKeyAt = now;
    if (direction == HardwarePageKeyDirection.previous) {
      handler.pageUp();
    } else {
      handler.pageDown();
    }
  }

  void _syncNative() {
    if (!_hardwareKeysEnabled) {
      // 默认关闭：不订阅方向、不打开拦截，只撤销此前的拦截。
      if (_lastNativeEnabled == true) {
        _lastNativeEnabled = false;
        unawaited(_keys.setEnabled(false));
      }
      return;
    }
    _ensureSubscribed();
    final enabled = _activeHandler != null;
    if (_lastNativeEnabled == enabled) {
      return;
    }
    if (!enabled && _lastNativeEnabled != true) {
      // 开关打开但还没有目标：不打开拦截，也不补发关闭消息。
      return;
    }
    _lastNativeEnabled = enabled;
    unawaited(_keys.setEnabled(enabled));
  }

  /// 为滚动列表创建步进目标；角标、边缘点击与实体键共用同一实现。
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
///
/// 监听控制器的滚动与挂载变化来维护可翻方向；布局首次完成后由持有方调用
/// [refreshBounds]，因为首帧尺寸确定时控制器不一定再发通知。
class EInkScrollPageHandler extends ChangeNotifier implements EInkPageHandler {
  EInkScrollPageHandler(
    ScrollController controller, {
    required this.ripple,
    this.viewportFraction = 0.85,
  }) : _controller = controller {
    _controller.addListener(_syncBounds);
    _syncBounds(notify: false);
  }

  ScrollController _controller;
  final EInkPageRippleService ripple;
  final double viewportFraction;
  bool _canPageUp = false;
  bool _canPageDown = false;
  bool _disposed = false;

  ScrollController get controller => _controller;

  /// 页面重建或切换列表时替换控制器；监听随之迁移并立即重算边界。
  set controller(ScrollController controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _controller.removeListener(_syncBounds);
    _controller = controller;
    _controller.addListener(_syncBounds);
    _syncBounds();
  }

  @override
  bool get canPageUp => _canPageUp;

  @override
  bool get canPageDown => _canPageDown;

  @override
  void pageUp() {
    if (!_disposed) {
      _jump(-1);
    }
  }

  @override
  void pageDown() {
    if (!_disposed) {
      _jump(1);
    }
  }

  /// 布局确定后可翻方向可能变化但控制器没有通知，由持有方在首帧后调用。
  void refreshBounds() => _syncBounds();

  void _syncBounds({bool notify = true}) {
    if (_disposed) {
      return;
    }
    final bounds = _readBounds();
    if (bounds.canUp == _canPageUp && bounds.canDown == _canPageDown) {
      return;
    }
    _canPageUp = bounds.canUp;
    _canPageDown = bounds.canDown;
    if (notify) {
      notifyListeners();
    }
  }

  ({bool canUp, bool canDown}) _readBounds() {
    if (_controller.positions.length != 1) {
      return (canUp: false, canDown: false);
    }
    final position = _controller.position;
    if (!position.hasContentDimensions) {
      return (canUp: false, canDown: false);
    }
    return (
      canUp: position.pixels > position.minScrollExtent + 1.0,
      canDown: position.pixels < position.maxScrollExtent - 1.0,
    );
  }

  void _jump(int direction) {
    if (_controller.positions.length != 1) {
      return;
    }
    final position = _controller.position;
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
    _controller.jumpTo(target);
    unawaited(
      ripple.triggerPageRipple(
        forward: direction > 0,
        speed: EInkRippleSpeed.standard,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_syncBounds);
    super.dispose();
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
