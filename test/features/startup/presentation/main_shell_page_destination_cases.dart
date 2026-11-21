part of 'main_shell_page_test.dart';

void _destinationCases() {
  testWidgets('attention follows configured navigation without reading feeds', (
    tester,
  ) async {
    final attention = MessageAttentionController();
    const owner = (
      sessionOwner: (uid: '101', revision: 0),
      sourceGeneration: 0,
    );
    attention.setOwner(owner);
    attention.accept(
      const ForumMessageAttentionObservation(
        viewerUserId: '101',
        source: ForumMessageAttentionSource.mobileHtml,
        combinedHint: ForumMessageAttentionState.present,
      ),
      owner: owner,
      sequence: attention.nextRequestSequence(),
    );
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    final messages = MessageTestRepository();
    addTearDown(attention.dispose);
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
      attention: attention,
      messages: messages,
    );

    MainNavigationItem groupItem(MainNavigationGroup group) => tester
        .widget<MainNavigationCapsule>(find.byType(MainNavigationCapsule))
        .items
        .firstWhere((item) => item.id == group.name);
    void expectDot(MainNavigationGroup target, bool expected) {
      final entry = groupItem(target);
      expect((entry.icon as MessageAttentionIcon).showAttention, expected);
      expect(
        (entry.selectedIcon as MessageAttentionIcon).showAttention,
        expected,
      );
    }

    expectDot(MainNavigationGroup.my, false);
    expectDot(MainNavigationGroup.forum, true);
    final context = tester.element(find.byType(MainShellPage));
    final l10n = AppLocalizations.of(context);
    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    await tester.pumpAndSettle();
    expectDot(MainNavigationGroup.my, false);
    expect(find.byKey(const Key('more-my-messages-entry')), findsNothing);
    expect(attention.value.hasUnacknowledgedAttention, false);

    await _tapNavigationGroup(tester, l10n.appNavigationForum);
    attention.accept(
      const ForumMessageAttentionObservation(
        viewerUserId: '101',
        source: ForumMessageAttentionSource.api,
        privateMessages: ForumMessageAttentionState.present,
        notifications: ForumMessageAttentionState.absent,
        notificationCount: 0,
      ),
      owner: owner,
      sequence: attention.nextRequestSequence(),
    );
    await tester.pump();
    expectDot(MainNavigationGroup.my, false);

    final navigation = ProviderScope.containerOf(context)
        .read(mainNavigationSettingsControllerProvider.notifier);
    await navigation.setVisibility(MainShellDestination.messages, true);
    await tester.pump();
    expectDot(MainNavigationGroup.messages, true);
    expectDot(MainNavigationGroup.my, false);
    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    expect(find.byKey(const Key('more-my-messages-entry')), findsNothing);
    final epoch = attention.value.attentionEpoch;
    await navigation.reorder(6, 0);
    await tester.pump();
    expectDot(MainNavigationGroup.messages, true);
    expect(attention.value.attentionEpoch, epoch);
    expect(messages.reads, isEmpty);
    expect(messages.notificationReads, isEmpty);
    await navigation.setVisibility(MainShellDestination.messages, false);
    await tester.pump();
    expectDot(MainNavigationGroup.my, false);
    expect(attention.value.attentionEpoch, epoch);
    expect(find.byKey(const Key('more-my-messages-entry')), findsNothing);
    await navigation.setVisibility(MainShellDestination.forum, false);
    await tester.pumpAndSettle();
    final fallback = tester.widget<AppGroupedRow>(
      find.byKey(const Key('more-my-messages-entry')),
    );
    expect((fallback.leading! as MessageAttentionIcon).showAttention, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cached forum stays mounted while covers wait and only shelves are gated',
    (tester) async {
      final covers = Completer<void>();
      final network = Completer<ForumHomeReadResult>();
      final repository = _FakeForumHomeRepository(
        cachedEntry: ForumHomeCacheEntry(
          payload: ForumHomePayload(
            directory: const ForumDirectoryData(
              sections: [
                ForumDirectorySection(
                  identity: 'cached',
                  title: 'Last home',
                  forums: [
                    ForumDirectoryForum(
                      fid: '16',
                      title: 'Cached forum',
                      description: '',
                      todayPosts: 5,
                    ),
                  ],
                ),
              ],
            ),
            isLoggedIn: false,
            favoriteForums: [],
          ),
          capabilities: forumHomeTestCapabilities,
          metadata: const DataReadMetadata.network(),
          updatedAt: DateTime(2026),
          cacheAccountId: 'anonymous',
        ),
        network: network.future,
      );
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
        homeRepository: repository,
        libraryReady: covers.future,
      );
      expect(covers.isCompleted, isFalse);
      expect(find.text('Cached forum'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final before = tester.element(find.byKey(const Key('forum-home-list')));
      // Standalone shelves from navigation management use the same barrier.
      final route = ProviderScope.containerOf(
        before,
      ).read(mainDestinationRouteFactoryProvider)(MainShellDestination.comic);
      final navigator = Navigator.of(before);
      unawaited(navigator.push(route));
      await _pumpShellTab(tester);
      expect(
        find.byKey(const Key('main-shell-library-loading')),
        findsOneWidget,
      );
      expect(find.byType(UnifiedShelfPage), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
      expect(
        find.byKey(const Key('main-shell-library-loading')),
        findsOneWidget,
      );
      expect(find.byType(UnifiedShelfPage), findsNothing);
      await _tapNavigationGroup(tester, l10n.appNavigationForum);
      final reads = repository.cacheReads;
      covers.complete();
      await tester.pump();
      await tester.pump();
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(before),
      );
      expect(repository.cacheReads, reads);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      network.complete(forumHomeReadSuccess(repository.cachedEntry!.payload));
      await tester.pumpAndSettle();
      await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
      expect(find.byKey(const Key('main-shell-library-loading')), findsNothing);
      expect(find.byType(UnifiedShelfPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management opens hidden shelves with isolated working selection bars',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final shellHost = ShelfSelectionHostController();
      addTearDown(queueSnapshot.dispose);
      addTearDown(shellHost.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queueSnapshot,
        selectionHost: shellHost,
        webViewDriver: _FakeForumWebViewDriver(),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShellPage)),
      );
      final settingsController = container.read(
        mainNavigationSettingsControllerProvider.notifier,
      );
      for (final destination in [
        MainShellDestination.comic,
        MainShellDestination.novel,
        MainShellDestination.favorites,
      ]) {
        await settingsController.setVisibility(destination, false);
      }
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      await _tapNavigationGroup(tester, l10n.appNavigationMy);
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-settings-entry')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('more-page-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more-settings-entry')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('more-navigation-management-entry')),
      );
      await tester.pumpAndSettle();
      final settingsBefore = container
          .read(mainNavigationSettingsControllerProvider)
          .requireValue
          .settings;

      for (final destination in ['bookshelf', 'favorites']) {
        await tester.tap(
          find.byKey(ValueKey('navigation-management-open-$destination')),
        );
        await _pumpShellTab(tester);
        final shelf = find.byType(UnifiedShelfPage);
        expect(shelf, findsOneWidget);
        final pageContainer = ProviderScope.containerOf(tester.element(shelf));
        final pageHost = pageContainer.read(
          shelfSelectionHostControllerProvider,
        );
        expect(pageHost, isNot(same(shellHost)));
        expect(
          tester.widget<UnifiedShelfPage>(shelf).selectionHost,
          same(pageHost),
        );
        final calls = <String>[];
        pageHost.activate(
          ownerToken: Object(),
          moduleKey: tester.widget<UnifiedShelfPage>(shelf).adapter.moduleKey,
          activeCategoryId: 'default',
          selectedCount: 1,
          selectedWorkIds: {'fixture'},
          selectionActions: const [
            SelectionAction(
              id: SelectionActionIds.download,
              icon: Icons.download,
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('selection-action-bar')), findsOneWidget);
        expect(shellHost.isActive, isFalse);
        await tester.tap(find.byKey(const Key('selection-action-download')));
        await tester.pump();
        expect(calls, [SelectionActionIds.download]);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationManagementPage), findsOneWidget);
        expect(pageHost.isActive, isFalse);
        expect(shellHost.isActive, isFalse);
        expect(
          container
              .read(mainNavigationSettingsControllerProvider)
              .requireValue
              .settings,
          settingsBefore,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
