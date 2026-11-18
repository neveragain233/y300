part of 'favorite_sync_service_test.dart';

void _detailIngestCases() {
  test(
    'removes disappeared shelf items via content ingest registry handlers',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 0,
          items: const <FavoriteThreadReference>[],
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
            tid: '100',
            title: '移除漫画',
            contentKind: ThreadContentKind.comic,
            workId: 'yamibo:100',
            detailLoadedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final comicHandler = _SpyFavoriteContentIngestHandler(
        kind: ThreadContentKind.comic,
      );
      final registry = _SpyFavoriteContentIngestRegistry(
        comicHandler: comicHandler,
        novelHandler: _SpyFavoriteContentIngestHandler(
          kind: ThreadContentKind.novel,
        ),
        forumHandler: _SpyFavoriteContentIngestHandler(
          kind: ThreadContentKind.forum,
        ),
      );
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        contentIngestRegistry: registry,
        detailContextLoader: _contextLoader(
          loadThreadDetail: (tid) =>
              throw StateError('detail should not be loaded during removal'),
        ),
        detailBatchLimit: 10,
      );

      await service.sync();

      expect(registry.requestedKinds, contains(ThreadContentKind.comic));
      expect(comicHandler.removedWorkIds, <String>['yamibo:100']);
    },
  );

  test('writes handler returned work id back to local favorite meta', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 1,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '漫画'),
        ],
      ),
    });
    final local = _MemoryLocalFavoriteRepository();
    final comicHandler = _SpyFavoriteContentIngestHandler(
      kind: ThreadContentKind.comic,
      ingestWorkIdBuilder: (request) => 'merged:${request.context.detail.tid}',
    );
    final registry = _SpyFavoriteContentIngestRegistry(
      comicHandler: comicHandler,
      novelHandler: _SpyFavoriteContentIngestHandler(
        kind: ThreadContentKind.novel,
      ),
      forumHandler: _SpyFavoriteContentIngestHandler(
        kind: ThreadContentKind.forum,
      ),
    );
    final service = _service(
      remoteRepository: remote,
      localRepository: local,
      contentIngestRegistry: registry,
      detailContextLoader: _contextLoader(),
      detailBatchLimit: 10,
    );

    final result = await service.sync();

    expect(result.detailLoadedCount, 1);
    expect(comicHandler.ingestedTids, <String>['100']);
    expect(local.records['100']?.workId, 'merged:100');
    expect(local.records['100']?.contentKind, ThreadContentKind.comic);
  });

  test(
    'detail failure does not block following missing records in same sync',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 2,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '100', title: '坏记录'),
            _favoriteThread(tid: '200', title: '小说'),
          ],
        ),
      });
      final local = _MemoryLocalFavoriteRepository();
      final novelIngest = _FakeNovelIngestService();
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(
          loadThreadDetail: (tid) async {
            if (tid == '100') {
              return const ApiFailure<ThreadDetailData>(
                ApiError(type: ApiErrorType.network, message: '网络错误'),
              );
            }
            return ApiSuccess(_detailForTid(tid));
          },
        ),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: novelIngest,
        detailBatchLimit: 1,
      );

      final result = await service.sync();

      expect(result.failedDetailTids, <String>['100']);
      expect(result.detailLoadedCount, 1);
      expect(novelIngest.upsertedTids, <String>['200']);
      expect(local.records['100']?.detailLoadedAt, isNull);
      expect(local.records['200']?.detailLoadedAt, isNotNull);
    },
  );

  test(
    'novel metadata ingest failure remains missing and retries next sync',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '200', title: '小说'),
          ],
        ),
      });
      final local = _MemoryLocalFavoriteRepository();
      final novelIngest = _FakeNovelIngestService(
        error: const FormatException('publisher id missing'),
      );
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        novelIngestService: novelIngest,
      );

      final first = await service.sync();
      final second = await service.sync();

      expect(first.failedDetailTids, <String>['200']);
      expect(second.failedDetailTids, <String>['200']);
      expect(local.records['200']?.detailLoadedAt, isNull);
      expect(novelIngest.upsertedTids, <String>['200', '200']);
    },
  );

  test('emits list and detail progress during first full sync', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 3,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '漫画'),
          _favoriteThread(tid: '200', title: '小说'),
        ],
      ),
      2: _page(
        page: 2,
        totalCount: 3,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '300', title: '普通帖'),
        ],
      ),
    });
    final service = _service(
      remoteRepository: remote,
      localRepository: _MemoryLocalFavoriteRepository(),
      detailContextLoader: _contextLoader(),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      detailBatchLimit: 10,
    );
    final emitted = <FavoriteSyncProgress>[];
    void listener() {
      emitted.add(service.progress.value);
    }

    service.progress.addListener(listener);
    addTearDown(() => service.progress.removeListener(listener));

    await service.sync();

    expect(
      emitted.map((progress) => progress.phase),
      containsAll(<FavoriteSyncProgressPhase>[
        FavoriteSyncProgressPhase.fetchingList,
        FavoriteSyncProgressPhase.savingList,
        FavoriteSyncProgressPhase.loadingDetails,
        FavoriteSyncProgressPhase.completed,
      ]),
    );
    expect(
      emitted.any(
        (progress) =>
            progress.phase == FavoriteSyncProgressPhase.fetchingList &&
            progress.total == 2,
      ),
      isTrue,
    );
    final parsingProgress = emitted
        .where(
          (progress) =>
              progress.phase == FavoriteSyncProgressPhase.loadingDetails &&
              progress.subject == '漫画',
        )
        .toList(growable: false);
    expect(parsingProgress.first.subject, '漫画');
    expect(parsingProgress.first.current, 1);
    expect(parsingProgress.first.total, 3);
    expect(service.progress.value.isActive, isFalse);
  });

  test('novel metadata ingest notifies novel and favorite shelves', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 1,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '200', title: '小说'),
        ],
      ),
    });
    final novelIngest = _FakeNovelIngestService();
    final bus = LibraryShelfRefreshBus();
    addTearDown(bus.dispose);
    final signals = <LibraryShelfRefreshSignal>[];
    bus.signal.addListener(() {
      final signal = bus.signal.value;
      if (signal != null) {
        signals.add(signal);
      }
    });
    final service = _service(
      remoteRepository: remote,
      localRepository: _MemoryLocalFavoriteRepository(),
      detailContextLoader: _contextLoader(),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: novelIngest,
      shelfRefreshBus: bus,
      detailBatchLimit: 10,
    );

    await service.sync();

    expect(novelIngest.upsertedTids, <String>['200']);
    expect(
      signals.any(
        (signal) =>
            signal.reason == 'favorite_novel_refresh_completed' &&
            signal.modules.contains(LibraryModuleKey.novel) &&
            signal.modules.contains(LibraryModuleKey.favorite) &&
            signal.source == LibraryMutationSource.novelRefresh &&
            signal.workId == 'novel:49:200' &&
            signal.tid == '200',
      ),
      isTrue,
    );
    expect(bus.signal.value?.reason, 'favorite_sync_completed');
    expect(bus.signal.value?.source, LibraryMutationSource.favoriteSync);
    expect(bus.signal.value?.payload['upsertedCount'], 1);
    expect(bus.signal.value?.payload['removedCount'], 0);
    expect(bus.signal.value?.payload['detailLoadedCount'], 1);
  });

  test(
    'first sync queues catalog miss search when comic tag is long-running',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '100', title: '[Fav] Long Comic EP 02'),
          ],
        ),
      });
      final queue = _RecordingSearchQueue();
      final bus = LibraryShelfRefreshBus();
      addTearDown(bus.dispose);
      final signals = <LibraryShelfRefreshSignal>[];
      bus.signal.addListener(() {
        final signal = bus.signal.value;
        if (signal != null) {
          signals.add(signal);
        }
      });
      final coordinator = ComicFavoriteAutoRefreshCoordinator(
        refreshService: _BackfillRefreshService(
          catalogOutcome: const ComicEpisodeRefreshOutcome(
            source: ComicEpisodeRefreshSource.empty,
            links: <ComicEpisodeLink>[],
          ),
          searchOutcome: const ComicEpisodeRefreshOutcome(
            source: ComicEpisodeRefreshSource.search,
            links: <ComicEpisodeLink>[
              ComicEpisodeLink(
                url: 'thread-201-1-1.html',
                rawText: 'Episode 2',
              ),
            ],
            usedSearch: true,
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
        localRepository: _MemoryLocalFavoriteRepository(),
        detailContextLoader: _contextLoader(
          loadTagLookup: () async => _lookup(comicTagName: _longRunningTagName),
        ),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: _FakeNovelIngestService(),
        comicAutoRefreshCoordinator: coordinator,
        detailBatchLimit: 10,
      );

      await service.sync();

      // 旧路径在 bootstrapInitial 下走内联搜索；新路径下所有 catalog 未命中
      // 都走持久化等待队列，由 ForumSearchReadScheduler 控制节奏，并通过队列快照
      // 驱动通知栏。
      expect(queue.enqueuedRequests, hasLength(1));
      expect(
        signals.any(
          (signal) => signal.reason == 'favorite_comic_search_refresh_queued',
        ),
        isTrue,
      );
      expect(
        signals.any(
          (signal) =>
              signal.reason == 'favorite_comic_catalog_miss_search_skipped',
        ),
        isFalse,
      );
    },
  );

  test(
    'first sync skips catalog miss search for non long-running comic tag',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '100', title: '[Fav] Short Comic EP 02'),
          ],
        ),
      });
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
      final service = _service(
        remoteRepository: remote,
        localRepository: _MemoryLocalFavoriteRepository(),
        detailContextLoader: _contextLoader(),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: _FakeNovelIngestService(),
        comicAutoRefreshCoordinator: coordinator,
        detailBatchLimit: 10,
      );

      await service.sync();

      expect(queue.enqueuedRequests, isEmpty);
    },
  );

  test(
    'comic auto refresh failure still marks favorite detail loaded',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '100', title: '漫画'),
          ],
        ),
      });
      final bus = LibraryShelfRefreshBus();
      addTearDown(bus.dispose);
      final coordinator = ComicFavoriteAutoRefreshCoordinator(
        refreshService: const _ThrowingRefreshService(),
        searchQueue: _RecordingSearchQueue(),
        refreshOutcomeApplier: _defaultRefreshOutcomeApplier(bus),
        shelfRefreshBus: bus,
        catalogMissPolicy: const DefaultComicCatalogMissPolicy(),
        titleAnalyzer: const PetitComicTitleAnalyzer(),
      );
      final local = _MemoryLocalFavoriteRepository();
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: _FakeNovelIngestService(),
        comicAutoRefreshCoordinator: coordinator,
        detailBatchLimit: 10,
      );

      final result = await service.sync();

      expect(result.detailLoadedCount, 1);
      expect(local.records['100']?.contentKind, ThreadContentKind.comic);
      expect(local.records['100']?.workId, 'yamibo:100');
      expect(local.records['100']?.detailLoadedAt, isNotNull);
    },
  );

  test('background maintenance queues already-loaded comic favorites for auto refresh', () async {
    final local = _MemoryLocalFavoriteRepository(
      seedRecords: <FavoriteThreadCacheRecord>[
        _cacheRecord(
          tid: '100',
          title: '[Fav] Backfill Comic EP 02',
          contentKind: ThreadContentKind.comic,
          workId: 'yamibo:100',
          detailLoadedAt: DateTime(2026, 1, 1),
          sourceTagName: _longRunningTagName,
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
    final service = _service(
      remoteRepository: _FakeFavoriteRepository(
        const <int, FavoriteThreadDirectoryData>{},
      ),
      localRepository: local,
      detailContextLoader: _contextLoader(
        loadThreadDetail: (tid) =>
            throw StateError('detail should not be loaded'),
      ),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      comicAutoRefreshCoordinator: coordinator,
    );

    await service.runBackgroundMaintenance();

    expect(queue.enqueuedTitles, <String>['Backfill Comic']);
    expect(queue.enqueuedRequests.single.comicId, 'yamibo:100');
    expect(queue.enqueuedRequests.single.sourceTid, '100');
    expect(queue.enqueuedRequests.single.displayTitle, 'Backfill Comic');
    expect(queue.enqueuedRequests.single.sourceTitle, 'Backfill Comic');
    expect(await local.hasCompletedComicAutoRefreshBackfill(), isTrue);
  });

  test('background maintenance queues long-running comic by type id when tag name is missing', () async {
    final local = _MemoryLocalFavoriteRepository(
      seedRecords: <FavoriteThreadCacheRecord>[
        _cacheRecord(
          tid: '100',
          title: '[Fav] Long Running Backfill EP 02',
          contentKind: ThreadContentKind.comic,
          workId: 'yamibo:100',
          sourceFid: '30',
          sourceTypeid: '69',
          sourceTagName: null,
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
    final service = _service(
      remoteRepository: _FakeFavoriteRepository(
        const <int, FavoriteThreadDirectoryData>{},
      ),
      localRepository: local,
      detailContextLoader: _contextLoader(
        loadThreadDetail: (tid) =>
            throw StateError('detail should not be loaded'),
      ),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      comicAutoRefreshCoordinator: coordinator,
    );

    await service.runBackgroundMaintenance();

    expect(queue.enqueuedRequests, hasLength(1));
    expect(queue.enqueuedRequests.single.comicId, 'yamibo:100');
    expect(queue.enqueuedRequests.single.sourceTid, '100');
  });

  test('background maintenance leaves backfill unfinished when runner cannot execute backfill task', () async {
    final local = _MemoryLocalFavoriteRepository(
      seedRecords: <FavoriteThreadCacheRecord>[
        _cacheRecord(
          tid: '100',
          title: '[Fav] Backfill Comic EP 02',
          contentKind: ThreadContentKind.comic,
          workId: 'yamibo:100',
          detailLoadedAt: DateTime(2026, 1, 1),
          sourceTagName: _longRunningTagName,
        ),
      ],
    );
    final service = _service(
      remoteRepository: _FakeFavoriteRepository(
        const <int, FavoriteThreadDirectoryData>{},
      ),
      localRepository: local,
      detailContextLoader: _contextLoader(
        loadThreadDetail: (tid) =>
            throw StateError('detail should not be loaded'),
      ),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      // Intentionally omit comicAutoRefreshCoordinator so the default runner
      // cannot execute ComicAutoRefreshBackfillTask.
    );

    await service.runBackgroundMaintenance();

    expect(await local.hasCompletedComicAutoRefreshBackfill(), isFalse);
  });

  test('background maintenance leaves backfill unfinished when no candidates exist', () async {
    final local = _MemoryLocalFavoriteRepository();
    final bus = LibraryShelfRefreshBus();
    addTearDown(bus.dispose);
    final coordinator = ComicFavoriteAutoRefreshCoordinator(
      refreshService: _BackfillRefreshService(
        catalogOutcome: const ComicEpisodeRefreshOutcome(
          source: ComicEpisodeRefreshSource.empty,
          links: <ComicEpisodeLink>[],
        ),
      ),
      searchQueue: _RecordingSearchQueue(),
      refreshOutcomeApplier: _defaultRefreshOutcomeApplier(bus),
      shelfRefreshBus: bus,
      catalogMissPolicy: const DefaultComicCatalogMissPolicy(),
      titleAnalyzer: const PetitComicTitleAnalyzer(),
    );
    final service = _service(
      remoteRepository: _FakeFavoriteRepository(
        const <int, FavoriteThreadDirectoryData>{},
      ),
      localRepository: local,
      detailContextLoader: _contextLoader(
        loadThreadDetail: (tid) =>
            throw StateError('detail should not be loaded'),
      ),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      comicAutoRefreshCoordinator: coordinator,
    );

    await service.runBackgroundMaintenance();

    expect(await local.hasCompletedComicAutoRefreshBackfill(), isFalse);
  });
}
