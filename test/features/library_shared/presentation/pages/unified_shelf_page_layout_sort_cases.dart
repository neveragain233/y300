part of 'unified_shelf_page_test.dart';

void _layoutSortCases() {
  testWidgets('grid mode uses compact shared cover spacing', (tester) async {
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

    final grid = tester.widget<GridView>(
      find.byKey(const Key('unified-shelf-grid-view')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(grid.padding, const EdgeInsets.all(8));
    expect(delegate.crossAxisSpacing, 4);
    expect(delegate.mainAxisSpacing, 4);
  });

  testWidgets('public shelf sort sheet exposes three fields and desc default', (
    tester,
  ) async {
    LibraryShelfSortOption? queriedSort;
    final adapter = _FakeShelfAdapter(
      initialDisplayMode: LibraryDisplayMode.grid,
      onQuery:
          ({
            required List<LibraryCategory> categories,
            required LibraryFilterSet filters,
            required LibraryShelfSortOption sortOption,
            required String keyword,
          }) async {
            queriedSort = sortOption;
            return <String, List<LibraryWorkItem>>{
              'default': <LibraryWorkItem>[
                _item(workId: '1', title: 'Comic A'),
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

    expect(queriedSort?.field, LibraryShelfSortField.favoriteAddedAt);
    expect(queriedSort?.direction, LibrarySortDirection.desc);

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('unified-shelf-panel-tabs')),
        matching: find.text(AppLocalizationsZh().libraryShelfSort),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('章节数'), findsOneWidget);
    expect(find.text('未读章节数'), findsOneWidget);
    expect(find.text('收藏日期'), findsOneWidget);
    expect(find.text('名称'), findsNothing);
    expect(find.text('最近阅读'), findsNothing);
    expect(find.text('检查更新时间'), findsNothing);
    expect(find.text('作品更新时间'), findsNothing);
    expect(find.text('章节获取时间'), findsNothing);

    final favoriteTile = find.ancestor(
      of: find.text('收藏日期'),
      matching: find.byType(AppGroupedRow),
    );
    expect(
      find.descendant(
        of: favoriteTile,
        matching: find.byIcon(Icons.arrow_downward),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('章节数'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('章节数'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-shelf-filter-apply')));
    await tester.pumpAndSettle();

    expect(queriedSort?.field, LibraryShelfSortField.chapterCount);
    expect(queriedSort?.direction, LibrarySortDirection.asc);
  });

  testWidgets('shelf capabilities hide read status and expose bookmarks', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            capabilities: const ShelfModuleCapabilities(
              supportsReadState: false,
              supportsBookmarkFilter: true,
            ),
            itemsByCategory: <String, List<LibraryWorkItem>>{
              'default': <LibraryWorkItem>[
                _item(
                  workId: 'novel-1',
                  title: 'Novel A',
                  unreadCount: 7,
                  hasBookmarks: true,
                ),
              ],
            },
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('unified-shelf-list-item-novel-1'),
        ),
        matching: find.text('7'),
      ),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();
    expect(find.text('未读'), findsNothing);
    expect(find.text('阅读过'), findsNothing);
    expect(find.text('有书签'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('unified-shelf-panel-tabs')),
        matching: find.text(AppLocalizationsZh().libraryShelfSort),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('章节数'), findsOneWidget);
    expect(find.text('未读章节数'), findsNothing);
    expect(find.text('收藏日期'), findsOneWidget);
  });

  testWidgets(
    'pull to refresh triggers adapter refresh in grid/list container',
    (tester) async {
      final adapter = _FakeShelfAdapter(
        initialDisplayMode: LibraryDisplayMode.grid,
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

      expect(adapter.refreshCalls, 0);
      // 下拉目标使用列表滚动容器，避免依赖页面结构中是否存在 CustomScrollView。
      await tester.drag(
        find.byKey(const Key('unified-shelf-grid-view')),
        const Offset(0, 300),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(adapter.refreshCalls, 1);
    },
  );

  testWidgets('grid and list buffer only one row for cover loading', (
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

    final grid = tester.widget<GridView>(
      find.byKey(const Key('unified-shelf-grid-view')),
    );
    expect(
      grid.scrollCacheExtent,
      ScrollCacheExtent.pixels(
        ((tester
                            .getSize(
                              find.byKey(const Key('unified-shelf-grid-view')),
                            )
                            .width -
                        16 -
                        4 *
                            ((grid.gridDelegate
                                        as SliverGridDelegateWithFixedCrossAxisCount)
                                    .crossAxisCount -
                                1)) /
                    (grid.gridDelegate
                            as SliverGridDelegateWithFixedCrossAxisCount)
                        .crossAxisCount) *
                1.5 +
            4,
      ),
    );

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('unified-shelf-panel-tabs')),
        matching: find.text(AppLocalizationsZh().libraryShelfDisplayMode),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('unified-shelf-display-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-shelf-filter-apply')));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(
      find.byKey(const Key('unified-shelf-list-view')),
    );
    expect(list.scrollCacheExtent, const ScrollCacheExtent.pixels(82));
  });
}
