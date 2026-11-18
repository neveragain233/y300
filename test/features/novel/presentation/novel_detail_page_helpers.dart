part of 'novel_detail_page_test.dart';

Future<void> _pumpNovelDetail(
  WidgetTester tester, {
  required _MemoryNovelInteractionPreferencesRepository preferences,
  required _FakeNovelChapterSourceRouteResolver routeResolver,
  _FakeNovelRepository? repository,
  _FakeLibraryStateRepository? libraryStateRepository,
  ThreadRepository? threadRepository,
  NovelChapterUpdateService? chapterUpdateService,
  NovelReadingStateRepository? readingStateRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        historyVisitRecorderProvider.overrideWithValue(
          const _NoopHistoryVisitRecorder(),
        ),
        novelRepositoryProvider.overrideWithValue(
          repository ?? _FakeNovelRepository(),
        ),
        if (readingStateRepository != null)
          novelReadingStateRepositoryProvider.overrideWithValue(
            readingStateRepository,
          ),
        libraryStateRepositoryProvider.overrideWithValue(
          libraryStateRepository ?? _FakeLibraryStateRepository(),
        ),
        novelSourceStateRepositoryProvider.overrideWithValue(
          const _EmptyNovelSourceStateRepository(),
        ),
        novelInteractionPreferencesRepositoryProvider.overrideWithValue(
          preferences,
        ),
        novelChapterSourceRouteResolverProvider.overrideWithValue(
          routeResolver,
        ),
        imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        if (chapterUpdateService != null)
          novelChapterUpdateServiceProvider.overrideWithValue(
            chapterUpdateService,
          ),
        if (threadRepository != null)
          threadRepositoryProvider.overrideWithValue(threadRepository),
      ],
      child: const LocalizedTestApp(home: NovelDetailPage(novelId: 'novel:1')),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingHistoryVisitRecorder implements HistoryVisitRecorder {
  final List<HistoryVisitDraft> drafts = <HistoryVisitDraft>[];

  @override
  Future<void> record(HistoryVisitDraft draft) async {
    drafts.add(draft);
  }
}

class _NoopHistoryVisitRecorder implements HistoryVisitRecorder {
  const _NoopHistoryVisitRecorder();

  @override
  Future<void> record(HistoryVisitDraft draft) async {}
}

Future<void> _scrollNovelChapterIntoTapArea(WidgetTester tester) async {
  final chapter = find.byKey(
    const ValueKey<String>('unified-detail-chapter-novel:1:e1'),
  );
  await tester.scrollUntilVisible(
    chapter,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
  await tester.pumpAndSettle();
}

class _MemoryNovelInteractionPreferencesRepository
    implements NovelInteractionPreferencesRepository {
  _MemoryNovelInteractionPreferencesRepository([
    this.mode = NovelChapterOpenMode.reader,
  ]);

  NovelChapterOpenMode mode;

  @override
  Future<NovelChapterOpenMode> loadChapterOpenMode() async => mode;

  @override
  Future<void> saveChapterOpenMode(NovelChapterOpenMode mode) async {
    this.mode = mode;
  }
}

class _FakeNovelChapterSourceRouteResolver
    implements NovelChapterSourceRouteResolver {
  _FakeNovelChapterSourceRouteResolver._({this.route, this.error});

  factory _FakeNovelChapterSourceRouteResolver.success({int page = 7}) {
    return _FakeNovelChapterSourceRouteResolver._(
      route: NovelChapterSourceRoute(
        tid: '100',
        pid: '5001',
        page: page,
        url: 'https://bbs.yamibo.com/thread-100-$page-1.html#pid5001',
      ),
    );
  }

  factory _FakeNovelChapterSourceRouteResolver.failure() {
    return _FakeNovelChapterSourceRouteResolver._(
      error: const NovelChapterSourceRouteException(
        NovelChapterSourceRouteFailureCode.locatorFailed,
        detail: 'test_failure',
      ),
    );
  }

  final NovelChapterSourceRoute? route;
  final NovelChapterSourceRouteException? error;
  NovelChapterSourceReference? lastReference;
  int callCount = 0;
  Future<void>? waitFor;

  @override
  Future<NovelChapterSourceRoute> resolve(
    NovelChapterSourceReference reference,
  ) async {
    callCount++;
    lastReference = reference;
    await waitFor;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return route!;
  }
}

class _FakeThreadRepository implements ThreadRepository {
  @override
  ThreadDetailSourceCapabilities get capabilities =>
      ThreadDetailSourceCapabilities.full;

  @override
  Future<DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities>>
  getThreadDetail({
    required String tid,
    int page = 1,
    ThreadDetailQuery query = const ThreadDetailQuery(),
  }) async {
    return DataReadSuccess<ThreadDetailData, ThreadDetailReadCapabilities>(
      data: ThreadDetailData(
        tid: tid,
        fid: '49',
        subject: '来源帖子',
        author: 'Author A',
        replies: 1,
        views: 1,
        currentPage: page,
        perPage: 20,
        posts: <ThreadPost>[
          ThreadPost(
            pid: '5001',
            author: 'Author A',
            authorId: '406769',
            message: '<p>来源正文</p>',
            number: 1,
            isFirst: false,
            dateline: '2026-01-01',
          ),
        ],
      ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _EmptyNovelSourceStateRepository implements NovelSourceStateRepository {
  const _EmptyNovelSourceStateRepository();

  @override
  Future<NovelSourceState?> getSourceState({required String novelId}) async {
    return _sourceState(
      novelId: novelId,
      hydrationState: NovelChapterHydrationState.ready,
    );
  }

  @override
  Future<void> saveMetadata(NovelSourceMetadata metadata) async {}

  @override
  Future<void> saveCheckpoint(NovelChapterSyncCheckpoint checkpoint) async {}

  @override
  Future<void> setHydrationState({
    required String novelId,
    required NovelChapterHydrationState state,
    String? lastError,
    DateTime? chaptersHydratedAt,
  }) async {}
}

class _HydrationNovelSourceStateRepository
    implements NovelSourceStateRepository {
  NovelSourceState state = _sourceState(
    novelId: 'novel:1',
    hydrationState: NovelChapterHydrationState.metadataOnly,
  );

  @override
  Future<NovelSourceState?> getSourceState({required String novelId}) async {
    return state;
  }

  @override
  Future<void> saveCheckpoint(NovelChapterSyncCheckpoint checkpoint) async {}

  @override
  Future<void> saveMetadata(NovelSourceMetadata metadata) async {}

  @override
  Future<void> setHydrationState({
    required String novelId,
    required NovelChapterHydrationState state,
    String? lastError,
    DateTime? chaptersHydratedAt,
  }) async {}
}

class _ControlledNovelChapterSyncService implements NovelChapterSyncService {
  final StreamController<NovelChapterSyncProgress> _progress =
      StreamController<NovelChapterSyncProgress>.broadcast();
  final Completer<void> _completion = Completer<void>();
  NovelChapterSyncRequest? request;
  bool _active = false;

  @override
  bool hasActiveRun(String novelId) => _active;

  @override
  Future<NovelChapterSyncResult> synchronize(
    NovelChapterSyncRequest request,
  ) async {
    this.request = request;
    _active = true;
    _progress.add(
      NovelChapterSyncProgress(
        runId: 'widget-run',
        novelId: request.novelId,
        mode: request.mode,
        phase: NovelChapterSyncPhase.fetchingPage,
        currentPage: 1,
        totalPages: 2,
        acceptedCount: 1,
      ),
    );
    await _completion.future;
    _active = false;
    final checkpoint = NovelChapterSyncCheckpoint(
      novelId: request.novelId,
      publisherId: request.publisherId,
      lastCompletedAuthorPage: 2,
      lastSeenPid: '5001',
      completedAt: DateTime(2026, 7, 13),
    );
    _progress.add(
      NovelChapterSyncProgress(
        runId: 'widget-run',
        novelId: request.novelId,
        mode: request.mode,
        phase: NovelChapterSyncPhase.completed,
        currentPage: 2,
        totalPages: 2,
        acceptedCount: 1,
      ),
    );
    return NovelChapterSyncResult(
      mode: request.mode,
      fetchedPages: 2,
      insertedCount: 1,
      updatedCount: 0,
      totalCount: 1,
      checkpoint: checkpoint,
    );
  }

  @override
  Stream<NovelChapterSyncProgress> watchProgress(String novelId) {
    return _progress.stream;
  }

  void complete() => _completion.complete();

  Future<void> dispose() => _progress.close();
}

class _RecordingNovelChapterUpdateService implements NovelChapterUpdateService {
  final List<String> novelIds = <String>[];
  final List<NovelChapterUpdateIntent> intents = <NovelChapterUpdateIntent>[];

  @override
  Future<NovelChapterSyncResult> update(
    String novelId, {
    NovelChapterUpdateIntent intent = NovelChapterUpdateIntent.normal,
  }) async {
    novelIds.add(novelId);
    intents.add(intent);
    return NovelChapterSyncResult(
      mode: intent == NovelChapterUpdateIntent.full
          ? NovelChapterSyncMode.fullRefresh
          : NovelChapterSyncMode.incremental,
      fetchedPages: 1,
      insertedCount: 0,
      updatedCount: 1,
      totalCount: 1,
      checkpoint: NovelChapterSyncCheckpoint(
        novelId: novelId,
        publisherId: '406769',
        lastCompletedAuthorPage: 1,
        lastSeenPid: '5001',
        completedAt: DateTime(2026, 7, 14),
      ),
    );
  }
}

class _BlockingNovelChapterUpdateService implements NovelChapterUpdateService {
  final Completer<NovelChapterSyncResult> _completion =
      Completer<NovelChapterSyncResult>();
  final List<NovelChapterUpdateIntent> intents = <NovelChapterUpdateIntent>[];

  @override
  Future<NovelChapterSyncResult> update(
    String novelId, {
    NovelChapterUpdateIntent intent = NovelChapterUpdateIntent.normal,
  }) {
    intents.add(intent);
    return _completion.future;
  }

  void complete() {
    _completion.complete(
      NovelChapterSyncResult(
        mode: NovelChapterSyncMode.fullRefresh,
        fetchedPages: 1,
        insertedCount: 0,
        updatedCount: 1,
        totalCount: 1,
        checkpoint: NovelChapterSyncCheckpoint(
          novelId: 'novel:1',
          publisherId: '406769',
          lastCompletedAuthorPage: 1,
          lastSeenPid: '5001',
          completedAt: DateTime(2026, 7, 14),
        ),
      ),
    );
  }
}

NovelSourceState _sourceState({
  required String novelId,
  required NovelChapterHydrationState hydrationState,
}) {
  return NovelSourceState(
    novelId: novelId,
    publisherId: '406769',
    publisherName: 'Author A',
    firstPostPid: '5000',
    sourceIntro: '来源简介',
    catalogEntries: const <NovelSourceCatalogEntry>[],
    metadataSourceVersion: 4,
    hydrationState: hydrationState,
    metadataIngestedAt: DateTime(2026, 7, 13),
    chaptersHydratedAt: hydrationState == NovelChapterHydrationState.ready
        ? DateTime(2026, 7, 13)
        : null,
    lastCompletedAuthorPage: hydrationState == NovelChapterHydrationState.ready
        ? 1
        : 0,
    lastSeenPid: null,
    lastSyncAt: hydrationState == NovelChapterHydrationState.ready
        ? DateTime(2026, 7, 13)
        : null,
    lastError: null,
  );
}

class _NoopImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: 'memory://${request.cacheKey}',
      fromCache: true,
    );
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: request.sourcePath,
      fromCache: true,
    );
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async => 0;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}
}

class _MemoryNovelReadingStateRepository
    implements NovelReadingStateRepository, NovelWorkReadingResetRepository {
  _MemoryNovelReadingStateRepository({
    this.hasPosition = false,
    this.isRead = false,
    this.isBookmarked = false,
    this.recentEpisodeId = 'novel:1:e1',
  });
  bool hasPosition;
  bool isRead;
  final bool isBookmarked;
  String? recentEpisodeId;
  int readMutationCount = 0;
  bool appliesMutation = true;
  NovelReadingProgress? lastCommitted;
  int progressCommitCount = 0;
  int completionCommitCount = 0;
  int workResetCount = 0;

  @override
  Future<NovelReadingStateSnapshot> loadWorkState({
    required String novelId,
  }) async => NovelReadingStateSnapshot(
    novelId: novelId,
    recentEpisodeId: hasPosition ? recentEpisodeId : null,
    progressByEpisode: {
      if (hasPosition)
        'novel:1:e1':
            lastCommitted ??
            NovelReadingProgress(
              novelId: novelId,
              episodeId: 'novel:1:e1',
              scrollOffset: 80,
              progressPercent: 0.42,
              isProgressPercentValid: true,
              updatedAt: DateTime(2026, 10, 7),
            ),
    },
    episodeStates: {
      'novel:1:e1': LibraryEpisodeState(
        moduleKey: LibraryModuleKey.novel,
        episodeId: 'novel:1:e1',
        workId: novelId,
        isRead: isRead,
        isBookmarked: isBookmarked,
      ),
    },
  );

  @override
  Future<NovelReadingProgress?> getChapterProgress({
    required String novelId,
    required String episodeId,
  }) async =>
      (await loadWorkState(novelId: novelId)).progressByEpisode[episodeId];

  @override
  Future<bool> commitProgress({
    required NovelReadingProgress progress,
    bool markCompleted = false,
    bool Function()? canCommit,
  }) async {
    if (canCommit?.call() == false || !appliesMutation) return false;
    hasPosition = true;
    lastCommitted = progress;
    recentEpisodeId = progress.episodeId;
    progressCommitCount++;
    if (markCompleted) {
      isRead = true;
      completionCommitCount++;
    }
    return true;
  }

  @override
  Future<bool> setChapterRead({
    required String novelId,
    required String episodeId,
    required bool isRead,
    bool Function()? canCommit,
  }) async {
    readMutationCount++;
    if (!appliesMutation) return false;
    this.isRead = isRead;
    return true;
  }

  @override
  Future<bool> resetChapter({
    required String novelId,
    required String episodeId,
    bool Function()? canCommit,
  }) async {
    readMutationCount++;
    if (!appliesMutation) return false;
    isRead = false;
    hasPosition = false;
    recentEpisodeId = null;
    return true;
  }

  @override
  Future<bool> resetWorkReadingState({
    required String novelId,
    bool Function()? canCommit,
  }) async {
    workResetCount++;
    if (canCommit?.call() == false || !appliesMutation) return false;
    isRead = false;
    hasPosition = false;
    recentEpisodeId = null;
    lastCommitted = null;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNovelRepository implements NovelRepository {
  _FakeNovelRepository({this.progress});

  final NovelReadingProgress? progress;

  @override
  Future<String> createCategory({required String name}) async => 'created';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<NovelShelfCategory>> getCategories() async {
    return [
      NovelShelfCategory(
        categoryId: 'default',
        name: 'Default',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<NovelChapterContent?> getChapterContent({
    required String episodeId,
  }) async => null;

  @override
  Future<NovelItem?> getDetail({required String novelId}) async {
    return NovelItem(
      novelId: novelId,
      sourceTid: '100',
      sourceFid: '49',
      title: 'Test Novel',
      author: 'Author A',
      coverImageUrl: null,
      updatedAt: DateTime(2026, 1, 1),
      episodeCount: 1,
      categoryId: 'default',
    );
  }

  @override
  Future<List<NovelEpisodeItem>> getEpisodes({
    required String novelId,
    bool descending = false,
  }) async {
    return const [
      NovelEpisodeItem(
        episodeId: 'novel:1:e1',
        novelId: 'novel:1',
        sourceTid: '100',
        sourcePid: '5001',
        sourcePage: 1,
        episodeTitle: 'Chapter 1',
        orderIndex: 0,
        datelineText: '2026-01-01',
      ),
    ];
  }

  @override
  Future<NovelReadingProgress?> getReadingProgress({
    required String novelId,
  }) async => progress;

  @override
  Future<List<NovelItem>> getShelfItems({
    String categoryId = 'default',
  }) async => const [];

  @override
  Future<void> moveNovelToCategory({
    required String novelId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

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

class _FakeLibraryStateRepository implements LibraryStateRepository {
  int readMutationCount = 0;

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
  }) async {
    if (isRead != null) {
      readMutationCount++;
    }
  }

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
