part of 'local_comic_repository_test.dart';

void _imageCacheCases() {
  test('clearEpisodeImageCache resets unprotected cache metadata', () async {
    await repository.addToShelf(
      comicId: 'yamibo:clear-cache',
      tid: '800',
      fid: '30',
      title: '清理缓存漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/clear-cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-801-1-1.html',
            rawText: '第1话',
            episodeTitle: '第1话',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );
    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:clear-cache',
      descending: false,
    );
    final episodeId = episodes.first.episodeId;
    await repository.saveEpisodeImages(
      episodeId: episodeId,
      imageUrls: const <String>['https://img.test/page-1.jpg'],
    );
    await repository.updateEpisodeImageCacheStatus(
      episodeId: episodeId,
      imageUrl: 'https://img.test/page-1.jpg',
      cacheStatus: 'done',
      cacheLocalPath: '/cache/page-1.jpg',
    );

    await repository.clearEpisodeImageCache(episodeId: episodeId);

    final images = await repository.getEpisodeImages(episodeId: episodeId);
    expect(images.single.cacheStatus, 'none');
    expect(images.single.effectiveLocalPath, isNull);
  });

  test(
    'updateEpisodeImageCacheMetadata persists decoded image dimensions',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:image-size',
        tid: '810',
        fid: '30',
        title: '图片尺寸漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/size-cover.jpg'],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-811-1-1.html',
              rawText: '第1话',
              episodeTitle: '第1话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );
      final episodes = await repository.getComicEpisodes(
        comicId: 'yamibo:image-size',
        descending: false,
      );
      final episodeId = episodes.first.episodeId;
      await repository.saveEpisodeImages(
        episodeId: episodeId,
        imageUrls: const <String>['https://img.test/size-page-1.jpg'],
      );

      await repository.updateEpisodeImageCacheMetadata(
        episodeId: episodeId,
        imageUrl: 'https://img.test/size-page-1.jpg',
        width: 900,
        height: 1800,
      );

      final images = await repository.getEpisodeImages(episodeId: episodeId);
      expect(images.single.width, 900);
      expect(images.single.height, 1800);
    },
  );

  test(
    'replaceEpisodeImages preserves only unchanged index cache metadata',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:refresh-images',
        tid: '815',
        fid: '30',
        title: '刷新目录漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/refresh-cover.jpg'],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-816-1-1.html',
              rawText: '第1话',
              episodeTitle: '第1话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );
      final episodes = await repository.getComicEpisodes(
        comicId: 'yamibo:refresh-images',
        descending: false,
      );
      final episodeId = episodes.first.episodeId;
      await repository.saveEpisodeImages(
        episodeId: episodeId,
        imageUrls: const <String>[
          'https://img.test/keep.jpg',
          'https://img.test/change-old.jpg',
          'https://img.test/failed.jpg',
        ],
      );
      await repository.updateEpisodeImageCacheMetadata(
        episodeId: episodeId,
        imageUrl: 'https://img.test/keep.jpg',
        localPath: '/cache/keep.jpg',
        width: 900,
        height: 1800,
      );
      await repository.updateEpisodeImageCacheMetadata(
        episodeId: episodeId,
        imageUrl: 'https://img.test/change-old.jpg',
        localPath: '/cache/change-old.jpg',
        width: 800,
        height: 1600,
      );
      await repository.updateEpisodeImageCacheMetadata(
        episodeId: episodeId,
        imageUrl: 'https://img.test/failed.jpg',
        localPath: '/cache/failed.jpg',
        width: 700,
        height: 1400,
      );
      await repository.updateEpisodeImageCacheStatus(
        episodeId: episodeId,
        imageUrl: 'https://img.test/failed.jpg',
        cacheStatus: 'failed',
      );

      await repository.replaceEpisodeImages(
        episodeId: episodeId,
        imageUrls: const <String>[
          'https://img.test/keep.jpg',
          'https://img.test/change-new.jpg',
          'https://img.test/failed.jpg',
        ],
      );

      final images = await repository.getEpisodeImages(episodeId: episodeId);
      expect(images[0].localPath, '/cache/keep.jpg');
      expect(images[0].width, 900);
      expect(images[0].height, 1800);
      expect(images[1].imageUrl, 'https://img.test/change-new.jpg');
      expect(images[1].localPath, isNull);
      expect(images[1].width, isNull);
      expect(images[1].height, isNull);
      expect(images[1].cacheStatus, 'none');
      expect(images[2].imageUrl, 'https://img.test/failed.jpg');
      expect(images[2].effectiveLocalPath, isNull);
      expect(images[2].width, isNull);
      expect(images[2].height, isNull);
      expect(images[2].cacheStatus, 'none');
    },
  );

  test('failed image cache status clears persisted local path', () async {
    await repository.addToShelf(
      comicId: 'yamibo:failed-local-path',
      tid: '820',
      fid: '30',
      title: '失败缓存漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>['https://img.test/failed-cover.jpg'],
        episodeLinks: <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-821-1-1.html',
            rawText: '第1话',
            episodeTitle: '第1话',
          ),
        ],
        plainTextSummary: '摘要',
      ),
    );
    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:failed-local-path',
      descending: false,
    );
    final episodeId = episodes.first.episodeId;
    await repository.saveEpisodeImages(
      episodeId: episodeId,
      imageUrls: const <String>['https://img.test/failed-page-1.jpg'],
    );
    await repository.updateEpisodeImageCacheMetadata(
      episodeId: episodeId,
      imageUrl: 'https://img.test/failed-page-1.jpg',
      localPath: '/cache/failed-page-1.jpg',
    );

    await repository.updateEpisodeImageCacheStatus(
      episodeId: episodeId,
      imageUrl: 'https://img.test/failed-page-1.jpg',
      cacheStatus: 'failed',
    );

    final images = await repository.getEpisodeImages(episodeId: episodeId);
    expect(images.single.cacheStatus, 'failed');
    expect(images.single.effectiveLocalPath, isNull);
  });
}
