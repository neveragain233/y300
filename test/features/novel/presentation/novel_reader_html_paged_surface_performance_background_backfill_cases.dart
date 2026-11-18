part of 'novel_reader_html_paged_surface_performance_test.dart';

void _backgroundBackfillCases() {
  for (final stop in ['timeout', 'error']) {
    testWidgets('background $stop retains the visible page through retry', (
      tester,
    ) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(
        coordinator,
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
      final reports = host.positions.length;
      if (stop == 'timeout') {
        await tester.pump(const Duration(milliseconds: 1100));
      } else {
        coordinator.fail(0);
      }
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-pagination-paused')),
        findsOneWidget,
      );
      expect(tester.element(pageFinder), same(pageElement));
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(1, 0.001),
      );
      expect(host.positions, hasLength(reports));
      expect(host.scrollChoices, 0);
      await tester.tap(find.byKey(const Key('novel-reader-pagination-retry')));
      await tester.pump();
      expect(coordinator.attempts, hasLength(2));
      expect(tester.element(pageFinder), same(pageElement));
      coordinator.emit(1, pageCount: 1);
      await tester.pump();
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(1, 0.001),
      );
      coordinator.emit(1, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-pagination-paused')),
        findsNothing,
      );
      expect(tester.element(pageFinder), same(pageElement));
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(1, 0.001),
      );
      expect(host.positions.last.pageIndex, 1);
      expect(coordinator.clearCount, 0);
      expect(host.scrollChoices, 0);
    });
  }

  testWidgets('background idle resets only when another stable page arrives', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(
      coordinator,
      backgroundIdle: const Duration(milliseconds: 50),
    );
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    coordinator.emit(0, pageCount: 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      find.byKey(const Key('novel-reader-pagination-paused')),
      findsNothing,
    );
    coordinator.emit(0, pageCount: 2, measurementCount: 123);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-pagination-paused')),
      findsOneWidget,
    );
    expect(host.scrollChoices, 0);
  });

  testWidgets('active retry replay can exceed the background idle duration', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(
      coordinator,
      backgroundIdle: const Duration(milliseconds: 50),
    );
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 3);
    await tester.pump();
    await tester.pump();
    final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
    final pageElement = tester.element(pageFinder);
    coordinator.fail(0);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('novel-reader-pagination-retry')));
    await tester.pump();
    for (var pageCount = 1; pageCount <= 3; pageCount++) {
      await tester.pump(const Duration(milliseconds: 30));
      coordinator.emit(1, pageCount: pageCount, isComplete: pageCount == 3);
      await tester.pump();
      await tester.pump();
      expect(tester.element(pageFinder), same(pageElement));
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(0, 0.001),
      );
      expect(
        find.byKey(const Key('novel-reader-pagination-paused')),
        findsNothing,
      );
    }
    expect(coordinator.attempts, hasLength(2));
    expect(coordinator.cancelPendingCount, 2);
    expect(host.positions.last.isPageCountFinal, isTrue);
    expect(host.scrollChoices, 0);
  });

  testWidgets('retry cannot replace a readable prefix with different HTML', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator);
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 2);
    await tester.pump();
    await tester.pump();
    final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
    final pageElement = tester.element(pageFinder);
    coordinator.fail(0);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('novel-reader-pagination-retry')));
    await tester.pump();
    coordinator.emit(1, pageCount: 3, isComplete: true, replaceFirstHtml: true);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-pagination-paused')),
      findsOneWidget,
    );
    expect(tester.element(pageFinder), same(pageElement));
    expect(find.text('被替换的正文', findRichText: true), findsNothing);
    expect(host.scrollChoices, 0);
  });
}
