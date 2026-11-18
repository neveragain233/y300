part of 'novel_reader_html_paged_surface_performance_test.dart';

void _missingPageWaitCases() {
  testWidgets('target timeout is recoverable and retry rejects old results', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator);
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-pagination-failure')),
      findsOneWidget,
    );
    expect(host.scrollChoices, 0);
    expect(coordinator.cancelPendingCount, 1);
    expect(host.positions, isEmpty);
    await tester.tap(find.byKey(const Key('novel-reader-pagination-retry')));
    await tester.pump();
    await tester.pump();
    expect(coordinator.attempts, hasLength(2));
    expect(
      find.byKey(const Key('novel-reader-pagination-failure')),
      findsNothing,
    );
    coordinator.emit(0, pageCount: 3, isComplete: true);
    coordinator.fail(0);
    await tester.pump();
    expect(host.positions, isEmpty);
    coordinator.emit(1, pageCount: 3, isComplete: true);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-paged-page-view')),
      findsOneWidget,
    );
    expect(host.positions.last.pageIndex, 0);
    expect(host.scrollChoices, 0);
    expect(coordinator.clearCount, 0);
    final reports = host.positions.length;
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.emit(1, pageCount: 3, isComplete: true);
    coordinator.fail(1);
    await tester.pump();
    expect(host.positions, hasLength(reports));
    expect(host.scrollChoices, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the explicit scroll button requests another mode', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator);
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(host.scrollChoices, 0);
    await tester.tap(find.byKey(const Key('novel-reader-pagination-fallback')));
    await tester.pump();
    expect(host.scrollChoices, 1);
  });

  testWidgets('preparation retry does not consume a late retired result', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final preparation = _GatedPreparationService();
    final host = _BudgetSurfaceHost(
      coordinator,
      preparationService: preparation,
    );
    final chapter = await const DefaultNovelReaderHtmlPreparationService()
        .prepare(
          rawHtml: _budgetRawHtml,
          episode: _episode,
          preferences: const NovelHtmlReaderPreferencesAdapter().map(
            host.preferences,
          ),
          theme: host.htmlTheme,
          sourceId: _episode.episodeId,
          threadId: _episode.sourceTid,
          imageCacheOwnerId: _episode.sourceTid,
        );
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    expect(preparation.requests, hasLength(1));
    expect(coordinator.attempts, isEmpty);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-pagination-failure')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('novel-reader-pagination-retry')));
    await tester.pump();
    expect(preparation.requests, hasLength(2));

    preparation.requests.first.complete(chapter);
    await tester.pump();
    await tester.pump();
    expect(coordinator.attempts, isEmpty);
    expect(host.positions, isEmpty);
    expect(
      find.byKey(const Key('novel-reader-paged-preparing')),
      findsOneWidget,
    );
    preparation.requests.last.complete(chapter);
    await tester.pump();
    await tester.pump();
    expect(coordinator.attempts, hasLength(1));
    coordinator.emit(0, pageCount: 3, isComplete: true);
    await tester.pump();
    await tester.pump();
    expect(host.positions.last.pageIndex, 0);
    expect(host.scrollChoices, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an uncovered restore target times out despite earlier page events',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(
        coordinator,
        targetPageWait: const Duration(milliseconds: 50),
      );
      host.snapshot = host.snapshot.copyWith(
        pageIndex: 99,
        paginationKey: 'previous-layout',
        anchorNodeId: 'paragraph-2',
        anchorFormatVersion: 1,
        anchorTextIdentity: NovelReaderAnchorFormat.textIdentity('尾页'),
        isProgressPercentValid: false,
      );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      coordinator.emit(0, pageCount: 2);
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-paged-restoring-position')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-pagination-failure')),
        findsOneWidget,
      );
      expect(host.positions, isEmpty);
      expect(host.scrollChoices, 0);
      await tester.tap(find.byKey(const Key('novel-reader-pagination-retry')));
      await tester.pump();
      coordinator.emit(1, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(host.positions.last.pageIndex, 2);
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isFalse);
    },
  );

  testWidgets('a changed navigation request receives its own waiting budget', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator);
    host.navigationRequest = _budgetNavigation(1, 1);
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    await tester.pump(const Duration(milliseconds: 30));
    host.navigationRequest = _budgetNavigation(2, 2);
    await tester.pumpWidget(host.build());
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      find.byKey(const Key('novel-reader-pagination-failure')),
      findsNothing,
    );
    expect(coordinator.cancelPendingCount, 0);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-pagination-failure')),
      findsOneWidget,
    );
    expect(coordinator.cancelPendingCount, 1);
    expect(host.scrollChoices, 0);
  });

  testWidgets(
    'a pending navigation reaches its target without replacing the readable page',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(
        coordinator,
        targetPageWait: const Duration(seconds: 1),
        backgroundIdle: const Duration(seconds: 1),
      );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 2);
      await tester.pump();
      await tester.pump();
      expect(host.navigation.turnNext(), isTrue);
      await tester.pumpAndSettle();
      final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
      final pageElement = tester.element(pageFinder);
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(1, 0.001),
      );

      host.navigationRequest = _budgetNavigation(1, 2);
      await tester.pumpWidget(host.build());
      await tester.pump();
      expect(tester.element(pageFinder), same(pageElement));
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(1, 0.001),
      );
      expect(
        find.byKey(const Key('novel-reader-pagination-paused')),
        findsOneWidget,
      );

      coordinator.emit(0, pageCount: 3);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.element(pageFinder), same(pageElement));
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(2, 0.001),
      );
      expect(host.positions.last.pageIndex, 2);
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isFalse);
      expect(host.positions.last.isPageCountFinal, isFalse);
      expect(
        find.byKey(const Key('novel-reader-pagination-paused')),
        findsNothing,
      );
      expect(host.scrollChoices, 0);
      expect(coordinator.cancelPendingCount, 0);
    },
  );

  testWidgets(
    'a missing forward page keeps one target until it becomes readable',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
        ..preferences = NovelReaderPreferences.defaults().copyWith(
          pageEffect: NovelReaderPageEffect.staggered,
        );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 2);
      await tester.pump();
      await tester.pump();
      expect(host.navigation.turnNext(), isTrue);
      await tester.pumpAndSettle();
      final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
      final pageElement = tester.element(pageFinder);
      final pageController = tester.widget<PageView>(pageFinder).controller!;
      expect(pageController.page, closeTo(1, 0.001));

      expect(host.navigation.turnNext(), isTrue);
      expect(host.navigation.turnNext(), isFalse);
      await tester.pump();
      expect(pageController.page, closeTo(1, 0.001));
      coordinator.emit(0, pageCount: 2);
      await tester.pumpAndSettle();
      expect(pageController.page, closeTo(1, 0.001));
      expect(host.navigation.turnNext(), isFalse);

      coordinator.emit(0, pageCount: 3);
      await tester.pumpAndSettle();
      expect(tester.element(pageFinder), same(pageElement));
      expect(
        tester.widget<PageView>(pageFinder).controller,
        same(pageController),
      );
      expect(pageController.page, closeTo(2, 0.001));
      expect(host.positions.last.pageIndex, 2);
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isFalse);
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pumpAndSettle();
      expect(pageController.page, closeTo(2, 0.001));
      expect(coordinator.attempts, hasLength(1));
      expect(host.scrollChoices, 0);
    },
  );

  testWidgets(
    'a newly published page accepts a turn before the old view rebuilds',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 2);
      await tester.pump();
      await tester.pump();
      expect(host.navigation.turnNext(), isTrue);
      await tester.pumpAndSettle();
      final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
      final controller = tester.widget<PageView>(pageFinder).controller!;
      expect(controller.page, closeTo(1, 0.001));

      coordinator.emit(0, pageCount: 3, isComplete: true);
      // Deliver the stream result without rebuilding the still-two-page view.
      await tester.idle();
      expect(
        tester
            .widget<PageView>(pageFinder)
            .childrenDelegate
            .estimatedChildCount,
        2,
      );
      expect(host.navigation.turnNext(), isTrue);
      expect(host.navigation.turnNext(), isFalse);
      await tester.pumpAndSettle();
      expect(controller.page, closeTo(2, 0.001));
      expect(host.positions.last.pageIndex, 2);
      expect(host.chapterTurns, 0);
    },
  );
}

void _missingPageRetirementCases() {
  for (final cancellation in ['reverse', 'drag', 'navigation', 'seek']) {
    testWidgets(
      '$cancellation cancels a missing-page turn before late coverage',
      (tester) async {
        final coordinator = _BudgetPaginationCoordinator();
        final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        coordinator.emit(0, pageCount: 2);
        await tester.pump();
        await tester.pump();
        expect(host.navigation.turnNext(), isTrue);
        await tester.pumpAndSettle();
        expect(host.navigation.turnNext(), isTrue);
        final pageFinder = find.byKey(
          const Key('novel-reader-paged-page-view'),
        );
        switch (cancellation) {
          case 'reverse':
            expect(host.navigation.turnPrevious(), isTrue);
          case 'drag':
            await tester.drag(pageFinder, const Offset(600, 0));
          case 'navigation':
            host.navigationRequest = _budgetNavigation(10, 0);
            await tester.pumpWidget(host.build());
          case 'seek':
            host.pageSeekRequest = NovelReaderPageSeekRequest(
              requestId: 10,
              episodeId: _episode.episodeId,
              paginationKey: host.positions.last.paginationKey,
              pageIndex: 0,
            );
            await tester.pumpWidget(host.build());
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(pageFinder).controller!.page,
          closeTo(0, 0.001),
        );
        final reports = host.positions.length;
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(pageFinder).controller!.page,
          closeTo(0, 0.001),
        );
        expect(
          host.positions
              .skip(reports)
              .any((position) => position.pageIndex == 2),
          isFalse,
        );
        expect(coordinator.attempts, hasLength(1));
      },
    );
  }

  for (final retirement in ['retry', 'generation']) {
    testWidgets(
      '$retirement retires a missing-page turn with its old attempt',
      (tester) async {
        final coordinator = _BudgetPaginationCoordinator();
        final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        coordinator.emit(0, pageCount: 2);
        await tester.pump();
        await tester.pump();
        expect(host.navigation.turnNext(), isTrue);
        await tester.pumpAndSettle();
        expect(host.navigation.turnNext(), isTrue);
        final pageFinder = find.byKey(
          const Key('novel-reader-paged-page-view'),
        );
        if (retirement == 'retry') {
          coordinator.fail(0);
          await tester.pump();
          await tester.pump();
          await tester.tap(
            find.byKey(const Key('novel-reader-pagination-retry')),
          );
          await tester.pump();
        } else {
          final replacementCache = NovelReaderPaginationCache();
          addTearDown(replacementCache.dispose);
          host.paginationCache = replacementCache;
          await tester.pumpWidget(host.build());
          await tester.pump();
        }
        await tester.pump();
        expect(coordinator.attempts, hasLength(2));
        final reports = host.positions.length;
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pump();
        coordinator.emit(1, pageCount: 3, isComplete: true);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(pageFinder).controller!.page,
          closeTo(retirement == 'retry' ? 1 : 0, 0.001),
        );
        expect(
          host.positions
              .skip(reports)
              .any((position) => position.pageIndex == 2),
          isFalse,
        );
        expect(coordinator.cancelPendingCount, greaterThan(0));
        expect(host.scrollChoices, 0);
      },
    );
  }

  for (final retirement in ['failure', 'retry', 'generation']) {
    testWidgets(
      '$retirement stops a claimed missing-page animation before arrival',
      (tester) async {
        final coordinator = _BudgetPaginationCoordinator();
        final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        coordinator.emit(0, pageCount: 2);
        await tester.pump();
        await tester.pump();
        expect(host.navigation.turnNext(), isTrue);
        await tester.pumpAndSettle();
        expect(host.navigation.turnNext(), isTrue);
        coordinator.emit(0, pageCount: 3);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 8));
        final pageFinder = find.byKey(
          const Key('novel-reader-paged-page-view'),
        );
        final controller = tester.widget<PageView>(pageFinder).controller!;
        expect(controller.page, allOf(greaterThan(1), lessThan(1.5)));
        expect(host.positions.last.pageIndex, 1);
        final reports = host.positions.length;

        if (retirement == 'generation') {
          final replacementCache = NovelReaderPaginationCache();
          addTearDown(replacementCache.dispose);
          host.paginationCache = replacementCache;
          await tester.pumpWidget(host.build());
          await tester.pump();
        } else {
          coordinator.fail(0);
          await tester.pump();
          await tester.pump();
          expect(controller.page, closeTo(1, 0.001));
          if (retirement == 'retry') {
            await tester.tap(
              find.byKey(const Key('novel-reader-pagination-retry')),
            );
            await tester.pump();
          }
        }
        await tester.pump();
        if (retirement != 'failure') {
          expect(coordinator.attempts, hasLength(2));
          coordinator.emit(1, pageCount: 3, isComplete: true);
        }
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(pageFinder).controller!.page,
          closeTo(retirement == 'generation' ? 0 : 1, 0.001),
        );
        expect(
          host.positions
              .skip(reports)
              .any((position) => position.pageIndex == 2),
          isFalse,
        );
        expect(host.chapterTurns, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('an absent pending page at completion never turns the chapter', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
      ..allowChapterTurns = true;
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 2);
    await tester.pump();
    await tester.pump();
    expect(host.navigation.turnNext(), isTrue);
    await tester.pumpAndSettle();
    expect(host.navigation.turnNext(), isTrue);
    coordinator.emit(0, pageCount: 2, isComplete: true);
    await tester.pumpAndSettle();
    final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
    expect(
      tester.widget<PageView>(pageFinder).controller!.page,
      closeTo(1, 0.001),
    );
    expect(host.chapterTurns, 0);
    // A subsequent explicit turn still reaches the configured chapter handler.
    expect(host.navigation.turnNext(), isFalse);
    expect(host.chapterTurns, 1);
  });
}

void _disabledBudgetWaitCases() {
  testWidgets(
    'disabled budgets keep an active request waiting without changing modes',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      await tester.pump(const Duration(seconds: 10));
      expect(
        find.byKey(const Key('novel-reader-pagination-failure')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('novel-reader-paged-layout-loading')),
        findsOneWidget,
      );
      expect(coordinator.cancelPendingCount, 0);
      expect(host.scrollChoices, 0);
    },
  );
}
