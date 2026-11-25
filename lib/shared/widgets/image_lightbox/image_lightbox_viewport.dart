import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/image_lightbox/image_lightbox_zoom_math.dart';

/// 供外层灯箱壳查询当前缩放状态与触发“适宽 / 还原”切换的控制器。
class ImageLightboxZoomController extends ChangeNotifier {
  bool _isZoomed = false;
  bool _isLongOrWideImage = false;
  VoidCallback? _onToggleFit;

  bool get isZoomed => _isZoomed;
  bool get isLongOrWideImage => _isLongOrWideImage;

  void toggleFit() => _onToggleFit?.call();

  void _attach(VoidCallback callback) {
    _onToggleFit = callback;
  }

  void _detach(VoidCallback callback) {
    if (identical(_onToggleFit, callback)) {
      _onToggleFit = null;
    }
  }

  void _updateState({required bool isZoomed, required bool isLongOrWideImage}) {
    if (_isZoomed == isZoomed && _isLongOrWideImage == isLongOrWideImage) {
      return;
    }
    _isZoomed = isZoomed;
    _isLongOrWideImage = isLongOrWideImage;
    notifyListeners();
  }
}

/// 社媒灯箱单图手势与缩放视口。
///
/// 1x 状态下保留水平滑动给外层 `PageView`，仅响应点击、双击与向下拖拽关闭；
/// 放大状态下接管拖拽平移、惯性滑行、双指捏合回弹与贴边切图交接。
class ImageLightboxViewport extends StatefulWidget {
  const ImageLightboxViewport({
    super.key,
    required this.child,
    this.imageSize,
    this.aspectRatio,
    this.zoomController,
    this.isActivePage = true,
    this.onSingleTap,
    this.onZoomChanged,
    this.onDismissProgressChanged,
    this.onDismissRequested,
    this.onEdgePageTurn,
  });

  final Widget child;
  final Size? imageSize;
  final double? aspectRatio;
  final ImageLightboxZoomController? zoomController;
  final bool isActivePage;
  final VoidCallback? onSingleTap;
  final ValueChanged<bool>? onZoomChanged;
  final ValueChanged<double>? onDismissProgressChanged;
  final VoidCallback? onDismissRequested;
  final ValueChanged<int>? onEdgePageTurn;

  @override
  State<ImageLightboxViewport> createState() => _ImageLightboxViewportState();
}

class _ImageLightboxViewportState extends State<ImageLightboxViewport>
    with TickerProviderStateMixin {
  static const Duration _snapDuration = Duration(milliseconds: 180);
  static const double _dismissDistanceThreshold = 110.0;
  static const double _dismissVelocityThreshold = 700.0;
  static const double _dismissFadeDistance = 260.0;
  static const double _edgeTurnThreshold = 48.0;

  late final AnimationController _snapController;
  late final AnimationController _flingController;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _translationAnimation;
  Animation<double>? _dismissAnimation;
  bool? _snapTargetZoomed;

  Offset _flingStartTranslation = Offset.zero;
  Offset _flingDirection = Offset.zero;

  double _scale = 1.0;
  Offset _translation = Offset.zero;
  bool _isZoomed = false;
  double _dismissOffsetY = 0.0;
  bool _dismissDragging = false;

  Size _viewportSize = Size.zero;
  Offset _lastDoubleTapDownPosition = Offset.zero;

  final Map<int, Offset> _activePointers = <int, Offset>{};
  bool _pinchActive = false;
  List<int> _pinchPointerIds = const <int>[];
  double _pinchInitialDistance = 0.0;
  double _pinchInitialScale = 1.0;
  Offset _pinchInitialSceneFocal = Offset.zero;

  double _edgeDragAccum = 0.0;
  int _edgeDragSign = 0;
  bool _edgeTurnFired = false;

  bool get _reduceMotion =>
      EInkModeScope.of(context) || AppMotion.reduceMotion(context);

  Rect get _fittedRect => computeFittedImageRect(
    viewportSize: _viewportSize,
    imageSize: widget.imageSize,
    aspectRatio: widget.aspectRatio,
  );

  ImageLightboxScaleBounds get _bounds => computeLightboxScaleBounds(
    viewportSize: _viewportSize,
    fittedRect: _fittedRect,
  );

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this, duration: _snapDuration)
      ..addListener(_onSnapTick)
      ..addStatusListener(_onSnapStatus);
    _flingController = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    widget.zoomController?._attach(_handleFitToggle);
  }

  @override
  void didUpdateWidget(ImageLightboxViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoomController != widget.zoomController) {
      oldWidget.zoomController?._detach(_handleFitToggle);
      widget.zoomController?._attach(_handleFitToggle);
    }
    if (oldWidget.isActivePage && !widget.isActivePage) {
      _resetImmediate();
    } else if (oldWidget.imageSize != widget.imageSize ||
        oldWidget.aspectRatio != widget.aspectRatio) {
      _syncZoomController();
      if (_isZoomed && !_pinchActive) {
        _translation = clampLightboxTranslation(
          viewportSize: _viewportSize,
          fittedRect: _fittedRect,
          scale: _scale,
          translation: _translation,
        );
      }
    }
  }

  @override
  void dispose() {
    widget.zoomController?._detach(_handleFitToggle);
    _snapController
      ..removeListener(_onSnapTick)
      ..removeStatusListener(_onSnapStatus)
      ..dispose();
    _flingController
      ..removeListener(_onFlingTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = constraints.biggest;
        if (_viewportSize != nextSize) {
          final hadSize = _viewportSize != Size.zero;
          _viewportSize = nextSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (hadSize && _isZoomed) {
              _resetImmediate();
            } else {
              _syncZoomController();
            }
          });
        }

        final dismissProgress = (_dismissOffsetY / _dismissFadeDistance).clamp(
          0.0,
          1.0,
        );
        final dismissScale = _reduceMotion
            ? 1.0
            : (1.0 - dismissProgress * 0.28).clamp(0.72, 1.0);

        final matrix = ImageLightboxTransform(
          scale: _scale,
          translation: _translation,
        ).toMatrix4();

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onSingleTap,
            onDoubleTapDown: (details) =>
                _lastDoubleTapDownPosition = details.localPosition,
            onDoubleTap: _onDoubleTap,
            onVerticalDragStart: _isZoomed ? null : _onDismissDragStart,
            onVerticalDragUpdate: _isZoomed ? null : _onDismissDragUpdate,
            onVerticalDragEnd: _isZoomed ? null : _onDismissDragEnd,
            onVerticalDragCancel: _isZoomed ? null : _onDismissDragCancel,
            onPanStart: _isZoomed ? _onPanStart : null,
            onPanUpdate: _isZoomed ? _onPanUpdate : null,
            onPanEnd: _isZoomed ? _onPanEnd : null,
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(0, _dismissOffsetY),
                child: Transform.scale(
                  scale: dismissScale,
                  child: Transform(
                    key: const Key('image-lightbox-transform'),
                    alignment: Alignment.topLeft,
                    transform: matrix,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleFitToggle() {
    if (_viewportSize.isEmpty) return;
    _stopAnimations();
    final target = computeFitToggleTransform(
      viewportSize: _viewportSize,
      fittedRect: _fittedRect,
      currentScale: _scale,
    );
    _animateTransformTo(target, targetZoomed: target.scale > 1.02);
  }

  void _onDoubleTap() {
    if (_viewportSize.isEmpty || _pinchActive) return;
    _stopAnimations();
    final target = computeDoubleTapTransform(
      viewportSize: _viewportSize,
      fittedRect: _fittedRect,
      focalPoint: _lastDoubleTapDownPosition,
      currentScale: _scale,
    );
    _animateTransformTo(target, targetZoomed: target.scale > 1.02);
  }

  void _onPointerDown(PointerDownEvent event) {
    _stopFling();
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      _startPinch();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_pinchActive) {
      _updatePinch();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _finishPointer(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _finishPointer(event.pointer);
  }

  void _finishPointer(int pointer) {
    final wasPinch = _pinchActive && _pinchPointerIds.contains(pointer);
    _activePointers.remove(pointer);
    if (wasPinch && _activePointers.length < 2) {
      _finishPinch();
    }
  }

  void _startPinch() {
    final ids = _activePointers.keys.take(2).toList(growable: false);
    final first = _activePointers[ids[0]]!;
    final second = _activePointers[ids[1]]!;
    final distance = (second - first).distance;
    if (distance <= 0.5) return;

    _stopAnimations();
    if (_dismissOffsetY != 0) {
      _dismissOffsetY = 0;
      _dismissDragging = false;
      widget.onDismissProgressChanged?.call(0.0);
    }

    final focal = Offset(
      (first.dx + second.dx) / 2,
      (first.dy + second.dy) / 2,
    );
    _pinchActive = true;
    _pinchPointerIds = ids;
    _pinchInitialDistance = distance;
    _pinchInitialScale = _scale;
    _pinchInitialSceneFocal = (focal - _translation) / _scale;
    _setZoomed(true);
  }

  void _updatePinch() {
    if (_pinchPointerIds.length != 2) return;
    final first = _activePointers[_pinchPointerIds[0]];
    final second = _activePointers[_pinchPointerIds[1]];
    if (first == null || second == null) return;

    final distance = (second - first).distance;
    final rawScale = _pinchInitialScale * (distance / _pinchInitialDistance);
    final maxScale = _bounds.maxScale;
    final clampedScale = rawScale.clamp(0.72, maxScale * 1.25).toDouble();
    final focal = Offset(
      (first.dx + second.dx) / 2,
      (first.dy + second.dy) / 2,
    );
    var nextTranslation = focal - _pinchInitialSceneFocal * clampedScale;
    if (clampedScale > 1.001) {
      nextTranslation = clampLightboxTranslation(
        viewportSize: _viewportSize,
        fittedRect: _fittedRect,
        scale: clampedScale,
        translation: nextTranslation,
      );
    } else {
      final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
      nextTranslation = center * (1 - clampedScale);
    }
    setState(() {
      _scale = clampedScale;
      _translation = nextTranslation;
    });
  }

  void _finishPinch() {
    _pinchActive = false;
    _pinchPointerIds = const <int>[];
    final maxScale = _bounds.maxScale;
    if (_scale <= 1.02) {
      _animateTransformTo(ImageLightboxTransform.identity, targetZoomed: false);
      return;
    }
    final targetScale = _scale.clamp(1.0, maxScale).toDouble();
    final targetTranslation = clampLightboxTranslation(
      viewportSize: _viewportSize,
      fittedRect: _fittedRect,
      scale: targetScale,
      translation: _translation,
    );
    _animateTransformTo(
      ImageLightboxTransform(
        scale: targetScale,
        translation: targetTranslation,
      ),
      targetZoomed: true,
    );
  }

  void _onDismissDragStart(DragStartDetails details) {
    if (_pinchActive || _isZoomed) return;
    _stopAnimations();
    _dismissDragging = true;
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    if (!_dismissDragging || _pinchActive || _isZoomed) return;
    if (_dismissOffsetY == 0 && details.delta.dy <= 0) {
      return;
    }
    final nextOffset = (_dismissOffsetY + details.delta.dy).clamp(
      0.0,
      _viewportSize.height > 0 ? _viewportSize.height : 800.0,
    );
    if (nextOffset == _dismissOffsetY) return;
    setState(() => _dismissOffsetY = nextOffset);
    widget.onDismissProgressChanged?.call(
      (_dismissOffsetY / _dismissFadeDistance).clamp(0.0, 1.0),
    );
  }

  void _onDismissDragEnd(DragEndDetails details) {
    if (!_dismissDragging) return;
    _dismissDragging = false;
    final velocityY = details.velocity.pixelsPerSecond.dy;
    if (_dismissOffsetY >= _dismissDistanceThreshold ||
        (_dismissOffsetY > 16 && velocityY >= _dismissVelocityThreshold)) {
      widget.onDismissRequested?.call();
      return;
    }
    _springBackDismiss();
  }

  void _onDismissDragCancel() {
    if (!_dismissDragging) return;
    _dismissDragging = false;
    _springBackDismiss();
  }

  void _springBackDismiss() {
    if (_dismissOffsetY == 0) {
      widget.onDismissProgressChanged?.call(0.0);
      return;
    }
    if (_reduceMotion) {
      setState(() => _dismissOffsetY = 0.0);
      widget.onDismissProgressChanged?.call(0.0);
      return;
    }
    _stopSnap();
    _dismissAnimation = Tween<double>(begin: _dismissOffsetY, end: 0.0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController
      ..reset()
      ..forward();
  }

  void _onPanStart(DragStartDetails details) {
    _stopFling();
    _edgeDragAccum = 0.0;
    _edgeDragSign = 0;
    _edgeTurnFired = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_pinchActive || !_isZoomed) return;
    final nextTranslation = clampLightboxTranslation(
      viewportSize: _viewportSize,
      fittedRect: _fittedRect,
      scale: _scale,
      translation: _translation + details.delta,
    );
    final edge = computeLightboxEdgeState(
      viewportSize: _viewportSize,
      fittedRect: _fittedRect,
      scale: _scale,
      translation: nextTranslation,
    );
    if (details.delta.dx.abs() > details.delta.dy.abs()) {
      if (details.delta.dx > 0 && edge.atLeftEdge) {
        _accumulateEdgeTurn(sign: -1, delta: details.delta.dx);
      } else if (details.delta.dx < 0 && edge.atRightEdge) {
        _accumulateEdgeTurn(sign: 1, delta: -details.delta.dx);
      } else {
        _edgeDragAccum = 0.0;
        _edgeDragSign = 0;
      }
    }
    if (nextTranslation == _translation) return;
    setState(() => _translation = nextTranslation);
  }

  void _accumulateEdgeTurn({required int sign, required double delta}) {
    if (_edgeTurnFired) return;
    if (_edgeDragSign != sign) {
      _edgeDragSign = sign;
      _edgeDragAccum = 0.0;
    }
    _edgeDragAccum += delta;
    if (_edgeDragAccum >= _edgeTurnThreshold) {
      _edgeTurnFired = true;
      widget.onEdgePageTurn?.call(sign);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_pinchActive || !_isZoomed || _edgeTurnFired || _reduceMotion) {
      return;
    }
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    if (speed <= 50.0) return;
    _flingStartTranslation = _translation;
    _flingDirection = velocity / speed;
    final simulation = FrictionSimulation(0.035, 0.0, speed);
    _flingController.animateWith(simulation);
  }

  void _onFlingTick() {
    if (!_isZoomed || _pinchActive) {
      _stopFling();
      return;
    }
    final candidate =
        _flingStartTranslation + _flingDirection * _flingController.value;
    final clamped = clampLightboxTranslation(
      viewportSize: _viewportSize,
      fittedRect: _fittedRect,
      scale: _scale,
      translation: candidate,
    );
    if ((clamped - _translation).distance < 0.1) {
      _stopFling();
      return;
    }
    setState(() => _translation = clamped);
  }

  void _animateTransformTo(
    ImageLightboxTransform target, {
    required bool targetZoomed,
  }) {
    if (_reduceMotion) {
      _stopAnimations();
      setState(() {
        _scale = target.scale;
        _translation = target.translation;
      });
      _setZoomed(targetZoomed);
      return;
    }
    _stopSnap();
    if (targetZoomed) {
      _setZoomed(true);
    }
    _snapTargetZoomed = targetZoomed;
    final curve = CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: _scale,
      end: target.scale,
    ).animate(curve);
    _translationAnimation = Tween<Offset>(
      begin: _translation,
      end: target.translation,
    ).animate(curve);
    _snapController
      ..reset()
      ..forward();
  }

  void _onSnapTick() {
    final scaleAnim = _scaleAnimation;
    final transAnim = _translationAnimation;
    final dismissAnim = _dismissAnimation;
    if (dismissAnim != null) {
      setState(() => _dismissOffsetY = dismissAnim.value);
      widget.onDismissProgressChanged?.call(
        (_dismissOffsetY / _dismissFadeDistance).clamp(0.0, 1.0),
      );
      return;
    }
    if (scaleAnim == null || transAnim == null) return;
    setState(() {
      _scale = scaleAnim.value;
      _translation = transAnim.value;
    });
  }

  void _onSnapStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final targetZoomed = _snapTargetZoomed;
    final hadDismiss = _dismissAnimation != null;
    _scaleAnimation = null;
    _translationAnimation = null;
    _dismissAnimation = null;
    _snapTargetZoomed = null;
    if (hadDismiss) {
      setState(() => _dismissOffsetY = 0.0);
      widget.onDismissProgressChanged?.call(0.0);
    }
    if (targetZoomed != null) {
      if (!targetZoomed) {
        setState(() {
          _scale = 1.0;
          _translation = Offset.zero;
        });
      }
      _setZoomed(targetZoomed);
    }
  }

  void _stopAnimations() {
    _stopSnap();
    _stopFling();
  }

  void _stopSnap() {
    _snapController.stop();
    _scaleAnimation = null;
    _translationAnimation = null;
    _dismissAnimation = null;
    _snapTargetZoomed = null;
  }

  void _stopFling() {
    if (_flingController.isAnimating) {
      _flingController.stop();
    }
  }

  void _setZoomed(bool zoomed) {
    if (_isZoomed != zoomed) {
      setState(() => _isZoomed = zoomed);
      widget.onZoomChanged?.call(zoomed);
    }
    _syncZoomController();
  }

  void _syncZoomController() {
    final bounds = _bounds;
    widget.zoomController?._updateState(
      isZoomed: _isZoomed,
      isLongOrWideImage: bounds.isLongImage || bounds.isWideImage,
    );
  }

  void _resetImmediate() {
    _stopAnimations();
    _activePointers.clear();
    _pinchActive = false;
    _pinchPointerIds = const <int>[];
    _dismissOffsetY = 0.0;
    _dismissDragging = false;
    _edgeDragAccum = 0.0;
    _edgeDragSign = 0;
    _edgeTurnFired = false;
    if (_scale != 1.0 || _translation != Offset.zero || _isZoomed) {
      setState(() {
        _scale = 1.0;
        _translation = Offset.zero;
        _isZoomed = false;
      });
      widget.onZoomChanged?.call(false);
    }
    _syncZoomController();
  }
}
