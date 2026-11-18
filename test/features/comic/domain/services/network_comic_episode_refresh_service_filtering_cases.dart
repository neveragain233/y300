part of 'network_comic_episode_refresh_service_test.dart';

void _filteringCases() {
  test('inspects only the three highest tids and merges the whole search page', () async {
    final discovery = _FakeDiscoveryService(byTid: {});
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: _FakeForumSearchCoordinator(
        response: SearchTestResponse(
          items: <SearchTestTopic>[
            for (final entry in <String, String>{
              '201': '测试漫画 第1话',
              '202': '测试漫画 第2话',
              '203': '测试漫画 第3话',
              '204': '测试漫画 第4话',
              '600': '测试漫話 第6话',
            }.entries)
              SearchTestTopic(
                tid: entry.key,
                title: entry.value,
                url:
                    'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=${entry.key}',
                fid: '30',
              ),
          ],
          rateLimited: false,
        ),
      ),
      threadSeedFetcher: (_) async => const ThreadSeed(subject: '测试漫画 第1话'),
    );

    final outcome = await service.fetchCatalogThenFallback(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(discovery.requestedTids, ['100', '600', '204', '203']);
    expect(outcome.links, hasLength(5));
  });

  test(
    'uses matched search results when candidate discovery finds no links',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '476059': const <ComicEpisodeLink>[],
          '503102': const <ComicEpisodeLink>[],
          '502780': const <ComicEpisodeLink>[],
          '502128': const <ComicEpisodeLink>[],
        },
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[
            SearchTestTopic(
              tid: '503102',
              title: '[百合會][サンデーうぇぶり][古鉢るか]はなにあらし(好事多磨)第82話下',
              url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=503102',
              fid: '30',
            ),
            SearchTestTopic(
              tid: '502780',
              title: '[百合會][サンデーうぇぶり][古鉢るか]はなにあらし(好事多磨)第82話上',
              url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=502780',
              fid: '30',
            ),
            SearchTestTopic(
              tid: '502128',
              title: '[百合會][サンデーうぇぶり][古鉢るか]はなにあらし(好事多磨)第81話',
              url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=502128',
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
          return const ThreadSeed(
            subject: '[百合會][サンデーうぇぶり][古鉢るか]はなにあらし(好事多磨)第6話',
          );
        },
      );

      final links = await service.fetchEpisodeLinks(
        const ComicEpisodeRefreshRequest(
          comicId: 'yamibo:476059',
          sourceTid: '476059',
          customTitle: '好事多磨',
        ),
      );

      expect(discovery.requestedTids, <String>[
        '476059',
        '503102',
        '502780',
        '502128',
      ]);
      expect(links.map((link) => link.url).toList(), <String>[
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=502128',
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=502780',
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=503102',
      ]);
      expect(links.map((link) => link.episodeTitle).toList(), <String>[
        '第81话',
        '第82话上',
        '第82话下',
      ]);
    },
  );

  test(
    'skips both covered candidates without reading older search bodies',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: {
          '600': const [
            ComicEpisodeLink(
              url: 'forum.php?mod=viewthread&tid=500&page=2#pid123',
              rawText: '第5话',
            ),
            ComicEpisodeLink(url: 'thread-400-1-1.html', rawText: '第4话'),
          ],
        },
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: _FakeForumSearchCoordinator(
          response: _searchResponseForTids([
            '200',
            '500',
            '100',
            '600',
            '400',
            '600',
          ]),
        ),
        threadSeedFetcher: (_) async => const ThreadSeed(subject: '测试漫画 第1话'),
      );

      final outcome = await service.fetchSearchAndCurrentOnly(
        const ComicEpisodeRefreshRequest(sourceTid: '100'),
      );

      expect(discovery.requestedTids, ['100', '600']);
      const references = ForumReferenceResolver();
      expect(outcome.links.map((link) => references.extractTid(link.url)), [
        '100',
        '200',
        '400',
        '500',
        '600',
      ]);
    },
  );

  test('continues with the uncovered third candidate', () async {
    final discovery = _FakeDiscoveryService(
      byTid: {
        '600': const [
          ComicEpisodeLink(url: 'thread-500-1-1.html', rawText: '第5话'),
        ],
        '400': const [
          ComicEpisodeLink(url: 'thread-300-1-1.html', rawText: '第3话'),
        ],
      },
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: _FakeForumSearchCoordinator(
        response: _searchResponseForTids(['200', '500', '100', '600', '400']),
      ),
      threadSeedFetcher: (_) async => const ThreadSeed(subject: '测试漫画 第1话'),
    );

    final outcome = await service.fetchSearchAndCurrentOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(discovery.requestedTids, ['100', '600', '400']);
    const references = ForumReferenceResolver();
    expect(outcome.links.map((link) => references.extractTid(link.url)), [
      '100',
      '200',
      '300',
      '400',
      '500',
      '600',
    ]);
  });

  test('also skips candidates covered by the second body', () async {
    final discovery = _FakeDiscoveryService(
      byTid: {
        '500': const [
          ComicEpisodeLink(url: 'thread-400-1-1.html', rawText: '第4话'),
        ],
      },
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: _FakeForumSearchCoordinator(
        response: _searchResponseForTids(['400', '500', '600', '200']),
      ),
      threadSeedFetcher: (_) async => const ThreadSeed(subject: '测试漫画 第1话'),
    );

    final outcome = await service.fetchSearchAndCurrentOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(discovery.requestedTids, ['100', '600', '500']);
    expect(outcome.links, hasLength(4));
  });

  test(
    'does not treat a rejected search as a completed empty result',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[],
        },
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[],
          rateLimited: true,
          retryAfter: Duration(seconds: 6),
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

      await expectLater(
        service.fetchEpisodeLinksFromTid('100'),
        throwsStateError,
      );
      expect(searchCoordinator.waitPolicies, [true]);
    },
  );
}
