import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_category_targets.dart';
import 'package:y300/features/library_shared/presentation/selection/selection_action_bar.dart';
import 'package:y300/features/library_shared/presentation/selection/selection_action_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/library_shared/presentation/services/library_error_summary.dart';
import 'package:y300/features/library_shared/presentation/services/library_shelf_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_category_name_dialog.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// Shares selection actions between tabbed and independently opened shelves.
class ShelfSelectionBottomBar extends ConsumerStatefulWidget {
  const ShelfSelectionBottomBar({super.key, this.fallback});

  final Widget? fallback;

  @override
  ConsumerState<ShelfSelectionBottomBar> createState() =>
      _ShelfSelectionBottomBarState();
}

class _ShelfSelectionBottomBarState
    extends ConsumerState<ShelfSelectionBottomBar> {
  static const String _createCategorySelectionSentinel =
      '__create-selection-category__';

  @override
  Widget build(BuildContext context) {
    final selectionHost = ref.watch(shelfSelectionHostControllerProvider);
    return ListenableBuilder(
      listenable: selectionHost,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: selectionHost.isActive
            ? SelectionActionBar(
                key: const ValueKey<String>('main-shell-selection-bar'),
                actions:
                    selectionHost.state?.selectionActions ??
                    const <SelectionAction>[],
                l10n: AppLocalizations.of(context),
                onActionTap: _handleSelectionActionTap,
              )
            : widget.fallback ?? const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _handleSelectionActionTap(SelectionAction action) async {
    final l10n = AppLocalizations.of(context);
    final selectionHost = ref.read(shelfSelectionHostControllerProvider);
    if (!selectionHost.isActive) {
      return;
    }
    String? targetCategoryId;

    try {
      if (action.id == SelectionActionIds.assignCategory) {
        targetCategoryId = await _pickTargetCategory(selectionHost);
        if (targetCategoryId == null || targetCategoryId.trim().isEmpty) {
          return;
        }
      }

      if (action.needsConfirm) {
        final confirmed = await _confirmSelectionAction(
          action,
          selectionHost.state,
        );
        if (confirmed != true || !mounted) {
          return;
        }
      }

      final result = await selectionHost.executeAction(
        actionId: action.id,
        targetCategoryId: targetCategoryId,
      );
      if (!mounted) {
        return;
      }
      _showSelectionMessage(
        SelectionActionTextResolver.resultMessage(
          l10n,
          action.id,
          result,
          targetCategoryId: targetCategoryId,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSelectionMessage(
        l10n.librarySelectionActionFailed(
          LibraryErrorSummary.resolve(l10n, error),
        ),
      );
    }
  }

  Future<bool?> _confirmSelectionAction(
    SelectionAction action,
    ShelfSelectionHostState? state,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selectedCount = state?.selectedCount ?? 0;
    final title = action.id == SelectionActionIds.unfavorite
        ? l10n.librarySelectionConfirmUnfavoriteTitle
        : l10n.librarySelectionConfirmActionTitle;
    final content = action.id == SelectionActionIds.unfavorite
        ? l10n.librarySelectionConfirmUnfavoriteBody(selectedCount)
        : l10n.librarySelectionConfirmActionBody(
            selectedCount,
            SelectionActionTextResolver.label(l10n, action.id),
          );
    return showAppConfirmDialog(
      context: context,
      title: title,
      message: content,
      confirmLabel: l10n.commonConfirm,
      cancelLabel: l10n.commonCancel,
    );
  }

  Future<String?> _pickTargetCategory(
    ShelfSelectionHostController selectionHost,
  ) async {
    final state = selectionHost.state;
    if (state == null) {
      return null;
    }
    final categories = await selectionHost.loadAvailableCategories();
    if (!mounted) {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    final available = categories
        .where(
          (category) =>
              category.categoryId != state.activeCategoryId &&
              !category.isSynthetic &&
              !category.isSystemCategory,
        )
        .toList(growable: false);
    final selected = await showAdaptivePanel<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(l10n.librarySelectionSelectCategory),
                enabled: false,
              ),
              for (final category in available)
                ListTile(
                  key: ValueKey<String>(
                    'selection-target-category-${category.categoryId}',
                  ),
                  title: Text(
                    LibraryShelfTextResolver.categoryName(l10n, category),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(category.categoryId);
                  },
                ),
              ListTile(
                key: const ValueKey<String>('selection-target-category-home'),
                leading: const Icon(Icons.playlist_remove),
                title: Text(l10n.libraryShelfRemoveFromCategory),
                onTap: () {
                  Navigator.of(sheetContext).pop(LibraryCategoryTargets.home);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.librarySelectionCreateCategory),
                onTap: () {
                  Navigator.of(sheetContext)
                      .pop(_createCategorySelectionSentinel);
                },
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return null;
    }
    if (selected != _createCategorySelectionSentinel) {
      return selected;
    }
    final categoryName = await _showCreateCategoryDialog();
    if (!mounted || categoryName == null || categoryName.trim().isEmpty) {
      return null;
    }
    return selectionHost.createCategory(categoryName.trim());
  }

  Future<String?> _showCreateCategoryDialog() {
    final l10n = AppLocalizations.of(context);
    return showLibraryCategoryNameDialog(
      context,
      title: l10n.librarySelectionCreateCategory,
      hintText: l10n.librarySelectionCategoryNameHint,
      dialogKey: const Key('selection-create-category-dialog'),
      fieldKey: const Key('selection-create-category-name-field'),
    );
  }

  void _showSelectionMessage(String message) {
    showTransientSnackBar(context, message);
  }
}
