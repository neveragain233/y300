part of 'default_image_cache_service_test.dart';

void _missingImageCooldownCases() {
  group('confirmed missing image cooldown', () {
    test(
      '45 sequential consumers produce one download and diagnostic',
      () async {
        final downloader = _ControlledFailureDownloader();
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final repository = _MemoryImageCacheRepository();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
          repository: repository,
        );

        for (var consumer = 0; consumer < 45; consumer++) {
          final result = await service.ensureCached(_missingImageRequest());
          expect(result.success, isFalse);
        }

        expect(downloader.downloadCount, 1);
        expect(recorder.events, hasLength(1));
        expect(
          recorder.events.single.stage,
          ImageCacheDiagnosticStage.download,
        );
        expect(
          recorder.events.single.failureKind,
          ImageCacheDiagnosticFailureKind.notFound,
        );
        expect(repository.records, isEmpty);
      },
    );

    test(
      'cooldown expires from actual failure and hits do not renew it',
      () async {
        var now = DateTime.utc(2026, 10, 14);
        final downloader = _ControlledFailureDownloader();
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
          failureBackoff: ImageCacheFailureBackoff(now: () => now),
        );

        await service.ensureCached(_missingImageRequest());
        now = now.add(const Duration(seconds: 29));
        await service.ensureCached(_missingImageRequest());
        expect(downloader.downloadCount, 1);
        now = now.add(const Duration(seconds: 1));
        await service.ensureCached(_missingImageRequest());
        expect(downloader.downloadCount, 2);
        expect(recorder.events, hasLength(2));
      },
    );

    test(
      'a slow download starts cooldown when its failure completes',
      () async {
        var now = DateTime.utc(2026, 10, 14);
        final completion = Completer<String>();
        final downloader = _ControlledFailureDownloader(
          onDownload: (call) => call == 1
              ? completion.future
              : Future<String>.error(_confirmedNotFound),
        );
        final service = _missingImageService(
          downloader: downloader,
          failureBackoff: ImageCacheFailureBackoff(now: () => now),
        );
        final request = _missingImageRequest();
        final first = service.ensureCached(request);
        await Future<void>.delayed(Duration.zero);
        now = now.add(const Duration(minutes: 1));
        completion.completeError(_confirmedNotFound);
        await first;

        now = now.add(const Duration(seconds: 29));
        await service.ensureCached(request);
        expect(downloader.downloadCount, 1);
        now = now.add(const Duration(seconds: 1));
        await service.ensureCached(request);
        expect(downloader.downloadCount, 2);
      },
    );

    test(
      'an expired missing resource can recover into the positive cache',
      () async {
        var now = DateTime.utc(2026, 10, 14);
        final imageFile = await _temporaryFailureCacheImage();
        final repository = _MemoryImageCacheRepository();
        final downloader = _ControlledFailureDownloader(
          onDownload: (call) => call == 1
              ? Future<String>.error(_confirmedNotFound)
              : Future<String>.value(imageFile.path),
        );
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          repository: repository,
          recorder: recorder,
          failureBackoff: ImageCacheFailureBackoff(now: () => now),
        );
        final request = _missingImageRequest();
        expect((await service.ensureCached(request)).success, isFalse);
        now = now.add(const Duration(seconds: 30));
        final recovered = await service.ensureCached(request);
        expect(recovered.success, isTrue);
        expect(recovered.fromCache, isFalse);
        expect(recovered.localPath, imageFile.path);
        expect(repository.records[request.cacheKey]?.localPath, imageFile.path);
        expect((await service.ensureCached(request)).fromCache, isTrue);
        expect(downloader.downloadCount, 2);
        expect(recorder.events, hasLength(1));
      },
    );

    test(
      'valid indexed file takes priority and clears remembered failure',
      () async {
        final imageFile = await _temporaryFailureCacheImage();
        final repository = _MemoryImageCacheRepository();
        final downloader = _ControlledFailureDownloader();
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
          repository: repository,
        );
        final request = _missingImageRequest();
        await service.ensureCached(request);
        repository.records[request.cacheKey] = _cachedMissingImageRecord(
          request,
          imageFile.path,
        );

        final cached = await service.ensureCached(request);
        expect(cached.success, isTrue);
        expect(cached.fromCache, isTrue);
        expect(cached.localPath, imageFile.path);
        expect(downloader.downloadCount, 1);
        expect(recorder.events, hasLength(1));

        await imageFile.delete();
        await service.ensureCached(request);
        expect(downloader.downloadCount, 2);
      },
    );

    test(
      'valid cache manager file takes priority over remembered failure',
      () async {
        final imageFile = await _temporaryFailureCacheImage();
        final manager = _MutableFileCacheManager();
        final downloader = _ControlledFailureDownloader();
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
          manager: manager,
        );
        final request = _missingImageRequest();
        await service.ensureCached(request);
        manager.cached = FileInfo(
          const LocalFileSystem().file(imageFile.path),
          FileSource.Cache,
          DateTime.utc(2026, 10, 15),
          request.sourceUrl,
        );

        final result = await service.ensureCached(request);
        expect(result.success, isTrue);
        expect(result.fromCache, isTrue);
        expect(result.localPath, imageFile.path);
        expect(downloader.downloadCount, 1);
        expect(recorder.events, hasLength(1));
      },
    );

    test(
      'source or referer changes can download while the original is cooling',
      () async {
        final downloader = _ControlledFailureDownloader();
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
        );
        final original = _missingImageRequest();

        await service.ensureCached(original);
        await service.ensureCached(
          _missingImageRequest(
            sourceUrl: 'https://bbs.yamibo.com/data/attachment/replaced.jpg',
          ),
        );
        await service.ensureCached(
          _missingImageRequest(
            referer: 'https://bbs.yamibo.com/thread-2-1-1.html',
          ),
        );
        await service.ensureCached(original);

        expect(downloader.downloadCount, 3);
        expect(recorder.events, hasLength(3));
      },
    );

    test(
      'trimmed key referer and resolved relative URL share cooldown',
      () async {
        final downloader = _ControlledFailureDownloader();
        final service = _missingImageService(downloader: downloader);

        await service.ensureCached(_missingImageRequest());
        await service.ensureCached(
          _missingImageRequest(
            cacheKey: ' missing/image ',
            sourceUrl: 'data/attachment/missing.jpg',
            referer: ' https://bbs.yamibo.com/thread-1-1-1.html ',
          ),
        );

        expect(downloader.downloadCount, 1);
      },
    );

    test(
      'concurrent consumers share the same failing download and diagnostic',
      () async {
        final completion = Completer<String>();
        final downloader = _ControlledFailureDownloader(
          onDownload: (_) => completion.future,
        );
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
        );
        final requests = List.generate(
          45,
          (_) => service.ensureCached(_missingImageRequest()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(downloader.downloadCount, 1);
        completion.completeError(_confirmedNotFound);

        final results = await Future.wait(requests);
        expect(results.map((result) => result.success), everyElement(isFalse));
        await service.ensureCached(_missingImageRequest());
        expect(downloader.downloadCount, 1);
        expect(recorder.events, hasLength(1));
      },
    );

    test(
      'shared different referer request only remembers initiating headers',
      () async {
        final completion = Completer<String>();
        final downloader = _ControlledFailureDownloader(
          onDownload: (call) => call == 1
              ? completion.future
              : Future<String>.error(_confirmedNotFound),
        );
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
        );
        final initiatingRequest = _missingImageRequest();
        final otherRefererRequest = _missingImageRequest(
          referer: 'https://bbs.yamibo.com/thread-2-1-1.html',
        );
        final first = service.ensureCached(initiatingRequest);
        await Future<void>.delayed(Duration.zero);
        final shared = service.ensureCached(otherRefererRequest);

        expect(identical(first, shared), isTrue);
        expect(downloader.downloadCount, 1);
        completion.completeError(_confirmedNotFound);
        expect((await first).success, isFalse);
        expect((await shared).success, isFalse);
        expect(recorder.events, hasLength(1));

        expect(
          (await service.ensureCached(otherRefererRequest)).success,
          isFalse,
        );
        expect(downloader.downloadCount, 2);
        expect(
          (await service.ensureCached(initiatingRequest)).success,
          isFalse,
        );
        expect(downloader.downloadCount, 2);
        expect(recorder.events, hasLength(2));
      },
    );

    test('explicit retry only clears the requested missing resource', () async {
      final downloader = _ControlledFailureDownloader();
      final service = _missingImageService(downloader: downloader);
      final first = _missingImageRequest();
      final second = _missingImageRequest(cacheKey: 'other/image');
      await service.ensureCached(first);
      await service.ensureCached(second);

      final ImageCacheFailureControl retryControl = service;
      retryControl.allowRetry(first);
      await service.ensureCached(first);
      await service.ensureCached(second);
      await service.ensureCached(first);

      expect(downloader.downloadCount, 3);
    });

    test(
      'retry during a download shares it and rejects its late cooldown',
      () async {
        final completion = Completer<String>();
        final downloader = _ControlledFailureDownloader(
          onDownload: (call) => call == 1
              ? completion.future
              : Future<String>.error(_confirmedNotFound),
        );
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
        );
        final request = _missingImageRequest();
        final first = service.ensureCached(request);
        await Future<void>.delayed(Duration.zero);
        service.allowRetry(request);
        final retry = service.ensureCached(request);

        expect(identical(first, retry), isTrue);
        expect(downloader.downloadCount, 1);
        completion.completeError(_confirmedNotFound);
        await Future.wait(<Future<CachedImageResult>>[first, retry]);
        await service.ensureCached(request);
        await service.ensureCached(request);

        expect(downloader.downloadCount, 2);
        expect(recorder.events, hasLength(2));
      },
    );

    test(
      'new session clears remembered missing resources including A B A',
      () async {
        var sessionScope = Object();
        final downloader = _ControlledFailureDownloader();
        final service = _missingImageService(
          downloader: downloader,
          failureScopeFor: () => sessionScope,
        );
        final request = _missingImageRequest();
        await service.ensureCached(request);
        await service.ensureCached(request);
        expect(downloader.downloadCount, 1);

        sessionScope = Object();
        await service.ensureCached(request);
        await service.ensureCached(request);
        expect(downloader.downloadCount, 2);

        // Re-entering the same account still creates a new session token.
        sessionScope = Object();
        await service.ensureCached(request);
        await service.ensureCached(request);
        expect(downloader.downloadCount, 3);
      },
    );

    test(
      'session change rejects old failure even before another ensure call',
      () async {
        var sessionScope = Object();
        final completion = Completer<String>();
        final downloader = _ControlledFailureDownloader(
          onDownload: (call) => call == 1
              ? completion.future
              : Future<String>.error(_confirmedNotFound),
        );
        final service = _missingImageService(
          downloader: downloader,
          failureScopeFor: () => sessionScope,
        );
        final request = _missingImageRequest();
        final oldSession = service.ensureCached(request);
        await Future<void>.delayed(Duration.zero);
        sessionScope = Object();
        completion.completeError(_confirmedNotFound);
        expect((await oldSession).success, isFalse);

        await service.ensureCached(request);
        await service.ensureCached(request);
        expect(downloader.downloadCount, 2);
      },
    );

    test(
      'session A B A while an old task is active cannot restore cooldown',
      () async {
        var sessionScope = Object();
        final completion = Completer<String>();
        final downloader = _ControlledFailureDownloader(
          onDownload: (call) => call == 1
              ? completion.future
              : Future<String>.error(_confirmedNotFound),
        );
        final service = _missingImageService(
          downloader: downloader,
          failureScopeFor: () => sessionScope,
        );
        final request = _missingImageRequest();
        final firstSession = service.ensureCached(request);
        await Future<void>.delayed(Duration.zero);
        sessionScope = Object();
        final secondSession = service.ensureCached(request);
        sessionScope = Object();
        final newFirstSession = service.ensureCached(request);
        expect(downloader.downloadCount, 1);
        completion.completeError(_confirmedNotFound);
        await Future.wait(<Future<CachedImageResult>>[
          firstSession,
          secondSession,
          newFirstSession,
        ]);

        await service.ensureCached(request);
        await service.ensureCached(request);
        expect(downloader.downloadCount, 2);
      },
    );

    test('cooldown storage is bounded and preserves recent hits', () async {
      final downloader = _ControlledFailureDownloader();
      final service = _missingImageService(
        downloader: downloader,
        failureBackoff: ImageCacheFailureBackoff(maxEntries: 2),
      );
      final first = _missingImageRequest(cacheKey: 'missing/1');
      final second = _missingImageRequest(cacheKey: 'missing/2');
      final third = _missingImageRequest(cacheKey: 'missing/3');
      await service.ensureCached(first);
      await service.ensureCached(second);
      await service.ensureCached(first);
      await service.ensureCached(third);
      await service.ensureCached(first);
      expect(downloader.downloadCount, 3);
      await service.ensureCached(second);
      expect(downloader.downloadCount, 4);
    });

    test('backward clock changes never extend a remembered failure', () async {
      var now = DateTime.utc(2026, 10, 14);
      final downloader = _ControlledFailureDownloader();
      final service = _missingImageService(
        downloader: downloader,
        failureBackoff: ImageCacheFailureBackoff(now: () => now),
      );
      await service.ensureCached(_missingImageRequest());
      now = now.subtract(const Duration(seconds: 1));
      await service.ensureCached(_missingImageRequest());
      expect(downloader.downloadCount, 2);
    });

    final uncachedFailures = <(String, Object)>[
      (
        'unauthorized 401',
        _resourceFailure(ForumResourceFailureKind.unauthorized, 401),
      ),
      (
        'unauthorized 403',
        _resourceFailure(ForumResourceFailureKind.unauthorized, 403),
      ),
      (
        'WAF challenge',
        _resourceFailure(ForumResourceFailureKind.securityChallenge, 405),
      ),
      ('timeout', _resourceFailure(ForumResourceFailureKind.timeout)),
      ('network', _resourceFailure(ForumResourceFailureKind.network)),
      (
        'not-found without HTTP status',
        _resourceFailure(ForumResourceFailureKind.notFound),
      ),
      (
        'not-found 410',
        _resourceFailure(ForumResourceFailureKind.notFound, 410),
      ),
      ('server 404', _resourceFailure(ForumResourceFailureKind.server, 404)),
      (
        'partial resource stream',
        const ForumResourceStreamException(
          failure: ForumResourceFailure(
            kind: ForumResourceFailureKind.notFound,
            code: 'resource_stream_failed',
            statusCode: 404,
          ),
          bytesReceived: 7,
        ),
      ),
      ('untyped error', StateError('resource_not_found')),
    ];
    for (final (label, error) in uncachedFailures) {
      test('$label does not suppress later download attempts', () async {
        final downloader = _ControlledFailureDownloader(failure: error);
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
        );
        await service.ensureCached(_missingImageRequest());
        await service.ensureCached(_missingImageRequest());
        expect(downloader.downloadCount, 2);
        expect(recorder.events, hasLength(2));
      });
    }

    test(
      'a typed 404 during cache lookup is not remembered as remote absence',
      () async {
        final manager = _MutableFileCacheManager()
          ..lookupFailure = _confirmedNotFound;
        final recorder = _RecordingImageCacheDiagnosticRecorder();
        final downloader = _ControlledFailureDownloader();
        final service = _missingImageService(
          downloader: downloader,
          recorder: recorder,
          manager: manager,
        );
        await service.ensureCached(_missingImageRequest());
        manager.lookupFailure = null;
        await service.ensureCached(_missingImageRequest());

        expect(downloader.downloadCount, 1);
        expect(recorder.events, hasLength(2));
        expect(
          recorder.events.first.stage,
          ImageCacheDiagnosticStage.cacheLookup,
        );
        expect(recorder.events.last.stage, ImageCacheDiagnosticStage.download);
      },
    );
  });
}
