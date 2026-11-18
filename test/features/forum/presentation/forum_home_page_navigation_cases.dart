part of 'forum_home_page_test.dart';

void _navigationCases() {
  testWidgets('opens forum display page when forum row is tapped', (
    tester,
  ) async {
    final observer = _CountingNavigatorObserver();
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayload()),
    );

    await tester.pumpWidget(
      _buildTestApp(repository, navigatorObservers: [observer]),
    );
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;
    await tester.tap(find.byKey(const Key('forum-card-2')));

    expect(observer.pushCount, pushCountBeforeTap + 1);
  });

  testWidgets('opens thread detail when carousel target is a thread link', (
    tester,
  ) async {
    final observer = _CountingNavigatorObserver();
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayloadWithCarousel()),
    );

    await tester.pumpWidget(
      _buildTestApp(repository, navigatorObservers: [observer]),
    );
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;
    await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));

    expect(observer.pushCount, pushCountBeforeTap + 1);
  });

  testWidgets('copies an external carousel URL and reports success', (
    tester,
  ) async {
    final launcher = _FakeForumWebViewExternalLauncher();
    final clipboard = _FakeClipboardTextWriter();
    const targetUrl = 'https://www.yamibo.com/notice?ref=a%2Fb&value=two#part';
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(
        _loggedOutPayload(
          carouselItems: const [
            ForumHomeCarouselItem(
              imageUrl: 'https://bbs.yamibo.com/banner.jpg',
              targetUrl: targetUrl,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        launcher: launcher,
        extraOverrides: [
          clipboardTextWriterProvider.overrideWithValue(clipboard),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ForumHomePage)),
    );

    await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));
    await tester.pump();

    expect(clipboard.written, [targetUrl]);
    expect(launcher.launchedUris, isEmpty);
    expect(find.text(l10n.linkCopied), findsOneWidget);
  });

  testWidgets('reports an external carousel link copy failure', (tester) async {
    final launcher = _FakeForumWebViewExternalLauncher();
    final clipboard = _FakeClipboardTextWriter(error: StateError('clipboard'));
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(
        _loggedOutPayload(
          carouselItems: const [
            ForumHomeCarouselItem(
              imageUrl: 'https://bbs.yamibo.com/banner.jpg',
              targetUrl: 'https://www.yamibo.com/',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        launcher: launcher,
        extraOverrides: [
          clipboardTextWriterProvider.overrideWithValue(clipboard),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ForumHomePage)),
    );

    await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));
    await tester.pump();

    expect(clipboard.written, ['https://www.yamibo.com/']);
    expect(launcher.launchedUris, isEmpty);
    expect(find.text(l10n.linkCopyFailed), findsOneWidget);
    expect(find.text(l10n.linkCopied), findsNothing);
  });

  for (final (targetUrl, pageNumber) in [
    ('https://bbs.yamibo.com/forum-52-1.html', 1),
    ('forum-52-3.html', 3),
    ('forum.php?mod=forumdisplay&fid=52&page=4', 4),
  ]) {
    testWidgets('opens carousel forum natively with its page: $targetUrl', (
      tester,
    ) async {
      final launcher = _FakeForumWebViewExternalLauncher();
      final clipboard = _FakeClipboardTextWriter();
      final webUris = <Uri>[];
      Widget? nativePage;
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(
          _loggedOutPayload(
            carouselItems: [
              ForumHomeCarouselItem(
                imageUrl: 'https://bbs.yamibo.com/banner.jpg',
                targetUrl: targetUrl,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          launcher: launcher,
          extraOverrides: [
            clipboardTextWriterProvider.overrideWithValue(clipboard),
            nativeForumLinkPageFactoryProvider.overrideWithValue((
              destination, {
              bool isActive = true,
            }) {
              nativePage = nativeForumLinkPage(destination, isActive: isActive);
              return const Scaffold(key: Key('native-carousel-destination'));
            }),
            forumWebViewRouteFactoryProvider.overrideWithValue((config) {
              webUris.add(config.initialUri);
              return MaterialPageRoute<void>(builder: (_) => const Scaffold());
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));
      await tester.pumpAndSettle();
      expect(nativePage, isA<ForumDisplayPage>());
      expect((nativePage! as ForumDisplayPage).fid, '52');
      expect((nativePage! as ForumDisplayPage).initialPage, pageNumber);
      expect(
        find.byKey(const Key('native-carousel-destination')),
        findsOneWidget,
      );
      expect(webUris, isEmpty);
      expect(launcher.launchedUris, isEmpty);
      expect(clipboard.written, isEmpty);
    });
  }

  testWidgets('opens supported non-thread carousel links natively', (
    tester,
  ) async {
    final launcher = _FakeForumWebViewExternalLauncher();
    final clipboard = _FakeClipboardTextWriter();
    const targetUrl = 'https://bbs.yamibo.com/misc.php?mod=tag&id=3';
    Widget? nativePage;
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(
        _loggedOutPayload(
          carouselItems: const [
            ForumHomeCarouselItem(
              imageUrl: 'https://bbs.yamibo.com/banner.jpg',
              targetUrl: targetUrl,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        launcher: launcher,
        extraOverrides: [
          clipboardTextWriterProvider.overrideWithValue(clipboard),
          nativeForumLinkPageFactoryProvider.overrideWithValue((
            destination, {
            bool isActive = true,
          }) {
            nativePage = nativeForumLinkPage(destination, isActive: isActive);
            return const Scaffold();
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));
    await tester.pump();

    expect(nativePage, isA<YamiboTagThreadPage>());
    expect((nativePage! as YamiboTagThreadPage).tagId, '3');
    expect(launcher.launchedUris, isEmpty);
    expect(clipboard.written, isEmpty);
  });

  testWidgets('keeps unsupported forum filters in an in-app WebView', (
    tester,
  ) async {
    final launcher = _FakeForumWebViewExternalLauncher();
    final opened = <Uri>[];
    const target =
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=52&page=3&filter=typeid&typeid=1';
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(
        _loggedOutPayload(
          carouselItems: const [
            ForumHomeCarouselItem(
              imageUrl: 'https://bbs.yamibo.com/banner.jpg',
              targetUrl: target,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        launcher: launcher,
        extraOverrides: [
          forumWebViewRouteFactoryProvider.overrideWithValue((config) {
            opened.add(config.initialUri);
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(key: Key('carousel-web-fallback')),
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(target)]);
    expect(find.byKey(const Key('carousel-web-fallback')), findsOneWidget);
    expect(launcher.launchedUris, isEmpty);
  });

  testWidgets('suppresses carousel copy feedback after leaving the route', (
    tester,
  ) async {
    final pending = Completer<void>();
    final launcher = _FakeForumWebViewExternalLauncher();
    final clipboard = _FakeClipboardTextWriter(pending: pending);
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(
        _loggedOutPayload(
          carouselItems: const [
            ForumHomeCarouselItem(
              imageUrl: 'https://bbs.yamibo.com/banner.jpg',
              targetUrl: 'https://www.yamibo.com/',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        launcher: launcher,
        extraOverrides: [
          clipboardTextWriterProvider.overrideWithValue(clipboard),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final pageContext = tester.element(find.byType(ForumHomePage));
    final l10n = AppLocalizations.of(pageContext);

    await tester.tap(find.byKey(const Key('forum-home-carousel-item-0')));
    expect(clipboard.written, ['https://www.yamibo.com/']);
    unawaited(
      Navigator.of(pageContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();

    expect(launcher.launchedUris, isEmpty);
    expect(find.text(l10n.linkCopied), findsNothing);
    expect(find.text(l10n.linkCopyFailed), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme native home surfaces are theme driven', (
    tester,
  ) async {
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository),
        child: LocalizedTestApp(
          theme: AppTheme.dark(),
          home: const ForumHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final palette = ForumHomeNativePalette.resolve(AppTheme.dark());
    expect(palette.background, AppTheme.dark().scaffoldBackgroundColor);
    expect(
      palette.sectionBodyBackground,
      AppTheme.dark().colorScheme.surfaceContainer,
    );
    expect(palette.sectionBodyBackground, isNot(Colors.white));
    expect(find.byKey(const Key('forum-favorite-card-2')), findsOneWidget);
  });
}
