part of 'favorite_sync_service_test.dart';

void _failureRecoveryCases() {
  test('incremental comic detail keeps ingested work id when duplicate merge fails', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 2,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '新增漫画'),
          _favoriteThread(tid: '999', title: '旧收藏'),
        ],
      ),
    });
    final local = _MemoryLocalFavoriteRepository(
      snapshot: FavoriteSyncSnapshot(
        syncKey: favoriteSyncKey,
        remoteCount: 1,
        localActiveCount: 1,
        lastSyncedAt: DateTime(2026, 1, 1),
      ),
      seedRecords: <FavoriteThreadCacheRecord>[
        _cacheRecord(
          tid: '999',
          title: '旧收藏',
          contentKind: ThreadContentKind.forum,
          workId: 'thread:999',
          detailLoadedAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    final service = _service(
      remoteRepository: remote,
      localRepository: local,
      detailContextLoader: _contextLoader(),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      comicDuplicateMergeService: const ComicDuplicateMergeService(
        repository: _ThrowingDuplicateMergeRepository(),
      ),
      detailBatchLimit: 10,
    );

    final result = await service.sync();

    expect(result.detailLoadedCount, 1);
    expect(local.records['100']?.workId, 'yamibo:100');
    expect(local.records['100']?.detailLoadedAt, isNotNull);
  });

  test('recently added comic sync refreshes target thread and queues search on catalog miss', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 2,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '新收藏漫画'),
          _favoriteThread(tid: '999', title: '旧收藏'),
        ],
      ),
    });
    final local = _MemoryLocalFavoriteRepository(
      snapshot: FavoriteSyncSnapshot(
        syncKey: favoriteSyncKey,
        remoteCount: 1,
        localActiveCount: 1,
        lastSyncedAt: DateTime(2026, 1, 1),
      ),
      seedRecords: <FavoriteThreadCacheRecord>[
        _cacheRecord(
          tid: '999',
          title: '旧收藏',
          contentKind: ThreadContentKind.forum,
          workId: 'thread:999',
          detailLoadedAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    final queue = _RecordingSearchQueue();
    final bus = LibraryShelfRefreshBus();
    addTearDown(bus.dispose);
    final reasons = <String>[];
    bus.signal.addListener(() {
      final signal = bus.signal.value;
      if (signal != null) {
        reasons.add(signal.reason);
      }
    });
    final coordinator = ComicFavoriteAutoRefreshCoordinator(
      refreshService: _BackfillRefreshService(
        catalogOutcome: const ComicEpisodeRefreshOutcome(
          source: ComicEpisodeRefreshSource.empty,
          links: <ComicEpisodeLink>[],
        ),
      ),
      searchQueue: queue,
      refreshOutcomeApplier: _defaultRefreshOutcomeApplier(bus),
      shelfRefreshBus: bus,
      catalogMissPolicy: const DefaultComicCatalogMissPolicy(),
      titleAnalyzer: const PetitComicTitleAnalyzer(),
    );
    final service = _service(
      remoteRepository: remote,
      localRepository: local,
      detailContextLoader: _contextLoader(),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      comicAutoRefreshCoordinator: coordinator,
      shelfRefreshBus: bus,
      detailBatchLimit: 10,
    );

    final result = await service.syncRecentlyAddedThread(tid: '100');

    expect(result.detailLoadedCount, 1);
    expect(queue.enqueuedRequests.single.comicId, 'yamibo:100');
    expect(local.records['100']?.contentKind, ThreadContentKind.comic);
    expect(local.records['100']?.detailLoadedAt, isNotNull);
    expect(reasons, contains('favorite_comic_search_refresh_queued'));
    expect(reasons, contains('thread_favorite_recent_sync_completed'));
    expect(bus.signal.value?.source, LibraryMutationSource.favoriteSync);
    expect(bus.signal.value?.payload['upsertedCount'], 2);
    expect(bus.signal.value?.payload['detailLoadedCount'], 1);
  });

  test(
    'recently added sync seeds target from detail when favorite list lags',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '999', title: '旧收藏'),
          ],
        ),
      });
      final local = _MemoryLocalFavoriteRepository(
        snapshot: FavoriteSyncSnapshot(
          syncKey: favoriteSyncKey,
          remoteCount: 1,
          localActiveCount: 1,
          lastSyncedAt: DateTime(2026, 1, 1),
        ),
        seedRecords: <FavoriteThreadCacheRecord>[
          _cacheRecord(
            tid: '999',
            title: '旧收藏',
            contentKind: ThreadContentKind.forum,
            workId: 'thread:999',
            detailLoadedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final queue = _RecordingSearchQueue();
      final bus = LibraryShelfRefreshBus();
      addTearDown(bus.dispose);
      final coordinator = ComicFavoriteAutoRefreshCoordinator(
        refreshService: _BackfillRefreshService(
          catalogOutcome: const ComicEpisodeRefreshOutcome(
            source: ComicEpisodeRefreshSource.empty,
            links: <ComicEpisodeLink>[],
          ),
        ),
        searchQueue: queue,
        refreshOutcomeApplier: _defaultRefreshOutcomeApplier(bus),
        shelfRefreshBus: bus,
        catalogMissPolicy: const DefaultComicCatalogMissPolicy(),
        titleAnalyzer: const PetitComicTitleAnalyzer(),
      );
      var detailLoadCount = 0;
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(
          loadThreadDetail: (tid) async {
            detailLoadCount++;
            return ApiSuccess(_detailForTid(tid));
          },
        ),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: _FakeNovelIngestService(),
        comicAutoRefreshCoordinator: coordinator,
        shelfRefreshBus: bus,
        detailBatchLimit: 10,
      );

      final result = await service.syncRecentlyAddedThread(tid: '100');

      expect(remote.requestedPages, <int>[1]);
      expect(detailLoadCount, 1);
      expect(result.detailLoadedCount, 1);
      expect(local.records['100']?.title, '主题100');
      expect(local.records['100']?.remoteFavoriteId, isNull);
      expect(local.records['100']?.favoritedAt, isNull);
      expect(local.records['100']?.contentKind, ThreadContentKind.comic);
      expect(local.records['100']?.detailLoadedAt, isNotNull);
      expect(queue.enqueuedRequests.single.comicId, 'yamibo:100');
    },
  );

  test('capability insufficiency fails before thread cache mutation', () async {
    final remote = _InsufficientCapabilityFavoriteRepository(
      <int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '100', title: '主题'),
          ],
        ),
      },
    );
    final local = _MemoryLocalFavoriteRepository();
    final service = _service(remoteRepository: remote, localRepository: local);

    await expectLater(service.sync(), throwsStateError);

    expect(local.upsertCallCount, 0);
    expect(local.markRemovedCallCount, 0);
    expect(local.records, isEmpty);
  });

  test('cross-page duplicate tid fails before thread cache mutation', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 3,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '主题一'),
          _favoriteThread(tid: '200', title: '主题二'),
        ],
      ),
      2: _page(
        page: 2,
        totalCount: 3,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '200', title: '重复主题'),
        ],
      ),
    });
    final local = _MemoryLocalFavoriteRepository();
    final service = _service(remoteRepository: remote, localRepository: local);

    await expectLater(service.sync(), throwsStateError);

    expect(local.upsertCallCount, 0);
    expect(local.markRemovedCallCount, 0);
    expect(local.records, isEmpty);
  });

  test('pagination drift fails before thread cache mutation', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 3,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '主题一'),
          _favoriteThread(tid: '200', title: '主题二'),
        ],
      ),
      2: FavoriteThreadDirectoryData(
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '300', title: '主题三'),
        ],
        pagination: const FavoriteThreadPagination(
          currentPage: 2,
          pageSize: 3,
          totalItems: 3,
          totalPages: 1,
          hasPrevious: true,
          hasNext: false,
        ),
      ),
    });
    final local = _MemoryLocalFavoriteRepository();
    final service = _service(remoteRepository: remote, localRepository: local);

    await expectLater(service.sync(), throwsStateError);

    expect(local.upsertCallCount, 0);
    expect(local.markRemovedCallCount, 0);
    expect(local.records, isEmpty);
  });
}
