part of 'cached_library_image_test.dart';

void _cachePipelineCases() {
  testWidgets(
    'eager remote first frame settles before cache-backed dimensions exist',
    (tester) async {
      final image = await tester.runAsync(
        () => createTestImage(width: 4, height: 3, cache: false),
      );
      final testImage = image!;
      addTearDown(testImage.dispose);
      final localFile = _createTempPng(tester);
      final cacheService = _ControlledImageCacheService();
      final dimensionProbe = _ControlledDimensionProbe();
      Size? resolvedSize;
      cacheService.completeGetCached('thread-image', null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(cacheService),
            encodedImageDimensionProbeProvider.overrideWithValue(
              dimensionProbe,
            ),
          ],
          child: LocalizedTestApp(
            home: CachedLibraryImage(
              request: _request('thread-image'),
              fit: BoxFit.cover,
              placeholder: const SizedBox(key: Key('placeholder')),
              showDelayedLoadingIndicator: true,
              remoteImageProviderOverride: _SynchronousImageProvider(testImage),
              onImageResolved: (size) => resolvedSize = size,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Image), findsOneWidget);
      expect(_loadingIndicator, findsNothing);
      expect(dimensionProbe.calls, 0);

      cacheService.completeEnsure(
        'thread-image',
        CachedImageResult(
          success: true,
          cacheKey: 'thread-image',
          localPath: localFile.path,
        ),
      );
      await tester.pump();

      expect(dimensionProbe.calls, 1);
      expect(resolvedSize, isNull);
      dimensionProbe.complete(const Size(900, 600));
      await tester.pump();

      expect(resolvedSize, const Size(900, 600));
      expect(_loadingIndicator, findsNothing);
    },
  );

  testWidgets(
    'local first frame settles before intrinsic dimension probing completes',
    (tester) async {
      final localFile = _createTempPng(tester);
      final image = await tester.runAsync(
        () => createTestImage(width: 4, height: 3, cache: false),
      );
      final testImage = image!;
      addTearDown(testImage.dispose);
      final cacheService = _ControlledImageCacheService();
      final dimensionProbe = _ControlledDimensionProbe();
      Size? resolvedSize;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(cacheService),
            encodedImageDimensionProbeProvider.overrideWithValue(
              dimensionProbe,
            ),
          ],
          child: LocalizedTestApp(
            home: SizedBox(
              width: 240,
              height: 240,
              child: CachedLibraryImage(
                request: _request('thread-image'),
                preferredLocalPath: localFile.path,
                imageProviderOverride: _SynchronousImageProvider(testImage),
                fit: BoxFit.contain,
                placeholder: const SizedBox(key: Key('placeholder')),
                showDelayedLoadingIndicator: true,
                onImageResolved: (size) => resolvedSize = size,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Image), findsOneWidget);
      expect(_loadingIndicator, findsNothing);
      expect(dimensionProbe.calls, 1);
      expect(resolvedSize, isNull);

      dimensionProbe.complete(const Size(1200, 1800));
      await tester.pump();

      expect(resolvedSize, const Size(1200, 1800));
      expect(
        cacheService.recordedDimensions['thread-image'],
        const Size(1200, 1800),
      );
      expect(_loadingIndicator, findsNothing);
    },
  );

  testWidgets('dimension probe failure does not turn display into an error', (
    tester,
  ) async {
    final localFile = _createTempPng(tester);
    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 3, cache: false),
    );
    final testImage = image!;
    addTearDown(testImage.dispose);
    final cacheService = _ControlledImageCacheService();
    var imageFailed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(cacheService),
          encodedImageDimensionProbeProvider.overrideWithValue(
            const _FailingDimensionProbe(),
          ),
        ],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request('thread-image'),
            preferredLocalPath: localFile.path,
            imageProviderOverride: _SynchronousImageProvider(testImage),
            fit: BoxFit.contain,
            placeholder: const SizedBox(key: Key('placeholder')),
            errorPlaceholder: const SizedBox(key: Key('error-placeholder')),
            showDelayedLoadingIndicator: true,
            onImageResolved: (_) {},
            onImageFailed: () => imageFailed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('error-placeholder')), findsNothing);
    expect(_loadingIndicator, findsNothing);
    expect(imageFailed, isFalse);
  });

  testWidgets('uses cached local result before starting a new cache request', (
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request('thread-image'),
            fit: BoxFit.cover,
            placeholder: const SizedBox(key: Key('placeholder')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(cacheService.getCachedCount('thread-image'), 1);
    expect(cacheService.ensureStarted('thread-image'), isFalse);
    expect(find.byType(Image), findsOneWidget);
    expect(
      _underlyingProvider(tester.widget<Image>(find.byType(Image)).image),
      isA<FileImage>(),
    );
  });

  testWidgets('uses trusted cached dimensions without probing the file', (
    tester,
  ) async {
    final localFile = _createTempPng(tester);
    final cacheService = _ControlledImageCacheService();
    final dimensionProbe = _ControlledDimensionProbe();
    Size? resolvedSize;
    cacheService.completeGetCached(
      'thread-image',
      CachedImageResult(
        success: true,
        cacheKey: 'thread-image',
        localPath: localFile.path,
        width: 1200,
        height: 800,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(cacheService),
          encodedImageDimensionProbeProvider.overrideWithValue(dimensionProbe),
        ],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request('thread-image'),
            fit: BoxFit.contain,
            placeholder: const SizedBox.shrink(),
            onImageResolved: (size) => resolvedSize = size,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(resolvedSize, const Size(1200, 800));
    expect(dimensionProbe.calls, 0);
  });

  testWidgets(
    'reports a local cache decode failure without exposing its path',
    (tester) async {
      final cacheService = _ControlledImageCacheService();
      final provider = _ControlledImageProvider();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(cacheService),
          ],
          child: LocalizedTestApp(
            home: CachedLibraryImage(
              request: _request('thread-image'),
              fit: BoxFit.cover,
              placeholder: const SizedBox(key: Key('placeholder')),
              errorPlaceholder: const SizedBox(key: Key('error-placeholder')),
              imageProviderOverride: provider,
            ),
          ),
        ),
      );
      await tester.pump();
      provider.fail();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-placeholder')), findsOneWidget);
      expect(cacheService.decodeFailures, hasLength(1));
      expect(cacheService.decodeFailures.single.cacheKey, 'thread-image');
    },
  );

  testWidgets('allows remote fallback only after direct cache lookup misses', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 3, cache: false),
    );
    final testImage = image!;
    addTearDown(testImage.dispose);
    final cacheService = _ControlledImageCacheService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request('thread-image'),
            fit: BoxFit.cover,
            placeholder: const SizedBox(key: Key('placeholder')),
            remoteImageProviderOverride: _SynchronousImageProvider(testImage),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(cacheService.ensureStarted('thread-image'), isFalse);

    cacheService.completeGetCached('thread-image', null);
    await tester.pump();
    await tester.pump();

    expect(cacheService.ensureStarted('thread-image'), isTrue);
    expect(find.byType(Image), findsOneWidget);
    expect(
      _underlyingProvider(tester.widget<Image>(find.byType(Image)).image),
      isA<_SynchronousImageProvider>(),
    );
  });

  testWidgets(
    'afterCacheWrite waits for one cache write before showing local image',
    (tester) async {
      final localFile = _createTempPng(tester);
      final image = await tester.runAsync(
        () => createTestImage(width: 4, height: 3, cache: false),
      );
      final testImage = image!;
      addTearDown(testImage.dispose);
      final cacheService = _ControlledImageCacheService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(cacheService),
          ],
          child: LocalizedTestApp(
            home: CachedLibraryImage(
              request: _request('thread-image'),
              fit: BoxFit.cover,
              placeholder: const SizedBox(key: Key('placeholder')),
              remoteImageProviderOverride: _SynchronousImageProvider(testImage),
              remoteDisplayPolicy:
                  CachedImageRemoteDisplayPolicy.afterCacheWrite,
            ),
          ),
        ),
      );
      await tester.pump();
      cacheService.completeGetCached('thread-image', null);
      await tester.pump();
      await tester.pump();

      expect(cacheService.ensureStarted('thread-image'), isTrue);
      expect(find.byType(Image), findsNothing);

      cacheService.completeEnsure(
        'thread-image',
        CachedImageResult(
          success: true,
          cacheKey: 'thread-image',
          localPath: localFile.path,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(cacheService.getCachedCount('thread-image'), 1);
      expect(find.byType(Image), findsOneWidget);
      expect(
        _underlyingProvider(tester.widget<Image>(find.byType(Image)).image),
        isA<FileImage>(),
      );
    },
  );

  testWidgets('afterCacheWrite failure settles on the error placeholder', (
    tester,
  ) async {
    final cacheService = _ControlledImageCacheService();
    var failedCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request('thread-image'),
            fit: BoxFit.cover,
            placeholder: const SizedBox(key: Key('placeholder')),
            errorPlaceholder: const SizedBox(key: Key('error-placeholder')),
            remoteDisplayPolicy: CachedImageRemoteDisplayPolicy.afterCacheWrite,
            onImageFailed: () => failedCount += 1,
          ),
        ),
      ),
    );
    await tester.pump();
    cacheService.completeGetCached('thread-image', null);
    await tester.pump();
    await tester.pump();
    cacheService.completeEnsure('thread-image', CachedImageResult.failed);
    await tester.pump();
    await tester.pump();

    expect(failedCount, 1);
    expect(find.byKey(const Key('error-placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'keeps displayed remote image instead of switching to local file mid-frame',
    (tester) async {
      final image = await tester.runAsync(
        () => createTestImage(width: 4, height: 3, cache: false),
      );
      final testImage = image!;
      addTearDown(testImage.dispose);
      final cacheService = _ControlledImageCacheService();
      cacheService.completeGetCached('thread-image', null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(cacheService),
          ],
          child: LocalizedTestApp(
            home: CachedLibraryImage(
              request: _request('thread-image'),
              fit: BoxFit.cover,
              placeholder: const SizedBox(key: Key('placeholder')),
              remoteImageProviderOverride: _SynchronousImageProvider(testImage),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(cacheService.ensureStarted('thread-image'), isTrue);
      expect(find.byType(Image), findsOneWidget);
      expect(
        _underlyingProvider(tester.widget<Image>(find.byType(Image)).image),
        isA<_SynchronousImageProvider>(),
      );

      cacheService.completeEnsure(
        'thread-image',
        const CachedImageResult(
          success: true,
          cacheKey: 'thread-image',
          localPath: 'C:/cache/thread-image.jpg',
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(
        _underlyingProvider(tester.widget<Image>(find.byType(Image)).image),
        isA<_SynchronousImageProvider>(),
      );
      expect(
        tester.widget<CachedLibraryImage>(find.byType(CachedLibraryImage)),
        isNotNull,
      );
    },
  );
}
