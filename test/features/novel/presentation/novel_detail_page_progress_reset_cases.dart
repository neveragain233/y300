part of 'novel_detail_page_test.dart';

void _progressResetCases() {
  testWidgets('continue resumes the single last-read progress', (tester) async {
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      repository: _FakeNovelRepository(
        progress: NovelReadingProgress(
          novelId: 'novel:1',
          episodeId: 'novel:1:e1',
          scrollOffset: 88,
          updatedAt: DateTime(2026, 7, 21),
        ),
      ),
    );

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).openPolicy,
      NovelEpisodeOpenPolicy.resumeLastRead,
    );
  });

  testWidgets('a non-recent unfinished chapter resumes its own position', (
    tester,
  ) async {
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      readingStateRepository: _MemoryNovelReadingStateRepository(
        hasPosition: true,
        recentEpisodeId: 'another-chapter',
      ),
    );
    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).openPolicy,
      NovelEpisodeOpenPolicy.resumeLastRead,
    );
  });

  testWidgets(
    'completed chapters reopen from the beginning without clearing completion',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(
        hasPosition: true,
        isRead: true,
      );
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(),
        routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
        readingStateRepository: reading,
      );
      await _scrollNovelChapterIntoTapArea(tester);
      await tester.tap(find.text('Chapter 1'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).openPolicy,
        NovelEpisodeOpenPolicy.startAtBeginning,
      );
      expect(reading.isRead, isTrue);
      expect(reading.readMutationCount, 0);
    },
  );

  testWidgets(
    'long press explicitly starts from the beginning without changing stored progress',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(hasPosition: true);
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(),
        routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
        readingStateRepository: reading,
      );
      await _scrollNovelChapterIntoTapArea(tester);
      await tester.longPress(find.text('Chapter 1'));
      await tester.pumpAndSettle();
      final action = find.byKey(
        const ValueKey<String>(
          'unified-detail-chapter-start-action-novel:1:e1',
        ),
      );
      final l10n = AppLocalizations.of(tester.element(action));
      expect(find.text(l10n.libraryDetailStartFromBeginning), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).openPolicy,
        NovelEpisodeOpenPolicy.startAtBeginning,
      );
      expect(reading.hasPosition, isTrue);
      expect(reading.readMutationCount, 0);
    },
  );

  testWidgets(
    'chapter swipe marks completion once and resetting preserves its bookmark',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(
        hasPosition: true,
        isBookmarked: true,
      );
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(),
        routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
        readingStateRepository: reading,
      );
      await _scrollNovelChapterIntoTapArea(tester);
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-novel:1:e1'),
      );
      await tester.drag(chapter, const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(reading.isRead, isTrue);
      expect(reading.readMutationCount, 1);
      expect(reading.hasPosition, isTrue);
      expect(reading.isBookmarked, isTrue);
      await tester.drag(chapter, const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(reading.isRead, isFalse);
      expect(reading.readMutationCount, 2);
      expect(reading.hasPosition, isFalse);
      expect(reading.isBookmarked, isTrue);
      expect(reading.recentEpisodeId, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chapter menu confirms resetting the whole novel and preserves bookmarks',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(
        hasPosition: true,
        isRead: true,
        isBookmarked: true,
      );
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(),
        routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
        readingStateRepository: reading,
      );
      await _scrollNovelChapterIntoTapArea(tester);
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-novel:1:e1'),
      );
      await tester.longPress(chapter);
      await tester.pumpAndSettle();
      final action = find.byKey(
        const Key('unified-detail-work-reset-reading-action'),
      );
      final l10n = AppLocalizations.of(tester.element(action));
      expect(find.text(l10n.libraryDetailResetWorkReading), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryDetailResetReadingBody), findsOneWidget);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(reading.workResetCount, 0);
      expect(reading.hasPosition, isTrue);
      expect(reading.isRead, isTrue);

      await tester.longPress(chapter);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('unified-detail-work-reset-reading-confirm')),
      );
      await tester.pumpAndSettle();

      expect(reading.workResetCount, 1);
      expect(reading.readMutationCount, 0);
      expect(reading.hasPosition, isFalse);
      expect(reading.isRead, isFalse);
      expect(reading.recentEpisodeId, isNull);
      expect(reading.isBookmarked, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed whole-novel reset preserves reading state and can be retried',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(
        hasPosition: true,
        isRead: true,
        isBookmarked: true,
      )..appliesMutation = false;
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(),
        routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
        readingStateRepository: reading,
      );
      await _scrollNovelChapterIntoTapArea(tester);
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-novel:1:e1'),
      );
      Future<void> reset() async {
        await tester.longPress(chapter);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('unified-detail-work-reset-reading-action')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('unified-detail-work-reset-reading-confirm')),
        );
        await tester.pumpAndSettle();
      }

      await reset();
      final l10n = AppLocalizations.of(tester.element(chapter));
      expect(find.text(l10n.libraryDetailResetReadingFailed), findsOneWidget);
      expect(reading.hasPosition, isTrue);
      expect(reading.isRead, isTrue);
      expect(reading.isBookmarked, isTrue);
      reading.appliesMutation = true;
      await reset();
      expect(reading.workResetCount, 2);
      expect(reading.hasPosition, isFalse);
      expect(reading.isRead, isFalse);
      expect(reading.isBookmarked, isTrue);
    },
  );

  testWidgets(
    'a failed chapter swipe preserves state and releases the action lock',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(hasPosition: true)
        ..appliesMutation = false;
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(),
        routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
        readingStateRepository: reading,
      );
      await _scrollNovelChapterIntoTapArea(tester);
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-novel:1:e1'),
      );
      await tester.drag(chapter, const Offset(240, 0));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(chapter));
      expect(
        find.text(l10n.libraryDetailReadStateUpdateFailed),
        findsOneWidget,
      );
      expect(reading.isRead, isFalse);
      expect(reading.hasPosition, isTrue);
      reading.appliesMutation = true;
      await tester.drag(chapter, const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(reading.isRead, isTrue);
      expect(reading.readMutationCount, 2);
    },
  );

  testWidgets(
    'explicit beginning confirms source position only after readable content',
    (tester) async {
      final reading = _MemoryNovelReadingStateRepository(hasPosition: true);
      final resolver = _FakeNovelChapterSourceRouteResolver.success(page: 7);
      await _pumpNovelDetail(
        tester,
        preferences: _MemoryNovelInteractionPreferencesRepository(
          NovelChapterOpenMode.sourcePost,
        ),
        routeResolver: resolver,
        readingStateRepository: reading,
        threadRepository: _FakeThreadRepository(),
      );
      await _scrollNovelChapterIntoTapArea(tester);
      await tester.longPress(find.text('Chapter 1'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'unified-detail-chapter-start-action-novel:1:e1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NovelReaderPage), findsNothing);
      expect(
        tester
            .widget<ThreadDetailPage>(find.byType(ThreadDetailPage))
            .targetPid,
        '5001',
      );
      expect(reading.readMutationCount, 0);
      expect(reading.hasPosition, isTrue);
      expect(reading.lastCommitted?.progressPercent, 0);
      expect(reading.completionCommitCount, 1);
    },
  );

  testWidgets('the chapter marked last-read resumes its progress', (
    tester,
  ) async {
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      repository: _FakeNovelRepository(
        progress: NovelReadingProgress(
          novelId: 'novel:1',
          episodeId: 'novel:1:e1',
          scrollOffset: 88,
          updatedAt: DateTime(2026, 7, 21),
        ),
      ),
    );

    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NovelReaderPage>(find.byType(NovelReaderPage)).openPolicy,
      NovelEpisodeOpenPolicy.resumeLastRead,
    );
  });

  testWidgets('source route double click resolves and pushes only once', (
    tester,
  ) async {
    final gate = Completer<void>();
    final resolver = _FakeNovelChapterSourceRouteResolver.success()
      ..waitFor = gate.future;
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(
        NovelChapterOpenMode.sourcePost,
      ),
      routeResolver: resolver,
      threadRepository: _FakeThreadRepository(),
    );
    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.tap(find.text('Chapter 1'));
    await tester.pump();
    expect(resolver.callCount, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ThreadDetailPage, skipOffstage: false), findsOneWidget);
    Navigator.of(tester.element(find.byType(ThreadDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ThreadDetailPage, skipOffstage: false), findsNothing);
    expect(find.byType(NovelDetailPage), findsOneWidget);
  });

  testWidgets('source route failure offers opening the thread home', (
    tester,
  ) async {
    final resolver = _FakeNovelChapterSourceRouteResolver.failure();
    final reading = _MemoryNovelReadingStateRepository();
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(
        NovelChapterOpenMode.sourcePost,
      ),
      routeResolver: resolver,
      readingStateRepository: reading,
      threadRepository: _FakeThreadRepository(),
    );

    await _scrollNovelChapterIntoTapArea(tester);
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-source-route-failure-dialog')),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NovelDetailPage)),
    );
    expect(find.text(l10n.threadPostTargetUnconfirmed), findsOneWidget);
    expect(find.textContaining('test_failure'), findsNothing);
    expect(find.byType(ThreadDetailPage), findsNothing);
    expect(
      find.byKey(const Key('thread-post-route-open-home')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('thread-post-route-open-home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final threadPage = tester.widget<ThreadDetailPage>(
      find.byType(ThreadDetailPage),
    );
    expect(threadPage.tid, '100');
    expect(threadPage.initialPage, isNull);
    expect(threadPage.targetPid, isNull);
    expect(threadPage.bodyReadingObserver, isNull);
    expect(reading.progressCommitCount, 0);
    expect(reading.completionCommitCount, 0);
  });

  testWidgets('continue opens the first chapter in source-post mode', (
    tester,
  ) async {
    final resolver = _FakeNovelChapterSourceRouteResolver.success();
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(
        NovelChapterOpenMode.sourcePost,
      ),
      routeResolver: resolver,
      threadRepository: _FakeThreadRepository(),
    );

    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ThreadDetailPage), findsOneWidget);
    expect(find.byType(NovelReaderPage), findsNothing);
    expect(resolver.callCount, 1);
  });
}
