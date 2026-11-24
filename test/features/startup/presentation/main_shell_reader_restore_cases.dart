part of 'main_shell_page_test.dart';

void _readerRestoreCases() {
  testWidgets(
    'eInk availability banner uses solid outlined controls with compact height and large-text wrap',
    (tester) async {
      final state = ForumAvailability()
        ..observe(
          generation: 0,
          status: 200,
          securityResponse: false,
          body: '<title>站点维护中</title>',
        );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var shelfTaps = 0;
      const root = Key('availability-banner');
      Widget buildBanner() => ProviderScope(
        overrides: [forumAvailabilityProvider.overrideWith((_) => state)],
        child: LocalizedTestApp(
          home: EInkModeScope(
            enabled: true,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ForumAvailabilityBanner(
                  key: root,
                  onBookshelf: () => shelfTaps++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(buildBanner());
      final banner = find.byKey(root);
      final buttons = find.descendant(
        of: banner,
        matching: find.byType(TextButton),
      );
      expect(buttons, findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(banner));
      final shelf = find.descendant(
        of: banner,
        matching: find.byTooltip(l10n.appNavigationBookshelf),
      );
      final leave = find.descendant(
        of: banner,
        matching: find.byTooltip(l10n.networkLeave),
      );
      final status = find.descendant(
        of: banner,
        matching: find.text(l10n.networkMaintenanceShort),
      );
      expect(
        find.descendant(
          of: banner,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
      final y = tester.getCenter(status).dy;
      for (final action in [buttons, shelf, leave]) {
        expect(tester.getCenter(action).dy, closeTo(y, 1));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      }
      final visualHeight = tester.getSize(banner).height;
      expect(visualHeight, inInclusiveRange(36, 40));
      final material = tester
          .widgetList<Material>(
            find.descendant(of: banner, matching: find.byType(Material)),
          )
          .first;
      expect((material.shape! as Border).top.width, 1);
      expect(
        material.color,
        Theme.of(tester.element(banner)).colorScheme.surface,
      );
      expect(
        tester.widget<TextButton>(buttons.first).style!.animationDuration,
        Duration.zero,
      );
      expect(
        find.descendant(of: banner, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpWidget(buildBanner());
      expect(tester.takeException(), isNull);
      expect(tester.getSize(banner).height, greaterThan(visualHeight));
      await tester.tap(shelf);
      expect(shelfTaps, 1);
      await tester.tap(leave);
      await tester.pump();
      expect(state.blocked, isFalse);
    },
  );

  testWidgets(
    'availability banner floats above capsule, docks on legacy, and centers on rail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final queue = ValueNotifier(ComicSearchRefreshQueueSnapshot.empty);
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      final state = ForumAvailability()..setConnected(false);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        availability: state,
        webViewDriver: _FakeForumWebViewDriver(),
      );
      final shell = find.byType(MainShellPage);
      Finder within(Type type) =>
          find.descendant(of: shell, matching: find.byType(type));
      final banner = within(ForumAvailabilityBanner);
      final pages = within(MainDestinationStack);
      final pageElement = tester.element(pages);

      // 沉浸式底栏：正文铺满全屏，状态条悬浮在导航胶囊上方并限宽。
      expect(tester.getRect(pages).bottom, closeTo(780, 1));
      expect(
        tester.getRect(banner).bottom,
        closeTo(tester.getRect(within(MainNavigationCapsule)).top, 1),
      );
      expect(tester.getSize(banner).width, lessThanOrEqualTo(560));

      // 旧式底栏：状态条紧贴旧式底栏上缘。
      final appearance = ProviderScope.containerOf(tester.element(shell))
          .read(appAppearanceControllerProvider.notifier);
      await appearance.setNavigationBarStyle(AppNavigationBarStyle.legacy);
      await tester.pump();
      expect(
        tester.getRect(pages).bottom,
        closeTo(tester.getRect(banner).top, 1),
      );
      expect(
        tester.getRect(banner).bottom,
        closeTo(tester.getRect(within(MainLegacyNavigationBar)).top, 1),
      );

      // 宽屏侧栏：状态条以限宽悬浮微胶囊居中于右侧内容区底部。
      tester.view.physicalSize = const Size(1000, 700);
      await tester.pump();
      expect(
        tester.getRect(banner).left,
        greaterThan(tester.getRect(within(MainNavigationRail)).right),
      );
      expect(tester.getSize(banner).width, lessThanOrEqualTo(560));
      expect(tester.getRect(banner).bottom, lessThan(700));
      expect(tester.getRect(pages).bottom, closeTo(700, 1));

      state.setConnected(true);
      await tester.pump();
      expect(banner, findsNothing);
      expect(tester.element(pages), same(pageElement));
    },
  );

  for (final scenario in [
    'online',
    'offline',
    'maintenance',
    'disabled',
    'ordinary',
    'deleted',
  ]) {
    testWidgets('cold reader restore $scenario', (tester) async {
      final availability = ForumAvailability();
      if (scenario == 'offline') availability.setConnected(false);
      if (scenario == 'maintenance') {
        availability.observe(
          generation: availability.generation,
          status: 200,
          securityResponse: false,
          body: '<title>站点维护中</title>',
        );
      }
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.restoreReader.name: scenario != 'disabled',
        if (scenario != 'ordinary')
          PreferenceKeys.activeReader.name: jsonEncode({
            'module': 'novel',
            'workId': 'work',
            'episodeId': 'episode',
            'updatedAt': 1,
          }),
      });
      final queue = ValueNotifier(ComicSearchRefreshQueueSnapshot.empty);
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      var opened = 0;
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        webViewDriver: _FakeForumWebViewDriver(),
        availability: availability,
        restorePage: (target) async {
          opened++;
          expect(target, (
            module: ActiveReaderModule.novel,
            workId: 'work',
            episodeId: 'episode',
          ));
          return scenario == 'deleted'
              ? null
              : const Scaffold(key: Key('restored-reader'));
        },
      );
      if (scenario == 'online' ||
          scenario == 'offline' ||
          scenario == 'maintenance') {
        expect(find.byKey(const Key('restored-reader')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
      }
      expect(find.byType(MainShellPage), findsOneWidget);
      expect(opened, scenario == 'disabled' || scenario == 'ordinary' ? 0 : 1);
      final ids = _navigationItems(tester).map((item) => item.id).toList();
      if (scenario == 'offline') {
        expect(ids, isNot(contains('forum')));
        expect(ids[_selectedNavigationIndex(tester)], 'bookshelf');
        availability.setConnected(true);
        await tester.pump();
        expect(
          _navigationItems(tester)[_selectedNavigationIndex(tester)].id,
          'bookshelf',
        );
      } else if (scenario == 'maintenance') {
        expect(ids, contains('forum'));
        expect(ids[_selectedNavigationIndex(tester)], 'bookshelf');
      } else {
        expect(ids[_selectedNavigationIndex(tester)], 'forum');
      }
    });
  }
}
