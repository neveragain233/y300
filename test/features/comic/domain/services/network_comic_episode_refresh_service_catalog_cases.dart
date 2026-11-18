part of 'network_comic_episode_refresh_service_test.dart';

void _catalogCases() {
  test(
    'catalog-then-fallback returns catalog outcome when catalog matches',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: 'EP 01'),
          ],
        },
        strategyByTid: const <String, EpisodeDiscoveryStrategy>{
          '100': EpisodeDiscoveryStrategy.catalog,
        },
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: _FakeForumSearchCoordinator(
          response: const SearchTestResponse(
            items: <SearchTestTopic>[],
            rateLimited: false,
          ),
        ),
        subjectParser: const RuleBasedComicSubjectParser(),
      );

      final outcome = await service.fetchCatalogThenFallback(
        const ComicEpisodeRefreshRequest(sourceTid: '100'),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.catalog);
      expect(outcome.catalogMatched, isTrue);
      expect(outcome.links, hasLength(1));
    },
  );

  test(
    'catalog-then-fallback returns search outcome when catalog misses',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[],
          '301': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-301-1-1.html', rawText: 'EP 03'),
          ],
        },
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[
            SearchTestTopic(
              tid: '301',
              title: '[Scan] Parsed Display Comic EP 03',
              url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301',
              fid: '30',
            ),
          ],
          rateLimited: false,
        ),
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: searchCoordinator,
        subjectParser: const RuleBasedComicSubjectParser(),
        threadSeedFetcher: (_) async {
          return const ThreadSeed(subject: '[Scan] Current Thread EP 01');
        },
      );

      final outcome = await service.fetchCatalogThenFallback(
        const ComicEpisodeRefreshRequest(
          sourceTid: '100',
          displayTitle: '[Favorite] Parsed Display Comic EP 02',
        ),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.search);
      expect(outcome.usedSearch, isTrue);
      expect(outcome.links, isNotEmpty);
      expect(searchCoordinator.calledKeywords, <String>[
        'Parsed Display Comic',
      ]);
    },
  );

  test(
    'catalog-then-fallback returns current-only outcome when search misses',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-100-1-1.html', rawText: 'EP 01'),
          ],
        },
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: _FakeForumSearchCoordinator(
          response: const SearchTestResponse(
            items: <SearchTestTopic>[],
            rateLimited: false,
          ),
        ),
        subjectParser: const RuleBasedComicSubjectParser(),
        threadSeedFetcher: (_) async {
          return const ThreadSeed(subject: 'Current Comic EP 01');
        },
      );

      final outcome = await service.fetchCatalogThenFallback(
        const ComicEpisodeRefreshRequest(
          sourceTid: '100',
          displayTitle: 'Current Comic EP 01',
        ),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.currentOnly);
      expect(outcome.usedSearch, isTrue);
      expect(outcome.links, hasLength(1));
    },
  );

  test(
    'catalog-then-fallback returns empty outcome when nothing is found',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[],
        },
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: _FakeForumSearchCoordinator(
          response: const SearchTestResponse(
            items: <SearchTestTopic>[],
            rateLimited: false,
          ),
        ),
        subjectParser: const RuleBasedComicSubjectParser(),
        threadSeedFetcher: (_) async {
          return const ThreadSeed(subject: 'Current Comic EP 01');
        },
      );

      final outcome = await service.fetchCatalogThenFallback(
        const ComicEpisodeRefreshRequest(
          sourceTid: '100',
          displayTitle: 'Current Comic EP 01',
        ),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.empty);
      expect(outcome.links, isEmpty);
    },
  );

  test('catalog hit does not consult extracted search strategies', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: 'EP 01'),
        ],
      },
      strategyByTid: const <String, EpisodeDiscoveryStrategy>{
        '100': EpisodeDiscoveryStrategy.catalog,
      },
    );
    final keywordResolver = _RecordingKeywordResolver();
    final candidateRanker = _RecordingCandidateRanker();
    final linkMerger = _RecordingEpisodeLinkMerger();
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[],
          rateLimited: false,
        ),
      ),
      keywordResolver: keywordResolver,
      candidateRanker: candidateRanker,
      episodeLinkMerger: linkMerger,
    );

    final outcome = await service.fetchCatalogThenFallback(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(outcome.source, ComicEpisodeRefreshSource.catalog);
    expect(keywordResolver.callCount, 0);
    expect(candidateRanker.callCount, 0);
    expect(linkMerger.mergeCallCount, 0);
    expect(linkMerger.fromSearchCandidatesCallCount, 0);
    expect(linkMerger.sortCallCount, 0);
  });

  test(
    'catalog miss delegates fallback to resolver ranker and merger',
    () async {
      const searchItem = SearchTestTopic(
        tid: '301',
        title: '测试漫画 第2话',
        url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301',
        fid: '30',
      );
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-100-1-1.html', rawText: '第1话'),
          ],
          '301': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-301-1-1.html', rawText: '第2话'),
          ],
        },
      );
      final keywordResolver = _RecordingKeywordResolver(
        keywords: const <ComicRefreshKeyword>[
          ComicRefreshKeyword(
            source: ComicRefreshKeywordSource.customTitle,
            value: '测试漫画',
          ),
        ],
      );
      final candidateRanker = _RecordingCandidateRanker(
        candidates: <ComicSearchCandidate>[
          ComicSearchCandidate(
            tid: searchItem.tid,
            title: searchItem.title,
            searchIndex: 0,
          ),
        ],
      );
      final linkMerger = _RecordingEpisodeLinkMerger();
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[searchItem],
          rateLimited: false,
        ),
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: searchCoordinator,
        keywordResolver: keywordResolver,
        candidateRanker: candidateRanker,
        episodeLinkMerger: linkMerger,
        threadSeedFetcher: (_) async {
          return const ThreadSeed(subject: '测试漫画 第1话');
        },
      );

      final outcome = await service.fetchCatalogThenFallback(
        const ComicEpisodeRefreshRequest(sourceTid: '100', customTitle: '测试漫画'),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.search);
      expect(searchCoordinator.calledKeywords, <String>['测试漫画']);
      expect(keywordResolver.callCount, 1);
      expect(keywordResolver.lastRequest?.sourceTid, '100');
      expect(keywordResolver.lastSubject, '测试漫画 第1话');
      expect(candidateRanker.callCount, 1);
      expect(
        candidateRanker.lastItems.map((item) => item.tid).toList(),
        <String>['301'],
      );
      expect(linkMerger.fromSearchCandidatesCallCount, 1);
      expect(linkMerger.sortCallCount, 1);
      expect(linkMerger.mergeCallCount, greaterThanOrEqualTo(2));
    },
  );

  test(
    'catalog miss preserves catalogUrl discovered from search candidate',
    () async {
      const candidateCatalogUrl =
          'https://bbs.yamibo.com/misc.php?mod=tag&id=18235';
      const searchItem = SearchTestTopic(
        tid: '301',
        title: '测试漫画 第2话',
        url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301',
        fid: '30',
      );
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[],
          '301': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-301-1-1.html', rawText: '第1话'),
            ComicEpisodeLink(url: 'thread-302-1-1.html', rawText: '第2话'),
          ],
        },
        catalogUrlByTid: const <String, String>{'301': candidateCatalogUrl},
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[searchItem],
          rateLimited: false,
        ),
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: searchCoordinator,
        threadSeedFetcher: (_) async {
          return const ThreadSeed(subject: '测试漫画 第1话');
        },
      );

      final outcome = await service.fetchSearchAndCurrentOnly(
        const ComicEpisodeRefreshRequest(sourceTid: '100', customTitle: '测试漫画'),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.search);
      expect(outcome.catalogUrl, candidateCatalogUrl);
    },
  );

  test('fetchCatalogDirect returns catalog outcome when links found', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{},
      byCatalogUrl: <String, List<ComicEpisodeLink>>{
        'https://bbs.yamibo.com/misc.php?mod=tag&id=123':
            const <ComicEpisodeLink>[
              ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
              ComicEpisodeLink(url: 'thread-102-1-1.html', rawText: '第2话'),
            ],
      },
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[],
          rateLimited: false,
        ),
      ),
    );

    final outcome = await service.fetchCatalogDirect(
      'https://bbs.yamibo.com/misc.php?mod=tag&id=123',
    );

    expect(outcome.catalogMatched, isTrue);
    expect(outcome.hasLinks, isTrue);
    expect(outcome.source, ComicEpisodeRefreshSource.catalog);
    expect(outcome.links, hasLength(2));
    expect(
      outcome.catalogUrl,
      'https://bbs.yamibo.com/misc.php?mod=tag&id=123',
    );
    expect(
      discovery.requestedCatalogUrls,
      contains('https://bbs.yamibo.com/misc.php?mod=tag&id=123'),
    );
  });

  test('fetchCatalogDirect returns empty when catalog has no links', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{},
      byCatalogUrl: <String, List<ComicEpisodeLink>>{},
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[],
          rateLimited: false,
        ),
      ),
    );

    final outcome = await service.fetchCatalogDirect(
      'https://bbs.yamibo.com/misc.php?mod=tag&id=999',
    );

    expect(outcome.catalogMatched, isFalse);
    expect(outcome.hasLinks, isFalse);
    expect(outcome.source, ComicEpisodeRefreshSource.empty);
    expect(
      outcome.catalogUrl,
      'https://bbs.yamibo.com/misc.php?mod=tag&id=999',
    );
  });
}
