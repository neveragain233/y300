part of 'novel_reader_html_paged_surface_performance_test.dart';

void _imageFirstFrameCases() {
  testWidgets('text-only current page reports images ready without a host', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 1, isComplete: true);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(host.imagesReady.last, isTrue);
  });

  testWidgets(
    'current image waits for its first frame; neighbor never blocks it',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator()
        ..pageHtml = {
          0: '<img src="https://images.test/first.png" width="160" height="100">',
          1: '<img src="https://images.test/second.png" width="160" height="100">',
        };
      final images = _ControlledPagedImageHost();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
        ..imageHost = images
        ..rawHtml = coordinator.pageHtml.values.join();
      _disposeBudgetHost(tester, coordinator);
      addTearDown(images.dispose);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 2, isComplete: true);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(host.imagesReady.last, isFalse);
      images.show('https://images.test/first.png');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(host.imagesReady.last, isTrue);

      final pageView = find.byKey(const Key('novel-reader-paged-page-view'));
      final gesture = await tester.startGesture(tester.getCenter(pageView));
      await gesture.moveBy(const Offset(-140, 0));
      await tester.pump();
      await tester.pump();
      expect(
        images.frames.containsKey('https://images.test/second.png'),
        isTrue,
      );
      expect(host.positions.last.pageIndex, 0);
      expect(host.imagesReady.last, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(host.navigation.turnNext(), isTrue);
      await tester.pumpAndSettle();
      expect(host.positions.last.pageIndex, 1);
      expect(host.imagesReady.last, isFalse);
      images.show('https://images.test/second.png');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(host.imagesReady.last, isTrue);
    },
  );

  testWidgets('failed image cannot make a paged chapter completion-ready', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator()
      ..pageHtml = {
        0: '<img src="https://images.test/failed.png" width="160" height="100">',
      };
    final images = _ControlledPagedImageHost();
    final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
      ..imageHost = images
      ..rawHtml = coordinator.pageHtml.values.join();
    _disposeBudgetHost(tester, coordinator);
    addTearDown(images.dispose);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 1, isComplete: true);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    images.fail('https://images.test/failed.png');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(host.imagesReady.last, isFalse);
    expect(host.imagesReady, isNot(contains(true)));
  });
}

void _inlineMediaFirstFrameCases() {
  testWidgets('paged surface clips inline media on the first page frame', (
    tester,
  ) async {
    final preferences = NovelReaderPreferences.defaults().copyWith(
      flowMode: NovelReaderFlowMode.pagedLtr,
    );
    final theme = ThemeData.light();
    final palette = const NovelReaderThemeResolver().resolve(
      preferences: preferences,
      theme: theme,
    );
    final htmlTheme = const NovelForumHtmlRenderThemeFactory().fromPalette(
      palette,
    );
    final typography = const NovelReaderTypographyResolver().resolve(
      preferences: preferences,
      theme: theme,
      palette: palette,
    );
    final coordinator = _CompleteRecordingPaginationCoordinator(
      pageHtml:
          '<p><img src="data/attachment/forum/chapter-image.jpg" '
          'width="640" height="480"></p>'
          '<img src="static/image/smiley/gexing/008.gif" '
          'width="24" height="24">',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        ],
        child: LocalizedTestApp(
          theme: theme,
          home: Scaffold(
            body: NovelReaderHtmlPagedSurface(
              rawHtml: coordinator.pageHtml,
              episode: _episode,
              preferences: preferences,
              typography: typography,
              theme: htmlTheme,
              imageReferer: 'https://bbs.yamibo.com/',
              progressSnapshot: const NovelReaderProgressSnapshot(
                novelId: 'performance-novel',
                episodeId: 'performance-episode',
                flowMode: NovelReaderFlowMode.pagedLtr,
                scrollOffset: 0,
                pageIndex: 0,
                progressPercent: 0,
              ),
              coordinatorBuilder: ({
                required BuildContext context,
                required ForumHtmlThemeContext theme,
                required ForumHtmlReaderPreferences preferences,
                required String sourceId,
                required String? threadId,
                required String? imageCacheOwnerId,
                required String? imageReferer,
              }) => coordinator,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
  });
}
