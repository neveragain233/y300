part of 'default_image_cache_service_test.dart';

void _undecodableCacheFileCases() {
  group('undecodable cache file', () {
    test(
      'explicit retry retires the failed file and downloads a new version',
      () async {
        final directory = await io.Directory.systemTemp.createTemp(
          'y300-undecodable-',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final corrupt = io.File('${directory.path}/bad.jpg');
        await corrupt.writeAsBytes(<int>[1, 2, 3]);
        final replacement = io.File('${directory.path}/replacement.png');
        final request = _missingImageRequest(cacheKey: 'comic/page-1');
        final repository = _MemoryImageCacheRepository()
          ..records[request.cacheKey] = _cachedMissingImageRecord(
            request,
            corrupt.path,
          );
        final downloader = _ControlledFailureDownloader(
          onDownload: (_) async {
            await replacement.writeAsBytes(_onePixelPngBytes);
            return replacement.path;
          },
        );
        final service = _missingImageService(
          downloader: downloader,
          repository: repository,
        );

        final initial = await service.ensureCached(request);
        expect(initial.success, isTrue);
        expect(initial.fromCache, isTrue);
        expect(initial.localPath, corrupt.path);

        service.reportDecodeFailure(
          request: request,
          error: Exception('Invalid image data'),
          localPath: corrupt.path,
        );
        service.allowRetry(request);

        // The retired version is hidden from cache hits even before the
        // background cleanup reaches the index and cache-manager entries.
        expect(await service.getCached(request.cacheKey), isNull);

        final retry = await service.ensureCached(request);
        expect(retry.success, isTrue);
        expect(retry.fromCache, isFalse);
        expect(retry.localPath, replacement.path);
        expect(downloader.downloadCount, 1);
        expect(downloader.lastForce, isTrue);
        expect(
          repository.records[request.cacheKey]?.localPath,
          replacement.path,
        );
        expect(await corrupt.exists(), isFalse);
      },
    );

    for (final failure in <Object>[
      const OutOfMemoryError(),
      const io.FileSystemException('read denied'),
      TimeoutException('decode timed out'),
    ]) {
      test('${failure.runtimeType} keeps the cached file available', () async {
        final file = await _temporaryFailureCacheImage();
        final request = _missingImageRequest(cacheKey: 'comic/page-2');
        final repository = _MemoryImageCacheRepository()
          ..records[request.cacheKey] = _cachedMissingImageRecord(
            request,
            file.path,
          );
        final downloader = _ControlledFailureDownloader(
          onDownload: (_) async => file.path,
        );
        final service = _missingImageService(
          downloader: downloader,
          repository: repository,
        );

        service.reportDecodeFailure(
          request: request,
          error: failure,
          localPath: file.path,
        );
        service.allowRetry(request);

        final retry = await service.ensureCached(request);
        expect(retry.success, isTrue);
        expect(retry.fromCache, isTrue);
        expect(retry.localPath, file.path);
        expect(await service.getCached(request.cacheKey), isNotNull);
        expect(downloader.downloadCount, 0);
        expect(await file.exists(), isTrue);
        expect(repository.records.containsKey(request.cacheKey), isTrue);
      });
    }

    for (final retention in <ImageRetentionClass>[
      ImageRetentionClass.downloaded,
      ImageRetentionClass.protected,
    ]) {
      test(
        '${retention.name} files are not retired by decode failures',
        () async {
          final file = await _temporaryFailureCacheImage();
          final request = _missingImageRequest(cacheKey: 'comic/page-3');
          final record = _cachedMissingImageRecord(request, file.path).copyWith(
            retentionClass: retention,
            protected: retention == ImageRetentionClass.protected,
          );
          final repository = _MemoryImageCacheRepository()
            ..records[request.cacheKey] = record;
          final downloader = _ControlledFailureDownloader(
            onDownload: (_) async => file.path,
          );
          final service = _missingImageService(
            downloader: downloader,
            repository: repository,
          );

          service.reportDecodeFailure(
            request: request,
            error: Exception('Invalid image data'),
            localPath: file.path,
          );
          service.allowRetry(request);

          final retry = await service.ensureCached(request);
          expect(retry.success, isTrue);
          expect(retry.fromCache, isTrue);
          expect(downloader.downloadCount, 0);
          expect(await file.exists(), isTrue);
          expect(await service.getCached(request.cacheKey), isNotNull);
        },
      );
    }

    test('a failure for another file version keeps the current file', () async {
      final file = await _temporaryFailureCacheImage();
      final request = _missingImageRequest(cacheKey: 'comic/page-4');
      final repository = _MemoryImageCacheRepository()
        ..records[request.cacheKey] = _cachedMissingImageRecord(
          request,
          file.path,
        );
      final downloader = _ControlledFailureDownloader(
        onDownload: (_) async => file.path,
      );
      final service = _missingImageService(
        downloader: downloader,
        repository: repository,
      );

      service.reportDecodeFailure(
        request: request,
        error: Exception('Invalid image data'),
        localPath: '/cache/previous-version.jpg',
      );
      service.allowRetry(request);

      final retry = await service.ensureCached(request);
      expect(retry.success, isTrue);
      expect(retry.fromCache, isTrue);
      expect(downloader.downloadCount, 0);
      expect(await file.exists(), isTrue);
      expect(await service.getCached(request.cacheKey), isNotNull);
    });
  });
}
