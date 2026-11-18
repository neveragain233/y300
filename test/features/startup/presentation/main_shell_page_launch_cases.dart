part of 'main_shell_page_test.dart';

void _launchCases() {
  for (final style in AppNavigationBarStyle.values) {
    testWidgets(
      'feedback avoids $style chrome and internal overlays in the real shell',
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
        );
        final home = tester.element(find.byKey(const Key('forum-home-list')));
        final container = ProviderScope.containerOf(home);
        await container
            .read(appAppearanceControllerProvider.notifier)
            .setNavigationBarStyle(style);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(home);
        var undo = 0;
        showTransientSnackBar(
          home,
          l10n.contentFilterSaveFailed,
          action: SnackBarAction(
            label: l10n.contentFilterUndo,
            onPressed: () => undo++,
          ),
        );
        await tester.pumpAndSettle();
        final chrome = style == AppNavigationBarStyle.immersive
            ? find.byType(MainNavigationCapsule)
            : find.byType(NavigationBar);
        expect(
          tester.getRect(find.text(l10n.contentFilterUndo)).bottom,
          lessThan(tester.getRect(chrome).top),
        );
        await tester.tap(find.text(l10n.contentFilterUndo));
        await tester.pumpAndSettle();
        expect(undo, 1);
        unawaited(
          Navigator.of(home).push(
            MaterialPageRoute<void>(
              builder: (_) => const TransientFeedbackObstacle(
                bottom: 180,
                child: Scaffold(body: SizedBox.expand()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        showTransientSnackBar(home, l10n.contentFilterSaveFailed);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text(l10n.contentFilterSaveFailed)).bottom,
          lessThan(620),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final startupPage in MainStartupPage.values) {
    testWidgets(
      'cold launch resolves $startupPage once independently of order',
      (tester) async {
        final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
          ComicSearchRefreshQueueSnapshot.empty,
        );
        final selection = ShelfSelectionHostController();
        addTearDown(queue.dispose);
        addTearDown(selection.dispose);
        final repository = _FakeMainNavigationSettingsRepository(
          MainNavigationSettings(
            startupPage: startupPage,
            managedOrder: MainShellDestination.defaultManagedOrder.reversed,
            hiddenDestinations: MainShellDestination.defaultHiddenDestinations,
          ),
        );
        await _pumpSelectionShell(
          tester,
          queueSnapshot: queue,
          selectionHost: selection,
          webViewDriver: _FakeForumWebViewDriver(),
          navigationRepository: repository,
        );
        final initial = startupPage == MainStartupPage.forum
            ? 'forum'
            : 'novel';
        expect(find.byKey(Key('main-shell-page-$initial')), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MainShellPage)),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MainShellPage)),
        );
        await _tapNavigationGroup(tester, l10n.appNavigationMy);
        await container
            .read(mainNavigationSettingsControllerProvider.notifier)
            .setStartupPage(
              startupPage == MainStartupPage.forum
                  ? MainStartupPage.bookshelf
                  : MainStartupPage.forum,
            );
        await tester.pumpAndSettle();
        expect(find.byType(MorePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rail and phone navigation retain visited forum and shelf instances',
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
      );
      final home = tester.element(find.byKey(const Key('forum-home-list')));
      tester.view.physicalSize = const Size(1100, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(home),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(l10n.appNavigationBookshelf),
        ),
      );
      await _pumpShellTab(tester);
      final comic = tester.element(
        find.byKey(const Key('main-shell-page-comic')),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(l10n.appNavigationForum),
        ),
      );
      await _pumpShellTab(tester);
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(MainNavigationCapsule), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(home),
      );
      await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
      expect(
        tester.element(find.byKey(const Key('main-shell-page-comic'))),
        same(comic),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reselecting and revisiting forum preserves the actual source route',
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
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      final homeContext = tester.element(
        find.byKey(const Key('forum-home-list')),
      );
      unawaited(
        Navigator.of(homeContext).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('fake-section'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('fake-section'), findsOneWidget);

      await _tapNavigationGroup(tester, l10n.appNavigationForum);
      await tester.pumpAndSettle();

      expect(find.text('fake-section'), findsOneWidget);
      await _tapNavigationGroup(tester, l10n.appNavigationMy);
      await _tapNavigationGroup(tester, l10n.appNavigationForum);
      expect(find.text('fake-section'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
