import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/main_shell_bottom_inset.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/media/cover_focal_point.dart';
import 'package:y300/features/cache/presentation/widgets/library_cached_image.dart';
import 'package:y300/features/library_shared/domain/contracts/library_view_preferences_repository.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/library_shared/domain/services/recent_reading.dart';
import 'package:y300/features/library_shared/domain/services/shelf_feature_flags.dart';
import 'package:y300/features/library_shared/presentation/controllers/unified_shelf_controller.dart';
import 'package:y300/features/library_shared/presentation/selection/selection_app_bar.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_controller.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/services/library_shelf_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/services/recent_reading_action.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';
import 'package:y300/features/library_shared/presentation/services/library_task_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_sort_option_tile.dart';
import 'package:y300/features/recent_search/application/recent_searches_controller.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/features/recent_search/presentation/recent_search_view.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/shelf/fixed_slot_pager_header.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_card.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_image.dart';
import 'package:y300/shared/widgets/shelf/shelf_grid_geometry.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';
import 'package:y300/shared/widgets/library_cover_placeholder.dart';
import 'package:y300/shared/widgets/inline_search_app_bar.dart';
import 'package:y300/features/library_shared/presentation/widgets/shelf_page_title_scope.dart';

/// 统一书架页面（Phase 3）。
class UnifiedShelfPage extends ConsumerStatefulWidget {
  const UnifiedShelfPage({
    super.key,
    required this.adapter,
    this.viewPreferencesRepository,
    required this.onOpenWork,
    this.imageReferer,
    this.featureFlags = ShelfFeatureFlags.defaults,
    this.isActive = true,
    this.selectionHost,
    this.recentReadingAction,
  });

  final ShelfModuleAdapter adapter;
  final LibraryViewPreferencesRepository? viewPreferencesRepository;
  final Future<void> Function(BuildContext context, String workId) onOpenWork;
  final String? imageReferer;
  final ShelfFeatureFlags featureFlags;
  final bool isActive;
  final ShelfSelectionHostController? selectionHost;
  final RecentReadingAction? recentReadingAction;

  @override
  ConsumerState<UnifiedShelfPage> createState() => _UnifiedShelfPageState();
}

class _UnifiedShelfPageState extends ConsumerState<UnifiedShelfPage> {
  static const String _moduleActionPrefix = 'module-action:';

  late final UnifiedShelfController _controller;
  late final PageController _pageController;
  late final ShelfSelectionController _selectionController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Object _selectionOwnerToken = Object();
  RecentReadingTarget? _recentReadingTarget;
  Future<void>? _recentReadingTargetFlight;
  Future<void>? _recentReadingOpenFlight;
  ValueListenable<LibraryShelfRefreshSignal?>? _recentReadingRefreshSignals;
  bool _recentReadingBusy = false;

  @override
  void initState() {
    super.initState();
    _controller = UnifiedShelfController(
      adapter: widget.adapter,
      viewPreferencesRepository: widget.viewPreferencesRepository,
      featureFlags: widget.featureFlags,
      backgroundReloadEnabled: widget.isActive,
    );
    _pageController = PageController();
    _selectionController = ShelfSelectionController()
      ..addListener(_handleSelectionStateChanged);
    _controller.stateListenable.addListener(_handleControllerStateChanged);
    // Local reads need no layout. Render the snapshot notification immediately,
    // even when initialize() is still persisting the resolved category.
    unawaited(_controller.initialize());
    _bindRecentReadingSignals();
    unawaited(_refreshRecentReadingTarget());
  }

  void _handleControllerStateChanged() {
    if (!mounted) {
      return;
    }
    _pruneSelectionForCurrentCategory();
    _syncSelectionHost();
    setState(() {});
  }

  void _handleSelectionStateChanged() {
    if (!mounted) {
      return;
    }
    if (_selectionController.isSelecting &&
        _selectionController.selectedCount == 0) {
      _exitSelection(notifyHost: true);
      return;
    }
    _syncSelectionHost();
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant UnifiedShelfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.recentReadingAction, widget.recentReadingAction)) {
      _bindRecentReadingSignals();
      unawaited(_refreshRecentReadingTarget());
    } else if (!oldWidget.isActive && widget.isActive) {
      unawaited(_refreshRecentReadingTarget());
    }
    if (oldWidget.isActive != widget.isActive) {
      _controller.setBackgroundReloadEnabled(widget.isActive);
      if (widget.isActive) {
        _syncSelectionHost();
      } else {
        widget.selectionHost?.deactivate(_selectionOwnerToken);
      }
    }
    if (!identical(oldWidget.selectionHost, widget.selectionHost)) {
      oldWidget.selectionHost?.deactivate(_selectionOwnerToken);
      _syncSelectionHost();
    }
  }

  @override
  void dispose() {
    widget.selectionHost?.deactivate(_selectionOwnerToken);
    _selectionController
      ..removeListener(_handleSelectionStateChanged)
      ..dispose();
    _controller.stateListenable.removeListener(_handleControllerStateChanged);
    _recentReadingRefreshSignals?.removeListener(
      _handleRecentReadingRefreshSignal,
    );
    _controller.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _controller.state;
    final imageReferer = widget.imageReferer;
    final categories = state.categories;
    final tabs = categories
        .map(
          (category) => FixedSlotHeaderTab(
            id: category.categoryId,
            label: _buildCategoryLabel(category),
          ),
        )
        .toList(growable: false);
    final selectedIndex = _resolveSelectedIndex(
      categories,
      state.selectedCategoryId,
    );
    final selecting = _selectionController.isSelecting;
    final shelfPalette = const ShelfThemePaletteResolver().resolve(
      Theme.of(context),
    );

    final content = PopScope<void>(
      canPop: !selecting && !state.isSearchMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (selecting) {
          _exitSelection();
          return;
        }
        if (state.isSearchMode) {
          await _exitSearchMode();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(state),
        body: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                // 书架内容位于 PageView 内部，垂直列表/网格滚动通知深度通常 > 0。
                // 显式放宽 predicate，确保网格/列表场景都能触发下拉刷新。
                notificationPredicate: (notification) {
                  return notification.metrics.axis == Axis.vertical;
                },
                onRefresh: _handlePullToRefresh,
                child: state.isLoading
                    ? Column(
                        children: [
                          _buildTaskProgressBanner(),
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildTaskProgressBanner(),
                          if (state.errorMessage != null &&
                              state.errorMessage!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  LibraryShelfTextResolver.loadError(
                                    l10n,
                                    state.errorMessage,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                ),
                              ),
                            ),
                          if (state.isSearchMode &&
                              state.keyword.trim().isEmpty)
                            RecentSearchView(
                              scope: _recentScopeFor(state.moduleKey),
                              onSelected: _applyRecentKeyword,
                            ),
                          if (categories.isNotEmpty)
                            IgnorePointer(
                              ignoring: selecting,
                              child: FixedSlotPagerHeader(
                                pageController: _pageController,
                                tabs: tabs,
                                selectedIndex: selectedIndex,
                                onTap: (index) async {
                                  await _controller.selectCategory(
                                    categories[index].categoryId,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  _pruneSelectionForCurrentCategory();
                                  _syncSelectionHost();
                                  setState(() {});
                                  await _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                                indicatorKey: const Key(
                                  'unified-shelf-category-indicator',
                                ),
                                tabKeyBuilder: (id) => ValueKey<String>(
                                  'unified-shelf-category-tab-$id',
                                ),
                              ),
                            ),
                          if (categories.isNotEmpty)
                            Divider(
                              height: 1,
                              color: shelfPalette.categoryDivider,
                            ),
                          Expanded(
                            child: categories.isEmpty
                                ? _AlwaysScrollableEmptyState(
                                    message: l10n.libraryShelfEmpty,
                                  )
                                : ValueListenableBuilder<UnifiedShelfState>(
                                    valueListenable:
                                        _controller.stateListenable,
                                    builder: (context, liveState, _) {
                                      return PageView.builder(
                                        controller: _pageController,
                                        physics: selecting
                                            ? const NeverScrollableScrollPhysics()
                                            : null,
                                        itemCount: categories.length,
                                        onPageChanged: (index) async {
                                          await _controller.selectCategory(
                                            categories[index].categoryId,
                                          );
                                          if (!mounted) {
                                            return;
                                          }
                                          _pruneSelectionForCurrentCategory();
                                          _syncSelectionHost();
                                          setState(() {});
                                        },
                                        itemBuilder: (context, index) {
                                          final category = categories[index];
                                          final items =
                                              liveState.itemsByCategory[category
                                                  .categoryId] ??
                                              const <LibraryWorkItem>[];
                                          return _ShelfCategoryPage(
                                            key: PageStorageKey<String>(
                                              'unified-shelf-category-page-${category.categoryId}',
                                            ),
                                            categoryId: category.categoryId,
                                            moduleKey: liveState.moduleKey,
                                            items: items,
                                            displayMode: liveState.displayMode,
                                            gridColumns:
                                                liveState.gridColumnCount,
                                            imageReferer: imageReferer,
                                            useShelfCoverImage: widget
                                                .featureFlags
                                                .useShelfCoverImage,
                                            showUnreadBadge:
                                                resolveShelfModuleCapabilities(
                                                  widget.adapter,
                                                ).showsUnreadBadge,
                                            selectedWorkIds:
                                                _selectionController
                                                    .selectedWorkIds,
                                            selectionEnabled: _selectionEnabled,
                                            onTapItem: _handleItemTap,
                                            onLongPressItem:
                                                _handleItemLongPress,
                                            onVisibleRangeChanged:
                                                ({
                                                  required firstIndex,
                                                  required lastIndex,
                                                }) {
                                                  _controller
                                                      .reportVisibleRange(
                                                        categoryId:
                                                            category.categoryId,
                                                        firstIndex: firstIndex,
                                                        lastIndex: lastIndex,
                                                      );
                                                },
                                          );
                                        },
                                        findChildIndexCallback: (key) {
                                          final valueKey =
                                              key is ValueKey<String>
                                              ? key.value
                                              : null;
                                          if (valueKey == null ||
                                              !valueKey.startsWith(
                                                'unified-shelf-category-page-',
                                              )) {
                                            return null;
                                          }
                                          final categoryId = valueKey.substring(
                                            'unified-shelf-category-page-'
                                                .length,
                                          );
                                          final index = categories.indexWhere(
                                            (category) =>
                                                category.categoryId ==
                                                categoryId,
                                          );
                                          return index < 0 ? null : index;
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_recentReadingVisible)
              Positioned(
                right: 16 + MediaQuery.paddingOf(context).right,
                bottom: 16 + mainShellBottomScrollInset(context),
                child: _buildRecentReadingButton(),
              ),
          ],
        ),
      ),
    );
    try {
      ProviderScope.containerOf(context, listen: false);
      return content;
    } on StateError {
      // Keep the shared page embeddable in isolated hosts and widget tests.
      // Production inherits the app-level container through the branch above.
      return ProviderScope(child: content);
    }
  }

  void _bindRecentReadingSignals() {
    final next = widget.recentReadingAction == null
        ? null
        : widget.adapter.shelfRefreshSignals;
    if (identical(_recentReadingRefreshSignals, next)) {
      return;
    }
    _recentReadingRefreshSignals?.removeListener(
      _handleRecentReadingRefreshSignal,
    );
    _recentReadingRefreshSignals = next;
    next?.addListener(_handleRecentReadingRefreshSignal);
  }

  void _handleRecentReadingRefreshSignal() {
    unawaited(_refreshRecentReadingTarget());
  }

  Future<void> _refreshRecentReadingTarget() async {
    final existing = _recentReadingTargetFlight;
    if (existing != null || !mounted) {
      return existing;
    }
    final action = widget.recentReadingAction;
    if (action == null) {
      return;
    }
    final flight = _loadRecentReadingTarget(action);
    _recentReadingTargetFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_recentReadingTargetFlight, flight)) {
        _recentReadingTargetFlight = null;
      }
    }
  }

  Future<void> _loadRecentReadingTarget(RecentReadingAction action) async {
    RecentReadingTarget? target;
    try {
      target = await action.resolve();
    } catch (_) {
      target = null;
    }
    if (!mounted) {
      return;
    }
    if (_recentReadingTarget == target) {
      return;
    }
    setState(() {
      _recentReadingTarget = target;
    });
  }

  Future<void> _openRecentReading() async {
    final action = widget.recentReadingAction;
    if (action == null || _recentReadingOpenFlight != null) {
      return;
    }
    final flight = _runRecentReadingOpen(action);
    _recentReadingOpenFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_recentReadingOpenFlight, flight)) {
        _recentReadingOpenFlight = null;
      }
    }
  }

  Future<void> _runRecentReadingOpen(RecentReadingAction action) async {
    setState(() {
      _recentReadingBusy = true;
    });
    try {
      RecentReadingTarget? target;
      try {
        target = await action.resolve();
      } catch (_) {
        target = null;
      }
      if (!mounted) {
        return;
      }
      if (target == null) {
        setState(() {
          _recentReadingTarget = null;
        });
        return;
      }
      await action.open(context, target);
      if (!mounted) {
        return;
      }
      await _refreshRecentReadingTarget();
    } finally {
      if (mounted) {
        setState(() {
          _recentReadingBusy = false;
        });
      }
    }
  }

  bool get _recentReadingVisible {
    final action = widget.recentReadingAction;
    return action != null &&
        !_selectionController.isSelecting &&
        !_controller.state.isSearchMode &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
  }

  Widget _buildRecentReadingButton() {
    final l10n = AppLocalizations.of(context);
    final enabled =
        _recentReadingTarget != null &&
        !_recentReadingBusy &&
        _recentReadingVisible;
    return TransientFeedbackObstacle(
      bottom: 80,
      child: FloatingActionButton.extended(
        key: const Key('unified-shelf-recent-reading'),
        onPressed: enabled ? _openRecentReading : null,
        tooltip: enabled
            ? l10n.libraryShelfContinueReading
            : l10n.libraryShelfNoRecentReading,
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.libraryShelfContinueReading),
      ),
    );
  }

  Future<void> _handlePullToRefresh() async {
    await _controller.refreshFromSource();
    if (!mounted) {
      return;
    }
    _pruneSelectionForCurrentCategory();
    _syncSelectionHost();
    setState(() {});
  }

  bool get _selectionEnabled {
    return widget.selectionHost != null &&
        widget.adapter is ShelfSelectionActionAdapter;
  }

  List<SelectionAction> get _selectionActions {
    if (!_selectionEnabled) {
      return const <SelectionAction>[];
    }
    final selectionAdapter = widget.adapter as ShelfSelectionActionAdapter;
    return selectionAdapter.selectionActions;
  }

  List<LibraryWorkItem> get _currentCategoryItems {
    return _controller.state.itemsByCategory[_controller
            .state
            .selectedCategoryId] ??
        const <LibraryWorkItem>[];
  }

  Set<String> get _currentVisibleWorkIds {
    return _currentCategoryItems.map((item) => item.identityKey).toSet();
  }

  Set<LibraryModuleKey> get _selectedSources {
    final selected = _selectionController.selectedWorkIds;
    if (selected.isEmpty) {
      return const <LibraryModuleKey>{};
    }
    final sources = <LibraryModuleKey>{};
    for (final item in _currentCategoryItems) {
      if (selected.contains(item.identityKey)) {
        sources.add(item.source ?? widget.adapter.moduleKey);
      }
    }
    return sources;
  }

  Future<void> _handleItemTap(String workId) async {
    if (_selectionEnabled && _selectionController.isSelecting) {
      _selectionController.toggle(workId);
      return;
    }
    if (_controller.state.keyword.trim().isNotEmpty) {
      // Opening a filtered result is an explicit search use; plain typing and
      // debounced intermediate fragments never reach this path.
      _recordRecentKeyword(_controller.state.keyword);
    }
    await _openWorkAndRefreshShelf(workId);
  }

  Future<void> _handleItemLongPress(String workId) async {
    if (!_selectionEnabled) {
      return;
    }
    if (_selectionController.isSelecting) {
      _selectionController.toggle(workId);
      return;
    }
    _selectionController.enter(workId);
  }

  Future<void> _exitSelection({bool notifyHost = true}) async {
    if (!_selectionController.isSelecting &&
        _selectionController.selectedCount == 0) {
      if (notifyHost) {
        widget.selectionHost?.deactivate(_selectionOwnerToken);
      }
      return;
    }
    _selectionController.exit();
    if (notifyHost) {
      widget.selectionHost?.deactivate(_selectionOwnerToken);
    }
  }

  void _pruneSelectionForCurrentCategory() {
    if (!_selectionController.isSelecting) {
      return;
    }
    _selectionController.prune(_currentVisibleWorkIds);
    if (_selectionController.selectedCount == 0) {
      _exitSelection();
    }
  }

  void _syncSelectionHost() {
    final host = widget.selectionHost;
    if (host == null) {
      return;
    }
    if (!_selectionEnabled ||
        !_selectionController.isSelecting ||
        _selectionController.selectedCount == 0 ||
        !widget.isActive) {
      host.deactivate(_selectionOwnerToken);
      return;
    }
    final delegate = ShelfSelectionHostDelegate(
      exitSelection: () => _exitSelection(),
      selectAllVisible: () async {
        _selectionController.selectAll(_currentVisibleWorkIds);
      },
      invertVisible: () async {
        _selectionController.invert(_currentVisibleWorkIds);
      },
      loadAvailableCategories: () => widget.adapter.loadCategories(),
      createCategory: (name, {source}) async {
        final effectiveSource = source ?? _controller.selectedCategory?.source;
        if (widget.adapter is ShelfCategorySourceAdapter &&
            effectiveSource != null) {
          final categoryId = await _controller.createCategoryForSource(
            effectiveSource,
            name,
          );
          if (categoryId != null) {
            return categoryId;
          }
        }
        return widget.adapter.createCategory(name: name);
      },
      runSelectionAction: (request) {
        final adapter = widget.adapter as ShelfSelectionActionAdapter;
        return adapter.runSelectionAction(request);
      },
      refreshAfterAction: () async {
        await _controller.refresh();
        if (!mounted) {
          return;
        }
        _pruneSelectionForCurrentCategory();
        setState(() {});
      },
    );
    final state = host.state;
    if (state != null && identical(state.ownerToken, _selectionOwnerToken)) {
      host.update(
        ownerToken: _selectionOwnerToken,
        activeCategoryId: _controller.state.selectedCategoryId,
        selectedCount: _selectionController.selectedCount,
        selectedWorkIds: _selectionController.selectedWorkIds,
        selectionActions: _selectionActions,
        selectedSources: _selectedSources,
      );
      return;
    }
    host.activate(
      ownerToken: _selectionOwnerToken,
      moduleKey: _controller.state.moduleKey,
      activeCategoryId: _controller.state.selectedCategoryId,
      selectedCount: _selectionController.selectedCount,
      selectedWorkIds: _selectionController.selectedWorkIds,
      selectionActions: _selectionActions,
      selectedSources: _selectedSources,
      delegate: delegate,
    );
  }

  Widget _buildTaskProgressBanner() {
    final progressListenable = widget.adapter.taskProgress;
    if (progressListenable == null) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<LibraryShelfTaskProgress?>(
      valueListenable: progressListenable,
      builder: (context, progress, _) {
        if (progress == null ||
            (!progress.active && !progress.needsAttention) ||
            !progress.visible) {
          return const SizedBox.shrink();
        }
        return _ShelfTaskProgressBanner(progress: progress);
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UnifiedShelfState state) {
    if (_selectionEnabled && _selectionController.isSelecting) {
      return SelectionAppBar(
        selectedCount: _selectionController.selectedCount,
        l10n: AppLocalizations.of(context),
        onClose: () {
          _exitSelection();
        },
        onSelectAll: () {
          _selectionController.selectAll(_currentVisibleWorkIds);
        },
        onInvertSelection: () {
          _selectionController.invert(_currentVisibleWorkIds);
        },
      );
    }
    final moduleActions = _moduleMenuActions();
    if (!state.isSearchMode) {
      return AppBar(
        leading: adaptiveDetailBackButton(context),
        title:
            ShelfPageTitleScope.titleOf(context) ??
            Text(
              LibraryShelfTextResolver.moduleTitle(
                AppLocalizations.of(context),
                state.moduleKey,
              ),
            ),
        actions: [
          AppToolbarActions(
            children: [
              IconButton(
                key: const Key('unified-shelf-search-button'),
                icon: const Icon(Icons.search),
                tooltip: AppLocalizations.of(context).libraryShelfSearch,
                onPressed: _enterSearchMode,
              ),
              IconButton(
                key: const Key('unified-shelf-filter-button'),
                icon: const Icon(Icons.filter_list),
                tooltip: AppLocalizations.of(context).libraryShelfFilterAndSort,
                onPressed: _showFilterSheet,
              ),
              AppPopupMenuButton<String>(
                key: const Key('unified-shelf-more-button'),
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  AppPopupMenuItem<String>(
                    value: 'add-category',
                    label: AppLocalizations.of(context)
                        .libraryShelfCreateCategory,
                  ),
                  AppPopupMenuItem<String>(
                    value: 'rename-category',
                    label: AppLocalizations.of(context)
                        .libraryShelfRenameCategory,
                  ),
                  AppPopupMenuItem<String>(
                    value: 'delete-category',
                    label: AppLocalizations.of(context)
                        .libraryShelfDeleteCategory,
                  ),
                  if (moduleActions.isNotEmpty) ...[
                    const PopupMenuDivider(),
                    ..._moduleActionItems(moduleActions),
                  ],
                  const PopupMenuDivider(),
                  AppPopupMenuItem<String>(
                    value: 'refresh-shelf',
                    label: AppLocalizations.of(context).libraryShelfUpdate,
                  ),
                  AppPopupMenuItem<String>(
                    value: 'random-open',
                    label: AppLocalizations.of(context).libraryShelfRandomOpen,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    final shelfTitle = ShelfPageTitleScope.titleOf(context);
    return InlineSearchAppBar(
      bottom: shelfTitle != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: shelfTitle,
              ),
            )
          : null,
      controller: _searchController,
      focusNode: _searchFocusNode,
      fieldKey: const Key('unified-shelf-search-input'),
      backButtonKey: const Key('unified-shelf-search-back-button'),
      clearButtonKey: const Key('unified-shelf-search-clear-button'),
      hintText: AppLocalizations.of(context).libraryShelfSearchHint,
      clearTooltip: AppLocalizations.of(context).commonClear,
      onBack: _exitSearchMode,
      onChanged: (value) async {
        await _controller.updateKeyword(value);
        if (!mounted) {
          return;
        }
        setState(() {});
      },
      onSubmitted: _recordRecentKeyword,
    );
  }

  RecentSearchScope _recentScopeFor(LibraryModuleKey key) {
    return switch (key) {
      LibraryModuleKey.comic => RecentSearchScope.comicShelf,
      LibraryModuleKey.novel => RecentSearchScope.novelShelf,
      LibraryModuleKey.favorite => RecentSearchScope.favoriteShelf,
      LibraryModuleKey.bookshelf => RecentSearchScope.bookshelfShelf,
    };
  }

  void _recordRecentKeyword(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(recentSearchesControllerProvider.notifier)
          .record(_recentScopeFor(_controller.state.moduleKey), normalized),
    );
  }

  void _applyRecentKeyword(String keyword) {
    _searchController.text = keyword;
    _searchController.selection = TextSelection.collapsed(
      offset: keyword.length,
    );
    unawaited(
      _controller.updateKeyword(keyword).then((_) {
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  Future<void> _enterSearchMode() async {
    await _controller.enterSearchMode();
    if (!mounted) {
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _exitSearchMode() async {
    _searchFocusNode.unfocus();
    _searchController.clear();
    await _controller.exitSearchMode();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _showFilterSheet() async {
    final state = _controller.state;
    final capabilities = resolveShelfModuleCapabilities(widget.adapter);
    var selectedFilter = capabilities.normalizeFilters(state.filters);
    final supportsDownloadedFilter =
        widget.adapter is ShelfDownloadStatusAdapter;
    if (!supportsDownloadedFilter &&
        selectedFilter.downloaded != TriStateFilterValue.ignore) {
      selectedFilter = selectedFilter.copyWith(
        downloaded: TriStateFilterValue.ignore,
      );
    }
    var selectedSort = capabilities.normalizeSortOption(state.sortOption);
    var selectedMode = state.displayMode;
    var selectedColumns = state.gridColumnCount.toDouble();
    var tabIndex = 0;

    await showAdaptivePanel<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final l10n = AppLocalizations.of(context);
            final tabs = [
              l10n.libraryShelfFilter,
              l10n.libraryShelfSort,
              l10n.libraryShelfDisplayMode,
            ];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(tabs.length, (index) {
                        final selected = tabIndex == index;
                        return Expanded(
                          child: TextButton(
                            onPressed: () =>
                                setSheetState(() => tabIndex = index),
                            child: Text(
                              tabs[index],
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tabIndex == 0)
                              _FilterTab(
                                filters: selectedFilter,
                                showDownloaded: supportsDownloadedFilter,
                                showReadState: capabilities.supportsReadState,
                                showBookmarked:
                                    capabilities.supportsBookmarkFilter,
                                onChanged: (next) =>
                                    setSheetState(() => selectedFilter = next),
                              ),
                            if (tabIndex == 1)
                              _SortTab(
                                sortOption: selectedSort,
                                availableFields:
                                    capabilities.availableSortFields,
                                onChanged: (next) =>
                                    setSheetState(() => selectedSort = next),
                              ),
                            if (tabIndex == 2)
                              _DisplayTab(
                                displayMode: selectedMode,
                                gridColumns: selectedColumns,
                                onDisplayModeChanged: (mode) =>
                                    setSheetState(() => selectedMode = mode),
                                onGridColumnsChanged: (columns) =>
                                    setSheetState(
                                      () => selectedColumns = columns,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(l10n.commonCancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await _controller.updateFilters(selectedFilter);
                              await _controller.updateSortOption(selectedSort);
                              await _controller.updateDisplayMode(selectedMode);
                              await _controller.updateGridColumnCount(
                                selectedColumns.toInt(),
                              );
                              if (!sheetContext.mounted || !mounted) {
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                              setState(() {});
                            },
                            child: Text(l10n.commonApply),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<LibraryShelfMenuAction> _moduleMenuActions() {
    final Object adapter = widget.adapter;
    if (adapter is! ShelfModuleActionAdapter) {
      return const <LibraryShelfMenuAction>[];
    }
    return adapter.menuActions;
  }

  List<PopupMenuEntry<String>> _moduleActionItems(
    List<LibraryShelfMenuAction> actions,
  ) {
    return actions
        .map(
          (action) => AppPopupMenuItem<String>(
            value: _moduleActionMenuValue(action),
            label: LibraryShelfTextResolver.menuAction(
              AppLocalizations.of(context),
              action,
            ),
          ),
        )
        .toList(growable: false);
  }

  String _moduleActionMenuValue(LibraryShelfMenuAction action) {
    return '$_moduleActionPrefix${action.name}';
  }

  Future<void> _handleMenuAction(String value) async {
    final messenger = ScaffoldMessenger.of(context);

    if (value.startsWith(_moduleActionPrefix)) {
      final Object adapter = widget.adapter;
      if (adapter is! ShelfModuleActionAdapter) {
        return;
      }
      final actionName = value.substring(_moduleActionPrefix.length);
      final action = LibraryShelfMenuAction.values.firstWhere(
        (candidate) => candidate.name == actionName,
      );
      final result = await adapter.runMenuAction(action);
      if (!mounted) {
        return;
      }
      if (result.changed) {
        await _controller.refresh();
        if (!mounted) {
          return;
        }
        setState(() {});
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            LibraryShelfTextResolver.menuOutcome(
              AppLocalizations.of(context),
              action,
              result,
            ),
          ),
        ),
      );
      return;
    }

    if (value == 'refresh-shelf') {
      await _controller.refreshFromSource();
      if (!mounted) {
        return;
      }
      setState(() {});
      return;
    }

    if (value == 'random-open') {
      final workId = await _controller.pickRandomWorkId();
      if (!mounted) {
        return;
      }
      if (workId == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).libraryShelfNoRandomWork,
            ),
          ),
        );
        return;
      }
      await _openWorkAndRefreshShelf(workId);
      return;
    }

    if (value == 'add-category') {
      final l10n = AppLocalizations.of(context);
      LibraryModuleKey? mixedSource;
      final selectedCategory = _controller.selectedCategory;
      final needsSourceChoice =
          widget.adapter.moduleKey == LibraryModuleKey.bookshelf &&
          (selectedCategory == null ||
              selectedCategory.source == null ||
              selectedCategory.source == LibraryModuleKey.bookshelf);
      if (needsSourceChoice) {
        mixedSource = await _pickCategorySource();
        if (mixedSource == null) {
          return;
        }
      }
      final name = await _showCategoryNameDialog(
        title: l10n.libraryShelfCreateCategory,
      );
      if (name == null || name.trim().isEmpty) {
        return;
      }
      try {
        if (mixedSource != null) {
          await _controller.createCategoryForSource(mixedSource, name.trim());
        } else {
          await _controller.createCategoryInCurrentSource(name.trim());
        }
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)
                    .libraryShelfCategoryOperationFailed,
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {});
      return;
    }

    final selectedCategory = _controller.selectedCategory;
    if (selectedCategory == null) {
      return;
    }

    if (value == 'rename-category') {
      if (selectedCategory.isDefault) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                  .libraryShelfDefaultCategoryCannotRename,
            ),
          ),
        );
        return;
      }
      final name = await _showCategoryNameDialog(
        title: AppLocalizations.of(context).libraryShelfRenameCategory,
        initialValue: selectedCategory.name,
      );
      if (name == null || name.trim().isEmpty) {
        return;
      }
      try {
        await _controller.renameCategory(
          categoryId: selectedCategory.categoryId,
          newName: name.trim(),
        );
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)
                    .libraryShelfCategoryOperationFailed,
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {});
      return;
    }

    if (value == 'delete-category') {
      if (selectedCategory.isDefault) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                  .libraryShelfDefaultCategoryCannotDelete,
            ),
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              AppLocalizations.of(dialogContext)
                  .libraryShelfDeleteCategoryTitle,
            ),
            content: Text(
              AppLocalizations.of(dialogContext).libraryShelfDeleteCategoryBody,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(dialogContext).commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(AppLocalizations.of(dialogContext).commonDelete),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
      await _controller.deleteCategory(selectedCategory.categoryId);
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  Future<LibraryModuleKey?> _pickCategorySource() {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<LibraryModuleKey>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                enabled: false,
                title: Text(l10n.libraryShelfCreateCategory),
              ),
              ListTile(
                key: const Key('unified-shelf-category-source-comic'),
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(l10n.libraryShelfTitle('comic')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(LibraryModuleKey.comic),
              ),
              ListTile(
                key: const Key('unified-shelf-category-source-novel'),
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(l10n.libraryShelfTitle('novel')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(LibraryModuleKey.novel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showCategoryNameDialog({
    required String title,
    String initialValue = '',
  }) async {
    final textController = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(dialogContext)
                  .libraryShelfCategoryNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(dialogContext).commonCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text),
              child: Text(AppLocalizations.of(dialogContext).commonConfirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWorkAndRefreshShelf(String workId) async {
    await widget.onOpenWork(context, workId);
    if (!mounted) {
      return;
    }
    await _controller.refresh();
    if (mounted) {
      setState(() {});
    }
  }

  int _resolveSelectedIndex(
    List<LibraryCategory> categories,
    String selectedId,
  ) {
    if (categories.isEmpty) {
      return 0;
    }
    final index = categories.indexWhere((e) => e.categoryId == selectedId);
    return index < 0 ? 0 : index;
  }

  String _buildCategoryLabel(LibraryCategory category) {
    final count =
        _controller.state.visibleMatchCountByCategory[category.categoryId] ?? 0;
    return LibraryShelfTextResolver.categoryLabel(
      AppLocalizations.of(context),
      category,
      showMatchCount: _controller.state.keyword.trim().isNotEmpty,
      matchCount: count,
    );
  }
}

class _ShelfCategoryPage extends ConsumerStatefulWidget {
  const _ShelfCategoryPage({
    super.key,
    required this.categoryId,
    required this.moduleKey,
    required this.items,
    required this.displayMode,
    required this.gridColumns,
    this.imageReferer,
    required this.useShelfCoverImage,
    required this.showUnreadBadge,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.selectionEnabled,
    required this.selectedWorkIds,
    required this.onVisibleRangeChanged,
  });

  final String categoryId;
  final LibraryModuleKey moduleKey;
  final List<LibraryWorkItem> items;
  final LibraryDisplayMode displayMode;
  final int gridColumns;
  final String? imageReferer;
  final bool useShelfCoverImage;
  final bool showUnreadBadge;
  final Future<void> Function(String workId) onTapItem;
  final Future<void> Function(String workId) onLongPressItem;
  final bool selectionEnabled;
  final Set<String> selectedWorkIds;
  final void Function({required int firstIndex, required int lastIndex})
  onVisibleRangeChanged;

  @override
  ConsumerState<_ShelfCategoryPage> createState() => _ShelfCategoryPageState();
}

class _ShelfCategoryPageState extends ConsumerState<_ShelfCategoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportInitialRange());
  }

  @override
  void didUpdateWidget(covariant _ShelfCategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.displayMode != widget.displayMode ||
        oldWidget.gridColumns != widget.gridColumns) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportInitialRange(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.items.isEmpty) {
      return _AlwaysScrollableEmptyState(
        message: AppLocalizations.of(context).libraryShelfEmpty,
      );
    }
    final child = widget.displayMode == LibraryDisplayMode.list
        ? _WorkList(
            categoryId: widget.categoryId,
            moduleKey: widget.moduleKey,
            items: widget.items,
            imageReferer: widget.imageReferer,
            useShelfCoverImage: widget.useShelfCoverImage,
            showUnreadBadge: widget.showUnreadBadge,
            onTapItem: widget.onTapItem,
            onLongPressItem: widget.onLongPressItem,
            selectionEnabled: widget.selectionEnabled,
            selectedWorkIds: widget.selectedWorkIds,
          )
        : _WorkGrid(
            categoryId: widget.categoryId,
            moduleKey: widget.moduleKey,
            items: widget.items,
            gridColumns: widget.gridColumns,
            imageReferer: widget.imageReferer,
            useShelfCoverImage: widget.useShelfCoverImage,
            showUnreadBadge: widget.showUnreadBadge,
            onTapItem: widget.onTapItem,
            onLongPressItem: widget.onLongPressItem,
            selectionEnabled: widget.selectionEnabled,
            selectedWorkIds: widget.selectedWorkIds,
          );
    return RepaintBoundary(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            _reportRangeForMetrics(notification.metrics);
          }
          return false;
        },
        child: KeyedSubtree(
          key: ValueKey<String>(
            'unified-shelf-category-scroll-host-${widget.categoryId}',
          ),
          child: child,
        ),
      ),
    );
  }

  void _reportInitialRange() {
    if (!mounted || widget.items.isEmpty) {
      return;
    }
    widget.onVisibleRangeChanged(
      firstIndex: 0,
      lastIndex: _estimateVisibleCount() - 1,
    );
  }

  void _reportRangeForMetrics(ScrollMetrics metrics) {
    if (widget.items.isEmpty) {
      return;
    }
    final firstIndex = _estimateFirstIndex(metrics.pixels);
    final visibleCount = _estimateVisibleCount();
    widget.onVisibleRangeChanged(
      firstIndex: firstIndex,
      lastIndex: firstIndex + visibleCount - 1,
    );
  }

  Size _coverDisplaySize() {
    if (widget.displayMode == LibraryDisplayMode.list) {
      return const Size.square(52);
    }
    final layoutWidth = context.size?.width;
    final viewportWidth =
        layoutWidth != null && layoutWidth.isFinite && layoutWidth > 0
        ? layoutWidth
        : MediaQuery.sizeOf(context).width;
    final columns = ShelfGridGeometry.columnCount(
      viewportWidth,
      widget.gridColumns,
    );
    final width =
        (viewportWidth -
            ShelfGridGeometry.contentPadding * 2 -
            ShelfGridGeometry.itemSpacing * (columns - 1)) /
        columns;
    return Size(width, width * 1.5);
  }

  int _estimateFirstIndex(double scrollOffset) {
    if (widget.displayMode == LibraryDisplayMode.list) {
      return (scrollOffset / 72)
          .floor()
          .clamp(0, widget.items.length - 1)
          .toInt();
    }
    final columns = ShelfGridGeometry.columnCount(
      context.size?.width ?? MediaQuery.sizeOf(context).width,
      widget.gridColumns,
    );
    final rowExtent =
        _coverDisplaySize().height + ShelfGridGeometry.itemSpacing;
    return ((scrollOffset / rowExtent).floor() * columns)
        .clamp(0, widget.items.length - 1)
        .toInt();
  }

  int _estimateVisibleCount() {
    if (widget.displayMode == LibraryDisplayMode.list) {
      return (MediaQuery.sizeOf(context).height / 82).ceil() + 1;
    }
    final columns = ShelfGridGeometry.columnCount(
      context.size?.width ?? MediaQuery.sizeOf(context).width,
      widget.gridColumns,
    );
    final size = _coverDisplaySize();
    final rows =
        (MediaQuery.sizeOf(context).height /
                (size.height + ShelfGridGeometry.itemSpacing))
            .ceil();
    return columns * (rows + 1);
  }
}

class _WorkGrid extends StatelessWidget {
  const _WorkGrid({
    required this.categoryId,
    required this.moduleKey,
    required this.items,
    required this.gridColumns,
    this.imageReferer,
    required this.useShelfCoverImage,
    required this.showUnreadBadge,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.selectionEnabled,
    required this.selectedWorkIds,
  });

  final String categoryId;
  final LibraryModuleKey moduleKey;
  final List<LibraryWorkItem> items;
  final int gridColumns;
  final String? imageReferer;
  final bool useShelfCoverImage;
  final bool showUnreadBadge;
  final Future<void> Function(String workId) onTapItem;
  final Future<void> Function(String workId) onLongPressItem;
  final bool selectionEnabled;
  final Set<String> selectedWorkIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ShelfGridGeometry.columnCount(
          constraints.maxWidth,
          gridColumns,
        );
        final horizontalSpace =
            ShelfGridGeometry.contentPadding * 2 +
            ShelfGridGeometry.itemSpacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - horizontalSpace) / columns;
        final rowExtent = itemWidth * 1.5 + ShelfGridGeometry.itemSpacing;
        return KeyedSubtree(
          key: PageStorageKey<String>('unified-shelf-grid-storage-$categoryId'),
          child: GridView.builder(
            key: const Key('unified-shelf-grid-view'),
            // 保证短列表也能触发 RefreshIndicator 下拉手势。
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            // 大书架场景预渲染适度前后缓存，降低滑动抖动。
            scrollCacheExtent: ScrollCacheExtent.pixels(rowExtent),
            // 沉浸式主导航覆盖在正文上方时，末行仍能完整滚出底栏。
            padding: EdgeInsets.fromLTRB(
              ShelfGridGeometry.contentPadding,
              ShelfGridGeometry.contentPadding,
              ShelfGridGeometry.contentPadding,
              ShelfGridGeometry.contentPadding +
                  mainShellBottomScrollInset(context),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: ShelfGridGeometry.itemSpacing,
              mainAxisSpacing: ShelfGridGeometry.itemSpacing,
              childAspectRatio: 2 / 3,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final l10n = AppLocalizations.of(context);
              return ShelfCoverCard(
                key: ValueKey<String>(
                  'unified-shelf-grid-item-${item.identityKey}',
                ),
                coverKey: item.identityKey,
                title: LibraryShelfTextResolver.workTitle(
                  l10n,
                  item.source ?? moduleKey,
                  item.title,
                  item.workId,
                ),
                coverImageUrl: item.coverImageUrl,
                coverLocalPath: item.coverLocalPath,
                customCoverLocalPath: item.customCoverLocalPath,
                customCoverFocusX: item.customCoverFocusX,
                customCoverFocusY: item.customCoverFocusY,
                coverAsset: item.coverAsset,
                imageReferer: imageReferer,
                coverLayerBuilder: useShelfCoverImage
                    ? null
                    : _legacyCoverLayerBuilder,
                onTap: () async => onTapItem(item.identityKey),
                onLongPress: selectionEnabled
                    ? () async => onLongPressItem(item.identityKey)
                    : null,
                topLeftBadge: showUnreadBadge
                    ? _UnreadBadge(
                        count: item.unreadCount,
                        semanticLabel: l10n.libraryShelfUnreadBadgeSemantics(
                          item.unreadCount,
                        ),
                      )
                    : null,
                trailingBadge: item.source == null
                    ? null
                    : _WorkTypeBadge(
                        label: LibraryShelfTextResolver.workTypeBadge(
                          l10n,
                          item.source,
                        ),
                      ),
                showTwoLineCustomEllipsis: true,
                selected: selectedWorkIds.contains(item.identityKey),
              );
            },
          ),
        );
      },
    );
  }

  Widget _legacyCoverLayerBuilder(
    BuildContext context,
    ShelfCoverLayerConfig config,
  ) {
    return LibraryCachedImage(
      localPath: config.localPath,
      imageUrl: config.remoteUrl,
      fit: config.fit,
      alignment: config.alignment,
      placeholder: config.placeholder,
      referer: config.imageReferer,
    );
  }
}

class _ShelfTaskProgressBanner extends StatelessWidget {
  const _ShelfTaskProgressBanner({required this.progress});

  final LibraryShelfTaskProgress progress;

  @override
  Widget build(BuildContext context) {
    final countText = _countText();
    final shelfPalette = const ShelfThemePaletteResolver().resolve(
      Theme.of(context),
    );
    return Material(
      color: shelfPalette.taskProgressBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LibraryTaskTextResolver.message(
                      AppLocalizations.of(context),
                      progress,
                    ),
                    key: const Key('unified-shelf-task-progress-message'),
                    maxLines: progress.needsAttention ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (countText != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    countText,
                    key: const Key('unified-shelf-task-progress-count'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
            if (LibraryTaskTextResolver.queueSummary(
                  AppLocalizations.of(context),
                  progress,
                )
                case final String summary) ...[
              const SizedBox(height: 4),
              Text(
                summary,
                key: const Key('unified-shelf-task-queue-summary'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (progress.active) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: const Key('unified-shelf-task-progress-bar'),
                value: progress.fraction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _countText() {
    final total = progress.total;
    if (total == null || total <= 0) {
      return null;
    }
    return '${progress.current.clamp(0, total)}/$total';
  }
}

class _WorkList extends StatelessWidget {
  const _WorkList({
    required this.categoryId,
    required this.moduleKey,
    required this.items,
    this.imageReferer,
    required this.useShelfCoverImage,
    required this.showUnreadBadge,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.selectionEnabled,
    required this.selectedWorkIds,
  });

  final String categoryId;
  final LibraryModuleKey moduleKey;
  final List<LibraryWorkItem> items;
  final String? imageReferer;
  final bool useShelfCoverImage;
  final bool showUnreadBadge;
  final Future<void> Function(String workId) onTapItem;
  final Future<void> Function(String workId) onLongPressItem;
  final bool selectionEnabled;
  final Set<String> selectedWorkIds;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: PageStorageKey<String>('unified-shelf-list-storage-$categoryId'),
      child: ListView.separated(
        key: const Key('unified-shelf-list-view'),
        // 保证短列表也能触发 RefreshIndicator 下拉手势。
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        // 大书架场景预渲染适度前后缓存，降低滑动抖动。
        scrollCacheExtent: const ScrollCacheExtent.pixels(82),
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          8 + mainShellBottomScrollInset(context),
        ),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, thickness: .5),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedWorkIds.contains(item.identityKey);
          final shelfPalette = const ShelfThemePaletteResolver().resolve(
            Theme.of(context),
          );
          final leading = _hasCoverSource(item)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: _buildLeadingCover(context, item),
                  ),
                )
              : null;
          return AnimatedContainer(
            key: ValueKey<String>(
              'unified-shelf-list-item-${item.identityKey}',
            ),
            duration: AppLayoutTokens.motionDuration(context),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? shelfPalette.selectedBorder
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListTile(
                  key: ValueKey<String>(
                    'unified-shelf-list-tile-${item.identityKey}',
                  ),
                  minTileHeight: 72,
                  selected: selected,
                  onTap: () async => onTapItem(item.identityKey),
                  onLongPress: selectionEnabled
                      ? () async => onLongPressItem(item.identityKey)
                      : null,
                  leading: leading,
                  title: Text(
                    LibraryShelfTextResolver.workTitle(
                      AppLocalizations.of(context),
                      item.source ?? moduleKey,
                      item.title,
                      item.workId,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: item.source == null && !showUnreadBadge
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.source != null) ...[
                              _WorkTypeBadge(
                                label: LibraryShelfTextResolver.workTypeBadge(
                                  AppLocalizations.of(context),
                                  item.source,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (showUnreadBadge)
                              _UnreadBadge(
                                count: item.unreadCount,
                                semanticLabel: AppLocalizations.of(context)
                                    .libraryShelfUnreadBadgeSemantics(
                                      item.unreadCount,
                                    ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeadingCover(BuildContext context, LibraryWorkItem item) {
    final shelfPalette = const ShelfThemePaletteResolver().resolve(
      Theme.of(context),
    );
    final placeholder = LibraryCoverPlaceholder(
      key: const Key('shelf-list-cover-placeholder'),
      color: shelfPalette.coverPlaceholderBackground,
    );
    // 焦点仅作用于自定义封面；展示来源封面时保持居中。
    final alignment = _isShowingCustomCover(item)
        ? coverAlignmentFromFocus(
            item.customCoverFocusX,
            item.customCoverFocusY,
          )
        : Alignment.center;
    if (!useShelfCoverImage) {
      return LibraryCachedImage(
        localPath: _preferredLocalPath(item),
        imageUrl: _preferredRemoteUrl(item),
        fit: BoxFit.cover,
        alignment: alignment,
        placeholder: placeholder,
        referer: imageReferer,
      );
    }
    return ShelfCoverImage(
      coverKey: item.workId,
      coverAsset: item.coverAsset,
      localPath: _preferredLocalPath(item),
      remoteUrl: _preferredRemoteUrl(item),
      imageReferer: imageReferer,
      fit: BoxFit.cover,
      alignment: alignment,
      placeholder: placeholder,
    );
  }

  bool _isShowingCustomCover(LibraryWorkItem item) {
    if (item.coverAsset?.kind == LibraryCoverAssetKind.custom) {
      return true;
    }
    final custom = item.customCoverLocalPath?.trim();
    return custom != null && custom.isNotEmpty;
  }

  bool _hasCoverSource(LibraryWorkItem item) {
    // 区分“作品没有配置封面”和“封面配置存在但加载失败”：
    // 前者在列表模式不占 leading，后者仍交给图片组件显示兜底。
    return item.coverAsset != null ||
        _preferredLocalPath(item) != null ||
        _preferredRemoteUrl(item) != null;
  }

  String? _preferredLocalPath(LibraryWorkItem item) {
    final custom = item.customCoverLocalPath?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    final cover = item.coverLocalPath?.trim();
    return cover == null || cover.isEmpty ? null : cover;
  }

  String? _preferredRemoteUrl(LibraryWorkItem item) {
    final custom = item.customCoverImageUrl?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    final cover = item.coverImageUrl?.trim();
    return cover == null || cover.isEmpty ? null : cover;
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.semanticLabel});

  final int count;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkTypeBadge extends StatelessWidget {
  const _WorkTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AlwaysScrollableEmptyState extends StatelessWidget {
  const _AlwaysScrollableEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      children: [SizedBox(height: 320, child: Center(child: Text(message)))],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.filters,
    required this.showDownloaded,
    required this.showReadState,
    required this.showBookmarked,
    required this.onChanged,
  });

  final LibraryFilterSet filters;
  final bool showDownloaded;
  final bool showReadState;
  final bool showBookmarked;
  final ValueChanged<LibraryFilterSet> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDownloaded)
          _TriStateLine(
            label: AppLocalizations.of(context).libraryShelfFilterDownloaded,
            value: filters.downloaded,
            onChanged: (v) => onChanged(filters.copyWith(downloaded: v)),
          ),
        if (showReadState) ...[
          _TriStateLine(
            label: AppLocalizations.of(context).libraryShelfFilterUnread,
            value: filters.unread,
            onChanged: (v) => onChanged(filters.copyWith(unread: v)),
          ),
          _TriStateLine(
            label: AppLocalizations.of(context).libraryShelfFilterRead,
            value: filters.read,
            onChanged: (v) => onChanged(filters.copyWith(read: v)),
          ),
        ],
        if (showBookmarked)
          _TriStateLine(
            label: AppLocalizations.of(context).libraryShelfFilterBookmarked,
            value: filters.bookmarked,
            onChanged: (v) => onChanged(filters.copyWith(bookmarked: v)),
          ),
      ],
    );
  }
}

class _SortTab extends StatelessWidget {
  const _SortTab({
    required this.sortOption,
    required this.availableFields,
    required this.onChanged,
  });

  final LibraryShelfSortOption sortOption;
  final List<LibraryShelfSortField> availableFields;
  final ValueChanged<LibraryShelfSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: availableFields
          .map((field) {
            final selected = field == sortOption.field;
            return LibrarySortOptionTile(
              label: LibraryShelfTextResolver.sortField(
                AppLocalizations.of(context),
                field,
              ),
              selected: selected,
              direction: sortOption.direction,
              onTap: () {
                final nextDirection =
                    selected &&
                        sortOption.direction == LibrarySortDirection.desc
                    ? LibrarySortDirection.asc
                    : LibrarySortDirection.desc;
                onChanged(
                  LibraryShelfSortOption(
                    field: field,
                    direction: nextDirection,
                  ),
                );
              },
            );
          })
          .toList(growable: false),
    );
  }
}

class _DisplayTab extends StatelessWidget {
  const _DisplayTab({
    required this.displayMode,
    required this.gridColumns,
    required this.onDisplayModeChanged,
    required this.onGridColumnsChanged,
  });

  final LibraryDisplayMode displayMode;
  final double gridColumns;
  final ValueChanged<LibraryDisplayMode> onDisplayModeChanged;
  final ValueChanged<double> onGridColumnsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioGroup<LibraryDisplayMode>(
          groupValue: displayMode,
          onChanged: (value) {
            if (value != null) {
              onDisplayModeChanged(value);
            }
          },
          child: Column(
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context).libraryShelfGrid),
                leading: const Radio<LibraryDisplayMode>(
                  value: LibraryDisplayMode.grid,
                ),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context).libraryShelfList),
                leading: const Radio<LibraryDisplayMode>(
                  value: LibraryDisplayMode.list,
                ),
              ),
            ],
          ),
        ),
        if (displayMode == LibraryDisplayMode.grid) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(AppLocalizations.of(context).libraryShelfColumnsPerRow),
                Expanded(
                  child: Slider(
                    value: gridColumns.clamp(1, 10),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${gridColumns.round()}',
                    onChanged: onGridColumnsChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TriStateLine extends StatelessWidget {
  const _TriStateLine({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TriStateFilterValue value;
  final ValueChanged<TriStateFilterValue> onChanged;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (value) {
      case TriStateFilterValue.ignore:
        icon = Icons.check_box_outline_blank;
        break;
      case TriStateFilterValue.include:
        icon = Icons.check_box;
        break;
      case TriStateFilterValue.exclude:
        icon = Icons.indeterminate_check_box;
        break;
    }
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        final next = switch (value) {
          TriStateFilterValue.ignore => TriStateFilterValue.include,
          TriStateFilterValue.include => TriStateFilterValue.exclude,
          TriStateFilterValue.exclude => TriStateFilterValue.ignore,
        };
        onChanged(next);
      },
    );
  }
}
