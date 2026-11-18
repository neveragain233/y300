part of 'local_comic_repository_test.dart';

void _episodeDetailCases() {
  test('can query comic detail and episodes descending', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '【测试汉化组】[作者A]测试漫画 第1话',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-101-1-1.html',
            rawText: '1',
            episodeTitle: '第1话',
          ),
          ComicEpisodeLink(
            url: 'thread-102-1-1.html',
            rawText: '2',
            episodeTitle: '第2话',
          ),
        ],
        plainTextSummary: '摘要',
        inferredAuthor: '作者A',
        subjectMetadata: ComicSubjectMetadata(
          normalizedTitle: '测试漫画',
          translationGroup: '测试汉化组',
          inferredAuthor: '作者A',
          episodeLabel: '第1话',
        ),
      ),
    );

    final detail = await repository.getComicDetail(comicId: 'yamibo:100');
    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:100',
      descending: true,
    );

    expect(detail, isNotNull);
    expect(detail!.title, '测试漫画');
    expect(detail.translationGroup, '测试汉化组');
    expect(detail.author, '作者A');
    expect(detail.episodeCount, greaterThanOrEqualTo(2));
    expect(episodes.first.episodeTitle, contains('2'));
  });

  test(
    'repairs DEATHPAIR older acts while preserving existing reading state',
    () async {
      const comicId = 'yamibo:$deathpairSourceTid';
      const readEpisodeId = '$comicId:570879';
      await repository.addToShelf(
        comicId: comicId,
        tid: deathpairSourceTid,
        fid: '30',
        title: deathpairSourceSubject,
        parsedPost: ParsedComicPost(
          imageUrls: const [],
          episodeLinks: [
            for (var chapter = 12; chapter <= 30; chapter++)
              ComicEpisodeLink(
                url: 'thread-${deathpairChapterTids[chapter - 1]}-1-1.html',
                rawText: '第$chapter话',
                episodeTitle: '第$chapter话',
              ),
          ],
          plainTextSummary: '',
        ),
      );
      final stateRepository = LocalLibraryStateRepository(dbFuture);
      await stateRepository.upsertEpisodeState(
        moduleKey: LibraryModuleKey.comic,
        episodeId: readEpisodeId,
        workId: comicId,
        isRead: true,
      );
      await repository.updateLastReadProgress(
        comicId: comicId,
        episodeId: readEpisodeId,
        imageIndex: 3,
        scrollOffset: 42,
      );
      await repository.saveEpisodeImages(
        episodeId: readEpisodeId,
        imageUrls: ['https://img.test/deathpair-12.jpg'],
      );
      await repository.updateEpisodeImageCacheMetadata(
        episodeId: readEpisodeId,
        imageUrl: 'https://img.test/deathpair-12.jpg',
        localPath: '/cache/deathpair-12.jpg',
      );
      final parsed = ComicPostParsingEngine().parse(
        messageHtml: deathpairPreviousChaptersHtml,
      );

      final result = await repository.mergeEpisodesFromLinks(
        comicId: comicId,
        fallbackSourceTid: deathpairSourceTid,
        episodeLinks: [
          for (final episode in parsed.episodes)
            ComicEpisodeLink(
              url: episode.url,
              rawText: episode.titleRaw,
              episodeTitle: episode.titleNormalized,
            ),
          const ComicEpisodeLink(
            url: 'thread-$deathpairSourceTid-1-1.html',
            rawText: deathpairSourceSubject,
          ),
          const ComicEpisodeLink(
            url: 'thread-$deathpairFinalTid-1-1.html',
            rawText: deathpairFinalSubject,
          ),
        ],
      );

      final episodes = await repository.getComicEpisodes(
        comicId: comicId,
        descending: false,
      );
      final progresses = await repository.getReadingProgresses(
        comicId: comicId,
      );
      final images = await repository.getEpisodeImages(
        episodeId: readEpisodeId,
      );
      final snapshot = await repository.queryShelfSnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: LibraryShelfSortOption.defaults,
        keyword: '',
      );
      expect(result.insertedCount, 12);
      expect(episodes.map((episode) => episode.sourceTid), [
        ...deathpairChapterTids,
        deathpairFinalTid,
      ]);
      expect(episodes.last.episodeTitle, '最终话');
      expect(progresses.single.episodeId, readEpisodeId);
      expect(progresses.single.imageIndex, 3);
      expect(progresses.single.scrollOffset, 42);
      expect(images.single.localPath, '/cache/deathpair-12.jpg');
      expect(
        snapshot.itemsByCategory['comic-default']!.single.readChapterCount,
        1,
      );

      // Favorite ingest reuses the same chapter writes on later syncs.
      await repository.addFavoriteToShelf(
        comicId: comicId,
        tid: deathpairSourceTid,
        fid: '30',
        title: deathpairSourceSubject,
        parsedPost: ParsedComicPost(
          imageUrls: const [],
          episodeLinks: [
            for (final episode in parsed.episodes)
              ComicEpisodeLink(
                url: episode.url,
                rawText: episode.titleRaw,
                episodeTitle: episode.titleNormalized,
              ),
          ],
          plainTextSummary: '',
        ),
        favoriteAddedAt: DateTime(2026, 8, 27),
      );
      expect(
        (await repository.getReadingProgresses(comicId: comicId))
            .single
            .imageIndex,
        3,
      );
      expect(
        (await repository.getEpisodeImages(episodeId: readEpisodeId))
            .single
            .localPath,
        '/cache/deathpair-12.jpg',
      );
    },
  );

  test('mergeEpisodesFromLinks can insert and update episodes', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-101-1-1.html',
            rawText: '1',
            episodeTitle: '1',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );

    final result = await repository.mergeEpisodesFromLinks(
      comicId: 'yamibo:100',
      fallbackSourceTid: '100',
      episodeLinks: const <ComicEpisodeLink>[
        ComicEpisodeLink(
          url: 'thread-101-1-1.html',
          rawText: '1',
          episodeTitle: '第1话-修订',
        ),
        ComicEpisodeLink(
          url: 'thread-102-1-1.html',
          rawText: '2',
          episodeTitle: '第2话',
        ),
      ],
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:100',
      descending: false,
    );
    expect(result.insertedCount, 1);
    expect(result.updatedCount, 1);
    expect(result.totalCount, episodes.length);
    expect(episodes.any((e) => e.episodeTitle == '第1话-修订'), isTrue);
  });

  test(
    'mergeEpisodesFromLinks updates same tid title without losing read state',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:110',
        tid: '110',
        fid: '30',
        title: '测试漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-111-1-1.html',
              rawText: '1',
              episodeTitle: '第1话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );
      final stateRepository = LocalLibraryStateRepository(dbFuture);
      await stateRepository.upsertEpisodeState(
        moduleKey: LibraryModuleKey.comic,
        episodeId: 'yamibo:110:111',
        workId: 'yamibo:110',
        isRead: true,
      );

      final result = await repository.mergeEpisodesFromLinks(
        comicId: 'yamibo:110',
        fallbackSourceTid: '110',
        episodeLinks: const <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-111-1-1.html',
            rawText: '第1话 完整标题',
            episodeTitle: '第1话 完整标题',
          ),
        ],
      );

      final episodes = await repository.getComicEpisodes(
        comicId: 'yamibo:110',
        descending: false,
      );
      final snapshot = await repository.queryShelfSnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: LibraryShelfSortOption.defaults,
        keyword: '',
      );
      final item = snapshot.itemsByCategory['comic-default']!.single;

      expect(result.insertedCount, 0);
      expect(result.updatedCount, 1);
      expect(episodes, hasLength(1));
      expect(episodes.single.episodeTitle, '第1话 完整标题');
      expect(item.readChapterCount, 1);
      expect(item.unreadCount, 0);
    },
  );
}
