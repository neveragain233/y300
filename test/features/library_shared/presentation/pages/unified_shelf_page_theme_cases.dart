part of 'unified_shelf_page_test.dart';

void _themeCases() {
  testWidgets('dark theme shelf surfaces use shelf palette', (tester) async {
    final theme = AppTheme.dark();
    final palette = const ShelfThemePaletteResolver().resolve(theme);
    final progress = ValueNotifier<LibraryShelfTaskProgress?>(
      const LibraryShelfTaskProgress(
        code: LibraryShelfTaskProgressCode.favoriteSyncLoadingDetails,
        subject: '收藏帖',
        current: 1,
        total: 2,
      ),
    );
    addTearDown(progress.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: LocalizedTestApp(
          theme: theme,
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.list,
              taskProgress: progress,
              onQuery:
                  ({
                    required List<LibraryCategory> categories,
                    required LibraryFilterSet filters,
                    required LibraryShelfSortOption sortOption,
                    required String keyword,
                  }) async {
                    return {
                      'default': [
                        _item(
                          workId: 'covered',
                          title: 'Covered Comic',
                          coverImageUrl: 'https://example.com/covered.jpg',
                        ),
                      ],
                    };
                  },
            ),
            onOpenWork: (context, workId, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bannerMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('unified-shelf-task-progress-bar')),
            matching: find.byType(Material),
          )
          .first,
    );
    final listItemMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('unified-shelf-list-item-covered'),
            ),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(
      find.descendant(
        of: find.byType(ShelfCategoryCapsuleBar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material &&
              widget.color == palette.categoryBarBackground,
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(UnifiedShelfPage),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
    expect(bannerMaterial.color, palette.taskProgressBackground);
    expect(listItemMaterial.color, AppTheme.dark().scaffoldBackgroundColor);

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();

    expect(find.text('筛选'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('unified-shelf-panel-tabs')),
        matching: find.text(AppLocalizationsZh().libraryShelfDisplayMode),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网格'), findsOneWidget);
    expect(find.text('列表'), findsOneWidget);
  });

  testWidgets('task progress without total keeps banner indeterminate', (
    tester,
  ) async {
    final progress = ValueNotifier<LibraryShelfTaskProgress?>(
      const LibraryShelfTaskProgress(
        code: LibraryShelfTaskProgressCode.comicSearchWaiting,
        subject: '排队漫画',
        estimatedDuration: Duration(seconds: 21),
      ),
    );
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            taskProgress: progress,
          ),
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('unified-shelf-task-progress-bar')),
    );
    expect(bar.value, isNull);
    expect(
      find.byKey(const Key('unified-shelf-task-progress-count')),
      findsNothing,
    );
    expect(find.text('《排队漫画》正在等待搜索，预计 21 秒'), findsOneWidget);
  });

  testWidgets('hidden task progress does not render banner', (tester) async {
    final progress = ValueNotifier<LibraryShelfTaskProgress?>(
      const LibraryShelfTaskProgress(
        code: LibraryShelfTaskProgressCode.coverWarmup,
        source: LibraryMutationSource.coverWarmup,
        visible: false,
      ),
    );
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            taskProgress: progress,
          ),
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-shelf-task-progress-bar')),
      findsNothing,
    );
    expect(find.text('正在准备封面'), findsNothing);
  });

  testWidgets('initial loading does not flash empty shelf state', (
    tester,
  ) async {
    final adapter = _FakeShelfAdapter(
      initialDisplayMode: LibraryDisplayMode.grid,
      onQuery:
          ({
            required List<LibraryCategory> categories,
            required LibraryFilterSet filters,
            required LibraryShelfSortOption sortOption,
            required String keyword,
          }) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return {
              'default': [_item(workId: '1', title: 'Comic A')],
            };
          },
    );

    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: adapter,
          onOpenWork: (context, workId, _) async {},
        ),
      ),
    );

    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.libraryShelfEmpty), findsNothing);
    expect(find.text(l10n.libraryShelfLoading), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryShelfEmpty), findsNothing);
    expect(find.text(l10n.libraryShelfLoading), findsNothing);
    expect(find.text('Comic A'), findsOneWidget);
  });
}
