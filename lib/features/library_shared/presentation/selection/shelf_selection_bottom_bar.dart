import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/presentation/selection/selection_action_bar.dart';
import 'package:y300/features/library_shared/presentation/selection/selection_action_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/library_shared/presentation/services/library_error_summary.dart';
import 'package:y300/features/library_shared/presentation/services/library_shelf_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';

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
    _CategoryTargetChoice? categoryTargets;

    try {
      if (action.id == SelectionActionIds.assignCategory) {
        categoryTargets = await _pickCategoryTargets(selectionHost);
        if (categoryTargets == null || categoryTargets.isEmpty) {
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
        targetCategoryId: categoryTargets?.singleTargetCategoryId,
        targetCategoryIdsBySource:
            categoryTargets?.targetsBySource ??
            const <LibraryModuleKey, String>{},
      );
      if (!mounted) {
        return;
      }
      _showSelectionMessage(
        SelectionActionTextResolver.resultMessage(l10n, action.id, result),
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
  ) {
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
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
  }

  Future<_CategoryTargetChoice?> _pickCategoryTargets(
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
    final sources = state.selectedSources;
    if (state.moduleKey != LibraryModuleKey.bookshelf) {
      return _pickSingleCategory(
        selectionHost,
        categories,
        state: state,
        source: null,
      );
    }
    if (sources.length <= 1) {
      final source = sources.isEmpty ? null : sources.single;
      return _pickSingleCategory(
        selectionHost,
        categories.where((category) => category.source == source).toList(),
        state: state,
        source: source,
      );
    }
    return _pickGroupedCategories(selectionHost, categories, state);
  }

  Future<_CategoryTargetChoice?> _pickSingleCategory(
    ShelfSelectionHostController selectionHost,
    List<LibraryCategory> categories, {
    required ShelfSelectionHostState state,
    required LibraryModuleKey? source,
  }) async {
    final l10n = AppLocalizations.of(context);
    final available = categories
        .where((category) => category.categoryId != state.activeCategoryId)
        .toList(growable: false);
    final selected = await showModalBottomSheet<String>(
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.librarySelectionCreateCategory),
                onTap: () {
                  Navigator.of(
                    sheetContext,
                  ).pop(_createCategorySelectionSentinel);
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
      return _CategoryTargetChoice(singleTargetCategoryId: selected);
    }
    final categoryId = await _createCategory(selectionHost, source: source);
    if (categoryId == null) {
      return null;
    }
    return _CategoryTargetChoice(singleTargetCategoryId: categoryId);
  }

  Future<_CategoryTargetChoice?> _pickGroupedCategories(
    ShelfSelectionHostController selectionHost,
    List<LibraryCategory> categories,
    ShelfSelectionHostState state,
  ) async {
    final sortedSources = state.selectedSources.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final categoriesBySource = <LibraryModuleKey, List<LibraryCategory>>{
      for (final source in sortedSources)
        source: categories
            .where(
              (category) =>
                  category.source == source &&
                  category.categoryId != state.activeCategoryId,
            )
            .toList(growable: false),
    };
    final selectedCountBySource = <LibraryModuleKey, int>{
      for (final source in sortedSources) source: 0,
    };
    for (final workKey in selectionHost.selectedWorkIds) {
      final parsed = LibraryWorkId.tryParse(workKey);
      if (parsed != null && selectedCountBySource.containsKey(parsed.source)) {
        selectedCountBySource[parsed.source] =
            selectedCountBySource[parsed.source]! + 1;
      }
    }
    final targets = await showModalBottomSheet<Map<LibraryModuleKey, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _GroupedCategoryTargetSheet(
          sources: sortedSources,
          categoriesBySource: categoriesBySource,
          selectedCountBySource: selectedCountBySource,
          onCreateCategory: (source) async {
            final categoryId = await _showCreateCategoryDialog();
            if (categoryId == null) {
              return null;
            }
            final name = categoryId.trim();
            if (name.isEmpty) {
              return null;
            }
            final newCategoryId = await selectionHost.createCategory(
              name,
              source: source,
            );
            return LibraryCategory(
              categoryId: newCategoryId,
              sourceCategoryId: newCategoryId,
              source: source,
              name: name,
              sortOrder: 0,
              createdAt: DateTime.now(),
            );
          },
        );
      },
    );
    if (targets == null || targets.isEmpty) {
      return null;
    }
    return _CategoryTargetChoice(targetsBySource: targets);
  }

  Future<String?> _createCategory(
    ShelfSelectionHostController selectionHost, {
    required LibraryModuleKey? source,
  }) async {
    final categoryName = await _showCreateCategoryDialog();
    if (!mounted || categoryName == null || categoryName.trim().isEmpty) {
      return null;
    }
    return selectionHost.createCategory(
      categoryName.trim(),
      source: source,
    );
  }

  Future<String?> _showCreateCategoryDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _CreateSelectionCategoryDialog(),
    );
  }

  void _showSelectionMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(trimmed)));
  }
}

class _CategoryTargetChoice {
  const _CategoryTargetChoice({
    this.singleTargetCategoryId,
    this.targetsBySource = const <LibraryModuleKey, String>{},
  });

  final String? singleTargetCategoryId;
  final Map<LibraryModuleKey, String> targetsBySource;

  bool get isEmpty {
    final single = singleTargetCategoryId?.trim() ?? '';
    return single.isEmpty && targetsBySource.isEmpty;
  }
}

class _GroupedCategoryTargetSheet extends StatefulWidget {
  const _GroupedCategoryTargetSheet({
    required this.sources,
    required this.categoriesBySource,
    required this.selectedCountBySource,
    required this.onCreateCategory,
  });

  final List<LibraryModuleKey> sources;
  final Map<LibraryModuleKey, List<LibraryCategory>> categoriesBySource;
  final Map<LibraryModuleKey, int> selectedCountBySource;
  final Future<LibraryCategory?> Function(LibraryModuleKey source)
  onCreateCategory;

  @override
  State<_GroupedCategoryTargetSheet> createState() =>
      _GroupedCategoryTargetSheetState();
}

class _GroupedCategoryTargetSheetState
    extends State<_GroupedCategoryTargetSheet> {
  late final Map<LibraryModuleKey, List<LibraryCategory>> _categories;
  final Map<LibraryModuleKey, String?> _selectedTargets =
      <LibraryModuleKey, String?>{};

  @override
  void initState() {
    super.initState();
    _categories = <LibraryModuleKey, List<LibraryCategory>>{
      for (final source in widget.sources)
        source: List<LibraryCategory>.of(
          widget.categoriesBySource[source] ?? const <LibraryCategory>[],
        ),
    };
    for (final source in widget.sources) {
      _selectedTargets[source] = null;
    }
  }

  bool get _hasSelection =>
      _selectedTargets.values.any((value) => value != null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.librarySelectionSelectCategory,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.librarySelectionMixedSourceHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final source in widget.sources)
                    _buildSourceSection(context, l10n, source),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('selection-target-confirm'),
                  onPressed: _hasSelection
                      ? () {
                          final targets = <LibraryModuleKey, String>{
                            for (final entry in _selectedTargets.entries)
                              if (entry.value != null)
                                entry.key: entry.value!,
                          };
                          Navigator.of(context).pop(targets);
                        }
                      : null,
                  child: Text(l10n.commonConfirm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSection(
    BuildContext context,
    AppLocalizations l10n,
    LibraryModuleKey source,
  ) {
    final categories = _categories[source] ?? const <LibraryCategory>[];
    final selected = _selectedTargets[source];
    final count = widget.selectedCountBySource[source] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.librarySelectionSourceSection(
              l10n.libraryShelfTitle(source.name),
              count,
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        ListTile(
          key: ValueKey<String>('selection-target-keep-${source.name}'),
          leading: Icon(
            selected == null
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(l10n.librarySelectionKeepCurrentCategory),
          onTap: () {
            setState(() {
              _selectedTargets[source] = null;
            });
          },
        ),
        for (final category in categories)
          ListTile(
            key: ValueKey<String>(
              'selection-target-${source.name}-${category.categoryId}',
            ),
            leading: Icon(
              selected == category.categoryId
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(_categoryLabel(l10n, category)),
            onTap: () {
              setState(() {
                _selectedTargets[source] = category.categoryId;
              });
            },
          ),
        ListTile(
          key: ValueKey<String>('selection-target-create-${source.name}'),
          leading: const Icon(Icons.add),
          title: Text(l10n.librarySelectionCreateCategory),
          onTap: () async {
            final category = await widget.onCreateCategory(source);
            if (!mounted || category == null) {
              return;
            }
            setState(() {
              _categories[source] = <LibraryCategory>[
                ...?_categories[source],
                category,
              ];
              _selectedTargets[source] = category.categoryId;
            });
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _categoryLabel(AppLocalizations l10n, LibraryCategory category) {
    return category.isDefault
        ? l10n.libraryShelfDefaultCategory
        : category.name;
  }
}

class _CreateSelectionCategoryDialog extends StatefulWidget {
  const _CreateSelectionCategoryDialog();

  @override
  State<_CreateSelectionCategoryDialog> createState() =>
      _CreateSelectionCategoryDialogState();
}

class _CreateSelectionCategoryDialogState
    extends State<_CreateSelectionCategoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('selection-create-category-dialog'),
      title: Text(l10n.librarySelectionCreateCategory),
      content: TextField(
        key: const Key('selection-create-category-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.librarySelectionCategoryNameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
