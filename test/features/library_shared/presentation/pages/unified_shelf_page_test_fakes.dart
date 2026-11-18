part of 'unified_shelf_page_test.dart';

Color _borderColorForListItem(WidgetTester tester, Finder itemFinder) {
  final container = tester.widget<AnimatedContainer>(itemFinder);
  final decoration = container.decoration as BoxDecoration;
  final border = decoration.border as Border;
  return border.top.color;
}

LibraryWorkItem _item({
  required String workId,
  required String title,
  String? coverImageUrl,
  LibraryCoverAssetRef? coverAsset,
  String? customCoverLocalPath,
  double? customCoverFocusX,
  double? customCoverFocusY,
  int unreadCount = 1,
  bool hasBookmarks = false,
}) {
  return LibraryWorkItem(
    workId: workId,
    categoryId: 'default',
    title: title,
    coverImageUrl: coverImageUrl,
    coverAsset: coverAsset,
    customCoverLocalPath: customCoverLocalPath,
    customCoverFocusX: customCoverFocusX,
    customCoverFocusY: customCoverFocusY,
    unreadCount: unreadCount,
    totalChapterCount: 3,
    readChapterCount: 2,
    addedAt: DateTime(2026, 1, 1),
    hasBookmarks: hasBookmarks,
  );
}

class _FakeMixedCategoryShelfAdapter extends _FakeShelfAdapter {
  _FakeMixedCategoryShelfAdapter()
    : super(
        initialDisplayMode: LibraryDisplayMode.grid,
        categories: <LibraryCategory>[
          LibraryCategory(
            categoryId: 'default',
            source: LibraryModuleKey.bookshelf,
            name: '',
            sortOrder: -1,
            createdAt: DateTime(2026, 1, 1),
          ),
          LibraryCategory(
            categoryId: 'comic:default',
            source: LibraryModuleKey.comic,
            name: '默认',
            sortOrder: 0,
            createdAt: DateTime(2026, 1, 1),
          ),
          LibraryCategory(
            categoryId: 'novel:default',
            source: LibraryModuleKey.novel,
            name: '默认',
            sortOrder: 1,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        itemsByCategory: <String, List<LibraryWorkItem>>{
          'default': <LibraryWorkItem>[
            _item(
              workId: 'yamibo:1',
              title: '漫画',
            ).copyWith(source: LibraryModuleKey.comic),
            _item(
              workId: 'novel:1',
              title: '小说',
            ).copyWith(source: LibraryModuleKey.novel),
          ],
        },
      );

  String? createdName;

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.bookshelf;

  @override
  Set<LibraryModuleKey> get refreshModuleKeys => const <LibraryModuleKey>{
    LibraryModuleKey.comic,
    LibraryModuleKey.novel,
  };

  @override
  String? get initialCategoryId => 'all';

  @override
  Future<String> createCategory({required String name}) async {
    createdName = name;
    return 'shared:created';
  }
}

class _PendingPreferences implements LibraryViewPreferencesRepository {
  final saved = Completer<void>();
  bool saveStarted = false;
  @override
  Future<LibraryShelfViewPreferences> load({
    required LibraryShelfViewPreferences defaults,
  }) async => defaults;
  @override
  Future<void> save(LibraryShelfViewPreferences preferences) {
    saveStarted = true;
    return saved.future;
  }
}

class _FakeShelfAdapter
    implements
        ShelfModuleAdapter,
        ShelfModuleCapabilitiesAdapter,
        ShelfDownloadStatusAdapter {
  _FakeShelfAdapter({
    required this.initialDisplayMode,
    this.onQuery,
    this.taskProgress,
    this.capabilities = const ShelfModuleCapabilities.defaults(),
    List<LibraryCategory>? categories,
    Map<String, List<LibraryWorkItem>>? itemsByCategory,
  }) : categories =
           categories ??
           [
             LibraryCategory(
               categoryId: 'default',
               name: 'Default',
               sortOrder: 0,
               createdAt: DateTime(2026, 1, 1),
             ),
           ],
       itemsByCategory =
           itemsByCategory ??
           {
             'default': [_item(workId: '1', title: 'Comic A')],
           };

  final LibraryDisplayMode initialDisplayMode;
  @override
  final ShelfModuleCapabilities capabilities;
  @override
  final ValueListenable<LibraryShelfTaskProgress?>? taskProgress;
  @override
  ValueListenable<LibraryShelfRefreshSignal?>? get shelfRefreshSignals => null;

  int refreshCalls = 0;
  final Future<Map<String, List<LibraryWorkItem>>> Function({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  })?
  onQuery;
  final List<LibraryCategory> categories;
  final Map<String, List<LibraryWorkItem>> itemsByCategory;

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.comic;

  @override
  Set<LibraryModuleKey> get refreshModuleKeys => <LibraryModuleKey>{moduleKey};

  @override
  String? get initialCategoryId => null;

  @override
  LibraryDisplayMode get defaultDisplayMode => initialDisplayMode;

  @override
  Future<Object> buildDetailRouteArgument({required String workId}) async =>
      workId;

  @override
  Future<String> createCategory({required String name}) async => 'created';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<LibraryCategory>> loadCategories() async {
    return categories;
  }

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems({
    required String categoryId,
  }) async {
    return itemsByCategory[categoryId] ?? const <LibraryWorkItem>[];
  }

  @override
  Future<void> moveWorkToCategory({
    required String workId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async => '1';

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    if (onQuery != null) {
      return onQuery!(
        categories: categories,
        filters: filters,
        sortOption: sortOption,
        keyword: keyword,
      );
    }
    return itemsByCategory;
  }

  @override
  Future<void> refreshShelf() async {
    refreshCalls += 1;
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<Map<String, List<LibraryWorkItem>>> searchItemsByKeyword({
    required String keyword,
  }) async {
    return queryItems(
      categories: await loadCategories(),
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: keyword,
    );
  }
}

class _FakeSelectableShelfAdapter extends _FakeShelfAdapter
    implements ShelfSelectionActionAdapter {
  _FakeSelectableShelfAdapter({
    required super.initialDisplayMode,
    super.capabilities,
    super.categories,
    super.itemsByCategory,
  });

  @override
  List<SelectionAction> get selectionActions => const <SelectionAction>[
    SelectionAction(
      id: SelectionActionIds.assignCategory,
      icon: Icons.edit_outlined,
    ),
    SelectionAction(
      id: SelectionActionIds.download,
      icon: Icons.download_outlined,
    ),
  ];

  @override
  Future<SelectionActionOutcome> runSelectionAction(
    SelectionActionExecutionRequest request,
  ) async {
    return const SelectionActionOutcome(
      code: SelectionActionOutcomeCode.noChange,
    );
  }
}
