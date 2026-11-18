part of 'favorite_sync_service_test.dart';

void _snapshotCompletionCases() {
  for (final recentAdd in <bool>[false, true]) {
    final operation = recentAdd ? 'recent add' : 'regular sync';
    test(
      '$operation awaits snapshot before completion and final notification',
      () async {
        final remote = _FakeFavoriteRepository(
          <int, FavoriteThreadDirectoryData>{
            1: _page(
              page: 1,
              totalCount: 1,
              items: <FavoriteThreadReference>[
                _favoriteThread(tid: '300', title: 'forum favorite'),
              ],
            ),
          },
        );
        final local = _MemoryLocalFavoriteRepository(
          snapshot: recentAdd
              ? const FavoriteSyncSnapshot(
                  syncKey: favoriteSyncKey,
                  remoteCount: 0,
                  localActiveCount: 0,
                )
              : null,
        );
        final storage = _GatedFavoriteSnapshotStorage();
        final bus = LibraryShelfRefreshBus();
        addTearDown(bus.dispose);
        final reasons = <String>[];
        bus.signal.addListener(() {
          final signal = bus.signal.value;
          if (signal != null) reasons.add(signal.reason);
        });
        final service = _service(
          remoteRepository: remote,
          localRepository: local,
          downloadStorageService: storage,
          shelfRefreshBus: bus,
          governorFactory: _RecordingGovernor.new,
        );
        var settled = false;
        final pending =
            (recentAdd
                    ? service.syncRecentlyAddedThread(tid: '300')
                    : service.sync())
                .whenComplete(() {
                  settled = true;
                });

        await storage.writeStarted;

        expect((await local.getSyncSnapshot())?.status, 'ok');
        expect(settled, isFalse);
        expect(service.progress.value.isActive, isTrue);
        expect(reasons, isEmpty);
        expect(storage.snapshot?['schemaVersion'], 1);
        final threads = storage.snapshot!['threads'] as List<dynamic>;
        expect(threads.single['workId'], 'thread:300');

        storage.release();
        await pending;

        expect(
          service.progress.value.phase,
          FavoriteSyncProgressPhase.completed,
        );
        expect(reasons, <String>[
          recentAdd
              ? 'thread_favorite_recent_sync_completed'
              : 'favorite_sync_completed',
        ]);
      },
    );

    test(
      '$operation reports snapshot failure without final notification',
      () async {
        final remote = _FakeFavoriteRepository(
          <int, FavoriteThreadDirectoryData>{
            1: _page(
              page: 1,
              totalCount: 1,
              items: <FavoriteThreadReference>[
                _favoriteThread(tid: '300', title: 'forum favorite'),
              ],
            ),
          },
        );
        final local = _MemoryLocalFavoriteRepository(
          snapshot: recentAdd
              ? const FavoriteSyncSnapshot(
                  syncKey: favoriteSyncKey,
                  remoteCount: 0,
                  localActiveCount: 0,
                )
              : null,
        );
        final storage = _GatedFavoriteSnapshotStorage();
        final bus = LibraryShelfRefreshBus();
        addTearDown(bus.dispose);
        final service = _service(
          remoteRepository: remote,
          localRepository: local,
          downloadStorageService: storage,
          shelfRefreshBus: bus,
          governorFactory: _RecordingGovernor.new,
        );
        final pending = recentAdd
            ? service.syncRecentlyAddedThread(tid: '300')
            : service.sync();
        await storage.writeStarted;
        final failure = StateError('snapshot storage unavailable');
        final checked = expectLater(pending, throwsA(same(failure)));

        storage.release(failure);
        await checked;

        expect(service.progress.value.phase, FavoriteSyncProgressPhase.failed);
        expect(local.syncFailureMessages, hasLength(1));
        expect(local.records['300']?.detailState, FavoriteDetailState.resolved);
        expect(bus.signal.value, isNull);
        expect(remote.requestedPages, <int>[1]);
      },
    );
  }

  test('writes favorites snapshot to download storage after sync', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 1,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '漫画'),
        ],
      ),
    });
    final storage = _FavoriteSnapshotStorageSpy();
    final service = _service(
      remoteRepository: remote,
      localRepository: _MemoryLocalFavoriteRepository(),
      detailContextLoader: _contextLoader(),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      downloadStorageService: storage,
      detailBatchLimit: 10,
    );

    await service.sync();

    expect(storage.snapshot?['remoteCount'], 1);
    final threads = storage.snapshot?['threads'] as List<dynamic>;
    expect(threads.single['tid'], '100');
    expect(threads.single['contentKind'], 'comic');
  });

  test(
    'first full sync runs comic duplicate merge once after details load',
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
      final duplicateRepository = _FakeDuplicateMergeRepository(
        groups: const <ComicDuplicateGroup>[
          ComicDuplicateGroup(
            comicIds: <String>{'yamibo:100', 'yamibo:old'},
            sharedTids: <String>{'100'},
          ),
        ],
      );
      final bus = LibraryShelfRefreshBus();
      addTearDown(bus.dispose);
      final reasons = <String>[];
      bus.signal.addListener(() {
        final signal = bus.signal.value;
        if (signal != null) {
          reasons.add(signal.reason);
        }
      });
      final service = _service(
        remoteRepository: remote,
        localRepository: _MemoryLocalFavoriteRepository(),
        detailContextLoader: _contextLoader(),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: _FakeNovelIngestService(),
        comicDuplicateMergeService: ComicDuplicateMergeService(
          repository: duplicateRepository,
        ),
        shelfRefreshBus: bus,
        detailBatchLimit: 10,
      );

      await service.sync();

      expect(duplicateRepository.mergeAllCallCount, 2);
      expect(duplicateRepository.mergeComicIds, isEmpty);
      expect(
        reasons,
        contains('favorite_first_sync_comic_duplicate_merge_completed'),
      );
      expect(bus.signal.value?.reason, 'favorite_sync_completed');
      expect(bus.signal.value?.source, LibraryMutationSource.favoriteSync);
    },
  );

  test('incremental comic detail stores merged target work id', () async {
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
    final duplicateRepository = _FakeDuplicateMergeRepository(
      groups: const <ComicDuplicateGroup>[
        ComicDuplicateGroup(
          comicIds: <String>{'yamibo:100', 'yamibo:old'},
          sharedTids: <String>{'100'},
        ),
      ],
    );
    final service = _service(
      remoteRepository: remote,
      localRepository: local,
      detailContextLoader: _contextLoader(),
      comicIngestService: _FakeComicIngestService(),
      novelIngestService: _FakeNovelIngestService(),
      comicDuplicateMergeService: ComicDuplicateMergeService(
        repository: duplicateRepository,
      ),
      detailBatchLimit: 10,
    );

    final result = await service.sync();

    expect(result.mode, FavoriteSyncMode.incremental);
    expect(duplicateRepository.mergeAllCallCount, 0);
    expect(duplicateRepository.mergeComicIds, <String>['yamibo:100']);
    expect(local.records['100']?.workId, 'yamibo:old');
  });
}
