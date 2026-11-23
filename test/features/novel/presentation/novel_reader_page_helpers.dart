part of 'novel_reader_page_test.dart';

List<Object?> _pagedSurfaceCaches(NovelReaderHtmlPagedSurface surface) => [
  surface.paginationCache,
  surface.paginationMeasureCache,
  surface.paginationBoundaryCache,
  surface.preparedChapterCache,
];

Future<void> _pumpPagedCacheReady(WidgetTester tester) async {
  for (var frame = 0; frame < 200; frame++) {
    // Cooperative work can be pending without scheduling a Flutter frame.
    await tester.pump(const Duration(milliseconds: 16));
    final surfaces = find.byType(NovelReaderHtmlPagedSurface);
    if (surfaces.evaluate().length == 1 &&
        tester
                .widget<NovelReaderHtmlPagedSurface>(surfaces)
                .paginationCache!
                .length >
            0 &&
        find
            .byKey(const Key('novel-reader-paged-page-view'))
            .evaluate()
            .isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(find.byKey(const Key('novel-reader-paged-page-view')), findsOneWidget);
  expect(
    tester
        .widget<NovelReaderHtmlPagedSurface>(
          find.byType(NovelReaderHtmlPagedSurface),
        )
        .paginationCache!
        .length,
    greaterThan(0),
  );
}

void _expectPagedCachesOpen(NovelReaderHtmlPagedSurface surface) {
  expect([
    surface.paginationCache!.isClosed,
    surface.paginationMeasureCache!.isClosed,
    surface.paginationBoundaryCache!.isClosed,
    surface.preparedChapterCache!.isClosed,
  ], everyElement(isFalse));
}

void _expectPagedCachesClosed(NovelReaderHtmlPagedSurface surface) {
  expect([
    surface.paginationCache!.isClosed,
    surface.paginationMeasureCache!.isClosed,
    surface.paginationBoundaryCache!.isClosed,
    surface.preparedChapterCache!.isClosed,
  ], everyElement(isTrue));
  expect([
    surface.paginationCache!.length,
    surface.paginationMeasureCache!.length,
    surface.paginationBoundaryCache!.length,
    surface.preparedChapterCache!.length,
  ], everyElement(0));
}

Future<void> _showReaderMenu(WidgetTester tester) async {
  await tester.tapAt(
    tester.getCenter(find.byKey(const Key('shared-reader-center-tap-zone'))),
  );
  await tester.pump(const Duration(milliseconds: 330));
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pump();
}

Future<void> _pumpVerticalReaderReady(WidgetTester tester) async {
  for (var frame = 0; frame < 300; frame++) {
    // Long HTML may be prepared on a worker isolate, outside the test clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (find
            .byKey(const Key('novel-reader-paragraph-list'))
            .evaluate()
            .isNotEmpty &&
        find
            .byKey(const Key('novel-reader-delayed-loading-surface'))
            .evaluate()
            .isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(
    find.byKey(const Key('novel-reader-delayed-loading-surface')),
    findsNothing,
  );
  expect(find.byKey(const Key('novel-reader-paragraph-list')), findsOneWidget);
}

ScrollPosition _verticalPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('novel-reader-paragraph-list')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

String _readingStatusTrailing(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const Key('shared-reader-persistent-status-trailing')),
      matching: find.byType(Text),
    ),
  );
  return text.data ?? '';
}

Future<void> _tapPagedReaderZone(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(ReaderPagedTurnMotion.tapConfirmationDelay);
  await tester.pump(ReaderPagedTurnMotion.animationDuration);
  await tester.pumpAndSettle();
}

Finder _readerText(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is RichText && widget.text.toPlainText().contains(text);
  });
}

List<Object?> _progressFields(NovelReaderProgressSnapshot snapshot) => [
  snapshot.flowMode,
  snapshot.pageIndex,
  snapshot.pageCount,
  snapshot.anchorNodeId,
  snapshot.anchorTextOffset,
  snapshot.anchorFormatVersion,
  snapshot.anchorTextIdentity,
  snapshot.paginationKey,
  snapshot.progressPercent,
  snapshot.isProgressPercentValid,
];

Widget _buildReaderApp({
  required _FakeNovelRepository repository,
  NovelReaderPreferencesRepository? preferencesRepository,
  NovelReaderProgressCommitter? progressCommitter,
  LibraryStateRepository? stateRepository,
  ThreadRepository? threadRepository,
  ThreadPostLocator? threadPostLocator,
  ClipboardTextWriter? clipboardWriter,
  ForumWebViewExternalLauncher? externalLauncher,
  NovelReaderDocumentBuildService? documentBuildService,
  NovelReaderSupplementalHydrationService? supplementalHydrationService,
  NovelChapterUpdateService? chapterUpdateService,
  ThemeData? theme,
  ValueListenable<ThemeData>? themeListenable,
  String initialEpisodeId = 'novel:49:100:5001',
  Widget? home,
  EdgeInsets safeArea = EdgeInsets.zero,
  ReaderSystemUiController? systemUiController,
  _FakeNovelChapterDockRepository? dockRepository,
}) {
  dockRepository ??= _FakeNovelChapterDockRepository();
  final homePage =
      home ??
      NovelReaderPage(
        novelId: 'novel:49:100',
        initialEpisodeId: initialEpisodeId,
      );
  final page = safeArea == EdgeInsets.zero
      ? homePage
      : Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: safeArea, viewPadding: safeArea),
            child: homePage,
          ),
        );
  return ProviderScope(
    overrides: [
      readerSystemUiControllerProvider.overrideWithValue(
        systemUiController ?? const _NoopReaderSystemUiController(),
      ),
      novelChapterInteractionsDockPreferencesRepositoryProvider
          .overrideWithValue(dockRepository),
      novelRepositoryProvider.overrideWithValue(repository),
      novelReaderPreferencesRepositoryProvider.overrideWithValue(
        preferencesRepository ??
            _FakeNovelReaderPreferencesRepository(repository),
      ),
      if (progressCommitter != null)
        novelReaderProgressCommitterProvider.overrideWithValue(
          progressCommitter,
        ),
      novelChapterUpdateServiceProvider.overrideWithValue(
        chapterUpdateService ?? _RecordingNovelChapterUpdateService(),
      ),
      forumWebViewExternalLauncherProvider.overrideWithValue(
        externalLauncher ?? _FakeForumWebViewExternalLauncher(),
      ),
      if (clipboardWriter != null)
        clipboardTextWriterProvider.overrideWithValue(clipboardWriter),
      forumImageRefererProvider.overrideWithValue('https://bbs.yamibo.com/'),
      imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
      if (documentBuildService != null)
        novelReaderDocumentBuildServiceProvider.overrideWithValue(
          documentBuildService,
        ),
      if (supplementalHydrationService != null)
        novelReaderSupplementalHydrationServiceProvider.overrideWithValue(
          supplementalHydrationService,
        ),
      libraryStateRepositoryProvider.overrideWithValue(
        stateRepository ?? _MemoryLibraryStateRepository(),
      ),
      if (threadRepository != null)
        threadRepositoryProvider.overrideWithValue(threadRepository),
      if (threadPostLocator != null)
        threadPostLocatorProvider.overrideWithValue(threadPostLocator),
    ],
    child: themeListenable == null
        ? LocalizedTestApp(theme: theme, home: page)
        : ValueListenableBuilder<ThemeData>(
            valueListenable: themeListenable,
            builder: (context, activeTheme, child) {
              return LocalizedTestApp(theme: activeTheme, home: page);
            },
          ),
  );
}

final class _NoopReaderSystemUiController implements ReaderSystemUiController {
  const _NoopReaderSystemUiController();

  @override
  Future<void> enterImmersive() async {}

  @override
  Future<void> restore() async {}
}

final class _RecordingReaderSystemUiController
    implements ReaderSystemUiController {
  bool immersive = false;
  int enterCount = 0;
  int restoreCount = 0;

  @override
  Future<void> enterImmersive() async {
    immersive = true;
    enterCount += 1;
  }

  @override
  Future<void> restore() async {
    immersive = false;
    restoreCount += 1;
  }
}

final class _FakeNovelChapterDockRepository
    implements NovelChapterInteractionsDockPreferencesRepository {
  _FakeNovelChapterDockRepository({this.failSave = false});

  final bool failSave;
  NovelChapterInteractionsDockPreferences current =
      const NovelChapterInteractionsDockPreferences();

  @override
  Future<NovelChapterInteractionsDockPreferences> load() async => current;

  @override
  Future<void> save(NovelChapterInteractionsDockPreferences preferences) async {
    if (failSave) throw StateError('save failed');
    current = preferences;
  }
}

class _NovelReaderRoundTripHost extends StatelessWidget {
  const _NovelReaderRoundTripHost();

  @override
  Widget build(BuildContext context) {
    Future<void> open(NovelEpisodeOpenPolicy policy) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => NovelReaderPage(
            novelId: 'novel:49:100',
            initialEpisodeId: 'novel:49:100:5001',
            openPolicy: policy,
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          TextButton(
            key: const Key('open-novel-from-beginning'),
            onPressed: () => open(NovelEpisodeOpenPolicy.startAtBeginning),
            child: const Text('从头阅读'),
          ),
          TextButton(
            key: const Key('continue-novel-reading'),
            onPressed: () => open(NovelEpisodeOpenPolicy.resumeLastRead),
            child: const Text('继续阅读'),
          ),
        ],
      ),
    );
  }
}

class _RecordingNovelChapterUpdateService implements NovelChapterUpdateService {
  final List<String> novelIds = <String>[];

  @override
  Future<NovelChapterSyncResult> update(
    String novelId, {
    NovelChapterUpdateIntent intent = NovelChapterUpdateIntent.normal,
  }) async {
    novelIds.add(novelId);
    return NovelChapterSyncResult(
      mode: NovelChapterSyncMode.incremental,
      fetchedPages: 1,
      insertedCount: 0,
      updatedCount: 1,
      totalCount: 2,
      checkpoint: NovelChapterSyncCheckpoint(
        novelId: novelId,
        publisherId: '406769',
        lastCompletedAuthorPage: 1,
        lastSeenPid: '5002',
        completedAt: DateTime(2026, 7, 14),
      ),
    );
  }
}

class _FakeForumWebViewExternalLauncher
    implements ForumWebViewExternalLauncher {
  bool succeeds = true;
  final opened = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }
}

class _ClipboardWriter implements ClipboardTextWriter {
  final writes = <String>[];
  Completer<void>? pending;

  @override
  Future<void> writeText(String text) {
    writes.add(text);
    return pending?.future ?? Future<void>.value();
  }
}

class _NoopImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(success: true, cacheKey: request.cacheKey);
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
    );
  }

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async {
    return 0;
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

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

class _ReaderPostLocator implements ThreadPostLocator {
  _ReaderPostLocator({this.tid = '200', this.pid = '5001'});

  final String tid;
  final String pid;
  var calls = 0;
  Completer<ApiResult<ThreadPostLocation>>? pending;
  ApiResult<ThreadPostLocation> get location =>
      ApiSuccess(ThreadPostLocation(tid: tid, pid: pid, page: 2, url: ''));
  @override
  Future<ApiResult<ThreadPostLocation>> locate({
    required String tid,
    required String pid,
    required Uri sourceUri,
  }) async {
    calls++;
    return pending == null ? location : await pending!.future;
  }
}

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository({this.targetPid});
  final String? targetPid;
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
    return DataReadSuccess(
      data: ThreadDetailData(
        tid: tid,
        fid: '49',
        subject: '测试小说',
        author: 'alice',
        replies: 0,
        views: 1,
        currentPage: page,
        perPage: 20,
        posts: [
          if (targetPid != null)
            ThreadPost(
              pid: targetPid!,
              author: 'Author',
              authorId: '10',
              message: '<p>Target body</p>',
              number: 21,
              isFirst: false,
              dateline: '',
            ),
        ],
      ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _MemoryLibraryStateRepository implements LibraryStateRepository {
  final Map<String, LibraryEpisodeState> _episodeStates =
      <String, LibraryEpisodeState>{};

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
    final old = _episodeStates[episodeId];
    _episodeStates[episodeId] = LibraryEpisodeState(
      moduleKey: moduleKey,
      episodeId: episodeId,
      workId: workId,
      isRead: isRead ?? old?.isRead ?? false,
      isDownloaded: isDownloaded ?? old?.isDownloaded ?? false,
      isBookmarked: isBookmarked ?? old?.isBookmarked ?? false,
      readAt: isRead == false ? null : readAt ?? old?.readAt,
      downloadedAt: isDownloaded == false
          ? null
          : downloadedAt ?? old?.downloadedAt,
    );
  }

  @override
  Future<LibraryEpisodeState?> getEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
  }) async {
    final state = _episodeStates[episodeId];
    return state?.moduleKey == moduleKey ? state : null;
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

  @override
  Future<LibraryWorkState?> getWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return null;
  }

  @override
  Future<int> countUnreadEpisodes({
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
  Future<int> countDownloadedEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return _episodeStates.values
        .where(
          (state) =>
              state.moduleKey == moduleKey &&
              state.workId == workId &&
              state.isDownloaded,
        )
        .length;
  }

  @override
  Future<void> setWorksReadState({
    required LibraryModuleKey moduleKey,
    required Set<String> workIds,
    required bool isRead,
    DateTime? readAt,
  }) async {}

  @override
  Future<void> purgeWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {}

  @override
  Future<void> upsertDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode displayMode,
    required int gridColumns,
  }) async {}

  @override
  Future<LibraryModuleDisplaySettings> getDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode defaultDisplayMode,
  }) async {
    return LibraryModuleDisplaySettings(
      moduleKey: moduleKey,
      displayMode: defaultDisplayMode,
      gridColumns: 3,
      updatedAt: DateTime(2026, 6, 8),
    );
  }

  @override
  Future<String> createTag({required String name}) async => 'tag';

  @override
  Future<List<LibraryTag>> getTags() async => const <LibraryTag>[];

  @override
  Future<void> renameTag({
    required String tagId,
    required String newName,
  }) async {}

  @override
  Future<void> deleteTag({required String tagId}) async {}

  @override
  Future<void> bindTagToWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  }) async {}

  @override
  Future<void> unbindTagFromWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  }) async {}

  @override
  Future<List<LibraryTag>> getWorkTags({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return const <LibraryTag>[];
  }

  @override
  Future<bool> hasAnyTag({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return false;
  }
}

class _FakeNovelRepository implements NovelRepository {
  _FakeNovelRepository({
    List<String>? firstParagraphs,
    String? firstRawHtml,
    NovelReaderPreferences? preferences,
    List<NovelEpisodeItem>? episodes,
    Map<String, NovelChapterContent>? contentsByEpisodeId,
    this.readingProgress,
    this.chapterLoadDelay = Duration.zero,
    this.failedEpisodeIds = const <String>{},
  }) : episodes = episodes ?? _defaultEpisodes(),
       contentsByEpisodeId =
           contentsByEpisodeId ??
           _defaultContents(
             firstParagraphs: firstParagraphs,
             firstRawHtml: firstRawHtml,
           ),
       preferences =
           preferences ??
           NovelReaderPreferences.defaults().copyWith(
             flowMode: NovelReaderFlowMode.vertical,
           );

  factory _FakeNovelRepository.threeEpisodes({
    List<String>? firstParagraphs,
    NovelReadingProgress? readingProgress,
    Duration chapterLoadDelay = Duration.zero,
    Set<String> failedEpisodeIds = const <String>{},
    NovelReaderPreferences? preferences,
  }) {
    return _FakeNovelRepository(
      preferences: preferences,
      episodes: _threeEpisodes(),
      contentsByEpisodeId: _contentsForParagraphs(<String, List<String>>{
        'novel:49:100:5001': firstParagraphs ?? <String>['第一段。', '第二段。'],
        'novel:49:100:5002': <String>['第三段。', '第四段。'],
        'novel:49:100:5003': <String>['第五段。', '第六段。'],
      }),
      readingProgress: readingProgress,
      chapterLoadDelay: chapterLoadDelay,
      failedEpisodeIds: failedEpisodeIds,
    );
  }

  factory _FakeNovelRepository.manyEpisodes({
    required int count,
    required int currentIndex,
  }) {
    final episodes = List<NovelEpisodeItem>.generate(count, (index) {
      final number = index + 1;
      final pid = (5000 + number).toString();
      return NovelEpisodeItem(
        episodeId: 'novel:49:100:$pid',
        novelId: 'novel:49:100',
        sourceTid: '100',
        sourcePid: pid,
        sourcePage: 1,
        episodeTitle: '第$number章',
        orderIndex: index,
        datelineText: '2026-05-${number.toString().padLeft(2, '0')}',
      );
    });
    final contents = <String, NovelChapterContent>{
      for (final episode in episodes)
        episode.episodeId: _contentFromParagraphs(episode.episodeId, <String>[
          '${episode.episodeTitle}正文。',
        ]),
    };
    return _FakeNovelRepository(
      episodes: episodes,
      contentsByEpisodeId: contents,
      readingProgress: NovelReadingProgress(
        novelId: 'novel:49:100',
        episodeId: episodes[currentIndex].episodeId,
        scrollOffset: 0,
        updatedAt: DateTime(2026, 6, 1),
      ),
      chapterLoadDelay: Duration.zero,
      failedEpisodeIds: const <String>{},
    );
  }

  final List<NovelEpisodeItem> episodes;
  final Map<String, NovelChapterContent> contentsByEpisodeId;
  NovelReadingProgress? readingProgress;
  final Duration chapterLoadDelay;
  final Set<String> failedEpisodeIds;
  NovelReaderPreferences preferences;
  NovelReaderPreferences? latestPreferences;
  int upsertPreferencesCallCount = 0;
  double lastSavedOffset = 0;
  final savedProgressEpisodeIds = <String>[];
  final savedProgressOffsets = <double>[];
  final chapterLoadEpisodeIds = <String>[];
  final chapterLoadGates = <String, Completer<void>>{};
  final bookmarks = <NovelReaderBookmark>[];

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
  Future<NovelItem?> getDetail({required String novelId}) async {
    return NovelItem(
      novelId: novelId,
      sourceTid: '100',
      sourceFid: '49',
      title: '测试小说',
      updatedAt: DateTime(2026, 1, 1),
      episodeCount: episodes.length,
    );
  }

  @override
  Future<NovelChapterContent?> getChapterContent({
    required String episodeId,
  }) async {
    chapterLoadEpisodeIds.add(episodeId);
    final gate = chapterLoadGates[episodeId];
    if (gate != null) await gate.future;
    if (chapterLoadDelay > Duration.zero) {
      await Future<void>.delayed(chapterLoadDelay);
    }
    if (failedEpisodeIds.contains(episodeId)) {
      throw StateError('章节内容不存在');
    }
    return contentsByEpisodeId[episodeId];
  }

  @override
  Future<List<NovelEpisodeItem>> getEpisodes({
    required String novelId,
    bool descending = false,
  }) async {
    return descending ? episodes.reversed.toList(growable: false) : episodes;
  }

  @override
  Future<List<NovelItem>> getShelfItems({
    String categoryId = 'default',
  }) async => const <NovelItem>[];

  @override
  Future<void> moveNovelToCategory({
    required String novelId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<NovelReadingProgress?> getReadingProgress({
    required String novelId,
  }) async {
    return readingProgress;
  }

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
  }) async {
    savedProgressEpisodeIds.add(episodeId);
    savedProgressOffsets.add(scrollOffset);
    lastSavedOffset = scrollOffset;
    readingProgress = NovelReadingProgress(
      novelId: novelId,
      episodeId: episodeId,
      scrollOffset: scrollOffset,
      updatedAt: DateTime(2026, 6, 8),
      flowMode: flowMode,
      pageIndex: pageIndex,
      pageCount: pageCount,
      anchorNodeId: anchorNodeId,
      anchorTextOffset: anchorTextOffset,
      anchorFormatVersion: anchorFormatVersion,
      anchorTextIdentity: anchorTextIdentity,
      isProgressPercentValid: isProgressPercentValid,
      paginationKey: paginationKey,
      progressPercent: progressPercent,
    );
  }

  @override
  Future<void> addReaderBookmark({
    required NovelReaderBookmark bookmark,
  }) async {
    bookmarks.removeWhere((item) => item.bookmarkId == bookmark.bookmarkId);
    bookmarks.add(bookmark);
  }

  @override
  Future<List<NovelReaderBookmark>> listReaderBookmarks({
    required String novelId,
  }) async {
    return bookmarks.where((bookmark) => bookmark.novelId == novelId).toList();
  }

  @override
  Future<void> removeReaderBookmark({required String bookmarkId}) async {
    bookmarks.removeWhere((bookmark) => bookmark.bookmarkId == bookmarkId);
  }

  @override
  Future<void> toggleEpisodeBookmark({
    required String novelId,
    required String episodeId,
    required bool isBookmarked,
  }) async {
    bookmarks.removeWhere(
      (bookmark) => bookmark.bookmarkId == 'episode-bookmark:$episodeId',
    );
    if (!isBookmarked) {
      return;
    }
    final episode = episodes.firstWhere((item) => item.episodeId == episodeId);
    bookmarks.add(
      NovelReaderBookmark(
        bookmarkId: 'episode-bookmark:$episodeId',
        novelId: novelId,
        episodeId: episodeId,
        anchor: NovelReaderTextAnchor(episodeId: episodeId),
        title: episode.episodeTitle,
        snippet: '章节书签',
        createdAt: DateTime(2026, 6, 8),
        updatedAt: DateTime(2026, 6, 8),
      ),
    );
  }

  static String _rawHtmlFromParagraphs(List<String> paragraphs) {
    return paragraphs.map((paragraph) => '<p>$paragraph</p>').join();
  }

  static List<NovelEpisodeItem> _defaultEpisodes() {
    return _threeEpisodes().take(2).toList(growable: false);
  }

  static List<NovelEpisodeItem> _threeEpisodes() {
    return const <NovelEpisodeItem>[
      NovelEpisodeItem(
        episodeId: 'novel:49:100:5001',
        novelId: 'novel:49:100',
        sourceTid: '100',
        sourcePid: '5001',
        sourcePage: 1,
        episodeTitle: '第1章',
        orderIndex: 0,
        datelineText: '2026-05-03',
      ),
      NovelEpisodeItem(
        episodeId: 'novel:49:100:5002',
        novelId: 'novel:49:100',
        sourceTid: '100',
        sourcePid: '5002',
        sourcePage: 1,
        episodeTitle: '第2章',
        orderIndex: 1,
        datelineText: '2026-05-04',
      ),
      NovelEpisodeItem(
        episodeId: 'novel:49:100:5003',
        novelId: 'novel:49:100',
        sourceTid: '100',
        sourcePid: '5003',
        sourcePage: 1,
        episodeTitle: '第3章',
        orderIndex: 2,
        datelineText: '2026-05-05',
      ),
    ];
  }

  static Map<String, NovelChapterContent> _defaultContents({
    List<String>? firstParagraphs,
    String? firstRawHtml,
  }) {
    final paragraphs = firstParagraphs ?? const <String>['第一段。', '第二段。'];
    final rawHtml = firstRawHtml ?? _rawHtmlFromParagraphs(paragraphs);
    return <String, NovelChapterContent>{
      'novel:49:100:5001': NovelChapterContent(
        episodeId: 'novel:49:100:5001',
        rawHtml: rawHtml,
        plainText: paragraphs.join('\n'),
        paragraphs: paragraphs,
      ),
      'novel:49:100:5002': const NovelChapterContent(
        episodeId: 'novel:49:100:5002',
        rawHtml: '<p>第三段。</p><p>第四段。</p>',
        plainText: '第三段。\n第四段。',
        paragraphs: <String>['第三段。', '第四段。'],
      ),
    };
  }

  static Map<String, NovelChapterContent> _contentsForParagraphs(
    Map<String, List<String>> source,
  ) {
    return <String, NovelChapterContent>{
      for (final entry in source.entries)
        entry.key: _contentFromParagraphs(entry.key, entry.value),
    };
  }

  static NovelChapterContent _contentFromParagraphs(
    String episodeId,
    List<String> paragraphs,
  ) {
    return NovelChapterContent(
      episodeId: episodeId,
      rawHtml: _rawHtmlFromParagraphs(paragraphs),
      plainText: paragraphs.join('\n'),
      paragraphs: paragraphs,
    );
  }
}

class _FakeNovelReaderPreferencesRepository
    implements NovelReaderPreferencesRepository {
  const _FakeNovelReaderPreferencesRepository(this.repository);

  final _FakeNovelRepository repository;

  @override
  Future<NovelReaderPreferences> load() async => repository.preferences;

  @override
  Future<void> save(NovelReaderPreferences preferences) async {
    repository.upsertPreferencesCallCount += 1;
    repository.latestPreferences = preferences;
    repository.preferences = preferences;
  }
}

class _ControlledPageProgressCommitter implements NovelReaderProgressCommitter {
  _ControlledPageProgressCommitter(
    _FakeNovelRepository repository, {
    this.forwardScheduledCommits = false,
  }) : _delegate = DefaultNovelReaderProgressCommitter(repository: repository);

  final DefaultNovelReaderProgressCommitter _delegate;
  final bool forwardScheduledCommits;
  bool autoCompleteFlushes = true;
  final flushes = <_PendingPageProgressFlush>[];
  Future<void> _tail = Future<void>.value();

  @override
  void schedule(NovelReaderProgressSnapshot snapshot) {
    if (forwardScheduledCommits) _delegate.schedule(snapshot);
  }

  @override
  Future<void> flush(NovelReaderProgressSnapshot snapshot) {
    final pending = _PendingPageProgressFlush(snapshot);
    flushes.add(pending);
    if (autoCompleteFlushes) pending.complete();
    final operation = _tail.then((_) async {
      await pending.completer.future;
      await _delegate.flush(snapshot);
    });
    _tail = operation.catchError((_) {});
    return operation;
  }

  @override
  void cancel() => _delegate.cancel();
}

class _PendingPageProgressFlush {
  _PendingPageProgressFlush(this.snapshot);

  final NovelReaderProgressSnapshot snapshot;
  final completer = Completer<void>();

  void complete() {
    if (!completer.isCompleted) completer.complete();
  }
}

class _ControlledPagePreferencesRepository
    implements NovelReaderPreferencesRepository {
  _ControlledPagePreferencesRepository(this.repository);

  final _FakeNovelRepository repository;
  final saves = <_PendingPagePreferencesSave>[];

  @override
  Future<NovelReaderPreferences> load() async => repository.preferences;

  @override
  Future<void> save(NovelReaderPreferences preferences) async {
    final save = _PendingPagePreferencesSave();
    saves.add(save);
    repository.upsertPreferencesCallCount += 1;
    await save.completer.future;
    repository.latestPreferences = preferences;
    repository.preferences = preferences;
  }
}

class _PendingPagePreferencesSave {
  final completer = Completer<void>();

  void complete() => completer.complete();
  void fail() => completer.completeError(StateError('preferences save failed'));
}

class _DelayedNovelReaderDocumentBuildService
    implements NovelReaderDocumentBuildService {
  _DelayedNovelReaderDocumentBuildService(this.delay);

  final Duration delay;

  @override
  Future<NovelReaderDocument> build(
    NovelReaderDocumentBuildRequest request, {
    TextConverter converter = const IdentityTextConverter(),
  }) async {
    await Future<void>.delayed(delay);
    return const DiscuzNovelReaderDocumentParser().parse(
      episodeId: request.episodeId,
      rawHtml: request.rawHtml,
      fallbackParagraphs: request.fallbackParagraphs,
    );
  }
}

class _ControlledNovelReaderSupplementalHydrationService
    implements NovelReaderSupplementalHydrationService {
  final Completer<List<NovelReaderBookmark>> _bookmarksCompleter =
      Completer<List<NovelReaderBookmark>>();
  final Completer<NovelItem?> _novelCompleter = Completer<NovelItem?>();

  @override
  Future<List<NovelReaderBookmark>> loadBookmarks({required String novelId}) {
    return _bookmarksCompleter.future;
  }

  @override
  Future<NovelItem?> loadNovel({required String novelId}) {
    return _novelCompleter.future;
  }

  void completeBookmarks(List<NovelReaderBookmark> value) {
    if (!_bookmarksCompleter.isCompleted) {
      _bookmarksCompleter.complete(value);
    }
  }

  void completeNovelTitle(String title) {
    if (!_novelCompleter.isCompleted) {
      _novelCompleter.complete(
        NovelItem(
          novelId: 'novel:49:100',
          sourceTid: '100',
          sourceFid: '49',
          title: title,
          updatedAt: DateTime(2026, 1, 1),
          episodeCount: 3,
        ),
      );
    }
  }
}
