part of 'local_comic_repository_test.dart';

void _categoryMetadataCases() {
  test('can create category and move comic across categories', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    final categoryId = await repository.createCategory(name: '追更');
    await repository.moveComicToCategory(
      comicId: 'yamibo:100',
      fromCategoryId: 'comic-default',
      toCategoryId: categoryId,
    );

    final defaultItems = await repository.getShelfItems(
      categoryId: 'comic-default',
    );
    final customItems = await repository.getShelfItems(categoryId: categoryId);

    expect(defaultItems, isEmpty);
    expect(customItems.length, 1);
    expect(customItems.first.comicId, 'yamibo:100');
  });

  test('deleting category moves comics back to default', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    final categoryId = await repository.createCategory(name: '归档');
    await repository.moveComicToCategory(
      comicId: 'yamibo:100',
      fromCategoryId: 'comic-default',
      toCategoryId: categoryId,
    );
    await repository.deleteCategory(categoryId: categoryId);

    final defaultItems = await repository.getShelfItems(
      categoryId: 'comic-default',
    );
    expect(defaultItems.length, 1);
    expect(defaultItems.first.comicId, 'yamibo:100');
  });

  test('favorite re-ingest keeps an existing custom collection', () async {
    const comicId = 'yamibo:300';
    await repository.addToShelf(
      comicId: comicId,
      tid: '300',
      fid: '30',
      title: '重复解析漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );
    final categoryId = await repository.createCategory(name: '收藏夹');
    await repository.moveComicToCategory(
      comicId: comicId,
      fromCategoryId: 'comic-default',
      toCategoryId: categoryId,
    );

    await repository.addFavoriteToShelf(
      comicId: comicId,
      tid: '300',
      fid: '30',
      title: '重复解析漫画',
      favoriteAddedAt: DateTime(2026, 1, 2),
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    expect(
      await repository.getShelfItems(categoryId: 'comic-default'),
      isEmpty,
    );
    expect(
      (await repository.getShelfItems(categoryId: categoryId)).single.comicId,
      comicId,
    );
  });

  test('type view snapshot includes works in a custom collection', () async {
    const comicId = 'yamibo:301';
    await repository.addToShelf(
      comicId: comicId,
      tid: '301',
      fid: '30',
      title: '收藏夹漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );
    final categoryId = await repository.createCategory(name: '稍后看');
    await repository.moveComicToCategory(
      comicId: comicId,
      fromCategoryId: 'comic-default',
      toCategoryId: categoryId,
    );

    final snapshot = await repository.queryShelfSnapshot(
      filters: LibraryFilterSet.defaults,
      sortOption: LibraryShelfSortOption.defaults,
      keyword: '',
    );

    expect(snapshot.itemsByCategory['comic-default']!.single.workId, comicId);
    expect(snapshot.itemsByCategory[categoryId]!.single.workId, comicId);
  });

  test('can update custom cover and display settings', () async {
    await repository.addToShelf(
      comicId: 'yamibo:100',
      tid: '100',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/original.jpg'],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    await repository.updateCustomCover(
      comicId: 'yamibo:100',
      customCoverImageUrl: 'https://img.test/custom.jpg',
    );

    await repository.updateGridColumnCount(columnCount: 4);

    final items = await repository.getShelfItems();
    final settings = await repository.getDisplaySettings();

    expect(items.first.coverImageUrl, 'https://img.test/custom.jpg');
    expect(items.first.customCoverImageUrl, 'https://img.test/custom.jpg');
    expect(settings.gridColumnCount, 4);
  });

  test('updating custom cover clears stale custom local path', () async {
    await repository.addToShelf(
      comicId: 'yamibo:101',
      tid: '101',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/original.jpg'],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    await repository.updateCustomCover(
      comicId: 'yamibo:101',
      customCoverImageUrl: 'https://img.test/custom-a.jpg',
    );
    await repository.updateCoverCache(
      comicId: 'yamibo:101',
      customCoverLocalPath: '/cache/custom-a.jpg',
    );
    await repository.updateCustomCover(
      comicId: 'yamibo:101',
      customCoverImageUrl: 'https://img.test/custom-b.jpg',
    );

    final detail = await repository.getComicDetail(comicId: 'yamibo:101');
    expect(detail?.coverImageUrl, 'https://img.test/custom-b.jpg');
    expect(detail?.customCoverImageUrl, 'https://img.test/custom-b.jpg');
    expect(detail?.customCoverLocalPath, isNull);
  });

  test(
    'custom metadata overrides display and can be cleared to source values',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:102',
        tid: '102',
        fid: '30',
        title: '【源组】[源作者]来源标题 第1话',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/original.jpg'],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
          subjectMetadata: ComicSubjectMetadata(
            normalizedTitle: '来源标题',
            translationGroup: '源组',
            inferredAuthor: '源作者',
          ),
        ),
      );

      await repository.updateCustomMetadata(
        comicId: 'yamibo:102',
        customTitle: '自定义标题',
        customAuthor: '自定义作者',
        customTranslationGroup: '自定义组',
        customSearchTitle: '搜索关键词',
      );

      var detail = await repository.getComicDetail(comicId: 'yamibo:102');
      var items = await repository.getShelfItems();
      expect(detail?.title, '自定义标题');
      expect(detail?.sourceTitle, '来源标题');
      expect(detail?.customTitle, '自定义标题');
      expect(detail?.author, '自定义作者');
      expect(detail?.translationGroup, '自定义组');
      expect(detail?.customSearchTitle, '搜索关键词');
      expect(items.single.title, '自定义标题');
      expect(items.single.translationGroup, '自定义组');

      await repository.clearCustomMetadata(
        comicId: 'yamibo:102',
        title: true,
        author: true,
        translationGroup: true,
        searchTitle: true,
      );

      detail = await repository.getComicDetail(comicId: 'yamibo:102');
      items = await repository.getShelfItems();
      expect(detail?.title, '来源标题');
      expect(detail?.customTitle, isNull);
      expect(detail?.author, '源作者');
      expect(detail?.translationGroup, '源组');
      expect(detail?.customSearchTitle, isNull);
      expect(items.single.title, '来源标题');
    },
  );

  test(
    'refreshing source metadata keeps custom metadata and display values',
    () async {
      const firstPost = ParsedComicPost(
        imageUrls: <String>['https://img.test/original.jpg'],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
        subjectMetadata: ComicSubjectMetadata(
          normalizedTitle: '旧来源',
          translationGroup: '旧组',
          inferredAuthor: '旧作者',
        ),
      );
      await repository.addToShelf(
        comicId: 'yamibo:103',
        tid: '103',
        fid: '30',
        title: '旧来源',
        parsedPost: firstPost,
      );
      await repository.updateCustomMetadata(
        comicId: 'yamibo:103',
        customTitle: '自定义标题',
        customAuthor: '自定义作者',
        customTranslationGroup: '自定义组',
        customSearchTitle: '自定义搜索',
      );

      await repository.addToShelf(
        comicId: 'yamibo:103',
        tid: '103',
        fid: '30',
        title: '新来源',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/new.jpg'],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
          subjectMetadata: ComicSubjectMetadata(
            normalizedTitle: '新来源',
            translationGroup: '新组',
            inferredAuthor: '新作者',
          ),
        ),
      );

      final detail = await repository.getComicDetail(comicId: 'yamibo:103');
      expect(detail?.sourceTitle, '新来源');
      expect(detail?.title, '自定义标题');
      expect(detail?.sourceAuthor, '新作者');
      expect(detail?.author, '自定义作者');
      expect(detail?.sourceTranslationGroup, '新组');
      expect(detail?.translationGroup, '自定义组');
      expect(detail?.customSearchTitle, '自定义搜索');
    },
  );
}
