part of 'novel_reader_controller_test.dart';

void _markReadingSurfaceReady(NovelReaderController controller) {
  controller.updateReadingVisibility(frontmost: true, resumed: true);
  controller.observeReadingSurface(
    bodyReady: true,
    restoreSettled: true,
    finalBoundaryKnown: false,
    atBodyEnd: false,
    wholeBodyVisible: false,
    idle: true,
    geometryIdentity: 'controller-test-body-layout',
  );
}

ProviderSubscription<AsyncValue<NovelReaderViewState>> _keepReaderAlive(
  ProviderContainer container,
  NovelReaderArgs args,
) {
  return container.listen<AsyncValue<NovelReaderViewState>>(
    novelReaderControllerProvider(args),
    (_, _) {},
  );
}

ProviderContainer _buildContainer({
  required _ControllerNovelRepository repository,
  NovelReaderPreferencesRepository? preferencesRepository,
  LibraryStateRepository? stateRepository,
  NovelReaderBootstrapService? bootstrapService,
  NovelReaderSupplementalHydrationService? supplementalHydrationService,
  NovelReaderDocumentBuildService? documentBuildService,
  NovelReaderProgressCommitter? progressCommitter,
  NovelChapterUpdateService? chapterUpdateService,
  FontLibraryService? fontService,
}) {
  return ProviderContainer(
    overrides: [
      if (fontService != null)
        fontLibraryServiceProvider.overrideWithValue(fontService),
      novelRepositoryProvider.overrideWithValue(repository),
      novelReaderPreferencesRepositoryProvider.overrideWithValue(
        preferencesRepository ??
            _ControllerNovelReaderPreferencesRepository(repository),
      ),
      novelChapterUpdateServiceProvider.overrideWithValue(
        chapterUpdateService ?? _RecordingNovelChapterUpdateService(),
      ),
      libraryStateRepositoryProvider.overrideWithValue(
        stateRepository ?? _MemoryLibraryStateRepository(),
      ),
      if (bootstrapService != null)
        novelReaderBootstrapServiceProvider.overrideWithValue(bootstrapService),
      if (supplementalHydrationService != null)
        novelReaderSupplementalHydrationServiceProvider.overrideWithValue(
          supplementalHydrationService,
        ),
      if (documentBuildService != null)
        novelReaderDocumentBuildServiceProvider.overrideWithValue(
          documentBuildService,
        ),
      if (progressCommitter != null)
        novelReaderProgressCommitterProvider.overrideWithValue(
          progressCommitter,
        ),
    ],
  );
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

NovelReaderViewState _viewState({
  required List<NovelEpisodeItem> episodes,
  required NovelEpisodeItem currentEpisode,
}) {
  return NovelReaderViewState(
    novel: null,
    episodes: episodes,
    currentEpisode: currentEpisode,
    currentContent: _content(currentEpisode.episodeId, '正文。'),
    document: _document(currentEpisode.episodeId),
    persistedPreferences: NovelReaderPreferences.defaults(),
    effectivePreferences: NovelReaderPreferences.defaults(),
    readingProgress: null,
    progressSnapshot: const NovelReaderProgressSnapshot(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
      flowMode: NovelReaderFlowMode.vertical,
      scrollOffset: 0,
      pageIndex: 0,
      progressPercent: 0,
    ),
    currentOffset: 0,
  );
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
  }) async {
    _episodeStates.removeWhere(
      (_, state) => state.moduleKey == moduleKey && state.workId == workId,
    );
  }

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

class _ControllerNovelRepository implements NovelRepository {
  _ControllerNovelRepository({
    this.readingProgress,
    NovelReaderPreferences? preferences,
  }) : preferences =
           preferences ??
           NovelReaderPreferences.defaults().copyWith(
             flowMode: NovelReaderFlowMode.vertical,
           ) {
    contentsByEpisodeId = <String, NovelChapterContent>{
      for (final episode in episodes)
        episode.episodeId: _content(
          episode.episodeId,
          '${episode.episodeTitle}正文。',
        ),
    };
  }

  final episodes = _episodes();
  late final Map<String, NovelChapterContent> contentsByEpisodeId;
  NovelReadingProgress? readingProgress;
  NovelReaderPreferences preferences;
  NovelReaderPreferences? latestPreferences;
  int upsertPreferencesCallCount = 0;
  final savedProgressEpisodeIds = <String>[];
  final bookmarks = <NovelReaderBookmark>[];

  @override
  Future<String> createCategory({required String name}) async => 'default';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<NovelShelfCategory>> getCategories() async {
    return const <NovelShelfCategory>[];
  }

  @override
  Future<NovelChapterContent?> getChapterContent({
    required String episodeId,
  }) async {
    return contentsByEpisodeId[episodeId];
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
  Future<List<NovelEpisodeItem>> getEpisodes({
    required String novelId,
    bool descending = false,
  }) async {
    return descending ? episodes.reversed.toList(growable: false) : episodes;
  }

  @override
  Future<NovelReadingProgress?> getReadingProgress({
    required String novelId,
  }) async {
    return readingProgress;
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
  Future<void> purgeWork({required String novelId}) async {}

  @override
  Future<void> removeFromShelf({required String novelId}) async {}

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
    String? paginationKey,
    double progressPercent = 0,
    bool? isProgressPercentValid,
  }) async {
    savedProgressEpisodeIds.add(episodeId);
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
      paginationKey: paginationKey,
      progressPercent: progressPercent,
      isProgressPercentValid: isProgressPercentValid,
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
    if (isBookmarked) {
      bookmarks.add(
        NovelReaderBookmark(
          bookmarkId: 'episode-bookmark:$episodeId',
          novelId: novelId,
          episodeId: episodeId,
          anchor: NovelReaderTextAnchor(episodeId: episodeId),
          title: episodeId,
          snippet: '章节书签',
          createdAt: DateTime(2026, 6, 8),
          updatedAt: DateTime(2026, 6, 8),
        ),
      );
    }
  }
}

final class _FontRepositoryForNovel implements FontLibraryRepository {
  final firstId = 'a' * 64;
  final secondId = 'b' * 64;
  late final entries = <String, ImportedFont>{
    for (final id in [firstId, secondId])
      id: ImportedFont(
        id: id,
        displayName: 'test font',
        storageFileName: '$id.ttf',
        byteLength: 1,
      ),
  };
  final _changes = StreamController<void>.broadcast(sync: true);
  bool failReads = false;

  void announceChange() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<ImportedFont>> listFonts() async => entries.values.toList();

  @override
  Future<Uint8List> readFont(String fontId) async {
    if (failReads) throw const FontLibraryException(FontLibraryFailure.storage);
    if (!entries.containsKey(fontId)) {
      throw const FontLibraryException(FontLibraryFailure.notFound);
    }
    return Uint8List(1);
  }

  @override
  Future<void> deleteFont(String fontId) async {
    entries.remove(fontId);
    _changes.add(null);
  }

  @override
  Future<ImportedFont> importFont({
    required String fileName,
    required Uint8List bytes,
  }) => throw UnimplementedError();

  @override
  Future<void> dispose() => _changes.close();
}

final class _DelayedFontRuntime implements FontRuntimeLoader {
  final _gates = <String, Completer<String>>{};
  final _started = <String, Completer<void>>{};

  Completer<String> block(String id) =>
      _gates.putIfAbsent(id, Completer<String>.new);
  Future<void> started(String id) =>
      _started.putIfAbsent(id, Completer<void>.new).future;

  @override
  Future<String> load(ImportedFont font, Uint8List bytes) {
    final began = _started.putIfAbsent(font.id, Completer<void>.new);
    if (!began.isCompleted) began.complete();
    return _gates[font.id]?.future ??
        Future.value(FontIdentity.runtimeFamily(font.id));
  }
}

class _ControllerNovelReaderPreferencesRepository
    implements NovelReaderPreferencesRepository {
  const _ControllerNovelReaderPreferencesRepository(this.repository);

  final _ControllerNovelRepository repository;

  @override
  Future<NovelReaderPreferences> load() async => repository.preferences;

  @override
  Future<void> save(NovelReaderPreferences preferences) async {
    repository.upsertPreferencesCallCount += 1;
    repository.latestPreferences = preferences;
    repository.preferences = preferences;
  }
}

class _DelayedPreferencesRepository
    implements NovelReaderPreferencesRepository {
  _DelayedPreferencesRepository(this.repository);

  final _ControllerNovelRepository repository;
  final saveGate = Completer<void>();

  @override
  Future<NovelReaderPreferences> load() async => repository.preferences;

  @override
  Future<void> save(NovelReaderPreferences preferences) async {
    repository.upsertPreferencesCallCount += 1;
    await saveGate.future;
    repository.latestPreferences = preferences;
    repository.preferences = preferences;
  }
}

class _ControlledConversionDocumentBuildService
    implements NovelReaderDocumentBuildService {
  final requests = <NovelReaderDocumentBuildRequest>[];
  final modes = <TextConversionMode>[];
  final completions = <Completer<NovelReaderDocument>>[];

  @override
  Future<NovelReaderDocument> build(
    NovelReaderDocumentBuildRequest request, {
    TextConverter converter = const IdentityTextConverter(),
  }) async {
    if (converter.mode == TextConversionMode.none) {
      return const DiscuzNovelReaderDocumentParser().parse(
        episodeId: request.episodeId,
        rawHtml: request.rawHtml,
        fallbackParagraphs: request.fallbackParagraphs,
      );
    }
    requests.add(request);
    modes.add(converter.mode);
    final completion = Completer<NovelReaderDocument>();
    completions.add(completion);
    return completion.future;
  }

  void completeAt(int index) {
    final request = requests[index];
    final parsed = const DiscuzNovelReaderDocumentParser().parse(
      episodeId: request.episodeId,
      rawHtml: request.rawHtml,
      fallbackParagraphs: request.fallbackParagraphs,
    );
    completions[index].complete(
      NovelReaderDocument(
        episodeId: parsed.episodeId,
        rawHtmlHash: parsed.rawHtmlHash,
        body: parsed.body,
        plainText: parsed.plainText,
        wordCount: parsed.wordCount,
        textConversionIdentity: modes[index].name,
      ),
    );
  }

  void failAt(int index) =>
      completions[index].completeError(StateError('conversion failed'));
}

class _SequenceNovelReaderBootstrapService
    implements NovelReaderBootstrapService {
  final contexts = <NovelReaderLoadContext>[];
  final _sequence = _HydrationSequence<NovelReaderCriticalBootstrap>();

  @override
  Future<NovelReaderCriticalBootstrap> loadCritical(
    NovelReaderLoadContext context,
  ) {
    contexts.add(context);
    return _sequence.take();
  }

  void completeAt(int index, NovelReaderCriticalBootstrap value) {
    _sequence.completeAt(index, value);
  }

  void failAt(int index, Object error) {
    _sequence.completeErrorAt(index, error);
  }
}

class _ControlledNovelReaderBootstrapService
    implements NovelReaderBootstrapService {
  _ControlledNovelReaderBootstrapService({
    required NovelReaderCriticalBootstrap initialCritical,
  }) : _initialCritical = initialCritical;

  final NovelReaderCriticalBootstrap _initialCritical;
  bool _hasServedInitialCritical = false;
  final Map<String, Completer<NovelReaderCriticalBootstrap>>
  _criticalCompleters = <String, Completer<NovelReaderCriticalBootstrap>>{};
  final Map<String, Object> _criticalFailures = <String, Object>{};

  @override
  Future<NovelReaderCriticalBootstrap> loadCritical(
    NovelReaderLoadContext context,
  ) {
    if (!_hasServedInitialCritical &&
        context.requestedEpisodeId ==
            _initialCritical.currentEpisode.episodeId) {
      _hasServedInitialCritical = true;
      return Future<NovelReaderCriticalBootstrap>.value(_initialCritical);
    }
    final failure = _criticalFailures[context.requestedEpisodeId];
    if (failure != null) {
      return Future<NovelReaderCriticalBootstrap>.error(failure);
    }
    final completer = _criticalCompleters.putIfAbsent(
      context.requestedEpisodeId,
      Completer<NovelReaderCriticalBootstrap>.new,
    );
    return completer.future;
  }

  void completeEpisodeCritical(
    String episodeId,
    NovelReaderCriticalBootstrap value,
  ) {
    _criticalCompleters.putIfAbsent(
      episodeId,
      Completer<NovelReaderCriticalBootstrap>.new,
    );
    final completer = _criticalCompleters[episodeId]!;
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  void failEpisodeCritical(String episodeId, Object error) {
    _criticalFailures[episodeId] = error;
  }
}

List<NovelEpisodeItem> _episodes() {
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

NovelChapterContent _content(String episodeId, String text) {
  return NovelChapterContent(
    episodeId: episodeId,
    rawHtml: '<p>$text</p>',
    plainText: text,
    paragraphs: <String>[text],
  );
}

NovelReaderDocument _document(String episodeId) {
  return NovelReaderDocument(
    episodeId: episodeId,
    rawHtmlHash: 'test',
    body: const RichDocument(
      blocks: <RichBlock>[
        RichTextBlock(
          anchorId: 'node-0',
          runs: <RichRun>[RichRun(text: '正文。')],
        ),
      ],
    ),
    plainText: '正文。',
    wordCount: 3,
  );
}

NovelReaderCriticalBootstrap _criticalBootstrap({
  required String episodeId,
  String paragraphText = '正文。',
  NovelReaderPreferences? preferences,
  NovelReadingProgress? readingProgress,
}) {
  final resolvedPreferences = preferences ?? NovelReaderPreferences.defaults();
  final progress = const NovelReaderProgressPolicy().fromReadingProgress(
    novelId: 'novel:49:100',
    episodeId: episodeId,
    flowMode: resolvedPreferences.flowMode,
    progress: readingProgress,
  );
  final episode = _episodes().firstWhere((item) => item.episodeId == episodeId);
  return NovelReaderCriticalBootstrap(
    episodes: _episodes(),
    currentEpisode: episode,
    currentContent: _content(episodeId, paragraphText),
    document: NovelReaderDocument(
      episodeId: episodeId,
      rawHtmlHash: 'test-$episodeId',
      body: RichDocument(
        blocks: <RichBlock>[
          RichTextBlock(
            anchorId: 'node-0',
            runs: <RichRun>[RichRun(text: paragraphText)],
          ),
        ],
      ),
      plainText: paragraphText,
      wordCount: paragraphText.length,
      textConversionIdentity: resolvedPreferences.conversionMode.name,
    ),
    persistedPreferences: resolvedPreferences,
    effectivePreferences: resolvedPreferences,
    readingProgress: readingProgress,
    progressSnapshot: progress,
    currentOffset: progress.scrollOffset,
  );
}

List<NovelReaderBookmark> _supplementalBookmarks({required String episodeId}) {
  return <NovelReaderBookmark>[
    NovelReaderBookmark(
      bookmarkId: 'episode-bookmark:$episodeId',
      novelId: 'novel:49:100',
      episodeId: episodeId,
      anchor: NovelReaderTextAnchor(episodeId: episodeId),
      title: '章节书签',
      snippet: '章节书签',
      createdAt: DateTime(2026, 6, 8),
      updatedAt: DateTime(2026, 6, 8),
    ),
  ];
}

NovelItem _supplementalNovel({String novelTitle = '测试小说'}) {
  return NovelItem(
    novelId: 'novel:49:100',
    sourceTid: '100',
    sourceFid: '49',
    title: novelTitle,
    updatedAt: DateTime(2026, 1, 1),
    episodeCount: _episodes().length,
  );
}

class _ControlledNovelReaderSupplementalHydrationService
    implements NovelReaderSupplementalHydrationService {
  final _HydrationSequence<List<NovelReaderBookmark>> _bookmarkSequence =
      _HydrationSequence<List<NovelReaderBookmark>>();
  final _HydrationSequence<NovelItem?> _novelSequence =
      _HydrationSequence<NovelItem?>();

  @override
  Future<List<NovelReaderBookmark>> loadBookmarks({required String novelId}) {
    return _bookmarkSequence.take();
  }

  @override
  Future<NovelItem?> loadNovel({required String novelId}) {
    return _novelSequence.take();
  }

  void completeInitialBookmarks(List<NovelReaderBookmark> value) {
    _bookmarkSequence.completeAt(0, value);
  }

  void failInitialBookmarks(Object error) {
    _bookmarkSequence.completeErrorAt(0, error);
  }

  void completeInitialNovel(NovelItem? value) {
    _novelSequence.completeAt(0, value);
  }
}

class _FakeNovelReaderProgressCommitter
    implements NovelReaderProgressCommitter {
  int scheduleCallCount = 0;
  int flushCallCount = 0;
  int cancelCallCount = 0;
  NovelReaderProgressSnapshot? latestScheduledSnapshot;
  NovelReaderProgressSnapshot? latestFlushedSnapshot;

  @override
  void cancel() {
    cancelCallCount += 1;
  }

  @override
  Future<void> flush(NovelReaderProgressSnapshot snapshot) async {
    flushCallCount += 1;
    latestFlushedSnapshot = snapshot;
  }

  @override
  void schedule(NovelReaderProgressSnapshot snapshot) {
    scheduleCallCount += 1;
    latestScheduledSnapshot = snapshot;
  }
}

class _GatedProgressCommitter extends _FakeNovelReaderProgressCommitter {
  _GatedProgressCommitter(this.repository);

  final _ControllerNovelRepository repository;
  final gate = Completer<void>();
  final committed = <NovelReaderProgressSnapshot>[];

  @override
  Future<void> flush(NovelReaderProgressSnapshot snapshot) async {
    flushCallCount += 1;
    latestFlushedSnapshot = snapshot;
    await gate.future;
    await repository.saveReadingProgress(
      novelId: snapshot.novelId,
      episodeId: snapshot.episodeId,
      scrollOffset: snapshot.scrollOffset,
      flowMode: snapshot.flowMode,
      pageIndex: snapshot.pageIndex,
      pageCount: snapshot.pageCount,
      anchorNodeId: snapshot.anchorNodeId,
      anchorTextOffset: snapshot.anchorTextOffset,
      anchorFormatVersion: snapshot.anchorFormatVersion,
      anchorTextIdentity: snapshot.anchorTextIdentity,
      paginationKey: snapshot.paginationKey,
      progressPercent: snapshot.progressPercent,
      isProgressPercentValid: snapshot.isProgressPercentValid,
    );
    committed.add(snapshot);
  }
}

class _GatedNovelChapterUpdateService
    extends _RecordingNovelChapterUpdateService {
  final gate = Completer<void>();
  int started = 0;

  @override
  Future<NovelChapterSyncResult> update(
    String novelId, {
    NovelChapterUpdateIntent intent = NovelChapterUpdateIntent.normal,
  }) async {
    started += 1;
    await gate.future;
    return super.update(novelId, intent: intent);
  }

  void complete({required bool fail}) {
    if (fail) {
      gate.completeError(StateError('controlled work update failure'));
    } else {
      gate.complete();
    }
  }
}

class _HydrationSequence<T> {
  final List<_PendingHydrationOutcome<T>?> _pendingOutcomes =
      <_PendingHydrationOutcome<T>?>[];
  final List<Completer<T>?> _completers = <Completer<T>?>[];
  int _nextTakeIndex = 0;

  Future<T> take() {
    final index = _nextTakeIndex++;
    _ensureIndex(index);
    final pendingOutcome = _pendingOutcomes[index];
    if (pendingOutcome != null) {
      return pendingOutcome.toFuture();
    }
    final completer = Completer<T>();
    _completers[index] = completer;
    return completer.future;
  }

  void completeAt(int index, T value) {
    _ensureIndex(index);
    final completer = _completers[index];
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
      return;
    }
    _pendingOutcomes[index] = _PendingHydrationValue<T>(value);
  }

  void completeErrorAt(int index, Object error) {
    _ensureIndex(index);
    final completer = _completers[index];
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
      return;
    }
    _pendingOutcomes[index] = _PendingHydrationError<T>(error);
  }

  void _ensureIndex(int index) {
    while (_pendingOutcomes.length <= index) {
      _pendingOutcomes.add(null);
      _completers.add(null);
    }
  }
}

abstract class _PendingHydrationOutcome<T> {
  Future<T> toFuture();
}

class _PendingHydrationValue<T> implements _PendingHydrationOutcome<T> {
  _PendingHydrationValue(this.value);

  final T value;

  @override
  Future<T> toFuture() {
    return Future<T>.value(value);
  }
}

class _PendingHydrationError<T> implements _PendingHydrationOutcome<T> {
  _PendingHydrationError(this.error);

  final Object error;

  @override
  Future<T> toFuture() {
    return Future<T>.error(error);
  }
}
