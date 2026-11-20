import 'package:flutter/material.dart';
import 'package:y300/core/eink/eink_paging_router.dart';

/// 墨水屏列表右下角的上下翻页角标。
///
/// 视觉方块 36dp，命中区扩到 48dp；只监听 [EInkScrollPageHandler] 的边界
/// 通知，不持有动画与定时器，避免墨水屏上额外整屏刷新。两个方向都不可翻
/// 时整体不渲染，单方向不可翻时该键保持位置并显示禁用态。
class EInkCornerPagingButtons extends StatefulWidget {
  const EInkCornerPagingButtons({
    super.key,
    required this.handler,
    this.padding = const EdgeInsets.only(right: 12, bottom: 16),
  });

  final EInkScrollPageHandler handler;

  /// 距屏幕边缘的避让，页面按底栏、悬浮按钮与阅读控件调整。
  final EdgeInsetsGeometry padding;

  @override
  State<EInkCornerPagingButtons> createState() =>
      _EInkCornerPagingButtonsState();
}

class _EInkCornerPagingButtonsState extends State<EInkCornerPagingButtons> {
  /// 触摸命中区，角标视觉尺寸固定 36dp 居中。
  static const double _hitSize = 48;
  static const double _visualSize = 36;
  static const double _iconSize = 22;
  static const double _radius = 8;

  @override
  void initState() {
    super.initState();
    widget.handler.addListener(_handleBoundsChanged);
  }

  @override
  void didUpdateWidget(covariant EInkCornerPagingButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.handler, widget.handler)) {
      oldWidget.handler.removeListener(_handleBoundsChanged);
      widget.handler.addListener(_handleBoundsChanged);
    }
  }

  @override
  void dispose() {
    widget.handler.removeListener(_handleBoundsChanged);
    super.dispose();
  }

  void _handleBoundsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPageUp = widget.handler.canPageUp;
    final canPageDown = widget.handler.canPageDown;
    if (!canPageUp && !canPageDown) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildButton(
              key: const Key('eink-corner-page-up'),
              icon: Icons.keyboard_arrow_up,
              enabled: canPageUp,
              onTap: widget.handler.pageUp,
              isDark: isDark,
            ),
            _buildButton(
              key: const Key('eink-corner-page-down'),
              icon: Icons.keyboard_arrow_down,
              enabled: canPageDown,
              onTap: widget.handler.pageDown,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required Key key,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final background = isDark
        ? const Color(0xFF141414)
        : const Color(0xFFFFFFFF);
    final border = enabled
        ? (isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC))
        : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0));
    final foreground = enabled
        ? (isDark ? const Color(0xFFEAEAEA) : const Color(0xFF222222))
        : (isDark ? const Color(0xFF5A5A5A) : const Color(0xFFA0A0A0));
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: _hitSize,
        height: _hitSize,
        child: Center(
          child: Container(
            width: _visualSize,
            height: _visualSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: border),
            ),
            child: Icon(icon, size: _iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}
