part of 'local_comic_repository_test.dart';

void _shelfIngestCases() {
  test('adds comic to shelf and can query shelf state', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      sourceTypeId: '398',
      sourceTagName: '韩国漫画',
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
        inferredAuthor: '作者A',
      ),
    );

    final inShelf = await repository.isInShelf(comicId: 'yamibo:100');
    final items = await repository.getShelfItems();

    expect(inShelf, isTrue);
    expect(items.length, 1);
    expect(items.first.title, '测试漫画');
    expect(items.first.sourceTypeId, '398');
    expect(items.first.sourceTagName, '韩国漫画');
    expect(items.first.author, '作者A');
    expect(items.first.coverImageUrl, 'https://img.test/cover.jpg');
  });

  test('addToShelf is idempotent for same comic', () async {
    const parsed = ParsedComicPost(
      imageUrls: <String>['https://img.test/cover.jpg'],
      episodeLinks: <ComicEpisodeLink>[],
      plainTextSummary: '摘要',
    );

    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: parsed,
    );

    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: parsed,
    );

    final items = await repository.getShelfItems();
    expect(items.length, 1);
  });

  test('favorite ingest keeps the original remote favorite date', () async {
    const parsed = ParsedComicPost(
      imageUrls: <String>[],
      episodeLinks: <ComicEpisodeLink>[],
      plainTextSummary: '摘要',
    );
    final originalAddedAt = DateTime(2026, 7, 1, 9);

    await repository.addFavoriteToShelf(
      comicId: 'yamibo:favorite-date',
      tid: 'favorite-date',
      fid: '30',
      title: '收藏时间漫画',
      parsedPost: parsed,
      favoriteAddedAt: originalAddedAt,
    );
    await repository.addFavoriteToShelf(
      comicId: 'yamibo:favorite-date',
      tid: 'favorite-date',
      fid: '30',
      title: '收藏时间漫画',
      parsedPost: parsed,
      favoriteAddedAt: DateTime(2026, 7, 20),
    );

    final item = (await repository.getShelfItems()).single;
    expect(item.addedAt, originalAddedAt);
  });

  test(
    'custom catalog overrides source without being replaced by ingest',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:catalog-config',
        tid: '100',
        fid: '30',
        title: '目录配置漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
          catalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
        ),
      );
      await repository.updateCustomCatalogUrl(
        comicId: 'yamibo:catalog-config',
        catalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
      );

      await repository.addToShelf(
        comicId: 'yamibo:catalog-config',
        tid: '100',
        fid: '30',
        title: '目录配置漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
          catalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=3',
        ),
      );

      var detail = await repository.getComicDetail(
        comicId: 'yamibo:catalog-config',
      );
      expect(
        detail?.catalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=3',
      );
      expect(
        detail?.customCatalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
      );
      expect(
        detail?.effectiveCatalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
      );

      await repository.updateCustomCatalogUrl(
        comicId: 'yamibo:catalog-config',
        catalogUrl: null,
      );
      detail = await repository.getComicDetail(
        comicId: 'yamibo:catalog-config',
      );
      expect(
        detail?.effectiveCatalogUrl,
        'https://bbs.yamibo.com/misc.php?mod=tag&id=3',
      );
    },
  );

  test('addToShelf 单帖漫画用 subject metadata 的 episodeLabel 作为话名', () async {
    await repository.addToShelf(
      comicId: 'yamibo:single-thread',
      tid: '300',
      fid: '30',
      title: '【某汉化组】一帖完结漫画 第3话',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[
          'https://img.test/single-thread-page-1.jpg',
          'https://img.test/single-thread-page-2.jpg',
        ],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
        subjectMetadata: ComicSubjectMetadata(
          normalizedTitle: '一帖完结漫画',
          translationGroup: '某汉化组',
          episodeLabel: '第3话',
        ),
      ),
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:single-thread',
      descending: false,
    );

    // 单帖漫画：唯一一话 + 命名取自标题分析器的 episodeLabel。
    expect(episodes, hasLength(1));
    expect(episodes.first.episodeTitle, '第3话');
    expect(episodes.first.sourceTid, '300');
  });

  test('addToShelf 单帖漫画无 episodeLabel 时回落到规范化书名', () async {
    await repository.addToShelf(
      comicId: 'yamibo:single-no-label',
      tid: '301',
      fid: '30',
      title: '【组A】整本就一话漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/no-label.jpg'],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
        subjectMetadata: ComicSubjectMetadata(
          normalizedTitle: '整本就一话漫画',
          translationGroup: '组A',
        ),
      ),
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:single-no-label',
      descending: false,
    );

    expect(episodes, hasLength(1));
    expect(episodes.first.episodeTitle, '整本就一话漫画');
  });

  test(
    'favorite DEATHPAIR ingest includes its own act before search',
    () async {
      const comicId = 'yamibo:$deathpairSourceTid';
      const sourceEpisodeId = '$comicId:$deathpairSourceTid';
      final service = RepositoryComicFavoriteIngestService(
        repository: repository,
        parserService: HtmlComicParserService(),
        subjectParser: const RuleBasedComicSubjectParser(),
        aggregationService: const ComicPostAggregationService(),
      );
      final detail = ThreadDetailData(
        tid: deathpairSourceTid,
        fid: '30',
        typeid: '398',
        subject: deathpairSourceSubject,
        author: 'Author',
        replies: 0,
        views: 1,
        currentPage: 1,
        perPage: 20,
        posts: [
          ThreadPost(
            pid: '1',
            author: 'Author',
            authorId: '1',
            message:
                '$deathpairPreviousChaptersHtml'
                '<img src="https://img.test/source-30.jpg" />',
            number: 1,
            isFirst: true,
            dateline: '',
          ),
        ],
      );

      await service.upsertFromThreadDetail(
        detail: detail,
        favoriteAddedAt: DateTime(2026, 10, 6),
      );

      final episodes = await repository.getComicEpisodes(
        comicId: comicId,
        descending: false,
      );
      expect(
        episodes.map((episode) => episode.sourceTid),
        deathpairChapterTids,
      );
      expect(episodes.last.episodeTitle, '第30话');
      expect(episodes.last.orderIndex, 29);
      expect(
        const ForumReferenceResolver().extractTid(episodes.last.sourceUrl),
        deathpairSourceTid,
      );
      expect(
        (await repository.getEpisodeImages(episodeId: sourceEpisodeId))
            .single
            .imageUrl,
        'https://img.test/source-30.jpg',
      );

      await repository.updateLastReadProgress(
        comicId: comicId,
        episodeId: sourceEpisodeId,
        imageIndex: 0,
        scrollOffset: 42,
      );
      await repository.updateEpisodeImageCacheMetadata(
        episodeId: sourceEpisodeId,
        imageUrl: 'https://img.test/source-30.jpg',
        localPath: '/cache/source-30.jpg',
      );
      await service.upsertFromThreadDetail(
        detail: detail,
        favoriteAddedAt: DateTime(2026, 10, 6),
      );
      expect(
        (await repository.getComicEpisodes(comicId: comicId)),
        hasLength(30),
      );
      expect(
        (await repository.getReadingProgresses(comicId: comicId))
            .single
            .scrollOffset,
        42,
      );
      expect(
        (await repository.getEpisodeImages(episodeId: sourceEpisodeId))
            .single
            .localPath,
        '/cache/source-30.jpg',
      );
    },
  );

  test('favorite ingest preserves both combined chapter entries', () async {
    const comicId = 'yamibo:$magicalGirlSourceTid';
    final service = RepositoryComicFavoriteIngestService(
      repository: repository,
      parserService: HtmlComicParserService(),
      subjectParser: const RuleBasedComicSubjectParser(),
      aggregationService: const ComicPostAggregationService(),
    );
    await service.upsertFromThreadDetail(
      detail: ThreadDetailData(
        tid: magicalGirlSourceTid,
        fid: '30',
        typeid: '69',
        subject: magicalGirlSourceSubject,
        author: 'fixture',
        replies: 0,
        views: 1,
        currentPage: 1,
        perPage: 20,
        posts: [
          ThreadPost(
            pid: '1',
            author: 'fixture',
            authorId: '1',
            message:
                '$magicalGirlPreviousChaptersHtml'
                '<img src="https://img.test/source-15-16.jpg">',
            number: 1,
            isFirst: true,
            dateline: '',
          ),
        ],
      ),
      favoriteAddedAt: DateTime(2026, 10, 6),
    );

    final episodes = await repository.getComicEpisodes(
      comicId: comicId,
      descending: false,
    );
    expect(episodes.map((episode) => episode.sourceTid), [
      ...magicalGirlPreviousChapterAnchors.map((chapter) => chapter.$1),
      magicalGirlSourceTid,
    ]);
    expect(episodes[1].episodeTitle, '02-03');
    expect(episodes[1].orderIndex, 1);
    expect(episodes.last.episodeTitle, '15-16');
    expect(
      (await repository.getEpisodeImages(
        episodeId: '$comicId:$magicalGirlSourceTid',
      )).single.imageUrl,
      'https://img.test/source-15-16.jpg',
    );
  });

  test('manual ingest keeps an already linked source chapter once', () async {
    final parsed = HtmlComicParserService().parse(
      message:
          '$deathpairPreviousChaptersHtml'
          '<img src="https://img.test/source-30.jpg" />',
    );
    await repository.addToShelf(
      comicId: 'yamibo:$deathpairSourceTid',
      tid: deathpairSourceTid,
      fid: '30',
      title: deathpairSourceSubject,
      parsedPost: parsed.copyWith(
        subjectMetadata: const RuleBasedComicSubjectParser().parse(
          deathpairSourceSubject,
        ),
        episodeLinks: [
          ...parsed.episodeLinks,
          const ComicEpisodeLink(
            url: 'thread-$deathpairSourceTid-1-1.html',
            rawText: '第三十幕',
          ),
        ],
      ),
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:$deathpairSourceTid',
      descending: false,
    );
    expect(episodes.map((episode) => episode.sourceTid), deathpairChapterTids);
    expect(episodes.last.episodeTitle, '第三十幕');
  });

  test('addToShelf 解析出目录时不种入自身影子章节', () async {
    await repository.addToShelf(
      comicId: 'yamibo:catalog-only',
      tid: '400',
      fid: '30',
      title: '【某汉化组】目录贴漫画',
      parsedPost: const ParsedComicPost(
        // 目录已识别时，横幅图不能让目录帖成为章节。
        catalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
        imageUrls: <String>['https://img.test/catalog-banner.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-401-1-1.html',
            rawText: '第1话',
            episodeTitle: '第1话',
          ),
          ComicEpisodeLink(
            url: 'thread-402-1-1.html',
            rawText: '第2话',
            episodeTitle: '第2话',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:catalog-only',
      descending: false,
    );

    expect(episodes, hasLength(2));
    expect(episodes.map((episode) => episode.episodeTitle).toList(), <String?>[
      '第1话',
      '第2话',
    ]);
    expect(episodes.any((episode) => episode.sourceTid == '400'), isFalse);
  });

  for (final hasHistoricalLinks in [false, true]) {
    test(
      'catalog excludes source content with history=$hasHistoricalLinks',
      () async {
        final parsed = HtmlComicParserService().parse(
          message:
              '${hasHistoricalLinks ? deathpairPreviousChaptersHtml : ''}'
              '<a href="https://bbs.yamibo.com/misc.php?mod=tag&id=1">目录</a>'
              '<img src="https://img.test/banner.jpg" />',
        );
        await repository.addFavoriteToShelf(
          comicId: 'yamibo:$deathpairSourceTid',
          tid: deathpairSourceTid,
          fid: '30',
          title: deathpairSourceSubject,
          favoriteAddedAt: DateTime(2026, 10, 6),
          parsedPost: parsed.copyWith(
            subjectMetadata: const RuleBasedComicSubjectParser().parse(
              deathpairSourceSubject,
            ),
          ),
        );

        final episodes = await repository.getComicEpisodes(
          comicId: 'yamibo:$deathpairSourceTid',
          descending: false,
        );
        expect(
          episodes.map((episode) => episode.sourceTid),
          hasHistoricalLinks ? deathpairChapterTids.take(29) : isEmpty,
        );
        expect(
          await repository.getEpisodeImages(
            episodeId: 'yamibo:$deathpairSourceTid:$deathpairSourceTid',
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'removeFromShelf only removes shelf entry and keeps comic data',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:remove-only',
        tid: '150',
        fid: '30',
        title: '保留数据漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/remove-only-cover.jpg'],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-151-1-1.html',
              rawText: '第1话',
              episodeTitle: '第1话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );
      const episodeId = 'yamibo:remove-only:151';
      await repository.saveEpisodeImages(
        episodeId: episodeId,
        imageUrls: const <String>['https://img.test/remove-only-page-1.jpg'],
      );
      await repository.updateLastReadProgress(
        comicId: 'yamibo:remove-only',
        episodeId: episodeId,
        imageIndex: 0,
        scrollOffset: 18,
      );
      final originalEpisodes = await repository.getComicEpisodes(
        comicId: 'yamibo:remove-only',
        descending: false,
      );

      await repository.removeFromShelf(comicId: 'yamibo:remove-only');

      final inShelf = await repository.isInShelf(comicId: 'yamibo:remove-only');
      final shelfItems = await repository.getShelfItems();
      final detail = await repository.getComicDetail(
        comicId: 'yamibo:remove-only',
      );
      final episodes = await repository.getComicEpisodes(
        comicId: 'yamibo:remove-only',
        descending: false,
      );
      final images = await repository.getEpisodeImages(episodeId: episodeId);
      final progress = await repository.getLastReadProgress(
        comicId: 'yamibo:remove-only',
      );

      expect(inShelf, isFalse);
      expect(shelfItems, isEmpty);
      expect(detail, isNotNull);
      expect(
        episodes.map((episode) => episode.episodeId),
        originalEpisodes.map((episode) => episode.episodeId),
      );
      expect(images, hasLength(1));
      expect(progress, isNotNull);
      expect(progress?.episodeId, episodeId);
    },
  );

  test('purgeWork deletes comic rows and cascaded episode data only for target comic', () async {
    await repository.addToShelf(
      comicId: 'yamibo:purge-a',
      tid: '160',
      fid: '30',
      title: '待清理漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/purge-a-cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-161-1-1.html',
            rawText: '第1话',
            episodeTitle: '第1话',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );
    await repository.addToShelf(
      comicId: 'yamibo:purge-b',
      tid: '260',
      fid: '30',
      title: '保留漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/purge-b-cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-261-1-1.html',
            rawText: '第1话',
            episodeTitle: '第1话',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );
    const purgeEpisodeId = 'yamibo:purge-a:161';
    await repository.saveEpisodeImages(
      episodeId: purgeEpisodeId,
      imageUrls: const <String>['https://img.test/purge-a-page-1.jpg'],
    );
    await repository.updateLastReadProgress(
      comicId: 'yamibo:purge-a',
      episodeId: purgeEpisodeId,
      imageIndex: 1,
      scrollOffset: 64,
    );

    final originalRemainingEpisodes = await repository.getComicEpisodes(
      comicId: 'yamibo:purge-b',
      descending: false,
    );
    await repository.purgeWork(comicId: 'yamibo:purge-a');

    final db = await dbFuture;
    final remainingDetail = await repository.getComicDetail(
      comicId: 'yamibo:purge-b',
    );
    final remainingEpisodes = await repository.getComicEpisodes(
      comicId: 'yamibo:purge-b',
      descending: false,
    );
    final purgedProgress = await repository.getLastReadProgress(
      comicId: 'yamibo:purge-a',
    );

    expect(
      await db.query(
        AppDatabase.comicsTable,
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:purge-a'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        AppDatabase.episodesTable,
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:purge-a'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        AppDatabase.episodeImagesTable,
        where: 'episode_id = ?',
        whereArgs: const <Object>[purgeEpisodeId],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        AppDatabase.shelfItemsTable,
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:purge-a'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        AppDatabase.readingProgressTable,
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:purge-a'],
      ),
      isEmpty,
    );
    expect(purgedProgress, isNull);
    expect(remainingDetail, isNotNull);
    expect(
      remainingEpisodes.map((episode) => episode.episodeId),
      originalRemainingEpisodes.map((episode) => episode.episodeId),
    );
    expect(
      await db.query(
        AppDatabase.comicsTable,
        where: 'comic_id = ?',
        whereArgs: const <Object>['yamibo:purge-b'],
      ),
      isNotEmpty,
    );
  });

  test(
    'addToShelf prefers normalized title and subject-derived author metadata',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:200',
        tid: '200',
        fid: '30',
        title: '【某汉化组】[作者X]作品名 12',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/cover-2.jpg'],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
          inferredAuthor: '内容作者Y',
          subjectMetadata: ComicSubjectMetadata(
            normalizedTitle: '作品名',
            translationGroup: '某汉化组',
            inferredAuthor: '作者X',
            episodeLabel: '12',
          ),
        ),
      );

      final detail = await repository.getComicDetail(comicId: 'yamibo:200');
      expect(detail, isNotNull);
      expect(detail!.title, '作品名');
      expect(detail.author, '作者X');
      expect(detail.translationGroup, '某汉化组');
    },
  );
}
