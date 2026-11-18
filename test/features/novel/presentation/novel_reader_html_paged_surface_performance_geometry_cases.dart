part of 'novel_reader_html_paged_surface_performance_test.dart';

void _pagedGeometryCases() {
  for (final mode in [
    NovelReaderFlowMode.pagedLtr,
    NovelReaderFlowMode.pagedRtl,
  ]) {
    for (final effect in [
      NovelReaderPageEffect.fade,
      NovelReaderPageEffect.cover,
    ]) {
      testWidgets('$effect turns pages without an in-page indicator in $mode', (
        tester,
      ) async {
        final coordinator = _BudgetPaginationCoordinator();
        final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
          ..preferences = NovelReaderPreferences.defaults().copyWith(
            flowMode: mode,
            pageEffect: effect,
          );
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pumpAndSettle();
        final finder = find.byKey(const Key('novel-reader-paged-page-view'));
        final controller = tester.widget<PageView>(finder).controller!;
        controller.jumpTo(controller.position.viewportDimension * .25);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('novel-reader-paged-page-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('novel-reader-paged-page-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('novel-reader-page-indicator')),
          findsNothing,
        );
        controller.jumpToPage(1);
        await tester.pumpAndSettle();
        expect(controller.page, 1);
        expect(host.positions.last.pageIndex, 1);
        expect(host.positions.last.hasUserNavigated, isFalse);
        expect(host.navigation.turnPrevious(), isTrue);
        await tester.pumpAndSettle();
        expect(controller.page, 0);
        expect(host.positions.last.pageIndex, 0);
        expect(host.positions.last.hasUserNavigated, isTrue);
        expect(coordinator.attempts, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final mode in [
    NovelReaderFlowMode.pagedLtr,
    NovelReaderFlowMode.pagedRtl,
  ]) {
    testWidgets('page motion settings retain layout and navigation in $mode', (
      tester,
    ) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
        ..preferences = NovelReaderPreferences.defaults().copyWith(
          flowMode: mode,
        );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pumpAndSettle();
      final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
      final element = tester.element(pageFinder);
      for (final effect in NovelReaderPageEffect.values) {
        host.preferences = host.preferences.copyWith(
          pageEffect: effect,
          pageSpeed: NovelReaderPageSpeed.brisk,
        );
        await _pumpBudgetHost(tester, host);
        expect(tester.element(pageFinder), same(element));
        expect(coordinator.attempts, hasLength(1));
        expect(host.navigation.turnNext(), isTrue);
        await tester.pumpAndSettle();
        expect(host.positions.last.pageIndex, 1);
        expect(host.positions.last.hasUserNavigated, isTrue);
        expect(host.navigation.turnPrevious(), isTrue);
        await tester.pumpAndSettle();
        expect(host.positions.last.pageIndex, 0);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'padding changes invalidate measured layout and rendered insets together',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pumpAndSettle();
      final original = coordinator.attempts.single.key;
      host.preferences = host.preferences.copyWith(pagePadding: 24);
      await _pumpBudgetHost(tester, host);
      expect(coordinator.attempts, hasLength(2));
      final changed = coordinator.attempts.last.key;
      expect(changed.layoutFingerprint, isNot(original.layoutFingerprint));
      expect(changed.viewportHeightPx, original.viewportHeightPx - 32);
      coordinator.emit(1, pageCount: 3, isComplete: true);
      await tester.pumpAndSettle();
      final padding = tester.widget<Padding>(
        find.byKey(const Key('novel-reader-paged-surface')),
      );
      expect(padding.padding.resolve(TextDirection.ltr).left, 24);
      expect(host.positions.last.paginationKey, changed.layoutFingerprint);
    },
  );
}

void _innerPageGeometryCases() {
  testWidgets('page movement reports actual activity until animation settles', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator();
    final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 2, isComplete: true);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    host.scrollActivity.clear();
    expect(host.navigation.turnNext(), isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    expect(host.scrollActivity, [true]);
    await tester.pumpAndSettle();
    expect(host.scrollActivity, [true, false]);
  });

  testWidgets('inner page requires its actual tail and a real reading scroll', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator()
      ..pageHtml = {0: '<div style="height: 1400px">内部长页正文</div>'}
      ..innerScrollPages = {0};
    final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
      ..rawHtml = coordinator.pageHtml.values.join();
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 1, isComplete: true);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(host.positions.last.isBodyEndVisible, isFalse);
    expect(host.positions.last.isWholeBodyVisible, isFalse);
    expect(host.positions.last.hasUserNavigated, isFalse);
    host.scrollActivity.clear();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1300),
    );
    await tester.pumpAndSettle();
    expect(host.positions.last.isBodyEndVisible, isTrue);
    expect(host.positions.last.isWholeBodyVisible, isFalse);
    expect(host.positions.last.hasUserNavigated, isTrue);
    expect(host.scrollActivity.first, isTrue);
    expect(host.scrollActivity.last, isFalse);
  });

  testWidgets(
    'inner metrics and programmatic compensation do not confirm navigation',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator()
        ..pageHtml = {0: '<div style="height: 1400px">自动定位的长页正文</div>'}
        ..innerScrollPages = {0};
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
        ..rawHtml = coordinator.pageHtml.values.join();
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 1, isComplete: true);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      final innerScrollable = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(innerScrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(host.positions.last.isBodyEndVisible, isTrue);
      expect(host.positions.last.isWholeBodyVisible, isFalse);
      expect(
        host.positions.every((position) => !position.hasUserNavigated),
        isTrue,
      );
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(host.positions.last.isBodyEndVisible, isFalse);
      expect(
        host.positions.every((position) => !position.hasUserNavigated),
        isTrue,
      );
    },
  );

  testWidgets('inner page with fully fitting body reports whole visibility', (
    tester,
  ) async {
    final coordinator = _BudgetPaginationCoordinator()
      ..pageHtml = {0: '<p>实际可见的单页正文</p>'}
      ..innerScrollPages = {0};
    final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false)
      ..rawHtml = coordinator.pageHtml.values.join();
    _disposeBudgetHost(tester, coordinator);
    await _pumpBudgetHost(tester, host);
    coordinator.emit(0, pageCount: 1, isComplete: true);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(host.positions.last.isBodyEndVisible, isTrue);
    expect(host.positions.last.isWholeBodyVisible, isTrue);
    expect(host.positions.last.hasUserNavigated, isFalse);
  });
}

void _layoutRebindCases() {
  testWidgets('remounting the paged surface hits the reader session plan', (
    tester,
  ) async {
    final owner = NovelReaderPaginationSessionCache();
    final diagnostics = _RecordingDiagnosticsSink();
    final host =
        _BudgetSurfaceHost(
            _BudgetPaginationCoordinator(),
            enforceBudgets: false,
          )
          ..useDefaultCoordinator = true
          ..paginationCache = owner.paginationCache
          ..measureCache = owner.measureCache
          ..boundaryCache = owner.boundaryCache
          ..preparedCache = owner.preparedChapterCache
          ..diagnosticsSink = diagnostics;
    addTearDown(owner.dispose);
    await tester.pumpWidget(host.build());
    for (
      var frame = 0;
      frame < 120 && owner.paginationCache.length == 0;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    final cold = diagnostics.records.lastWhere((entry) => entry.isComplete);
    expect(cold.cacheHit, isFalse);
    expect(
      owner.paginationCache.length,
      1,
      reason: 'closed=${owner.isClosed}, ${diagnostics.records}',
    );
    expect(owner.preparedChapterCache.length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(owner.isClosed, isFalse);
    diagnostics.records.clear();
    await tester.pumpWidget(host.build());
    await tester.pumpAndSettle();
    final warm = diagnostics.records.lastWhere((entry) => entry.isComplete);
    expect(warm.cacheHit, isTrue);
    expect(warm.paginationKey, cold.paginationKey);
    expect(warm.pageCount, cold.pageCount);
    expect(
      find.byKey(const Key('novel-reader-paged-page-view')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final cacheKind in ['plan', 'measure', 'boundary']) {
    testWidgets('same layout rebinds a replaced $cacheKind cache', (
      tester,
    ) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      final originalKey = coordinator.attempts.single.key;
      final originalCache = NovelReaderPaginationCache();
      final originalMeasureCache = NovelReaderPaginationMeasureCache();
      final originalBoundaryCache = NovelReaderComplexHtmlBoundaryCache();
      switch (cacheKind) {
        case 'plan':
          host.paginationCache = originalCache;
        case 'measure':
          host.measureCache = originalMeasureCache;
        case 'boundary':
          host.boundaryCache = originalBoundaryCache;
      }
      await tester.pumpWidget(host.build());
      await tester.pump();
      await tester.pump();
      expect(coordinator.attempts, hasLength(2));
      expect(coordinator.attempts.last.key, originalKey);
      expect(coordinator.cancelPendingCount, greaterThan(0));
      coordinator.emit(0, pageCount: 3, isComplete: true);
      coordinator.fail(0);
      coordinator.emit(1, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-pagination-failure')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(originalCache.isClosed, isFalse);
      expect(originalMeasureCache.isClosed, isFalse);
      expect(originalBoundaryCache.isClosed, isFalse);
      expect(tester.takeException(), isNull);
      originalCache.dispose();
      originalMeasureCache.dispose();
      originalBoundaryCache.dispose();
    });
  }
}

void _paginationGeometryInsetsCases() {
  testWidgets('paged surface uses safe insets in its pagination geometry', (
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
    final coordinator = _CompleteRecordingPaginationCoordinator();

    Widget buildSurface(ReaderChromeInsets insets) {
      return LocalizedTestApp(
        theme: theme,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 24, bottom: 30),
            ),
            child: NovelReaderHtmlPagedSurface(
              rawHtml: '<p>安全区分页几何</p>',
              episode: _episode,
              preferences: preferences,
              typography: const NovelReaderTypographyResolver().resolve(
                preferences: preferences,
                theme: theme,
                palette: palette,
              ),
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
              chromeInsets: insets,
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
      );
    }

    await tester.pumpWidget(
      buildSurface(
        const ReaderChromeInsets(safeAreaTop: 24, safeAreaBottom: 30),
      ),
    );
    await tester.pumpAndSettle();
    final safeKey = coordinator.lastKey;

    await tester.pumpWidget(buildSurface(const ReaderChromeInsets.zero()));
    await tester.pumpAndSettle();
    final normalKey = coordinator.lastKey;

    expect(safeKey, isNotNull);
    expect(normalKey, isNotNull);
    expect(safeKey!.topChromeInsetPx, 24);
    expect(safeKey.bottomChromeInsetPx, 30);
    expect(normalKey!.topChromeInsetPx, 0);
    expect(normalKey.bottomChromeInsetPx, 0);
    expect(safeKey.viewportHeightPx, lessThan(normalKey.viewportHeightPx));
  });
}

void _layoutInputRebindCases() {
  for (final value in ['body', 'align', 'direction']) {
    testWidgets(
      'actual $value layout changes rebind the coordinator under a new key',
      (tester) async {
        final coordinator = _BudgetPaginationCoordinator();
        final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pump();
        await tester.pump();
        final originalKey = coordinator.attempts.single.key;
        final originalBuildCount = host.coordinatorBuildCount;
        if (value == 'direction') {
          host.direction = TextDirection.rtl;
        } else {
          final typography = host.typography;
          host.typography = NovelReaderTypography(
            body: value == 'body'
                ? typography.body.copyWith(fontSize: 24.5, letterSpacing: 1.5)
                : typography.body,
            chapterTitle: typography.chapterTitle,
            quote: typography.quote,
            link: typography.link,
            textAlign: value == 'align'
                ? TextAlign.center
                : typography.textAlign,
            paragraphIndent: typography.paragraphIndent,
            contentMaxWidth: typography.contentMaxWidth,
          );
        }
        await tester.pumpWidget(host.build());
        await tester.pump();
        await tester.pump();
        expect(coordinator.attempts, hasLength(2));
        final newKey = coordinator.attempts.last.key;
        expect(newKey, isNot(originalKey));
        expect(newKey.layoutFingerprint, isNot(originalKey.layoutFingerprint));
        expect(host.coordinatorBuildCount, originalBuildCount + 1);
        expect(coordinator.cancelPendingCount, greaterThan(0));
        coordinator.emit(0, pageCount: 3, isComplete: true);
        coordinator.emit(1, pageCount: 3, isComplete: true);
        await tester.pump();
        await tester.pump();
        expect(host.positions.last.paginationKey, newKey.layoutFingerprint);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
