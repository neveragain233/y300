part of 'unified_shelf_page_test.dart';

void _searchFilterCases() {
  testWidgets(
    'snapshot displays before initial category preference write completes',
    (tester) async {
      final preferences = _PendingPreferences();
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.grid,
            ),
            viewPreferencesRepository: preferences,
            onOpenWork: (_, _) async {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(preferences.saveStarted, isTrue);
      expect(preferences.saved.isCompleted, isFalse);
      expect(find.byType(ShelfCoverCard), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      preferences.saved.complete();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('search mode switches app bar layout', (tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-shelf-search-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('unified-shelf-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(InlineSearchAppBar), findsOneWidget);
    expect(find.byKey(const Key('unified-shelf-search-input')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byKey(const Key('unified-shelf-filter-button')), findsNothing);
    expect(find.byKey(const Key('unified-shelf-more-button')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('unified-shelf-search-input')),
      'Comic',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('unified-shelf-search-clear-button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('unified-shelf-search-clear-button')),
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('unified-shelf-search-input')),
          )
          .controller
          ?.text,
      isEmpty,
    );

    await tester.tap(find.byKey(const Key('unified-shelf-search-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unified-shelf-search-input')), findsNothing);
    expect(
      find.byKey(const Key('unified-shelf-filter-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unified-shelf-more-button')), findsOneWidget);
  });

  testWidgets('system back exits shelf search before leaving the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('unified-shelf-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unified-shelf-search-input')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(UnifiedShelfPage), findsOneWidget);
    expect(find.byKey(const Key('unified-shelf-search-input')), findsNothing);
    expect(
      find.byKey(const Key('unified-shelf-search-button')),
      findsOneWidget,
    );
  });

  testWidgets('search updates category match count label', (tester) async {
    final adapter = _FakeShelfAdapter(
      initialDisplayMode: LibraryDisplayMode.grid,
      categories: [
        LibraryCategory(
          categoryId: 'comic-default',
          name: '漫画',
          sortOrder: 0,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      onQuery:
          ({
            required List<LibraryCategory> categories,
            required LibraryFilterSet filters,
            required LibraryShelfSortOption sortOption,
            required String keyword,
          }) async {
            if (keyword.trim().isEmpty) {
              return {
                'comic-default': [_item(workId: '1', title: 'Comic A')],
              };
            }
            return {
              'comic-default': [
                _item(workId: '1', title: 'Comic A'),
                _item(workId: '2', title: 'Comic B'),
              ],
            };
          },
    );

    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: adapter,
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('unified-shelf-search-input')),
      'Comic',
    );
    // UnifiedShelfController 对关键词查询有 250ms 防抖，等待防抖触发 reload。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final l10n = AppLocalizationsZh();
    expect(
      find.text(
        l10n.libraryShelfCategoryMatchCount(l10n.libraryShelfTitle('comic'), 2),
      ),
      findsOneWidget,
    );
  });

  testWidgets('filter sheet and display mode switch work', (tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-shelf-grid-view')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();

    expect(find.text('已添加标签'), findsNothing);

    // 切到第 3 个分段（显示），避免依赖具体文案。
    await tester.tap(
      find.byKey(const ValueKey<String>('unified-shelf-panel-tab-2')),
    );
    await tester.pumpAndSettle();

    // 选择列表模式：分组行使用同一槽位，当前选中项显示勾选。
    await tester.tap(
      find.byKey(const ValueKey<String>('unified-shelf-display-list')),
    );
    await tester.pumpAndSettle();

    // 点击底部右侧确认按钮（胶囊 FilledButton）。
    await tester.tap(find.byKey(const Key('unified-shelf-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-shelf-list-view')), findsOneWidget);
  });

  for (final size in [const Size(400, 800), const Size(600, 360)]) {
    testWidgets('shelf panel actions stay usable with large text at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        LocalizedTestApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.grid,
            ),
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_list).first);
      await tester.pumpAndSettle();
      final l10n = AppLocalizationsZh();
      for (final label in [
        l10n.libraryShelfFilter,
        l10n.libraryShelfSort,
        l10n.libraryShelfDisplayMode,
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(l10n.commonApply).hitTestable(), findsOneWidget);
        expect(find.text(l10n.commonCancel).hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text(l10n.commonApply)).dy,
          lessThanOrEqualTo(size.height - 24),
        );
        expect(tester.takeException(), isNull);
      }
      final scroll = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byType(Slider).hitTestable(), findsOneWidget);
      await tester.tap(find.text(l10n.commonApply));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
