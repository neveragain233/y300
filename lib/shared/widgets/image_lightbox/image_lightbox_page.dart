import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';
import 'package:y300/shared/widgets/image_lightbox/image_lightbox_viewport.dart';

/// 构造支持下拉渐隐透出下层页面的透明灯箱路由。
PageRoute<T> buildImageLightboxRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion =
          EInkModeScope.of(context) || AppMotion.reduceMotion(context);
      if (reduceMotion) return child;
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      );
    },
  );
}

/// 灯箱底部工具栏动作项。
class ImageLightboxAction {
  const ImageLightboxAction({
    required this.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key key;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
}

/// 与漫画阅读偏好解绑的通用社媒图片灯箱外壳。
///
/// 固定从左到右翻页，使用 `prism_ui` 玻璃胶囊工具栏，支持单击显隐工具栏、
/// 下拉关闭、双指缩放、长图双击满宽与键盘快捷键切换。
class ImageLightboxPage<T> extends StatefulWidget {
  const ImageLightboxPage({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    this.initialAspectRatioFor,
    this.actionsFor,
    this.onPageChanged,
    this.onBeforeExit,
  }) : assert(itemCount > 0);

  final int itemCount;
  final int initialIndex;
  final Widget Function(
    BuildContext context,
    int index,
    ValueChanged<Size> onSizeResolved,
  )
  itemBuilder;
  final double? Function(int index)? initialAspectRatioFor;
  final List<ImageLightboxAction> Function(BuildContext context, int index)?
  actionsFor;
  final ValueChanged<int>? onPageChanged;
  final Future<T?> Function(int currentIndex, bool hasNavigated)? onBeforeExit;

  @override
  State<ImageLightboxPage<T>> createState() => _ImageLightboxPageState<T>();
}

class _ImageLightboxPageState<T> extends State<ImageLightboxPage<T>> {
  late final PageController _pageController;
  late final ValueNotifier<double> _dismissProgress;
  final Map<int, Size> _resolvedSizes = <int, Size>{};
  final Map<int, ImageLightboxZoomController> _zoomControllers =
      <int, ImageLightboxZoomController>{};

  late int _currentIndex;
  bool _hasNavigated = false;
  bool _hudVisible = true;
  bool _pageZoomed = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.itemCount - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _dismissProgress = ValueNotifier<double>(0.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dismissProgress.dispose();
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ImageLightboxZoomController _zoomControllerFor(int index) {
    return _zoomControllers.putIfAbsent(index, ImageLightboxZoomController.new);
  }

  void _onSizeResolved(int index, Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    final previous = _resolvedSizes[index];
    if (previous == size) return;
    if (!mounted) return;
    setState(() {
      _resolvedSizes[index] = size;
    });
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    T? result;
    final onBeforeExit = widget.onBeforeExit;
    if (onBeforeExit != null) {
      try {
        result = await onBeforeExit(_currentIndex, _hasNavigated);
      } catch (_) {
        result = null;
      }
    }
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      Navigator.of(context).pop(result);
    } else {
      _exiting = false;
    }
  }

  void _turnPage(int delta) {
    final target = (_currentIndex + delta).clamp(0, widget.itemCount - 1);
    if (target == _currentIndex || !_pageController.hasClients) return;
    final reduceMotion =
        EInkModeScope.of(context) || AppMotion.reduceMotion(context);
    if (reduceMotion) {
      _pageController.jumpToPage(target);
      return;
    }
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_exit());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _turnPage(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _turnPage(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final eInk = EInkModeScope.of(context);
    final reduceMotion = eInk || AppMotion.reduceMotion(context);
    final l10n = AppLocalizations.of(context);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: baseTheme.colorScheme.primary,
      brightness: Brightness.dark,
    );
    final darkTheme = baseTheme.copyWith(
      colorScheme: darkScheme,
      scaffoldBackgroundColor: Colors.transparent,
    );
    final currentZoom = _zoomControllerFor(_currentIndex);
    final customActions =
        widget.actionsFor?.call(context, _currentIndex) ??
        const <ImageLightboxAction>[];

    return PopScope<T>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_exit());
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Theme(
            data: darkTheme,
            child: AppPrismTheme(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _dismissProgress,
                      builder: (context, progress, _) {
                        final opacity = reduceMotion
                            ? 1.0
                            : (1.0 - progress * 0.75).clamp(0.25, 1.0);
                        return ColoredBox(
                          key: const Key('image-lightbox-backdrop'),
                          color: Colors.black.withValues(alpha: opacity),
                        );
                      },
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: PageView.builder(
                        key: const Key('image-lightbox-page-view'),
                        controller: _pageController,
                        physics: _pageZoomed
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        itemCount: widget.itemCount,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                            _hasNavigated =
                                _hasNavigated || index != widget.initialIndex;
                            _pageZoomed = false;
                          });
                          widget.onPageChanged?.call(index);
                        },
                        itemBuilder: (context, index) {
                          return ImageLightboxViewport(
                            key: ValueKey<int>(index),
                            imageSize: _resolvedSizes[index],
                            aspectRatio: widget.initialAspectRatioFor?.call(
                              index,
                            ),
                            zoomController: _zoomControllerFor(index),
                            isActivePage: index == _currentIndex,
                            onSingleTap: () {
                              setState(() => _hudVisible = !_hudVisible);
                            },
                            onZoomChanged: (zoomed) {
                              if (index == _currentIndex &&
                                  _pageZoomed != zoomed) {
                                setState(() => _pageZoomed = zoomed);
                              }
                            },
                            onDismissProgressChanged: (progress) {
                              if (index == _currentIndex) {
                                _dismissProgress.value = progress;
                              }
                            },
                            onDismissRequested: () {
                              unawaited(_exit());
                            },
                            onEdgePageTurn: _turnPage,
                            child: Center(
                              child: widget.itemBuilder(
                                context,
                                index,
                                (size) => _onSizeResolved(index, size),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildHudLayer(
                        visible: _hudVisible,
                        reduceMotion: reduceMotion,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Row(
                              children: [
                                AppToolbarIconButton(
                                  buttonKey: const Key(
                                    'image-lightbox-close-button',
                                  ),
                                  tooltip: l10n.imageLightboxClose,
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => unawaited(_exit()),
                                ),
                                const Spacer(),
                                if (widget.itemCount > 1)
                                  AppGlassSurface(
                                    borderRadius: 20,
                                    baseColor: eInk
                                        ? darkScheme.surface
                                        : darkScheme.surfaceContainerHigh,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        '${_currentIndex + 1} / ${widget.itemCount}',
                                        key: const Key(
                                          'image-lightbox-counter',
                                        ),
                                        style: darkTheme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: darkScheme.onSurface,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildHudLayer(
                        visible: _hudVisible,
                        reduceMotion: reduceMotion,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            child: Center(
                              child: ListenableBuilder(
                                listenable: currentZoom,
                                builder: (context, _) {
                                  final showFitToggle =
                                      currentZoom.isZoomed ||
                                      currentZoom.isLongOrWideImage;
                                  final actions = <Widget>[
                                    if (showFitToggle)
                                      IconButton(
                                        key: const Key(
                                          'image-lightbox-fit-toggle-button',
                                        ),
                                        tooltip: currentZoom.isZoomed
                                            ? l10n.imageLightboxResetZoom
                                            : l10n.imageLightboxFitWidth,
                                        icon: Icon(
                                          currentZoom.isZoomed
                                              ? Icons.fullscreen_exit_rounded
                                              : Icons.fit_screen_rounded,
                                        ),
                                        onPressed: currentZoom.toggleFit,
                                      ),
                                    for (final action in customActions)
                                      IconButton(
                                        key: action.key,
                                        tooltip: action.tooltip,
                                        icon: Icon(action.icon),
                                        onPressed: action.onPressed,
                                      ),
                                  ];
                                  if (actions.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return AppToolbarActions(
                                    size: AppToolbarButtonSize.bar,
                                    children: actions,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHudLayer({
    required bool visible,
    required bool reduceMotion,
    required Widget child,
  }) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}
