import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/config/app_edition.dart';
import 'package:y300/core/eink/eink_paging_router.dart';

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

/// 在 eink 构建下给滚动列表挂上硬件键路由与左右边缘步进。
///
/// 只在墨水屏构建启用；普通构建直接返回 [child]，不增加点击层和路由注册。
class EInkScrollPager extends ConsumerStatefulWidget {
  const EInkScrollPager({
    super.key,
    required this.controller,
    required this.child,
    this.edgeTapWidth = 40,
    this.edgeTapEnabled = true,
    this.enabled,
  });

  final ScrollController controller;
  final Widget child;
  final double edgeTapWidth;
  final bool edgeTapEnabled;

  /// 显式覆盖构建变体判断；默认跟随 [AppEdition.isEInk]。
  final bool? enabled;

  @override
  ConsumerState<EInkScrollPager> createState() => _EInkScrollPagerState();
}

class _EInkScrollPagerState extends ConsumerState<EInkScrollPager> {
  EInkPagingRouter? _router;
  EInkScrollPageHandler? _handler;

  bool get _supported => widget.enabled ?? AppEdition.isEInk;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _router = ref.read(eInkPagingRouterProvider);
      _handler = _router!.createScrollHandler(widget.controller);
      _router!.register(this, _handler!);
    }
  }

  @override
  void didUpdateWidget(covariant EInkScrollPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final handler = _handler;
    if (handler != null &&
        !identical(oldWidget.controller, widget.controller)) {
      handler.controller = widget.controller;
    }
  }

  @override
  void dispose() {
    _router?.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handler = _handler;
    if (!_supported || handler == null) {
      return widget.child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.edgeTapEnabled) ...[
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: widget.edgeTapWidth,
            child: _EdgeTapLayer(
              key: const Key('eink-edge-tap-previous'),
              onTap: handler.pageUp,
            ),
          ),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            width: widget.edgeTapWidth,
            child: _EdgeTapLayer(
              key: const Key('eink-edge-tap-next'),
              onTap: handler.pageDown,
            ),
          ),
        ],
      ],
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
