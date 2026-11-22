import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism_theme;
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// A lazy, anchored page picker for native forum pagination surfaces.
///
/// Uses prism_ui's [prism.PopupAnchor] + [prism.PopupMenu.builder] pushed onto
/// the root navigator so only visible rows are built even for large page
/// counts while the menu stays above the immersive bottom dock.
class NativePageDropdownButton extends StatelessWidget {
  const NativePageDropdownButton({
    super.key,
    required this.buttonKey,
    required this.menuKeyPrefix,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
    required this.enabled,
    required this.label,
    required this.style,
    required this.onSelected,
  });

  final Key buttonKey;
  final String menuKeyPrefix;
  final int currentPage;
  final int? lastPage;
  final bool hasMore;
  final bool enabled;
  final String label;
  final ButtonStyle? style;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final safeCurrentPage = math.max(1, currentPage);
    final knownLastPage = lastPage;
    final pageCount = knownLastPage != null && knownLastPage > 0
        ? math.max(safeCurrentPage, knownLastPage)
        : safeCurrentPage + (hasMore ? 1 : 0);
    final theme = prism_theme.ThemeData(
      colorScheme: prismColorSchemeOf(Theme.of(context).colorScheme),
    );
    return prism.PopupAnchor(
      useRootNavigator: true,
      placement: prism.PopupPlacement.overAnchorCenter,
      bare: true,
      runsPickedAfterReturn: false,
      reduceMotion: AppMotion.reduceMotion(context),
      theme: theme,
      targetBuilder: (open) => SizedBox(
        key: buttonKey,
        height: 34,
        child: TextButton(
          onPressed: enabled ? open : null,
          style: style,
          child: Text(label),
        ),
      ),
      popupBuilder: (_) => prism.PopupMenu.builder(
        key: Key('$menuKeyPrefix-page-menu'),
        listKey: Key('$menuKeyPrefix-page-list'),
        itemCount: pageCount,
        checkedIndex: safeCurrentPage - 1,
        maxVisibleItems: 7,
        minWidth: 120,
        widthSampleLabels: <String>['$pageCount'],
        itemBuilder: (index) {
          final page = index + 1;
          final selected = page == safeCurrentPage;
          return prism.PopupMenuItem(
            key: Key('$menuKeyPrefix-page-option-$page'),
            label: '$page',
            checked: selected,
            onPressed: () {
              if (!selected) {
                onSelected(page);
              }
            },
          );
        },
      ),
    );
  }
}
