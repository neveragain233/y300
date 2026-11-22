import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:y300/app/navigation/main_shell_bottom_inset.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_category_name_dialog.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/shared/widgets/eink_scroll_pager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/segmented_control.dart' as prism;
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/media/cover_focal_point.dart';
import 'package:y300/core/motion/app_motion.dart';
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
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';
import 'package:y300/features/library_shared/presentation/services/library_task_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_shelf_app_bar.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_shelf_loading.dart';
import 'package:y300/features/recent_search/application/recent_searches_controller.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/features/recent_search/presentation/recent_search_view.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/shelf/shelf_category_capsule_bar.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_card.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_image.dart';
import 'package:y300/shared/widgets/shelf/shelf_grid_geometry.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';
import 'package:y300/shared/widgets/shelf/library_cover_identity.dart';
import 'package:y300/shared/widgets/shelf/typographic_library_cover.dart';
import 'package:y300/shared/widgets/library_cover_placeholder.dart';
import 'package:y300/shared/widgets/forum_media_loading_style.dart';
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
  final Future<void> Function(
    BuildContext context,
    String workId,
    LibraryWorkItem? shelfItem,
  )
  onOpenWork;
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
  int? _programmaticTargetPage;
  int _pageTransitionToken = 0;
  int? _lastSyncedCategoryIndex;
  String? _lastSyncedCategoryId;

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
          (category) => ShelfCategoryCapsuleTab(
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
    final eInk = EInkModeScope.of(context);
    if (!state.isLoading && categories.isNotEmpty) {
      final syncedId = categories[selectedIndex].categoryId;
      if (_lastSyncedCategoryIndex != selectedIndex ||
          _lastSyncedCategoryId != syncedId ||
          !_pageController.hasClients) {
        _lastSyncedCategoryIndex = selectedIndex;
        _lastSyncedCategoryId = syncedId;
        _schedulePageControllerSync(selectedIndex, categories.length);
      }
    }

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
                          const LibraryShelfCategoryPlaceholder(),
                          const Expanded(child: LibraryShelfLoadingStatus()),
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
                            ShelfCategoryCapsuleBar(
                              tabs: tabs,
                              selectedIndex: selectedIndex,
                              enabled: !selecting,
                              onTap: (index) async {
                                if (selecting ||
                                    index < 0 ||
                                    index >= categories.length) {
                                  return;
                                }
                                final token = ++_pageTransitionToken;
                                _programmaticTargetPage = index;
                                _lastSyncedCategoryIndex = index;
                                _lastSyncedCategoryId =
                                    categories[index].categoryId;
                                final selectFuture = _controller.selectCategory(
                                  categories[index].categoryId,
                                );
                                _pruneSelectionForCurrentCategory();
                                _syncSelectionHost();
                                setState(() {});
                                try {
                                  if (_pageController.hasClients) {
                                    final currentPage =
                                        _pageController.page?.round() ??
                                        _pageController.initialPage;
                                    if (eInk ||
                                        AppMotion.reduceMotion(context) ||
                                        currentPage == index) {
                                      _pageController.jumpToPage(index);
                                    } else {
                                      await _pageController.animateToPage(
                                        index,
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  }
                                } finally {
                                  if (_pageTransitionToken == token) {
                                    _programmaticTargetPage = null;
                                  }
                                }
                                await selectFuture;
                                if (!mounted) {
                                  return;
                                }
                              },
                              longPressMenuBuilder: (context, tab) {
                                final categoryIndex = categories.indexWhere(
                                  (candidate) => candidate.categoryId == tab.id,
                                );
                                if (categoryIndex < 0) {
                                  return const <PopupMenuEntry<String>>[];
                                }
                                final category = categories[categoryIndex];
                                if (category.isSystemCategory ||
                                    category.isSynthetic) {
                                  return const <PopupMenuEntry<String>>[];
                                }
                                return <PopupMenuEntry<String>>[
                                  AppPopupMenuItem<String>(
                                    value: 'rename-category',
                                    label: l10n.libraryShelfRenameCategoryTitle,
                                    icon: const Icon(
                                      Icons.drive_file_rename_outline,
                                    ),
                                  ),
                                  AppPopupMenuItem<String>(
                                    value: 'delete-category',
                                    label: l10n.libraryShelfDeleteCategoryTitle,
                                    icon: const Icon(Icons.delete_outline),
                                    danger: true,
                                  ),
                                ];
                              },
                              onLongPressMenuSelected: (index, value) {
                                if (index < 0 || index >= categories.length) {
                                  return;
                                }
                                final targetCategory = categories[index];
                                if (value == 'rename-category') {
                                  unawaited(_renameCategory(targetCategory));
                                } else if (value == 'delete-category') {
                                  unawaited(_deleteCategory(targetCategory));
                                }
                              },
                              indicatorKey: const Key(
                                'unified-shelf-category-indicator',
                              ),
                              tabKeyBuilder: (id) => ValueKey<String>(
                                'unified-shelf-category-tab-$id',
                              ),
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
                                        physics: (selecting || eInk)
                                            ? const NeverScrollableScrollPhysics()
                                            : null,
                                        itemCount: categories.length,
                                        onPageChanged: (index) async {
                                          if (_programmaticTargetPage != null ||
                                              index < 0 ||
                                              index >= categories.length) {
                                            return;
                                          }
                                          _lastSyncedCategoryIndex = index;
                                          _lastSyncedCategoryId =
                                              categories[index].categoryId;
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final enabled =
        _recentReadingTarget != null &&
        !_recentReadingBusy &&
        _recentReadingVisible;
    final glassActive =
        AppGlassSurface.levelOf(context).enabled &&
        !eInk &&
        !MediaQuery.highContrastOf(context);
    final foreground = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final tooltip = enabled
        ? l10n.libraryShelfContinueReading
        : l10n.libraryShelfNoRecentReading;
    return TransientFeedbackObstacle(
      bottom: 72,
      child: glassActive
          ? FloatingActionButton(
              key: const Key('unified-shelf-recent-reading'),
              onPressed: enabled ? _openRecentReading : null,
              tooltip: tooltip,
              backgroundColor: Colors.transparent,
              foregroundColor: foreground,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              disabledElevation: 0,
              shape: const CircleBorder(),
              child: AppGlassSurface(
                borderRadius: 28,
                child: SizedBox.square(
                  dimension: 56,
                  child: Icon(Icons.play_arrow, color: foreground),
                ),
              ),
            )
          : FloatingActionButton(
              key: const Key('unified-shelf-recent-reading'),
              onPressed: enabled ? _openRecentReading : null,
              tooltip: tooltip,
              backgroundColor: eInk
                  ? scheme.surface
                  : scheme.surfaceContainerHigh,
              foregroundColor: foreground,
              elevation: eInk ? 0 : null,
              highlightElevation: eInk ? 0 : null,
              focusElevation: eInk ? 0 : null,
              hoverElevation: eInk ? 0 : null,
              disabledElevation: eInk ? 0 : null,
              shape: eInk
                  ? CircleBorder(
                      side: BorderSide(
                        color: AppTheme.eInkBorderColor(scheme.brightness),
                      ),
                    )
                  : const CircleBorder(),
              child: const Icon(Icons.play_arrow),
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

  Future<void> _handleItemTap(LibraryWorkItem item) async {
    if (_selectionEnabled && _selectionController.isSelecting) {
      _selectionController.toggle(item.identityKey);
      return;
    }
    if (_controller.state.keyword.trim().isNotEmpty) {
      // Opening a filtered result is an explicit search use; plain typing and
      // debounced intermediate fragments never reach this path.
      _recordRecentKeyword(_controller.state.keyword);
    }
    await _openWorkAndRefreshShelf(item.identityKey, shelfItem: item);
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
      createCategory: (name) => widget.adapter.createCategory(name: name),
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
      return buildLibraryShelfAppBar(
        context,
        moduleKey: state.moduleKey,
        onSearch: _enterSearchMode,
        onFilter: _showFilterSheet,
        menu: AppPopupMenuButton<String>(
          key: const Key('unified-shelf-more-button'),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            AppPopupMenuItem<String>(
              value: 'add-category',
              label: AppLocalizations.of(context).libraryShelfCreateCategory,
              icon: const Icon(Icons.add),
            ),
            AppPopupMenuItem<String>(
              value: 'rename-category',
              label: AppLocalizations.of(context).libraryShelfRenameCategory,
              icon: const Icon(Icons.drive_file_rename_outline),
            ),
            AppPopupMenuItem<String>(
              value: 'delete-category',
              label: AppLocalizations.of(context).libraryShelfDeleteCategory,
              icon: const Icon(Icons.delete_outline),
              danger: true,
            ),
            if (moduleActions.isNotEmpty) ...[
              const PopupMenuDivider(),
              ..._moduleActionItems(moduleActions),
            ],
            const PopupMenuDivider(),
            AppPopupMenuItem<String>(
              value: 'refresh-shelf',
              label: AppLocalizations.of(context).libraryShelfUpdate,
              icon: const Icon(Icons.refresh),
            ),
            AppPopupMenuItem<String>(
              value: 'random-open',
              label: AppLocalizations.of(context).libraryShelfRandomOpen,
              icon: const Icon(Icons.shuffle),
            ),
          ],
        ),
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
    var initialFilter = capabilities.normalizeFilters(state.filters);
    final supportsDownloadedFilter =
        widget.adapter is ShelfDownloadStatusAdapter;
    if (!supportsDownloadedFilter &&
        initialFilter.downloaded != TriStateFilterValue.ignore) {
      initialFilter = initialFilter.copyWith(
        downloaded: TriStateFilterValue.ignore,
      );
    }
    final initialSort = capabilities.normalizeSortOption(state.sortOption);

    await showAdaptivePanel<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _UnifiedShelfFilterPanel(
          initialFilters: initialFilter,
          initialSortOption: initialSort,
          initialDisplayMode: state.displayMode,
          initialGridColumns: state.gridColumnCount.toDouble(),
          showDownloaded: supportsDownloadedFilter,
          showReadState: capabilities.supportsReadState,
          showBookmarked: capabilities.supportsBookmarkFilter,
          availableSortFields: capabilities.availableSortFields,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onApply: (filters, sortOption, displayMode, gridColumnCount) =>
              unawaited(
                _commitShelfPanel(
                  sheetContext: sheetContext,
                  filters: filters,
                  sortOption: sortOption,
                  displayMode: displayMode,
                  gridColumnCount: gridColumnCount,
                ),
              ),
        );
      },
    );
  }

  /// 确认只提交实际变化的项，一次性完成并关闭面板，不重复持久化或重载书架。
  Future<void> _commitShelfPanel({
    required BuildContext sheetContext,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required LibraryDisplayMode displayMode,
    required int gridColumnCount,
  }) async {
    final state = _controller.state;
    if (!_sameLibraryFilters(filters, state.filters)) {
      await _controller.updateFilters(filters);
    }
    if (sortOption.field != state.sortOption.field ||
        sortOption.direction != state.sortOption.direction) {
      await _controller.updateSortOption(sortOption);
    }
    if (displayMode != state.displayMode) {
      await _controller.updateDisplayMode(displayMode);
    }
    if (gridColumnCount != state.gridColumnCount) {
      await _controller.updateGridColumnCount(gridColumnCount);
    }
    if (!sheetContext.mounted) {
      return;
    }
    Navigator.of(sheetContext).pop();
    if (mounted) {
      setState(() {});
    }
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
    final feedbackStyle = TransientFeedbackStyle.capture(context);

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
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        LibraryShelfTextResolver.menuOutcome(
          AppLocalizations.of(context),
          action,
          result,
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
        showTransientSnackBarWithMessenger(
          messenger,
          feedbackStyle,
          AppLocalizations.of(context).libraryShelfNoRandomWork,
        );
        return;
      }
      await _openWorkAndRefreshShelf(workId);
      return;
    }

    if (value == 'add-category') {
      final l10n = AppLocalizations.of(context);
      final name = await _showCategoryNameDialog(
        title: l10n.libraryShelfCreateCategory,
      );
      if (name == null || name.trim().isEmpty) {
        return;
      }
      try {
        await _controller.createCategory(name.trim());
      } catch (_) {
        if (mounted) {
          showTransientSnackBarWithMessenger(
            messenger,
            feedbackStyle,
            AppLocalizations.of(context).libraryShelfCategoryOperationFailed,
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
      await _renameCategory(selectedCategory);
      return;
    }

    if (value == 'delete-category') {
      await _deleteCategory(selectedCategory);
    }
  }

  Future<void> _renameCategory(LibraryCategory category) async {
    final messenger = ScaffoldMessenger.of(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    if (category.isSystemCategory || category.isSynthetic) {
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        AppLocalizations.of(context).libraryShelfSystemCategoryCannotRename,
      );
      return;
    }
    final name = await _showCategoryNameDialog(
      title: AppLocalizations.of(context).libraryShelfRenameCategory,
      initialValue: category.name,
    );
    if (!mounted || name == null || name.trim().isEmpty) {
      return;
    }
    try {
      await _controller.renameCategory(
        categoryId: category.categoryId,
        newName: name.trim(),
      );
    } catch (_) {
      if (mounted) {
        showTransientSnackBarWithMessenger(
          messenger,
          feedbackStyle,
          AppLocalizations.of(context).libraryShelfCategoryOperationFailed,
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _deleteCategory(LibraryCategory category) async {
    final messenger = ScaffoldMessenger.of(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    if (category.isSystemCategory || category.isSynthetic) {
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        AppLocalizations.of(context).libraryShelfSystemCategoryCannotDelete,
      );
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.libraryShelfDeleteCategoryTitle,
      message: l10n.libraryShelfDeleteCategoryBody,
      confirmLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _controller.deleteCategory(category.categoryId);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _schedulePageControllerSync(int targetIndex, int categoryCount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_pageController.hasClients ||
          _programmaticTargetPage != null ||
          categoryCount <= 0) {
        return;
      }
      final boundedIndex = targetIndex.clamp(0, categoryCount - 1);
      final currentPage =
          _pageController.page?.round() ?? _pageController.initialPage;
      if (currentPage == boundedIndex ||
          _pageController.position.isScrollingNotifier.value) {
        return;
      }
      _programmaticTargetPage = boundedIndex;
      try {
        _pageController.jumpToPage(boundedIndex);
      } finally {
        _programmaticTargetPage = null;
      }
    });
  }

  Future<String?> _showCategoryNameDialog({
    required String title,
    String initialValue = '',
  }) {
    return showLibraryCategoryNameDialog(
      context,
      title: title,
      hintText: AppLocalizations.of(context).libraryShelfCategoryNameHint,
      initialValue: initialValue,
    );
  }

  Future<void> _openWorkAndRefreshShelf(
    String workId, {
    LibraryWorkItem? shelfItem,
  }) async {
    // Random opening can choose a work outside the visible, filtered items.
    shelfItem ??= _currentCategoryItems
        .where((item) => item.identityKey == workId)
        .firstOrNull;
    await widget.onOpenWork(context, workId, shelfItem);
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
  final Future<void> Function(LibraryWorkItem item) onTapItem;
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

class _WorkGrid extends StatefulWidget {
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
  final Future<void> Function(LibraryWorkItem item) onTapItem;
  final Future<void> Function(String workId) onLongPressItem;
  final bool selectionEnabled;
  final Set<String> selectedWorkIds;

  @override
  State<_WorkGrid> createState() => _WorkGridState();
}

class _WorkGridState extends State<_WorkGrid> {
  /// 每个分类页各自持有控制器，滚动位置不跨分类共享。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ShelfGridGeometry.columnCount(
          constraints.maxWidth,
          widget.gridColumns,
        );
        final horizontalSpace =
            ShelfGridGeometry.contentPadding * 2 +
            ShelfGridGeometry.itemSpacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - horizontalSpace) / columns;
        final rowExtent = itemWidth * 1.5 + ShelfGridGeometry.itemSpacing;
        return KeyedSubtree(
          key: PageStorageKey<String>(
            'unified-shelf-grid-storage-${widget.categoryId}',
          ),
          // 网格含横向手势，不启用边缘点击；角标避让右缘最近阅读按钮。
          child: EInkScrollPager(
            controller: _scrollController,
            edgeTapAllowed: false,
            cornerPadding: EdgeInsets.only(
              right: 12,
              bottom: 88 + mainShellBottomScrollInset(context),
            ),
            child: GridView.builder(
              controller: _scrollController,
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
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final l10n = AppLocalizations.of(context);
                final source = item.source ?? widget.moduleKey;
                return ShelfCoverCard(
                  key: ValueKey<String>(
                    'unified-shelf-grid-item-${item.identityKey}',
                  ),
                  coverKey: item.identityKey,
                  identity: LibraryCoverIdentity.resolve(
                    moduleKey: source,
                    workId: item.workId,
                    coverAsset: item.coverAsset,
                  ),
                  title: LibraryShelfTextResolver.workTitle(
                    l10n,
                    source,
                    item.title,
                    item.workId,
                  ),
                  author: item.secondaryName,
                  coverImageUrl: item.coverImageUrl,
                  coverLocalPath: item.coverLocalPath,
                  customCoverLocalPath: item.customCoverLocalPath,
                  customCoverFocusX: item.customCoverFocusX,
                  customCoverFocusY: item.customCoverFocusY,
                  coverAsset: item.coverAsset,
                  imageReferer: widget.imageReferer,
                  coverLayerBuilder: widget.useShelfCoverImage
                      ? null
                      : _legacyCoverLayerBuilder,
                  onTap: () async => widget.onTapItem(item),
                  onLongPress: widget.selectionEnabled
                      ? () async => widget.onLongPressItem(item.identityKey)
                      : null,
                  topLeftBadge: widget.showUnreadBadge
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
                  selected: widget.selectedWorkIds.contains(item.identityKey),
                );
              },
            ),
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
      fadeInDuration: ForumMediaLoadingStyle.fadeInDuration,
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

class _WorkList extends StatefulWidget {
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
  final Future<void> Function(LibraryWorkItem item) onTapItem;
  final Future<void> Function(String workId) onLongPressItem;
  final bool selectionEnabled;
  final Set<String> selectedWorkIds;

  @override
  State<_WorkList> createState() => _WorkListState();
}

class _WorkListState extends State<_WorkList> {
  /// 每个分类页各自持有控制器，滚动位置不跨分类共享。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: PageStorageKey<String>(
        'unified-shelf-list-storage-${widget.categoryId}',
      ),
      // 列表支持右划标记已读，不启用边缘点击；角标避让右缘最近阅读按钮。
      child: EInkScrollPager(
        controller: _scrollController,
        edgeTapAllowed: false,
        cornerPadding: EdgeInsets.only(
          right: 12,
          bottom: 88 + mainShellBottomScrollInset(context),
        ),
        child: ListView.separated(
          controller: _scrollController,
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
          itemCount: widget.items.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, thickness: .5),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final selected = widget.selectedWorkIds.contains(item.identityKey);
            final shelfPalette = const ShelfThemePaletteResolver().resolve(
              Theme.of(context),
            );
            final leading = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: _buildLeadingCover(context, item, widget.moduleKey),
              ),
            );
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
                    onTap: () async => widget.onTapItem(item),
                    onLongPress: widget.selectionEnabled
                        ? () async => widget.onLongPressItem(item.identityKey)
                        : null,
                    leading: leading,
                    title: Text(
                      LibraryShelfTextResolver.workTitle(
                        AppLocalizations.of(context),
                        item.source ?? widget.moduleKey,
                        item.title,
                        item.workId,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.source == null && !widget.showUnreadBadge
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
                              if (widget.showUnreadBadge)
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
      ),
    );
  }

  Widget _buildLeadingCover(
    BuildContext context,
    LibraryWorkItem item,
    LibraryModuleKey moduleKey,
  ) {
    final source = item.source ?? moduleKey;
    final hasCover = LibraryCoverSources.hasAny(
      asset: item.coverAsset,
      customLocalPath: item.customCoverLocalPath,
      customImageUrl: item.customCoverImageUrl,
      coverLocalPath: item.coverLocalPath,
      coverImageUrl: item.coverImageUrl,
    );
    if (!hasCover) {
      return TypographicLibraryCover(
        identity: LibraryCoverIdentity.resolve(
          moduleKey: source,
          workId: item.workId,
          coverAsset: item.coverAsset,
        ),
        title: LibraryShelfTextResolver.workTitle(
          AppLocalizations.of(context),
          source,
          item.title,
          item.workId,
        ),
        layout: LibraryCoverLayout.list,
      );
    }
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
    if (!widget.useShelfCoverImage) {
      return LibraryCachedImage(
        localPath: _preferredLocalPath(item),
        imageUrl: _preferredRemoteUrl(item),
        fit: BoxFit.cover,
        alignment: alignment,
        placeholder: placeholder,
        referer: widget.imageReferer,
        fadeInDuration: ForumMediaLoadingStyle.fadeInDuration,
      );
    }
    return ShelfCoverImage(
      coverKey: item.workId,
      coverAsset: item.coverAsset,
      localPath: _preferredLocalPath(item),
      remoteUrl: _preferredRemoteUrl(item),
      imageReferer: widget.imageReferer,
      fit: BoxFit.cover,
      alignment: alignment,
      placeholder: placeholder,
      failureColor: shelfPalette.coverPlaceholderBackground,
      compactFailure: true,
    );
  }

  bool _isShowingCustomCover(LibraryWorkItem item) {
    if (item.coverAsset?.kind == LibraryCoverAssetKind.custom) {
      return true;
    }
    final custom = item.customCoverLocalPath?.trim();
    return custom != null && custom.isNotEmpty;
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
      children: [SizedBox(height: 320, child: AppEmptyState(title: message))],
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
    final l10n = AppLocalizations.of(context);
    return AppGroupedSection(
      children: [
        if (showDownloaded)
          _TriStateLine(
            key: const ValueKey<String>('unified-shelf-filter-downloaded'),
            label: l10n.libraryShelfFilterDownloaded,
            value: filters.downloaded,
            onChanged: (v) => onChanged(filters.copyWith(downloaded: v)),
          ),
        if (showReadState) ...[
          _TriStateLine(
            key: const ValueKey<String>('unified-shelf-filter-unread'),
            label: l10n.libraryShelfFilterUnread,
            value: filters.unread,
            onChanged: (v) => onChanged(filters.copyWith(unread: v)),
          ),
          _TriStateLine(
            key: const ValueKey<String>('unified-shelf-filter-read'),
            label: l10n.libraryShelfFilterRead,
            value: filters.read,
            onChanged: (v) => onChanged(filters.copyWith(read: v)),
          ),
        ],
        if (showBookmarked)
          _TriStateLine(
            key: const ValueKey<String>('unified-shelf-filter-bookmarked'),
            label: l10n.libraryShelfFilterBookmarked,
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
    final l10n = AppLocalizations.of(context);
    return AppGroupedSection(
      children: [
        for (final field in availableFields)
          AppGroupedRow(
            key: ValueKey<String>('unified-shelf-sort-${field.name}'),
            title: LibraryShelfTextResolver.sortField(l10n, field),
            selected: field == sortOption.field,
            trailing: field == sortOption.field
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sortOption.direction == LibrarySortDirection.asc
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.check, size: 18),
                    ],
                  )
                : null,
            onTap: () {
              final selected = field == sortOption.field;
              final nextDirection =
                  selected && sortOption.direction == LibrarySortDirection.desc
                  ? LibrarySortDirection.asc
                  : LibrarySortDirection.desc;
              onChanged(
                LibraryShelfSortOption(field: field, direction: nextDirection),
              );
            },
          ),
      ],
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
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppGroupedSection(
          children: [
            AppGroupedRow(
              key: const ValueKey<String>('unified-shelf-display-grid'),
              leading: const Icon(Icons.grid_view),
              title: l10n.libraryShelfGrid,
              selected: displayMode == LibraryDisplayMode.grid,
              trailing: displayMode == LibraryDisplayMode.grid
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () => onDisplayModeChanged(LibraryDisplayMode.grid),
            ),
            AppGroupedRow(
              key: const ValueKey<String>('unified-shelf-display-list'),
              leading: const Icon(Icons.view_list),
              title: l10n.libraryShelfList,
              selected: displayMode == LibraryDisplayMode.list,
              trailing: displayMode == LibraryDisplayMode.list
                  ? const Icon(Icons.check, size: 20)
                  : null,
              onTap: () => onDisplayModeChanged(LibraryDisplayMode.list),
            ),
          ],
        ),
        if (displayMode == LibraryDisplayMode.grid)
          AppGroupedSection(
            children: [
              AppGroupedRow(
                title: l10n.libraryShelfColumnsPerRow,
                semanticsValue: '${gridColumns.round()}',
                trailing: Text(
                  '${gridColumns.round()}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Slider(
                  key: const Key('unified-shelf-grid-columns-slider'),
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
      ],
    );
  }
}

class _TriStateLine extends StatelessWidget {
  const _TriStateLine({
    super.key,
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
    return AppGroupedRow(
      leading: Icon(icon),
      title: label,
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

enum _ShelfPanelTab { filter, sort, display }

/// 与阅读器显示面板同构的书架筛选／排序／显示面板：
/// 顶部使用 `prism.SegmentedControl`、单行配置摘要与定高 `IndexedStack`。
class _UnifiedShelfFilterPanel extends StatefulWidget {
  const _UnifiedShelfFilterPanel({
    required this.initialFilters,
    required this.initialSortOption,
    required this.initialDisplayMode,
    required this.initialGridColumns,
    required this.showDownloaded,
    required this.showReadState,
    required this.showBookmarked,
    required this.availableSortFields,
    required this.onCancel,
    required this.onApply,
  });

  final LibraryFilterSet initialFilters;
  final LibraryShelfSortOption initialSortOption;
  final LibraryDisplayMode initialDisplayMode;
  final double initialGridColumns;
  final bool showDownloaded;
  final bool showReadState;
  final bool showBookmarked;
  final List<LibraryShelfSortField> availableSortFields;
  final VoidCallback onCancel;
  final void Function(
    LibraryFilterSet filters,
    LibraryShelfSortOption sortOption,
    LibraryDisplayMode displayMode,
    int gridColumnCount,
  )
  onApply;

  @override
  State<_UnifiedShelfFilterPanel> createState() =>
      _UnifiedShelfFilterPanelState();
}

class _UnifiedShelfFilterPanelState extends State<_UnifiedShelfFilterPanel> {
  _ShelfPanelTab _tab = _ShelfPanelTab.filter;
  late LibraryFilterSet _filters;
  late LibraryShelfSortOption _sortOption;
  late LibraryDisplayMode _displayMode;
  late double _gridColumns;
  late final Map<_ShelfPanelTab, ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _sortOption = widget.initialSortOption;
    _displayMode = widget.initialDisplayMode;
    _gridColumns = widget.initialGridColumns;
    _scrollControllers = {
      for (final tab in _ShelfPanelTab.values) tab: ScrollController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _summaryText(AppLocalizations l10n) {
    final activeFilters = [
      if (widget.showDownloaded) _filters.downloaded,
      if (widget.showReadState) _filters.unread,
      if (widget.showReadState) _filters.read,
      if (widget.showBookmarked) _filters.bookmarked,
    ].where((value) => value != TriStateFilterValue.ignore).length;
    final filterPart = activeFilters == 0
        ? l10n.libraryShelfAllWorks
        : '${l10n.libraryShelfFilter} $activeFilters';
    final sortArrow = _sortOption.direction == LibrarySortDirection.asc
        ? '↑'
        : '↓';
    final sortPart =
        '${LibraryShelfTextResolver.sortField(l10n, _sortOption.field)} $sortArrow';
    final displayPart = _displayMode == LibraryDisplayMode.grid
        ? '${l10n.libraryShelfGrid} ${_gridColumns.round()}'
        : l10n.libraryShelfList;
    return '$filterPart · $sortPart · $displayPart';
  }

  Widget _buildTabContent(_ShelfPanelTab tab) {
    switch (tab) {
      case _ShelfPanelTab.filter:
        return _FilterTab(
          filters: _filters,
          showDownloaded: widget.showDownloaded,
          showReadState: widget.showReadState,
          showBookmarked: widget.showBookmarked,
          onChanged: (next) => setState(() => _filters = next),
        );
      case _ShelfPanelTab.sort:
        return _SortTab(
          sortOption: _sortOption,
          availableFields: widget.availableSortFields,
          onChanged: (next) => setState(() => _sortOption = next),
        );
      case _ShelfPanelTab.display:
        return _DisplayTab(
          displayMode: _displayMode,
          gridColumns: _gridColumns,
          onDisplayModeChanged: (mode) => setState(() => _displayMode = mode),
          onGridColumnsChanged: (columns) =>
              setState(() => _gridColumns = columns),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPrismTheme(
              child: prism.SegmentedControl<_ShelfPanelTab>(
                key: const Key('unified-shelf-panel-tabs'),
                segments: [
                  (_ShelfPanelTab.filter, l10n.libraryShelfFilter),
                  (_ShelfPanelTab.sort, l10n.libraryShelfSort),
                  (_ShelfPanelTab.display, l10n.libraryShelfDisplayMode),
                ],
                value: _tab,
                onChanged: (next) {
                  if (next == _tab) {
                    return;
                  }
                  final controller = _scrollControllers[next];
                  if (controller != null && controller.hasClients) {
                    controller.jumpTo(0);
                  }
                  setState(() => _tab = next);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                _summaryText(l10n),
                key: const Key('unified-shelf-panel-summary'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              // 用 IndexedStack 固定三栏最大高度，切换分段时外框不跳变。
              child: IndexedStack(
                index: _tab.index,
                alignment: AlignmentDirectional.topStart,
                children: [
                  for (final tab in _ShelfPanelTab.values)
                    ExcludeFocus(
                      key: ValueKey<_ShelfPanelTab>(tab),
                      excluding: tab != _tab,
                      child: SingleChildScrollView(
                        key: const Key('unified-shelf-panel-scroll'),
                        controller: _scrollControllers[tab],
                        child: _buildTabContent(tab),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ShelfPanelActions(
              onCancel: widget.onCancel,
              onApply: () => widget.onApply(
                _filters,
                _sortOption,
                _displayMode,
                _gridColumns.round(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 面板尾部动作：取消与确认都使用胶囊按钮，矮窗口下固定在滚动区之外。
class _ShelfPanelActions extends StatelessWidget {
  const _ShelfPanelActions({required this.onCancel, required this.onApply});

  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const buttonSize = Size(0, 48);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('unified-shelf-filter-cancel'),
            style: OutlinedButton.styleFrom(minimumSize: buttonSize),
            onPressed: onCancel,
            child: Text(l10n.commonCancel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            key: const Key('unified-shelf-filter-apply'),
            style: FilledButton.styleFrom(minimumSize: buttonSize),
            onPressed: onApply,
            child: Text(l10n.commonApply),
          ),
        ),
      ],
    );
  }
}

bool _sameLibraryFilters(LibraryFilterSet a, LibraryFilterSet b) {
  return a.downloaded == b.downloaded &&
      a.unread == b.unread &&
      a.read == b.read &&
      a.hasTags == b.hasTags &&
      a.bookmarked == b.bookmarked;
}
