part of 'default_image_cache_service_test.dart';

void _dimensionCases() {
  test(
    'recordResolvedDimensions updates existing cache record dimensions',
    () async {
      final repository = _MemoryImageCacheRepository();
      repository.records['page-1'] = CachedImageRecord(
        cacheKey: 'page-1',
        ownerType: ImageCacheOwnerType.thread.dbValue,
        ownerId: 'tid-1',
        role: ImageCacheRole.threadInline.dbValue,
        localPath: '/tmp/page.jpg',
        bytes: 1,
        protected: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final service = DefaultImageCacheService(
        repository: repository,
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
      );

      await service.recordResolvedDimensions(
        cacheKey: 'page-1',
        size: const Size(900, 1200),
      );

      expect(repository.records['page-1']?.width, 900);
      expect(repository.records['page-1']?.height, 1200);
    },
  );

  test(
    'dimension single-flight preserves real file and metadata validation',
    () async {
      final tempDir = await io.Directory.systemTemp.createTemp(
        'y300-dimension-index-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final image = io.File('${tempDir.path}/cached.jpg');
      await image.writeAsBytes(<int>[1, 2, 3]);
      const key = 'cover/dimension-test';
      final repository = _MemoryImageCacheRepository()
        ..records[key] = CachedImageRecord(
          cacheKey: key,
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'dimension-owner',
          role: ImageCacheRole.cover.dbValue,
          localPath: image.path,
          bytes: 3,
          width: 320,
          height: 200,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
      final service = DefaultImageCacheService(
        repository: repository,
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
      );
      final index = CacheRecordForumImageDimensionIndex(
        imageCacheService: service,
        imageRequestResolver: const DefaultForumImageRequestResolver(),
      );
      final spec = ForumImageLoadSpec(
        kind: ForumImageKind.cover,
        url: Uri.parse('https://bbs.yamibo.com/cache-dimension-test.jpg'),
        ownerId: 'dimension-owner',
        cacheKey: key,
      );
      final results = await Future.wait(
        List.generate(10, (_) => index.getBySpec(spec)),
      );
      expect(
        results.map((value) => value?.size),
        everyElement(const Size(320, 200)),
      );
      expect(repository.getByKeyCalls, 1);
      expect(repository.records[key]?.lastAccessedAt, isNull);
      expect(repository.touchCalls, 0);

      await image.delete();
      expect(await index.getBySpec(spec), isNull);
      expect(repository.getByKeyCalls, 2);

      await image.writeAsBytes(<int>[1, 2, 3, 4, 5, 6, 7]);
      expect((await service.peekCached(key))?.bytes, 7);
      await index.recordDecodedDimensions(
        spec: spec,
        size: const Size(640, 400),
      );
      final recordedAccess = repository.records[key]?.lastAccessedAt;
      expect((await index.getBySpec(spec))?.size, const Size(640, 400));
      expect(repository.records[key]?.lastAccessedAt, recordedAccess);
      expect(repository.touchCalls, 0);

      repository.records.remove(key);
      expect(await index.getBySpec(spec), isNull);
    },
  );

  test(
    'last known dimensions prefer current key then newest matching owner',
    () async {
      final repository = _MemoryImageCacheRepository()
        ..records['current-head'] = CachedImageRecord(
          cacheKey: 'current-head',
          ownerType: ImageCacheOwnerType.forum.dbValue,
          ownerId: 'forum:30',
          role: ImageCacheRole.forumHeadImage.dbValue,
          bytes: 1,
          width: 1200,
          height: 300,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        ..records['newer-head'] = CachedImageRecord(
          cacheKey: 'newer-head',
          ownerType: ImageCacheOwnerType.forum.dbValue,
          ownerId: 'forum:30',
          role: ImageCacheRole.forumHeadImage.dbValue,
          bytes: 1,
          width: 1600,
          height: 500,
          protected: false,
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        )
        ..records['other-forum'] = CachedImageRecord(
          cacheKey: 'other-forum',
          ownerType: ImageCacheOwnerType.forum.dbValue,
          ownerId: 'forum:33',
          role: ImageCacheRole.forumHeadImage.dbValue,
          bytes: 1,
          width: 999,
          height: 111,
          protected: false,
          createdAt: DateTime(2026, 1, 3),
          updatedAt: DateTime(2026, 1, 3),
        );
      final service = DefaultImageCacheService(
        repository: repository,
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
      );

      final current = await service.getLastKnownDimensions(
        ownerType: ImageCacheOwnerType.forum,
        ownerId: 'forum:30',
        role: ImageCacheRole.forumHeadImage,
        preferredCacheKey: 'current-head',
      );
      final latest = await service.getLastKnownDimensions(
        ownerType: ImageCacheOwnerType.forum,
        ownerId: 'forum:30',
        role: ImageCacheRole.forumHeadImage,
        preferredCacheKey: 'missing-head',
      );

      expect(current, const Size(1200, 300));
      expect(latest, const Size(1600, 500));
    },
  );
}
