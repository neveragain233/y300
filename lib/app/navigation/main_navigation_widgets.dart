import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/layout/app_window_layout.dart';

@immutable
class MainNavigationItem {
  const MainNavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String id;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

class MainNavigationRail extends StatelessWidget {
  const MainNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelected,
  });
  final List<MainNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color:
        Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetHeight =
              items.length *
                  (64 + MediaQuery.textScalerOf(context).scale(14) * 2) +
              32;
          return SingleChildScrollView(
            child: SizedBox(
              height: math.max(constraints.maxHeight, targetHeight),
              child: NavigationRail(
                key: const Key('main-shell-navigation-rail'),
                minWidth: 80,
                backgroundColor: Theme.of(context)
                    .navigationBarTheme
                    .backgroundColor,
                labelType: NavigationRailLabelType.all,
                indicatorColor: Theme.of(context).colorScheme.primary,
                selectedIconTheme: IconThemeData(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// 沉浸式主壳的悬浮导航胶囊。
///
/// 指示层只随已提交的选择或拖动位置移动；横向拖选只在 [swipeEnabled] 打开
/// 时建立独立手势，松手按落点提交，越界时使用受限的回弹而不改变条目顺序。
class MainNavigationCapsule extends StatefulWidget {
  const MainNavigationCapsule({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onSelected,
    this.swipeEnabled = false,
  }) : assert(items.length >= 1 && items.length <= 5);

  final List<MainNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  /// 拖动期间只移动指示层，页面切换和语义选中态在松手后才提交。
  final bool swipeEnabled;

  @override
  State<MainNavigationCapsule> createState() => _MainNavigationCapsuleState();
}

class _MainNavigationCapsuleState extends State<MainNavigationCapsule> {
  /// 条目单位上的连续位置；为空表示没有进行中的拖动。
  double? _dragPosition;

  /// 越界后经回弹收敛的条目偏移，只用于指示层边缘拉伸。
  double _dragOvershoot = 0;

  bool get _dragging => _dragPosition != null;
  int get _lastIndex => widget.items.length - 1;

  @override
  void didUpdateWidget(MainNavigationCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final invalidated =
        _dragging &&
        (!widget.swipeEnabled ||
            widget.onSelected == null ||
            widget.items.length != oldWidget.items.length);
    if (invalidated) {
      _dragPosition = null;
      _dragOvershoot = 0;
    }
  }

  double _rubberBand(double overshoot) {
    const limit = 0.3;
    if (overshoot == 0) return 0;
    final pull = 1 - 1 / (overshoot.abs() * 0.55 / limit + 1);
    return limit * pull * (overshoot < 0 ? -1 : 1);
  }

  void _startDrag() {
    setState(() {
      _dragPosition = widget.selectedIndex.toDouble();
      _dragOvershoot = 0;
    });
  }

  void _updateDrag(double dx, double itemWidth) {
    final current = _dragPosition;
    if (current == null || itemWidth <= 0) return;
    final raw = current + dx / itemWidth;
    final clamped = raw.clamp(0.0, _lastIndex.toDouble());
    final overshoot = raw - clamped;
    setState(() {
      _dragPosition = clamped + _rubberBand(overshoot);
      _dragOvershoot = (clamped + _rubberBand(overshoot) - clamped).abs();
    });
  }

  void _finishDrag({required bool commit}) {
    final position = _dragPosition;
    if (position == null) return;
    final target = position.round().clamp(0, _lastIndex);
    setState(() {
      _dragPosition = null;
      _dragOvershoot = 0;
    });
    if (commit && target != widget.selectedIndex) {
      widget.onSelected?.call(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final region = AppWindowLayout(
          size: Size(constraints.maxWidth, media.size.height),
          displayFeatures: media.displayFeatures,
        ).readingRegion;
        final horizontalPadding = math.min(
          16.0,
          math.max(0.0, (region.width - widget.items.length * 48 - 12) / 2),
        );
        final width = math.max(
          widget.items.length * 48.0 + 12,
          math.min(560.0, region.width - horizontalPadding * 2),
        );
        return Padding(
          padding: EdgeInsets.only(
            left: region.left,
            right: constraints.maxWidth - region.right,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                12,
              ),
              child: Center(
                heightFactor: 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: widget.swipeEnabled
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  child: Material(
                    key: const Key('main-shell-immersive-navigation'),
                    color:
                        Theme.of(context).navigationBarTheme.backgroundColor ??
                        scheme.surfaceContainer,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(40),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: width,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: widget.swipeEnabled
                            ? (_) => _startDrag()
                            : null,
                        onHorizontalDragUpdate: widget.swipeEnabled
                            ? (details) {
                                final itemWidth =
                                    (width - 12) / widget.items.length;
                                _updateDrag(details.delta.dx, itemWidth);
                              }
                            : null,
                        onHorizontalDragEnd: widget.swipeEnabled
                            ? (_) => _finishDrag(commit: true)
                            : null,
                        onHorizontalDragCancel: widget.swipeEnabled
                            ? () => _finishDrag(commit: false)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final itemWidth =
                                  constraints.maxWidth / widget.items.length;
                              final displayPosition =
                                  _dragPosition ??
                                  widget.selectedIndex.toDouble();
                              final duration = _dragging || animationsDisabled
                                  ? Duration.zero
                                  : AppLayoutTokens.feedbackDuration;
                              final stretch = animationsDisabled
                                  ? 1.0
                                  : 1 +
                                        _dragOvershoot /
                                            widget.items.length *
                                            0.5;
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: 1 / widget.items.length,
                                        heightFactor: 1,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween<double>(
                                            begin: displayPosition,
                                            end: displayPosition,
                                          ),
                                          duration: duration,
                                          curve: const Cubic(0.77, 0, 0.175, 1),
                                          builder: (_, index, child) =>
                                              Transform.translate(
                                                offset: Offset(
                                                  itemWidth * index,
                                                  0,
                                                ),
                                                child: Transform.scale(
                                                  scaleX: stretch,
                                                  child: child,
                                                ),
                                              ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(34),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < widget.items.length;
                                        index++
                                      )
                                        Expanded(
                                          key: ValueKey(widget.items[index].id),
                                          child: _CapsuleDestination(
                                            item: widget.items[index],
                                            selected:
                                                index == widget.selectedIndex,
                                            onSelected:
                                                widget.onSelected == null
                                                ? null
                                                : () =>
                                                      widget.onSelected!(index),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CapsuleDestination extends StatefulWidget {
  const _CapsuleDestination({
    required this.item,
    required this.selected,
    required this.onSelected,
  });
  final MainNavigationItem item;
  final bool selected;
  final VoidCallback? onSelected;
  @override
  State<_CapsuleDestination> createState() => _CapsuleDestinationState();
}

class _CapsuleDestinationState extends State<_CapsuleDestination> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = widget.selected
        ? scheme.onPrimary
        : scheme.onSurfaceVariant;
    return FocusableActionDetector(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onSelected?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (shown) => setState(() => _focused = shown),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.item.label,
        onTap: widget.onSelected,
        excludeSemantics: true,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(34),
          onTap: widget.onSelected,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: _focused ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.selected ? widget.item.selectedIcon : widget.item.icon,
                  const SizedBox(height: 3),
                  Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
