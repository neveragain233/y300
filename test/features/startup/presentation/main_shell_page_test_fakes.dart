part of 'main_shell_page_test.dart';

Future<void> _pumpShellTab(WidgetTester tester) async {
  // Shelf tabs can legitimately keep an indeterminate loading indicator
  // alive while their first async load is in flight. The test only needs a
  // bounded frame window for the tab transition, not global quiescence.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  // A newly mounted shelf first passes its own cover-readiness FutureBuilder.
  await tester.pump();
}

Future<void> _pumpSelectionShell(
  WidgetTester tester, {
  required ValueNotifier<ComicSearchRefreshQueueSnapshot> queueSnapshot,
  required ShelfSelectionHostController selectionHost,
  required _FakeForumWebViewDriver webViewDriver,
  ForumHomeRepository? homeRepository,
  Future<void>? libraryReady,
  MessageAttentionController? attention,
  MessageTestRepository? messages,
  MainNavigationSettingsRepository? navigationRepository,
  HistoryRepository? historyRepository,
  HistoryEntryRouter? historyEntryRouter,
  ForumAvailability? availability,
  Future<Widget?> Function(ActiveReaderTarget)? restorePage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumAvailabilityProvider.overrideWith(
          (_) => availability ?? ForumAvailability(),
        ),
        if (restorePage != null)
          readerRestorePageProvider.overrideWithValue(restorePage),
        if (navigationRepository != null)
          mainNavigationSettingsRepositoryProvider.overrideWithValue(
            navigationRepository,
          ),
        if (messages != null)
          messageRepositoryProvider.overrideWithValue(messages),
        if (attention != null) ...[
          messageAttentionControllerProvider.overrideWithValue(attention),
          messageAttentionOwnerProvider.overrideWithValue(
            attention.value.owner,
          ),
        ],
        comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
        novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
        libraryStateRepositoryProvider.overrideWithValue(
          _FakeLibraryStateRepository(),
        ),
        localFavoriteRepositoryProvider.overrideWith(
          (ref) => _FakeLocalFavoriteRepository(),
        ),
        favoriteSyncServiceProvider.overrideWith(
          (ref) => _FakeFavoriteSyncService(),
        ),
        comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
          queueSnapshot,
        ),
        mainShellBackgroundTaskStarterProvider.overrideWithValue((_) async {
          await libraryReady;
        }),
        mainShellNotificationInitializerProvider.overrideWithValue(
          (_) async {},
        ),
        mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
        ...forumAuthOverrides(_FakeAuthRepository()),
        shelfSelectionHostControllerProvider.overrideWithValue(selectionHost),
        forumHomeRepositoryProvider.overrideWithValue(
          homeRepository ?? _FakeForumHomeRepository(),
        ),
        forumWebViewDriverFactoryProvider.overrideWithValue(
          () => webViewDriver,
        ),
        cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        historyRepositoryProvider.overrideWithValue(
          historyRepository ?? const _FakeHistoryRepository(),
        ),
        if (historyEntryRouter != null)
          historyEntryRouterProvider.overrideWithValue(historyEntryRouter),
      ],
      child: const LocalizedTestApp(home: MainShellPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMainShellReady(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    if (find
        .byKey(const Key('main-shell-navigation-loading'))
        .evaluate()
        .isEmpty) {
      // The selected destination can have its own async settings provider.
      // Give that child one frame after the shell configuration is ready.
      await tester.pump();
      return;
    }
  }
  fail('Main shell navigation settings did not finish loading');
}

List<TickerMode> _builtTickerModes(IndexedStack stack) {
  return stack.children
      .whereType<KeyedSubtree>()
      .map((subtree) => subtree.child)
      .whereType<TickerMode>()
      .toList(growable: false);
}

List<MainNavigationItem> _navigationItems(WidgetTester tester) {
  final capsule = find.byType(MainNavigationCapsule);
  if (capsule.evaluate().isNotEmpty) {
    return tester.widget<MainNavigationCapsule>(capsule).items;
  }
  final bar = find.byType(MainLegacyNavigationBar);
  if (bar.evaluate().isNotEmpty) {
    return tester.widget<MainLegacyNavigationBar>(bar).items;
  }
  return tester
      .widget<MainNavigationRail>(find.byType(MainNavigationRail))
      .items;
}

List<String> _navigationLabels(WidgetTester tester) =>
    _navigationItems(tester).map((item) => item.label).toList();

int _selectedNavigationIndex(WidgetTester tester) {
  final capsule = find.byType(MainNavigationCapsule);
  if (capsule.evaluate().isNotEmpty) {
    return tester.widget<MainNavigationCapsule>(capsule).selectedIndex;
  }
  final bar = find.byType(MainLegacyNavigationBar);
  if (bar.evaluate().isNotEmpty) {
    return tester.widget<MainLegacyNavigationBar>(bar).selectedIndex;
  }
  return tester
      .widget<MainNavigationRail>(find.byType(MainNavigationRail))
      .selectedIndex;
}

Future<void> _tapNavigationGroup(WidgetTester tester, String label) async {
  final capsule = find.byType(MainNavigationCapsule);
  final rail = find.byType(MainNavigationRail);
  final bar = find.byType(MainLegacyNavigationBar);
  final Finder target;
  if (capsule.evaluate().isNotEmpty) {
    target = find.descendant(of: capsule, matching: find.text(label));
  } else if (rail.evaluate().isNotEmpty) {
    target = find.descendant(of: rail, matching: find.text(label));
  } else {
    target = find.descendant(of: bar, matching: find.text(label));
  }
  await tester.tap(target);
  await _pumpShellTab(tester);
}

IconData? _navigationIconData(Widget widget) {
  return (widget as MessageAttentionIcon).icon;
}

ShelfSelectionHostDelegate _selectionDelegate({
  Future<SelectionActionOutcome> Function(
    SelectionActionExecutionRequest request,
  )?
  onRun,
}) {
  return ShelfSelectionHostDelegate(
    exitSelection: () async {},
    selectAllVisible: () async {},
    invertVisible: () async {},
    loadAvailableCategories: () async => const <LibraryCategory>[],
    createCategory: (name, {source}) async => 'created',
    runSelectionAction:
        onRun ??
        (request) async {
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.noChange,
          );
        },
    refreshAfterAction: () async {},
  );
}

HistoryEntry _historyEntry() {
  return HistoryEntry(
    target: const HistoryTargetKey(
      type: HistoryTargetType.thread,
      id: '572514',
    ),
    title: '测试记录帖子',
    contextLabel: '管理版',
    lastSurface: HistoryVisitSurface.threadNative,
    firstVisitedAt: DateTime(2026, 11, 13),
    lastVisitedAt: DateTime(2026, 11, 13, 12),
    visitCount: 1,
  );
}

class _NavigatingHistoryEntryRouter extends HistoryEntryRouter {
  _NavigatingHistoryEntryRouter()
    : super(
        comicWorkExists: (_) async => true,
        novelWorkExists: (_) async => true,
      );

  @override
  Future<HistoryOpenResult> open(
    BuildContext context,
    HistoryEntry entry,
  ) async {
    unawaited(
      openAdaptiveDetail<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                'fake-history-detail',
                key: Key('fake-history-detail'),
              ),
            ),
          ),
        ),
      ),
    );
    return const HistoryOpenSuccess();
  }
}

class _FakeHistoryRepository implements HistoryRepository {
  const _FakeHistoryRepository({this.items = const <HistoryEntry>[]});

  final List<HistoryEntry> items;

  @override
  Future<void> recordVisit(HistoryEntry candidate) async {}

  @override
  Future<HistoryQueryPage> query(HistoryQuery query) async {
    return HistoryQueryPage(items: items, hasMore: false);
  }

  @override
  Future<void> delete(HistoryTargetKey target) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> restore(HistoryEntry entry) async {}

  @override
  Stream<HistoryChange> watchChanges() {
    return const Stream<HistoryChange>.empty();
  }
}

class _FakeMainNavigationSettingsRepository
    implements MainNavigationSettingsRepository {
  _FakeMainNavigationSettingsRepository(this.settings);

  MainNavigationSettings settings;

  @override
  Future<MainNavigationSettings> load() async => settings;

  @override
  Future<void> save(MainNavigationSettings settings) async {
    this.settings = settings;
  }
}

class _FakeLibraryTaskNotificationService
    implements LibraryTaskNotificationService {
  _FakeLibraryTaskNotificationService({
    required LibraryTaskNotificationPermissionState? initialPermission,
  }) : _permissionState =
           ValueNotifier<LibraryTaskNotificationPermissionState?>(
             initialPermission,
           );

  final ValueNotifier<LibraryTaskNotificationPermissionState?> _permissionState;
  int initializeCalls = 0;
  int ensurePermissionCalls = 0;

  @override
  ValueListenable<LibraryTaskNotificationPermissionState?>
  get permissionState => _permissionState;

  @override
  Future<void> clear(LibraryTaskNotificationKey key) async {}

  @override
  Future<LibraryTaskNotificationPermissionState> ensurePermission() async {
    ensurePermissionCalls++;
    return _permissionState.value ??
        LibraryTaskNotificationPermissionState.denied;
  }

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> showOrUpdate(LibraryTaskNotification notification) async {}

  void dispose() {
    _permissionState.dispose();
  }
}

class _FakeForumWebViewDriver implements ForumWebViewDriver {
  @override
  Widget buildWidget({Key? key}) {
    return Container(key: key);
  }

  @override
  Future<ForumWebViewCapabilityProfile> probeCapabilities() async {
    return const ForumWebViewCapabilityProfile(
      documentStartMode: ForumWebViewDocumentStartMode.reliable,
      supportsContentBlockers: false,
      supportsTransparentBackground: true,
      supportsPlatformScrollTuning: true,
      supportsCookieHooks: true,
      supportsPageCommitVisible: true,
    );
  }

  @override
  Future<void> initialize({
    required ForumWebViewCallbacks callbacks,
    required ForumWebViewBootstrapConfig bootstrapConfig,
  }) async {}

  @override
  Future<void> load(Uri uri, {Map<String, String> headers = const {}}) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<bool> clearCookies() async {
    return true;
  }

  @override
  Future<String?> getTitle() async {
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    return false;
  }

  @override
  Future<void> goBack() async {}

  @override
  Future<void> runJavaScript(String script) async {}

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    return null;
  }

  @override
  Future<void> seedCookies({
    required String domain,
    required Map<String, String> cookies,
    String path = '/',
  }) async {}
}

class _FakeCookieStore extends CookieStore {
  @override
  Future<Map<String, String>> readCookieMap(Uri uri) async {
    return <String, String>{};
  }

  @override
  Future<String?> readCookieHeader(Uri uri) async {
    return null;
  }
}

class _FakeComicRepository implements ComicRepository {
  @override
  Future<void> addToShelf({
    required String comicId,
    required String tid,
    required String fid,
    String? sourceTypeId,
    String? sourceTagName,
    required String title,
    required ParsedComicPost parsedPost,
  }) async {}

  @override
  Future<void> removeFromShelf({required String comicId}) async {}

  @override
  Future<void> purgeWork({required String comicId}) async {}

  @override
  Future<String> createCategory({required String name}) async =>
      'mock-category';

  @override
  Future<void> clearEpisodeImageCache({required String episodeId}) async {}

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<ComicDetail?> getComicDetail({required String comicId}) async => null;

  @override
  Future<List<ComicEpisodeItem>> getComicEpisodes({
    required String comicId,
    bool descending = true,
  }) async {
    return const <ComicEpisodeItem>[];
  }

  @override
  Future<List<ComicEpisodeImageItem>> getEpisodeImages({
    required String episodeId,
  }) async {
    return const <ComicEpisodeImageItem>[];
  }

  @override
  Future<List<ComicShelfCategory>> getCategories() async {
    return <ComicShelfCategory>[
      ComicShelfCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<ComicShelfDisplaySettings> getDisplaySettings() async {
    return const ComicShelfDisplaySettings(gridColumnCount: 3);
  }

  @override
  Future<List<ComicShelfItem>> getShelfItems({
    String categoryId = 'default',
  }) async {
    return const <ComicShelfItem>[];
  }

  @override
  Future<bool> isInShelf({required String comicId}) async {
    return false;
  }

  @override
  Future<ComicReadingProgress?> getLastReadProgress({
    required String comicId,
  }) async => null;

  @override
  Future<ComicReadingProgress?> getReadingProgressForEpisode({
    required String comicId,
    required String episodeId,
  }) async => null;

  @override
  Future<List<ComicReadingProgress>> getReadingProgresses({
    required String comicId,
  }) async => const <ComicReadingProgress>[];

  @override
  Future<ComicEpisodeRefreshResult> mergeEpisodesFromLinks({
    required String comicId,
    required List<ComicEpisodeLink> episodeLinks,
    required String fallbackSourceTid,
  }) async {
    return const ComicEpisodeRefreshResult(
      insertedCount: 0,
      updatedCount: 0,
      totalCount: 0,
    );
  }

  @override
  Future<void> moveComicToCategory({
    required String comicId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> updateCustomCover({
    required String comicId,
    required String? customCoverImageUrl,
  }) async {}

  @override
  Future<void> updateCustomCoverFromLocalFile({
    required String comicId,
    required String localCoverPath,
    String? sourceEpisodeId,
    int? sourceImageIndex,
    String? sourceImageUrl,
    double? focusX,
    double? focusY,
  }) async {}

  @override
  Future<void> updateCustomCoverFocus({
    required String comicId,
    required double? focusX,
    required double? focusY,
  }) async {}

  @override
  Future<void> updateCustomMetadata({
    required String comicId,
    String? customTitle,
    String? customAuthor,
    String? customTranslationGroup,
    String? customOriginalWork,
    String? customSearchTitle,
  }) async {}

  @override
  Future<void> clearCustomMetadata({
    required String comicId,
    bool title = false,
    bool author = false,
    bool translationGroup = false,
    bool originalWork = false,
    bool searchTitle = false,
  }) async {}

  @override
  Future<void> updateGridColumnCount({required int columnCount}) async {}

  @override
  Future<void> saveEpisodeImages({
    required String episodeId,
    required List<String> imageUrls,
  }) async {}

  @override
  Future<void> updateEpisodeImageCacheStatus({
    required String episodeId,
    required String imageUrl,
    required String cacheStatus,
    String? cacheLocalPath,
  }) async {}

  @override
  Future<void> updateLastReadProgress({
    required String comicId,
    required String episodeId,
    required int imageIndex,
    required double scrollOffset,
  }) async {}

  @override
  Future<void> updateCatalogUrl({
    required String comicId,
    required String catalogUrl,
  }) async {}

  @override
  Future<Set<String>> getKnownEpisodeTids({required String comicId}) async =>
      <String>{};
}

class _FakeNovelRepository implements NovelRepository {
  @override
  Future<String> createCategory({required String name}) async => 'default';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<NovelShelfCategory>> getCategories() async {
    return <NovelShelfCategory>[
      NovelShelfCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<NovelItem?> getDetail({required String novelId}) async => null;

  @override
  Future<NovelChapterContent?> getChapterContent({
    required String episodeId,
  }) async => null;

  @override
  Future<List<NovelEpisodeItem>> getEpisodes({
    required String novelId,
    bool descending = false,
  }) async {
    return const <NovelEpisodeItem>[];
  }

  @override
  Future<List<NovelItem>> getShelfItems({String categoryId = 'default'}) async {
    return const <NovelItem>[];
  }

  @override
  Future<void> moveNovelToCategory({
    required String novelId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<NovelReadingProgress?> getReadingProgress({
    required String novelId,
  }) async => null;

  @override
  Future<void> removeFromShelf({required String novelId}) async {}

  @override
  Future<void> purgeWork({required String novelId}) async {}

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> saveReadingProgress({
    required String novelId,
    required String episodeId,
    required double scrollOffset,
    NovelReaderFlowMode flowMode = NovelReaderFlowMode.vertical,
    int pageIndex = 0,
    int? pageCount,
    String? anchorNodeId,
    int anchorTextOffset = 0,
    int anchorFormatVersion = 0,
    String? anchorTextIdentity,
    bool? isProgressPercentValid,
    String? paginationKey,
    double progressPercent = 0,
  }) async {}

  @override
  Future<void> addReaderBookmark({
    required NovelReaderBookmark bookmark,
  }) async {}

  @override
  Future<List<NovelReaderBookmark>> listReaderBookmarks({
    required String novelId,
  }) async {
    return const <NovelReaderBookmark>[];
  }

  @override
  Future<void> removeReaderBookmark({required String bookmarkId}) async {}

  @override
  Future<void> toggleEpisodeBookmark({
    required String novelId,
    required String episodeId,
    required bool isBookmarked,
  }) async {}
}

class _FakeFavoriteSyncService implements FavoriteSyncService {
  final _progress = ValueNotifier<FavoriteSyncProgress>(
    FavoriteSyncProgress.idle,
  );

  @override
  ValueListenable<FavoriteSyncProgress> get progress => _progress;

  @override
  Future<void> runBackgroundMaintenance() async {}

  @override
  Future<FavoriteSyncResult> sync() async {
    return const FavoriteSyncResult(
      mode: FavoriteSyncMode.incremental,
      remoteCount: 1,
      fetchedPages: 1,
      upsertedCount: 0,
      removedRecords: <FavoriteThreadCacheRecord>[],
      detailLoadedCount: 0,
      failedDetailTids: <String>[],
    );
  }

  @override
  Future<FavoriteSyncResult> syncRecentlyAddedThread({required String tid}) {
    return sync();
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionInfo>> login({
    required String username,
    required String password,
    String questionId = '0',
    String answer = '',
  }) async {
    return const ApiFailure(
      ApiError(type: ApiErrorType.business, message: 'not implemented'),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<ApiResult<SessionInfo>> refreshSession() async {
    return const ApiSuccess(
      SessionInfo(
        uid: '0',
        username: '',
        formhash: 'fh_guest',
        isLoggedIn: false,
      ),
    );
  }

  @override
  Future<ApiResult<bool>> verifyAuthByForumIndex() async {
    return const ApiSuccess(false);
  }
}

class _FakeLocalFavoriteRepository implements LocalFavoriteRepository {
  @override
  Future<void> markThreadDetailPending({required String tid}) async {}

  final _category = LibraryCategory(
    categoryId: favoriteDefaultCategoryId,
    name: '默认',
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );

  final _item = LibraryWorkItem(
    workId: FavoriteShelfWorkId.fromTid('100'),
    categoryId: favoriteDefaultCategoryId,
    title: '收藏帖',
    secondaryName: '作者A',
    unreadCount: 0,
    totalChapterCount: 1,
    readChapterCount: 0,
    addedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<int> countActiveThreads() async => 1;

  @override
  Future<int> countMissingDetailRecords() async => 0;

  @override
  Future<String> createCategory({required String name}) async => 'fav-custom';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<void> finishSync({
    required FavoriteSyncMode mode,
    required int remoteCount,
    String? status,
    String? message,
  }) async {}

  @override
  Future<Set<String>> getActiveTids() async => const <String>{'100'};

  @override
  Future<List<FavoriteThreadCacheRecord>> getActiveThreadsForSnapshot() async =>
      const <FavoriteThreadCacheRecord>[];

  @override
  Future<bool> hasCompletedComicAutoRefreshBackfill() async => true;

  @override
  Future<void> markComicAutoRefreshBackfillCompleted({
    required int checkedCount,
    String? message,
  }) async {}

  @override
  Future<FavoriteThreadCacheRecord?> getActiveThreadByTid(String tid) async =>
      null;

  @override
  Future<List<FavoriteThreadCacheRecord>> getActiveThreadsByWorkId(
    String workId,
  ) async => const <FavoriteThreadCacheRecord>[];

  @override
  Future<bool> hasActiveThreadForWorkId(String workId) async => false;

  @override
  Future<int> markRemovedByWorkId(String workId) async => 0;

  @override
  Future<int> markRemovedByTids(Set<String> tids) async => 0;

  @override
  Future<List<FavoriteThreadCacheRecord>> getMissingDetailRecords({
    int limit = 20,
    Set<String> excludedTids = const <String>{},
  }) async {
    return const <FavoriteThreadCacheRecord>[];
  }

  @override
  Future<List<FavoriteThreadCacheRecord>>
  getComicAutoRefreshBackfillCandidates({
    int limit = 20,
    Set<String> excludedTids = const <String>{},
  }) async {
    return const <FavoriteThreadCacheRecord>[];
  }

  @override
  Future<FavoriteRouteTarget?> getRouteTargetByShelfWorkId(
    String workId,
  ) async {
    return const FavoriteRouteTarget(
      tid: '100',
      title: '收藏帖',
      contentKind: ThreadContentKind.forum,
      workId: 'thread:100',
    );
  }

  @override
  Future<FavoriteSyncSnapshot?> getSyncSnapshot() async {
    return FavoriteSyncSnapshot(
      syncKey: favoriteSyncKey,
      remoteCount: 1,
      localActiveCount: 1,
      lastSyncedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems(String categoryId) async {
    return <LibraryWorkItem>[_item];
  }

  @override
  Future<List<LibraryCategory>> loadVisibleCategories() async {
    return <LibraryCategory>[_category];
  }

  @override
  Future<void> markSyncFailure(String message) async {}

  @override
  Future<List<FavoriteThreadCacheRecord>> markRemovedTids(
    Set<String> activeRemoteTids,
  ) async {
    return const <FavoriteThreadCacheRecord>[];
  }

  @override
  Future<void> moveThreadToCategory({
    required String tid,
    required String toCategoryId,
  }) async {}

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async =>
      _item.workId;

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    return <String, List<LibraryWorkItem>>{
      for (final category in categories)
        category.categoryId: <LibraryWorkItem>[_item],
    };
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> updateThreadDetailMeta({
    required String tid,
    required String fid,
    required String typeid,
    required String? tagName,
    required ThreadContentKind contentKind,
    required String? workId,
  }) async {}

  @override
  Future<void> markThreadDetailInvalid({required String tid}) async {}

  @override
  Future<int> upsertRemoteThreads(
    List<FavoriteThreadCacheUpsert> items,
  ) async => 0;
}

class _FakeLibraryStateRepository implements LibraryStateRepository {
  @override
  Future<void> bindTagToWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  }) async {}

  @override
  Future<int> countDownloadedEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return 0;
  }

  @override
  Future<void> purgeWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {}

  @override
  Future<void> setWorksReadState({
    required LibraryModuleKey moduleKey,
    required Set<String> workIds,
    required bool isRead,
    DateTime? readAt,
  }) async {}

  @override
  Future<int> countReadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return 0;
  }

  @override
  Future<int> countUnreadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return 0;
  }

  @override
  Future<String> createTag({required String name}) async => 'tag-1';

  @override
  Future<void> deleteTag({required String tagId}) async {}

  @override
  Future<LibraryModuleDisplaySettings> getDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode defaultDisplayMode,
  }) async {
    return LibraryModuleDisplaySettings(
      moduleKey: moduleKey,
      displayMode: defaultDisplayMode,
      gridColumns: 3,
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<LibraryEpisodeState?> getEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
  }) async {
    return null;
  }

  @override
  Future<List<LibraryTag>> getTags() async => const [];

  @override
  Future<LibraryWorkState?> getWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return null;
  }

  @override
  Future<List<LibraryTag>> getWorkTags({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return const [];
  }

  @override
  Future<bool> hasAnyTag({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return false;
  }

  @override
  Future<void> renameTag({
    required String tagId,
    required String newName,
  }) async {}

  @override
  Future<void> unbindTagFromWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  }) async {}

  @override
  Future<void> upsertDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode displayMode,
    required int gridColumns,
  }) async {}

  @override
  Future<void> upsertEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
    required String workId,
    bool? isRead,
    bool? isDownloaded,
    bool? isBookmarked,
    DateTime? readAt,
    DateTime? downloadedAt,
  }) async {}

  @override
  Future<void> upsertWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
    String? lastReadEpisodeId,
    DateTime? lastReadAt,
    DateTime? checkUpdatedAt,
    DateTime? fetchedUpdatedAt,
    String? introText,
  }) async {}
}

class _FakeForumHomeRepository implements ForumHomeRepository {
  _FakeForumHomeRepository({this.cachedEntry, this.network});
  final ForumHomeCacheEntry? cachedEntry;
  final Future<ForumHomeReadResult>? network;
  int cacheReads = 0;
  @override
  Future<ForumHomeCacheEntry?> readCachedPayload({
    required DocumentRequestProfile requestProfile,
  }) async {
    cacheReads++;
    return cachedEntry;
  }

  @override
  Future<ForumHomeReadResult> getForumHomePayload({
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    DocumentRequestProfile? requestProfileOverride,
  }) async =>
      network ??
      forumHomeReadSuccess(
        ForumHomePayload(
          directory: const ForumDirectoryData(sections: []),
          isLoggedIn: false,
          favoriteForums: [],
        ),
      );
}
