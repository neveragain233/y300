part of 'cached_library_image_test.dart';

void _retryLoadingCases() {
  testWidgets('only a changed retry token lifts the current request cooldown', (
    tester,
  ) async {
    final cacheService = _RetryableImageCacheService();
    cacheService.completeGetCached('thread-image', null);
    cacheService.completeGetCached('new-image', null);

    Widget build(int retryToken, {String cacheKey = 'thread-image'}) {
      return ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request(cacheKey),
            fit: BoxFit.contain,
            placeholder: const SizedBox(key: Key('placeholder')),
            errorPlaceholder: const SizedBox(key: Key('error-placeholder')),
            remoteDisplayPolicy: CachedImageRemoteDisplayPolicy.afterCacheWrite,
            retryToken: retryToken,
          ),
        ),
      );
    }

    await tester.pumpWidget(build(4));
    await tester.pump();
    await tester.pump();
    expect(cacheService.retryRequests, isEmpty);
    expect(cacheService.ensureRequests, hasLength(1));
    expect(find.byKey(const Key('error-placeholder')), findsOneWidget);

    await tester.pumpWidget(build(4));
    await tester.pump();
    expect(cacheService.retryRequests, isEmpty);
    expect(cacheService.ensureRequests, hasLength(1));

    await tester.pumpWidget(build(5));
    await tester.pump();
    await tester.pump();
    expect(cacheService.retryRequests.map((request) => request.cacheKey), [
      'thread-image',
    ]);
    expect(cacheService.operations, [
      'ensure:thread-image',
      'retry:thread-image',
      'ensure:thread-image',
    ]);

    await tester.pumpWidget(build(6, cacheKey: 'new-image'));
    await tester.pump();
    await tester.pump();
    expect(cacheService.retryRequests.map((request) => request.cacheKey), [
      'thread-image',
      'new-image',
    ]);
    expect(
      cacheService.retryRequests.last.sourceUrl,
      _request('new-image').sourceUrl,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(build(6, cacheKey: 'new-image'));
    await tester.pump();
    await tester.pump();
    expect(cacheService.retryRequests, hasLength(2));
    expect(cacheService.ensureRequests, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry token changes keep legacy cache services working', (
    tester,
  ) async {
    final cacheService = _ControlledImageCacheService();
    cacheService.completeGetCached('thread-image', null);
    cacheService.completeEnsure('thread-image', CachedImageResult.failed);

    Widget build(int retryToken) {
      return ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: LocalizedTestApp(
          home: CachedLibraryImage(
            request: _request('thread-image'),
            fit: BoxFit.contain,
            placeholder: const SizedBox(),
            errorPlaceholder: const SizedBox(key: Key('error-placeholder')),
            remoteDisplayPolicy: CachedImageRemoteDisplayPolicy.afterCacheWrite,
            retryToken: retryToken,
          ),
        ),
      );
    }

    await tester.pumpWidget(build(0));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(build(1));
    await tester.pump();
    await tester.pump();

    expect(cacheService.getCachedCount('thread-image'), 2);
    expect(find.byKey(const Key('error-placeholder')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows placeholder and does not build remote image while cache lookup is pending',
    (tester) async {
      final cacheService = _ControlledImageCacheService();
      final image = await tester.runAsync(
        () => createTestImage(width: 4, height: 3, cache: false),
      );
      final testImage = image!;
      addTearDown(testImage.dispose);

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

      expect(cacheService.getCachedCount('thread-image'), 1);
      expect(cacheService.ensureStarted('thread-image'), isFalse);
      expect(find.byKey(const Key('placeholder')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('shows a loading indicator only after the configured delay', (
    tester,
  ) async {
    final cacheService = _ControlledImageCacheService();

    await tester.pumpWidget(
      _loadingHarness(
        cacheService,
        remoteImageProvider: const _PendingImageProvider(),
      ),
    );
    await tester.pump();

    expect(_loadingIndicator, findsNothing);
    await tester.pump(const Duration(milliseconds: 299));
    expect(_loadingIndicator, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(_loadingIndicator, findsOneWidget);
  });

  testWidgets('keeps one loading deadline across cache and remote stages', (
    tester,
  ) async {
    final cacheService = _ControlledImageCacheService();

    await tester.pumpWidget(
      _loadingHarness(
        cacheService,
        remoteImageProvider: const _PendingImageProvider(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    cacheService.completeGetCached('thread-image', null);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(cacheService.ensureStarted('thread-image'), isTrue);
    expect(_loadingIndicator, findsNothing);

    await tester.pump(const Duration(milliseconds: 50));
    expect(_loadingIndicator, findsOneWidget);
  });

  testWidgets('fast image completion never flashes the delayed indicator', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 3, cache: false),
    );
    final testImage = image!;
    addTearDown(testImage.dispose);
    final cacheService = _ControlledImageCacheService();
    cacheService.completeGetCached('thread-image', null);

    await tester.pumpWidget(
      _loadingHarness(
        cacheService,
        remoteImageProvider: _SynchronousImageProvider(testImage),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Image), findsOneWidget);
    expect(_loadingIndicator, findsNothing);
  });

  testWidgets('image failure settles and removes the loading indicator', (
    tester,
  ) async {
    final cacheService = _ControlledImageCacheService();
    final provider = _ControlledImageProvider();

    await tester.pumpWidget(
      _loadingHarness(cacheService, imageProvider: provider),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_loadingIndicator, findsOneWidget);

    provider.fail();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('error-placeholder')), findsOneWidget);
    expect(_loadingIndicator, findsNothing);
  });

  testWidgets('changing requests resets and isolates the loading deadline', (
    tester,
  ) async {
    final cacheService = _ControlledImageCacheService();

    await tester.pumpWidget(
      _loadingHarness(
        cacheService,
        cacheKey: 'old-image',
        remoteImageProvider: const _PendingImageProvider(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.pumpWidget(
      _loadingHarness(
        cacheService,
        cacheKey: 'new-image',
        remoteImageProvider: const _PendingImageProvider(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(_loadingIndicator, findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(_loadingIndicator, findsOneWidget);
  });

  testWidgets('the delayed indicator remains opt-in', (tester) async {
    final cacheService = _ControlledImageCacheService();

    await tester.pumpWidget(
      _loadingHarness(
        cacheService,
        showDelayedLoadingIndicator: false,
        remoteImageProvider: const _PendingImageProvider(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 301));

    expect(_loadingIndicator, findsNothing);
  });
}
