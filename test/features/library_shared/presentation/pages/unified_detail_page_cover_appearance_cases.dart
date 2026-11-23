part of 'unified_detail_page_test.dart';

void _coverAppearanceCases() {
  testWidgets('UnifiedDetailPage configures catalog through optional adapter', (
    tester,
  ) async {
    final adapter = _CatalogEditableDetailAdapter();
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
    await tester.tap(find.byKey(const Key('unified-detail-configure-catalog')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-catalog-sheet')),
      findsOneWidget,
    );
    expect(
      find.text('来源目录：https://bbs.yamibo.com/misc.php?mod=tag&id=1'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppTextInput>(
            find.byKey(const Key('unified-detail-catalog-url-input')),
          )
          .controller
          ?.text,
      'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
    );

    await tester.enterText(
      find.byKey(const Key('unified-detail-catalog-url-input')),
      'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
    );
    await tester.tap(find.byKey(const Key('unified-detail-save-catalog')));
    await tester.pumpAndSettle();

    expect(
      adapter.lastCatalogUrl,
      'https://bbs.yamibo.com/misc.php?mod=tag&id=2',
    );
    expect(find.byKey(const Key('unified-detail-catalog-sheet')), findsNothing);
  });

  testWidgets(
    'UnifiedDetailPage shows cover-edit menu only when editor + picker present',
    (tester) async {
      final adapter = _CoverEditableDetailAdapter();
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
            pickCoverImage: () async => null,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unified-detail-set-cover')), findsOneWidget);
      // 无自定义封面时不显示“取消封面”。
      expect(
        find.byKey(const Key('unified-detail-remove-cover')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'UnifiedDetailPage hides cover-edit menu when picker not injected',
    (tester) async {
      final adapter = _CoverEditableDetailAdapter();
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

      expect(find.byKey(const Key('unified-detail-set-cover')), findsNothing);
    },
  );

  testWidgets('UnifiedDetailPage removes custom cover through cover editor', (
    tester,
  ) async {
    final adapter = _CoverEditableDetailAdapter(hasCustomCover: true);
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          pickCoverImage: () async => null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-remove-cover')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('unified-detail-remove-cover')));
    await tester.pumpAndSettle();

    expect(adapter.coverRemoved, isTrue);
    expect(find.text('已取消封面'), findsOneWidget);
  });

  testWidgets('UnifiedDetailPage can cancel a source cover by adapter policy', (
    tester,
  ) async {
    final adapter = _CoverEditableDetailAdapter(hasSourceCover: true);
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          pickCoverImage: () async => null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-remove-cover')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('unified-detail-remove-cover')));
    await tester.pumpAndSettle();

    expect(adapter.coverRemoved, isTrue);
    expect(
      find.byKey(const Key('unified-detail-plain-header')),
      findsOneWidget,
    );
  });

  testWidgets('cover mutation publishes shelf and favorite refresh signals', (
    tester,
  ) async {
    final bus = LibraryShelfRefreshBus();
    final adapter = _CoverEditableDetailAdapter(hasCustomCover: true);
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          pickCoverImage: () async => null,
          shelfRefreshBus: bus,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-detail-remove-cover')));
    await tester.pumpAndSettle();

    final signal = bus.signal.value;
    expect(signal, isNotNull);
    expect(signal!.modules, <LibraryModuleKey>{
      LibraryModuleKey.comic,
      LibraryModuleKey.favorite,
    });
    expect(signal.source, LibraryMutationSource.coverEdit);
    expect(signal.workId, 'work-1');
  });

  testWidgets('post-image cover entry requires both candidates and importer', (
    tester,
  ) async {
    final adapter = _CoverCandidateDetailAdapter();
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          pickCoverImage: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-set-cover-from-post')),
      findsNothing,
    );
  });

  testWidgets(
    'post-image cover entry does not require the local image picker',
    (tester) async {
      final adapter = _CoverCandidateDetailAdapter();
      await tester.pumpWidget(
        _scopedApp(
          home: UnifiedDetailPage(
            adapter: adapter,
            workId: 'work-1',
            onOpenReader: (context, target) async {},
            onOpenThread: (context, target) async {},
            importCoverImage: (imageUrl) async => '/tmp/cover.jpg',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('unified-detail-set-cover-from-post')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('unified-detail-set-cover')), findsNothing);
    },
  );

  testWidgets('sets a custom cover from a post image candidate', (
    tester,
  ) async {
    final adapter = _CoverCandidateDetailAdapter();
    String? importedImageUrl;
    await tester.pumpWidget(
      _scopedApp(
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
          pickCoverImage: () async => null,
          importCoverImage: (imageUrl) async {
            importedImageUrl = imageUrl;
            return '/tmp/y300-imported-cover.jpg';
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('unified-detail-set-cover-from-post')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const Key('unified-detail-cover-candidates-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('unified-detail-cover-candidate-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('unified-detail-cover-candidate-0')));
    // 焦点选区会持续尝试读取本地临时图；用有界 pump 推进弹层与后续流程。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(importedImageUrl, 'https://img.test/candidate-1.jpg');
    expect(find.byType(CoverFocalPointPicker), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(adapter.lastSourcePath, '/tmp/y300-imported-cover.jpg');
    expect(find.text('封面已更新'), findsOneWidget);
  });

  testWidgets('header gradient follows scaffold background', (tester) async {
    const pageBackground = Color(0xFF123456);
    final adapter = _FakeDetailAdapter(
      coverLocalPath: 'missing-y300-detail-cover.png',
    );

    await tester.pumpWidget(
      _scopedApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          scaffoldBackgroundColor: pageBackground,
        ),
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor?.a, 0);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      pageBackground,
    );
    expect(_headerGradient(tester).colors.last, pageBackground);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('unified-detail-header-seam-bridge')),
          )
          .color,
      pageBackground,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));

    final appearingAlpha = tester
        .widget<AppBar>(find.byType(AppBar))
        .backgroundColor!
        .a;
    expect(appearingAlpha, greaterThan(0));
    expect(appearingAlpha, lessThan(1));

    await tester.pumpAndSettle();

    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      pageBackground,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final disappearingAlpha = tester
        .widget<AppBar>(find.byType(AppBar))
        .backgroundColor!
        .a;
    expect(disappearingAlpha, greaterThan(0));
    expect(disappearingAlpha, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor?.a, 0);
  });

  testWidgets(
    'UnifiedDetailPage uses dark hero metadata on a light covered header',
    (tester) async {
      const pageBackground = Color(0xFFF1F3F5);
      final adapter = _FakeDetailAdapter(
        coverLocalPath: 'missing-y300-detail-cover.png',
      );

      await tester.pumpWidget(
        _scopedApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            scaffoldBackgroundColor: pageBackground,
          ),
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
        tester
            .widget<Text>(find.byKey(const Key('unified-detail-hero-title')))
            .style
            ?.color,
        Colors.black,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).foregroundColor,
        Colors.white,
      );
    },
  );

  testWidgets('UnifiedDetailPage no-cover header shows typographic cover', (
    tester,
  ) async {
    const pageBackground = Color(0xFFF1F3F5);
    final adapter = _FakeDetailAdapter();

    await tester.pumpWidget(
      _scopedApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          scaffoldBackgroundColor: pageBackground,
        ),
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
      find.byKey(const Key('unified-detail-header-section')),
      findsOneWidget,
    );
    final plainHeaderHeight = tester
        .getSize(find.byKey(const Key('unified-detail-plain-header')))
        .height;
    expect(find.byKey(const Key('unified-detail-hero-title')), findsOneWidget);
    expect(
      find.byKey(const Key('unified-detail-plain-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('unified-detail-typographic-cover')),
      findsOneWidget,
    );
    expect(find.byType(TypographicLibraryCover), findsOneWidget);
    expect(
      find.byKey(const Key('unified-detail-header-gradient')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-header-seam-bridge')),
      findsNothing,
    );
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('unified-detail-header-section')),
        matching: find.byKey(const Key('unified-detail-header-actions-row')),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _scopedApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          scaffoldBackgroundColor: pageBackground,
        ),
        home: UnifiedDetailPage(
          key: const ValueKey('covered-detail-page'),
          adapter: _FakeDetailAdapter(
            coverLocalPath: 'missing-y300-detail-cover.png',
          ),
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const Key('unified-detail-cover-header')))
          .height,
      plainHeaderHeight,
    );
  });

  testWidgets('UnifiedDetailPage builds dark theme chrome and sheets', (
    tester,
  ) async {
    final adapter = _EditableDetailAdapter();

    await tester.pumpWidget(
      _scopedApp(
        theme: AppTheme.dark(),
        home: UnifiedDetailPage(
          adapter: adapter,
          workId: 'work-1',
          onOpenReader: (context, target) async {},
          onOpenThread: (context, target) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.byKey(const Key('unified-detail-header-section')),
      findsOneWidget,
    );
    // 顶栏“更多”菜单改用公共菜单入口，不再构建 Material PopupMenuButton。
    expect(find.byType(AppPopupMenuButton<String>), findsWidgets);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.filter_list),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('unified-detail-chapter-filter-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unified-detail-sort-source')), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-detail-edit-metadata')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('unified-detail-metadata-sheet')),
      findsOneWidget,
    );
  });

  testWidgets(
    'UnifiedDetailPage suppresses cover background in E-ink mode while keeping cover thumbnail',
    (tester) async {
      final adapter = _CoverEditableDetailAdapter(hasSourceCover: true);
      await tester.pumpWidget(
        _scopedApp(
          home: EInkModeScope(
            enabled: true,
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

      expect(
        find.byKey(const Key('unified-detail-header-gradient')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('unified-detail-header-seam-bridge')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('unified-detail-plain-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-typographic-cover')),
        findsNothing,
      );
      expect(find.byType(ShelfCoverImage), findsOneWidget);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).foregroundColor,
        Colors.black,
      );
    },
  );
}
