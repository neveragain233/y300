part of 'local_comic_repository_test.dart';

void _duplicateGroupCases() {
  test(
    'mergeDuplicateGroup keeps shortest title and merges unique episodes',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:1000',
        tid: '1000',
        fid: '30',
        title: '很长的重复漫画标题',
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
      await repository.addToShelf(
        comicId: 'yamibo:2000',
        tid: '2000',
        fid: '30',
        title: '短标题',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-1002-1-1.html',
              rawText: '2',
              episodeTitle: '第二话完整标题',
            ),
            ComicEpisodeLink(
              url: 'thread-1003-1-1.html',
              rawText: '3',
              episodeTitle: '第3话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );

      final groups = await repository.findDuplicateGroups();
      final result = await repository.mergeDuplicateGroup(
        comicIds: groups.single.comicIds,
      );

      final detail = await repository.getComicDetail(
        comicId: result.targetComicId,
      );
      final removedDetail = await repository.getComicDetail(
        comicId: result.mergedComicIds.single,
      );
      final episodes = await repository.getComicEpisodes(
        comicId: result.targetComicId,
        descending: false,
      );
      final shelfItems = await repository.getShelfItems();

      expect(result.changed, isTrue);
      expect(result.targetComicId, 'yamibo:2000');
      expect(result.targetTitle, '短标题');
      expect(detail?.title, '短标题');
      expect(removedDetail, isNull);
      expect(episodes.map((episode) => episode.sourceTid).toList(), <String>[
        '1001',
        '1002',
        '1003',
      ]);
      expect(shelfItems.map((item) => item.comicId).toSet(), <String>{
        'yamibo:2000',
      });
    },
  );

  test(
    'mergeDuplicateGroup moves reading state tags and favorite work id safely',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:source',
        tid: '3000',
        fid: '30',
        title: '来源重复漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-3001-1-1.html',
              rawText: '1',
              episodeTitle: '第1话',
            ),
            ComicEpisodeLink(
              url: 'thread-3002-1-1.html',
              rawText: '2',
              episodeTitle: '第2话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );
      await repository.addToShelf(
        comicId: 'yamibo:target',
        tid: '4000',
        fid: '30',
        title: '短',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-3001-1-1.html',
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
        episodeId: 'yamibo:source:3001',
        workId: 'yamibo:source',
        isRead: true,
        isDownloaded: true,
      );
      await stateRepository.upsertEpisodeState(
        moduleKey: LibraryModuleKey.comic,
        episodeId: 'yamibo:source:3002',
        workId: 'yamibo:source',
        isRead: true,
      );
      final tagId = await stateRepository.createTag(name: '重复');
      await stateRepository.bindTagToWork(
        moduleKey: LibraryModuleKey.comic,
        workId: 'yamibo:source',
        tagId: tagId,
      );
      await repository.updateLastReadProgress(
        comicId: 'yamibo:source',
        episodeId: 'yamibo:source:3001',
        imageIndex: 2,
        scrollOffset: 42,
      );
      await repository.updateLastReadProgress(
        comicId: 'yamibo:source',
        episodeId: 'yamibo:source:3002',
        imageIndex: 4,
        scrollOffset: 84,
      );
      final db = await dbFuture;
      await db.insert(AppDatabase.favoriteThreadsTable, <String, Object?>{
        'tid': '3000',
        'title': '来源重复漫画',
        'content_kind': 'comic',
        'work_id': 'yamibo:source',
        'first_seen_at': 1,
        'last_seen_at': 1,
      });

      final result = await repository.mergeDuplicateGroup(
        comicIds: const <String>{'yamibo:source', 'yamibo:target'},
      );

      final snapshot = await repository.queryShelfSnapshot(
        filters: LibraryFilterSet.defaults,
        sortOption: LibraryShelfSortOption.defaults,
        keyword: '',
      );
      final item = snapshot.itemsByCategory['comic-default']!.single;
      final progresses = await repository.getReadingProgresses(
        comicId: result.targetComicId,
      );
      final favoriteRows = await db.query(
        AppDatabase.favoriteThreadsTable,
        columns: const <String>['work_id'],
        where: 'tid = ?',
        whereArgs: <Object>['3000'],
      );

      expect(result.targetComicId, 'yamibo:target');
      expect(item.readChapterCount, 2);
      expect(item.unreadCount, 0);
      expect(item.hasTags, isTrue);
      expect(
        <String, int>{
          for (final progress in progresses)
            progress.episodeId: progress.imageIndex,
        },
        <String, int>{'yamibo:target:3001': 2, 'yamibo:target:3002': 4},
      );
      expect(favoriteRows.single['work_id'], 'yamibo:target');
    },
  );
}
