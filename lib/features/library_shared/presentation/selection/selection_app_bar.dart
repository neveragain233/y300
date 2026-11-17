import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';
import 'package:y300/l10n/app_localizations.dart';

/// 选择态顶栏沿用压入页外壳：同一页面表面、标题层级和动作胶囊。
///
/// 关闭键保持圆形触区与压入页返回键同规格；全选／反选只投影原回调，
/// 选择集合与页面生命周期仍归原控制器。
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.l10n,
    required this.onClose,
    required this.onSelectAll,
    required this.onInvertSelection,
  });

  final int selectedCount;
  final AppLocalizations l10n;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onInvertSelection;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppPageAppBar(
      key: const Key('selection-app-bar'),
      leading: AppToolbarCloseButton(
        buttonKey: const Key('selection-app-bar-close'),
        tooltip: l10n.librarySelectionExit,
        onPressed: onClose,
      ),
      titleWidget: Text(
        l10n.librarySelectionSelectedCount(selectedCount),
        key: const Key('selection-app-bar-title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          key: const Key('selection-app-bar-select-all'),
          tooltip: l10n.librarySelectionSelectAll,
          icon: const Icon(Icons.select_all),
          onPressed: onSelectAll,
        ),
        IconButton(
          key: const Key('selection-app-bar-invert'),
          tooltip: l10n.librarySelectionInvert,
          icon: const Icon(Icons.flip_to_back),
          onPressed: onInvertSelection,
        ),
      ],
    );
  }
}
