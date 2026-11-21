import 'package:flutter/material.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';

class ShelfCategoryCapsuleTab {
  const ShelfCategoryCapsuleTab({required this.id, required this.label});

  final String id;
  final String label;
}

/// 书架分类的胶囊过滤器。
///
/// 每个分类是一枚可横向滚动的胶囊；选中胶囊承担原来的下划线指示器职责。
/// 分类很多时只滚动胶囊行，不改变下方 PageView 的分页和手势。
class ShelfCategoryCapsuleBar extends StatefulWidget {
  const ShelfCategoryCapsuleBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    required this.indicatorKey,
    required this.tabKeyBuilder,
  });

  final List<ShelfCategoryCapsuleTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Key indicatorKey;
  final Key Function(String id) tabKeyBuilder;

  @override
  State<ShelfCategoryCapsuleBar> createState() =>
      _ShelfCategoryCapsuleBarState();
}

class _ShelfCategoryCapsuleBarState extends State<ShelfCategoryCapsuleBar> {
  final GlobalKey _selectedCapsuleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ensureSelectedVisible();
  }

  @override
  void didUpdateWidget(covariant ShelfCategoryCapsuleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.tabs.length != widget.tabs.length) {
      _ensureSelectedVisible();
    }
  }

  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedCapsuleKey.currentContext;
      if (!mounted || context == null) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = const ShelfThemePaletteResolver().resolve(theme);
    if (widget.tabs.isEmpty) {
      return Material(
        color: palette.categoryBarBackground,
        child: const SizedBox(height: 56),
      );
    }

    return Material(
      color: palette.categoryBarBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  palette: palette,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsule(
    BuildContext context, {
    required int index,
    required ShelfCategoryCapsuleTab tab,
    required ShelfThemePalette palette,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final reduceMotion = AppMotion.reduceMotion(context);
    final glassEnabled =
        !eInk &&
        !MediaQuery.highContrastOf(context) &&
        AppGlassSurface.levelOf(context).enabled;
    final selected = index == widget.selectedIndex;
    final foreground = selected
        ? palette.categorySelectedForeground
        : scheme.onSurfaceVariant;
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
                  baseColor: palette.categorySelectedBackground,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: palette.categorySelectedBackground.withValues(
                        alpha: 0.86,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: pillContent,
                  ),
                )
              : DecoratedBox(
                  decoration: ShapeDecoration(
                    color: palette.categorySelectedBackground,
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
              : AppGlassSurface(
                  borderRadius: 999,
                  baseColor: scheme.surfaceContainerHigh,
                  child: pillContent,
                ));
    final taggedCapsule = selected
        ? KeyedSubtree(
            key: _selectedCapsuleKey,
            child: KeyedSubtree(key: widget.indicatorKey, child: capsule),
          )
        : capsule;
    return Semantics(
      key: widget.tabKeyBuilder(tab.id),
      container: true,
      selected: selected,
      button: true,
      onTap: () => widget.onTap(index),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTap(index),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: reduceMotion
                ? taggedCapsule
                : ElasticPress(child: taggedCapsule),
          ),
        ),
      ),
    );
  }
}
