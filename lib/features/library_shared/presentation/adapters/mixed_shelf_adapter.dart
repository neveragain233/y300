import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_query_utils.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';

/// 只做汇总与分派的混合书架适配器。
///
/// 分类由两个模块共享的同一张应用级分类表提供；作品仍带来源身份。打开、
/// 刷新、分类管理和批量动作都回到原模块适配器，不复制任何仓储逻辑。
class MixedShelfAdapter
    implements
        ShelfModuleAdapter,
        ShelfModuleCapabilitiesAdapter,
        ShelfSnapshotAdapter,
        ShelfSelectionActionAdapter,
        ShelfModuleActionAdapter,
        ShelfDownloadStatusAdapter {
  MixedShelfAdapter({
    required ShelfModuleAdapter comicAdapter,
    required ShelfModuleAdapter novelAdapter,
  }) : _comicAdapter = comicAdapter,
       _novelAdapter = novelAdapter;

  static const String allCategoryId = 'all';

  final ShelfModuleAdapter _comicAdapter;
  final ShelfModuleAdapter _novelAdapter;

  final Map<String, LibraryWorkItem> _itemsByIdentity =
      <String, LibraryWorkItem>{};

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.bookshelf;

  @override
  String? get initialCategoryId => allCategoryId;

  @override
  Set<LibraryModuleKey> get refreshModuleKeys => const <LibraryModuleKey>{
    LibraryModuleKey.comic,
    LibraryModuleKey.novel,
  };

  @override
  LibraryDisplayMode get defaultDisplayMode => LibraryDisplayMode.grid;

  @override
  ShelfModuleCapabilities get capabilities => const ShelfModuleCapabilities(
    supportsReadState: false,
    supportsBookmarkFilter: false,
    showsUnreadBadge: true,
  );

  late final ValueListenable<LibraryShelfRefreshSignal?>? _refreshSignals =
      _buildRefreshSignals();

  @override
  ValueListenable<LibraryShelfRefreshSignal?>? get shelfRefreshSignals =>
      _refreshSignals;

  ValueListenable<LibraryShelfRefreshSignal?>? _buildRefreshSignals() {
    final comic = _comicAdapter.shelfRefreshSignals;
    final novel = _novelAdapter.shelfRefreshSignals;
    if (identical(comic, novel)) {
      return comic;
    }
    if (comic == null || novel == null) {
      return comic ?? novel;
    }
    return _MergedRefreshSignals(comic: comic, novel: novel);
  }

  @override
  ValueListenable<LibraryShelfTaskProgress?>? get taskProgress {
    return _comicAdapter.taskProgress ?? _novelAdapter.taskProgress;
  }

  @override
  List<LibraryShelfMenuAction> get menuActions {
    final adapter = _comicAdapter;
    return adapter is ShelfModuleActionAdapter
        ? (adapter as ShelfModuleActionAdapter).menuActions
        : const <LibraryShelfMenuAction>[];
  }

  @override
  Future<ShelfModuleActionOutcome> runMenuAction(
    LibraryShelfMenuAction action,
  ) {
    final adapter = _comicAdapter;
    if (adapter is ShelfModuleActionAdapter) {
      return (adapter as ShelfModuleActionAdapter).runMenuAction(action);
    }
    return Future<ShelfModuleActionOutcome>.value(
      const ShelfModuleActionOutcome(
        code: ShelfModuleActionOutcomeCode.unsupported,
      ),
    );
  }

  @override
  List<SelectionAction> get selectionActions {
    final actions = <SelectionAction>[];
    final ids = <String>{};
    for (final adapter in <ShelfModuleAdapter>[_comicAdapter, _novelAdapter]) {
      if (adapter is! ShelfSelectionActionAdapter) {
        continue;
      }
      for (final action
          in (adapter as ShelfSelectionActionAdapter).selectionActions) {
        if (ids.add(action.id)) {
          actions.add(action);
        }
      }
    }
    return List<SelectionAction>.unmodifiable(actions);
  }

  @override
  Future<List<LibraryCategory>> loadCategories() async {
    final comic = await _comicAdapter.loadCategories();
    final novel = await _novelAdapter.loadCategories();
    final merged = <String, LibraryCategory>{};
    for (final category in <LibraryCategory>[...comic, ...novel]) {
      merged.putIfAbsent(category.categoryId, () => category);
    }
    final categories = merged.values.toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List<LibraryCategory>.unmodifiable(<LibraryCategory>[
      LibraryCategory(
        categoryId: allCategoryId,
        name: '',
        sortOrder: -1,
        createdAt: _epoch,
        source: LibraryModuleKey.bookshelf,
        sourceCategoryId: allCategoryId,
      ),
      ...categories,
    ]);
  }

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems({
    required String categoryId,
  }) async {
    if (categoryId == allCategoryId) {
      final snapshots = await Future.wait(<Future<LibraryShelfSnapshot>>[
        _childSnapshot(_comicAdapter, keyword: ''),
        _childSnapshot(_novelAdapter, keyword: ''),
      ]);
      return _allItems(snapshots);
    }
    final results = await Future.wait(<Future<List<LibraryWorkItem>>>[
      _comicAdapter.loadCategoryItems(categoryId: categoryId),
      _novelAdapter.loadCategoryItems(categoryId: categoryId),
    ]);
    return _decorateAll(results[0], LibraryModuleKey.comic, categoryId) +
        _decorateAll(results[1], LibraryModuleKey.novel, categoryId);
  }

  @override
  Future<Map<String, List<LibraryWorkItem>>> searchItemsByKeyword({
    required String keyword,
  }) async {
    final snapshot = await querySnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: keyword,
    );
    return snapshot.itemsByCategory;
  }

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    final snapshot = await querySnapshot(
      filters: filters,
      sortOption: sortOption,
      keyword: keyword,
    );
    return snapshot.itemsByCategory;
  }

  @override
  Future<LibraryShelfSnapshot> querySnapshot({
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    final snapshots = await Future.wait(<Future<LibraryShelfSnapshot>>[
      _childSnapshot(_comicAdapter, keyword: ''),
      _childSnapshot(_novelAdapter, keyword: ''),
    ]);
    _itemsByIdentity.clear();
    final categories = await loadCategories();
    final source = <String, List<LibraryWorkItem>>{
      for (final category in categories)
        category.categoryId: <LibraryWorkItem>[],
    };
    final all = <String, LibraryWorkItem>{};
    for (final (index, snapshot) in snapshots.indexed) {
      final sourceKey = index == 0
          ? LibraryModuleKey.comic
          : LibraryModuleKey.novel;
      for (final category in snapshot.categories) {
        final rawItems =
            snapshot.itemsByCategory[category.categoryId] ??
            const <LibraryWorkItem>[];
        for (final item in rawItems) {
          final decorated = _decorate(item, sourceKey);
          source
              .putIfAbsent(category.categoryId, () => <LibraryWorkItem>[])
              .add(decorated);
          all.putIfAbsent(decorated.identityKey, () => decorated);
        }
      }
    }
    source[allCategoryId] = all.values.toList(growable: false);

    final queried = LibraryShelfQueryUtils.filterAndSortByCategory(
      source: source,
      filters: filters,
      sortOption: sortOption,
      keyword: keyword,
    );
    return LibraryShelfSnapshot(
      categories: categories,
      itemsByCategory: queried,
      visibleMatchCountByCategory: LibraryShelfQueryUtils.countByCategory(
        queried,
      ),
    );
  }

  @override
  Future<void> refreshShelf() async {
    await Future.wait(<Future<void>>[
      _comicAdapter.refreshShelf(),
      _novelAdapter.refreshShelf(),
    ]);
  }

  @override
  Future<Object> buildDetailRouteArgument({required String workId}) {
    throw UnsupportedError('mixedShelfDetailRoute');
  }

  @override
  Future<String> createCategory({required String name}) {
    return _comicAdapter.createCategory(name: name);
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) {
    return _comicAdapter.renameCategory(
      categoryId: categoryId,
      newName: newName,
    );
  }

  @override
  Future<void> deleteCategory({required String categoryId}) {
    return _comicAdapter.deleteCategory(categoryId: categoryId);
  }

  @override
  Future<void> moveWorkToCategory({
    required String workId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    final work = LibraryWorkId.tryParse(workId);
    if (work == null) {
      throw UnsupportedError('mixedShelfMoveWork');
    }
    final current = _itemsByIdentity[work.encoded]?.categoryId;
    await _adapterFor(work.source).moveWorkToCategory(
      workId: work.workId,
      fromCategoryId: current ?? fromCategoryId,
      toCategoryId: toCategoryId,
    );
  }

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async {
    final items = await loadCategoryItems(categoryId: categoryId);
    if (items.isEmpty) {
      return null;
    }
    return items[Random().nextInt(items.length)].identityKey;
  }

  @override
  Future<SelectionActionOutcome> runSelectionAction(
    SelectionActionExecutionRequest request,
  ) async {
    final groups = <LibraryModuleKey, List<String>>{};
    var invalidCount = 0;
    for (final workKey in request.workIds) {
      final parsed = LibraryWorkId.tryParse(workKey);
      if (parsed == null ||
          (parsed.source != LibraryModuleKey.comic &&
              parsed.source != LibraryModuleKey.novel)) {
        invalidCount += 1;
        continue;
      }
      groups.putIfAbsent(parsed.source, () => <String>[]).add(parsed.workId);
    }
    if (groups.isEmpty) {
      return SelectionActionOutcome(
        code: SelectionActionOutcomeCode.noValidItems,
        failedCount: invalidCount,
      );
    }
    if (request.actionId == SelectionActionIds.assignCategory &&
        (request.targetCategoryId?.trim().isEmpty ?? true)) {
      return const SelectionActionOutcome(
        code: SelectionActionOutcomeCode.missingTargetCategory,
      );
    }
    var succeeded = 0;
    var failed = invalidCount;
    var enqueued = 0;
    var deduplicated = 0;
    var changed = false;
    var supported = false;
    for (final entry in groups.entries) {
      final adapter = _adapterFor(entry.key);
      if (adapter is! ShelfSelectionActionAdapter) {
        failed += entry.value.length;
        continue;
      }
      final selectionAdapter = adapter as ShelfSelectionActionAdapter;
      supported = true;
      final byCurrentCategory = <String, List<String>>{};
      for (final workId in entry.value) {
        final workKey = LibraryWorkId(
          source: entry.key,
          workId: workId,
        ).encoded;
        final current = _itemsByIdentity[workKey]?.categoryId ?? 'default';
        byCurrentCategory.putIfAbsent(current, () => <String>[]).add(workId);
      }
      for (final category in byCurrentCategory.entries) {
        final outcome = await selectionAdapter.runSelectionAction(
          SelectionActionExecutionRequest(
            actionId: request.actionId,
            workIds: category.value.toSet(),
            activeCategoryId: category.key,
            targetCategoryId: request.targetCategoryId,
          ),
        );
        if (outcome.code == SelectionActionOutcomeCode.unsupported ||
            outcome.code == SelectionActionOutcomeCode.noValidItems) {
          failed += category.value.length;
          continue;
        }
        succeeded += outcome.succeededCount;
        failed += outcome.failedCount;
        enqueued += outcome.enqueuedCount;
        deduplicated += outcome.deduplicatedCount;
        changed = changed || outcome.changed;
      }
    }
    if (!supported) {
      return SelectionActionOutcome(
        code: SelectionActionOutcomeCode.unsupported,
        failedCount: failed,
      );
    }
    return SelectionActionOutcome(
      code: failed > 0
          ? SelectionActionOutcomeCode.partialFailure
          : SelectionActionOutcomeCode.success,
      changed: changed,
      succeededCount: succeeded,
      failedCount: failed,
      enqueuedCount: enqueued,
      deduplicatedCount: deduplicated,
    );
  }

  ShelfModuleAdapter _adapterFor(LibraryModuleKey source) {
    return source == LibraryModuleKey.novel ? _novelAdapter : _comicAdapter;
  }

  List<LibraryWorkItem> _allItems(List<LibraryShelfSnapshot> snapshots) {
    final items = <String, LibraryWorkItem>{};
    for (final (index, snapshot) in snapshots.indexed) {
      final sourceKey = index == 0
          ? LibraryModuleKey.comic
          : LibraryModuleKey.novel;
      for (final category in snapshot.categories) {
        for (final item
            in snapshot.itemsByCategory[category.categoryId] ??
                const <LibraryWorkItem>[]) {
          final decorated = _decorate(item, sourceKey);
          items[decorated.identityKey] = decorated;
        }
      }
    }
    return List<LibraryWorkItem>.unmodifiable(items.values);
  }

  List<LibraryWorkItem> _decorateAll(
    List<LibraryWorkItem> items,
    LibraryModuleKey source,
    String categoryId,
  ) {
    return <LibraryWorkItem>[
      for (final item in items)
        _decorate(item.copyWith(categoryId: categoryId), source),
    ];
  }

  LibraryWorkItem _decorate(LibraryWorkItem item, LibraryModuleKey source) {
    final decorated = item.copyWith(source: source);
    _itemsByIdentity[decorated.identityKey] = decorated;
    return decorated;
  }

  Future<LibraryShelfSnapshot> _childSnapshot(
    ShelfModuleAdapter adapter, {
    required String keyword,
  }) async {
    if (adapter is ShelfSnapshotAdapter) {
      final capabilities = resolveShelfModuleCapabilities(adapter);
      return (adapter as ShelfSnapshotAdapter).querySnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: capabilities.defaultSortOption,
        keyword: keyword,
      );
    }
    final categories = await adapter.loadCategories();
    final queried = await adapter.queryItems(
      categories: categories,
      filters: LibraryFilterSet.defaults,
      sortOption: resolveShelfModuleCapabilities(adapter).defaultSortOption,
      keyword: keyword,
    );
    return LibraryShelfSnapshot(
      categories: categories,
      itemsByCategory: queried,
      visibleMatchCountByCategory: <String, int>{
        for (final category in categories)
          category.categoryId:
              (queried[category.categoryId] ?? const <LibraryWorkItem>[])
                  .length,
      },
    );
  }

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}

/// 把一个子适配器的单个刷新流合并成混合书架可监听的值。
class _MergedRefreshSignals extends ValueNotifier<LibraryShelfRefreshSignal?>
    implements ValueListenable<LibraryShelfRefreshSignal?> {
  _MergedRefreshSignals({required this.comic, required this.novel})
    : super(_latest(comic?.value, novel?.value)) {
    comic?.addListener(_handleChanged);
    novel?.addListener(_handleChanged);
  }

  final ValueListenable<LibraryShelfRefreshSignal?>? comic;
  final ValueListenable<LibraryShelfRefreshSignal?>? novel;

  void _handleChanged() {
    final next = _latest(comic?.value, novel?.value);
    if (identical(next, value) || next?.sequence == value?.sequence) {
      return;
    }
    value = next;
  }

  static LibraryShelfRefreshSignal? _latest(
    LibraryShelfRefreshSignal? first,
    LibraryShelfRefreshSignal? second,
  ) {
    if (first == null) {
      return second;
    }
    if (second == null) {
      return first;
    }
    return first.sequence >= second.sequence ? first : second;
  }

  @override
  void dispose() {
    comic?.removeListener(_handleChanged);
    novel?.removeListener(_handleChanged);
    super.dispose();
  }
}
