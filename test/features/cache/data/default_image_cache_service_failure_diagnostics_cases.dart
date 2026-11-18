part of 'default_image_cache_service_test.dart';

void _failureDiagnosticsCases() {
  test(
    'download failures emit one privacy-safe structured diagnostic',
    () async {
      final recorder = _RecordingImageCacheDiagnosticRecorder();
      final service = DefaultImageCacheService(
        repository: _MemoryImageCacheRepository(),
        cacheManagerFuture: Future<BaseCacheManager>.value(
          _UnusedCacheManager(),
        ),
        directoryResolver: const ImageCacheDirectoryResolver(),
        downloader: const _FailingImageFileDownloader(),
        diagnosticRecorder: recorder,
      );
      const cacheKey = 'private/cache/key/123';

      final result = await service.ensureCached(
        const ImageCacheRequest(
          cacheKey: cacheKey,
          sourceUrl:
              'https://bbs.yamibo.com/forum.php?mod=image&aid=123&key=secret',
          referer:
              'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=private',
          ownerType: ImageCacheOwnerType.composer,
          ownerId: 'private-owner',
          role: ImageCacheRole.composerUnusedAttachment,
        ),
      );

      expect(result.success, isFalse);
      expect(recorder.events, hasLength(1));
      final event = recorder.events.single;
      expect(event.stage, ImageCacheDiagnosticStage.download);
      expect(event.ownerType, ImageCacheOwnerType.composer.dbValue);
      expect(event.role, ImageCacheRole.composerUnusedAttachment.dbValue);
      expect(event.failureKind, ImageCacheDiagnosticFailureKind.invalidContent);
      expect(event.reasonCode, 'resource_is_not_image');
      expect(event.cacheKeyFingerprint, isNot(contains(cacheKey)));
      expect(event.cacheKeyFingerprint, hasLength(16));
    },
  );

  test('diagnostic recorder failures never change cache result', () async {
    final service = DefaultImageCacheService(
      repository: _MemoryImageCacheRepository(),
      cacheManagerFuture: Future<BaseCacheManager>.value(_UnusedCacheManager()),
      directoryResolver: const ImageCacheDirectoryResolver(),
      downloader: const _FailingImageFileDownloader(),
      diagnosticRecorder: const _ThrowingImageCacheDiagnosticRecorder(),
    );

    final result = await service.ensureCached(
      const ImageCacheRequest(
        cacheKey: 'failure-isolation',
        sourceUrl: 'https://bbs.yamibo.com/image.png',
        ownerType: ImageCacheOwnerType.thread,
        ownerId: 'thread-owner',
        role: ImageCacheRole.threadInline,
      ),
    );

    expect(result.success, isFalse);
  });

  test(
    'manager initialization failures are classified and contained',
    () async {
      final recorder = _RecordingImageCacheDiagnosticRecorder();
      final managerCompleter = Completer<BaseCacheManager>();
      final service = DefaultImageCacheService(
        repository: _MemoryImageCacheRepository(),
        cacheManagerFuture: managerCompleter.future,
        directoryResolver: const ImageCacheDirectoryResolver(),
        diagnosticRecorder: recorder,
      );

      final resultFuture = service.ensureCached(
        const ImageCacheRequest(
          cacheKey: 'manager-failure',
          sourceUrl: 'https://bbs.yamibo.com/image.png',
          ownerType: ImageCacheOwnerType.thread,
          ownerId: 'thread-owner',
          role: ImageCacheRole.threadInline,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      managerCompleter.completeError(StateError('manager unavailable'));
      final result = await resultFuture;

      expect(result.success, isFalse);
      expect(
        recorder.events.single.stage,
        ImageCacheDiagnosticStage.managerInitialization,
      );
      expect(
        recorder.events.single.failureKind,
        ImageCacheDiagnosticFailureKind.cacheManager,
      );
    },
  );

  test('typed resource stream diagnostics retain available byte count', () {
    final event = buildImageCacheFailureDiagnostic(
      stage: ImageCacheDiagnosticStage.download,
      cacheKey: 'stream-failure',
      ownerType: ImageCacheOwnerType.comic,
      role: ImageCacheRole.comicPage,
      error: const ForumResourceStreamException(
        failure: ForumResourceFailure(
          kind: ForumResourceFailureKind.network,
          code: 'resource_stream_failed',
        ),
        bytesReceived: 23,
      ),
      elapsed: const Duration(milliseconds: 8),
    );

    expect(event.failureKind, ImageCacheDiagnosticFailureKind.network);
    expect(event.reasonCode, 'resource_stream_failed');
    expect(event.bytesReceived, 23);
  });
}
