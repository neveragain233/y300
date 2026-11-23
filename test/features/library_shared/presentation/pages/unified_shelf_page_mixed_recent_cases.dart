part of 'unified_shelf_page_test.dart';

void _mixedRecentCases() {
  testWidgets(
    'initial selection uses first visible category when controller starts empty',
    (tester) async {
      final host = ShelfSelectionHostController();
      addTearDown(host.dispose);
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeSelectableShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.list,
              categories: [
                LibraryCategory(
                  categoryId: 'comic',
                  name: 'Comic',
                  sortOrder: 0,
                  createdAt: DateTime(2026, 1, 1),
                ),
                LibraryCategory(
                  categoryId: 'novel',
                  name: 'Novel',
                  sortOrder: 1,
                  createdAt: DateTime(2026, 1, 2),
                ),
                LibraryCategory(
                  categoryId: 'default',
                  name: 'Default',
                  sortOrder: 2,
                  createdAt: DateTime(2026, 1, 3),
                ),
              ],
              itemsByCategory: {
                'comic': [
                  _item(workId: 'comic-1', title: 'Comic A'),
                  _item(workId: 'comic-2', title: 'Comic B'),
                ],
                'novel': [_item(workId: 'novel-1', title: 'Novel A')],
                'default': List<LibraryWorkItem>.generate(
                  15,
                  (index) => _item(
                    workId: 'default-${index + 1}',
                    title: 'Default ${index + 1}',
                  ),
                ),
              },
            ),
            selectionHost: host,
            onOpenWork: (context, workId, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('unified-shelf-list-item-comic-1')),
      );
      await tester.pumpAndSettle();

      expect(host.state?.activeCategoryId, 'comic');

      await tester.tap(find.byKey(const Key('selection-app-bar-select-all')));
      await tester.pumpAndSettle();

      expect(find.text('已选 2 项'), findsOneWidget);
      for (final workId in ['comic-1', 'comic-2']) {
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
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-list-item-default-1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'recent reading button stays disabled until a target exists and opens it once',
    (tester) async {
      RecentReadingTarget? target;
      RecentReadingTarget? opened;
      var resolveCount = 0;
      final action = RecentReadingAction(
        resolve: () async {
          resolveCount++;
          return target;
        },
        open: (context, next) async {
          opened = next;
          target = null;
        },
      );
      var isActive = true;
      late StateSetter setPageState;
      await tester.pumpWidget(
        LocalizedTestApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setPageState = setState;
              return UnifiedShelfPage(
                adapter: _FakeShelfAdapter(
                  initialDisplayMode: LibraryDisplayMode.grid,
                ),
                recentReadingAction: action,
                isActive: isActive,
                onOpenWork: (_, _, _) async {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('unified-shelf-recent-reading'));
      expect(button, findsOneWidget);
      expect(tester.widget<FloatingActionButton>(button).onPressed, isNull);

      target = RecentReadingTarget(
        moduleKey: LibraryModuleKey.comic,
        workId: 'comic:1',
        episodeId: 'e1',
        readAt: DateTime(2026, 6, 1),
      );
      isActive = false;
      setPageState(() {});
      await tester.pump();
      isActive = true;
      setPageState(() {});
      await tester.pumpAndSettle();
      expect(resolveCount, greaterThan(1));
      expect(tester.widget<FloatingActionButton>(button).onPressed, isNotNull);

      final expected = target;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(opened, expected);
      expect(tester.widget<FloatingActionButton>(button).onPressed, isNull);
    },
  );

  testWidgets('mixed items show source badges and unread semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final l10n = AppLocalizationsZh();
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.list,
              itemsByCategory: <String, List<LibraryWorkItem>>{
                'default': <LibraryWorkItem>[
                  _item(
                    workId: 'yamibo:1',
                    title: '漫画作品',
                  ).copyWith(source: LibraryModuleKey.comic),
                  _item(
                    workId: 'novel:1',
                    title: '小说作品',
                    unreadCount: 0,
                  ).copyWith(source: LibraryModuleKey.novel),
                ],
              },
            ),
            onOpenWork: (_, _, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.libraryShelfComicBadge), findsOneWidget);
      expect(find.text(l10n.libraryShelfNovelBadge), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(l10n.libraryShelfUnreadBadgeSemantics(1))),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('mixed shelf creates one shared category', (tester) async {
    final adapter = _FakeMixedCategoryShelfAdapter();
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: adapter,
          onOpenWork: (_, _, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('unified-shelf-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-shelf-category-source-comic')),
      findsNothing,
    );
    await tester.enterText(find.byType(AppTextInput), '共享分类');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(adapter.createdName, '共享分类');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent reading button hides in search mode', (tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
          ),
          recentReadingAction: RecentReadingAction(
            resolve: () async => RecentReadingTarget(
              moduleKey: LibraryModuleKey.novel,
              workId: 'novel:1',
              episodeId: 'e1',
              readAt: DateTime(2026, 6, 1),
            ),
            open: (_, _) async {},
          ),
          onOpenWork: (_, _, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('unified-shelf-recent-reading')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('unified-shelf-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unified-shelf-recent-reading')), findsNothing);
  });

  testWidgets(
    'recent reading button is icon-only without label and uses e-ink solid circle border',
    (tester) async {
      final l10n = AppLocalizationsZh();
      var eInk = false;
      late StateSetter setMode;
      await tester.pumpWidget(
        ProviderScope(
          child: StatefulBuilder(
            builder: (context, setState) {
              setMode = setState;
              return LocalizedTestApp(
                builder: (context, child) =>
                    EInkModeScope(enabled: eInk, child: child!),
                home: UnifiedShelfPage(
                  adapter: _FakeShelfAdapter(
                    initialDisplayMode: LibraryDisplayMode.grid,
                  ),
                  recentReadingAction: RecentReadingAction(
                    resolve: () async => RecentReadingTarget(
                      moduleKey: LibraryModuleKey.comic,
                      workId: 'comic:1',
                      episodeId: 'e1',
                      readAt: DateTime(2026, 6, 1),
                    ),
                    open: (_, _) async {},
                  ),
                  onOpenWork: (_, _, _) async {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(
        const Key('unified-shelf-recent-reading'),
      );
      expect(buttonFinder, findsOneWidget);
      expect(
        find.descendant(
          of: buttonFinder,
          matching: find.text(l10n.libraryShelfContinueReading),
        ),
        findsNothing,
      );
      final fab = tester.widget<FloatingActionButton>(buttonFinder);
      expect(fab.tooltip, l10n.libraryShelfContinueReading);
      expect(fab.onPressed, isNotNull);
      expect(
        find.ancestor(of: buttonFinder, matching: find.byType(ElasticPress)),
        findsOneWidget,
      );

      setMode(() => eInk = true);
      await tester.pumpAndSettle();

      expect(
        find.ancestor(of: buttonFinder, matching: find.byType(ElasticPress)),
        findsNothing,
      );
      final eInkFab = tester.widget<FloatingActionButton>(buttonFinder);
      expect(
        eInkFab.shape,
        CircleBorder(
          side: BorderSide(
            color: AppTheme.eInkBorderColor(Brightness.light),
            width: 1,
          ),
        ),
      );
    },
  );
}
