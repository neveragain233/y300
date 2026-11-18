part of 'comic_detail_adapter_test.dart';

void _chapterListCases() {
  test('loadChapters sorts comic sources by numeric tid', () async {
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      stateRepository: _FakeLibraryStateRepository(),
    );

    final ascending = await adapter.loadChapters(
      workId: 'comic:1',
      filters: const LibraryFilterSet(),
      sortOption: LibraryChapterSortOption.defaults,
    );
    final descending = await adapter.loadChapters(
      workId: 'comic:1',
      filters: const LibraryFilterSet(),
      sortOption: const LibraryChapterSortOption(
        direction: LibrarySortDirection.desc,
      ),
    );

    expect(ascending.map((chapter) => chapter.sourceTid), <String?>[
      '90',
      '120',
    ]);
    expect(descending.map((chapter) => chapter.sourceTid), <String?>[
      '120',
      '90',
    ]);
  });

  test(
    'loadChapters maps current reading progress to chapter progress info',
    () async {
      final repository = _FakeComicRepository(
        progress: ComicReadingProgress(
          comicId: 'comic:1',
          episodeId: 'comic:1:90',
          imageIndex: 2,
          scrollOffset: 120,
          updatedAt: DateTime(2026, 5, 12),
        ),
        imageCountByEpisodeId: const <String, int>{'comic:1:90': 5},
      );
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final chapters = await adapter.loadChapters(
        workId: 'comic:1',
        filters: const LibraryFilterSet(),
        sortOption: LibraryChapterSortOption.defaults,
      );
      final current = chapters.singleWhere(
        (chapter) => chapter.episodeId == 'comic:1:90',
      );

      expect(
        current.progressInfo?.kind,
        LibraryChapterProgressKind.currentPage,
      );
      expect(current.progressInfo?.currentPage, 3);
      expect(current.progressInfo?.totalPages, 5);
      expect(current.progressInfo?.isCurrent, isTrue);
      expect(current.progressInfo?.fraction, closeTo(3 / 5, 0.0001));
    },
  );

  test(
    'loadChapters keeps page progress for multiple unfinished chapters',
    () async {
      final repository = _FakeComicRepository(
        progresses: <ComicReadingProgress>[
          ComicReadingProgress(
            comicId: 'comic:1',
            episodeId: 'comic:1:120',
            imageIndex: 1,
            scrollOffset: 20,
            updatedAt: DateTime(2026, 5, 13),
          ),
          ComicReadingProgress(
            comicId: 'comic:1',
            episodeId: 'comic:1:90',
            imageIndex: 2,
            scrollOffset: 10,
            updatedAt: DateTime(2026, 5, 12),
          ),
        ],
        imageCountByEpisodeId: const <String, int>{
          'comic:1:90': 5,
          'comic:1:120': 4,
        },
      );
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(),
      );

      final chapters = await adapter.loadChapters(
        workId: 'comic:1',
        filters: const LibraryFilterSet(),
        sortOption: LibraryChapterSortOption.defaults,
      );

      expect(
        chapters
            .singleWhere((chapter) => chapter.episodeId == 'comic:1:90')
            .progressInfo
            ?.currentPage,
        3,
      );
      expect(
        chapters
            .singleWhere((chapter) => chapter.episodeId == 'comic:1:120')
            .progressInfo
            ?.currentPage,
        2,
      );
    },
  );

  test(
    'continue targets the latest unfinished chapter with progress',
    () async {
      final repository = _FakeComicRepository(
        progresses: <ComicReadingProgress>[
          ComicReadingProgress(
            comicId: 'comic:1',
            episodeId: 'comic:1:120',
            imageIndex: 1,
            scrollOffset: 20,
            updatedAt: DateTime(2026, 5, 13),
          ),
          ComicReadingProgress(
            comicId: 'comic:1',
            episodeId: 'comic:1:90',
            imageIndex: 2,
            scrollOffset: 10,
            updatedAt: DateTime(2026, 5, 12),
          ),
        ],
      );
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

  test(
    'loadChapters clamps comic progress and hides it for read chapters',
    () async {
      final repository = _FakeComicRepository(
        progress: ComicReadingProgress(
          comicId: 'comic:1',
          episodeId: 'comic:1:90',
          imageIndex: 99,
          scrollOffset: 120,
          updatedAt: DateTime(2026, 5, 12),
        ),
        imageCountByEpisodeId: const <String, int>{'comic:1:90': 5},
      );
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(
          episodeStates: <String, LibraryEpisodeState>{
            'comic:1:120': const LibraryEpisodeState(
              moduleKey: LibraryModuleKey.comic,
              episodeId: 'comic:1:120',
              workId: 'comic:1',
              isRead: false,
            ),
          },
        ),
      );

      final chapters = await adapter.loadChapters(
        workId: 'comic:1',
        filters: const LibraryFilterSet(),
        sortOption: LibraryChapterSortOption.defaults,
      );
      final current = chapters.singleWhere(
        (chapter) => chapter.episodeId == 'comic:1:90',
      );

      expect(current.progressInfo?.currentPage, 5);
      expect(current.progressInfo?.fraction, 1);

      final readAdapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(
          episodeStates: <String, LibraryEpisodeState>{
            'comic:1:90': const LibraryEpisodeState(
              moduleKey: LibraryModuleKey.comic,
              episodeId: 'comic:1:90',
              workId: 'comic:1',
              isRead: true,
            ),
          },
        ),
      );
      final readChapters = await readAdapter.loadChapters(
        workId: 'comic:1',
        filters: const LibraryFilterSet(),
        sortOption: LibraryChapterSortOption.defaults,
      );

      expect(
        readChapters
            .singleWhere((chapter) => chapter.episodeId == 'comic:1:90')
            .progressInfo,
        isNull,
      );
    },
  );

  test('loadChapters ignores comic progress for missing episode', () async {
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(
        progress: ComicReadingProgress(
          comicId: 'comic:1',
          episodeId: 'missing',
          imageIndex: 1,
          scrollOffset: 120,
          updatedAt: DateTime(2026, 5, 12),
        ),
      ),
      stateRepository: _FakeLibraryStateRepository(),
    );

    final chapters = await adapter.loadChapters(
      workId: 'comic:1',
      filters: const LibraryFilterSet(),
      sortOption: LibraryChapterSortOption.defaults,
    );

    expect(chapters.where((chapter) => chapter.progressInfo != null), isEmpty);
  });
}
