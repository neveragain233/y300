part of 'novel_reader_html_paged_surface_performance_test.dart';

void _claimedTurnRestoreCases() {
  testWidgets(
    'a claimed turn takes precedence over late legacy percentage restoration',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
      host.snapshot = host.snapshot.copyWith(
        progressPercent: 0.8,
        pageCount: 3,
        anchorNodeId: 'paragraph-0',
      );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 1);
      await tester.pump();
      await tester.pump();
      expect(host.positions.last.pageIndex, 0);
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isTrue);
      expect(host.navigation.turnNext(), isTrue);
      await tester.pump();
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isTrue);

      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(host.positions.last.pageIndex, 0);
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isTrue);
      await tester.pumpAndSettle();
      final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
      expect(
        tester.widget<PageView>(pageFinder).controller!.page,
        closeTo(1, 0.001),
      );
      expect(host.positions.last.pageIndex, 1);
      expect(host.positions.last.isReadOnlyCompatibilityRestore, isFalse);
      expect(
        host.positions.any((position) => position.pageIndex == 2),
        isFalse,
      );
      expect(coordinator.attempts, hasLength(1));
    },
  );
}

void _restoreAnchorCases() {
  testWidgets(
    'incremental restore waits for the saved anchor before reporting progress',
    (tester) async {
      final preferences = NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      );
      final theme = ThemeData.light();
      final palette = const NovelReaderThemeResolver().resolve(
        preferences: preferences,
        theme: theme,
      );
      final typography = const NovelReaderTypographyResolver().resolve(
        preferences: preferences,
        theme: theme,
        palette: palette,
      );
      final htmlTheme = const NovelForumHtmlRenderThemeFactory().fromPalette(
        palette,
      );
      final coordinator = _ControlledRestorePaginationCoordinator();
      final positions = <NovelReaderPaginationPosition>[];
      final diagnostics = _RecordingDiagnosticsSink();

      await tester.pumpWidget(
        LocalizedTestApp(
          theme: theme,
          home: Scaffold(
            body: NovelReaderHtmlPagedSurface(
              rawHtml: '<p>第一页</p><p>恢复目标页</p>',
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
                pageIndex: 1,
                anchorNodeId: 'paragraph-1',
                progressPercent: 0.5,
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
              diagnosticsSink: diagnostics,
              onPositionChanged: (position) {
                positions.add(position);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('novel-reader-paged-restoring-position')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('novel-reader-paged-page-view')),
        findsNothing,
      );
      expect(positions, isEmpty);
      expect(diagnostics.records, isEmpty);

      coordinator.emitTargetPage();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('novel-reader-paged-restoring-position')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('novel-reader-paged-page-view')),
        findsOneWidget,
      );
      expect(positions.map((position) => position.pageIndex), <int>[1]);
      expect(positions.single.isReadOnlyCompatibilityRestore, isTrue);
      final firstFrame = diagnostics.records.single;
      expect(firstFrame.isComplete, isFalse);
      expect(firstFrame.firstPublishedPageDuration, isNotNull);
      expect(
        firstFrame.targetPageAvailableDuration,
        greaterThan(firstFrame.firstPublishedPageDuration!),
      );
      expect(
        firstFrame.firstVisibleFrameDuration,
        greaterThanOrEqualTo(firstFrame.targetPageAvailableDuration),
      );

      coordinator.emitComplete();
      await tester.pump();
      await tester.pump();
      expect(diagnostics.records.map((record) => record.isComplete), <bool>[
        false,
        true,
      ]);
      expect(
        diagnostics.records.last.firstVisibleFrameDuration,
        firstFrame.firstVisibleFrameDuration,
      );
      expect(
        diagnostics.records.last.firstPublishedPageDuration,
        firstFrame.firstPublishedPageDuration,
      );
      expect(
        positions.every((position) => position.isReadOnlyCompatibilityRestore),
        isTrue,
      );
    },
  );

  for (final interaction in ['tap', 'drag', 'seek']) {
    testWidgets(
      'legacy background restore stays read-only until a real $interaction',
      (tester) async {
        final coordinator = _ControlledRestorePaginationCoordinator(
          finalPageCount: 3,
        );
        final navigation = NovelReaderPagedNavigationController();
        NovelReaderPageSeekRequest? seekRequest;
        final positions = <NovelReaderPaginationPosition>[];
        final preferences = NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        );
        final theme = ThemeData.light();
        final palette = const NovelReaderThemeResolver().resolve(
          preferences: preferences,
          theme: theme,
        );
        final typography = const NovelReaderTypographyResolver().resolve(
          preferences: preferences,
          theme: theme,
          palette: palette,
        );
        Widget host() => LocalizedTestApp(
          theme: theme,
          home: Scaffold(
            body: NovelReaderHtmlPagedSurface(
              rawHtml: '<p>第一页</p><p>恢复目标页</p><p>尾页</p>',
              episode: _episode,
              preferences: preferences,
              typography: typography,
              theme: const NovelForumHtmlRenderThemeFactory().fromPalette(
                palette,
              ),
              imageReferer: 'https://bbs.yamibo.com/',
              progressSnapshot: const NovelReaderProgressSnapshot(
                novelId: 'performance-novel',
                episodeId: 'performance-episode',
                flowMode: NovelReaderFlowMode.pagedLtr,
                scrollOffset: 0,
                pageIndex: 0,
                anchorNodeId: 'paragraph-0',
                anchorTextOffset: 777,
                progressPercent: 0.8,
              ),
              navigationController: navigation,
              pageSeekRequest: seekRequest,
              coordinatorBuilder: ({
                required BuildContext context,
                required ForumHtmlThemeContext theme,
                required ForumHtmlReaderPreferences preferences,
                required String sourceId,
                required String? threadId,
                required String? imageCacheOwnerId,
                required String? imageReferer,
              }) => coordinator,
              onPositionChanged: positions.add,
            ),
          ),
        );
        await tester.pumpWidget(host());
        await tester.pump();
        await tester.pump();
        expect(positions.last.pageIndex, 0);
        expect(positions.last.isReadOnlyCompatibilityRestore, isTrue);
        coordinator.emitComplete();
        await tester.pump();
        await tester.pump();
        // Completion moves the visible page by the old percentage rule. That
        // programmatic jump must not masquerade as reader confirmation.
        expect(positions.last.pageIndex, 1);
        expect(
          positions.every(
            (position) => position.isReadOnlyCompatibilityRestore,
          ),
          isTrue,
        );
        if (interaction == 'tap') {
          expect(navigation.turnNext(), isTrue);
        } else if (interaction == 'seek') {
          seekRequest = NovelReaderPageSeekRequest(
            requestId: 1,
            episodeId: _episode.episodeId,
            paginationKey: positions.last.paginationKey,
            pageIndex: 1,
          );
          await tester.pumpWidget(host());
        } else {
          await tester.drag(
            find.byKey(const Key('novel-reader-paged-page-view')),
            const Offset(-600, 0),
          );
        }
        await tester.pumpAndSettle();
        expect(positions.last.pageIndex, interaction == 'seek' ? 1 : 2);
        expect(positions.last.isReadOnlyCompatibilityRestore, isFalse);
        expect(positions.last.anchor.formatVersion, 1);
      },
    );
  }
}
