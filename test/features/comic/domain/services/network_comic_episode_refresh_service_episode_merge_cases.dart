part of 'network_comic_episode_refresh_service_test.dart';

void _episodeMergeCases() {
  test('trusts server matches without rescoring titles', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[],
        '401': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-401-1-1.html', rawText: '第1话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '401',
            title: '完全不同的作品 第1话',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=401',
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
        return const ThreadSeed(subject: '百合情结 第4话');
      },
    );

    final links = await service.fetchEpisodeLinksFromTid('100');

    expect(links.single.url, contains('tid=401'));
    expect(discovery.requestedTids, <String>['100', '401']);
  });

  test(
    'multi-keyword flag retries source title after custom keyword has no hits',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[],
          '501': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-501-1-1.html', rawText: '第1话'),
          ],
        },
      );
      final searchCoordinator = _SequencedForumSearchCoordinator(
        responses: <SearchTestResponse>[
          const SearchTestResponse(
            items: <SearchTestTopic>[],
            rateLimited: false,
          ),
          const SearchTestResponse(
            items: <SearchTestTopic>[
              SearchTestTopic(
                tid: '501',
                title: '来源标题 第1话',
                url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=501',
                fid: '30',
              ),
            ],
            rateLimited: false,
          ),
        ],
      );
      final service = _buildService(
        discoveryService: discovery,
        searchCoordinator: searchCoordinator,
        subjectParser: const RuleBasedComicSubjectParser(),
        featureFlags: ComicReaderFeatureFlags.defaults.copyWith(
          readerRefreshMultiKeywordEnabled: true,
        ),
        threadSeedFetcher: (tid) async {
          return const ThreadSeed(subject: '来源标题 第1话');
        },
      );

      final links = await service.fetchEpisodeLinks(
        const ComicEpisodeRefreshRequest(
          sourceTid: '100',
          customSearchTitle: '错误关键词',
          sourceTitle: '来源标题',
        ),
      );

      expect(searchCoordinator.calledKeywords, <String>['错误关键词', '来源标题']);
      expect(links.map((link) => link.url), <String>[
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=501',
      ]);
    },
  );

  test('single keyword mode does not retry lower priority title', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[],
        '501': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-501-1-1.html', rawText: '第1话'),
        ],
      },
    );
    final searchCoordinator = _SequencedForumSearchCoordinator(
      responses: <SearchTestResponse>[
        const SearchTestResponse(
          items: <SearchTestTopic>[],
          rateLimited: false,
        ),
        const SearchTestResponse(
          items: <SearchTestTopic>[
            SearchTestTopic(
              tid: '501',
              title: '来源标题 第1话',
              url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=501',
              fid: '30',
            ),
          ],
          rateLimited: false,
        ),
      ],
    );
    final service = _buildService(
      discoveryService: discovery,
      searchCoordinator: searchCoordinator,
      subjectParser: const RuleBasedComicSubjectParser(),
      threadSeedFetcher: (tid) async {
        return const ThreadSeed(subject: '来源标题 第1话');
      },
    );

    final links = await service.fetchEpisodeLinks(
      const ComicEpisodeRefreshRequest(
        sourceTid: '100',
        customSearchTitle: '错误关键词',
        sourceTitle: '来源标题',
      ),
    );

    expect(searchCoordinator.calledKeywords, <String>['错误关键词']);
    expect(links, isEmpty);
    expect(discovery.requestedTids, <String>['100']);
  });

  test('search candidate links keep an episode-like current tid', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[],
        '601': const <ComicEpisodeLink>[],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '100',
            title: '测试漫画 第1话',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
            fid: '30',
          ),
          SearchTestTopic(
            tid: '601',
            title: '测试漫画 第2话',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=601',
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
        return const ThreadSeed(subject: '测试漫画 第1话');
      },
    );

    final links = await service.fetchEpisodeLinksFromTid('100');

    expect(links.map((link) => link.url).toList(), <String>[
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=601',
    ]);
  });

  test(
    'keeps the real latest episode when the favorited source is latest',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '571256': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-568759-1-1.html', rawText: '第1话'),
            ComicEpisodeLink(url: 'thread-570088-1-1.html', rawText: '第2话'),
          ],
          '570088': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-568759-1-1.html', rawText: '第1话'),
          ],
          '568759': const <ComicEpisodeLink>[],
        },
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[
            SearchTestTopic(
              tid: '571256',
              title: '[汉化工房九九组][相崎うたう]可爱会毁灭一切 03话',
              url: 'https://bbs.yamibo.com/thread-571256-1-1.html',
              fid: '30',
            ),
            SearchTestTopic(
              tid: '570088',
              title: '[汉化工房九九组][相崎うたう]可爱会毁灭一切 02话',
              url: 'https://bbs.yamibo.com/thread-570088-1-1.html',
              fid: '30',
            ),
            SearchTestTopic(
              tid: '568759',
              title: '[汉化工房九九组][相崎うたう]可爱会毁灭一切 01话',
              url: 'https://bbs.yamibo.com/thread-568759-1-1.html',
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
          return const ThreadSeed(subject: '[汉化工房九九组][相崎うたう]可爱会毁灭一切 03话');
        },
      );

      final links = await service.fetchEpisodeLinksFromTid('571256');

      expect(links.map((link) => link.episodeTitle).toList(), <String>[
        '第1话',
        '第2话',
        '第3话',
      ]);
      expect(discovery.requestedTids, <String>['571256']);
    },
  );

  test('keeps the latest episode when the favorited source is older', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '568759': const <ComicEpisodeLink>[],
        '571256': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-568759-1-1.html', rawText: '01话'),
          ComicEpisodeLink(url: 'thread-570088-1-1.html', rawText: '02话'),
        ],
        '570088': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-568759-1-1.html', rawText: '01话'),
        ],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '571256',
            title: '可爱会毁灭一切 03话',
            url: 'https://bbs.yamibo.com/thread-571256-1-1.html',
            fid: '30',
          ),
          SearchTestTopic(
            tid: '570088',
            title: '可爱会毁灭一切 02话',
            url: 'https://bbs.yamibo.com/thread-570088-1-1.html',
            fid: '30',
          ),
          SearchTestTopic(
            tid: '568759',
            title: '可爱会毁灭一切 01话',
            url: 'https://bbs.yamibo.com/thread-568759-1-1.html',
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
        return const ThreadSeed(subject: '可爱会毁灭一切 01话');
      },
    );

    final links = await service.fetchEpisodeLinksFromTid('568759');

    expect(links.map((link) => link.episodeTitle).toList(), <String>[
      '第1话',
      '第2话',
      '第3话',
    ]);
    expect(discovery.requestedTids, <String>['568759', '571256']);
  });

  test(
    'merges unique search episodes even when discovery returns more links',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '900': const <ComicEpisodeLink>[],
          '304': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
            ComicEpisodeLink(url: 'thread-102-1-1.html', rawText: '第2话'),
            ComicEpisodeLink(url: 'thread-103-1-1.html', rawText: '第3话'),
          ],
          '305': const <ComicEpisodeLink>[],
        },
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[
            SearchTestTopic(
              tid: '304',
              title: '测试漫画 第4话',
              url: 'https://bbs.yamibo.com/thread-304-1-1.html',
              fid: '30',
            ),
            SearchTestTopic(
              tid: '305',
              title: '测试漫画 第5话',
              url: 'https://bbs.yamibo.com/thread-305-1-1.html',
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
          return const ThreadSeed(subject: '测试漫画 第3话');
        },
      );

      final links = await service.fetchEpisodeLinksFromTid('900');

      expect(
        links.map((link) => link.episodeTitle ?? link.rawText).toList(),
        <String>['第1话', '第2话', '第3话', '第4话', '第5话'],
      );
    },
  );

  test(
    'searches once and merges when current tid only has older direct links',
    () async {
      final discovery = _FakeDiscoveryService(
        byTid: <String, List<ComicEpisodeLink>>{
          '100': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '上一话'),
          ],
          '301': const <ComicEpisodeLink>[
            ComicEpisodeLink(url: 'thread-90-1-1.html', rawText: '第13话'),
            ComicEpisodeLink(url: 'thread-100-1-1.html', rawText: '第14话'),
          ],
        },
      );
      final searchCoordinator = _FakeForumSearchCoordinator(
        response: const SearchTestResponse(
          items: <SearchTestTopic>[
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

      expect(searchCoordinator.calledKeywords, contains('百合情结'));
      expect(discovery.requestedTids, containsAll(<String>['100', '301']));
      expect(links.map((link) => link.url), <String>[
        'thread-90-1-1.html',
        'thread-100-1-1.html',
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301',
      ]);
      expect(links.first.rawText, '第13话');
    },
  );

  test('search keyword uses clean book name from the new parser', () async {
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
      threadSeedFetcher: (_) async {
        return const ThreadSeed(subject: '[汉化组]漫画标题 Vol.2');
      },
    );

    await service.fetchEpisodeLinksFromTid('100');

    expect(searchCoordinator.calledKeywords, <String>['漫画标题']);
  });
}
