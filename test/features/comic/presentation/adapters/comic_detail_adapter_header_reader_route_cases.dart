part of 'comic_detail_adapter_test.dart';

void _headerAndReaderRouteCases() {
  test(
    'loadHeader falls back to first image of smallest tid episode',
    () async {
      final repository = _FakeComicRepository();
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final header = await adapter.loadHeader(workId: 'comic:1');

      expect(header.coverImageUrl, 'https://img.test/90-1.jpg');
    },
  );

  test('loadHeader exposes source asset without synchronous caching', () async {
    final repository = _FakeComicRepositoryWithCoverWriter();
    final adapter = ComicDetailAdapter(
      repository,
      stateRepository: _FakeLibraryStateRepository(),
    );

    final header = await adapter.loadHeader(workId: 'comic:1');

    expect(header.coverLocalPath, isNull);
    expect(header.coverAsset?.assetId, 'comic/comic:1/source');
    expect(header.coverAsset?.kind, LibraryCoverAssetKind.source);
    expect(header.coverAsset?.sourceUrl, 'https://img.test/90-1.jpg');
    expect(repository.lastCoverImageUrl, isNull);
    expect(repository.lastCoverLocalPath, isNull);
  });

  test('loadHeader exposes custom asset without synchronous caching', () async {
    final repository = _FakeComicRepositoryWithCoverWriter(
      customCoverImageUrl: 'https://img.test/custom-cover.jpg',
    );
    final adapter = ComicDetailAdapter(
      repository,
      stateRepository: _FakeLibraryStateRepository(),
    );

    final header = await adapter.loadHeader(workId: 'comic:1');

    expect(header.customCoverLocalPath, isNull);
    expect(header.coverAsset?.assetId, 'comic/comic:1/custom');
    expect(header.coverAsset?.kind, LibraryCoverAssetKind.custom);
    expect(header.coverAsset?.sourceUrl, 'https://img.test/custom-cover.jpg');
    expect(repository.lastCoverImageUrl, isNull);
    expect(repository.lastCoverLocalPath, isNull);
    expect(repository.lastCustomCoverLocalPath, isNull);
  });

  test('getReaderRouteTarget continues from reading progress first', () async {
    final repository = _FakeComicRepository(
      progress: ComicReadingProgress(
        comicId: 'comic:1',
        episodeId: 'comic:1:90',
        imageIndex: 2,
        scrollOffset: 120,
        updatedAt: DateTime(2026, 5, 12),
      ),
    );
    final adapter = ComicDetailAdapter(
      repository,
      stateRepository: _FakeLibraryStateRepository(
        workState: LibraryWorkState(
          moduleKey: LibraryModuleKey.comic,
          workId: 'comic:1',
          lastReadEpisodeId: 'comic:1:120',
          lastReadAt: DateTime(2026, 5, 12),
          createdAt: DateTime(2026, 5, 12),
          updatedAt: DateTime(2026, 5, 12),
        ),
      ),
    );

    final target = await adapter.getReaderRouteTarget(
      workId: 'comic:1',
      preferContinue: true,
    );

    expect(target?.episodeId, 'comic:1:90');
  });

  test('getReaderRouteTarget falls back to library work state', () async {
    final repository = _FakeComicRepository();
    final adapter = ComicDetailAdapter(
      repository,
      stateRepository: _FakeLibraryStateRepository(
        workState: LibraryWorkState(
          moduleKey: LibraryModuleKey.comic,
          workId: 'comic:1',
          lastReadEpisodeId: 'comic:1:120',
          lastReadAt: DateTime(2026, 5, 12),
          createdAt: DateTime(2026, 5, 12),
          updatedAt: DateTime(2026, 5, 12),
        ),
      ),
    );

    final target = await adapter.getReaderRouteTarget(
      workId: 'comic:1',
      preferContinue: true,
    );

    expect(target?.episodeId, 'comic:1:120');
  });

  test(
    'getReaderRouteTarget starts from first unread chapter without progress',
    () async {
      final repository = _FakeComicRepository();
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(
          episodeStates: <String, LibraryEpisodeState>{
            'comic:1:120': const LibraryEpisodeState(
              moduleKey: LibraryModuleKey.comic,
              episodeId: 'comic:1:120',
              workId: 'comic:1',
              isRead: true,
            ),
          },
        ),
      );

      final target = await adapter.getReaderRouteTarget(
        workId: 'comic:1',
        preferContinue: true,
      );

      expect(target?.episodeId, 'comic:1:90');
    },
  );
}
