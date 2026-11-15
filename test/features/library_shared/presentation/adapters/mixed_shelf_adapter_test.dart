import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/presentation/adapters/mixed_shelf_adapter.dart';

void main() {
  late _FakeChildAdapter comic;
  late _FakeChildAdapter novel;
  late MixedShelfAdapter adapter;

  setUp(() {
    comic = _FakeChildAdapter(
      moduleKey: LibraryModuleKey.comic,
      categories: <LibraryCategory>[
        LibraryCategory(
          categoryId: 'comic-default',
          name: '漫画',
          sortOrder: 0,
          createdAt: _epoch,
        ),
        LibraryCategory(
          categoryId: 'c1',
          name: '追更',
          sortOrder: 2,
          createdAt: _epoch,
        ),
      ],
      itemsByCategory: <String, List<LibraryWorkItem>>{
        'comic-default': <LibraryWorkItem>[
          _item(
            workId: 'yamibo:1',
            categoryId: 'comic-default',
            unreadCount: 2,
          ),
          _item(workId: 'yamibo:2', categoryId: 'c1', unreadCount: 0),
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
          categoryId: 'novel-default',
          name: '小说',
          sortOrder: 1,
          createdAt: _epoch,
        ),
        LibraryCategory(
          categoryId: 'n1',
          name: '追更',
          sortOrder: 3,
          createdAt: _epoch,
        ),
      ],
      itemsByCategory: <String, List<LibraryWorkItem>>{
        'novel-default': <LibraryWorkItem>[
          _item(
            workId: 'yamibo:1',
            categoryId: 'novel-default',
            unreadCount: 0,
          ),
          _item(workId: 'novel:49:9', categoryId: 'n1', unreadCount: 0),
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
    'snapshot merges shared categories and keeps work identities apart',
    () async {
      final snapshot = await adapter.querySnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: LibraryShelfSortOption.defaults,
        keyword: '',
      );

      expect(
        snapshot.categories.map((category) => category.categoryId),
        <String>['all', 'comic-default', 'novel-default', 'c1', 'n1'],
      );
      final allItems = snapshot.itemsByCategory['all']!;
      expect(allItems, hasLength(4));
      expect(allItems.map((item) => item.identityKey).toSet(), <String>{
        'comic:yamibo:1',
        'comic:yamibo:2',
        'novel:yamibo:1',
        'novel:novel:49:9',
      });
      expect(
        snapshot.itemsByCategory['comic-default']!.map(
          (item) => item.identityKey,
        ),
        unorderedEquals(<String>['comic:yamibo:1', 'comic:yamibo:2']),
      );
      expect(
        snapshot.itemsByCategory['novel-default']!.map(
          (item) => item.identityKey,
        ),
        unorderedEquals(<String>['novel:yamibo:1', 'novel:novel:49:9']),
      );
      expect(
        snapshot.itemsByCategory['c1']!.single.identityKey,
        'comic:yamibo:2',
      );
      expect(
        snapshot.itemsByCategory['n1']!.single.identityKey,
        'novel:novel:49:9',
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

    expect(snapshot.itemsByCategory['all'], isEmpty);
    expect(comic.lastSnapshotKeyword, '');
    expect(novel.lastSnapshotKeyword, '');
  });

  test('type views are real categories containing all works of that type', () async {
    final snapshot = await adapter.querySnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );

    for (final categoryId in <String>['comic-default', 'novel-default']) {
      final category = snapshot.categories.firstWhere(
        (candidate) => candidate.categoryId == categoryId,
      );
      expect(category.isSystemCategory, isTrue);
      expect(category.isSynthetic, isFalse);
    }
    expect(
      snapshot.categories.map((category) => category.categoryId),
      isNot(contains('default')),
    );
  });

  test('a shared target category is sent to both source adapters', () async {
    await adapter.querySnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );

    final outcome = await adapter.runSelectionAction(
      const SelectionActionExecutionRequest(
        actionId: SelectionActionIds.assignCategory,
        workIds: <String>{'comic:yamibo:1', 'novel:yamibo:1'},
        activeCategoryId: 'all',
        targetCategoryId: 'c1',
      ),
    );

    expect(comic.requests.single.targetCategoryId, 'c1');
    expect(novel.requests.single.targetCategoryId, 'c1');
    expect(outcome.code, SelectionActionOutcomeCode.success);
    expect(outcome.succeededCount, 2);
    expect(outcome.failedCount, 0);
  });

  test('category creation delegates to the shared module path', () async {
    final categoryId = await adapter.createCategory(name: '新分类');

    expect(comic.createdCategoryName, '新分类');
    expect(novel.createdCategoryName, isNull);
    expect(categoryId, 'new-新分类');

    await adapter.renameCategory(categoryId: categoryId, newName: '改名');
    expect(comic.renamedCategory, ('new-新分类', '改名'));
    await adapter.deleteCategory(categoryId: categoryId);
    expect(comic.deletedCategoryId, 'new-新分类');
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

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

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
        ShelfSelectionActionAdapter {
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
  (String, String)? renamedCategory;
  String? deletedCategoryId;
  final List<SelectionActionExecutionRequest> requests =
      <SelectionActionExecutionRequest>[];

  @override
  String? get initialCategoryId => null;

  @override
  LibraryDisplayMode get defaultDisplayMode => displayMode;

  @override
  ShelfModuleCapabilities get capabilities =>
      const ShelfModuleCapabilities.defaults();

  @override
  Set<LibraryModuleKey> get refreshModuleKeys => <LibraryModuleKey>{moduleKey};

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
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {
    renamedCategory = (categoryId, newName);
  }

  @override
  Future<void> deleteCategory({required String categoryId}) async {
    deletedCategoryId = categoryId;
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
