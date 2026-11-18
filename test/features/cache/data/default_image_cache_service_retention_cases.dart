part of 'default_image_cache_service_test.dart';

void _retentionCases() {
  test('clearUnprotected spares sticky long-term cache', () async {
    final repository = _MemoryImageCacheRepository()
      ..records['thread-1'] = CachedImageRecord(
        cacheKey: 'thread-1',
        ownerType: ImageCacheOwnerType.thread.dbValue,
        ownerId: 'tid-1',
        role: ImageCacheRole.threadInline.dbValue,
        bytes: 3,
        protected: false,
        retentionClass: ImageRetentionClass.ephemeral,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      )
      ..records['smiley-1'] = CachedImageRecord(
        cacheKey: 'smiley-1',
        ownerType: ImageCacheOwnerType.sticker.dbValue,
        ownerId: 'yamibo-smiley-v4',
        role: ImageCacheRole.remoteSmiley.dbValue,
        bytes: 3,
        protected: false,
        retentionClass: ImageRetentionClass.sticky,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      )
      ..records['avatar-1'] = CachedImageRecord(
        cacheKey: 'avatar-1',
        ownerType: ImageCacheOwnerType.profile.dbValue,
        ownerId: 'uid-1',
        role: ImageCacheRole.avatar.dbValue,
        bytes: 3,
        protected: false,
        retentionClass: ImageRetentionClass.recentReader,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    final service = DefaultImageCacheService(
      repository: repository,
      cacheManagerFuture: Future<BaseCacheManager>.value(_UnusedCacheManager()),
      directoryResolver: const ImageCacheDirectoryResolver(),
    );

    final usage = await service.loadUsage();
    expect(usage.budgetedBytes, 6);
    expect(usage.clearableBytes, 6);
    expect(usage.longTermBytes, 3);

    await service.clearUnprotected();

    // 常规与 recentReader 被清，sticky 保留。
    expect(repository.records.containsKey('thread-1'), isFalse);
    expect(repository.records.containsKey('avatar-1'), isFalse);
    expect(repository.records.containsKey('smiley-1'), isTrue);
  });

  test('pruneToLimit excludes sticky from the regular cache budget', () async {
    final repository = _MemoryImageCacheRepository()
      ..records['smiley-1'] = CachedImageRecord(
        cacheKey: 'smiley-1',
        ownerType: ImageCacheOwnerType.sticker.dbValue,
        ownerId: 'yamibo-smiley-v4',
        role: ImageCacheRole.remoteSmiley.dbValue,
        bytes: 100,
        protected: false,
        retentionClass: ImageRetentionClass.sticky,
        // 更久未访问：若仅按 LRU 会先删它，但 sticky 应后于 ephemeral。
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        lastAccessedAt: DateTime(2026, 1, 1),
      )
      ..records['thread-1'] = CachedImageRecord(
        cacheKey: 'thread-1',
        ownerType: ImageCacheOwnerType.thread.dbValue,
        ownerId: 'tid-1',
        role: ImageCacheRole.threadInline.dbValue,
        bytes: 100,
        protected: false,
        retentionClass: ImageRetentionClass.ephemeral,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
        lastAccessedAt: DateTime(2026, 2, 1),
      );
    final service = DefaultImageCacheService(
      repository: repository,
      cacheManagerFuture: Future<BaseCacheManager>.value(_UnusedCacheManager()),
      directoryResolver: const ImageCacheDirectoryResolver(),
    );

    // 常规缓存 100，长期缓存 100 不计入额度。限额 50 时只删常规缓存。
    await service.pruneToLimit(maxBytes: 50);

    expect(repository.records.containsKey('thread-1'), isFalse);
    expect(repository.records.containsKey('smiley-1'), isTrue);
  });
}
