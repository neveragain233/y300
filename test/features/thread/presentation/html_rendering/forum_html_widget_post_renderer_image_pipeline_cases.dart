part of 'forum_html_widget_post_renderer_test.dart';

void _imagePipelineCases() {
  testWidgets('maps tapped images to forum image requests', (tester) async {
    ForumHtmlImageRequest? tappedImage;
    var interactions = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'image',
            html:
                '<img id="aimg_286401" '
                'src="data/attachment/forum/month_1110/pic.jpg" '
                'alt="预览图" title="图片标题" width="640" height="480">',
            callbacks: ForumHtmlRenderCallbacks(
              onInteraction: () => interactions += 1,
              onTapImage: (request) => tappedImage = request,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('thread-post-html-first-readable-image-image-0')),
    );
    await tester.pump();

    expect(
      tappedImage?.url,
      endsWith('/data/attachment/forum/month_1110/pic.jpg'),
    );
    expect(tappedImage?.alt, '预览图');
    expect(tappedImage?.title, '图片标题');
    expect(tappedImage?.width, 640);
    expect(tappedImage?.height, 480);
    expect(tappedImage?.isSticker, isFalse);
    expect(tappedImage?.attachmentId, '286401');
    expect(interactions, 1);
  });

  testWidgets('cached thread image taps include readable sequence metadata', (
    tester,
  ) async {
    ForumHtmlImageRequest? tappedImage;
    var interactions = 0;
    final prepared = const DefaultForumHtmlRenderPreparer().prepare(
      html:
          '<img id="aimg_286401" '
          'src="data/attachment/forum/month_1110/pic.jpg" '
          'alt="预览图" title="图片标题" width="640" height="480">',
      preferences: ForumHtmlReaderPreferences.defaults(),
      theme: forumHtmlTestTheme,
      sourceId: 'p1',
      threadId: '573279',
      imageCacheOwnerId: '573279',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'p1',
              threadId: '573279',
              preparedDocument: prepared,
              html: prepared.preparedHtml,
              callbacks: ForumHtmlRenderCallbacks(
                onInteraction: () => interactions += 1,
                onTapImage: (request) => tappedImage = request,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('thread-post-html-first-readable-image-p1-0')),
    );

    expect(tappedImage?.readableIndex, 0);
    expect(tappedImage?.attachmentId, '286401');
    expect(interactions, 1);
    expect(
      tappedImage?.cacheKey,
      ForumImageCacheRequests.threadInline(
        tid: '573279',
        url: 'https://bbs.yamibo.com/data/attachment/forum/month_1110/pic.jpg',
        imageIndex: 0,
      ).cacheKey,
    );
  });

  testWidgets('detects a prepared document theme signature mismatch', (
    tester,
  ) async {
    final prepared = const DefaultForumHtmlRenderPreparer().prepare(
      html: '<p>正文</p>',
      preferences: ForumHtmlReaderPreferences.defaults(),
      theme: forumHtmlTestTheme,
      sourceId: 'theme-mismatch',
      threadId: '100',
      imageCacheOwnerId: '100',
    );

    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            html: prepared.preparedHtml,
            theme: _darkTestTheme,
            sourceId: 'theme-mismatch',
            preparedDocument: prepared,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('compact HTML keeps images in the project cache pipeline', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();
    const referer = 'https://bbs.yamibo.com/';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(cacheService),
          appImageCacheManagerProvider.overrideWith(
            (ref) async =>
                throw StateError('intentional cache manager failure'),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'cached-thread-image',
              threadId: '573279',
              imageReferer: referer,
              contentLayout: ForumHtmlContentLayout.compact,
              html:
                  '<img src="data/attachment/forum/page-1.jpg" '
                  'width="640" height="480">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage).first,
    );

    expect(image.referer, referer);
    expect(image.showDelayedLoadingIndicator, isTrue);
    expect(image.loadingIndicatorDelay, const Duration(milliseconds: 300));
    expect(image.request?.role, ImageCacheRole.threadInline);
    expect(image.request?.ownerType, ImageCacheOwnerType.thread);
    expect(image.request?.ownerId, '573279');
    expect(image.request?.imageIndex, 0);
    expect(
      image.request?.sourceUrl,
      'https://bbs.yamibo.com/data/attachment/forum/page-1.jpg',
    );
    expect(
      image.request?.cacheKey,
      ForumImageCacheRequests.threadInline(
        tid: '573279',
        url: 'https://bbs.yamibo.com/data/attachment/forum/page-1.jpg',
        imageIndex: 0,
      ).cacheKey,
    );
    expect(cacheService.requests.single.cacheKey, image.request?.cacheKey);
  });

  testWidgets('clips attachment and smiley media at the HTML surface', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(cacheService),
          appImageCacheManagerProvider.overrideWith(
            (ref) async => throw StateError('fixture network failure'),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'html-media-radius',
              threadId: '573279',
              html:
                  '<img src="data/attachment/forum/page-1.jpg" '
                  'width="640" height="480">'
                  '<img src="static/image/smiley/gexing/008.gif" '
                  'width="24" height="24">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final images = find.byType(CachedLibraryImage);
    expect(images, findsNWidgets(2));
    for (var index = 0; index < 2; index += 1) {
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(of: images.at(index), matching: find.byType(ClipRRect))
            .first,
      );
      expect(clip.borderRadius, const BorderRadius.all(Radius.circular(4)));
    }

    // The same clip must remain present after the cache miss reaches the
    // remote/error stage; it is owned by the HTML surface, not the cache
    // state.
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: images.first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ClipRRect &&
              widget.borderRadius == const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed thread image offers a retry that reruns the cache flow', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(cacheService),
          appImageCacheManagerProvider.overrideWith(
            (ref) async => throw StateError('fixture network failure'),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'retryable-thread-image',
              threadId: '573279',
              html:
                  '<img src="data/attachment/forum/page-1.jpg" '
                  'width="640" height="480">',
            ),
          ),
        ),
      ),
    );
    // 测试环境的 HttpClient 对所有请求返回失败，图片必然走到失败占位。
    await tester.pumpAndSettle();

    expect(cacheService.requests, hasLength(1));
    final retryButton = find.byKey(
      ValueKey<String>(
        'thread-post-image-retry-${cacheService.requests.single.cacheKey}',
      ),
    );
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(cacheService.requests, hasLength(2));
  });

  testWidgets('builds image load specs before resolving cache requests', (
    tester,
  ) async {
    final resolver = _RecordingForumImageRequestResolver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'spec-thread-image',
              threadId: '573279',
              imageRequestResolver: resolver,
              html:
                  '<img src="data/attachment/forum/page-1.jpg" '
                  'width="640" height="480">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CachedLibraryImage), findsOneWidget);
    expect(resolver.specs, hasLength(1));
    expect(resolver.specs.single.kind, ForumImageKind.threadInline);
    expect(resolver.specs.single.ownerId, '573279');
    expect(resolver.specs.single.imageIndex, 0);
    expect(resolver.specs.single.htmlWidth, 640);
    expect(resolver.specs.single.htmlHeight, 480);
    expect(
      resolver.specs.single.sourceUrl,
      'https://bbs.yamibo.com/data/attachment/forum/page-1.jpg',
    );
  });

  testWidgets('renders smiley images through long-lived smiley cache', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'cached-smiley',
              threadId: '573279',
              html: '<img src="static/image/smiley/gexing/008.gif" alt="">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage).first,
    );

    expect(image.request?.role, ImageCacheRole.remoteSmiley);
    expect(image.showDelayedLoadingIndicator, isFalse);
    expect(image.request?.ownerType, ImageCacheOwnerType.sticker);
    expect(image.request?.effectiveRetentionClass, ImageRetentionClass.sticky);
    expect(
      image.request?.cacheKey,
      ImageCacheKeys.remoteSmiley(
        'https://bbs.yamibo.com/static/image/smiley/gexing/008.gif',
      ),
    );
    expect(cacheService.requests.single.role, ImageCacheRole.remoteSmiley);
  });

  testWidgets('does not force unsized smiley images to 24 square', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'unsized-smiley',
              threadId: '573279',
              html: '<img src="static/image/smiley/gexing/008.gif" alt="">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final imageFinder = find.byType(CachedLibraryImage).first;
    final image = tester.widget<CachedLibraryImage>(imageFinder);

    expect(image.width, isNull);
    expect(image.height, isNull);
    expect(
      find.ancestor(
        of: imageFinder,
        matching: find.byWidgetPredicate((widget) {
          return widget is SizedBox &&
              widget.width == 24 &&
              widget.height == 24;
        }),
      ),
      findsNothing,
    );
  });

  testWidgets('uses html dimensions for smiley images when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'sized-smiley',
              threadId: '573279',
              html:
                  '<img src="static/image/smiley/gexing/008.gif" '
                  'width="36" height="28" alt="">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final imageFinder = find.byType(CachedLibraryImage).first;
    final image = tester.widget<CachedLibraryImage>(imageFinder);
    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(of: imageFinder, matching: find.byType(SizedBox)).first,
    );

    expect(image.width, 36);
    expect(image.height, 28);
    expect(sizedBox.width, 36);
    expect(sizedBox.height, 28);
  });

  testWidgets('uses cached dimensions for smiley images when html is unsized', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();
    final cacheKey = ImageCacheKeys.remoteSmiley(
      'https://bbs.yamibo.com/static/image/smiley/gexing/008.gif',
    );
    cacheService.cachedResults[cacheKey] = CachedImageResult(
      success: true,
      cacheKey: cacheKey,
      width: 40,
      height: 32,
      fromCache: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'cached-size-smiley',
              threadId: '573279',
              html: '<img src="static/image/smiley/gexing/008.gif" alt="">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final imageFinder = find.byType(CachedLibraryImage).first;
    final image = tester.widget<CachedLibraryImage>(imageFinder);
    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(of: imageFinder, matching: find.byType(SizedBox)).first,
    );

    expect(image.width, 40);
    expect(image.height, 32);
    expect(sizedBox.width, 40);
    expect(sizedBox.height, 32);
  });

  testWidgets('uses legacy fallback aspect ratio for unsized thread images', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'unsized-image',
              threadId: '573279',
              html: '<img src="data/attachment/forum/page-unsized.jpg">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final aspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;

    expect(aspectRatio, closeTo(0.7, 0.001));
  });

  testWidgets('uses learned fallback ratio and reports decoded block size', (
    tester,
  ) async {
    final resolvedSizes = <Size>[];
    final resolvedCacheKeys = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'learned-ratio-image',
              threadId: '573279',
              html: '<img src="data/attachment/forum/page-learned.jpg">',
              imageFallbackAspectRatioFor: (spec, request) {
                expect(spec.htmlWidth, isNull);
                expect(spec.htmlHeight, isNull);
                resolvedCacheKeys.add(request.cacheKey);
                return 1.6;
              },
              onBlockImageResolved: (spec, request, size) {
                resolvedSizes.add(size);
                resolvedCacheKeys.add(request.cacheKey);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final aspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;

    expect(aspectRatio, closeTo(1.6, 0.001));

    tester
        .widget<CachedLibraryImage>(find.byType(CachedLibraryImage).first)
        .onImageResolved
        ?.call(const Size(800, 400));
    await tester.pump();

    expect(resolvedSizes, <Size>[const Size(800, 400)]);
    expect(resolvedCacheKeys, hasLength(2));
    expect(resolvedCacheKeys.toSet(), hasLength(1));
  });

  testWidgets('promotes fallback thread image layout after decoded size', (
    tester,
  ) async {
    final shifts = <ForumHtmlImageLayoutShift>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'decoded-size-image',
              threadId: '573279',
              html: '<img src="data/attachment/forum/page-decoded.jpg">',
              callbacks: ForumHtmlRenderCallbacks(
                onImageLayoutShift: shifts.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    double currentAspectRatio() =>
        tester.getSize(find.byType(CachedLibraryImage).first).aspectRatio;

    expect(currentAspectRatio(), closeTo(0.7, 0.001));

    tester
        .widget<CachedLibraryImage>(find.byType(CachedLibraryImage).first)
        .onImageResolved
        ?.call(const Size(1600, 900));
    await tester.pump();

    expect(currentAspectRatio(), closeTo(1600 / 900, 0.001));
    expect(shifts, hasLength(1));
    expect(shifts.single.oldAspectRatio, 0.7);
    expect(shifts.single.newAspectRatio, 1600 / 900);
    expect(shifts.single.deltaHeight, lessThan(0));
  });

  testWidgets(
    'uses the decoded ratio for small deltas without scroll compensation',
    (tester) async {
      final shifts = <ForumHtmlImageLayoutShift>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(
              _RecordingImageCacheService(),
            ),
          ],
          child: LocalizedTestApp(
            home: Scaffold(
              body: ForumHtmlWidgetPostRenderer(
                theme: forumHtmlTestTheme,
                sourceId: 'small-decoded-size-delta-image',
                threadId: '573279',
                html: '<img src="data/attachment/forum/page-small-delta.jpg">',
                callbacks: ForumHtmlRenderCallbacks(
                  onImageLayoutShift: shifts.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      double currentAspectRatio() =>
          tester.getSize(find.byType(CachedLibraryImage).first).aspectRatio;

      ClipRRect currentClip() {
        return tester.widget<ClipRRect>(
          find
              .ancestor(
                of: find.byType(CachedLibraryImage).first,
                matching: find.byType(ClipRRect),
              )
              .first,
        );
      }

      expect(currentAspectRatio(), closeTo(0.7, 0.001));
      expect(
        currentClip().borderRadius,
        const BorderRadius.all(Radius.circular(4)),
      );

      tester
          .widget<CachedLibraryImage>(find.byType(CachedLibraryImage).first)
          .onImageResolved
          ?.call(const Size(720, 1000));
      await tester.pump();

      expect(currentAspectRatio(), closeTo(0.72, 0.001));
      expect(shifts, isEmpty);
      expect(
        currentClip().borderRadius,
        const BorderRadius.all(Radius.circular(4)),
      );
    },
  );
}
