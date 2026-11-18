part of 'comic_detail_adapter_test.dart';

void _refreshDiscoveryCases() {
  test(
    'refreshWork uses catalog fast path when catalogUrl is persisted',
    () async {
      final repository = _FakeComicRepository(
        catalogUrl: 'https://example.com/catalog',
      );
      final refreshService = _FakeComicEpisodeRefreshService();
      final queue = _RecordingSearchQueue();
      final applier = _RecordingRefreshOutcomeApplier();
      final adapter = ComicDetailAdapter(
        repository,
        refreshService: refreshService,
        searchQueue: queue,
        refreshOutcomeApplier: applier,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final result = await adapter.refreshWork(workId: 'comic:1');

      expect(result.status, DetailRefreshStatus.immediate);
      expect(applier.requests, hasLength(1));
      expect(applier.requests.single.comicId, 'comic:1');
      expect(applier.requests.single.source, ComicEpisodeRefreshSource.catalog);
      expect(
        applier.requests.single.reason,
        'comic_detail_catalog_direct_refresh',
      );
      expect(queue.enqueuedRequests, isEmpty);
    },
  );

  test(
    'refreshWork uses catalog-only before current thread and search queue',
    () async {
      final repository = _FakeComicRepository();
      final refreshService = _FakeComicEpisodeRefreshService();
      final queue = _RecordingSearchQueue();
      final applier = _RecordingRefreshOutcomeApplier();
      final discovery = _FakeDiscoveryService(
        threadResult: const ParsedThreadResult(
          episodeLinks: <ComicEpisodeLink>[],
          recursiveTidCandidates: <String>[],
          catalogUrl: null,
        ),
      );
      final adapter = ComicDetailAdapter(
        repository,
        refreshService: refreshService,
        searchQueue: queue,
        refreshOutcomeApplier: applier,
        discoveryService: discovery,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final result = await adapter.refreshWork(workId: 'comic:1');

      expect(result.status, DetailRefreshStatus.immediate);
      expect(refreshService.catalogOnlyCalls, 1);
      expect(discovery.fetchAndParseThreadCalls, 0);
      expect(queue.enqueuedRequests, isEmpty);
      expect(applier.requests.single.reason, 'comic_detail_catalog_refresh');
    },
  );

  test('refreshWork uses incremental discovery when no catalogUrl', () async {
    final repository = _FakeComicRepository();
    final refreshService = _FakeComicEpisodeRefreshService(
      catalogOutcome: const ComicEpisodeRefreshOutcome(
        source: ComicEpisodeRefreshSource.empty,
        links: <ComicEpisodeLink>[],
      ),
    );
    final discovery = _FakeDiscoveryService(
      threadResult: const ParsedThreadResult(
        episodeLinks: [
          ComicEpisodeLink(url: 'thread-201-1-1.html', rawText: '第1话'),
          ComicEpisodeLink(url: 'thread-202-1-1.html', rawText: '第2话'),
          ComicEpisodeLink(url: 'thread-203-1-1.html', rawText: '第3话'),
        ],
        recursiveTidCandidates: [],
        catalogUrl: null,
      ),
    );
    final incremental = _FakeIncrementalDiscovery(
      directResult: const [
        ComicEpisodeLink(url: 'thread-203-1-1.html', rawText: '第3话'),
      ],
    );
    final queue = _RecordingSearchQueue();
    final applier = _RecordingRefreshOutcomeApplier();
    final adapter = ComicDetailAdapter(
      repository,
      refreshService: refreshService,
      searchQueue: queue,
      refreshOutcomeApplier: applier,
      incrementalDiscovery: incremental,
      discoveryService: discovery,
      stateRepository: _FakeLibraryStateRepository(),
    );

    final result = await adapter.refreshWork(workId: 'comic:1');

    expect(result.status, DetailRefreshStatus.immediate);
    expect(applier.requests, hasLength(1));
    expect(applier.requests.single.reason, 'comic_detail_incremental_refresh');
    expect(applier.requests.single.links, hasLength(1));
    expect(discovery.fetchAndParseThreadCalls, 1);
    expect(queue.enqueuedRequests, isEmpty);
  });

  test(
    'refreshWork enqueues and returns queued when no incremental links',
    () async {
      final repository = _FakeComicRepository();
      final refreshService = _FakeComicEpisodeRefreshService(
        catalogOutcome: const ComicEpisodeRefreshOutcome(
          source: ComicEpisodeRefreshSource.empty,
          links: <ComicEpisodeLink>[],
        ),
      );
      final queue = _RecordingSearchQueue();
      final applier = _RecordingRefreshOutcomeApplier();
      final adapter = ComicDetailAdapter(
        repository,
        refreshService: refreshService,
        searchQueue: queue,
        refreshOutcomeApplier: applier,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final result = await adapter.refreshWork(workId: 'comic:1');

      // No discovery service → no incremental links → returns queued
      expect(result.status, DetailRefreshStatus.queued);
      expect(queue.enqueuedOrigins, <ComicSearchRefreshOrigin>[
        ComicSearchRefreshOrigin.detailManual,
      ]);
      expect(queue.enqueuedRequests.single.comicId, 'comic:1');
      expect(queue.enqueuedRequests.single.sourceTid, '100');
      expect(
        queue.enqueuedRequests.single.customSearchTitle,
        'Search Test Comic',
      );
      expect(queue.enqueuedTitles, <String>['Search Test Comic']);
    },
  );

  test('refreshWork enqueues cleaned display title when no custom search title is set', () async {
    final repository = _FakeComicRepository(title: '[Scan] Noisy Title Vol.2');
    final refreshService = _FakeComicEpisodeRefreshService(
      catalogOutcome: const ComicEpisodeRefreshOutcome(
        source: ComicEpisodeRefreshSource.empty,
        links: <ComicEpisodeLink>[],
      ),
    );
    final queue = _RecordingSearchQueue();
    final adapter = ComicDetailAdapter(
      repository,
      refreshService: refreshService,
      searchQueue: queue,
      refreshOutcomeApplier: _RecordingRefreshOutcomeApplier(),
      featureFlags: ComicReaderFeatureFlags.defaults.copyWith(
        readerCustomMetadataEnabled: false,
      ),
      stateRepository: _FakeLibraryStateRepository(),
    );

    final result = await adapter.refreshWork(workId: 'comic:1');

    expect(result.status, DetailRefreshStatus.queued);
    // Custom search title is suppressed, so the queue title is the analyzer's
    // clean book name rather than the raw "[Scan] Noisy Title Vol.2" thread.
    expect(queue.enqueuedTitles, <String>['Noisy Title']);
  });

  test('custom metadata feature flag can fall back to source fields', () async {
    final repository = _FakeComicRepositoryWithCoverWriter(
      customCoverImageUrl: 'https://img.test/custom-cover.jpg',
    );
    final refreshService = _FakeComicEpisodeRefreshService();
    final adapter = ComicDetailAdapter(
      repository,
      refreshService: refreshService,
      refreshOutcomeApplier: _RecordingRefreshOutcomeApplier(),
      featureFlags: ComicReaderFeatureFlags.defaults.copyWith(
        readerCustomMetadataEnabled: false,
      ),
      stateRepository: _FakeLibraryStateRepository(),
    );

    final header = await adapter.loadHeader(workId: 'comic:1');
    await adapter.refreshWork(workId: 'comic:1');

    expect(header.title, 'Source Test Comic');
    expect(header.customTitle, isNull);
    expect(header.coverImageUrl, 'https://img.test/90-1.jpg');
    expect(header.customCoverImageUrl, isNull);
    expect(header.customCoverLocalPath, isNull);
    expect(repository.lastCustomCoverLocalPath, isNull);
    expect(header.author, 'Source Author');
    expect(header.customAuthor, isNull);
    expect(header.translationGroup, 'Source Group');
    expect(header.customTranslationGroup, isNull);
    expect(header.customSearchTitle, isNull);
    expect(refreshService.lastRequest?.customTitle, isNull);
    expect(refreshService.lastRequest?.customSearchTitle, isNull);
  });
}
