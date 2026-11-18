part of 'cached_library_image_test.dart';

void _dimensionsStaleCases() {
  testWidgets('ignores stale cache lookup results after request changes', (
    tester,
  ) async {
    final oldFile = _createTempPng(tester);
    final newFile = _createTempPng(tester);
    final cacheService = _ControlledImageCacheService();

    Widget build(String cacheKey) {
      return ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request(cacheKey),
            fit: BoxFit.cover,
            placeholder: const SizedBox(key: Key('placeholder')),
          ),
        ),
      );
    }

    await tester.pumpWidget(build('old-image'));
    await tester.pump();
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(build('new-image'));
    await tester.pump();

    cacheService.completeGetCached(
      'old-image',
      CachedImageResult(
        success: true,
        cacheKey: 'old-image',
        localPath: oldFile.path,
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(cacheService.ensureStarted('old-image'), isFalse);

    cacheService.completeGetCached(
      'new-image',
      CachedImageResult(
        success: true,
        cacheKey: 'new-image',
        localPath: newFile.path,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    final provider = _underlyingProvider(
      tester.widget<Image>(find.byType(Image)).image,
    );
    expect(provider, isA<FileImage>());
    expect((provider as FileImage).file.path, newFile.path);
  });

  testWidgets('ignores stale intrinsic dimensions after request changes', (
    tester,
  ) async {
    final oldFile = _createTempPng(tester);
    final newFile = _createTempPng(tester);
    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 3, cache: false),
    );
    final testImage = image!;
    addTearDown(testImage.dispose);
    final cacheService = _ControlledImageCacheService();
    final dimensionProbe = _KeyedControlledDimensionProbe();
    final resolvedSizes = <Size>[];

    Widget build(String cacheKey, String localPath) {
      return ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(cacheService),
          encodedImageDimensionProbeProvider.overrideWithValue(dimensionProbe),
        ],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request(cacheKey),
            preferredLocalPath: localPath,
            imageProviderOverride: _SynchronousImageProvider(testImage),
            fit: BoxFit.contain,
            placeholder: const SizedBox(key: Key('placeholder')),
            onImageResolved: resolvedSizes.add,
          ),
        ),
      );
    }

    await tester.pumpWidget(build('old-image', oldFile.path));
    await tester.pump();
    await tester.pump();
    expect(dimensionProbe.startedKeys, contains('old-image'));

    await tester.pumpWidget(build('new-image', newFile.path));
    await tester.pump();
    await tester.pump();
    expect(dimensionProbe.startedKeys, contains('new-image'));

    dimensionProbe.complete('old-image', const Size(100, 200));
    await tester.pump();
    expect(resolvedSizes, isEmpty);

    dimensionProbe.complete('new-image', const Size(300, 400));
    await tester.pump();
    expect(resolvedSizes, <Size>[const Size(300, 400)]);
  });

  for (final source in ['cached', 'downloaded', 'preferred']) {
    testWidgets(
      'checks $source files before decoding or publishing dimensions',
      (tester) async {
        final localFile = _createTempPng(tester);
        final cacheService = _ControlledImageCacheService();
        final dimensionProbe = _ControlledDimensionProbe();
        final inspection = Completer<bool>();
        final inspectedPaths = <String>[];
        final resolvedPaths = <String>[];
        final resolvedSizes = <Size>[];
        var failures = 0;
        final result = CachedImageResult(
          success: true,
          cacheKey: 'thread-image',
          localPath: localFile.path,
          width: 640,
          height: 480,
        );
        if (source != 'preferred') {
          cacheService.completeGetCached(
            'thread-image',
            source == 'cached' ? result : null,
          );
        }

        await tester.pumpWidget(
          _localFallbackHarness(
            cacheService,
            preferredLocalPath: source == 'preferred' ? localFile.path : null,
            predicate: (path) {
              inspectedPaths.add(path);
              return inspection.future;
            },
            dimensionProbe: dimensionProbe,
            onLocalPathResolved: resolvedPaths.add,
            onImageResolved: resolvedSizes.add,
            onImageFailed: () => failures++,
            showDelayedLoadingIndicator: true,
          ),
        );
        await tester.pump();
        if (source == 'downloaded') {
          expect(cacheService.ensureStarted('thread-image'), isTrue);
          cacheService.completeEnsure('thread-image', result);
          await tester.pump();
        }
        expect(inspectedPaths, [localFile.path]);
        expect(find.byType(Image), findsNothing);
        expect(resolvedPaths, isEmpty);
        expect(resolvedSizes, isEmpty);
        await tester.pump(const Duration(milliseconds: 300));
        expect(_loadingIndicator, findsOneWidget);

        inspection.complete(true);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('local-file-fallback')), findsOneWidget);
        expect(find.byType(LibraryCachedImage), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(_loadingIndicator, findsNothing);
        expect(resolvedPaths, isEmpty);
        expect(resolvedSizes, isEmpty);
        expect(dimensionProbe.calls, 0);
        expect(cacheService.recordedDimensions, isEmpty);
        expect(cacheService.decodeFailures, isEmpty);
        expect(failures, 0);
        expect(
          cacheService.getCachedCount('thread-image'),
          source == 'preferred' ? 0 : 1,
        );
        expect(
          cacheService.ensureStarted('thread-image'),
          source == 'downloaded',
        );
      },
    );
  }

  for (final throws in [false, true]) {
    testWidgets(
      'a ${throws ? 'throwing' : 'false'} file predicate keeps normal decoding',
      (tester) async {
        final localFile = _createTempPng(tester);
        final cacheService = _ControlledImageCacheService();
        cacheService.completeGetCached(
          'thread-image',
          CachedImageResult(
            success: true,
            cacheKey: 'thread-image',
            localPath: localFile.path,
          ),
        );

        await tester.pumpWidget(
          _localFallbackHarness(
            cacheService,
            predicate: (_) async {
              if (throws) throw StateError('inspection failed');
              return false;
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('local-file-fallback')), findsNothing);
        final provider = _underlyingProvider(
          tester.widget<Image>(find.byType(Image)).image,
        );
        expect(provider, isA<FileImage>());
        expect((provider as FileImage).file.path, localFile.path);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a non-fallback corrupt file still reports its decode failure', (
    tester,
  ) async {
    final localFile = _createTempPng(tester)
      ..writeAsStringSync('invalid raster image', encoding: utf8, flush: true);
    final cacheService = _ControlledImageCacheService();
    var failures = 0;

    // Resolve the actual FileImage in the real async zone so native file I/O
    // and codec completion do not depend on an arbitrary sequence of pumps.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _localFallbackHarness(
          cacheService,
          preferredLocalPath: localFile.path,
          predicate: (_) async => false,
          onImageFailed: () => failures++,
        ),
      );
      await tester.pump();
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final stream = provider.resolve(ImageConfiguration.empty);
      final decoded = Completer<void>();
      final listener = ImageStreamListener((image, _) {
        image.dispose();
        decoded.completeError(StateError('corrupt bytes unexpectedly decoded'));
      }, onError: (Object _, StackTrace? _) => decoded.complete());
      stream.addListener(listener);
      try {
        await decoded.future.timeout(const Duration(seconds: 5));
      } finally {
        stream.removeListener(listener);
      }
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('local-file-fallback')), findsNothing);
    expect(find.byKey(const Key('error-placeholder')), findsOneWidget);
    expect(cacheService.decodeFailures, hasLength(1));
    expect(cacheService.decodeFailures.single.cacheKey, 'thread-image');
    expect(cacheService.decodeFailurePaths.single, localFile.path);
    expect(failures, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback widget changes preserve the inspected file decision', (
    tester,
  ) async {
    final localFile = _createTempPng(tester);
    final cacheService = _ControlledImageCacheService();
    cacheService.completeGetCached(
      'thread-image',
      CachedImageResult(
        success: true,
        cacheKey: 'thread-image',
        localPath: localFile.path,
      ),
    );
    var inspections = 0;
    Future<bool> predicate(String _) async {
      inspections++;
      return true;
    }

    await tester.pumpWidget(
      _localFallbackHarness(cacheService, predicate: predicate),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local-file-fallback')), findsOneWidget);

    await tester.pumpWidget(
      _localFallbackHarness(
        cacheService,
        predicate: predicate,
        fallback: const SizedBox(key: Key('updated-fallback')),
      ),
    );
    expect(find.byKey(const Key('updated-fallback')), findsOneWidget);

    await tester.pumpWidget(
      _localFallbackHarness(cacheService, predicate: predicate, fallback: null),
    );
    expect(find.byKey(const Key('error-placeholder')), findsOneWidget);

    await tester.pumpWidget(
      _localFallbackHarness(
        cacheService,
        predicate: predicate,
        fallback: null,
        errorPlaceholder: null,
      ),
    );
    expect(find.byKey(const Key('placeholder')), findsOneWidget);
    expect(inspections, 1);
    expect(cacheService.getCachedCount('thread-image'), 1);
    expect(cacheService.decodeFailures, isEmpty);
  });

  testWidgets('changing the predicate restarts and isolates inspection', (
    tester,
  ) async {
    final localFile = _createTempPng(tester);
    final cacheService = _ControlledImageCacheService();
    final previousInspection = Completer<bool>();
    cacheService.completeGetCached(
      'thread-image',
      CachedImageResult(
        success: true,
        cacheKey: 'thread-image',
        localPath: localFile.path,
      ),
    );
    var previousCalls = 0;
    var currentCalls = 0;
    await tester.pumpWidget(
      _localFallbackHarness(
        cacheService,
        predicate: (_) {
          previousCalls++;
          return previousInspection.future;
        },
      ),
    );
    await tester.pump();
    expect(previousCalls, 1);

    await tester.pumpWidget(
      _localFallbackHarness(
        cacheService,
        predicate: (_) async {
          currentCalls++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(currentCalls, 1);
    expect(cacheService.getCachedCount('thread-image'), 2);
    expect(find.byKey(const Key('local-file-fallback')), findsOneWidget);

    previousInspection.complete(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local-file-fallback')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  for (final previousDecision in [false, true]) {
    testWidgets(
      'ignores stale $previousDecision inspection after the request changes',
      (tester) async {
        final oldFile = _createTempPng(tester);
        final newFile = _createTempPng(tester);
        final cacheService = _ControlledImageCacheService();
        final previousInspection = Completer<bool>();
        final inspectedPaths = <String>[];
        Future<bool> predicate(String path) {
          inspectedPaths.add(path);
          return path == oldFile.path
              ? previousInspection.future
              : Future.value(false);
        }

        for (final entry in {
          'old-image': oldFile,
          'new-image': newFile,
        }.entries) {
          cacheService.completeGetCached(
            entry.key,
            CachedImageResult(
              success: true,
              cacheKey: entry.key,
              localPath: entry.value.path,
            ),
          );
        }
        await tester.pumpWidget(
          _localFallbackHarness(
            cacheService,
            cacheKey: 'old-image',
            predicate: predicate,
          ),
        );
        await tester.pump();
        expect(inspectedPaths, [oldFile.path]);
        expect(find.byType(Image), findsNothing);

        await tester.pumpWidget(
          _localFallbackHarness(
            cacheService,
            cacheKey: 'new-image',
            predicate: predicate,
          ),
        );
        await tester.pump();
        previousInspection.complete(previousDecision);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('local-file-fallback')), findsNothing);
        final provider = _underlyingProvider(
          tester.widget<Image>(find.byType(Image)).image,
        ) as FileImage;
        expect(provider.file.path, newFile.path);
        expect(inspectedPaths, [oldFile.path, newFile.path]);
        expect(cacheService.decodeFailures, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ignores a local file inspection that completes after disposal', (
    tester,
  ) async {
    final localFile = _createTempPng(tester);
    final cacheService = _ControlledImageCacheService();
    final inspection = Completer<bool>();
    var inspected = false;
    await tester.pumpWidget(
      _localFallbackHarness(
        cacheService,
        preferredLocalPath: localFile.path,
        predicate: (_) {
          inspected = true;
          return inspection.future;
        },
      ),
    );
    await tester.pump();
    expect(inspected, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    inspection.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(cacheService.decodeFailures, isEmpty);
  });
}
