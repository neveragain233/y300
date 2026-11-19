import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/app/eink/eink_epdc_channel.dart';

export 'package:y300/app/eink/eink_epdc_channel.dart'
    show EInkEpdcChannel, EInkModeScope, EInkRippleSpeed, EInkScrollBehavior;

/// Non-bouncing clamping scroll physics that still allows pull-to-refresh on short content.
abstract final class EInkPagePhysics {
  static const ScrollPhysics clampingAlwaysScrollable =
      AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
}

/// Interface for any active scrollable list or paged reader controllable by E-Ink paging keys/buttons.
abstract interface class EInkPageHandler implements Listenable {
  bool get canPageUp;
  bool get canPageDown;
  void pageUp();
  void pageDown();
}

({bool canUp, bool canDown}) _scrollBounds(ScrollController controller) {
  if (controller.positions.length != 1) {
    return (canUp: false, canDown: false);
  }
  final position = controller.position;
  if (!position.hasContentDimensions) {
    return (canUp: false, canDown: false);
  }
  return (
    canUp: position.pixels > position.minScrollExtent + 1.0,
    canDown: position.pixels < position.maxScrollExtent - 1.0,
  );
}

void _jumpScrollBy(
  ScrollController controller,
  int direction,
  double viewportFraction,
) {
  if (controller.positions.length != 1) return;
  final position = controller.position;
  if (!position.hasContentDimensions || !position.hasViewportDimension) {
    return;
  }
  final viewport = position.viewportDimension;
  if (!viewport.isFinite || viewport <= 0) return;
  final step = (viewport * viewportFraction).clamp(120.0, viewport);
  final target = (position.pixels + direction * step).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if ((target - position.pixels).abs() >= 0.5) {
    controller.jumpTo(target);
    unawaited(EInkEpdcChannel.triggerPageRipple(forward: direction > 0));
  }
}

/// Paginated non-animated jump handler backed by a [ScrollController].
class EInkScrollPageHandler extends ChangeNotifier implements EInkPageHandler {
  EInkScrollPageHandler(
    ScrollController controller, {
    this.viewportFraction = 0.85,
  }) : _controller = controller {
    _controller.addListener(_syncBounds);
    _syncBounds(notify: false);
  }

  ScrollController _controller;
  final double viewportFraction;
  bool _canPageUp = false;
  bool _canPageDown = false;
  bool _disposed = false;

  void updateController(ScrollController controller) {
    if (identical(_controller, controller)) return;
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
    if (!_disposed) _jumpScrollBy(_controller, -1, viewportFraction);
  }

  @override
  void pageDown() {
    if (!_disposed) _jumpScrollBy(_controller, 1, viewportFraction);
  }

  void _syncBounds({bool notify = true}) {
    if (_disposed) return;
    final bounds = _scrollBounds(_controller);
    if (bounds.canUp != _canPageUp || bounds.canDown != _canPageDown) {
      _canPageUp = bounds.canUp;
      _canPageDown = bounds.canDown;
      if (notify) {
        notifyListeners();
      }
    }
  }

  void refreshBounds() => _syncBounds();

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_syncBounds);
    super.dispose();
  }
}

/// Callback-backed E-Ink page handler for horizontal/paged readers.
class EInkCallbackPageHandler extends ChangeNotifier implements EInkPageHandler {
  EInkCallbackPageHandler({
    required VoidCallback onPageUp,
    required VoidCallback onPageDown,
    this.canPageUp = false,
    this.canPageDown = false,
    this.handlesEpdcRipple = false,
  }) : _onPageUp = onPageUp,
       _onPageDown = onPageDown;

  final VoidCallback _onPageUp;
  final VoidCallback _onPageDown;
  final bool handlesEpdcRipple;

  @override
  final bool canPageUp;

  @override
  final bool canPageDown;

  @override
  void pageUp() {
    if (canPageUp) _onPageUp();
  }

  @override
  void pageDown() {
    if (canPageDown) _onPageDown();
  }
}

final class _RegisteredPageEntry {
  _RegisteredPageEntry({
    required this.token,
    required this.handler,
    required this.isVisible,
  });

  final Object token;
  final EInkPageHandler handler;
  bool isVisible;
}

/// Global coordinator mapping active visible scrollables/readers to hardware keys and corner buttons.
class EInkPageRegistry extends ChangeNotifier {
  EInkPageRegistry._();

  static final EInkPageRegistry instance = EInkPageRegistry._();

  static const MethodChannel _keysChannel = MethodChannel(
    'com.adws.y300/eink_keys',
  );
  static const int _debounceMs = 180;

  final List<_RegisteredPageEntry> _entries = <_RegisteredPageEntry>[];
  EInkPageHandler? _activeHandler;
  bool _channelInitialized = false;
  bool _userVolumePagingEnabled = false;
  bool? _lastNativeVolumePagingEnabled;
  int _lastKeyActionAtMs = 0;

  EInkPageHandler? get activeHandler => _activeHandler;
  bool get hasActiveHandler => _activeHandler != null;
  bool get userVolumePagingEnabled => _userVolumePagingEnabled;
  bool get _effectiveNativeVolumePagingEnabled =>
      _userVolumePagingEnabled && _activeHandler != null;

  void setUserVolumePagingEnabled(bool enabled) {
    if (_userVolumePagingEnabled == enabled) return;
    _userVolumePagingEnabled = enabled;
    _syncNativeVolumePaging(_effectiveNativeVolumePagingEnabled);
    notifyListeners();
  }

  void ensureHardwareKeysAttached() {
    if (!_channelInitialized) {
      _channelInitialized = true;
      _keysChannel.setMethodCallHandler((call) async {
        if (call.method == 'onHardwarePageKey') {
          final direction = call.arguments as String?;
          if (direction == 'up') {
            triggerPageUp();
          } else if (direction == 'down') {
            triggerPageDown();
          }
        }
      });
      _syncNativeVolumePaging(_effectiveNativeVolumePagingEnabled);
    }
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
  }

  void register(
    Object token,
    EInkPageHandler handler, {
    bool isVisible = true,
  }) {
    final existingIndex = _entries.indexWhere(
      (entry) => identical(entry.token, token),
    );
    if (existingIndex >= 0) {
      _entries.removeAt(existingIndex);
    }
    _entries.add(
      _RegisteredPageEntry(token: token, handler: handler, isVisible: isVisible),
    );
    _recomputeActiveHandler();
  }

  void setVisible(Object token, bool isVisible) {
    final index = _entries.indexWhere((entry) => identical(entry.token, token));
    if (index < 0) return;
    if (_entries[index].isVisible == isVisible) return;
    _entries[index].isVisible = isVisible;
    _recomputeActiveHandler();
  }

  void unregister(Object token) {
    final before = _entries.length;
    _entries.removeWhere((entry) => identical(entry.token, token));
    if (_entries.length != before) {
      _recomputeActiveHandler();
    }
  }

  void triggerPageUp() => _triggerPage(up: true);

  void triggerPageDown() => _triggerPage(up: false);

  void _triggerPage({required bool up}) {
    final handler = _activeHandler;
    if (handler == null || !_tryAcquireDebounce()) return;
    final canTurn = up ? handler.canPageUp : handler.canPageDown;
    if (up) {
      handler.pageUp();
    } else {
      handler.pageDown();
    }
    final alreadyTriggeredRipple =
        handler is EInkScrollPageHandler ||
        (handler is EInkCallbackPageHandler && handler.handlesEpdcRipple);
    if (canTurn && !alreadyTriggeredRipple) {
      unawaited(EInkEpdcChannel.triggerPageRipple(forward: !up));
    }
  }

  bool _tryAcquireDebounce() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastKeyActionAtMs < _debounceMs) {
      return false;
    }
    _lastKeyActionAtMs = nowMs;
    return true;
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    final handler = _activeHandler;
    if (handler == null) return false;
    final key = event.logicalKey;
    final isVolume =
        key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.audioVolumeDown;
    final isPage =
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown;
    final isArrow =
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    if (!isVolume && !isPage && !isArrow) {
      return false;
    }
    if (isVolume && !_userVolumePagingEnabled) {
      return false;
    }
    if (isArrow && _isTextInputFocused()) {
      return false;
    }
    if (event is KeyDownEvent) {
      final isUp =
          key == LogicalKeyboardKey.audioVolumeUp ||
          key == LogicalKeyboardKey.pageUp ||
          key == LogicalKeyboardKey.arrowUp;
      if (isUp) {
        triggerPageUp();
      } else {
        triggerPageDown();
      }
      return true;
    }
    if (event is KeyRepeatEvent || event is KeyUpEvent) {
      return isVolume || isPage;
    }
    return false;
  }

  bool _isTextInputFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    if (focusContext.widget is EditableText) return true;
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _recomputeActiveHandler() {
    EInkPageHandler? next;
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].isVisible) {
        next = _entries[i].handler;
        break;
      }
    }
    if (identical(_activeHandler, next)) return;
    _activeHandler?.removeListener(_relayHandlerUpdate);
    _activeHandler = next;
    _activeHandler?.addListener(_relayHandlerUpdate);
    _syncNativeVolumePaging(_effectiveNativeVolumePagingEnabled);
    notifyListeners();
  }

  void _relayHandlerUpdate() => notifyListeners();

  Future<void> _syncNativeVolumePaging(bool enabled) async {
    if (_lastNativeVolumePagingEnabled == enabled) return;
    _lastNativeVolumePagingEnabled = enabled;
    try {
      await _keysChannel.invokeMethod<void>('setVolumePagingEnabled', enabled);
    } on MissingPluginException {
      // Ignored in pure widget tests without Android host channel.
    } catch (_) {
      // Keep UI resilient if host engine is tearing down.
    }
  }
}

/// Registers a [ScrollController] with [EInkPageRegistry] while mounted and visible
/// when E-Ink mode is active.
class EInkScrollHandlerBinding extends StatefulWidget {
  const EInkScrollHandlerBinding({
    super.key,
    required this.controller,
    required this.child,
    this.viewportFraction = 0.85,
    this.isVisible,
  });

  final ScrollController controller;
  final Widget child;
  final double viewportFraction;
  final bool? isVisible;

  @override
  State<EInkScrollHandlerBinding> createState() =>
      _EInkScrollHandlerBindingState();
}

class _EInkScrollHandlerBindingState extends State<EInkScrollHandlerBinding> {
  final Object _token = Object();
  late final EInkScrollPageHandler _handler;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _handler = EInkScrollPageHandler(
      widget.controller,
      viewportFraction: widget.viewportFraction,
    );
    EInkPageRegistry.instance.ensureHardwareKeysAttached();
  }

  bool _computeVisible(BuildContext context) {
    final isEink = EInkModeScope.of(context);
    if (!isEink) return false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    return (widget.isVisible ?? true) && tickerEnabled && routeCurrent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = _computeVisible(context);
    if (!_registered) {
      _registered = true;
      EInkPageRegistry.instance.register(_token, _handler, isVisible: visible);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handler.refreshBounds();
      });
    } else {
      EInkPageRegistry.instance.setVisible(_token, visible);
    }
  }

  @override
  void didUpdateWidget(covariant EInkScrollHandlerBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _handler.updateController(widget.controller);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handler.refreshBounds();
      });
    }
    if (oldWidget.isVisible != widget.isVisible && _registered) {
      EInkPageRegistry.instance.setVisible(_token, _computeVisible(context));
    }
  }

  @override
  void dispose() {
    EInkPageRegistry.instance.unregister(_token);
    _handler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Unobtrusive icon-only Efficiency E-Ink corner paging buttons (`#FFFFFF` + `#CCCCCC` + `#222222`).
/// Renders nothing when E-Ink mode is disabled.
class EInkCornerPagingButtons extends StatefulWidget {
  const EInkCornerPagingButtons({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.only(right: 12, bottom: 16),
    this.viewportFraction = 0.85,
  });

  final ScrollController controller;
  final EdgeInsetsGeometry padding;
  final double viewportFraction;

  @override
  State<EInkCornerPagingButtons> createState() =>
      _EInkCornerPagingButtonsState();
}

class _EInkCornerPagingButtonsState extends State<EInkCornerPagingButtons> {
  ({bool canUp, bool canDown}) _bounds = (canUp: false, canDown: false);
  bool _postFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncBounds);
    _schedulePostFrameSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePostFrameSync();
  }

  @override
  void didUpdateWidget(covariant EInkCornerPagingButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_syncBounds);
      widget.controller.addListener(_syncBounds);
      _bounds = _scrollBounds(widget.controller);
      _schedulePostFrameSync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncBounds);
    super.dispose();
  }

  void _schedulePostFrameSync() {
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled = false;
      _syncBounds();
    });
  }

  void _syncBounds() {
    if (!mounted) return;
    final next = _scrollBounds(widget.controller);
    if (next.canUp != _bounds.canUp || next.canDown != _bounds.canDown) {
      setState(() {
        _bounds = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!EInkModeScope.of(context)) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveBounds = _scrollBounds(widget.controller);
    final bounds = liveBounds.canUp || liveBounds.canDown ? liveBounds : _bounds;
    if (!bounds.canUp && !bounds.canDown) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCornerButton(
              key: const Key('eink-corner-page-up'),
              icon: Icons.keyboard_arrow_up,
              enabled: bounds.canUp,
              direction: -1,
              isDark: isDark,
            ),
            const SizedBox(height: 6),
            _buildCornerButton(
              key: const Key('eink-corner-page-down'),
              icon: Icons.keyboard_arrow_down,
              enabled: bounds.canDown,
              direction: 1,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerButton({
    required Key key,
    required IconData icon,
    required bool enabled,
    required int direction,
    required bool isDark,
  }) {
    final bg = isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
    final borderColor = enabled
        ? (isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC))
        : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0));
    final fg = enabled
        ? (isDark ? const Color(0xFFEAEAEA) : const Color(0xFF222222))
        : (isDark ? const Color(0xFF5A5A5A) : const Color(0xFFA0A0A0));
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () => _jumpScrollBy(
              widget.controller,
              direction,
              widget.viewportFraction,
            )
          : null,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 22, color: fg),
      ),
    );
  }
}

/// Optional narrow left/right edge tap zones (`pageUp` / `pageDown`) for E-Ink reading.
class EInkEdgeTapOverlay extends StatelessWidget {
  const EInkEdgeTapOverlay({
    super.key,
    required this.enabled,
    required this.child,
    this.edgeWidth = 40,
  });

  final bool enabled;
  final Widget child;
  final double edgeWidth;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !EInkModeScope.of(context)) {
      return child;
    }
    final mediaPadding = MediaQuery.paddingOf(context);
    final topInset = mediaPadding.top + kToolbarHeight;
    final bottomInset = mediaPadding.bottom + 96;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: EInkPageRegistry.instance,
            builder: (context, _) {
              final handler = EInkPageRegistry.instance.activeHandler;
              final canUp = handler?.canPageUp ?? false;
              final canDown = handler?.canPageDown ?? false;
              if (!canUp && !canDown) {
                return const SizedBox.shrink();
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (canUp)
                    _edgeZone(
                      key: const Key('eink-edge-tap-up'),
                      isLeft: true,
                      top: topInset,
                      bottom: bottomInset,
                      onTap: EInkPageRegistry.instance.triggerPageUp,
                    ),
                  if (canDown)
                    _edgeZone(
                      key: const Key('eink-edge-tap-down'),
                      isLeft: false,
                      top: topInset,
                      bottom: bottomInset,
                      onTap: EInkPageRegistry.instance.triggerPageDown,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _edgeZone({
    required Key key,
    required bool isLeft,
    required double top,
    required double bottom,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: top,
      bottom: bottom,
      width: edgeWidth,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
      ),
    );
  }
}

/// Owns a [ScrollController] for stateless scrollable views and attaches
/// [EInkScrollHandlerBinding] + [EInkCornerPagingButtons] when E-Ink mode is active.
class EInkScrollablePager extends StatefulWidget {
  const EInkScrollablePager({
    super.key,
    required this.builder,
    this.padding = const EdgeInsets.only(right: 12, bottom: 16),
    this.isVisible,
  });

  final Widget Function(BuildContext context, ScrollController controller)
  builder;
  final EdgeInsetsGeometry padding;
  final bool? isVisible;

  @override
  State<EInkScrollablePager> createState() => _EInkScrollablePagerState();
}

class _EInkScrollablePagerState extends State<EInkScrollablePager> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EInkScrollHandlerBinding(
      controller: _controller,
      isVisible: widget.isVisible,
      child: Stack(
        children: [
          widget.builder(context, _controller),
          Positioned(
            right: 0,
            bottom: 0,
            child: EInkCornerPagingButtons(
              controller: _controller,
              padding: widget.padding,
            ),
          ),
        ],
      ),
    );
  }
}
