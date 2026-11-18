part of 'novel_detail_page_test.dart';

void _openModeCases() {
  testWidgets('chapter open mode selection is persisted globally', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.reset);
    final preferences = _MemoryNovelInteractionPreferencesRepository();
    await _pumpNovelDetail(
      tester,
      preferences: preferences,
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
    );

    final control = find.byKey(const Key('novel-chapter-open-mode-control'));
    await tester.scrollUntilVisible(
      control,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    try {
      final l10n = AppLocalizations.of(tester.element(control));
      final reader = find.descendant(
        of: control,
        matching: find.widgetWithText(TextButton, l10n.novelOpenInReader),
      );
      final source = find.descendant(
        of: control,
        matching: find.widgetWithText(TextButton, l10n.novelOpenSourcePost),
      );
      final readerRect = tester.getRect(reader);
      final sourceRect = tester.getRect(source);
      final indicator = find.byKey(
        const Key('novel-chapter-open-mode-indicator'),
      );
      final initialIndicatorX = tester.getCenter(indicator).dx;
      expect(readerRect.size.width, greaterThanOrEqualTo(48));
      expect(readerRect.size.height, greaterThanOrEqualTo(48));
      expect(sourceRect.size.width, greaterThanOrEqualTo(48));
      expect(sourceRect.size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(reader).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      await tester.tap(source);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final movingIndicatorX = tester.getCenter(indicator).dx;
      expect(movingIndicatorX, greaterThan(initialIndicatorX));
      expect(movingIndicatorX, lessThan(sourceRect.center.dx));
      expect(tester.getRect(reader), readerRect);
      expect(tester.getRect(source), sourceRect);
      await tester.pumpAndSettle();

      expect(preferences.mode, NovelChapterOpenMode.sourcePost);
      expect(
        tester.getSemantics(source).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        tester.getSemantics(reader).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      expect(tester.getRect(reader), readerRect);
      expect(tester.getRect(source), sourceRect);
      expect(
        tester.getCenter(indicator).dx,
        closeTo(sourceRect.center.dx, 0.5),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('source-post mode opens located ordinary page and target PID', (
    tester,
  ) async {
    final preferences = _MemoryNovelInteractionPreferencesRepository(
      NovelChapterOpenMode.sourcePost,
    );
    final resolver = _FakeNovelChapterSourceRouteResolver.success(page: 7);
    final libraryState = _FakeLibraryStateRepository();
    await _pumpNovelDetail(
      tester,
      preferences: preferences,
      routeResolver: resolver,
      libraryStateRepository: libraryState,
      threadRepository: _FakeThreadRepository(),
    );

    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final threadPage = tester.widget<ThreadDetailPage>(
      find.byType(ThreadDetailPage),
    );
    expect(threadPage.tid, '100');
    expect(threadPage.initialPage, 7);
    expect(threadPage.targetPid, '5001');
    expect(resolver.lastReference?.tid, '100');
    expect(resolver.lastReference?.pid, '5001');
    expect(libraryState.readMutationCount, 0);
  });

  testWidgets('continue honors source-post mode for the last-read chapter', (
    tester,
  ) async {
    final resolver = _FakeNovelChapterSourceRouteResolver.success(page: 6);
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(
        NovelChapterOpenMode.sourcePost,
      ),
      routeResolver: resolver,
      repository: _FakeNovelRepository(
        progress: NovelReadingProgress(
          novelId: 'novel:1',
          episodeId: 'novel:1:e1',
          scrollOffset: 88,
          updatedAt: DateTime(2026, 7, 15),
        ),
      ),
      threadRepository: _FakeThreadRepository(),
    );

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    final threadPage = tester.widget<ThreadDetailPage>(
      find.byType(ThreadDetailPage),
    );
    expect(threadPage.initialPage, 6);
    expect(threadPage.targetPid, '5001');
    expect(resolver.lastReference?.pid, '5001');
  });

  testWidgets('source restoration binds the catalog and remains read only', (
    tester,
  ) async {
    final reading = _MemoryNovelReadingStateRepository(hasPosition: true);
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(
        NovelChapterOpenMode.sourcePost,
      ),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(page: 7),
      readingStateRepository: reading,
      threadRepository: _FakeThreadRepository(),
    );
    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    final page = tester.widget<ThreadDetailPage>(find.byType(ThreadDetailPage));
    expect(page.initialPage, 7);
    expect(page.bodyReadingObserver?.tracks('100', '5001'), isTrue);
    expect(page.bodyReadingObserver?.tracks('100', '5002'), isFalse);
    expect(reading.progressCommitCount, 0);
    expect(reading.completionCommitCount, 0);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(reading.progressCommitCount, 0);
    expect(reading.hasPosition, isTrue);
    expect(reading.isRead, isFalse);
  });

  testWidgets('a readable source chapter updates the same catalog state', (
    tester,
  ) async {
    final reading = _MemoryNovelReadingStateRepository();
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(
        NovelChapterOpenMode.sourcePost,
      ),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      readingStateRepository: reading,
      threadRepository: _FakeThreadRepository(),
    );
    expect(reading.hasPosition, isFalse);
    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(reading.hasPosition, isTrue);
    expect(reading.lastCommitted?.progressPercent, 0);
    expect(reading.lastCommitted?.isProgressPercentValid, isTrue);
    expect(reading.lastCommitted?.percentBasis, 'bodyGeometryV1');
    expect(reading.lastCommitted?.anchorNodeId, isNull);
    expect(reading.lastCommitted?.paginationKey, isNull);
    expect(reading.completionCommitCount, 1);
    expect(reading.recentEpisodeId, 'novel:1:e1');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final chapter = find.byKey(
      const ValueKey<String>('unified-detail-chapter-novel:1:e1'),
    );
    final l10n = AppLocalizations.of(tester.element(chapter));
    expect(
      find.descendant(
        of: chapter,
        matching: find.textContaining(
          l10n.libraryChapterLastRead,
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    expect(reading.isRead, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('work source action binds bodies without restoring a chapter', (
    tester,
  ) async {
    final reading = _MemoryNovelReadingStateRepository(hasPosition: true);
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      readingStateRepository: reading,
      threadRepository: _FakeThreadRepository(),
    );
    final actions = find.byKey(const Key('unified-detail-header-actions-row'));
    final l10n = AppLocalizations.of(tester.element(actions));
    await tester.tap(
      find.descendant(
        of: actions,
        matching: find.text(l10n.libraryDetailSourceThread),
      ),
    );
    await tester.pumpAndSettle();
    final page = tester.widget<ThreadDetailPage>(find.byType(ThreadDetailPage));
    expect(page.targetPid, isNull);
    expect(page.bodyReadingObserver?.tracks('100', '5001'), isTrue);
    expect(reading.progressCommitCount, 0);
  });

  testWidgets('reader mode keeps opening chapters in NovelReaderPage', (
    tester,
  ) async {
    final resolver = _FakeNovelChapterSourceRouteResolver.success();
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: resolver,
    );

    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NovelReaderPage), findsOneWidget);
    expect(
      tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).openPolicy,
      NovelEpisodeOpenPolicy.startAtBeginning,
    );
    expect(resolver.callCount, 0);
  });
}
