part of 'unified_shelf_page_test.dart';

void _selectionCases() {
  testWidgets(
    'long press enters selection mode and selected grid item is highlighted',
    (tester) async {
      final host = ShelfSelectionHostController();
      addTearDown(host.dispose);
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeSelectableShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.grid,
            ),
            selectionHost: host,
            onOpenWork: (context, workId, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('selection-app-bar')), findsOneWidget);
      expect(host.state?.selectedCount, 1);
      final card = tester.widget<ShelfCoverCard>(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
      );
      expect(card.selected, isTrue);
    },
  );

  testWidgets('selection mode tap toggles item without opening detail', (
    tester,
  ) async {
    final host = ShelfSelectionHostController();
    addTearDown(host.dispose);
    var openCount = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeSelectableShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
          ),
          selectionHost: host,
          onOpenWork: (context, workId, _) async {
            openCount += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final itemFinder = find.byKey(
      const ValueKey<String>('unified-shelf-grid-item-1'),
    );
    await tester.longPress(itemFinder);
    await tester.pumpAndSettle();
    await tester.tap(itemFinder);
    await tester.pumpAndSettle();

    expect(openCount, 0);
    expect(find.byKey(const Key('selection-app-bar')), findsNothing);
    expect(host.isActive, isFalse);
  });

  testWidgets('selection mode disables category tap and page swipe', (
    tester,
  ) async {
    final host = ShelfSelectionHostController();
    addTearDown(host.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeSelectableShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
            categories: [
              LibraryCategory(
                categoryId: 'default',
                name: 'Default',
                sortOrder: 0,
                createdAt: DateTime(2026, 1, 1),
              ),
              LibraryCategory(
                categoryId: 'other',
                name: 'Other',
                sortOrder: 1,
                createdAt: DateTime(2026, 1, 2),
              ),
            ],
            itemsByCategory: {
              'default': [_item(workId: '1', title: 'Comic A')],
              'other': [_item(workId: '2', title: 'Comic B')],
            },
          ),
          selectionHost: host,
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('unified-shelf-category-tab-other')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('unified-shelf-grid-view')).first,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(host.state?.activeCategoryId, 'default');
    expect(
      find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('unified-shelf-grid-item-2')),
      findsNothing,
    );
  });

  testWidgets('page back exits selection before popping route', (tester) async {
    final host = ShelfSelectionHostController();
    addTearDown(host.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeSelectableShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
          ),
          selectionHost: host,
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(UnifiedShelfPage), findsOneWidget);
    expect(find.byKey(const Key('selection-app-bar')), findsNothing);
    expect(host.isActive, isFalse);
  });

  testWidgets('list mode selected item shows border highlight', (tester) async {
    final host = ShelfSelectionHostController();
    addTearDown(host.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeSelectableShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
          ),
          selectionHost: host,
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final itemFinder = find.byKey(
      const ValueKey<String>('unified-shelf-list-item-1'),
    );
    final sizeBefore = tester.getSize(itemFinder);
    await tester.longPress(itemFinder);
    await tester.pumpAndSettle();
    final sizeAfter = tester.getSize(itemFinder);

    expect(sizeAfter, sizeBefore);
    final tile = tester.widget<ListTile>(
      find.descendant(
        of: itemFinder,
        matching: find.byKey(
          const ValueKey<String>('unified-shelf-list-tile-1'),
        ),
      ),
    );
    expect(tile.selected, isTrue);
    expect(
      _borderColorForListItem(tester, itemFinder),
      isNot(Colors.transparent),
    );
  });

  testWidgets('list mode select all highlights all visible items', (
    tester,
  ) async {
    final host = ShelfSelectionHostController();
    addTearDown(host.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeSelectableShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            itemsByCategory: {
              'default': [
                _item(workId: '1', title: 'Comic A'),
                _item(workId: '2', title: 'Comic B'),
                _item(workId: '3', title: 'Comic C'),
              ],
            },
          ),
          selectionHost: host,
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-shelf-list-item-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('selection-app-bar-select-all')));
    await tester.pumpAndSettle();

    expect(find.text('已选 3 项'), findsOneWidget);
    for (final workId in ['1', '2', '3']) {
      final itemFinder = find.byKey(
        ValueKey<String>('unified-shelf-list-item-$workId'),
      );
      final tileFinder = find.descendant(
        of: itemFinder,
        matching: find.byKey(
          ValueKey<String>('unified-shelf-list-tile-$workId'),
        ),
      );
      expect(tester.widget<ListTile>(tileFinder).selected, isTrue);
      expect(
        _borderColorForListItem(tester, itemFinder),
        isNot(Colors.transparent),
      );
    }
  });

  testWidgets('list mode invert updates highlighted items', (tester) async {
    final host = ShelfSelectionHostController();
    addTearDown(host.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeSelectableShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            itemsByCategory: {
              'default': [
                _item(workId: '1', title: 'Comic A'),
                _item(workId: '2', title: 'Comic B'),
                _item(workId: '3', title: 'Comic C'),
              ],
            },
          ),
          selectionHost: host,
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('unified-shelf-list-item-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('selection-app-bar-invert')));
    await tester.pumpAndSettle();

    expect(find.text('已选 2 项'), findsOneWidget);
    for (final workId in ['2', '3']) {
      final itemFinder = find.byKey(
        ValueKey<String>('unified-shelf-list-item-$workId'),
      );
      final tileFinder = find.descendant(
        of: itemFinder,
        matching: find.byKey(
          ValueKey<String>('unified-shelf-list-tile-$workId'),
        ),
      );
      expect(tester.widget<ListTile>(tileFinder).selected, isTrue);
      expect(
        _borderColorForListItem(tester, itemFinder),
        isNot(Colors.transparent),
      );
    }

    final firstItemFinder = find.byKey(
      const ValueKey<String>('unified-shelf-list-item-1'),
    );
    final firstTileFinder = find.descendant(
      of: firstItemFinder,
      matching: find.byKey(const ValueKey<String>('unified-shelf-list-tile-1')),
    );
    expect(tester.widget<ListTile>(firstTileFinder).selected, isFalse);
    expect(
      _borderColorForListItem(tester, firstItemFinder),
      Colors.transparent,
    );
  });
}
