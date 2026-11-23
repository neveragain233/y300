part of 'main_shell_page_test.dart';

void _readerRestoreCases() {
  testWidgets(
    'eInk availability banner uses solid outlined controls with immediate feedback',
    (tester) async {
      final state = ForumAvailability()..setManual(true);
      const root = Key('availability-banner');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [forumAvailabilityProvider.overrideWith((_) => state)],
          child: const LocalizedTestApp(
            home: EInkModeScope(
              enabled: true,
              child: Scaffold(body: ForumAvailabilityBanner(key: root)),
            ),
          ),
        ),
      );
      final banner = find.byKey(root);
      final buttons = find.descendant(
        of: banner,
        matching: find.byType(TextButton),
      );
      expect(buttons, findsNWidgets(2));
      final material = tester
          .widgetList<Material>(
            find.descendant(of: banner, matching: find.byType(Material)),
          )
          .first;
      expect((material.shape! as Border).bottom.width, 1);
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
      await tester.tap(buttons.last);
      await tester.pump();
      expect(state.blocked, isFalse);
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
