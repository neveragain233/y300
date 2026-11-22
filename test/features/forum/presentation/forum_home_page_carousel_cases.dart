part of 'forum_home_page_test.dart';

void _carouselCases() {
  testWidgets(
    'renders carousel, grouped sections, forum rows, and today counts',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(_loggedOutPayloadWithCarousel()),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
      expect(find.byKey(const Key('forum-home-carousel')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('forum-home-carousel'))).height,
        greaterThan(0),
      );
      final carouselClip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byKey(const Key('forum-home-carousel')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(carouselClip.borderRadius, BorderRadius.circular(16));
      expect(find.text('综合区'), findsOneWidget);
      expect(find.text('公告区'), findsOneWidget);
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const Key('forum-card-2')), findsOneWidget);
      expect(find.textContaining('共1 个分组'), findsNothing);
    },
  );

  testWidgets('carousel uses sticky forum head image cache request', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayloadWithCarousel()),
    );

    await tester.pumpWidget(
      _buildTestApp(repository, imageCacheService: cacheService),
    );
    await tester.pump();
    await tester.pump();

    final carouselImage = tester.widget<CachedLibraryImage>(
      find.descendant(
        of: find.byKey(const Key('forum-home-carousel')),
        matching: find.byType(CachedLibraryImage),
      ),
    );

    expect(carouselImage.request?.role, ImageCacheRole.forumHeadImage);
    expect(carouselImage.request?.ownerType, ImageCacheOwnerType.forum);
    expect(
      carouselImage.request?.effectiveRetentionClass,
      ImageRetentionClass.sticky,
    );
    expect(
      carouselImage.request?.sourceUrl,
      'https://bbs.yamibo.com/banner.jpg',
    );
    expect(
      cacheService.requests.where(
        (request) => request.role == ImageCacheRole.forumHeadImage,
      ),
      isNotEmpty,
    );
  });

  testWidgets('carousel applies a ratio update without replacing its content', (
    tester,
  ) async {
    Widget build(double? aspectRatio) {
      return ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHomeCarousel(
              items: [
                ForumHomeCarouselItem(
                  imageUrl: 'https://bbs.yamibo.com/banner.jpg',
                  targetUrl: 'https://bbs.yamibo.com/thread-570956-1-1.html',
                  aspectRatio: aspectRatio,
                ),
              ],
              imageReferer: 'https://bbs.yamibo.com/',
              onOpen: (_) {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(null));
    await tester.pump();

    final carousel = find.byKey(const Key('forum-home-carousel'));
    final width = tester.getSize(carousel).width;
    expect(
      tester.getSize(carousel).height,
      closeTo((width / 3.45).clamp(0, ForumHomeCarousel.maxHeight), 0.01),
    );

    await tester.pumpWidget(build(6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.getSize(carousel).height, closeTo(width / 6, 0.01));
  });

  testWidgets('carousel suspends its timer while inactive or ticker-muted', (
    tester,
  ) async {
    Widget build({bool isActive = true, bool tickersEnabled = true}) {
      return ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: TickerMode(
              enabled: tickersEnabled,
              child: ForumHomeCarousel(
                items: const [
                  ForumHomeCarouselItem(
                    imageUrl: 'https://bbs.yamibo.com/banner-1.jpg',
                    targetUrl: 'https://bbs.yamibo.com/thread-1-1-1.html',
                  ),
                  ForumHomeCarouselItem(
                    imageUrl: 'https://bbs.yamibo.com/banner-2.jpg',
                    targetUrl: 'https://bbs.yamibo.com/thread-2-1-1.html',
                  ),
                ],
                imageReferer: 'https://bbs.yamibo.com/',
                isActive: isActive,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build());
    await tester.pump();
    final slider = tester.state<CarouselSliderState>(
      find.byType(CarouselSlider),
    );
    final initialPage = slider.pageController!.page!;
    expect(slider.timer?.isActive, isTrue);

    await tester.pumpWidget(build(isActive: false));
    expect(slider.timer, isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(slider.pageController!.page, initialPage);

    await tester.pumpWidget(build(tickersEnabled: false));
    expect(slider.timer, isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(slider.pageController!.page, initialPage);

    await tester.pumpWidget(build());
    expect(slider.timer?.isActive, isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(slider.pageController!.page, greaterThan(initialPage));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('carousel adopts the first decoded image ratio', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHomeCarousel(
              items: const [
                ForumHomeCarouselItem(
                  imageUrl: 'https://bbs.yamibo.com/banner.jpg',
                  targetUrl: 'https://bbs.yamibo.com/thread-570956-1-1.html',
                ),
              ],
              imageReferer: 'https://bbs.yamibo.com/',
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final carousel = find.byKey(const Key('forum-home-carousel'));
    final width = tester.getSize(carousel).width;
    final image = tester.widget<CachedLibraryImage>(
      find.descendant(of: carousel, matching: find.byType(CachedLibraryImage)),
    );

    image.onImageResolved!(const Size(900, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getSize(carousel).height,
      closeTo((width / 3).clamp(0, ForumHomeCarousel.maxHeight), 0.01),
    );
  });

  testWidgets('carousel pending item prewarm uses forum image precache', (
    tester,
  ) async {
    final precacheService = _RecordingForumImagePrecacheService();
    const oldItems = [
      ForumHomeCarouselItem(
        imageUrl: 'https://bbs.yamibo.com/old-banner.jpg',
        targetUrl: 'https://bbs.yamibo.com/thread-1-1-1.html',
      ),
    ];
    const newItems = [
      ForumHomeCarouselItem(
        imageUrl: 'https://bbs.yamibo.com/new-banner.jpg',
        targetUrl: 'https://bbs.yamibo.com/thread-2-1-1.html',
      ),
    ];

    Widget build(List<ForumHomeCarouselItem> items) {
      return ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
          forumImagePrecacheServiceProvider.overrideWithValue(precacheService),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumHomeCarousel(
              items: items,
              imageReferer: 'https://bbs.yamibo.com/',
              onOpen: (_) {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(oldItems));
    await tester.pump();
    await tester.pumpWidget(build(newItems));
    await tester.pump();

    expect(precacheService.decodedSpecs, hasLength(1));
    expect(
      precacheService.decodedSpecs.single.kind,
      ForumImageKind.forumHeadImage,
    );
    expect(precacheService.decodedSpecs.single.ownerId, 'home');
    expect(
      precacheService.decodedSpecs.single.sourceUrl,
      'https://bbs.yamibo.com/new-banner.jpg',
    );
  });

  testWidgets('renders forum list when carousel is empty', (tester) async {
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayload()),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-carousel')), findsNothing);
    expect(find.byKey(const Key('forum-card-2')), findsOneWidget);
  });
}
