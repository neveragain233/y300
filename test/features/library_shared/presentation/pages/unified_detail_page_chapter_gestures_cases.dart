part of 'unified_detail_page_test.dart';

void _chapterGesturesCases() {
  testWidgets('UnifiedDetailPage toggles chapter bookmark from long press', (
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.offline_pin_outlined), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-bookmark-indicator-e1'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-bookmark-button-e1'),
      ),
      findsNothing,
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-bookmark-action-e1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(adapter.isBookmarked, isTrue);
    expect(adapter.lastBookmarkEpisodeId, 'e1');
    expect(adapter.loadChaptersCallCount, greaterThanOrEqualTo(2));
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-bookmark-indicator-e1'),
      ),
      findsOneWidget,
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('移除书签'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-bookmark-action-e1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(adapter.isBookmarked, isFalse);
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-bookmark-indicator-e1'),
      ),
      findsNothing,
    );
  });

  testWidgets('UnifiedDetailPage toggles unread chapter read by right swipe', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(module: LibraryModuleKey.comic);

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

    await tester.drag(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(adapter.markReadCallCount, 1);
    expect(adapter.isRead, isTrue);
    expect(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      findsOneWidget,
    );
  });

  testWidgets('UnifiedDetailPage resets read chapter by right swipe', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(
      module: LibraryModuleKey.comic,
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

    await tester.drag(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(adapter.lastResetEpisodeId, 'e1');
    expect(adapter.isRead, isFalse);
  });

  testWidgets('UnifiedDetailPage caps chapter swipe at one third width', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(module: LibraryModuleKey.comic);
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
    final chapter = find.byKey(
      const ValueKey<String>('unified-detail-chapter-e1'),
    );
    await tester.scrollUntilVisible(
      chapter,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final gesture = await tester.startGesture(tester.getCenter(chapter));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump();

    final foreground = tester.widget<FractionalTranslation>(
      find.byKey(
        const ValueKey<String>(
          'unified-detail-chapter-read-swipe-foreground-e1',
        ),
      ),
    );
    expect(foreground.translation.dx, closeTo(1 / 3, 0.001));
    expect(adapter.markReadCallCount, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(adapter.markReadCallCount, 1);
  });

  testWidgets('UnifiedDetailPage keeps physical right swipe in RTL', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(module: LibraryModuleKey.comic);
    await tester.pumpWidget(
      _scopedApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chapter = find.byKey(
      const ValueKey<String>('unified-detail-chapter-e1'),
    );
    await tester.scrollUntilVisible(
      chapter,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.drag(chapter, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(adapter.markReadCallCount, 1);
    expect(adapter.isRead, isTrue);
  });

  testWidgets('UnifiedDetailPage ignores right-to-left chapter swipe', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(module: LibraryModuleKey.comic);
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

    await tester.drag(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(adapter.markReadCallCount, 0);
    expect(adapter.lastResetEpisodeId, isNull);
  });

  testWidgets(
    'UnifiedDetailPage marks chapters through target by second-stage swipe and undoes it',
    (tester) async {
      final adapter = _ReadThroughDetailAdapter();
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
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-e3'),
      );
      await tester.scrollUntilVisible(
        chapter,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.drag(chapter, const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(adapter.markedThroughTargets, <String>['e3']);
      expect(adapter.readEpisodeIds, containsAll(<String>['e1', 'e2', 'e3']));
      expect(find.text('已将本章及之前的章节标为已读'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);

      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      expect(adapter.restoredEpisodeIds, <String>['e1', 'e2', 'e3']);
      expect(adapter.readEpisodeIds, isEmpty);
    },
  );

  testWidgets(
    'UnifiedDetailPage keeps first-stage distance as the single chapter action',
    (tester) async {
      final adapter = _ReadThroughDetailAdapter();
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
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-e3'),
      );
      await tester.scrollUntilVisible(
        chapter,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.drag(chapter, const Offset(240, 0));
      await tester.pumpAndSettle();

      expect(adapter.markedThroughTargets, isEmpty);
      expect(adapter.markReadCallCount, 1);
      expect(adapter.readEpisodeIds, <String>{'e3'});
    },
  );

  testWidgets(
    'UnifiedDetailPage offers mark through in the chapter long-press menu',
    (tester) async {
      final adapter = _ReadThroughDetailAdapter();
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
      final chapter = find.byKey(
        const ValueKey<String>('unified-detail-chapter-e2'),
      );
      await tester.scrollUntilVisible(
        chapter,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.longPress(chapter);
      await tester.pumpAndSettle();
      expect(find.text('标记已读到此'), findsOneWidget);
      expect(find.text('本章及阅读顺序中更早的章节'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'unified-detail-chapter-mark-read-through-action-e2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(adapter.markedThroughTargets, <String>['e2']);
      expect(adapter.readEpisodeIds, unorderedEquals(<String>['e1', 'e2']));
      expect(adapter.readEpisodeIds, isNot(contains('e3')));
    },
  );

  testWidgets('UnifiedDetailPage reports a removed target for mark through', (
    tester,
  ) async {
    final adapter = _ReadThroughDetailAdapter()..removeTargetAtCommit = true;
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
    final chapter = find.byKey(
      const ValueKey<String>('unified-detail-chapter-e3'),
    );
    await tester.scrollUntilVisible(
      chapter,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.drag(chapter, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('阅读状态更新失败'), findsOneWidget);
    expect(find.text('已将本章及之前的章节标为已读'), findsNothing);
  });

  testWidgets('UnifiedDetailPage reports chapter read mutation failure', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(
      module: LibraryModuleKey.comic,
      failMarkRead: true,
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
    final chapter = find.byKey(
      const ValueKey<String>('unified-detail-chapter-e1'),
    );
    await tester.scrollUntilVisible(
      chapter,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.drag(chapter, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('阅读状态更新失败'), findsOneWidget);
    expect(adapter.isRead, isFalse);
    expect(chapter, findsOneWidget);
  });

  testWidgets('UnifiedDetailPage confirms resetting the whole comic', (
    tester,
  ) async {
    final adapter = _FakeDetailAdapter(
      module: LibraryModuleKey.comic,
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
    final chapter = find.byKey(
      const ValueKey<String>('unified-detail-chapter-e1'),
    );
    await tester.scrollUntilVisible(
      chapter,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.longPress(chapter);
    await tester.pumpAndSettle();
    expect(find.text('重置本章阅读'), findsNothing);
    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.libraryDetailResetWorkReading), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('unified-detail-work-reset-reading-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryDetailResetReadingTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(adapter.resetWorkCallCount, 0);

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

    expect(adapter.resetWorkCallCount, 1);
    expect(adapter.isRead, isFalse);
  });

  testWidgets('UnifiedDetailPage keeps chapter cache action without badge', (
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
    await tester.scrollUntilVisible(
      find.byTooltip('缓存该章节'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-downloaded-badge-e1'),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('缓存该章节'));
    await tester.pumpAndSettle();

    expect(adapter.isDownloaded, isTrue);
    expect(adapter.lastDownloadedEpisodeId, 'e1');
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-downloaded-badge-e1'),
      ),
      findsNothing,
    );
    expect(find.text('已缓存'), findsNothing);
    expect(find.byTooltip('已缓存，点击删除缓存'), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin_outlined), findsNothing);

    await tester.tap(find.byTooltip('已缓存，点击删除缓存'));
    await tester.pumpAndSettle();

    expect(adapter.isDownloaded, isFalse);
    expect(adapter.lastDeletedDownloadEpisodeId, 'e1');
    expect(
      find.byKey(
        const ValueKey<String>('unified-detail-chapter-downloaded-badge-e1'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'UnifiedDetailPage keeps spinner until the queued chapter finishes',
    (tester) async {
      final adapter = _QueuedDownloadDetailAdapter();
      final refreshBus = LibraryShelfRefreshBus();
      addTearDown(() {
        adapter.dispose();
        refreshBus.dispose();
      });
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            shelfRefreshBus: refreshBus,
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('正在缓存'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('已加入缓存队列'), findsNothing);

      adapter.complete('e1');
      refreshBus.notify(
        modules: const <LibraryModuleKey>{LibraryModuleKey.comic},
        reason: 'comic_download_completed',
        source: LibraryMutationSource.bulkDownload,
        workId: 'work-1',
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('正在缓存'), findsNothing);
      expect(find.byTooltip('已缓存，点击删除缓存'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
