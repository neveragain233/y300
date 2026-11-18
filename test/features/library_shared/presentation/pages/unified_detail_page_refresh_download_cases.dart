part of 'unified_detail_page_test.dart';

void _refreshDownloadCases() {
  testWidgets(
    'UnifiedDetailPage omits chapter progress badge when progress is null',
    (tester) async {
      final adapter = _FakeDetailAdapter();

      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-progress-e1'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('UnifiedDetailPage shows refresh queue snackbar', (tester) async {
    final adapter = _FakeDetailAdapter()
      ..refreshResult = DetailRefreshResult.queued(
        estimatedDuration: const Duration(milliseconds: 10500),
        queuePosition: 1,
      );
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('更新').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        AppLocalizationsZh().libraryDetailRefreshQueuedAtPosition(
          1,
          AppLocalizationsZh().libraryTaskDurationSeconds(11),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('UnifiedDetailPage shows refresh fallback snackbars', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter();
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('更新').first);
    await tester.pumpAndSettle();
    expect(find.text('已更新'), findsOneWidget);

    adapter.refreshResult = DetailRefreshResult.skipped;
    await tester.tap(find.text('更新').first);
    await tester.pumpAndSettle();
    expect(find.text('暂无可更新内容'), findsOneWidget);
  });

  testWidgets(
    'UnifiedDetailPage reloads when current work refresh signal arrives',
    (tester) async {
      final bus = LibraryShelfRefreshBus();
      addTearDown(bus.dispose);
      final adapter = _FakeDetailAdapter();
      var presentationCount = 0;
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            shelfRefreshBus: bus,
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
            onFirstContentPresented: (header, chapters) {
              presentationCount++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialLoadCount = adapter.loadChaptersCallCount;
      expect(presentationCount, 1);

      bus.notify(
        modules: const <LibraryModuleKey>{LibraryModuleKey.novel},
        reason: 'comic_search_refresh_completed',
        source: LibraryMutationSource.comicSearchQueue,
        workId: 'other-work',
      );
      await tester.pumpAndSettle();

      expect(adapter.loadChaptersCallCount, initialLoadCount);

      bus.notify(
        modules: const <LibraryModuleKey>{LibraryModuleKey.novel},
        reason: 'comic_search_refresh_completed',
        source: LibraryMutationSource.comicSearchQueue,
        workId: 'work-1',
      );
      await tester.pumpAndSettle();

      expect(adapter.loadChaptersCallCount, initialLoadCount + 1);
      expect(presentationCount, 1);
    },
  );

  testWidgets('UnifiedDetailPage shows error panel and retries initial load', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter()..failLoadHeaderOnce = true;
    var presentationCount = 0;
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          onFirstContentPresented: (header, chapters) {
            presentationCount++;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-detail-error-panel')), findsOneWidget);
    expect(find.byKey(const Key('unified-detail-error-retry')), findsOneWidget);
    final l10n = AppLocalizationsZh();
    expect(
      find.text(
        l10n.libraryDetailLoadFailed(
          LibraryDetailTextResolver.safeError(
            l10n,
            StateError('header failed'),
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(presentationCount, 0);

    await tester.ensureVisible(
      find.byKey(const Key('unified-detail-error-retry')),
    );
    await tester.tap(find.byKey(const Key('unified-detail-error-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-detail-error-panel')), findsNothing);
    expect(find.text('测试作品'), findsWidgets);
    expect(presentationCount, 1);
  });

  testWidgets('UnifiedDetailPage isolates first content callback failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: _FakeDetailAdapter(),
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          onFirstContentPresented: (header, chapters) {
            throw StateError('history unavailable');
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('测试作品'), findsWidgets);
    expect(find.byKey(const Key('unified-detail-error-panel')), findsNothing);
  });

  testWidgets('each UnifiedDetailPage route presents the same work once', (
    tester,
  ) async {
    var presentationCount = 0;

    await tester.pumpWidget(
      _scopedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-detail-route'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UnifiedDetailPage(
                        adapter: _FakeDetailAdapter(),
                        workId: 'work-1',
                        onOpenReader: (context, target) async {},
                        onOpenThread: (context, target) async {},
                        onFirstContentPresented: (header, chapters) {
                          presentationCount++;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-detail-route')));
    await tester.pumpAndSettle();
    expect(presentationCount, 1);

    Navigator.of(tester.element(find.text('测试作品').first)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-detail-route')));
    await tester.pumpAndSettle();

    expect(presentationCount, 2);
  });

  testWidgets('source tag can be confirmed as catalog and refreshes chapters', (
    tester,
  ) async {
    final adapter = _SourceTagCatalogAdapter();
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-detail-source-tags')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('unified-detail-source-tag-86')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('unified-detail-source-tag-catalog-86')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('unified-detail-source-tag-catalog-confirm')),
    );
    await tester.pumpAndSettle();

    expect(adapter.lastCatalogUrl, contains('misc.php'));
    expect(adapter.lastCatalogUrl, contains('id=86'));
    expect(adapter.refreshWorkCallCount, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'UnifiedDetailPage keeps existing content when chapter reload fails',
    (tester) async {
      final adapter = _FakeDetailAdapter();
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();

      adapter.failLoadChaptersOnce = true;
      await tester.longPress(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-bookmark-action-e1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('unified-detail-error-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        findsOneWidget,
      );

      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('unified-detail-error-retry'))),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unified-detail-error-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unified-detail-error-panel')), findsNothing);
    },
  );

  testWidgets(
    'UnifiedDetailPage reports chapter download failures without stale spinner',
    (tester) async {
      final adapter = _FakeDetailAdapter()..failMarkDownload = true;
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('缓存该章节'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('缓存该章节'));
      await tester.pumpAndSettle();

      expect(find.textContaining('缓存失败'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-downloaded-badge-e1'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'UnifiedDetailPage manages chapter visibility one chapter at a time',
    (tester) async {
      final adapter = _ManageableDetailAdapter();
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('显示或隐藏章节，手动添加或移除章节'), findsNothing);
      await tester.tap(find.byKey(const Key('unified-detail-manage-chapters')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('unified-detail-chapter-management-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'unified-detail-chapter-management-visibility-e1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      // 单章操作只隐藏目标章节，其他可见章节保持不变。
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e2')),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unified-detail-manage-chapters')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'unified-detail-chapter-management-visibility-e1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UnifiedDetailPage reports delete download failures and keeps download state',
    (tester) async {
      final adapter = _FakeDetailAdapter(isDownloaded: true)
        ..failDeleteDownload = true;
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('已缓存，点击删除缓存'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('已缓存，点击删除缓存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('删除缓存失败'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-downloaded-badge-e1'),
        ),
        findsNothing,
      );
      expect(find.text('已缓存'), findsNothing);
      expect(find.byTooltip('已缓存，点击删除缓存'), findsOneWidget);
    },
  );
}
