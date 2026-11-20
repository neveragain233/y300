part of 'unified_detail_page_test.dart';

void _headerMetadataCases() {
  testWidgets('header long press remains a normal refresh without capability', (
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

    final update = find.byKey(const Key('unified-detail-header-update'));
    await tester.longPress(update);
    await tester.pumpAndSettle();
    expect(adapter.refreshWorkCallCount, 1);

    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(adapter.refreshWorkCallCount, 2);
  });

  for (final module in [LibraryModuleKey.comic, LibraryModuleKey.novel]) {
    testWidgets(
      'detail chapter search stays local and opens once for $module',
      (tester) async {
        final adapter = _FakeDetailAdapter(
          module: module,
          includeSecondChapter: true,
        );
        final opened = <String>[];
        await tester.pumpWidget(
          _scopedApp(
            home: UnifiedDetailPage(
              adapter: adapter,
              workId: 'work-1',
              onOpenReader: (context, target) async {
                opened.add(target.episodeId);
              },
              onOpenThread: (context, target) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final reads = adapter.loadChaptersCallCount;
        final input = find.byKey(
          const Key('unified-detail-chapter-search-field'),
        );
        expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
        expect(
          tester
              .widget<AppBar>(find.byType(AppBar))
              .systemOverlayStyle
              ?.statusBarIconBrightness,
          Brightness.dark,
        );
        expect(
          tester.getTopLeft(input).dy,
          greaterThanOrEqualTo(
            tester
                .getBottomLeft(
                  find.byKey(const Key('unified-detail-chapter-toolbar')),
                )
                .dy,
          ),
        );
        expect(tester.widget<AppTextInput>(input).autofocus, isFalse);
        await tester.enterText(input, '2');
        await tester.pumpAndSettle();
        expect(adapter.loadChaptersCallCount, reads);
        expect(
          find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
          findsNothing,
        );
        final result = find.byKey(
          const ValueKey<String>('unified-detail-chapter-e2'),
        );
        expect(result, findsOneWidget);
        expect(
          tester.getTopLeft(result).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
        );
        await tester.tap(result);
        await tester.pumpAndSettle();
        expect(opened, ['e2']);
        expect(adapter.refreshWorkCallCount, 0);
      },
    );
  }

  testWidgets('UnifiedDetailPage renders header/chapter and FAB', (
    tester,
  ) async {
    ReaderRouteTarget? openedTarget;
    final adapter = _FakeDetailAdapter(
      module: LibraryModuleKey.comic,
      isDownloaded: true,
    );
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {
            openedTarget = target;
          },
          onOpenThread: (context, target) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-header-section')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('unified-detail-header-section')),
        matching: find.byKey(const Key('unified-detail-header-actions-row')),
      ),
      findsOneWidget,
    );
    expect(find.text('测试作品'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('unified-detail-hero-title')))
          .maxLines,
      3,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('unified-detail-hero-title')))
          .style
          ?.fontWeight,
      FontWeight.normal,
    );
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).titleTextStyle?.fontWeight,
      FontWeight.normal,
    );
    expect(find.byKey(const Key('unified-detail-author-row')), findsOneWidget);
    expect(find.text('UID: 10001'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('unified-detail-author-row')),
        matching: find.byIcon(Icons.person_outlined),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('unified-detail-collapsed-title')))
          .style
          ?.color
          ?.a,
      0,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(
                  of: find.byKey(const Key('unified-detail-collapsed-title')),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isTrue,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('unified-detail-collapsed-title')))
          .style
          ?.color
          ?.a,
      1,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(
                  of: find.byKey(const Key('unified-detail-collapsed-title')),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isFalse,
    );

    // 章节列表位于下方 sliver，测试中需要滚动后再断言。
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('第1章')).style?.fontWeight,
      FontWeight.normal,
    );
    expect(find.textContaining('Pid:5001'), findsOneWidget);

    expect(find.text('继续'), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.filter_list), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('unified-detail-tag-strip')), findsOneWidget);
    expect(find.text('韩国漫画'), findsOneWidget);
    final tagWidth = tester
        .getSize(find.byKey(const Key('unified-detail-source-tag')))
        .width;
    final labelWidth = tester.getSize(find.text('韩国漫画')).width;
    expect(tagWidth, closeTo(labelWidth + 22, 1));

    await tester.tap(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
    );
    await tester.pumpAndSettle();
    expect(openedTarget?.episodeId, 'e1');
    expect(adapter.markReadCallCount, 0);
    expect(adapter.loadChaptersCallCount, greaterThanOrEqualTo(2));

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-detail-chapter-e1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除该章节缓存'), findsOneWidget);
  });

  testWidgets(
    'Phase 0 baseline commits initial detail content and refreshes in place',
    (tester) async {
      final adapter = _FakeDetailAdapter();
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

      expect(
        find.byKey(const Key('unified-detail-header-section')),
        findsNothing,
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('unified-detail-header-section')),
        findsOneWidget,
      );
      expect(adapter.loadHeaderCallCount, 1);
      expect(adapter.loadChaptersCallCount, 1);
      expect(adapter.refreshWorkCallCount, 0);
      expect(presentationCount, 1);

      await tester.tap(find.text('更新').first);
      await tester.pumpAndSettle();

      expect(adapter.refreshWorkCallCount, 1);
      expect(adapter.loadHeaderCallCount, 2);
      expect(adapter.loadChaptersCallCount, 2);
      expect(
        find.byKey(const Key('unified-detail-header-section')),
        findsOneWidget,
      );
      expect(presentationCount, 1);
    },
  );

  testWidgets(
    'UnifiedDetailPage edits custom metadata through optional adapter',
    (tester) async {
      final adapter = _EditableDetailAdapter();
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
      await tester.tap(find.byKey(const Key('unified-detail-edit-metadata')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('unified-detail-metadata-sheet')),
        findsOneWidget,
      );
      expect(find.text('来源标题：来源标题'), findsOneWidget);
      expect(
        tester
            .widget<AppTextInput>(
              find.byKey(const Key('unified-detail-custom-title-input')),
            )
            .controller
            ?.text,
        '测试作品',
      );
      expect(
        tester
            .widget<AppTextInput>(
              find.byKey(const Key('unified-detail-custom-author-input')),
            )
            .controller
            ?.text,
        '作者A',
      );
      expect(
        tester
            .widget<AppTextInput>(
              find.byKey(const Key('unified-detail-custom-group-input')),
            )
            .controller
            ?.text,
        '汉化组A',
      );

      await tester.enterText(
        find.byKey(const Key('unified-detail-custom-title-input')),
        '新标题',
      );
      await tester.enterText(
        find.byKey(const Key('unified-detail-custom-author-input')),
        '新作者',
      );
      await tester.enterText(
        find.byKey(const Key('unified-detail-custom-group-input')),
        '',
      );
      await tester.enterText(
        find.byKey(const Key('unified-detail-custom-search-title-input')),
        '刷新关键词',
      );
      await tester.tap(find.byKey(const Key('unified-detail-save-metadata')));
      await tester.pumpAndSettle();

      expect(adapter.lastCustomTitle, '新标题');
      expect(adapter.lastCustomAuthor, '新作者');
      expect(adapter.lastCustomTranslationGroup, isNull);
      expect(adapter.lastCustomSearchTitle, '刷新关键词');
      expect(find.text('新标题'), findsWidgets);
    },
  );

  testWidgets('metadata field set controls rendered and submitted values', (
    tester,
  ) async {
    final adapter = _EditableDetailAdapter(
      fields: const <LibraryMetadataField>{LibraryMetadataField.title},
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
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-detail-edit-metadata')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-custom-title-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('unified-detail-custom-author-input')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-custom-group-input')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-custom-search-title-input')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('unified-detail-save-metadata')));
    await tester.pumpAndSettle();

    expect(adapter.updateCalls, 1);
    expect(adapter.lastCustomTitle, '测试作品');
    expect(adapter.lastCustomAuthor, isNull);
    expect(adapter.lastCustomTranslationGroup, isNull);
    expect(adapter.lastCustomSearchTitle, isNull);
  });

  testWidgets('UnifiedDetailPage only exposes parsed source tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: _FakeDetailAdapter(),
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('韩国漫画'), findsOneWidget);
    expect(find.text('自定义标签'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('管理标签'), findsNothing);
    expect(find.text('添加标签'), findsNothing);
    expect(find.text('移除标签'), findsNothing);
    expect(find.text('配置目录'), findsNothing);
  });
}
