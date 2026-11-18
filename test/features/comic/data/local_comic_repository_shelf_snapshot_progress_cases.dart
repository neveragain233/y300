part of 'local_comic_repository_test.dart';

void _shelfSnapshotProgressCases() {
  test('queryShelfSnapshot aggregates episode state and tags', () async {
    await repository.addToShelf(
      comicId: 'yamibo:900',
      tid: '900',
      fid: '30',
      title: '聚合漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-901-1-1.html',
            rawText: '1',
            episodeTitle: '第1话',
          ),
          ComicEpisodeLink(
            url: 'thread-902-1-1.html',
            rawText: '2',
            episodeTitle: '第2话',
          ),
        ],
        plainTextSummary: '摘要',
        inferredAuthor: '作者S',
      ),
    );
    final stateRepository = LocalLibraryStateRepository(dbFuture);
    await stateRepository.upsertEpisodeState(
      moduleKey: LibraryModuleKey.comic,
      episodeId: 'yamibo:900:901',
      workId: 'yamibo:900',
      isRead: false,
      isDownloaded: true,
    );
    await stateRepository.upsertEpisodeState(
      moduleKey: LibraryModuleKey.comic,
      episodeId: 'yamibo:900:902',
      workId: 'yamibo:900',
      isRead: true,
    );
    final tagId = await stateRepository.createTag(name: '追更');
    await stateRepository.bindTagToWork(
      moduleKey: LibraryModuleKey.comic,
      workId: 'yamibo:900',
      tagId: tagId,
    );

    final snapshot = await repository.queryShelfSnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );
    final item = snapshot.itemsByCategory['comic-default']!.single;

    expect(snapshot.categories.single.categoryId, 'comic-default');
    expect(snapshot.visibleMatchCountByCategory['comic-default'], 1);
    expect(item.title, '聚合漫画');
    expect(item.unreadCount, 1);
    expect(item.readChapterCount, 1);
    expect(item.totalChapterCount, greaterThanOrEqualTo(2));
    expect(item.isDownloaded, isTrue);
    expect(item.hasTags, isTrue);
  });

  test(
    'queryShelfSnapshot treats episodes without state rows as unread',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:910',
        tid: '910',
        fid: '30',
        title: '无状态漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-911-1-1.html',
              rawText: '1',
              episodeTitle: '第1话',
            ),
            ComicEpisodeLink(
              url: 'thread-912-1-1.html',
              rawText: '2',
              episodeTitle: '第2话',
            ),
            ComicEpisodeLink(
              url: 'thread-913-1-1.html',
              rawText: '3',
              episodeTitle: '第3话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );

      final stateRepository = LocalLibraryStateRepository(dbFuture);
      await stateRepository.upsertEpisodeState(
        moduleKey: LibraryModuleKey.comic,
        episodeId: 'yamibo:910:911',
        workId: 'yamibo:910',
        isRead: true,
      );

      final snapshot = await repository.queryShelfSnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: LibraryShelfSortOption.defaults,
        keyword: '',
      );
      final item = snapshot.itemsByCategory['comic-default']!.single;

      expect(item.totalChapterCount, 3);
      expect(item.readChapterCount, 1);
      expect(item.unreadCount, 2);
    },
  );

  test('queryShelfSnapshot unread filter includes works with missing episode state', () async {
    await repository.addToShelf(
      comicId: 'yamibo:920',
      tid: '920',
      fid: '30',
      title: '未初始化未读',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-921-1-1.html',
            rawText: '1',
            episodeTitle: '第1话',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );

    final snapshot = await repository.queryShelfSnapshot(
      filters: const LibraryFilterSet(unread: TriStateFilterValue.include),
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );

    expect(
      snapshot.itemsByCategory['comic-default']!.single.workId,
      'yamibo:920',
    );
    expect(snapshot.itemsByCategory['comic-default']!.single.unreadCount, 1);
  });

  test('can persist reading progress and image cache status', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/1.jpg'],
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
      ),
    );

    const episodeId = 'yamibo:100:101';
    await repository.saveEpisodeImages(
      episodeId: episodeId,
      imageUrls: const <String>[
        'https://img.test/101-1.jpg',
        'https://img.test/101-2.jpg',
      ],
    );
    await repository.updateEpisodeImageCacheStatus(
      episodeId: episodeId,
      imageUrl: 'https://img.test/101-1.jpg',
      cacheStatus: 'done',
      cacheLocalPath: '/tmp/101-1.jpg',
    );
    await repository.updateLastReadProgress(
      comicId: 'yamibo:100',
      episodeId: episodeId,
      imageIndex: 1,
      scrollOffset: 222.5,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repository.updateLastReadProgress(
      comicId: 'yamibo:100',
      episodeId: 'yamibo:100:102',
      imageIndex: 0,
      scrollOffset: 12,
    );

    final images = await repository.getEpisodeImages(episodeId: episodeId);
    final progress = await repository.getLastReadProgress(
      comicId: 'yamibo:100',
    );
    final firstEpisodeProgress = await repository.getReadingProgressForEpisode(
      comicId: 'yamibo:100',
      episodeId: episodeId,
    );
    final progresses = await repository.getReadingProgresses(
      comicId: 'yamibo:100',
    );

    expect(images.length, 2);
    expect(images.first.cacheStatus, 'done');
    expect(images.first.cacheLocalPath, '/tmp/101-1.jpg');
    expect(progress, isNotNull);
    expect(progress!.episodeId, 'yamibo:100:102');
    expect(firstEpisodeProgress?.imageIndex, 1);
    expect(firstEpisodeProgress?.scrollOffset, 222.5);
    expect(progresses.map((item) => item.episodeId), <String>[
      'yamibo:100:102',
      episodeId,
    ]);

    await repository.clearReadingProgress(
      comicId: 'yamibo:100',
      episodeId: 'yamibo:100:102',
    );
    final fallbackProgress = await repository.getLastReadProgress(
      comicId: 'yamibo:100',
    );
    expect(fallbackProgress?.episodeId, episodeId);
    expect(
      await repository.getReadingProgressForEpisode(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:102',
      ),
      isNull,
    );

    await repository.clearReadingProgress(
      comicId: 'yamibo:100',
      episodeId: episodeId,
    );
    expect(
      await repository.getReadingProgresses(comicId: 'yamibo:100'),
      isEmpty,
    );
    final db = await dbFuture;
    final comicRow = await db.query(
      AppDatabase.comicsTable,
      columns: const <String>['last_read_episode_id'],
      where: 'comic_id = ?',
      whereArgs: const <Object>['yamibo:100'],
    );
    expect(comicRow.single['last_read_episode_id'], isNull);
  });

  test(
    'resetComicReadingState clears reading data and preserves durable state',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:reset',
        tid: '1000',
        fid: '30',
        title: '重置测试漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-1001-1-1.html',
              rawText: '1',
              episodeTitle: '第1话',
            ),
            ComicEpisodeLink(
              url: 'thread-1002-1-1.html',
              rawText: '2',
              episodeTitle: '第2话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );
      const firstEpisodeId = 'yamibo:reset:1001';
      const secondEpisodeId = 'yamibo:reset:1002';
      final stateRepository = LocalLibraryStateRepository(dbFuture);
      final downloadedAt = DateTime(2026, 7, 22, 12);
      await stateRepository.upsertEpisodeState(
        moduleKey: LibraryModuleKey.comic,
        episodeId: firstEpisodeId,
        workId: 'yamibo:reset',
        isRead: true,
        isDownloaded: true,
        isBookmarked: true,
        readAt: DateTime(2026, 7, 22, 11),
        downloadedAt: downloadedAt,
      );
      await stateRepository.upsertWorkState(
        moduleKey: LibraryModuleKey.comic,
        workId: 'yamibo:reset',
        lastReadEpisodeId: secondEpisodeId,
        lastReadAt: DateTime(2026, 7, 22, 11),
        introText: '保留简介',
      );
      await repository.saveEpisodeImages(
        episodeId: firstEpisodeId,
        imageUrls: const <String>['https://img.test/reset-1.jpg'],
      );
      await repository.updateEpisodeImageCacheStatus(
        episodeId: firstEpisodeId,
        imageUrl: 'https://img.test/reset-1.jpg',
        cacheStatus: 'done',
        cacheLocalPath: '/tmp/reset-1.jpg',
      );
      await repository.updateLastReadProgress(
        comicId: 'yamibo:reset',
        episodeId: firstEpisodeId,
        imageIndex: 4,
        scrollOffset: 400,
      );
      await repository.updateLastReadProgress(
        comicId: 'yamibo:reset',
        episodeId: secondEpisodeId,
        imageIndex: 2,
        scrollOffset: 200,
      );

      final db = await dbFuture;
      final comicUpdatedAtBeforeReset = (await db.query(
        AppDatabase.comicsTable,
        columns: const <String>['updated_at'],
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:reset'],
      )).single['updated_at'];
      final workUpdatedAtBeforeReset = (await db.query(
        AppDatabase.libraryWorkStateTable,
        columns: const <String>['updated_at'],
        where: 'content_type = ? AND work_id = ?',
        whereArgs: const <Object>['comic', 'yamibo:reset'],
      )).single['updated_at'];

      await repository.resetComicReadingState(comicId: 'yamibo:reset');

      final stateRows = await db.query(
        AppDatabase.libraryEpisodeStateTable,
        where: 'content_type = ? AND work_id = ?',
        whereArgs: const <Object>['comic', 'yamibo:reset'],
        orderBy: 'episode_id ASC',
      );
      expect(stateRows, hasLength(2));
      expect(stateRows.every((row) => row['is_read'] == 0), isTrue);
      final firstState = stateRows.firstWhere(
        (row) => row['episode_id'] == firstEpisodeId,
      );
      expect(firstState['is_downloaded'], 1);
      expect(firstState['is_bookmarked'], 1);
      expect(firstState['downloaded_at'], downloadedAt.millisecondsSinceEpoch);
      expect(firstState['read_at'], isNull);
      expect(
        await repository.getReadingProgresses(comicId: 'yamibo:reset'),
        isEmpty,
      );
      final comicRows = await db.query(
        AppDatabase.comicsTable,
        columns: const <String>['last_read_episode_id', 'updated_at'],
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:reset'],
      );
      expect(comicRows.single['last_read_episode_id'], isNull);
      expect(comicRows.single['updated_at'], comicUpdatedAtBeforeReset);
      final workStateRows = await db.query(
        AppDatabase.libraryWorkStateTable,
        columns: const <String>['updated_at'],
        where: 'content_type = ? AND work_id = ?',
        whereArgs: const <Object>['comic', 'yamibo:reset'],
      );
      expect(workStateRows.single['updated_at'], workUpdatedAtBeforeReset);
      final workState = await stateRepository.getWorkState(
        moduleKey: LibraryModuleKey.comic,
        workId: 'yamibo:reset',
      );
      expect(workState?.lastReadEpisodeId, isNull);
      expect(workState?.lastReadAt, isNull);
      expect(workState?.introText, '保留简介');
      final images = await repository.getEpisodeImages(
        episodeId: firstEpisodeId,
      );
      expect(images.single.cacheStatus, 'done');
      expect(images.single.cacheLocalPath, '/tmp/reset-1.jpg');
    },
  );
}
