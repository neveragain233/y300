part of 'default_image_cache_service_test.dart';

void _ownerClearCases() {
  test(
    'deleteByOwner removes all owner records and ignores missing files',
    () async {
      final tempDir = await io.Directory.systemTemp.createTemp(
        'y300-image-cache-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final existingProtected = io.File('${tempDir.path}/protected.jpg');
      final existingPage = io.File('${tempDir.path}/page.jpg');
      await existingProtected.writeAsBytes(<int>[1, 2, 3]);
      await existingPage.writeAsBytes(<int>[4, 5, 6]);

      final repository = _MemoryImageCacheRepository()
        ..records['cover-1'] = CachedImageRecord(
          cacheKey: 'cover-1',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.cover.dbValue,
          localPath: existingProtected.path,
          bytes: 3,
          protected: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        ..records['page-1'] = CachedImageRecord(
          cacheKey: 'page-1',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.comicPage.dbValue,
          localPath: existingPage.path,
          bytes: 3,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        ..records['missing-1'] = CachedImageRecord(
          cacheKey: 'missing-1',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.comicPage.dbValue,
          localPath: '${tempDir.path}/missing.jpg',
          bytes: 0,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        ..records['other-owner'] = CachedImageRecord(
          cacheKey: 'other-owner',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:200',
          role: ImageCacheRole.cover.dbValue,
          localPath: '${tempDir.path}/other.jpg',
          bytes: 0,
          protected: true,
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

      final deletedCount = await service.deleteByOwner(
        ownerType: ImageCacheOwnerType.comic,
        ownerId: 'yamibo:100',
      );

      expect(deletedCount, 3);
      expect(repository.records.keys, <String>{'other-owner'});
      expect(await existingProtected.exists(), isFalse);
      expect(await existingPage.exists(), isFalse);
    },
  );

  test(
    'clearUnprotectedByRoles deletes only matching unprotected roles',
    () async {
      final tempDir = await io.Directory.systemTemp.createTemp(
        'y300-image-cache-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final comicPageFile = io.File('${tempDir.path}/comic-page.jpg');
      final threadFile = io.File('${tempDir.path}/thread.jpg');
      await comicPageFile.writeAsBytes(<int>[1, 2, 3]);
      await threadFile.writeAsBytes(<int>[4, 5, 6]);

      final repository = _MemoryImageCacheRepository()
        // 命中：漫画页，非保护 -> 删。
        ..records['comic-page-1'] = CachedImageRecord(
          cacheKey: 'comic-page-1',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.comicPage.dbValue,
          localPath: comicPageFile.path,
          bytes: 3,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        // 命中：帖子内联图，非保护 -> 删。
        ..records['thread-1'] = CachedImageRecord(
          cacheKey: 'thread-1',
          ownerType: ImageCacheOwnerType.thread.dbValue,
          ownerId: 'tid-1',
          role: ImageCacheRole.threadInline.dbValue,
          localPath: threadFile.path,
          bytes: 3,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        // 保留：封面，非保护但 role 不在清理集合。
        ..records['cover-1'] = CachedImageRecord(
          cacheKey: 'cover-1',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.cover.dbValue,
          localPath: '${tempDir.path}/cover.jpg',
          bytes: 0,
          protected: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        )
        // 保留：漫画页但受保护。
        ..records['protected-page-1'] = CachedImageRecord(
          cacheKey: 'protected-page-1',
          ownerType: ImageCacheOwnerType.comic.dbValue,
          ownerId: 'yamibo:100',
          role: ImageCacheRole.comicPage.dbValue,
          localPath: '${tempDir.path}/protected-page.jpg',
          bytes: 0,
          protected: true,
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

      final deletedCount = await service.clearUnprotectedByRoles(
        roles: const <ImageCacheRole>[
          ImageCacheRole.comicPage,
          ImageCacheRole.threadInline,
        ],
      );

      expect(deletedCount, 2);
      expect(repository.records.keys, <String>{'cover-1', 'protected-page-1'});
      expect(await comicPageFile.exists(), isFalse);
      expect(await threadFile.exists(), isFalse);
    },
  );

  test('clearUnprotectedByRoles with empty roles deletes nothing', () async {
    final repository = _MemoryImageCacheRepository()
      ..records['comic-page-1'] = CachedImageRecord(
        cacheKey: 'comic-page-1',
        ownerType: ImageCacheOwnerType.comic.dbValue,
        ownerId: 'yamibo:100',
        role: ImageCacheRole.comicPage.dbValue,
        bytes: 3,
        protected: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    final service = DefaultImageCacheService(
      repository: repository,
      cacheManagerFuture: Future<BaseCacheManager>.value(_UnusedCacheManager()),
      directoryResolver: const ImageCacheDirectoryResolver(),
    );

    final deletedCount = await service.clearUnprotectedByRoles(
      roles: const <ImageCacheRole>[],
    );

    expect(deletedCount, 0);
    expect(repository.records.keys, <String>{'comic-page-1'});
  });
}
