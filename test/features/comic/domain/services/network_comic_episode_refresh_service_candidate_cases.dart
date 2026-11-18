part of 'network_comic_episode_refresh_service_test.dart';

void _candidateCases() {
  test('combines DEATHPAIR body acts with first-page search and final act', () async {
    final repository = _RecordingDiscoveryRepository({
      deathpairSourceTid: _threadDetail(
        tid: deathpairSourceTid,
        subject: deathpairSourceSubject,
        message: deathpairPreviousChaptersHtml,
      ),
      for (final tid in [deathpairFinalTid, '575648', '575647'])
        tid: _threadDetail(tid: tid, subject: '圣少女默示录 DEATHPAIR', message: ''),
    });
    final service = _buildService(
      discoveryService: ComicEpisodeDiscoveryService(
        repository: repository,
        opPostParser: ComicConsecutiveOpPostParser(
          engine: ComicPostParsingEngine(),
        ),
        catalogDirectoryReader: _NoopCatalogDirectoryReader(),
      ),
      searchCoordinator: _FakeForumSearchCoordinator(
        response: SearchTestResponse(
          items: [
            const SearchTestTopic(
              tid: deathpairFinalTid,
              title: deathpairFinalSubject,
              url: 'https://bbs.yamibo.com/thread-$deathpairFinalTid-1-1.html',
              fid: '30',
            ),
            for (var chapter = 30; chapter >= 12; chapter--)
              SearchTestTopic(
                tid: deathpairChapterTids[chapter - 1],
                title: '圣少女默示录 DEATHPAIR 第$chapter幕',
                url:
                    'https://bbs.yamibo.com/thread-${deathpairChapterTids[chapter - 1]}-1-1.html',
                fid: '30',
              ),
          ],
          rateLimited: false,
        ),
      ),
    );

    final outcome = await service.fetchSearchAndCurrentOnly(
      const ComicEpisodeRefreshRequest(sourceTid: deathpairSourceTid),
    );

    const references = ForumReferenceResolver();
    expect(outcome.links.map((link) => references.extractTid(link.url)), [
      ...deathpairChapterTids,
      deathpairFinalTid,
    ]);
    expect(outcome.links.last.episodeTitle, '最终话');
    expect(
      repository.requestedTids.where((tid) => tid == deathpairSourceTid),
      hasLength(1),
    );
    expect(repository.requestedTids, [deathpairSourceTid, deathpairFinalTid]);
  });

  test('follows newer bodies before older hits in the search result page', () async {
    final repository = _RecordingDiscoveryRepository(<String, ThreadDetailData>{
      for (final tid in <String>['100', '201', '202', '203', '999'])
        tid: _threadDetail(tid: tid, subject: '测试漫画 第1话', message: ''),
      '600': _threadDetail(
        tid: '600',
        subject: '测试漫画 第6话',
        message: '<a href="thread-500-1-1.html">上一话</a>',
      ),
      '500': _threadDetail(
        tid: '500',
        subject: '测试漫画 第5话',
        message: '<a href="thread-400-1-1.html">上一话</a>',
      ),
      '400': _threadDetail(
        tid: '400',
        subject: '测试漫画 第4话',
        message: '<a href="thread-203-1-1.html">上一话</a>',
      ),
    });
    final service = _buildService(
      discoveryService: ComicEpisodeDiscoveryService(
        repository: repository,
        opPostParser: ComicConsecutiveOpPostParser(
          engine: ComicPostParsingEngine(),
        ),
        catalogDirectoryReader: _NoopCatalogDirectoryReader(),
        recursiveRequestGovernor: DefaultComicRecursiveThreadRequestGovernor(
          cooldown: Duration.zero,
        ),
      ),
      searchCoordinator: _FakeForumSearchCoordinator(
        response: SearchTestResponse(
          items: <SearchTestTopic>[
            for (final entry in <String, String>{
              '201': '测试漫画 第1话',
              '202': '测试漫画 第2话',
              '203': '测试漫画 第3话',
              '600': '测试漫画 第6话',
              '999': '测试漫画 讨论',
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
    );

    final outcome = await service.fetchSearchAndCurrentOnly(
      const ComicEpisodeRefreshRequest(sourceTid: '100'),
    );

    expect(
      outcome.links.map((link) => Uri.parse(link.url).queryParameters['tid']),
      containsAll(<String>['201', '202', '203', '400', '500', '600']),
    );
    expect(repository.requestedTids.where((tid) => tid == '100'), hasLength(1));
    expect(repository.requestedTids, [
      '100',
      '999',
      '600',
      '500',
      '400',
      '203',
    ]);
    expect(outcome.links.any((link) => link.url.contains('tid=999')), isFalse);
  });

  test('uses search fallback top-k when discovery returns empty', () async {
    final discovery = _FakeDiscoveryService(
      byTid: <String, List<ComicEpisodeLink>>{
        '100': const <ComicEpisodeLink>[],
        '301': const <ComicEpisodeLink>[
          ComicEpisodeLink(url: 'thread-9001-1-1.html', rawText: '第1话'),
        ],
        '302': const <ComicEpisodeLink>[],
        '303': const <ComicEpisodeLink>[],
      },
    );
    final searchCoordinator = _FakeForumSearchCoordinator(
      response: const SearchTestResponse(
        items: <SearchTestTopic>[
          SearchTestTopic(
            tid: '301',
            title: '百合情结 第14话',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=301',
            fid: '30',
          ),
          SearchTestTopic(
            tid: '302',
            title: '百合情结 特典',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=302',
            fid: '30',
          ),
          SearchTestTopic(
            tid: '303',
            title: '百合情结 番外',
            url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=303',
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

    expect(links, isNotEmpty);
    expect(links.first.url, contains('9001'));
    expect(searchCoordinator.calledKeywords, contains('百合情结'));
    expect(
      searchCoordinator.queries.single.scope,
      ForumSearchScope.currentForum,
    );
    expect(searchCoordinator.queries.single.normalizedForumId, '30');
    expect(discovery.requestedTids, containsAll(<String>['301']));
  });
}
