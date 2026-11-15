import 'package:flutter/material.dart';
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
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
    final selected = index == widget.selectedIndex;
    final foreground = selected
        ? palette.categorySelectedForeground
        : theme.colorScheme.onSurfaceVariant;
    final background = selected
        ? palette.categorySelectedBackground
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final capsule = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: ShapeDecoration(
        color: background,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        tab.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
    return ConstrainedBox(
      key: widget.tabKeyBuilder(tab.id),
      constraints: const BoxConstraints(minHeight: 48),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => widget.onTap(index),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: selected
                  ? KeyedSubtree(
                      key: _selectedCapsuleKey,
                      child: KeyedSubtree(
                        key: widget.indicatorKey,
                        child: capsule,
                      ),
                    )
                  : capsule,
            ),
          ),
        ),
      ),
    );
  }
}
