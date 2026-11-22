import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';

class AppCapsuleTabItem {
  const AppCapsuleTabItem({required this.id, required this.label});

  final String id;
  final String label;
}

/// 公共胶囊标签栏：选中项承担单胶囊／透镜高亮，未选中项保持轻量文本；
/// 项数过多或字号放大时仅按钮行自身横向滚动并展示溢出边缘羽化。
class AppCapsuleTabBar extends StatefulWidget {
  const AppCapsuleTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    required this.indicatorKey,
    required this.tabKeyBuilder,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.selectedBackgroundColor,
    this.selectedForegroundColor,
    this.unselectedForegroundColor,
    this.longPressMenuBuilder,
    this.onLongPressMenuSelected,
  });

  final List<AppCapsuleTabItem> tabs;

  /// 为 null 或越界时表示无选中项，不绘制高亮胶囊。
  final int? selectedIndex;
  final ValueChanged<int> onTap;
  final Key indicatorKey;
  final Key Function(String id) tabKeyBuilder;
  final bool enabled;
  final EdgeInsetsGeometry padding;
  final Color? selectedBackgroundColor;
  final Color? selectedForegroundColor;
  final Color? unselectedForegroundColor;
  final List<PopupMenuEntry<String>> Function(
    BuildContext context,
    AppCapsuleTabItem tab,
  )?
  longPressMenuBuilder;
  final void Function(int index, String value)? onLongPressMenuSelected;

  /// 根据当前文字排版与缩放倍率估算胶囊栏完整高度，供吸顶委托同步占位。
  static double preferredHeight(
    BuildContext context, {
    Iterable<String> labels = const <String>[],
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 4,
    ),
  }) {
    final theme = Theme.of(context);
    final labelStyle = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w700);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final resolvedPadding = padding.resolve(direction);
    final sampleLabels = labels.isEmpty ? const <String>['全部'] : labels;
    var maxTextHeight = 0.0;
    for (final label in sampleLabels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        maxLines: 1,
        textScaler: textScaler,
        textDirection: direction,
        locale: locale,
      )..layout();
      maxTextHeight = math.max(maxTextHeight, painter.height);
      painter.dispose();
    }
    final pillHeight = maxTextHeight + 16.0;
    final itemHeight = math.max(48.0, pillHeight);
    return (itemHeight + resolvedPadding.vertical).ceilToDouble();
  }

  @override
  State<AppCapsuleTabBar> createState() => _AppCapsuleTabBarState();
}

class _AppCapsuleTabBarState extends State<AppCapsuleTabBar> {
  final GlobalKey _selectedCapsuleKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _fadeLeft = false;
  bool _fadeRight = false;

  int? get _validSelectedIndex {
    final index = widget.selectedIndex;
    if (index == null || index < 0 || index >= widget.tabs.length) {
      return null;
    }
    return index;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollFade);
    _ensureSelectedVisible();
    _scheduleScrollFadeUpdate();
  }

  @override
  void didUpdateWidget(covariant AppCapsuleTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.tabs.length != widget.tabs.length) {
      _ensureSelectedVisible();
    }
    _scheduleScrollFadeUpdate();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateScrollFade)
      ..dispose();
    super.dispose();
  }

  void _scheduleScrollFadeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollFade();
    });
  }

  void _updateScrollFade() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextLeft = position.pixels > 1.0;
    final nextRight = position.maxScrollExtent - position.pixels > 1.0;
    if (nextLeft != _fadeLeft || nextRight != _fadeRight) {
      setState(() {
        _fadeLeft = nextLeft;
        _fadeRight = nextRight;
      });
    }
  }

  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_validSelectedIndex == null) {
        _updateScrollFade();
        return;
      }
      final context = _selectedCapsuleKey.currentContext;
      if (context == null) {
        _updateScrollFade();
        return;
      }
      final reduceMotion = AppMotion.reduceMotion(context);
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      _updateScrollFade();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: AppCapsuleTabBar.preferredHeight(
          context,
          padding: widget.padding,
        ),
      );
    }

    final eInk = EInkModeScope.of(context);
    final Widget scrollView = SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var index = 0; index < widget.tabs.length; index++)
            Padding(
              padding: EdgeInsets.only(
                right: index == widget.tabs.length - 1 ? 0 : 8,
              ),
              child: _buildCapsule(
                context,
                index: index,
                tab: widget.tabs[index],
                selectedIndex: _validSelectedIndex,
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.42,
          duration: AppMotion.duration(
            context,
            const Duration(milliseconds: 160),
          ),
          child: _HorizontalEdgeFade(
            fadeLeft: !eInk && _fadeLeft,
            fadeRight: !eInk && _fadeRight,
            child: scrollView,
          ),
        ),
      ),
    );
  }

  Widget _buildCapsule(
    BuildContext context, {
    required int index,
    required AppCapsuleTabItem tab,
    required int? selectedIndex,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final reduceMotion = AppMotion.reduceMotion(context);
    final glassEnabled =
        !eInk &&
        !MediaQuery.highContrastOf(context) &&
        AppGlassSurface.levelOf(context).enabled;
    final selected = selectedIndex != null && index == selectedIndex;
    final selectedBg = widget.selectedBackgroundColor ?? scheme.primary;
    final selectedFg = widget.selectedForegroundColor ?? scheme.onPrimary;
    final unselectedFg =
        widget.unselectedForegroundColor ?? scheme.onSurfaceVariant;
    final foreground = selected ? selectedFg : unselectedFg;
    final label = AnimatedDefaultTextStyle(
      duration: AppMotion.duration(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    final pillContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: label,
    );
    final Widget capsule = selected
        ? (glassEnabled
              ? AppGlassSurface(
                  borderRadius: 999,
                  baseColor: selectedBg,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: selectedBg.withValues(alpha: 0.88),
                      shape: const StadiumBorder(),
                    ),
                    child: pillContent,
                  ),
                )
              : DecoratedBox(
                  decoration: ShapeDecoration(
                    color: selectedBg,
                    shape: const StadiumBorder(),
                  ),
                  child: pillContent,
                ))
        : (eInk
              ? DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.surface,
                    shape: StadiumBorder(
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: pillContent,
                )
              : pillContent);
    final taggedCapsule = selected
        ? KeyedSubtree(
            key: _selectedCapsuleKey,
            child: KeyedSubtree(key: widget.indicatorKey, child: capsule),
          )
        : capsule;
    final menuEntries = widget.enabled && widget.longPressMenuBuilder != null
        ? widget.longPressMenuBuilder!(context, tab)
        : const <PopupMenuEntry<String>>[];

    Widget buildTrigger(VoidCallback? onLongPress) {
      return Semantics(
        key: widget.tabKeyBuilder(tab.id),
        container: true,
        enabled: widget.enabled,
        selected: selected,
        button: true,
        onTap: widget.enabled ? () => widget.onTap(index) : null,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? () => widget.onTap(index) : null,
            onLongPress: onLongPress,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: !widget.enabled || reduceMotion
                  ? taggedCapsule
                  : ElasticPress(child: taggedCapsule),
            ),
          ),
        ),
      );
    }

    if (menuEntries.isEmpty) {
      return buildTrigger(null);
    }

    return AppPopupMenuButton<String>(
      itemBuilder: (_) => menuEntries,
      onSelected: (value) => widget.onLongPressMenuSelected?.call(index, value),
      targetBuilder: (_, open) => buildTrigger(open),
    );
  }
}

/// Keeps [SingleChildScrollView] mounted at a fixed tree depth while toggling
/// soft horizontal overflow fades cleanly without resetting [ScrollPosition].
class _HorizontalEdgeFade extends SingleChildRenderObjectWidget {
  const _HorizontalEdgeFade({
    required this.fadeLeft,
    required this.fadeRight,
    required super.child,
  });

  final bool fadeLeft;
  final bool fadeRight;

  @override
  _RenderHorizontalEdgeFade createRenderObject(BuildContext context) {
    return _RenderHorizontalEdgeFade(fadeLeft: fadeLeft, fadeRight: fadeRight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHorizontalEdgeFade renderObject,
  ) {
    renderObject
      ..fadeLeft = fadeLeft
      ..fadeRight = fadeRight;
  }
}

class _RenderHorizontalEdgeFade extends RenderProxyBox {
  _RenderHorizontalEdgeFade({required bool fadeLeft, required bool fadeRight})
    : _fadeLeft = fadeLeft,
      _fadeRight = fadeRight;

  static const double _fadeWidth = 20.0;

  bool _fadeLeft;
  set fadeLeft(bool value) {
    if (_fadeLeft == value) {
      return;
    }
    final hadFade = _fadeLeft || _fadeRight;
    _fadeLeft = value;
    if (hadFade != (_fadeLeft || _fadeRight)) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  bool _fadeRight;
  set fadeRight(bool value) {
    if (_fadeRight == value) {
      return;
    }
    final hadFade = _fadeLeft || _fadeRight;
    _fadeRight = value;
    if (hadFade != (_fadeLeft || _fadeRight)) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _fadeLeft || _fadeRight;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      return;
    }
    if ((!_fadeLeft && !_fadeRight) || size.isEmpty) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    final fadeFraction = (_fadeWidth / size.width).clamp(0.0, 0.25);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[
        _fadeLeft ? Colors.transparent : Colors.black,
        Colors.black,
        Colors.black,
        _fadeRight ? Colors.transparent : Colors.black,
      ],
      stops: <double>[0.0, fadeFraction, 1.0 - fadeFraction, 1.0],
    ).createShader(Offset.zero & size);
    final shaderLayer = (layer as ShaderMaskLayer? ?? ShaderMaskLayer())
      ..shader = shader
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    layer = shaderLayer;
    context.pushLayer(shaderLayer, super.paint, offset);
  }
}
