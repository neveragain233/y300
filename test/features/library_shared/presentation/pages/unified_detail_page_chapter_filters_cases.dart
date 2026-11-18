part of 'unified_detail_page_test.dart';

void _chapterFiltersCases() {
  testWidgets('UnifiedDetailPage header seam bridge does not block actions', (
    tester,
  ) async {
    final adapter =
        _FakeDetailAdapter(coverLocalPath: 'missing-y300-detail-cover.png')
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

    expect(
      find.byKey(const Key('unified-detail-header-seam-bridge')),
      findsOneWidget,
    );
    await tester.tap(find.text('更新').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('已加入更新队列'), findsOneWidget);
  });

  testWidgets('UnifiedDetailPage renders comic progress beside source id', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(
      module: LibraryModuleKey.comic,
      progressInfo: const LibraryChapterProgressInfo(
        kind: LibraryChapterProgressKind.currentPage,
        isCurrent: true,
        currentPage: 3,
        totalPages: 12,
        fraction: 0.3,
      ),
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-inline-progress-e1'),
      ),
      findsOneWidget,
    );
    final progressLine = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('unified-detail-chapter-inline-progress-e1'),
        ),
        matching: find.byType(RichText),
      ),
    );
    final progressText = progressLine.text.toPlainText();
    expect(progressText, contains('  ·  第 3 页'));
    expect(progressText, isNot(contains('共 12 页')));
    final progressSemantics = tester.getSemantics(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-inline-progress-e1'),
      ),
    );
    expect(progressSemantics.label, contains('第 3 页'));
    expect(progressSemantics.label, isNot(contains('共 12 页')));
    expect(
      find.byKey(const ValueKey<String>('unified-detail-chapter-progress-e1')),
      findsNothing,
    );
  });

  testWidgets('UnifiedDetailPage renders novel last-read marker inline', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(
      progressInfo: const LibraryChapterProgressInfo(
        kind: LibraryChapterProgressKind.lastRead,
        isCurrent: true,
        fraction: 0.42,
      ),
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const ValueKey<String>('unified-detail-chapter-progress-e1')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-inline-progress-e1'),
      ),
      findsOneWidget,
    );
    final progressLine = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('unified-detail-chapter-inline-progress-e1'),
        ),
        matching: find.byType(RichText),
      ),
    );
    expect(progressLine.text.toPlainText(), contains('  ·  上次阅读'));
  });

  testWidgets(
    'UnifiedDetailPage renders chapter indicators without status text',
    (tester) async {
      final adapter = _FakeDetailAdapter(
        module: LibraryModuleKey.comic,
        progressInfo: const LibraryChapterProgressInfo(
          kind: LibraryChapterProgressKind.currentPage,
          isCurrent: true,
          currentPage: 3,
          fraction: 0.42,
        ),
        isBookmarked: true,
        isDownloaded: true,
        isRead: true,
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-inline-progress-e1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'unified-detail-chapter-bookmark-indicator-e1',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-downloaded-badge-e1'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-read-badge-e1'),
        ),
        findsNothing,
      );
      expect(find.text('书签'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('unified-detail-chapter-bookmark-button-e1'),
        ),
        findsNothing,
      );
      expect(find.text('已缓存'), findsNothing);
      expect(find.byTooltip('已缓存，点击删除缓存'), findsOneWidget);
      expect(find.text('已读'), findsNothing);
    },
  );

  testWidgets(
    'UnifiedDetailPage AppBar filter opens sheet and filters unread',
    (tester) async {
      final adapter = _FakeDetailAdapter(
        secondIsRead: true,
        secondIsDownloaded: true,
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
      await tester.scrollUntilVisible(
        find.byKey(const Key('unified-detail-chapter-toolbar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(const Key('unified-detail-chapter-toolbar')),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsZh().libraryChapterCount(2)),
        findsOneWidget,
      );
      expect(find.text('全部章节'), findsNothing);

      await tester.tap(find.byKey(const Key('unified-detail-appbar-filter')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('unified-detail-chapter-filter-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-filter-downloaded')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-filter-unread')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-filter-bookmarked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-sort-source')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-sort-direction')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('unified-detail-filter-unread')));
      await tester.ensureVisible(
        find.byKey(const Key('unified-detail-apply-filter-sort')),
      );
      await tester.tap(
        find.byKey(const Key('unified-detail-apply-filter-sort')),
      );
      await tester.pumpAndSettle();

      expect(find.text('未读'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e2')),
        findsNothing,
      );
      expect(adapter.lastFilters.unread, TriStateFilterValue.include);

      await tester.drag(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
        findsNothing,
      );
    },
  );

  testWidgets('UnifiedDetailPage chapter filter keeps bookmark semantics', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(secondIsBookmarked: true);

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
      find.byKey(const Key('unified-detail-chapter-toolbar')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('unified-detail-appbar-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-detail-filter-bookmarked')));
    await tester.ensureVisible(
      find.byKey(const Key('unified-detail-apply-filter-sort')),
    );
    await tester.tap(find.byKey(const Key('unified-detail-apply-filter-sort')));
    await tester.pumpAndSettle();

    expect(find.text('已加书签'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e2')),
      findsOneWidget,
    );
    expect(adapter.lastFilters.bookmarked, TriStateFilterValue.include);
  });

  testWidgets('UnifiedDetailPage chapter toolbar omits duplicate actions', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(includeSecondChapter: true);

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
      find.byKey(const Key('unified-detail-chapter-toolbar')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final toolbar = find.byKey(const Key('unified-detail-chapter-toolbar'));
    expect(
      find.text(AppLocalizationsZh().libraryChapterCount(2)),
      findsOneWidget,
    );
    expect(find.text('全部章节'), findsNothing);
    expect(
      find.descendant(of: toolbar, matching: find.byIcon(Icons.filter_list)),
      findsNothing,
    );
    expect(
      find.descendant(of: toolbar, matching: find.byIcon(Icons.arrow_upward)),
      findsNothing,
    );
    expect(
      find.descendant(of: toolbar, matching: find.byIcon(Icons.file_download)),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-appbar-download')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-appbar-filter')),
      findsOneWidget,
    );
  });

  testWidgets(
    'UnifiedDetailPage chapter filter sheet only exposes source sorting',
    (tester) async {
      final adapter = _FakeDetailAdapter(includeSecondChapter: true);

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
        find.byKey(const Key('unified-detail-chapter-toolbar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byKey(const Key('unified-detail-appbar-filter')));
      await tester.pumpAndSettle();

      expect(find.text('按来源'), findsOneWidget);
      expect(find.text('按章节编号'), findsNothing);
      expect(find.text('按日期'), findsNothing);
      expect(find.text('按名称'), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is DropdownButtonFormField),
        findsNothing,
      );
      expect(find.byType(SegmentedButton<LibrarySortDirection>), findsNothing);

      final sourceSort = find.byKey(const Key('unified-detail-sort-source'));
      expect(
        find.descendant(
          of: sourceSort,
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
      );
      await tester.tap(sourceSort);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: sourceSort,
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('unified-detail-apply-filter-sort')),
      );
      await tester.tap(
        find.byKey(const Key('unified-detail-apply-filter-sort')),
      );
      await tester.pumpAndSettle();

      expect(adapter.lastSortOption.direction, LibrarySortDirection.desc);

      final chapterTiles = tester
          .widgetList<Material>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Material &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'unified-detail-chapter-',
                  ),
            ),
          )
          .toList();
      expect(
        (chapterTiles.first.key! as ValueKey<String>).value,
        'unified-detail-chapter-e2',
      );
    },
  );
}
