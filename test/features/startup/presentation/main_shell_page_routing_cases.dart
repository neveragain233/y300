part of 'main_shell_page_test.dart';

void _routingCases() {
  testWidgets('MainShellPage can switch across all six lazy tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final textScale = ValueNotifier<double>(2);
    final blogs = BlogDirectoryFixture();
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    addTearDown(textScale.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumAvailabilityProvider.overrideWith((_) => ForumAvailability()),
          blogAccountIdProvider.overrideWithValue('101'),
          userBlogDirectoryRepositoryProvider.overrideWithValue(blogs),
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
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          historyRepositoryProvider.overrideWithValue(
            const _FakeHistoryRepository(),
          ),
        ],
        child: LocalizedTestApp(
          builder: (context, child) {
            return ValueListenableBuilder<double>(
              valueListenable: textScale,
              builder: (context, scale, _) {
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                );
              },
            );
          },
          home: const MainShellPage(),
        ),
      ),
    );

    await _pumpMainShellReady(tester);

    final l10n = AppLocalizationsZh();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    final capsule = tester.widget<MainNavigationCapsule>(
      find.byType(MainNavigationCapsule),
    );
    expect(capsule.items.map((item) => item.label), <String>[
      l10n.appNavigationForum,
      l10n.appNavigationFavorites,
      l10n.appNavigationBookshelf,
      l10n.appNavigationMy,
    ]);
    expect(_navigationIconData(capsule.items[1].icon), Icons.star_border);
    expect(_navigationIconData(capsule.items[1].selectedIcon), Icons.star);
    expect(
      _navigationIconData(capsule.items[2].icon),
      Icons.auto_stories_outlined,
    );
    final initialStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(
      initialStack.children,
      hasLength(MainShellDestination.values.length),
    );
    expect(blogs.queries, isEmpty);
    final initialTickerModes = _builtTickerModes(initialStack);
    expect(initialTickerModes, hasLength(1));
    expect(initialTickerModes.single.enabled, isTrue);
    expect(tester.takeException(), isNull);

    textScale.value = 1;
    await tester.binding.setSurfaceSize(const Size(800, 700));
    await tester.pump();

    await _tapNavigationGroup(tester, l10n.appNavigationFavorites);
    expect(find.byKey(const Key('unified-shelf-list-view')), findsOneWidget);

    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);
    expect(find.byKey(const Key('main-bookshelf-switcher')), findsNothing);

    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    expect(find.byKey(const Key('more-login-entry')), findsOneWidget);
    final fullyBuiltStack = tester.widget<IndexedStack>(
      find.byType(IndexedStack),
    );
    final fullyBuiltTickerModes = _builtTickerModes(fullyBuiltStack);
    expect(fullyBuiltTickerModes, hasLength(4));
    expect(
      fullyBuiltTickerModes.map((tickerMode) => tickerMode.enabled),
      <bool>[false, false, false, true],
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );

    await container
        .read(mainNavigationSettingsControllerProvider.notifier)
        .setVisibility(MainShellDestination.forum, false);
    await tester.pumpAndSettle();
    // 论坛隐藏时由“我的”接替记录入口，日志始终可用。
    final navigator = Navigator.of(
      tester.element(find.byKey(const Key('more-page-list'))),
    );
    await tester.tap(find.byKey(const ValueKey('more-destination-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-page')), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MainShellPage), findsOneWidget);
    expect(find.byType(MorePage), findsOneWidget);

    await container
        .read(mainNavigationSettingsControllerProvider.notifier)
        .setVisibility(MainShellDestination.blogs, true);
    await tester.pumpAndSettle();
    expect(blogs.queries, isEmpty);
    await tester.tap(find.byKey(const ValueKey('more-destination-blogs')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileBlogPage), findsOneWidget);
    expect(blogs.queries, hasLength(1));
    Navigator.of(tester.element(find.byType(ProfileBlogPage))).pop();
    await tester.pumpAndSettle();

    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history opened from forum routes its threads through the forum host',
    (tester) async {
      final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        webViewDriver: _FakeForumWebViewDriver(),
        historyRepository: _FakeHistoryRepository(items: [_historyEntry()]),
        historyEntryRouter: _NavigatingHistoryEntryRouter(),
      );

      await tester.tap(find.byKey(const Key('forum-home-history-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-page')), findsOneWidget);
      // 记录页仍是主壳的来源页，底栏保留；只有打开详情才退出底栏。
      expect(
        find.byKey(const Key('main-shell-immersive-navigation')),
        findsOneWidget,
      );
      // 不能让记录页再套一层宿主，否则详情会被截留在内层。
      expect(find.byType(AdaptiveDetailHost), findsOneWidget);

      await tester.tap(find.text('测试记录帖子'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-history-detail')), findsOneWidget);
      expect(
        find.byKey(const Key('main-shell-immersive-navigation')),
        findsNothing,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-page')), findsOneWidget);
      expect(
        find.byKey(const Key('main-shell-immersive-navigation')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MainShellPage applies custom order with stable lazy destination slots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final webViewDriver = _FakeForumWebViewDriver();
      final navigationRepository = _FakeMainNavigationSettingsRepository(
        MainNavigationSettings(
          managedOrder: const <MainShellDestination>[
            MainShellDestination.novel,
            MainShellDestination.comic,
            MainShellDestination.forum,
            MainShellDestination.favorites,
            MainShellDestination.history,
          ],
          hiddenDestinations: const <MainShellDestination>{
            MainShellDestination.forum,
            MainShellDestination.history,
            MainShellDestination.blogs,
            MainShellDestination.messages,
          },
        ),
      );
      final messages = MessageTestRepository();
      addTearDown(queueSnapshot.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            forumAvailabilityProvider.overrideWith((_) => ForumAvailability()),
            mainNavigationSettingsRepositoryProvider.overrideWithValue(
              navigationRepository,
            ),
            messageAccountIdProvider.overrideWithValue('10'),
            messageRepositoryProvider.overrideWithValue(messages),
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
            mainShellReplyDraftAttachmentMaintenanceStarterProvider
                .overrideWithValue(() async {}),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
            historyRepositoryProvider.overrideWithValue(
              const _FakeHistoryRepository(),
            ),
          ],
          child: const LocalizedTestApp(home: MainShellPage()),
        ),
      );

      await _pumpMainShellReady(tester);

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-novel')), findsOneWidget);
      expect(find.byKey(const Key('main-shell-page-forum')), findsNothing);

      expect(find.byKey(const Key('main-bookshelf-switcher')), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShellPage)),
      );
      final controller = container.read(
        mainNavigationSettingsControllerProvider.notifier,
      );

      // 漫画移到最前，书架规范入口从小说切到漫画，但页面栈只保留一个书架页。
      await controller.reorder(1, 0);
      await tester.pump();

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-novel')), findsNothing);
      expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);

      await controller.setVisibility(MainShellDestination.comic, false);
      await tester.pump();

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-comic')), findsNothing);
      expect(find.byKey(const Key('main-shell-page-novel')), findsOneWidget);

      await controller.setVisibility(MainShellDestination.comic, true);
      await tester.pump();

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-novel')), findsNothing);
      expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);

      expect(messages.reads, isEmpty);
      await controller.setVisibility(MainShellDestination.messages, true);
      await tester.pump();
      final label = AppLocalizationsZh().appNavigationMessages;
      expect(_navigationLabels(tester), <String>['书架', '收藏', '消息', '我的']);
      await _tapNavigationGroup(tester, label);
      expect(messages.reads, hasLength(1));
      expect(messages.notificationReads, isEmpty);
      messages.reads.single.result.complete(messageTestPage([]));
      await _pumpShellTab(tester);
      final messageElement = tester.element(find.byType(MessageCenterPage));
      await _tapNavigationGroup(tester, '书架');
      await _tapNavigationGroup(tester, label);
      expect(
        tester.element(find.byType(MessageCenterPage)),
        same(messageElement),
      );
      expect(messages.reads, hasLength(1));
    },
  );

  testWidgets('navigation group icon changes after tap', (tester) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumAvailabilityProvider.overrideWith((_) => ForumAvailability()),
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

    await _pumpMainShellReady(tester);

    Finder capsuleIcon(IconData icon) => find.descendant(
      of: find.byType(MainNavigationCapsule),
      matching: find.byIcon(icon),
    );
    expect(capsuleIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(capsuleIcon(Icons.auto_stories), findsNothing);

    await _tapNavigationGroup(tester, '书架');
    // 松开后仍有抬起与 400ms 落位弹簧，透镜内容副本在落位期与真实入口
    // 同时存在；等弹簧收敛后再统计图标，避免把副本当成第二个选中图标。
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    final capsule = tester.widget<MainNavigationCapsule>(
      find.byType(MainNavigationCapsule),
    );
    final bookshelf = capsule.items.indexWhere((item) => item.label == '书架');
    expect(bookshelf, isNonNegative);
    expect(capsule.selectedIndex, bookshelf);
    expect(capsuleIcon(Icons.auto_stories_outlined), findsNothing);
    expect(capsuleIcon(Icons.auto_stories), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey(capsule.items[bookshelf].id)),
        matching: find.byIcon(Icons.auto_stories),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mixed shelf keeps one search state across group switching', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumAvailabilityProvider.overrideWith((_) => ForumAvailability()),
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

    await _pumpMainShellReady(tester);

    final l10n = AppLocalizationsZh();
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    final bookshelf = tester.element(
      find.byKey(const Key('main-shell-page-comic')),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AppTextInput), '混合关键词');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _tapNavigationGroup(tester, l10n.appNavigationForum);
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(
      tester.element(find.byKey(const Key('main-shell-page-comic'))),
      same(bookshelf),
    );
    expect(
      tester.widget<AppTextInput>(find.byType(AppTextInput)).controller!.text,
      '混合关键词',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MainShellPage immersive navigation reads the themed background color',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final webViewDriver = _FakeForumWebViewDriver();
      addTearDown(queueSnapshot.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            forumAvailabilityProvider.overrideWith((_) => ForumAvailability()),
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
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          ],
          child: LocalizedTestApp(
            theme: AppTheme.light(),
            home: const MainShellPage(),
          ),
        ),
      );

      await _pumpMainShellReady(tester);

      final navigationBarContext = tester.element(
        find.byKey(const Key('main-shell-immersive-navigation')),
      );
      expect(
        NavigationBarTheme.of(navigationBarContext).backgroundColor,
        const Color(0xFFFDE6B9),
      );
    },
  );
}
