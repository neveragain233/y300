part of 'favorite_sync_service_test.dart';

class _ControlledPostTasks implements LibraryPostIngestTaskRunner {
  _ControlledPostTasks(this.execute);
  final Future<void> Function(LibraryPostIngestTask) execute;
  @override
  bool canRun(LibraryPostIngestTask task) => true;
  @override
  Future<LibraryPostIngestTaskReport> runAll(
    List<LibraryPostIngestTask> tasks, {
    FavoriteSyncExecutionContext? executionContext,
  }) async {
    for (final task in tasks) {
      await execute(task);
    }
    return LibraryPostIngestTaskReport(completed: tasks);
  }
}

NetworkFavoriteSyncService _service({
  required FavoriteThreadDirectoryRepository remoteRepository,
  required LocalFavoriteRepository localRepository,
  FavoriteDetailContextLoader? detailContextLoader,
  ComicFavoriteIngestService? comicIngestService,
  NovelFavoriteIngestService? novelIngestService,
  FavoriteContentIngestRegistry? contentIngestRegistry,
  LibraryPostIngestTaskRunner? postIngestTaskRunner,
  ComicFavoriteAutoRefreshCoordinator? comicAutoRefreshCoordinator,
  ComicDuplicateMergeService? comicDuplicateMergeService,
  LibraryShelfRefreshBus? shelfRefreshBus,
  DownloadStorageService? downloadStorageService,
  int detailBatchLimit = 20,
  FavoriteSyncRequestGovernor Function()? governorFactory,
}) {
  final resolvedComicIngestService =
      comicIngestService ?? _FakeComicIngestService();
  final resolvedNovelIngestService =
      novelIngestService ?? _FakeNovelIngestService();
  return NetworkFavoriteSyncService(
    remoteRepository: remoteRepository,
    localRepository: localRepository,
    detailContextLoader: detailContextLoader ?? _contextLoader(),
    contentIngestRegistry:
        contentIngestRegistry ??
        _contentRegistry(
          comicIngestService: resolvedComicIngestService,
          novelIngestService: resolvedNovelIngestService,
        ),
    postIngestTaskRunner:
        postIngestTaskRunner ??
        DefaultLibraryPostIngestTaskRunner(
          comicAutoRefreshCoordinator: comicAutoRefreshCoordinator,
          comicDuplicateMergeService: comicDuplicateMergeService,
          shelfRefreshBus: shelfRefreshBus,
        ),
    shelfRefreshBus: shelfRefreshBus,
    downloadStorageService: downloadStorageService,
    detailBatchLimit: detailBatchLimit,
    governorFactory: governorFactory,
  );
}

FavoriteContentIngestRegistry _contentRegistry({
  ComicFavoriteIngestService? comicIngestService,
  NovelFavoriteIngestService? novelIngestService,
}) {
  return DefaultFavoriteContentIngestRegistry(
    comicHandler: ComicFavoriteContentIngestHandler(
      ingestService: comicIngestService ?? _FakeComicIngestService(),
    ),
    novelHandler: NovelFavoriteContentIngestHandler(
      ingestService: novelIngestService ?? _FakeNovelIngestService(),
    ),
    forumHandler: const ForumFavoriteContentIngestHandler(),
  );
}

ComicRefreshOutcomeApplier _defaultRefreshOutcomeApplier(
  LibraryShelfRefreshBus bus,
) {
  return DefaultComicRefreshOutcomeApplier(
    repository: _RecordingComicRepository(),
    firstEpisodeCoverPromoter: _RecordingCoverPromoter(),
    shelfRefreshBus: bus,
  );
}

class _FavoriteSnapshotStorageSpy implements DownloadStorageService {
  Map<String, Object?>? snapshot;

  @override
  Future<void> writeFavoritesSnapshot(Map<String, Object?> json) async {
    snapshot = json;
  }

  @override
  Future<DownloadedComicEpisode?> findDownloadedComicEpisode({
    required String workId,
    required String title,
    required String episodeId,
  }) async => null;
  @override
  Future<DownloadStorageRoot> prepareRoot() => throw UnimplementedError();
  @override
  Future<io.Directory> prepareComicDirectory({
    required String workId,
    required String title,
  }) => throw UnimplementedError();
  @override
  Future<bool> deleteComicDownloads({required String workId}) async => false;
  @override
  Future<bool> deleteNovelDownloads({required String novelId}) async => false;
  @override
  String numberedFileName({
    required int index,
    required String title,
    required String extension,
  }) => throw UnimplementedError();
  @override
  String safeFileName(String value, {String fallback = 'untitled'}) => value;
  @override
  Future<void> writeJsonAtomically(io.File file, Object? value) =>
      throw UnimplementedError();
}

class _GatedFavoriteSnapshotStorage extends _FavoriteSnapshotStorageSpy {
  final Completer<void> _started = Completer<void>();
  final Completer<void> _gate = Completer<void>();

  Future<void> get writeStarted => _started.future;

  void release([Object? error]) {
    if (error == null) {
      _gate.complete();
    } else {
      _gate.completeError(error);
    }
  }

  @override
  Future<void> writeFavoritesSnapshot(Map<String, Object?> json) async {
    await super.writeFavoritesSnapshot(json);
    _started.complete();
    await _gate.future;
  }
}

class _FakeFavoriteRepository implements FavoriteThreadDirectoryRepository {
  _FakeFavoriteRepository(this.pages);

  final Map<int, FavoriteThreadDirectoryData> pages;
  final List<int> requestedPages = <int>[];

  @override
  FavoriteThreadDirectorySourceCapabilities get capabilities =>
      _testDirectorySourceCapabilities;

  @override
  Future<
    DataReadResult<
      FavoriteThreadDirectoryData,
      FavoriteThreadDirectoryReadCapabilities
    >
  >
  load(
    FavoriteThreadDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    requestedPages.add(query.page);
    return DataReadSuccess(
      data:
          pages[query.page] ??
          _page(
            page: query.page,
            totalCount: 0,
            items: const <FavoriteThreadReference>[],
          ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _DelayedFavoriteRepository extends _FakeFavoriteRepository {
  _DelayedFavoriteRepository(super.pages);

  final Completer<void> _firstRequestStarted = Completer<void>();
  final Completer<void> _releaseGate = Completer<void>();

  Future<void> get firstRequestStarted => _firstRequestStarted.future;

  void release() {
    if (!_releaseGate.isCompleted) {
      _releaseGate.complete();
    }
  }

  @override
  Future<
    DataReadResult<
      FavoriteThreadDirectoryData,
      FavoriteThreadDirectoryReadCapabilities
    >
  >
  load(
    FavoriteThreadDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    requestedPages.add(query.page);
    if (!_firstRequestStarted.isCompleted) {
      _firstRequestStarted.complete();
    }
    await _releaseGate.future;
    return DataReadSuccess(
      data:
          pages[query.page] ??
          _page(
            page: query.page,
            totalCount: 0,
            items: const <FavoriteThreadReference>[],
          ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _InsufficientCapabilityFavoriteRepository
    extends _FakeFavoriteRepository {
  _InsufficientCapabilityFavoriteRepository(super.pages);

  @override
  FavoriteThreadDirectorySourceCapabilities get capabilities =>
      FavoriteThreadDirectorySourceCapabilities(
        values: DataCapabilitySet<FavoriteThreadDirectoryCapability>.supported(
          FavoriteThreadDirectoryCapability.values.where(
            (capability) =>
                capability != FavoriteThreadDirectoryCapability.totalItemCount,
          ),
        ),
        paginationPrecision: PaginationPrecision.exact,
      );
}

class _FailingFavoriteRepository implements FavoriteThreadDirectoryRepository {
  const _FailingFavoriteRepository(this.message);

  final String message;

  @override
  FavoriteThreadDirectorySourceCapabilities get capabilities =>
      _testDirectorySourceCapabilities;

  @override
  Future<
    DataReadResult<
      FavoriteThreadDirectoryData,
      FavoriteThreadDirectoryReadCapabilities
    >
  >
  load(
    FavoriteThreadDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    return DataReadFailure(
      kind: DataReadFailureKind.network,
      diagnosticMessage: message,
    );
  }
}

final _testDirectorySourceCapabilities =
    FavoriteThreadDirectorySourceCapabilities(
      values: DataCapabilitySet<FavoriteThreadDirectoryCapability>.supported(
        FavoriteThreadDirectoryCapability.values,
      ),
      paginationPrecision: PaginationPrecision.exact,
    );

class _FakeComicIngestService implements ComicFavoriteIngestService {
  final List<String> upsertedTids = <String>[];
  final List<String> removedWorkIds = <String>[];

  @override
  Future<String> upsertFromThreadDetail({
    required ThreadDetailData detail,
    required DateTime favoriteAddedAt,
    String? sourceTagName,
    FavoriteSyncExecutionContext? executionContext,
  }) async {
    upsertedTids.add(detail.tid);
    return 'yamibo:${detail.tid}';
  }

  @override
  Future<void> removeFromShelf({required String workId}) async {
    removedWorkIds.add(workId);
  }
}

class _SpyFavoriteContentIngestRegistry
    implements FavoriteContentIngestRegistry {
  _SpyFavoriteContentIngestRegistry({
    required FavoriteContentIngestHandler comicHandler,
    required FavoriteContentIngestHandler novelHandler,
    required FavoriteContentIngestHandler forumHandler,
  }) : _handlers = <ThreadContentKind, FavoriteContentIngestHandler>{
         ThreadContentKind.comic: comicHandler,
         ThreadContentKind.novel: novelHandler,
         ThreadContentKind.forum: forumHandler,
         ThreadContentKind.unknown: forumHandler,
       };

  final Map<ThreadContentKind, FavoriteContentIngestHandler> _handlers;
  final List<ThreadContentKind> requestedKinds = <ThreadContentKind>[];

  @override
  FavoriteContentIngestHandler handlerFor(ThreadContentKind kind) {
    requestedKinds.add(kind);
    return _handlers[kind] ?? _handlers[ThreadContentKind.forum]!;
  }
}

class _SpyFavoriteContentIngestHandler implements FavoriteContentIngestHandler {
  _SpyFavoriteContentIngestHandler({
    required this.kind,
    this.ingestWorkIdBuilder,
  });

  @override
  final ThreadContentKind kind;

  final String Function(FavoriteContentIngestRequest request)?
  ingestWorkIdBuilder;
  final List<String> ingestedTids = <String>[];
  final List<String> removedWorkIds = <String>[];

  @override
  Future<FavoriteContentIngestResult> ingest(
    FavoriteContentIngestRequest request,
  ) async {
    ingestedTids.add(request.context.detail.tid);
    return FavoriteContentIngestResult(
      kind: kind,
      workId:
          ingestWorkIdBuilder?.call(request) ??
          'work:${request.context.detail.tid}',
    );
  }

  @override
  Future<void> removeFromShelf({required String workId}) async {
    removedWorkIds.add(workId);
  }
}

class _FakeNovelIngestService implements NovelFavoriteIngestService {
  _FakeNovelIngestService({this.error});

  final Object? error;
  final List<String> upsertedTids = <String>[];
  final List<String> removedWorkIds = <String>[];

  @override
  Future<String> upsertFromThreadDetail({
    required ThreadDetailData detail,
    required DateTime favoriteAddedAt,
    String? sourceTagName,
  }) async {
    upsertedTids.add(detail.tid);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return 'novel:${detail.fid}:${detail.tid}';
  }

  @override
  Future<void> removeFromShelf({required String workId}) async {
    removedWorkIds.add(workId);
  }
}

class _BackfillRefreshService implements ComicEpisodeRefreshService {
  _BackfillRefreshService({
    required ComicEpisodeRefreshOutcome catalogOutcome,
    ComicEpisodeRefreshOutcome? searchOutcome,
  }) : _catalogOutcome = catalogOutcome,
       _searchOutcome = searchOutcome;

  final ComicEpisodeRefreshOutcome _catalogOutcome;
  final ComicEpisodeRefreshOutcome? _searchOutcome;

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogOnly(
    ComicEpisodeRefreshRequest request, {
    FavoriteSyncExecutionContext? executionContext,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    return _catalogOutcome;
  }

  @override
  Future<List<ComicEpisodeLink>> fetchEpisodeLinks(
    ComicEpisodeRefreshRequest request,
  ) async {
    return _catalogOutcome.links;
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogThenFallback(
    ComicEpisodeRefreshRequest request,
  ) async {
    return _catalogOutcome;
  }

  @override
  Future<List<ComicEpisodeLink>> fetchEpisodeLinksFromTid(String tid) async {
    return _catalogOutcome.links;
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogDirect(
    String catalogUrl, {
    FavoriteSyncExecutionContext? executionContext,
  }) async {
    return const ComicEpisodeRefreshOutcome(
      source: ComicEpisodeRefreshSource.empty,
      links: <ComicEpisodeLink>[],
    );
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchSearchAndCurrentOnly(
    ComicEpisodeRefreshRequest request, {
    FavoriteSyncExecutionContext? executionContext,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    return _searchOutcome ??
        const ComicEpisodeRefreshOutcome(
          source: ComicEpisodeRefreshSource.empty,
          links: <ComicEpisodeLink>[],
        );
  }
}

class _ThrowingRefreshService implements ComicEpisodeRefreshService {
  const _ThrowingRefreshService();

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogOnly(
    ComicEpisodeRefreshRequest request, {
    FavoriteSyncExecutionContext? executionContext,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    throw StateError('refresh failed');
  }

  @override
  Future<List<ComicEpisodeLink>> fetchEpisodeLinks(
    ComicEpisodeRefreshRequest request,
  ) async {
    throw StateError('refresh failed');
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogThenFallback(
    ComicEpisodeRefreshRequest request,
  ) async {
    throw StateError('refresh failed');
  }

  @override
  Future<List<ComicEpisodeLink>> fetchEpisodeLinksFromTid(String tid) async {
    throw StateError('refresh failed');
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogDirect(
    String catalogUrl, {
    FavoriteSyncExecutionContext? executionContext,
  }) async {
    throw StateError('refresh failed');
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchSearchAndCurrentOnly(
    ComicEpisodeRefreshRequest request, {
    FavoriteSyncExecutionContext? executionContext,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    throw StateError('refresh failed');
  }
}

class _RecordingGovernor implements FavoriteSyncRequestGovernor {
  final List<FavoriteSyncRequestKind> kinds = <FavoriteSyncRequestKind>[];

  @override
  Future<T> run<T>({
    required FavoriteSyncRequestKind kind,
    required Future<T> Function() action,
  }) async {
    kinds.add(kind);
    return action();
  }
}

class _RecordingSearchQueue implements ComicSearchRefreshQueueEnqueuer {
  final List<ComicEpisodeRefreshRequest> enqueuedRequests =
      <ComicEpisodeRefreshRequest>[];
  final List<String> enqueuedTitles = <String>[];

  @override
  Future<ComicSearchRefreshEnqueueResult> enqueue({
    required ComicEpisodeRefreshRequest request,
    required String title,
    required ComicSearchRefreshOrigin origin,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
  }) async {
    enqueuedRequests.add(request);
    enqueuedTitles.add(title);
    return ComicSearchRefreshEnqueueResult(
      entry: ComicSearchRefreshQueueEntry(
        id: enqueuedRequests.length,
        comicId: request.comicId ?? '',
        title: title,
        request: request,
        origin: origin,
        status: ComicSearchRefreshQueueStatus.pending,
        attempts: 0,
        availableAt: DateTime(2026, 5, 16),
        createdAt: DateTime(2026, 5, 16),
        updatedAt: DateTime(2026, 5, 16),
      ),
      position: enqueuedRequests.length,
      estimatedDuration: Duration(
        milliseconds: 10500 * enqueuedRequests.length,
      ),
      deduplicated: false,
    );
  }
}

class _RecordingCoverPromoter implements ComicFirstEpisodeCoverPromoter {
  @override
  Future<bool> promoteIfPossible({
    required String comicId,
    ComicThreadDiscoveryCache? threadCache,
    FavoriteSyncRequestGovernor? governor,
  }) async {
    return true;
  }
}

class _RecordingComicRepository implements ComicRepository {
  @override
  Future<ComicEpisodeRefreshResult> mergeEpisodesFromLinks({
    required String comicId,
    required List<ComicEpisodeLink> episodeLinks,
    required String fallbackSourceTid,
  }) async {
    return ComicEpisodeRefreshResult(
      insertedCount: episodeLinks.length,
      updatedCount: 0,
      totalCount: episodeLinks.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeDuplicateMergeRepository implements ComicDuplicateMergeRepository {
  _FakeDuplicateMergeRepository({required List<ComicDuplicateGroup> groups})
    : _groups = groups.toList(growable: true);

  final List<ComicDuplicateGroup> _groups;
  final List<String> mergeComicIds = <String>[];
  int mergeAllCallCount = 0;

  @override
  Future<List<ComicDuplicateGroup>> findDuplicateGroups({
    String? comicId,
  }) async {
    if (comicId == null || comicId.trim().isEmpty) {
      mergeAllCallCount++;
      return List<ComicDuplicateGroup>.unmodifiable(_groups);
    }
    mergeComicIds.add(comicId.trim());
    return _groups
        .where((group) => group.comicIds.contains(comicId.trim()))
        .toList(growable: false);
  }

  @override
  Future<ComicDuplicateMergeResult> mergeDuplicateGroup({
    required Set<String> comicIds,
  }) async {
    _groups.removeWhere((group) => group.comicIds.containsAll(comicIds));
    final target = comicIds.contains('yamibo:old')
        ? 'yamibo:old'
        : comicIds.first;
    final removed = comicIds.where((comicId) => comicId != target).toSet();
    return ComicDuplicateMergeResult(
      targetComicId: target,
      targetTitle: '短标题',
      mergedComicIds: removed,
      replacements: <String, String>{
        for (final comicId in removed) comicId: target,
      },
      movedEpisodeCount: 1,
    );
  }
}

class _ThrowingDuplicateMergeRepository
    implements ComicDuplicateMergeRepository {
  const _ThrowingDuplicateMergeRepository();

  @override
  Future<List<ComicDuplicateGroup>> findDuplicateGroups({String? comicId}) {
    throw StateError('merge failed');
  }

  @override
  Future<ComicDuplicateMergeResult> mergeDuplicateGroup({
    required Set<String> comicIds,
  }) {
    throw StateError('merge failed');
  }
}

class _MemoryLocalFavoriteRepository implements LocalFavoriteRepository {
  _MemoryLocalFavoriteRepository({
    FavoriteSyncSnapshot? snapshot,
    List<FavoriteThreadCacheRecord> seedRecords =
        const <FavoriteThreadCacheRecord>[],
  }) : _snapshot = snapshot,
       records = <String, FavoriteThreadCacheRecord>{
         for (final record in seedRecords) record.tid: record,
       };

  FavoriteSyncSnapshot? _snapshot;
  bool _comicBackfillCompleted = false;
  final Map<String, FavoriteThreadCacheRecord> records;
  final List<String> syncFailureMessages = <String>[];
  int upsertCallCount = 0;
  int markRemovedCallCount = 0;

  @override
  Future<int> countActiveThreads() async =>
      records.values.where((record) => record.isActive).length;

  @override
  Future<int> countMissingDetailRecords() async {
    return records.values
        .where((record) => record.isActive && record.needsDetail)
        .length;
  }

  @override
  Future<String> createCategory({required String name}) async => 'custom';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<void> finishSync({
    required FavoriteSyncMode mode,
    required int remoteCount,
    String? status,
    String? message,
  }) async {
    _snapshot = FavoriteSyncSnapshot(
      syncKey: favoriteSyncKey,
      remoteCount: remoteCount,
      localActiveCount: await countActiveThreads(),
      lastSyncedAt: DateTime(2026, 1, 1),
      status: status,
      message: message,
    );
  }

  @override
  Future<Set<String>> getActiveTids() async {
    return records.values
        .where((record) => record.isActive)
        .map((record) => record.tid)
        .toSet();
  }

  @override
  Future<List<FavoriteThreadCacheRecord>> getActiveThreadsForSnapshot() async {
    return records.values
        .where((record) => record.isActive)
        .toList(growable: false);
  }

  @override
  Future<bool> hasCompletedComicAutoRefreshBackfill() async {
    return _comicBackfillCompleted;
  }

  @override
  Future<void> markComicAutoRefreshBackfillCompleted({
    required int checkedCount,
    String? message,
  }) async {
    _comicBackfillCompleted = true;
  }

  @override
  Future<FavoriteThreadCacheRecord?> getActiveThreadByTid(String tid) async {
    final record = records[tid];
    return record?.isActive == true ? record : null;
  }

  @override
  Future<List<FavoriteThreadCacheRecord>> getActiveThreadsByWorkId(
    String workId,
  ) async {
    return records.values
        .where((record) => record.isActive && record.workId == workId)
        .toList(growable: false);
  }

  @override
  Future<bool> hasActiveThreadForWorkId(String workId) async {
    return records.values.any(
      (record) => record.isActive && record.workId == workId,
    );
  }

  @override
  Future<int> markRemovedByWorkId(String workId) async {
    var changed = 0;
    for (final record in records.values.toList(growable: false)) {
      if (!record.isActive || record.workId != workId) {
        continue;
      }
      records[record.tid] = _cacheRecord(
        tid: record.tid,
        title: record.title,
        contentKind: record.contentKind,
        workId: record.workId,
        sourceTagName: record.sourceTagName,
        detailLoadedAt: record.detailLoadedAt,
        detailState: record.detailState,
        removedAt: DateTime(2026, 1, 2),
      );
      changed++;
    }
    return changed;
  }

  @override
  Future<int> markRemovedByTids(Set<String> tids) async {
    var changed = 0;
    for (final tid in tids) {
      final record = records[tid];
      if (record == null || !record.isActive) {
        continue;
      }
      records[record.tid] = _cacheRecord(
        tid: record.tid,
        title: record.title,
        contentKind: record.contentKind,
        workId: record.workId,
        sourceTagName: record.sourceTagName,
        detailLoadedAt: record.detailLoadedAt,
        detailState: record.detailState,
        removedAt: DateTime(2026, 1, 2),
      );
      changed++;
    }
    return changed;
  }

  @override
  Future<List<FavoriteThreadCacheRecord>> getMissingDetailRecords({
    int limit = 20,
    Set<String> excludedTids = const <String>{},
  }) async {
    return records.values
        .where(
          (record) =>
              record.isActive &&
              record.needsDetail &&
              !excludedTids.contains(record.tid),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<FavoriteThreadCacheRecord>>
  getComicAutoRefreshBackfillCandidates({
    int limit = 20,
    Set<String> excludedTids = const <String>{},
  }) async {
    return records.values
        .where(
          (record) =>
              record.isActive &&
              record.contentKind == ThreadContentKind.comic &&
              record.workId != null &&
              record.workId!.trim().isNotEmpty &&
              !excludedTids.contains(record.tid),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<FavoriteRouteTarget?> getRouteTargetByShelfWorkId(
    String workId,
  ) async => null;

  @override
  Future<FavoriteSyncSnapshot?> getSyncSnapshot() async => _snapshot;

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems(String categoryId) async =>
      const <LibraryWorkItem>[];

  @override
  Future<List<LibraryCategory>> loadVisibleCategories() async =>
      const <LibraryCategory>[];

  @override
  Future<void> markSyncFailure(String message) async {
    syncFailureMessages.add(message);
  }

  @override
  Future<List<FavoriteThreadCacheRecord>> markRemovedTids(
    Set<String> activeRemoteTids,
  ) async {
    markRemovedCallCount += 1;
    final removed = records.values
        .where(
          (record) => record.isActive && !activeRemoteTids.contains(record.tid),
        )
        .toList(growable: false);
    for (final record in removed) {
      records[record.tid] = FavoriteThreadCacheRecord(
        tid: record.tid,
        remoteFavoriteId: record.remoteFavoriteId,
        title: record.title,
        description: record.description,
        authorName: record.authorName,
        replyCount: record.replyCount,
        favoritedAt: record.favoritedAt,
        remoteOrder: record.remoteOrder,
        sourceFid: record.sourceFid,
        sourceTypeid: record.sourceTypeid,
        sourceTagName: record.sourceTagName,
        contentKind: record.contentKind,
        workId: record.workId,
        detailLoadedAt: record.detailLoadedAt,
        detailState: record.detailState,
        firstSeenAt: record.firstSeenAt,
        lastSeenAt: record.lastSeenAt,
        removedAt: DateTime(2026, 1, 2),
        customCategoryId: record.customCategoryId,
      );
    }
    return removed;
  }

  @override
  Future<void> moveThreadToCategory({
    required String tid,
    required String toCategoryId,
  }) async {}

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async => null;

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async => const <String, List<LibraryWorkItem>>{};

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
  }) async {
    final old = records[tid]!;
    records[tid] = FavoriteThreadCacheRecord(
      tid: tid,
      remoteFavoriteId: old.remoteFavoriteId,
      title: old.title,
      description: old.description,
      authorName: old.authorName,
      replyCount: old.replyCount,
      favoritedAt: old.favoritedAt,
      remoteOrder: old.remoteOrder,
      sourceFid: fid,
      sourceTypeid: typeid,
      sourceTagName: tagName,
      contentKind: contentKind,
      workId: workId,
      detailLoadedAt: DateTime(2026, 1, 1),
      detailState: FavoriteDetailState.resolved,
      firstSeenAt: old.firstSeenAt,
      lastSeenAt: old.lastSeenAt,
      removedAt: old.removedAt,
      customCategoryId: old.customCategoryId,
    );
  }

  @override
  Future<void> markThreadDetailPending({required String tid}) async {
    final old = records[tid]!;
    records[tid] = FavoriteThreadCacheRecord(
      tid: tid,
      remoteFavoriteId: old.remoteFavoriteId,
      title: old.title,
      description: old.description,
      authorName: old.authorName,
      replyCount: old.replyCount,
      favoritedAt: old.favoritedAt,
      remoteOrder: old.remoteOrder,
      sourceFid: old.sourceFid,
      sourceTypeid: old.sourceTypeid,
      sourceTagName: old.sourceTagName,
      contentKind: old.contentKind,
      workId: old.workId,
      detailLoadedAt: old.detailLoadedAt,
      detailState: FavoriteDetailState.pending,
      firstSeenAt: old.firstSeenAt,
      lastSeenAt: old.lastSeenAt,
      removedAt: old.removedAt,
      customCategoryId: old.customCategoryId,
    );
  }

  @override
  Future<void> markThreadDetailInvalid({required String tid}) async {
    final old = records[tid]!;
    records[tid] = FavoriteThreadCacheRecord(
      tid: tid,
      remoteFavoriteId: old.remoteFavoriteId,
      title: old.title,
      description: old.description,
      authorName: old.authorName,
      replyCount: old.replyCount,
      favoritedAt: old.favoritedAt,
      remoteOrder: old.remoteOrder,
      sourceFid: old.sourceFid,
      sourceTypeid: old.sourceTypeid,
      sourceTagName: old.sourceTagName,
      contentKind: ThreadContentKind.unknown,
      workId: old.workId,
      detailLoadedAt: DateTime(2026, 1, 1),
      detailState: FavoriteDetailState.invalid,
      firstSeenAt: old.firstSeenAt,
      lastSeenAt: old.lastSeenAt,
      removedAt: old.removedAt,
      customCategoryId: old.customCategoryId,
    );
  }

  @override
  Future<int> upsertRemoteThreads(List<FavoriteThreadCacheUpsert> items) async {
    upsertCallCount += 1;
    final now = DateTime(2026, 1, 1);
    for (final item in items) {
      final old = records[item.tid];
      final restored =
          old != null &&
          (old.removedAt != null ||
              (old.remoteFavoriteId != null &&
                  item.remoteFavoriteId != null &&
                  old.remoteFavoriteId != item.remoteFavoriteId));
      records[item.tid] = FavoriteThreadCacheRecord(
        tid: item.tid,
        remoteFavoriteId: item.remoteFavoriteId,
        title: item.title,
        description: item.description,
        authorName: item.authorName,
        replyCount: item.replyCount,
        favoritedAt: item.favoritedAt,
        remoteOrder: item.remoteOrder,
        sourceFid: old?.sourceFid,
        sourceTypeid: old?.sourceTypeid,
        sourceTagName: old?.sourceTagName,
        contentKind: old?.contentKind ?? ThreadContentKind.unknown,
        workId: old?.workId,
        detailLoadedAt: old?.detailLoadedAt,
        detailState: restored
            ? FavoriteDetailState.pending
            : old?.detailState ?? FavoriteDetailState.pending,
        firstSeenAt: old?.firstSeenAt ?? now,
        lastSeenAt: now,
        removedAt: null,
        customCategoryId: old?.customCategoryId,
      );
    }
    return items.length;
  }
}

FavoriteThreadDirectoryData _page({
  required int page,
  required int totalCount,
  required List<FavoriteThreadReference> items,
}) {
  const pageSize = 2;
  final totalPages = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
  return FavoriteThreadDirectoryData(
    items: items,
    pagination: FavoriteThreadPagination(
      currentPage: page,
      pageSize: pageSize,
      totalItems: totalCount,
      totalPages: totalPages,
      hasPrevious: page > 1,
      hasNext: page < totalPages,
    ),
  );
}

FavoriteThreadReference _favoriteThread({
  required String tid,
  required String title,
}) {
  return FavoriteThreadReference(
    tid: tid,
    title: title,
    remoteFavoriteId: 'fav-$tid',
    description: '',
    authorName: '作者',
    replyCount: 0,
    favoritedAt: DateTime.fromMillisecondsSinceEpoch(
      1767225600 * Duration.millisecondsPerSecond,
      isUtc: true,
    ),
  );
}

FavoriteThreadCacheRecord _cacheRecord({
  required String tid,
  required String title,
  required ThreadContentKind contentKind,
  String? workId,
  String? sourceFid,
  String? sourceTypeid,
  String? sourceTagName,
  DateTime? detailLoadedAt,
  FavoriteDetailState? detailState,
  DateTime? removedAt,
}) {
  return FavoriteThreadCacheRecord(
    tid: tid,
    remoteFavoriteId: 'fav-$tid',
    title: title,
    replyCount: 0,
    sourceFid: sourceFid,
    sourceTypeid: sourceTypeid,
    sourceTagName: sourceTagName,
    contentKind: contentKind,
    workId: workId,
    detailLoadedAt: detailLoadedAt,
    detailState:
        detailState ??
        (detailLoadedAt == null
            ? FavoriteDetailState.pending
            : FavoriteDetailState.resolved),
    firstSeenAt: DateTime(2026, 1, 1),
    lastSeenAt: DateTime(2026, 1, 1),
    removedAt: removedAt,
  );
}

ThreadDetailData _detailForTid(String tid) {
  final fid = switch (tid) {
    '100' => '30',
    '200' => '49',
    _ => '1',
  };
  final typeid = switch (tid) {
    '100' => '398',
    '200' => '293',
    _ => '',
  };
  return ThreadDetailData(
    tid: tid,
    fid: fid,
    typeid: typeid,
    subject: '主题$tid',
    author: '作者',
    replies: 0,
    views: 1,
    currentPage: 1,
    perPage: 20,
    posts: <ThreadPost>[
      ThreadPost(
        pid: 'p1',
        author: '作者',
        authorId: '1',
        message: '<p>正文</p>',
        number: 1,
        isFirst: true,
        dateline: '2026-01-01',
      ),
    ],
  );
}

ThreadDetailData _invalidDetailForTid(String tid) {
  return ThreadDetailData(
    tid: tid,
    fid: '',
    typeid: '',
    subject: '失效主题$tid',
    author: '',
    replies: 0,
    views: 0,
    currentPage: 1,
    perPage: 20,
    posts: const <ThreadPost>[],
  );
}

ForumTagLookup _lookup({String comicTagName = '韩国漫画'}) {
  return ForumTagLookup(<ForumBoardTagSet>[
    ForumBoardTagSet(
      fid: '30',
      name: '漫画区',
      tags: <ForumTagDefinition>[
        ForumTagDefinition(fid: '30', typeid: '398', name: comicTagName),
      ],
    ),
    const ForumBoardTagSet(
      fid: '49',
      name: '文学区',
      tags: <ForumTagDefinition>[
        ForumTagDefinition(fid: '49', typeid: '293', name: '原创'),
      ],
    ),
  ]);
}

FavoriteDetailContextLoader _contextLoader({
  Future<ApiResult<ThreadDetailData>> Function(String tid)? loadThreadDetail,
  FavoriteTagLookupLoader? loadTagLookup,
}) {
  final loader =
      loadThreadDetail ?? ((tid) async => ApiSuccess(_detailForTid(tid)));
  return DefaultFavoriteDetailContextLoader(
    threadRepository: _FavoriteTestThreadRepository(loader),
    loadTagLookup: loadTagLookup ?? (() async => _lookup()),
    classifier: const ThreadContentClassifier(),
  );
}

final class _FavoriteTestThreadRepository implements ThreadRepository {
  const _FavoriteTestThreadRepository(this.loader);

  final Future<ApiResult<ThreadDetailData>> Function(String tid) loader;

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
    return dataReadResultFromApiResult(
      await loader(tid),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}
