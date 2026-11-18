part of 'comic_detail_adapter_test.dart';

void _sourceMetadataCases() {
  test('reads source tags from the comic source thread first post', () async {
    final threadRepository = _FakeThreadRepository(
      _threadDetailWithTags(const [
        ThreadPostTagLink(
          label: '漫画',
          url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=86',
          tagId: '86',
        ),
        ThreadPostTagLink(
          label: '漫画',
          url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=86',
          tagId: '86',
        ),
        ThreadPostTagLink(
          label: '讨论',
          url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=87',
          tagId: '87',
        ),
      ]),
    );
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      threadRepository: threadRepository,
      stateRepository: _FakeLibraryStateRepository(),
    );

    final tags = await adapter.loadSourceTags(workId: 'comic:1');

    expect(tags.map((tag) => tag.tagId), <String>['86', '87']);
    expect(tags.first.label, '漫画');
    expect(threadRepository.requestedTids, <String>['100']);
  });

  test('cover candidates come from the lowest tid first episode', () async {
    final repository = _FakeComicRepository(
      imageCountByEpisodeId: const <String, int>{'comic:1:90': 2},
    );
    final adapter = ComicDetailAdapter(
      repository,
      stateRepository: _FakeLibraryStateRepository(),
      firstEpisodeCoverService: ComicFirstEpisodeCoverService(
        repository: repository,
      ),
    );

    final candidates = await adapter.loadCoverCandidates(workId: 'comic:1');

    expect(adapter, isA<DetailCoverCandidateSource>());
    expect(candidates.map((candidate) => candidate.imageUrl), <String>[
      'https://img.test/90-1.jpg',
      'https://img.test/90-2.jpg',
    ]);
  });

  test(
    'cover candidates stay empty without the first episode service',
    () async {
      final adapter = ComicDetailAdapter(
        _FakeComicRepository(),
        stateRepository: _FakeLibraryStateRepository(),
      );

      expect(await adapter.loadCoverCandidates(workId: 'comic:1'), isEmpty);
    },
  );

  test(
    'catalog configuration keeps source and custom values separate',
    () async {
      final repository = _FakeComicRepository(
        catalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
        customCatalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
      );
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final configuration = await adapter.loadCatalogConfiguration(
        workId: 'comic:1',
      );
      expect(
        configuration.sourceCatalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
      );
      expect(
        configuration.customCatalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
      );

      await adapter.updateCatalogOverride(
        workId: 'comic:1',
        catalogUrl: 'misc.php?mod=tag&id=3',
      );
      expect(
        repository.lastCustomCatalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=3&type=thread&page=1',
      );

      await adapter.updateCatalogOverride(
        workId: 'comic:1',
        catalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
      );
      expect(repository.lastCustomCatalogUrl, isNull);
    },
  );

  test('catalog configuration rejects a non-Yamibo URL', () async {
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      stateRepository: _FakeLibraryStateRepository(),
    );

    final outcome = await adapter.updateCatalogOverride(
      workId: 'comic:1',
      catalogUrl: 'https://example.com/catalog',
    );

    expect(outcome.code, DetailCatalogUpdateOutcomeCode.invalidInput);
    expect(outcome.inputErrorCode, DetailCatalogInputErrorCode.unexpectedHost);
    expect(outcome.expectedHost, 'bbs.yamibo.com');
  });
}
