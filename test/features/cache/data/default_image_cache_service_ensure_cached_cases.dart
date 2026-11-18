part of 'default_image_cache_service_test.dart';

void _ensureCachedCases() {
  test('ensureCached deduplicates concurrent same-key downloads', () async {
    final tempDir = await io.Directory.systemTemp.createTemp(
      'y300-image-cache-dedupe-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final imageFile = io.File('${tempDir.path}/downloaded.jpg');
    await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);
    final downloadCompleter = Completer<String>();
    final downloader = _SpyImageFileDownloader(
      localPath: imageFile.path,
      downloadCompleter: downloadCompleter,
    );
    final service = DefaultImageCacheService(
      repository: _MemoryImageCacheRepository(),
      cacheManagerFuture: Future<BaseCacheManager>.value(_UnusedCacheManager()),
      directoryResolver: const ImageCacheDirectoryResolver(),
      downloader: downloader,
    );
    const request = ImageCacheRequest(
      cacheKey: 'comic-page-dedupe',
      sourceUrl: 'https://bbs.yamibo.com/data/attachment/page.jpg',
      ownerType: ImageCacheOwnerType.comic,
      ownerId: 'yamibo:100',
      role: ImageCacheRole.comicPage,
    );

    final first = service.ensureCached(request);
    final second = service.ensureCached(request);
    await Future<void>.delayed(Duration.zero);

    expect(downloader.downloadCount, 1);
    downloadCompleter.complete(imageFile.path);
    await Future.wait(<Future<CachedImageResult>>[first, second]);
  });

  test(
    'ensureCached passes only the resource referer to cache manager',
    () async {
      final tempDir = await io.Directory.systemTemp.createTemp(
        'y300-image-cache-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final imageFile = io.File('${tempDir.path}/downloaded.jpg');
      await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);
      final downloader = _SpyImageFileDownloader(localPath: imageFile.path);
      final service = DefaultImageCacheService(
        repository: _MemoryImageCacheRepository(),
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
        downloader: downloader,
      );

      final result = await service.ensureCached(
        const ImageCacheRequest(
          cacheKey: 'comic-page-1',
          sourceUrl: 'https://bbs.yamibo.com/data/attachment/test.jpg',
          referer: 'https://bbs.yamibo.com/thread-1-1-1.html',
          ownerType: ImageCacheOwnerType.comic,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.comicPage,
        ),
      );

      expect(result.success, isTrue);
      expect(downloader.lastHeaders, <String, String>{
        'Referer': 'https://bbs.yamibo.com/thread-1-1-1.html',
      });
    },
  );

  test(
    'ensureCached normalizes relative source url before downloading',
    () async {
      final tempDir = await io.Directory.systemTemp.createTemp(
        'y300-image-cache-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final imageFile = io.File('${tempDir.path}/downloaded.jpg');
      await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);
      final downloader = _SpyImageFileDownloader(localPath: imageFile.path);
      final repository = _MemoryImageCacheRepository();
      final service = DefaultImageCacheService(
        repository: repository,
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
        downloader: downloader,
      );

      await service.ensureCached(
        const ImageCacheRequest(
          cacheKey: 'comic-page-1',
          sourceUrl: 'data/attachment/test.jpg',
          ownerType: ImageCacheOwnerType.comic,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.comicPage,
        ),
      );

      expect(
        downloader.lastSourceUrl,
        'https://bbs.yamibo.com/data/attachment/test.jpg',
      );
      expect(
        repository.records['comic-page-1']?.lastSourceUrl,
        'https://bbs.yamibo.com/data/attachment/test.jpg',
      );
    },
  );

  test(
    'ensureCached redownloads when a stable key gets a new source url',
    () async {
      final tempDir = await io.Directory.systemTemp.createTemp(
        'y300-image-cache-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final oldFile = io.File('${tempDir.path}/old.jpg');
      final newFile = io.File('${tempDir.path}/new.jpg');
      await oldFile.writeAsBytes(<int>[1, 2, 3]);
      await newFile.writeAsBytes(<int>[4, 5, 6, 7]);

      final repository = _MemoryImageCacheRepository();
      repository.records['cover/comic/yamibo:100'] = CachedImageRecord(
        cacheKey: 'cover/comic/yamibo:100',
        ownerType: ImageCacheOwnerType.comic.dbValue,
        ownerId: 'yamibo:100',
        role: ImageCacheRole.cover.dbValue,
        lastSourceUrl: 'https://bbs.yamibo.com/data/attachment/old.jpg',
        localPath: oldFile.path,
        bytes: 3,
        protected: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final downloader = _SpyImageFileDownloader(localPath: newFile.path);
      final service = DefaultImageCacheService(
        repository: repository,
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
        downloader: downloader,
      );

      final result = await service.ensureCached(
        const ImageCacheRequest(
          cacheKey: 'cover/comic/yamibo:100',
          sourceUrl: 'https://bbs.yamibo.com/data/attachment/new.jpg',
          ownerType: ImageCacheOwnerType.comic,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.cover,
          protected: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.localPath, newFile.path);
      expect(result.fromCache, isFalse);
      expect(
        downloader.lastSourceUrl,
        'https://bbs.yamibo.com/data/attachment/new.jpg',
      );
      expect(downloader.lastForce, isTrue);
      expect(
        repository.records['cover/comic/yamibo:100']?.lastSourceUrl,
        'https://bbs.yamibo.com/data/attachment/new.jpg',
      );
    },
  );
}
