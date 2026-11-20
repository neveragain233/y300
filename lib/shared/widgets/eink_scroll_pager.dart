import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/settings/eink_mode.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/eink/eink_paging_router.dart';
import 'package:y300/shared/widgets/eink_corner_paging_buttons.dart';

/// 墨水屏滚动行为：不绘制 overscroll 光效，统一钳制物理，减少整屏重绘。
class EInkScrollBehavior extends MaterialScrollBehavior {
  const EInkScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

/// 在墨水屏模式下给滚动列表挂上硬件键路由、角标与可选边缘步进。
///
/// 模式关闭（`enabled` 为 false，或未显式传入且 [EInkModeScope] 为 false）时
/// 直接返回 [child]：不读取路由、不注册目标、不叠加任何点击层。模式切换即时
/// 生效，关闭时注销并在重新打开时重新注册。
class EInkScrollPager extends ConsumerStatefulWidget {
  const EInkScrollPager({
    super.key,
    required this.controller,
    required this.child,
    this.cornerButtons = true,
    this.cornerPadding = const EdgeInsets.only(right: 12, bottom: 16),
    this.edgeTapAllowed = true,
    this.edgeTopInset = 0,
    this.edgeBottomInset = 0,
    this.enabled,
  });

  final ScrollController controller;
  final Widget child;

  /// 是否叠加右下角上下翻页角标。
  final bool cornerButtons;

  /// 角标距屏幕右下角的避让，由页面按底栏、悬浮控件与阅读控件传入。
  final EdgeInsetsGeometry cornerPadding;

  /// 边缘点击总开关；仍受外观设置里的 `eInkEdgeTapPaging` 控制，两者都开才出现。
  final bool edgeTapAllowed;

  /// 边缘层在安全区之下的额外上下避让。
  final double edgeTopInset;
  final double edgeBottomInset;

  /// 显式覆盖模式判断；为 null 时读 [EInkModeScope]。
  final bool? enabled;

  @override
  ConsumerState<EInkScrollPager> createState() => _EInkScrollPagerState();
}

class _EInkScrollPagerState extends ConsumerState<EInkScrollPager> {
  /// 规格宽度 24dp、上限 32dp；固定取下限，避免抢占正文链接与横向手势。
  static const double _edgeTapWidth = 24;

  EInkPagingRouter? _router;
  EInkScrollPageHandler? _handler;
  bool _active = false;
  bool _visible = false;
  bool _boundsRefreshScheduled = false;

  bool get _enabled => widget.enabled ?? EInkModeScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMode();
  }

  @override
  void didUpdateWidget(covariant EInkScrollPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final handler = _handler;
    if (handler != null &&
        !identical(oldWidget.controller, widget.controller)) {
      handler.controller = widget.controller;
      _scheduleBoundsRefresh();
    }
    _syncMode();
  }

  void _syncMode() {
    final enabled = _enabled;
    if (enabled == _active) {
      if (_active) {
        _updateVisibility();
      }
      return;
    }
    if (enabled) {
      _activate();
    } else {
      _deactivate();
    }
  }

  void _activate() {
    final router = ref.read(eInkPagingRouterProvider);
    final handler = router.createScrollHandler(widget.controller);
    _router = router;
    _handler = handler;
    _active = true;
    _visible = _computeVisible();
    router.register(this, handler, isVisible: _visible);
    // 首帧尺寸确定时控制器通常不会再通知，布局完成后主动补算一次边界。
    _scheduleBoundsRefresh();
  }

  void _deactivate() {
    _router?.unregister(this);
    _router = null;
    _handler?.dispose();
    _handler = null;
    _active = false;
    _visible = false;
  }

  bool _computeVisible() {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    return TickerMode.valuesOf(context).enabled;
  }

  void _updateVisibility() {
    final visible = _computeVisible();
    if (visible == _visible) {
      return;
    }
    _visible = visible;
    _router?.setVisible(this, visible);
  }

  void _scheduleBoundsRefresh() {
    if (_boundsRefreshScheduled) {
      return;
    }
    _boundsRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boundsRefreshScheduled = false;
      if (mounted && _active) {
        _handler?.refreshBounds();
      }
    });
  }

  @override
  void dispose() {
    _router?.unregister(this);
    _router = null;
    _handler?.dispose();
    _handler = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handler = _handler;
    if (!_active || handler == null) {
      return widget.child;
    }
    final showEdgeTap =
        widget.edgeTapAllowed && ref.watch(eInkEdgeTapPagingProvider);
    final mediaPadding = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.cornerButtons)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: EInkCornerPagingButtons(
              handler: handler,
              padding: widget.cornerPadding,
            ),
          ),
        if (showEdgeTap)
          Positioned.fill(
            child: _EInkEdgeTapOverlay(
              handler: handler,
              top: mediaPadding.top + widget.edgeTopInset,
              bottom: mediaPadding.bottom + widget.edgeBottomInset,
              width: _edgeTapWidth,
            ),
          ),
      ],
    );
  }
}

/// 左右窄条边缘点击层：只在对应方向还能翻页时出现。
class _EInkEdgeTapOverlay extends StatelessWidget {
  const _EInkEdgeTapOverlay({
    required this.handler,
    required this.top,
    required this.bottom,
    required this.width,
  });

  final EInkScrollPageHandler handler;
  final double top;
  final double bottom;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: handler,
      builder: (context, _) {
        final canPageUp = handler.canPageUp;
        final canPageDown = handler.canPageDown;
        if (!canPageUp && !canPageDown) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: [
            if (canPageUp)
              PositionedDirectional(
                start: 0,
                top: top,
                bottom: bottom,
                width: width,
                child: _EdgeTapLayer(
                  key: const Key('eink-edge-tap-previous'),
                  onTap: handler.pageUp,
                ),
              ),
            if (canPageDown)
              PositionedDirectional(
                end: 0,
                top: top,
                bottom: bottom,
                width: width,
                child: _EdgeTapLayer(
                  key: const Key('eink-edge-tap-next'),
                  onTap: handler.pageDown,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EdgeTapLayer extends StatelessWidget {
  const _EdgeTapLayer({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap);
  }
}
