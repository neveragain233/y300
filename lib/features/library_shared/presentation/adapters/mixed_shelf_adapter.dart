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
/// 分类和作品都带来源身份：分类键在混合页是 `来源:原始分类键`，作品键是
/// `来源:原始作品编号`。打开、刷新、分类管理和批量动作都回到原模块适配器，
/// 不复制漫画／小说的仓储、下载或阅读状态逻辑。
class MixedShelfAdapter
    implements
        ShelfModuleAdapter,
        ShelfModuleCapabilitiesAdapter,
        ShelfSnapshotAdapter,
        ShelfSelectionActionAdapter,
        ShelfModuleActionAdapter,
        ShelfDownloadStatusAdapter,
        ShelfCategorySourceAdapter {
  MixedShelfAdapter({
    required ShelfModuleAdapter comicAdapter,
    required ShelfModuleAdapter novelAdapter,
  }) : _comicAdapter = comicAdapter,
       _novelAdapter = novelAdapter;

  static const String allCategoryId = 'default';

  final ShelfModuleAdapter _comicAdapter;
  final ShelfModuleAdapter _novelAdapter;

  final Map<String, LibraryCategory> _categoriesByKey =
      <String, LibraryCategory>{};
  final Map<String, String> _rawCategoryByKey = <String, String>{};
  final Map<String, LibraryModuleKey> _sourceByCategoryKey =
      <String, LibraryModuleKey>{};
  final Map<String, String> _sourceCategoryKeyByWorkKey = <String, String>{};

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.bookshelf;

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

  @override
  ValueListenable<LibraryShelfTaskProgress?>? get taskProgress {
    return _comicAdapter.taskProgress ?? _novelAdapter.taskProgress;
  }

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
    if (adapter is! ShelfModuleActionAdapter) {
      return Future<ShelfModuleActionOutcome>.value(
        const ShelfModuleActionOutcome(
          code: ShelfModuleActionOutcomeCode.unsupported,
        ),
      );
    }
    return (adapter as ShelfModuleActionAdapter).runMenuAction(action);
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
    return _buildCategories(
      _ShelfChild(moduleKey: LibraryModuleKey.comic, categories: comic),
      _ShelfChild(moduleKey: LibraryModuleKey.novel, categories: novel),
    );
  }

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems({
    required String categoryId,
  }) async {
    if (categoryId == allCategoryId) {
      final snapshots = await Future.wait(<Future<LibraryShelfSnapshot>>[
        _childSnapshot(_comicAdapter),
        _childSnapshot(_novelAdapter),
      ]);
      return _allItems(snapshots);
    }
    final resolved = _resolveCategory(categoryId);
    if (resolved == null) {
      return const <LibraryWorkItem>[];
    }
    final adapter = _adapterFor(resolved.source);
    final items = await adapter.loadCategoryItems(
      categoryId: resolved.rawCategoryId,
    );
    return List<LibraryWorkItem>.unmodifiable(
      items.map(
        (item) => _decorate(
          item,
          source: resolved.source,
          rawCategoryId: resolved.rawCategoryId,
        ),
      ),
    );
  }

  @override
  Future<Map<String, List<LibraryWorkItem>>> searchItemsByKeyword({
    required String keyword,
  }) async {
    final snapshots = await Future.wait(<Future<LibraryShelfSnapshot>>[
      _childSnapshot(_comicAdapter, keyword: keyword),
      _childSnapshot(_novelAdapter, keyword: keyword),
    ]);
    final result = <String, List<LibraryWorkItem>>{};
    _collectChildItems(
      snapshot: snapshots[0],
      source: LibraryModuleKey.comic,
      target: result,
    );
    _collectChildItems(
      snapshot: snapshots[1],
      source: LibraryModuleKey.novel,
      target: result,
    );
    result[allCategoryId] = _allItems(snapshots);
    return result;
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
      _childSnapshot(_comicAdapter),
      _childSnapshot(_novelAdapter),
    ]);
    _categoriesByKey.clear();
    _rawCategoryByKey.clear();
    _sourceByCategoryKey.clear();
    _sourceCategoryKeyByWorkKey.clear();

    final comic = _ShelfChild(
      moduleKey: LibraryModuleKey.comic,
      categories: snapshots[0].categories,
    );
    final novel = _ShelfChild(
      moduleKey: LibraryModuleKey.novel,
      categories: snapshots[1].categories,
    );
    final categories = _buildCategories(comic, novel);
    final source = <String, List<LibraryWorkItem>>{
      for (final category in categories)
        category.categoryId: <LibraryWorkItem>[],
    };
    _collectChildItems(
      snapshot: snapshots[0],
      source: LibraryModuleKey.comic,
      target: source,
    );
    _collectChildItems(
      snapshot: snapshots[1],
      source: LibraryModuleKey.novel,
      target: source,
    );
    source[allCategoryId] = _allItems(snapshots);

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
    throw UnsupportedError('mixedShelfCreateCategory');
  }

  @override
  Future<String> createCategoryInSource({
    required String sourceCategoryId,
    required String name,
  }) async {
    final resolved = _resolveCategory(sourceCategoryId);
    if (resolved == null) {
      throw UnsupportedError('mixedShelfCreateCategory');
    }
    final categoryId = await _adapterFor(resolved.source)
        .createCategory(name: name);
    final key = _categoryKey(resolved.source, categoryId);
    _rawCategoryByKey[key] = categoryId;
    _sourceByCategoryKey[key] = resolved.source;
    return key;
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {
    final resolved = _resolveCategory(categoryId);
    if (resolved == null || resolved.rawCategoryId == allCategoryId) {
      throw UnsupportedError('mixedShelfRenameCategory');
    }
    await _adapterFor(resolved.source)
        .renameCategory(categoryId: resolved.rawCategoryId, newName: newName);
  }

  @override
  Future<void> deleteCategory({required String categoryId}) async {
    final resolved = _resolveCategory(categoryId);
    if (resolved == null || resolved.rawCategoryId == allCategoryId) {
      throw UnsupportedError('mixedShelfDeleteCategory');
    }
    await _adapterFor(resolved.source)
        .deleteCategory(categoryId: resolved.rawCategoryId);
  }

  @override
  Future<void> moveWorkToCategory({
    required String workId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    final work = LibraryWorkId.tryParse(workId);
    final target = _resolveTargetForSource(toCategoryId, work?.source);
    if (work == null || target == null) {
      throw UnsupportedError('mixedShelfMoveWork');
    }
    final fromCategory =
        _sourceCategoryKeyByWorkKey[work.encoded] ??
        _categoryKey(work.source, allCategoryId);
    final from = _resolveCategory(fromCategory);
    if (from == null) {
      throw UnsupportedError('mixedShelfMoveWork');
    }
    await _adapterFor(work.source).moveWorkToCategory(
      workId: work.workId,
      fromCategoryId: from.rawCategoryId,
      toCategoryId: target.rawCategoryId,
    );
  }

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async {
    if (categoryId != allCategoryId) {
      final resolved = _resolveCategory(categoryId);
      if (resolved == null) {
        return null;
      }
      final workId = await _adapterFor(resolved.source)
          .pickRandomWorkId(categoryId: resolved.rawCategoryId);
      if (workId == null) {
        return null;
      }
      return LibraryWorkId(source: resolved.source, workId: workId).encoded;
    }
    final items = await loadCategoryItems(categoryId: allCategoryId);
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
      final requests = _requestsFor(
        actionId: request.actionId,
        workIds: entry.value,
        source: entry.key,
        targetCategoryId: request.targetCategoryId,
      );
      if (requests.isEmpty) {
        failed += entry.value.length;
        continue;
      }
      supported = true;
      final selectionAdapter = adapter as ShelfSelectionActionAdapter;
      for (final childRequest in requests) {
        final outcome = await selectionAdapter.runSelectionAction(childRequest);
        if (outcome.code == SelectionActionOutcomeCode.unsupported ||
            outcome.code == SelectionActionOutcomeCode.noValidItems) {
          failed += childRequest.workIds.length;
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

  List<SelectionActionExecutionRequest> _requestsFor({
    required String actionId,
    required List<String> workIds,
    required LibraryModuleKey source,
    required String? targetCategoryId,
  }) {
    final target = _resolveTargetForSource(targetCategoryId, source);
    if (actionId == SelectionActionIds.assignCategory && target == null) {
      return const <SelectionActionExecutionRequest>[];
    }
    final byCategory = <String, List<String>>{};
    for (final workId in workIds) {
      final workKey = LibraryWorkId(source: source, workId: workId).encoded;
      final categoryKey =
          _sourceCategoryKeyByWorkKey[workKey] ??
          _categoryKey(source, allCategoryId);
      final resolved = _resolveCategory(categoryKey);
      final rawCategoryId = resolved?.rawCategoryId ?? allCategoryId;
      byCategory.putIfAbsent(rawCategoryId, () => <String>[]).add(workId);
    }
    return <SelectionActionExecutionRequest>[
      for (final entry in byCategory.entries)
        SelectionActionExecutionRequest(
          actionId: actionId,
          workIds: entry.value.toSet(),
          activeCategoryId: entry.key,
          targetCategoryId: target?.rawCategoryId,
        ),
    ];
  }

  _ResolvedCategory? _resolveCategory(String categoryKey) {
    if (categoryKey == allCategoryId) {
      return null;
    }
    final source = _sourceByCategoryKey[categoryKey];
    final rawCategoryId = _rawCategoryByKey[categoryKey];
    if (source == null || rawCategoryId == null) {
      return null;
    }
    return _ResolvedCategory(
      source: source,
      rawCategoryId: rawCategoryId,
      key: categoryKey,
    );
  }

  _ResolvedCategory? _resolveTargetForSource(
    String? categoryKey,
    LibraryModuleKey? source,
  ) {
    if (source == null) {
      return null;
    }
    if (categoryKey == null ||
        categoryKey.isEmpty ||
        categoryKey == allCategoryId) {
      return _ResolvedCategory(
        source: source,
        rawCategoryId: allCategoryId,
        key: _categoryKey(source, allCategoryId),
      );
    }
    final resolved = _resolveCategory(categoryKey);
    if (resolved == null || resolved.source != source) {
      return null;
    }
    return resolved;
  }

  ShelfModuleAdapter _adapterFor(LibraryModuleKey source) {
    return source == LibraryModuleKey.novel ? _novelAdapter : _comicAdapter;
  }

  LibraryCategory? _categoryFor(
    LibraryModuleKey source,
    LibraryCategory category,
  ) {
    final key = _categoryKey(source, category.categoryId);
    _rawCategoryByKey[key] = category.categoryId;
    _sourceByCategoryKey[key] = source;
    final mapped = LibraryCategory(
      categoryId: key,
      name: category.name,
      sortOrder:
          (source == LibraryModuleKey.novel ? 1000 : 0) + category.sortOrder,
      createdAt: category.createdAt,
      visibleMatchCount: category.visibleMatchCount,
      source: source,
      sourceCategoryId: category.categoryId,
    );
    _categoriesByKey[key] = mapped;
    return mapped;
  }

  List<LibraryCategory> _buildCategories(_ShelfChild comic, _ShelfChild novel) {
    final categories = <LibraryCategory>[
      LibraryCategory(
        categoryId: allCategoryId,
        name: '',
        sortOrder: -1000,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        source: LibraryModuleKey.bookshelf,
        sourceCategoryId: allCategoryId,
      ),
    ];
    for (final child in <_ShelfChild>[comic, novel]) {
      for (final category in child.categories) {
        final mapped = _categoryFor(child.moduleKey, category);
        if (mapped != null) {
          categories.add(mapped);
        }
      }
    }
    return List<LibraryCategory>.unmodifiable(categories);
  }

  void _collectChildItems({
    required LibraryShelfSnapshot snapshot,
    required LibraryModuleKey source,
    required Map<String, List<LibraryWorkItem>> target,
  }) {
    for (final category in snapshot.categories) {
      final key = _categoryKey(source, category.categoryId);
      target
          .putIfAbsent(key, () => <LibraryWorkItem>[])
          .addAll(
            (snapshot.itemsByCategory[category.categoryId] ??
                    const <LibraryWorkItem>[])
                .map(
                  (item) => _decorate(
                    item,
                    source: source,
                    rawCategoryId: category.categoryId,
                  ),
                ),
          );
    }
  }

  List<LibraryWorkItem> _allItems(List<LibraryShelfSnapshot> snapshots) {
    final items = <String, LibraryWorkItem>{};
    for (final (index, snapshot) in snapshots.indexed) {
      final source = index == 0
          ? LibraryModuleKey.comic
          : LibraryModuleKey.novel;
      for (final category in snapshot.categories) {
        for (final item
            in snapshot.itemsByCategory[category.categoryId] ??
                const <LibraryWorkItem>[]) {
          final decorated = _decorate(
            item,
            source: source,
            rawCategoryId: category.categoryId,
          );
          items[decorated.identityKey] = decorated;
        }
      }
    }
    return List<LibraryWorkItem>.unmodifiable(items.values);
  }

  LibraryWorkItem _decorate(
    LibraryWorkItem item, {
    required LibraryModuleKey source,
    required String rawCategoryId,
  }) {
    final categoryKey = _categoryKey(source, rawCategoryId);
    _sourceCategoryKeyByWorkKey[LibraryWorkId(
          source: source,
          workId: item.workId,
        ).encoded] =
        categoryKey;
    return item.copyWith(categoryId: categoryKey, source: source);
  }

  Future<LibraryShelfSnapshot> _childSnapshot(
    ShelfModuleAdapter adapter, {
    String keyword = '',
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

  String _categoryKey(LibraryModuleKey source, String rawCategoryId) {
    return '${source.name}:$rawCategoryId';
  }
}

class _ShelfChild {
  const _ShelfChild({required this.moduleKey, required this.categories});

  final LibraryModuleKey moduleKey;
  final List<LibraryCategory> categories;
}

class _ResolvedCategory {
  const _ResolvedCategory({
    required this.source,
    required this.rawCategoryId,
    required this.key,
  });

  final LibraryModuleKey source;
  final String rawCategoryId;
  final String key;
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
    _notifyLatest();
  }

  void _notifyLatest() {
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
