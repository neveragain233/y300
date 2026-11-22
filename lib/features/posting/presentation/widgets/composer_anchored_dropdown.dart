import 'package:flutter/material.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/press_region.dart' as prism_press;
import 'package:prism_ui/surface.dart' as prism_surface;
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

class ComposerDropdownItem<T> {
  const ComposerDropdownItem({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

/// Compact anchored dropdown used by the posting composer form.
///
/// Reuses [AppPopupMenuButton] with indexed integer values so nullable domain
/// options (such as "无分类") commit as real selections rather than cancel.
class ComposerAnchoredDropdown<T> extends StatefulWidget {
  const ComposerAnchoredDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onSelected,
    required this.valueLabelBuilder,
    this.enabled = true,
    this.anchorKey,
    this.summaryKey,
    this.panelKey,
  });

  final String label;
  final T value;
  final List<ComposerDropdownItem<T>> items;
  final ValueChanged<T> onSelected;
  final String Function(T value) valueLabelBuilder;
  final bool enabled;
  final Key? anchorKey;
  final Key? summaryKey;
  final Key? panelKey;

  @override
  State<ComposerAnchoredDropdown<T>> createState() =>
      _ComposerAnchoredDropdownState<T>();
}

class _ComposerAnchoredDropdownState<T>
    extends State<ComposerAnchoredDropdown<T>> {
  static const double _anchorHeight = 44;

  bool _isMenuOpen = false;

  void _setMenuOpen(bool value) {
    if (!mounted || _isMenuOpen == value) {
      return;
    }
    setState(() {
      _isMenuOpen = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = widget.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    final outline = theme.colorScheme.outlineVariant;
    return AppPopupMenuButton<int>(
      enabled: widget.enabled,
      useRootNavigator: true,
      placement: prism.PopupPlacement.overAnchorStart,
      onOpened: () => _setMenuOpen(true),
      onCanceled: () => _setMenuOpen(false),
      onSelected: (index) {
        if (!mounted) {
          return;
        }
        _setMenuOpen(false);
        if (index < 0 || index >= widget.items.length) {
          return;
        }
        final item = widget.items[index];
        if (item.value != widget.value) {
          widget.onSelected(item.value);
        }
      },
      itemBuilder: (_) => [
        for (var index = 0; index < widget.items.length; index++)
          AppPopupMenuItem<int>(
            key: widget.items[index].key,
            value: index,
            label: widget.items[index].label,
            checked: widget.items[index].value == widget.value,
          ),
      ],
      targetBuilder: (_, open) => AppPrismTheme(
        child: Builder(
          builder: (prismContext) {
            final surfaceColor = prism_surface.SurfaceContext(prismContext)
                .raisedSurfaceLevel
                .colorOf(prismColorSchemeOf(theme.colorScheme));
            return DecoratedBox(
              key: widget.anchorKey,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: outline),
              ),
              child: SizedBox(
                height: _anchorHeight,
                width: double.infinity,
                child: prism_press.PressRegion(
                  onTap: widget.enabled ? open : null,
                  overlay: prism_press.PressRegion.pressOverlay,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.valueLabelBuilder(widget.value),
                                key: widget.summaryKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: foreground,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ComposerDropdownArrow(
                          isExpanded: _isMenuOpen,
                          color: foreground,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ComposerDropdownArrow extends StatelessWidget {
  const _ComposerDropdownArrow({required this.isExpanded, required this.color});

  final bool isExpanded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isExpanded ? 0.5 : 0),
      duration: AppMotion.duration(context, const Duration(milliseconds: 160)),
      curve: Curves.easeOutCubic,
      builder: (context, turns, child) {
        return RotationTransition(
          turns: AlwaysStoppedAnimation<double>(turns),
          child: child,
        );
      },
      child: Icon(Icons.keyboard_arrow_down, color: color),
    );
  }
}
