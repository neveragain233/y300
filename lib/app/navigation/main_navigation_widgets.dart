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

/// 指示层只做位移；快速切换从当前位置继续，键盘选择直接到达目标。
class MainNavigationCapsule extends StatefulWidget {
  const MainNavigationCapsule({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(items.length >= 2 && items.length <= 5);
  final List<MainNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  State<MainNavigationCapsule> createState() => _MainNavigationCapsuleState();
}

class _MainNavigationCapsuleState extends State<MainNavigationCapsule> {
  int? _pointerTarget;
  bool _animate = false;
  @override
  void didUpdateWidget(MainNavigationCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animate =
        _pointerTarget == widget.selectedIndex &&
        widget.items.length == oldWidget.items.length;
    _pointerTarget = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = _animate
        ? AppLayoutTokens.motionDuration(context)
        : Duration.zero;
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
                  child: Material(
                    color:
                        Theme.of(context).navigationBarTheme.backgroundColor ??
                        scheme.surfaceContainer,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(40),
                    child: SizedBox(
                      width: width,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth =
                                constraints.maxWidth / widget.items.length;
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: 1 / widget.items.length,
                                      heightFactor: 1,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(
                                          begin: widget.selectedIndex
                                              .toDouble(),
                                          end: widget.selectedIndex.toDouble(),
                                        ),
                                        duration: duration,
                                        curve: const Cubic(0.77, 0, 0.175, 1),
                                        builder: (_, index, child) =>
                                            Transform.translate(
                                              offset: Offset(
                                                itemWidth * index,
                                                0,
                                              ),
                                              child: child,
                                            ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              34,
                                            ),
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
                                          onSelected: (pointer) {
                                            _pointerTarget = pointer
                                                ? index
                                                : null;
                                            widget.onSelected(index);
                                          },
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
  final ValueChanged<bool> onSelected;
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
            widget.onSelected(false);
            return null;
          },
        ),
      },
      onShowFocusHighlight: (shown) => setState(() => _focused = shown),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.item.label,
        onTap: () => widget.onSelected(false),
        excludeSemantics: true,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(34),
          onTap: () => widget.onSelected(true),
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
