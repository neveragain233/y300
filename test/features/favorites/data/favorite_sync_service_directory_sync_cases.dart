part of 'favorite_sync_service_test.dart';

void _directorySyncCases() {
  for (final removedWhileWaiting in [false, true]) {
    test(
      'historical maintenance yields between records and rechecks membership (removed=$removedWhileWaiting)',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        final events = <String>[];
        final local = _MemoryLocalFavoriteRepository(
          seedRecords: [
            for (final tid in ['100', '200'])
              _cacheRecord(
                tid: tid,
                title: 'Historical comic',
                contentKind: ThreadContentKind.comic,
                workId: 'yamibo:$tid',
                detailLoadedAt: DateTime(2026, 1, 1),
              ),
            _cacheRecord(
              tid: '300',
              title: 'Foreground',
              contentKind: ThreadContentKind.unknown,
            ),
          ],
        );
        final tasks = _ControlledPostTasks((task) async {
          if (task is ComicAutoRefreshBackfillTask) {
            events.add('backfill${task.sourceTid}');
            if (task.sourceTid == '100') {
              entered.complete();
              await release.future;
            }
          }
        });
        final service = _service(
          remoteRepository: _FakeFavoriteRepository(const {}),
          localRepository: local,
          postIngestTaskRunner: tasks,
          detailContextLoader: _contextLoader(
            loadThreadDetail: (tid) async {
              events.add('detail$tid');
              if (removedWhileWaiting) await local.markRemovedByTids({'200'});
              return ApiSuccess(_detailForTid(tid));
            },
          ),
        );
        final maintenance = service.runBackgroundMaintenance();
        await entered.future;
        final foreground = service.parseThread(
          const FavoriteParseTarget(tid: '300'),
          isCurrent: () async => true,
        );
        release.complete();
        await Future.wait([maintenance, foreground]);
        expect(
          events,
          removedWhileWaiting
              ? ['backfill100', 'detail300']
              : ['backfill100', 'detail300', 'backfill200'],
        );
      },
    );
  }

  test(
    'first sync fetches all pages and ingests comic and novel details',
    () async {
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
      final local = _MemoryLocalFavoriteRepository();
      final comicIngest = _FakeComicIngestService();
      final novelIngest = _FakeNovelIngestService();
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(),
        comicIngestService: comicIngest,
        novelIngestService: novelIngest,
        detailBatchLimit: 10,
      );

      final result = await service.sync();

      expect(remote.requestedPages, <int>[1, 2]);
      expect(result.mode, FavoriteSyncMode.fullDiff);
      expect(result.detailLoadedCount, 3);
      expect(comicIngest.upsertedTids, <String>['100']);
      expect(novelIngest.upsertedTids, <String>['200']);
      expect(local.records['300']?.contentKind, ThreadContentKind.forum);
    },
  );

  test(
    'first sync classifies empty postlist as a completed invalid detail',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '404', title: '失效收藏'),
          ],
        ),
      });
      final local = _MemoryLocalFavoriteRepository();
      final comicIngest = _FakeComicIngestService();
      final novelIngest = _FakeNovelIngestService();
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(
          loadThreadDetail: (tid) async =>
              ApiSuccess(_invalidDetailForTid(tid)),
        ),
        comicIngestService: comicIngest,
        novelIngestService: novelIngest,
        detailBatchLimit: 10,
      );

      final result = await service.sync();

      expect(result.mode, FavoriteSyncMode.fullDiff);
      expect(result.detailLoadedCount, 1);
      expect(result.failedDetailTids, isEmpty);
      expect(local.records['404']?.detailState, FavoriteDetailState.invalid);
      expect(local.records['404']?.contentKind, ThreadContentKind.unknown);
      expect(local.records['404']?.workId, isNull);
      expect(comicIngest.upsertedTids, isEmpty);
      expect(novelIngest.upsertedTids, isEmpty);
    },
  );

  test(
    'incremental sync persists invalid detail without retrying it',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 2,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '404', title: '新增失效收藏'),
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
      var detailLoadCount = 0;
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(
          loadThreadDetail: (tid) async {
            detailLoadCount++;
            return ApiSuccess(_invalidDetailForTid(tid));
          },
        ),
        detailBatchLimit: 10,
      );

      final first = await service.sync();
      final second = await service.sync();

      expect(first.mode, FavoriteSyncMode.incremental);
      expect(first.failedDetailTids, isEmpty);
      expect(second.failedDetailTids, isEmpty);
      expect(local.records['404']?.detailState, FavoriteDetailState.invalid);
      expect(detailLoadCount, 1);
    },
  );

  test('recently added sync accepts an empty postlist as invalid', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 2,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '404', title: '刚收藏的失效帖'),
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
      detailContextLoader: _contextLoader(
        loadThreadDetail: (tid) async => ApiSuccess(_invalidDetailForTid(tid)),
      ),
      detailBatchLimit: 10,
    );

    final result = await service.syncRecentlyAddedThread(tid: '404');

    expect(result.failedDetailTids, isEmpty);
    expect(result.detailLoadedCount, 1);
    expect(local.records['404']?.detailState, FavoriteDetailState.invalid);
  });

  test(
    'first sync creates and uses bootstrap governor when snapshot is null',
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
      final governor = _RecordingGovernor();
      final local = _MemoryLocalFavoriteRepository();
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        governorFactory: () => governor,
        detailBatchLimit: 10,
      );

      await service.sync();

      expect(
        governor.kinds,
        containsAll(<FavoriteSyncRequestKind>[
          FavoriteSyncRequestKind.favoriteListPage,
          FavoriteSyncRequestKind.favoriteThreadDetail,
        ]),
      );
    },
  );

  test('incremental sync is also governed when snapshot exists', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 1,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '漫画'),
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
          tid: '100',
          title: '漫画',
          contentKind: ThreadContentKind.comic,
          workId: 'yamibo:100',
          detailLoadedAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    var created = 0;
    final service = _service(
      remoteRepository: remote,
      localRepository: local,
      governorFactory: () {
        created++;
        return _RecordingGovernor();
      },
      detailBatchLimit: 10,
    );

    await service.sync();

    // Subsequent (incremental) sync must be paced too, to avoid IP bans:
    // it creates a governor and routes the favorite list request through it.
    expect(created, 1);
  });

  test(
    'syncRecentlyAddedThread is governed (paced) even when snapshot is null',
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
      final governor = _RecordingGovernor();
      final service = _service(
        remoteRepository: remote,
        localRepository: _MemoryLocalFavoriteRepository(),
        governorFactory: () => governor,
        detailBatchLimit: 10,
      );

      await service.syncRecentlyAddedThread(tid: '100');

      // Manual recent-add must also be paced through the governor.
      expect(
        governor.kinds,
        containsAll(<FavoriteSyncRequestKind>[
          FavoriteSyncRequestKind.favoriteListPage,
          FavoriteSyncRequestKind.favoriteThreadDetail,
        ]),
      );
    },
  );

  test(
    'concurrent first sync joins single inflight run and governor',
    () async {
      final remote = _DelayedFavoriteRepository(
        <int, FavoriteThreadDirectoryData>{
          1: _page(
            page: 1,
            totalCount: 1,
            items: <FavoriteThreadReference>[
              _favoriteThread(tid: '100', title: '漫画'),
            ],
          ),
        },
      );
      var governorCreated = 0;
      final governor = _RecordingGovernor();
      final service = _service(
        remoteRepository: remote,
        localRepository: _MemoryLocalFavoriteRepository(),
        governorFactory: () {
          governorCreated++;
          return governor;
        },
        detailBatchLimit: 10,
      );

      final first = service.sync();
      await remote.firstRequestStarted;
      final second = service.sync();
      remote.release();

      await Future.wait(<Future<FavoriteSyncResult>>[first, second]);

      expect(remote.requestedPages, <int>[1]);
      expect(governorCreated, 1);
      expect(
        governor.kinds
            .where((kind) => kind == FavoriteSyncRequestKind.favoriteListPage)
            .length,
        1,
      );
    },
  );

  test('sync starts a new run after previous inflight settles', () async {
    final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
      1: _page(
        page: 1,
        totalCount: 1,
        items: <FavoriteThreadReference>[
          _favoriteThread(tid: '100', title: '漫画'),
        ],
      ),
    });
    final service = _service(
      remoteRepository: remote,
      localRepository: _MemoryLocalFavoriteRepository(),
      detailBatchLimit: 10,
    );

    await service.sync();
    await service.sync();

    expect(remote.requestedPages, <int>[1, 1]);
  });

  test('remote list failure fails sync before detail ingestion', () async {
    final local = _MemoryLocalFavoriteRepository();
    final comicIngest = _FakeComicIngestService();
    final novelIngest = _FakeNovelIngestService();
    var detailLoadCount = 0;
    final service = _service(
      remoteRepository: const _FailingFavoriteRepository('远端失败'),
      localRepository: local,
      detailContextLoader: _contextLoader(
        loadThreadDetail: (tid) async {
          detailLoadCount++;
          return ApiSuccess(_detailForTid(tid));
        },
      ),
      comicIngestService: comicIngest,
      novelIngestService: novelIngest,
    );

    await expectLater(
      service.sync(),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', '远端失败'),
      ),
    );

    expect(detailLoadCount, 0);
    expect(comicIngest.upsertedTids, isEmpty);
    expect(novelIngest.upsertedTids, isEmpty);
    expect(local.syncFailureMessages, <String>['远端失败']);
  });

  test(
    'count decrease does full diff and removes disappeared module shelf items',
    () async {
      final remote = _FakeFavoriteRepository(<int, FavoriteThreadDirectoryData>{
        1: _page(
          page: 1,
          totalCount: 1,
          items: <FavoriteThreadReference>[
            _favoriteThread(tid: '100', title: '保留'),
          ],
        ),
      });
      final local = _MemoryLocalFavoriteRepository(
        snapshot: FavoriteSyncSnapshot(
          syncKey: favoriteSyncKey,
          remoteCount: 2,
          localActiveCount: 2,
          lastSyncedAt: DateTime(2026, 1, 1),
        ),
        seedRecords: <FavoriteThreadCacheRecord>[
          _cacheRecord(
            tid: '100',
            title: '保留',
            contentKind: ThreadContentKind.comic,
            workId: 'yamibo:100',
          ),
          _cacheRecord(
            tid: '200',
            title: '移除',
            contentKind: ThreadContentKind.novel,
            workId: 'novel:49:200',
          ),
        ],
      );
      final novelIngest = _FakeNovelIngestService();
      final service = _service(
        remoteRepository: remote,
        localRepository: local,
        detailContextLoader: _contextLoader(),
        comicIngestService: _FakeComicIngestService(),
        novelIngestService: novelIngest,
        detailBatchLimit: 10,
      );

      final result = await service.sync();

      expect(result.mode, FavoriteSyncMode.fullDiff);
      expect(result.removedRecords.map((record) => record.tid), <String>[
        '200',
      ]);
      expect(novelIngest.removedWorkIds, <String>['novel:49:200']);
    },
  );
}
