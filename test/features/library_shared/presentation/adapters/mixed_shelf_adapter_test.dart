import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/presentation/adapters/mixed_shelf_adapter.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

void main() {
  late _FakeChildAdapter comic;
  late _FakeChildAdapter novel;
  late MixedShelfAdapter adapter;

  setUp(() {
    comic = _FakeChildAdapter(
      moduleKey: LibraryModuleKey.comic,
      categories: <LibraryCategory>[
        LibraryCategory(
          categoryId: 'default',
          name: '默认',
          sortOrder: 0,
          createdAt: _epoch,
        ),
        LibraryCategory(
          categoryId: 'c1',
          name: '追更',
          sortOrder: 1,
          createdAt: _epoch,
        ),
      ],
      itemsByCategory: <String, List<LibraryWorkItem>>{
        'default': <LibraryWorkItem>[
          _item(workId: 'yamibo:1', categoryId: 'default', unreadCount: 2),
        ],
        'c1': <LibraryWorkItem>[
          _item(workId: 'yamibo:2', categoryId: 'c1', unreadCount: 0),
        ],
      },
      displayMode: LibraryDisplayMode.grid,
    );
    novel = _FakeChildAdapter(
      moduleKey: LibraryModuleKey.novel,
      categories: <LibraryCategory>[
        LibraryCategory(
          categoryId: 'default',
          name: '默认',
          sortOrder: 0,
          createdAt: _epoch,
        ),
        LibraryCategory(
          categoryId: 'n1',
          name: '追更',
          sortOrder: 1,
          createdAt: _epoch,
        ),
      ],
      itemsByCategory: <String, List<LibraryWorkItem>>{
        'default': <LibraryWorkItem>[
          _item(workId: 'yamibo:1', categoryId: 'default', unreadCount: 0),
        ],
        'n1': <LibraryWorkItem>[
          _item(workId: 'novel:49:9', categoryId: 'n1', unreadCount: 0),
        ],
      },
      displayMode: LibraryDisplayMode.list,
    );
    adapter = MixedShelfAdapter(comicAdapter: comic, novelAdapter: novel);
  });

  test(
    'snapshot keeps same raw work ids apart and labels categories by source',
    () async {
      final snapshot = await adapter.querySnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: LibraryShelfSortOption.defaults,
        keyword: '',
      );

      final categoryIds = snapshot.categories
          .map((category) => category.categoryId)
          .toList(growable: false);
      expect(categoryIds, <String>[
        'default',
        'comic:default',
        'comic:c1',
        'novel:default',
        'novel:n1',
      ]);

      final allItems = snapshot.itemsByCategory['default']!;
      expect(allItems, hasLength(4));
      expect(allItems.map((item) => item.identityKey).toSet(), <String>{
        'comic:yamibo:1',
        'comic:yamibo:2',
        'novel:yamibo:1',
        'novel:novel:49:9',
      });
      expect(
        snapshot.itemsByCategory['comic:default']!.single.identityKey,
        'comic:yamibo:1',
      );
      expect(
        snapshot.itemsByCategory['novel:default']!.single.identityKey,
        'novel:yamibo:1',
      );
      expect(
        snapshot.itemsByCategory['comic:c1']!.single.identityKey,
        'comic:yamibo:2',
      );
      expect(
        snapshot.itemsByCategory['novel:n1']!.single.identityKey,
        'novel:novel:49:9',
      );
      expect(
        snapshot.categories
            .firstWhere((category) => category.categoryId == 'default')
            .source,
        LibraryModuleKey.bookshelf,
      );
      expect(
        snapshot.categories
            .firstWhere((category) => category.categoryId == 'comic:default')
            .isDefault,
        isTrue,
      );
    },
  );

  test('keyword and sort apply once on the combined snapshot', () async {
    final snapshot = await adapter.querySnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: const LibraryShelfSortOption(
        field: LibraryShelfSortField.chapterCount,
        direction: LibrarySortDirection.asc,
      ),
      keyword: '追更',
    );

    expect(snapshot.itemsByCategory['default'], isEmpty);
    expect(comic.lastSnapshotKeyword, '');
    expect(novel.lastSnapshotKeyword, '');
  });

  test('selection actions dispatch to the source adapters', () async {
    await adapter.querySnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );

    final outcome = await adapter.runSelectionAction(
      const SelectionActionExecutionRequest(
        actionId: SelectionActionIds.assignCategory,
        workIds: <String>{'comic:yamibo:1', 'novel:yamibo:1'},
        activeCategoryId: 'default',
        targetCategoryId: 'comic:c1',
      ),
    );

    expect(comic.requests, hasLength(1));
    expect(comic.requests.single.workIds, <String>{'yamibo:1'});
    expect(comic.requests.single.activeCategoryId, 'default');
    expect(comic.requests.single.targetCategoryId, 'c1');
    expect(novel.requests, isEmpty);
    expect(outcome.code, SelectionActionOutcomeCode.partialFailure);
    expect(outcome.failedCount, 1);
  });

  test('category creation follows the selected source category', () async {
    await adapter.querySnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );

    final categoryId = await adapter.createCategoryInSource(
      sourceCategoryId: 'novel:default',
      name: '新分类',
    );

    expect(novel.createdCategoryName, '新分类');
    expect(comic.createdCategoryName, isNull);
    expect(categoryId, 'novel:new-新分类');

    await expectLater(
      adapter.createCategoryInSource(sourceCategoryId: 'default', name: '没有来源'),
      throwsUnsupportedError,
    );
  });

  test('refresh fans out to both module adapters', () async {
    expect(adapter.refreshModuleKeys, <LibraryModuleKey>{
      LibraryModuleKey.comic,
      LibraryModuleKey.novel,
    });
    await adapter.refreshShelf();
    expect(comic.refreshCount, 1);
    expect(novel.refreshCount, 1);
  });
}

LibraryWorkItem _item({
  required String workId,
  required String categoryId,
  required int unreadCount,
}) {
  return LibraryWorkItem(
    workId: workId,
    categoryId: categoryId,
    title: workId,
    unreadCount: unreadCount,
    totalChapterCount: 1,
    readChapterCount: 0,
    addedAt: DateTime(2026, 1, 1),
  );
}

class _FakeChildAdapter
    implements
        ShelfModuleAdapter,
        ShelfModuleCapabilitiesAdapter,
        ShelfSnapshotAdapter,
        ShelfSelectionActionAdapter,
        ShelfCategorySourceAdapter {
  _FakeChildAdapter({
    required this.moduleKey,
    required this.categories,
    required this.itemsByCategory,
    required this.displayMode,
  });

  @override
  final LibraryModuleKey moduleKey;
  final List<LibraryCategory> categories;
  final Map<String, List<LibraryWorkItem>> itemsByCategory;
  final LibraryDisplayMode displayMode;

  int refreshCount = 0;
  String? lastSnapshotKeyword;
  String? createdCategoryName;
  final List<SelectionActionExecutionRequest> requests =
      <SelectionActionExecutionRequest>[];

  @override
  LibraryDisplayMode get defaultDisplayMode => displayMode;

  @override
  ShelfModuleCapabilities get capabilities =>
      const ShelfModuleCapabilities.defaults();

  @override
  List<SelectionAction> get selectionActions => const <SelectionAction>[
    SelectionAction(id: SelectionActionIds.assignCategory, icon: Icons.label),
  ];

  @override
  Future<LibraryShelfSnapshot> querySnapshot({
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    lastSnapshotKeyword = keyword;
    return LibraryShelfSnapshot(
      categories: categories,
      itemsByCategory: itemsByCategory,
      visibleMatchCountByCategory: <String, int>{
        for (final entry in itemsByCategory.entries)
          entry.key: entry.value.length,
      },
    );
  }

  @override
  Future<List<LibraryCategory>> loadCategories() async => categories;

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems({
    required String categoryId,
  }) async => itemsByCategory[categoryId] ?? const <LibraryWorkItem>[];

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async => itemsByCategory;

  @override
  Future<Map<String, List<LibraryWorkItem>>> searchItemsByKeyword({
    required String keyword,
  }) async => itemsByCategory;

  @override
  Future<void> refreshShelf() async {
    refreshCount += 1;
  }

  @override
  Future<String> createCategory({required String name}) async {
    createdCategoryName = name;
    return 'new-$name';
  }

  @override
  Future<String> createCategoryInSource({
    required String sourceCategoryId,
    required String name,
  }) async {
    createdCategoryName = name;
    return 'new-$name';
  }

  @override
  Future<SelectionActionOutcome> runSelectionAction(
    SelectionActionExecutionRequest request,
  ) async {
    requests.add(request);
    return SelectionActionOutcome(
      code: SelectionActionOutcomeCode.success,
      changed: true,
      succeededCount: request.workIds.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
