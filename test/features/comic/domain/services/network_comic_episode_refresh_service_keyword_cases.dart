part of 'network_comic_episode_refresh_service_test.dart';

void _keywordCases() {
  test('search fallback avoids rediscovering current tid but keeps it as an episode', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '上一话'),
        ],
        '301': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '第13话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '100',
            title: '百合情结 第14话',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
            fid: '30',
          ),
          SearchTestTopic(
            tid: '301',
            title: '百合情结 第15话',
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
      threadSeedFetcher: (tid) async {
        return ThreadSeed(
          subject: const <String, String>{'100': '【提黄灯喵汉化组】百合情结 第14话'}[tid]!,
        );
      },
    );

    final links = await service.fetchEpisodeLinksFromTid('100');

    expect(discovery.requestedTids, <String>['100', '301']);
    expect(links.map((link) => link.episodeTitle ?? link.rawText), <String>[
      '第13话',
      '第14话',
      '第15话',
    ]);
  });

  test('normalizes display title before using it as search keyword', () async {
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

    final links = await service.fetchEpisodeLinks(
      const ComicEpisodeRefreshRequest(
        sourceTid: '100',
        displayTitle: '[Favorite] Parsed Display Comic EP 02',
      ),
    );

    expect(links, isNotEmpty);
    expect(searchCoordinator.calledKeywords, <String>['Parsed Display Comic']);
    expect(discovery.requestedTids, <String>['100', '301']);
  });

  test('uses custom search title before custom and source titles', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[],
        '301': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-301-1-1.html', rawText: '第1话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '301',
            title: '真正标题 第1话',
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
      threadSeedFetcher: (tid) async {
        return const ThreadSeed(subject: '【错误组】错误标题 第1话');
      },
    );

    final links = await service.fetchEpisodeLinks(
      const ComicEpisodeRefreshRequest(
        comicId: 'comic:100',
        sourceTid: '100',
        displayTitle: '展示标题',
        sourceTitle: '来源标题',
        customTitle: '自定义标题',
        customSearchTitle: '真正标题',
      ),
    );

    expect(links, isNotEmpty);
    expect(searchCoordinator.calledKeywords, <String>['真正标题']);
    expect(discovery.requestedTids, <String>['100', '301']);
  });

  test('falls back from empty custom search title to custom title', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[],
        rateLimited: false,
      ),
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: searchCoordinator,
      subjectParser: const RuleBasedComicSubjectParser(),
      threadSeedFetcher: (tid) async {
        return const ThreadSeed(subject: '来源标题 第1话');
      },
    );

    await service.fetchEpisodeLinks(
      const ComicEpisodeRefreshRequest(
        sourceTid: '100',
        customSearchTitle: '   ',
        customTitle: '自定义标题',
        displayTitle: '展示标题',
        sourceTitle: '来源标题',
      ),
    );

    expect(searchCoordinator.calledKeywords, <String>['自定义标题']);
  });

  test('catalog-only returns catalog outcome without searching', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
        ],
      },
      strategyByTid: const <String, EpisodeDiscoveryStrategy>{
        '100': EpisodeDiscoveryStrategy.catalog,
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[],
        rateLimited: false,
      ),
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: searchCoordinator,
      subjectParser: const RuleBasedComicSubjectParser(),
    );

    final outcome = await service.fetchCatalogOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(outcome.source, ComicEpisodeRefreshSource.catalog);
    expect(outcome.catalogMatched, isTrue);
    expect(outcome.links, hasLength(1));
    expect(searchCoordinator.calledKeywords, isEmpty);
  });

  test('catalog-only miss does not trigger search fallback', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '上一话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '301',
            title: '测试漫画 第2话',
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
    );

    final outcome = await service.fetchCatalogOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(outcome.source, ComicEpisodeRefreshSource.empty);
    expect(outcome.links, isEmpty);
    expect(outcome.catalogMatched, isFalse);
    expect(searchCoordinator.calledKeywords, isEmpty);
  });

  test('search-and-current-only returns search outcome and skips current catalog fallback', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '上一话'),
        ],
        '301': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '301',
            title: '测试漫画 第1话',
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
        return const ThreadSeed(subject: '测试漫画 第2话');
      },
    );

    final outcome = await service.fetchSearchAndCurrentOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(outcome.source, ComicEpisodeRefreshSource.search);
    expect(outcome.usedSearch, isTrue);
    expect(
      outcome.links.map((link) => link.url),
      contains('thread-101-1-1.html'),
    );
    expect(discovery.catalogFallbackAllowedByTid['100'], isFalse);
  });

  test(
    'catalog-only reuses preloaded root detail without root discovery request',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '301': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
          ],
        },
        directLinksByTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-301-1-1.html', rawText: '上一话'),
          ],
        },
        strategyByTid: const <String, EpisodeDiscoveryStrategy>{
          '100': EpisodeDiscoveryStrategy.direct,
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

      final outcome = await service.fetchCatalogOnly(
        const ComicEpisodeRefreshRequest(sourceTid: '100'),
        preloadedRootDetail: const ComicThreadDiscoveryProjector().project(
          _threadDetail(
            tid: '100',
            subject: '测试漫画 第1话',
            message: '<a href="https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301">上一话</a>',
          ),
        ),
      );

      expect(outcome.source, ComicEpisodeRefreshSource.empty);
      expect(discovery.requestedTids, isEmpty);
      expect(discovery.preloadedTids, <String>['100']);
    },
  );

  test('search-and-current-only reuses preloaded root detail and skips threadSeedFetcher', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '301': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
        ],
      },
      directLinksByTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '上一话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '301',
            title: '测试漫画 第1话',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301',
            fid: '30',
          ),
        ],
        rateLimited: false,
      ),
    );
    var threadSeedFetchCount = 0;
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: searchCoordinator,
      subjectParser: const RuleBasedComicSubjectParser(),
      threadSeedFetcher: (_) async {
        threadSeedFetchCount++;
        return const ThreadSeed(subject: '不会被使用');
      },
    );

    final outcome = await service.fetchSearchAndCurrentOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
      preloadedRootDetail: const ComicThreadDiscoveryProjector().project(
        _threadDetail(
          tid: '100',
          subject: '测试漫画 第2话',
          message: '<a href="https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301">上一话</a>',
        ),
      ),
    );

    expect(outcome.source, ComicEpisodeRefreshSource.search);
    expect(outcome.links, isNotEmpty);
    expect(threadSeedFetchCount, 0);
    expect(searchCoordinator.calledKeywords, <String>['测试漫画']);
    expect(discovery.requestedTids, <String>['301']);
    expect(discovery.preloadedTids, <String>['100']);
  });
}
