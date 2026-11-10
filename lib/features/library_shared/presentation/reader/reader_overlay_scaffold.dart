import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_bottom_overlay_panel.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_gesture_coordinator.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_models.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_tap_zones.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_top_overlay_bar.dart';

class ReaderOverlayController extends ChangeNotifier {
  bool _isMenuVisible = false;
  _ReaderOverlayScaffoldState? _state;

  bool get isMenuVisible => _state?._isMenuVisible ?? _isMenuVisible;

  void showMenu() {
    final state = _state;
    if (state != null) {
      state._setMenuVisible(true);
      return;
    }
    _setDetachedValue(true);
  }

  void hideMenu() {
    final state = _state;
    if (state != null) {
      state._setMenuVisible(false);
      return;
    }
    _setDetachedValue(false);
  }

  void toggleMenu() {
    final state = _state;
    if (state != null) {
      state._setMenuVisible(!state._isMenuVisible);
      return;
    }
    _setDetachedValue(!_isMenuVisible);
  }

  void _attach(_ReaderOverlayScaffoldState state) {
    _state = state;
    _isMenuVisible = state._isMenuVisible;
  }

  void _detach(_ReaderOverlayScaffoldState state) {
    if (_state != state) {
      return;
    }
    _isMenuVisible = state._isMenuVisible;
    _state = null;
  }

  void _syncFromState(bool value) {
    if (_isMenuVisible == value) {
      return;
    }
    _isMenuVisible = value;
    notifyListeners();
  }

  void _setDetachedValue(bool value) {
    if (_isMenuVisible == value) {
      return;
    }
    _isMenuVisible = value;
    notifyListeners();
  }
}

class ReaderOverlayScaffold extends StatefulWidget {
  const ReaderOverlayScaffold({
    super.key,
    required this.topBar,
    required this.bottomBar,
    required this.child,
    this.persistentFooter,
    this.controller,
    this.onLeftTap,
    this.onCenterTap,
    this.onRightTap,
    this.menuInitiallyVisible = false,
    this.tapZonesEnabled = true,
    this.tapZonesBlockedListenable,
    this.gestureCoordinator,
    this.bottomSafeFraction = 0,
    this.animationDuration = const Duration(milliseconds: 240),
  });

  final ReaderTopBarConfig topBar;
  final ReaderBottomBarConfig bottomBar;
  final Widget child;

  /// Display-only status shown below the tap-zone viewport for the whole
  /// reading session. It is intentionally outside [child] so scroll and tap
  /// geometry never include it.
  final Widget? persistentFooter;
  final ReaderOverlayController? controller;
  final VoidCallback? onLeftTap;
  final VoidCallback? onCenterTap;
  final VoidCallback? onRightTap;
  final bool menuInitiallyVisible;
  final bool tapZonesEnabled;
  final ValueListenable<bool>? tapZonesBlockedListenable;
  final ReaderGestureCoordinator? gestureCoordinator;
  final double bottomSafeFraction;
  final Duration animationDuration;

  @override
  State<ReaderOverlayScaffold> createState() => _ReaderOverlayScaffoldState();
}

class _ReaderOverlayScaffoldState extends State<ReaderOverlayScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _topSlideAnimation;
  late final Animation<Offset> _bottomSlideAnimation;
  late bool _isMenuVisible;
  final _topFocus = FocusScopeNode();
  final _bottomFocus = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    _isMenuVisible =
        widget.menuInitiallyVisible ||
        (widget.controller?.isMenuVisible ?? false);
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: _isMenuVisible ? 1 : 0,
    );
    final curve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _topSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(curve);
    _bottomSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curve);
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationDuration();
  }

  void _updateAnimationDuration() {
    _animationController.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : widget.animationDuration;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animationController.value = _isMenuVisible ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(ReaderOverlayScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimationDuration();
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller?._detach(this);
    final nextVisible = widget.controller?.isMenuVisible;
    if (nextVisible != null) {
      _setMenuVisible(nextVisible);
    }
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _animationController.dispose();
    _topFocus.dispose();
    _bottomFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('shared-reader-overlay-scaffold'),
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ReaderTapZones(
                    enabled: widget.tapZonesEnabled,
                    blockedListenable: widget.tapZonesBlockedListenable,
                    gestureCoordinator: widget.gestureCoordinator,
                    bottomSafeFraction: widget.bottomSafeFraction,
                    onCenterTap: _handleCenterTap,
                    onLeftTap: widget.onLeftTap,
                    onRightTap: widget.onRightTap,
                    child: widget.child,
                  ),
                ],
              ),
            ),
            if (widget.persistentFooter != null)
              KeyedSubtree(
                key: const Key('shared-reader-persistent-footer-slot'),
                child: widget.persistentFooter!,
              ),
          ],
        ),
        Positioned(
          key: const Key('shared-reader-top-overlay'),
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            key: const Key('shared-reader-top-overlay-hit-test-gate'),
            ignoring: !_isMenuVisible,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              excludeSemantics: !_isMenuVisible,
              child: ExcludeFocus(
                excluding: !_isMenuVisible,
                child: FocusScope(
                  node: _topFocus,
                  child: SlideTransition(
                    position: _topSlideAnimation,
                    child: ReaderTopOverlayBar(config: widget.topBar),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          key: const Key('shared-reader-bottom-overlay'),
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            key: const Key('shared-reader-bottom-overlay-hit-test-gate'),
            ignoring: !_isMenuVisible,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              excludeSemantics: !_isMenuVisible,
              child: ExcludeFocus(
                excluding: !_isMenuVisible,
                child: FocusScope(
                  node: _bottomFocus,
                  child: SlideTransition(
                    position: _bottomSlideAnimation,
                    child: ReaderBottomOverlayPanel(config: widget.bottomBar),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _setMenuVisible(bool visible) {
    if (_isMenuVisible == visible) {
      return;
    }
    if (!visible) {
      if (_topFocus.hasFocus) _topFocus.unfocus();
      if (_bottomFocus.hasFocus) _bottomFocus.unfocus();
    }
    setState(() {
      _isMenuVisible = visible;
    });
    widget.controller?._syncFromState(visible);
    if (_isMenuVisible) {
      _animationController.forward();
      return;
    }
    _animationController.reverse();
  }

  void _handleCenterTap() {
    _setMenuVisible(!_isMenuVisible);
    widget.onCenterTap?.call();
  }
}
