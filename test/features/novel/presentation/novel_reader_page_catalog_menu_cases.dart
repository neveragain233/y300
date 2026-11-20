part of 'novel_reader_page_test.dart';

void _catalogMenuCases() {
  testWidgets('NovelReaderPage opens catalog and switches chapter', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      chapterLoadDelay: const Duration(milliseconds: 120),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-chapter-list-sheet')),
      findsOneWidget,
    );
    expect(find.text('当前'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('novel-reader-chapter-novel:49:100:5002')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('novel-reader-delayed-loading-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-surface')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    expect(_readerText('第三段。'), findsOneWidget);
    expect(_readerText('第一段。'), findsNothing);
    expect(repository.savedProgressEpisodeIds, contains('novel:49:100:5001'));
  });

  testWidgets(
    'NovelReaderPage catalog searches chapters and shows empty state',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes();
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-catalog')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-chapter-search-field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('novel-reader-chapter-search-field')),
        '第3章',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-chapter-novel:49:100:5003')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('novel-reader-chapter-novel:49:100:5001')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('novel-reader-chapter-search-field')),
        '5002',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-chapter-novel:49:100:5002')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('novel-reader-chapter-novel:49:100:5003')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('novel-reader-chapter-search-field')),
        '不存在',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-chapter-search-empty')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'NovelReaderPage catalog marks the newly readable chapter as recent',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes(
        readingProgress: NovelReadingProgress(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5003',
          scrollOffset: 120,
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-catalog')),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(NovelReaderPage)),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('novel-reader-chapter-novel:49:100:5001')),
          matching: find.textContaining(l10n.libraryChapterLastRead),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('NovelReaderPage catalog opens near current chapter', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.manyEpisodes(
      count: 20,
      currentIndex: 14,
    );
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        initialEpisodeId: 'novel:49:100:5015',
      ),
    );
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-chapter-novel:49:100:5015')),
      findsOneWidget,
    );
    expect(find.text('当前'), findsOneWidget);
    expect(
      find.byKey(const Key('novel-reader-chapter-novel:49:100:5001')),
      findsNothing,
    );
  });

  testWidgets('NovelReaderPage bottom menu shows progress and chapter nav', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    expect(
      find.byKey(const Key('shared-reader-progress-slider')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shared-reader-prev-button')), findsOneWidget);
    expect(find.byKey(const Key('shared-reader-next-button')), findsOneWidget);
    final verticalSlider = tester.widget<Slider>(
      find.byKey(const Key('shared-reader-progress-slider')),
    );
    expect(verticalSlider.divisions, isNull);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-prev-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-next-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-bookmark')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('shared-reader-top-action-bookmark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-display')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-show-progress-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-show-chapter-title-switch')),
      findsNothing,
    );
  });

  testWidgets('vertical progress slider seeks once on release', (tester) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List<String>.generate(30, (index) => '滚动进度段落 $index'),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();
    await _showReaderMenu(tester);

    final slider = tester.widget<Slider>(
      find.byKey(const Key('shared-reader-progress-slider')),
    );
    slider.onChangeStart?.call(0.5);
    slider.onChanged?.call(0.5);
    slider.onChangeEnd?.call(0.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.lastSavedOffset, greaterThan(0));
    expect(repository.readingProgress?.progressPercent, closeTo(0.5, 0.01));
  });

  testWidgets('NovelReaderPage chapter loading uses one neutral indicator', (
    tester,
  ) async {
    final theme = AppTheme.dark();
    final repository = _FakeNovelRepository.threeEpisodes(
      chapterLoadDelay: const Duration(milliseconds: 420),
    );
    await tester.pumpWidget(
      _buildReaderApp(repository: repository, theme: theme),
    );
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('novel-reader-chapter-novel:49:100:5002')),
    );
    await tester.pump();

    expect(find.byKey(const Key('novel-reader-transition-mask')), findsNothing);
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-indicator')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-indicator')),
      findsOneWidget,
    );
    final surface = tester.widget<ColoredBox>(
      find.byKey(const Key('novel-reader-delayed-loading-surface')),
    );
    expect(surface.color, theme.scaffoldBackgroundColor);

    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-indicator')),
      findsNothing,
    );
  });

  testWidgets(
    'NovelReaderPage reader chrome uses shared palette in dark theme',
    (tester) async {
      final theme = AppTheme.dark();
      final palette = const ReaderChromePaletteResolver().resolve(theme);
      final repository = _FakeNovelRepository();
      await tester.pumpWidget(
        _buildReaderApp(repository: repository, theme: theme),
      );
      await tester.pumpAndSettle();

      final topBar = tester.widget<Material>(
        find.byKey(const Key('shared-reader-top-overlay-bar')),
      );
      final bottomPanel = tester.widget<Material>(
        find.byKey(const Key('shared-reader-bottom-overlay-panel')),
      );

      expect(topBar.color, palette.chromeBackground);
      expect(bottomPanel.color, palette.chromeBackground);
    },
  );

  testWidgets('NovelReaderPage follows application family and brightness', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.vertical,
      ),
      firstParagraphs: List<String>.generate(
        30,
        (index) => '主题同步阅读位置段落 $index',
      ),
    );
    final moonWhite = AppTheme.build(
      family: AppThemeFamily.moonWhite,
      brightness: Brightness.light,
    );
    final themeNotifier = ValueNotifier<ThemeData>(moonWhite);
    addTearDown(themeNotifier.dispose);
    await tester.pumpWidget(
      _buildReaderApp(repository: repository, themeListenable: themeNotifier),
    );
    await tester.pumpAndSettle();

    var background = tester.widget<ColoredBox>(
      find.byKey(const Key('novel-reader-background')),
    );
    expect(background.color, moonWhite.scaffoldBackgroundColor);
    final readerList = find.byKey(const Key('novel-reader-paragraph-list'));
    await tester.drag(readerList, const Offset(0, -160));
    await tester.pumpAndSettle();
    final offsetBeforeThemeChange = tester
        .state<ScrollableState>(
          find.descendant(of: readerList, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;

    final plumPurple = AppTheme.build(
      family: AppThemeFamily.plumPurple,
      brightness: Brightness.dark,
    );
    themeNotifier.value = plumPurple;
    await tester.pumpAndSettle();

    background = tester.widget<ColoredBox>(
      find.byKey(const Key('novel-reader-background')),
    );
    expect(background.color, plumPurple.scaffoldBackgroundColor);
    final offsetAfterThemeChange = tester
        .state<ScrollableState>(
          find.descendant(of: readerList, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    expect(offsetAfterThemeChange, closeTo(offsetBeforeThemeChange, 0.01));
  });

  testWidgets(
    'NovelReaderPage chapter switch failure reveals old content and shows snackbar',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes(
        failedEpisodeIds: const <String>{'novel:49:100:5002'},
        chapterLoadDelay: const Duration(milliseconds: 120),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-catalog')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('novel-reader-chapter-novel:49:100:5002')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('novel-reader-transition-mask')),
        findsNothing,
      );
      expect(_readerText('第一段。'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 140));
      await tester.pumpAndSettle();

      expect(_readerText('第一段。'), findsOneWidget);
      expect(_readerText('第三段。'), findsNothing);
      expect(find.text('章节切换失败，已保留当前章节'), findsOneWidget);
      expect(
        find.byKey(const Key('novel-reader-delayed-loading-indicator')),
        findsNothing,
      );
    },
  );
}
