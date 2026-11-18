part of 'main_shell_page_test.dart';

void _navigationCases() {
  testWidgets('immersive navigation is the default and clears content', (
    tester,
  ) async {
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
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );
    final capsule = tester.widget<MainNavigationCapsule>(
      find.byType(MainNavigationCapsule),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.byKey(const Key('main-shell-immersive-navigation')),
      findsOneWidget,
    );
    expect(capsule.items.map((item) => item.label), <String>[
      l10n.appNavigationForum,
      l10n.appNavigationFavorites,
      l10n.appNavigationBookshelf,
      l10n.appNavigationMy,
    ]);
    expect(capsule.selectedIndex, 0);
    expect(capsule.swipeEnabled, isTrue);
    final listRect = tester.getRect(find.byKey(const Key('forum-home-list')));
    final capsuleRect = tester.getRect(find.byType(MainNavigationCapsule));
    // 正文视口铺到屏幕底部，内容从胶囊后方滚过，只在滚动尾部预留空间。
    expect(listRect.bottom, greaterThan(capsuleRect.top));
    final homeList = tester.widget<ListView>(
      find.byKey(const Key('forum-home-list')),
    );
    expect((homeList.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));

    await _tapNavigationGroup(tester, l10n.appNavigationFavorites);
    final shelfList = tester.widget<ListView>(
      find.byKey(const Key('unified-shelf-list-view')),
    );
    expect((shelfList.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));

    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    final moreList = tester.widget<ListView>(
      find.byKey(const Key('more-page-list')),
    );
    expect((moreList.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });

  for (final style in AppNavigationBarStyle.values) {
    for (final destination in [
      MainShellDestination.favorites,
      MainShellDestination.comic,
    ]) {
      testWidgets(
        'shelf modal covers shell chrome for ${destination.name} with ${style.name}',
        (tester) async {
          tester.view.padding = const FakeViewPadding(bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
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
          );
          final shellContext = tester.element(find.byType(MainShellPage));
          final appearance = ProviderScope.containerOf(shellContext)
              .read(appAppearanceControllerProvider.notifier);
          await appearance.setNavigationBarStyle(style);
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(shellContext);
          await _tapNavigationGroup(
            tester,
            destination == MainShellDestination.favorites
                ? l10n.appNavigationFavorites
                : l10n.appNavigationBookshelf,
          );
          await tester.pumpAndSettle();
          final page = find.byKey(Key('main-shell-page-${destination.name}'));
          final source = tester.element(page);
          final before = tester.getRect(page);
          final selectedIndex = _selectedNavigationIndex(tester);
          final navigation = style == AppNavigationBarStyle.immersive
              ? find.byType(MainNavigationCapsule)
              : find.byType(NavigationBar);
          final navigationPoint =
              tester.getTopLeft(navigation) + const Offset(30, 30);
          await tester.tap(
            find.byKey(const Key('unified-shelf-filter-button')),
          );
          await tester.pumpAndSettle();

          final sheet = find.byType(BottomSheet);
          final sheetContext = tester.element(sheet);
          expect(
            Navigator.of(sheetContext),
            same(Navigator.of(shellContext, rootNavigator: true)),
          );
          expect(find.text(l10n.commonApply).hitTestable(), findsOneWidget);
          expect(find.text(l10n.commonCancel).hitTestable(), findsOneWidget);
          expect(tester.getRect(page), before);
          await tester.tap(find.text(l10n.commonApply));
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(tester.element(page), same(source));

          await tester.tap(
            find.byKey(const Key('unified-shelf-filter-button')),
          );
          await tester.pumpAndSettle();
          // 底栏所在位置只能命中弹层或遮罩，不能切换背景入口。
          await tester.tapAt(navigationPoint);
          await tester.pumpAndSettle();
          expect(_selectedNavigationIndex(tester), selectedIndex);
          if (sheet.evaluate().isNotEmpty) {
            await tester.tap(find.text(l10n.commonCancel));
            await tester.pumpAndSettle();
          }
          expect(tester.element(page), same(source));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('legacy navigation switches without losing page state', (
    tester,
  ) async {
    // More 收敛为单个设置入口后内容变短，用更矮的窗口保证列表仍可滚动。
    tester.view.physicalSize = const Size(400, 560);
    addTearDown(tester.view.resetPhysicalSize);
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
    );

    final home = tester.element(find.byKey(const Key('forum-home-list')));
    final container = ProviderScope.containerOf(home);
    final controller = container.read(appAppearanceControllerProvider.notifier);
    await controller.setNavigationBarStyle(AppNavigationBarStyle.legacy);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MainNavigationCapsule), findsNothing);
    expect(_navigationLabels(tester), hasLength(4));
    expect(
      tester.element(find.byKey(const Key('forum-home-list'))),
      same(home),
    );
    final legacyPageRect = tester.getRect(
      find.byKey(const Key('main-shell-page-forum')),
    );
    final legacyListRect = tester.getRect(
      find.byKey(const Key('forum-home-list')),
    );
    expect(legacyListRect.bottom, closeTo(legacyPageRect.bottom, 1));

    await controller.setNavigationBarStyle(AppNavigationBarStyle.immersive);
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationCapsule), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.element(find.byKey(const Key('forum-home-list'))),
      same(home),
    );
    final immersiveListRect = tester.getRect(
      find.byKey(const Key('forum-home-list')),
    );
    final capsuleRect = tester.getRect(find.byType(MainNavigationCapsule));
    expect(immersiveListRect.bottom, greaterThan(capsuleRect.top));

    // 切换样式只在主壳重建底栏，入口页面的滚动位置保持。
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );
    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    await tester.drag(
      find.byKey(const Key('more-page-list')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    ScrollableState moreScrollable() => tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('more-page-list')),
        matching: find.byType(Scrollable),
      ),
    );
    final offset = moreScrollable().position.pixels;
    expect(offset, greaterThan(0));

    await controller.setNavigationBarStyle(AppNavigationBarStyle.legacy);
    await tester.pumpAndSettle();
    expect(moreScrollable().position.pixels, offset);

    await controller.setNavigationBarStyle(AppNavigationBarStyle.immersive);
    await tester.pumpAndSettle();
    expect(moreScrollable().position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive capsule drag from the selection switches groups', (
    tester,
  ) async {
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
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );
    await container
        .read(appAppearanceControllerProvider.notifier)
        .setNavigationLensMotion(AppNavigationLensMotion.fromSelection);
    await tester.pumpAndSettle();

    final capsuleFinder = find.byType(MainNavigationCapsule);
    final capsule = tester.widget<MainNavigationCapsule>(capsuleFinder);
    expect(capsule.selectedIndex, 0);
    expect(capsule.dragFromSelection, isTrue);
    await tester.drag(capsuleFinder, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      1,
    );
    expect(find.byKey(const Key('main-shell-page-favorites')), findsOneWidget);

    await tester.drag(capsuleFinder, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      0,
    );
    expect(find.byKey(const Key('main-shell-page-forum')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive capsule follow press starts from the pressed entry', (
    tester,
  ) async {
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
    );

    final capsuleFinder = find.byType(MainNavigationCapsule);
    final capsule = tester.widget<MainNavigationCapsule>(capsuleFinder);
    // 默认按下即跟随：透镜先落到按下的入口，再从按压点跟手。
    expect(capsule.selectedIndex, 0);
    expect(capsule.dragFromSelection, isFalse);
    final pitch =
        tester.getCenter(find.byKey(const ValueKey('favorites'))).dx -
        tester.getCenter(find.byKey(const ValueKey('forum'))).dx;
    await tester.drag(find.byKey(const ValueKey('forum')), Offset(pitch, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      1,
    );
    expect(find.byKey(const Key('main-shell-page-favorites')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled swipe leaves taps as the only group switch', (
    tester,
  ) async {
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
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );
    await container
        .read(appAppearanceControllerProvider.notifier)
        .setNavigationSwipeEnabled(false);
    await tester.pumpAndSettle();

    final capsuleFinder = find.byType(MainNavigationCapsule);
    await tester.drag(capsuleFinder, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      0,
    );
    expect(find.byKey(const Key('main-shell-page-forum')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding entries falls back to a visible group and keeps a bar', (
    tester,
  ) async {
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
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );
    final controller = container.read(
      mainNavigationSettingsControllerProvider.notifier,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );

    await controller.setVisibility(MainShellDestination.forum, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-shell-page-favorites')), findsOneWidget);
    expect(_navigationLabels(tester), <String>['收藏', '书架', '我的']);

    await controller.setVisibility(MainShellDestination.favorites, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);
    expect(_navigationLabels(tester), <String>['书架', '我的']);

    await controller.setVisibility(MainShellDestination.comic, false);
    await controller.setVisibility(MainShellDestination.novel, false);
    await tester.pumpAndSettle();
    expect(_navigationLabels(tester), <String>[l10n.appNavigationMy]);
    expect(
      tester
          .widget<MainNavigationCapsule>(find.byType(MainNavigationCapsule))
          .selectedIndex,
      0,
    );
    expect(find.byType(MorePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookshelf group opens one mixed page without type switcher', (
    tester,
  ) async {
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
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    final bookshelfPage = find.byKey(const Key('main-shell-page-comic'));
    final original = tester.element(bookshelfPage);
    expect(find.byKey(const Key('main-bookshelf-switcher')), findsNothing);
    expect(find.byKey(const Key('main-shell-page-novel')), findsNothing);
    final recentReading = find.byKey(const Key('unified-shelf-recent-reading'));
    expect(recentReading, findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(recentReading).onPressed,
      isNull,
    );

    await _tapNavigationGroup(tester, l10n.appNavigationFavorites);
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(tester.element(bookshelfPage), same(original));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard hides the immersive chrome and restores it', (
    tester,
  ) async {
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
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationCapsule), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('main-shell-page-forum'))).bottom,
      lessThanOrEqualTo(501),
    );

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationCapsule), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('forum-home-list'))).bottom,
      greaterThan(tester.getRect(find.byType(MainNavigationCapsule)).top),
    );
    expect(tester.takeException(), isNull);
  });
}
