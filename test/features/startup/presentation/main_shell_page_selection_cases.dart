part of 'main_shell_page_test.dart';

void _selectionCases() {
  testWidgets(
    'MainShellPage switches bottom bar when selection becomes active',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selectionHost = ShelfSelectionHostController();
      final webViewDriver = _FakeForumWebViewDriver();
      addTearDown(queueSnapshot.dispose);
      addTearDown(selectionHost.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            localFavoriteRepositoryProvider.overrideWith(
              (ref) => _FakeLocalFavoriteRepository(),
            ),
            favoriteSyncServiceProvider.overrideWith(
              (ref) => _FakeFavoriteSyncService(),
            ),
            comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
              queueSnapshot,
            ),
            mainShellBackgroundTaskStarterProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellNotificationInitializerProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            shelfSelectionHostControllerProvider.overrideWithValue(
              selectionHost,
            ),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          ],
          child: const LocalizedTestApp(home: MainShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationCapsule), findsOneWidget);
      expect(find.byKey(const Key('selection-action-bar')), findsNothing);

      selectionHost.activate(
        ownerToken: Object(),
        moduleKey: LibraryModuleKey.comic,
        activeCategoryId: 'default',
        selectedCount: 1,
        selectedWorkIds: const <String>{'comic-1'},
        selectionActions: const <SelectionAction>[
          SelectionAction(
            id: SelectionActionIds.download,
            icon: Icons.download_outlined,
          ),
        ],
        delegate: _selectionDelegate(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationCapsule), findsNothing);
      expect(find.byKey(const Key('selection-action-bar')), findsOneWidget);

      selectionHost.deactivate(selectionHost.state!.ownerToken);
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationCapsule), findsOneWidget);
      expect(find.byKey(const Key('selection-action-bar')), findsNothing);
    },
  );

  testWidgets('MainShellPage selection action bar delegates button taps', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selectionHost = ShelfSelectionHostController();
    final calls = <String>[];
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    addTearDown(selectionHost.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          shelfSelectionHostControllerProvider.overrideWithValue(selectionHost),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    selectionHost.activate(
      ownerToken: Object(),
      moduleKey: LibraryModuleKey.comic,
      activeCategoryId: 'default',
      selectedCount: 1,
      selectedWorkIds: const <String>{'comic-1'},
      selectionActions: const <SelectionAction>[
        SelectionAction(
          id: SelectionActionIds.download,
          icon: Icons.download_outlined,
        ),
      ],
      delegate: _selectionDelegate(
        onRun: (request) async {
          calls.add(request.actionId);
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.noChange,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-download')),
    );
    await tester.pumpAndSettle();

    expect(calls, <String>[SelectionActionIds.download]);
    expect(selectionHost.isActive, isTrue);
  });

  testWidgets(
    'MainShellPage selection category creation safely handles cancel and confirm',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selectionHost = ShelfSelectionHostController();
      final webViewDriver = _FakeForumWebViewDriver();
      final createdNames = <String>[];
      final requests = <SelectionActionExecutionRequest>[];
      addTearDown(queueSnapshot.dispose);
      addTearDown(selectionHost.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queueSnapshot,
        selectionHost: selectionHost,
        webViewDriver: webViewDriver,
      );

      selectionHost.activate(
        ownerToken: Object(),
        moduleKey: LibraryModuleKey.comic,
        activeCategoryId: 'default',
        selectedCount: 1,
        selectedWorkIds: const <String>{'comic-1'},
        selectionActions: const <SelectionAction>[
          SelectionAction(
            id: SelectionActionIds.assignCategory,
            icon: Icons.label_outline,
          ),
        ],
        delegate: ShelfSelectionHostDelegate(
          exitSelection: () async {},
          selectAllVisible: () async {},
          invertVisible: () async {},
          loadAvailableCategories: () async => const <LibraryCategory>[],
          createCategory: (name, {source}) async {
            createdNames.add(name);
            return 'created-category';
          },
          runSelectionAction: (request) async {
            requests.add(request);
            return const SelectionActionOutcome(
              code: SelectionActionOutcomeCode.noChange,
            );
          },
          refreshAfterAction: () async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-action-assign-category')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建分类'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOne);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(createdNames, isEmpty);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-action-assign-category')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建分类'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新分类');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(createdNames, const <String>['新分类']);
      expect(requests, hasLength(1));
      expect(requests.single.targetCategoryId, 'created-category');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mixed selection uses one shared category target', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selectionHost = ShelfSelectionHostController();
    final requests = <SelectionActionExecutionRequest>[];
    final created = <String>[];
    addTearDown(queueSnapshot.dispose);
    addTearDown(selectionHost.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queueSnapshot,
      selectionHost: selectionHost,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final categories = <LibraryCategory>[
      LibraryCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
      LibraryCategory(
        categoryId: 'shared:1',
        name: '共享分类',
        sortOrder: 1,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    selectionHost.activate(
      ownerToken: Object(),
      moduleKey: LibraryModuleKey.bookshelf,
      activeCategoryId: 'all',
      selectedCount: 2,
      selectedWorkIds: const <String>{'comic:yamibo:1', 'novel:novel:1'},
      selectionActions: const <SelectionAction>[
        SelectionAction(
          id: SelectionActionIds.assignCategory,
          icon: Icons.label_outline,
        ),
      ],
      delegate: ShelfSelectionHostDelegate(
        exitSelection: () async {},
        selectAllVisible: () async {},
        invertVisible: () async {},
        loadAvailableCategories: () async => categories,
        createCategory: (name) async {
          created.add(name);
          return 'shared:new';
        },
        runSelectionAction: (request) async {
          requests.add(request);
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.success,
            changed: true,
            succeededCount: 2,
          );
        },
        refreshAfterAction: () async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-assign-category')),
    );
    await tester.pumpAndSettle();

    expect(find.text('共享分类'), findsOneWidget);
    expect(find.text('移出分类'), findsOneWidget);
    expect(find.text('漫画作品（1 项）'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('selection-target-category-shared:1')),
    );
    await tester.pumpAndSettle();

    expect(requests.single.targetCategoryId, 'shared:1');

    selectionHost.activate(
      ownerToken: Object(),
      moduleKey: LibraryModuleKey.bookshelf,
      activeCategoryId: 'all',
      selectedCount: 2,
      selectedWorkIds: const <String>{'comic:yamibo:1', 'novel:novel:1'},
      selectionActions: const <SelectionAction>[
        SelectionAction(
          id: SelectionActionIds.assignCategory,
          icon: Icons.label_outline,
        ),
      ],
      delegate: ShelfSelectionHostDelegate(
        exitSelection: () async {},
        selectAllVisible: () async {},
        invertVisible: () async {},
        loadAvailableCategories: () async => categories,
        createCategory: (name) async {
          created.add(name);
          return 'shared:new';
        },
        runSelectionAction: (request) async {
          requests.add(request);
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.success,
            changed: true,
            succeededCount: 2,
          );
        },
        refreshAfterAction: () async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-assign-category')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新共享分类');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(created, <String>['新共享分类']);
    expect(requests.last.targetCategoryId, 'shared:new');
    expect(tester.takeException(), isNull);
  });

  testWidgets('MainShellPage unfavorite action requires confirmation', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selectionHost = ShelfSelectionHostController();
    var runCount = 0;
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    addTearDown(selectionHost.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          shelfSelectionHostControllerProvider.overrideWithValue(selectionHost),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    selectionHost.activate(
      ownerToken: Object(),
      moduleKey: LibraryModuleKey.favorite,
      activeCategoryId: 'default',
      selectedCount: 2,
      selectedWorkIds: const <String>{'favorite:100', 'favorite:101'},
      selectionActions: const <SelectionAction>[
        SelectionAction(
          id: SelectionActionIds.unfavorite,
          icon: Icons.delete_outline,
          destructive: true,
          needsConfirm: true,
        ),
      ],
      delegate: _selectionDelegate(
        onRun: (request) async {
          runCount += 1;
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.success,
            changed: true,
            succeededCount: 2,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-unfavorite')),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认取消收藏'), findsOneWidget);
    expect(find.textContaining('会被清除'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(runCount, 0);
    expect(selectionHost.isActive, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-unfavorite')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(runCount, 1);
    expect(selectionHost.isActive, isFalse);
  });
}
