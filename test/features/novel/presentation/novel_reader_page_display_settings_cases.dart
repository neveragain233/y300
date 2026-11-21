part of 'novel_reader_page_test.dart';

void _displaySettingsCases() {
  testWidgets('NovelReaderPage phone display panel keeps half-height layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _buildReaderApp(repository: _FakeNovelRepository()),
    );
    await tester.pumpAndSettle();
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('novel-reader-display-settings-sheet')))
          .height,
      lessThanOrEqualTo(401),
    );
    expect(find.byKey(const Key('adaptive-side-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NovelReaderPage wide display panel applies theme live', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.vertical,
        themePreset: NovelReaderThemePreset.light,
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();

    final wideL10n = AppLocalizations.of(
      tester.element(find.byType(NovelReaderPage)),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('novel-reader-display-settings-sheet')),
        matching: find.byType(Slider),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-display-settings-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-content-width-slider')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-paragraph-spacing-slider')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-page-padding-stepper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-first-line-indent-slider')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-font-weight-control')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-text-align-control')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-display-settings-save')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('novel-reader-display-settings-cancel')),
      findsNothing,
    );

    final sheetHeight = tester
        .getSize(find.byKey(const Key('novel-reader-display-settings-sheet')))
        .height;
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(sheetHeight, lessThanOrEqualTo(viewportHeight));
    expect(
      tester.getSize(find.byKey(const Key('adaptive-side-panel'))).width,
      480,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(wideL10n.novelTheme),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('novel-theme-sepia')), findsOneWidget);
    expect(find.byKey(const Key('novel-theme-follow-app')), findsOneWidget);

    await tester.tap(find.byKey(const Key('novel-theme-sepia')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(repository.latestPreferences?.themeMode, 'sepia');
    expect(
      repository.latestPreferences?.themePreset,
      NovelReaderThemePreset.sepia,
    );
    expect(repository.upsertPreferencesCallCount, 1);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(wideL10n.novelReading),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('novel-reader-flow-mode-control')),
      findsOneWidget,
    );
  });

  testWidgets('NovelReaderPage display sheet exposes paged modes', (
    tester,
  ) async {
    final repository = _FakeNovelRepository();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NovelReaderPage)),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(l10n.novelTheme),
      ),
    );
    await tester.pumpAndSettle();

    const themeKeys = <Key>[
      Key('novel-theme-follow-app'),
      Key('novel-theme-light'),
      Key('novel-theme-sepia'),
      Key('novel-theme-dark'),
    ];
    final widgets = tester.allWidgets.toList(growable: false);
    final optionIndices = themeKeys
        .map((key) => widgets.indexWhere((widget) => widget.key == key))
        .toList(growable: false);
    expect(optionIndices.every((index) => index >= 0), isTrue);
    expect(optionIndices, orderedEquals(optionIndices.toList()..sort()));
    for (final key in themeKeys) {
      final chip = tester.widget<ChoiceChip>(
        find.descendant(of: find.byKey(key), matching: find.byType(ChoiceChip)),
      );
      expect(chip.showCheckmark, isFalse);
      expect(chip.selected, key == const Key('novel-theme-follow-app'));
    }

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(l10n.novelReading),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('novel-reader-flow-mode-control')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-conversion-mode-control')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-safe-area-switch')),
      findsOneWidget,
    );
    expect(find.text('分页 LTR'), findsOneWidget);
    expect(find.text('分页 RTL'), findsOneWidget);
    expect(find.byKey(const Key('novel-reader-paged-page-view')), findsNothing);
    expect(
      find.byKey(const Key('novel-reader-paragraph-list')),
      findsOneWidget,
    );
    expect(repository.latestPreferences, isNull);
  });

  testWidgets(
    'NovelReaderPage display sheet stepper applies without save button',
    (tester) async {
      final repository = _FakeNovelRepository();
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-display-settings-save')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('novel-reader-font-size-increase')),
      );
      await tester.pumpAndSettle();

      expect(repository.latestPreferences, isNotNull);
      expect(repository.latestPreferences?.fontSize, 19.0);
      expect(repository.upsertPreferencesCallCount, 1);
    },
  );

  testWidgets('paragraph indent setting reflows paged body in place', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
      firstRawHtml:
          '<div align="left"><font>&nbsp; &nbsp; &nbsp; &nbsp;第一段正文。</font></div>'
          '<div align="left"><font>第二段正文。</font></div>',
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await _pumpPagedCacheReady(tester);

    String pageText() => tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byKey(const Key('novel-reader-paged-page-view')),
            matching: find.byType(RichText),
          ),
        )
        .map((widget) => widget.text.toPlainText())
        .join();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(
      tester.element(find.byType(NovelReaderPage)),
    );
    await tester.ensureVisible(
      find.byKey(const Key('novel-reader-paragraph-indent-control')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.novelParagraphIndentRemove));
    for (var frame = 0; frame < 160; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (pageText().startsWith('第一段正文。')) break;
    }
    expect(pageText(), contains('第一段正文。第二段正文。'));
    expect(pageText(), isNot(contains('\u00a0')));

    await tester.tap(find.text(strings.novelParagraphIndentIncrease));
    for (var frame = 0; frame < 160; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (pageText().startsWith('\u3000\u3000第一段正文。')) break;
    }
    expect(pageText(), contains('\u3000\u3000第一段正文。\u3000\u3000第二段正文。'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      repository.latestPreferences?.paragraphIndent,
      NovelReaderParagraphIndentMode.increase,
    );
  });

  testWidgets('NovelReaderPage persists the safe area display switch', (
    tester,
  ) async {
    final repository = _FakeNovelRepository();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();

    final switchL10n = AppLocalizations.of(
      tester.element(find.byType(NovelReaderPage)),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(switchL10n.novelReading),
      ),
    );
    await tester.pumpAndSettle();

    final safeAreaSwitch = tester.widget<prism.Switch>(
      find.byKey(const Key('novel-reader-safe-area-switch')),
    );
    expect(safeAreaSwitch.value, isTrue);

    await tester.ensureVisible(
      find.byKey(const Key('novel-reader-safe-area-switch')),
    );
    await tester.tap(find.byKey(const Key('novel-reader-safe-area-switch')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(repository.latestPreferences?.safeAreaEnabled, isFalse);
    expect(repository.upsertPreferencesCallCount, 1);
  });

  testWidgets(
    'NovelReaderPage display sheet barrier dismiss keeps applied settings',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.vertical,
          themePreset: NovelReaderThemePreset.light,
        ),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();

      final themeTab = find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(
          AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
              .novelTheme,
        ),
      );
      await tester.tap(themeTab);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('novel-theme-sepia')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        repository.latestPreferences?.themePreset,
        NovelReaderThemePreset.sepia,
      );

      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-display-settings-sheet')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('novel-reader-paged-page-view')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('novel-reader-paragraph-list')),
        findsOneWidget,
      );
      expect(
        repository.latestPreferences?.themePreset,
        NovelReaderThemePreset.sepia,
      );
      expect(repository.upsertPreferencesCallCount, 1);
    },
  );

  testWidgets('dismissing display settings flushes before the save debounce', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.vertical,
        themePreset: NovelReaderThemePreset.light,
      ),
    );
    final preferencesRepository = _ControlledPagePreferencesRepository(
      repository,
    );
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        preferencesRepository: preferencesRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(
          AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
              .novelTheme,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('novel-theme-sepia')));
    await tester.pump();
    expect(preferencesRepository.saves, isEmpty);

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(
      find.byKey(const Key('novel-reader-display-settings-sheet')),
      findsNothing,
    );
    expect(preferencesRepository.saves, hasLength(1));
    expect(repository.latestPreferences, isNull);
    preferencesRepository.saves.single.complete();
    await tester.pumpAndSettle();
    expect(
      repository.latestPreferences?.themePreset,
      NovelReaderThemePreset.sepia,
    );
    expect(repository.upsertPreferencesCallCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed active save after dismissal rolls back and reports localized error',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.vertical,
          themePreset: NovelReaderThemePreset.light,
        ),
      );
      final preferencesRepository = _ControlledPagePreferencesRepository(
        repository,
      );
      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          preferencesRepository: preferencesRepository,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(NovelReaderPage));
      final container = ProviderScope.containerOf(context, listen: false);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final initial = container.read(provider).value!;
      final failureText = AppLocalizations.of(context)
          .novelSaveDisplaySettingsFailed;
      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text(
            AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
                .novelTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('novel-theme-sepia')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(preferencesRepository.saves, hasLength(1));
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();
      expect(preferencesRepository.saves, hasLength(1));
      preferencesRepository.saves.single.fail();
      await tester.pumpAndSettle();

      final state = container.read(provider).value!;
      expect(state.preferences, initial.persistedPreferences);
      expect(state.persistedPreferences, initial.persistedPreferences);
      expect(state.progressSnapshot, initial.progressSnapshot);
      expect(find.text(failureText), findsOneWidget);
      expect(repository.latestPreferences, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reader rebuild retires the old sheet preview and save timers', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.vertical,
        themePreset: NovelReaderThemePreset.light,
      ),
    );
    final preferencesRepository = _ControlledPagePreferencesRepository(
      repository,
    );
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        preferencesRepository: preferencesRepository,
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NovelReaderPage)),
      listen: false,
    );
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(
          AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
              .novelTheme,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('novel-theme-sepia')));
    await tester.tap(find.byKey(const Key('novel-theme-dark')));
    container.invalidate(provider);
    final rebuilt = await container.read(provider.future);
    final nextPreview = rebuilt.preferences.copyWith(fontSize: 24);
    container.read(provider.notifier).previewPreferences(nextPreview);
    await tester.pump(const Duration(milliseconds: 600));
    expect(preferencesRepository.saves, isEmpty);
    expect(container.read(provider).value!.preferences, nextPreview);

    // The sheet still holds callbacks from the retired coordinator.
    await tester.tap(find.byKey(const Key('novel-theme-light')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(preferencesRepository.saves, isEmpty);
    expect(container.read(provider).value!.preferences, nextPreview);
    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(preferencesRepository.saves, isEmpty);
    expect(
      container.read(provider).value!.persistedPreferences,
      rebuilt.persistedPreferences,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reader rebuild isolates a late save failure from the new preview',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.vertical,
          themePreset: NovelReaderThemePreset.light,
        ),
      );
      final preferencesRepository = _ControlledPagePreferencesRepository(
        repository,
      );
      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          preferencesRepository: preferencesRepository,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(NovelReaderPage));
      final failureText = AppLocalizations.of(context)
          .novelSaveDisplaySettingsFailed;
      final container = ProviderScope.containerOf(context, listen: false);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text(
            AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
                .novelTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('novel-theme-sepia')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(preferencesRepository.saves, hasLength(1));
      container.invalidate(provider);
      final rebuilt = await container.read(provider.future);
      final nextPreview = rebuilt.preferences.copyWith(fontSize: 24);
      container.read(provider.notifier).previewPreferences(nextPreview);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();
      preferencesRepository.saves.single.fail();
      await tester.pumpAndSettle();

      final state = container.read(provider).value!;
      expect(state.preferences, nextPreview);
      expect(state.persistedPreferences, rebuilt.persistedPreferences);
      expect(state.progressSnapshot, rebuilt.progressSnapshot);
      expect(preferencesRepository.saves, hasLength(1));
      expect(find.text(failureText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'latest baseline choice survives a successful save from the retired reader',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.vertical,
          themePreset: NovelReaderThemePreset.light,
        ),
      );
      final original = repository.preferences;
      final preferencesRepository = _ControlledPagePreferencesRepository(
        repository,
      );
      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          preferencesRepository: preferencesRepository,
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelReaderPage)),
        listen: false,
      );
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text(
            AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
                .novelTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('novel-theme-sepia')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(preferencesRepository.saves, hasLength(1));
      container.invalidate(provider);
      final rebuilt = await container.read(provider.future);
      expect(rebuilt.persistedPreferences, original);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text(
            AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
                .novelTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('novel-theme-dark')));
      await tester.tap(find.byKey(const Key('novel-theme-light')));
      await tester.pump();
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();
      expect(preferencesRepository.saves, hasLength(1));

      preferencesRepository.saves.first.complete();
      await tester.pumpAndSettle();
      expect(preferencesRepository.saves, hasLength(2));
      expect(repository.preferences.themePreset, NovelReaderThemePreset.sepia);
      preferencesRepository.saves.last.complete();
      await tester.pumpAndSettle();
      expect(repository.preferences, original);
      expect(container.read(provider).value!.preferences, original);
      expect(container.read(provider).value!.persistedPreferences, original);
      expect(repository.upsertPreferencesCallCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('NovelReaderPage renders the paged LTR default', (tester) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults(),
      firstParagraphs: List<String>.generate(
        12,
        (index) => '首屏分页段落 $index ${List<String>.filled(60, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('novel-reader-paragraph-list')), findsNothing);
    expect(
      find.byKey(const Key('novel-reader-html-document-view')),
      findsNothing,
    );
    expect(find.byKey(const Key('novel-reader-paged-surface')), findsOneWidget);
    expect(
      find.byKey(const Key('novel-reader-paged-page-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-persistent-status-bar')),
      findsOneWidget,
    );
    expect(_readingStatusTrailing(tester), contains('第 1 /'));
    final statusCenter = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('shared-reader-persistent-status-trailing')),
        matching: find.byType(Text),
      ),
    );
    expect(statusCenter.style?.fontSize, 11);
    final contentInset = tester.widget<Padding>(
      find.byKey(const ValueKey<String>('novel-reader-paged-content-inset-0')),
    );
    expect(
      (contentInset.padding as EdgeInsets).bottom,
      0,
      reason:
          'Page progress lives in the persistent footer, not inside the page.',
    );
    expect(
      tester
          .getBottomLeft(
            find.byKey(const ValueKey<String>('novel-reader-paged-page-0')),
          )
          .dy,
      lessThanOrEqualTo(
        tester
            .getTopLeft(
              find.byKey(const Key('shared-reader-persistent-status-bar')),
            )
            .dy,
      ),
    );

    await _showReaderMenu(tester);
    final pagedSlider = tester.widget<Slider>(
      find.byKey(const Key('shared-reader-progress-slider')),
    );
    expect(pagedSlider.divisions, isNotNull);
    expect(find.text('计算中'), findsNothing);
    pagedSlider.onChangeStart?.call(pagedSlider.max);
    pagedSlider.onChanged?.call(pagedSlider.max);
    pagedSlider.onChangeEnd?.call(pagedSlider.max);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.readingProgress?.pageIndex, pagedSlider.max.toInt());
    expect(repository.readingProgress?.pageCount, pagedSlider.max.toInt() + 1);
  });

  testWidgets(
    'explicit scroll mode choice persists across reader reconstruction',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      final surface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      final savesBeforeChoice = repository.upsertPreferencesCallCount;
      expect(repository.preferences.flowMode, NovelReaderFlowMode.pagedLtr);

      // The surface exposes this callback only for an explicit user action.
      // Exercise its page coordinator and durable preferences repository.
      surface.onChooseScrollMode!();
      await tester.pumpAndSettle();

      expect(repository.upsertPreferencesCallCount, savesBeforeChoice + 1);
      expect(
        repository.latestPreferences?.flowMode,
        NovelReaderFlowMode.vertical,
      );
      expect(repository.preferences.flowMode, NovelReaderFlowMode.vertical);
      expect(
        find.byKey(const Key('novel-reader-html-document-view')),
        findsOneWidget,
      );
      expect(find.byType(NovelReaderHtmlPagedSurface), findsNothing);
      surface.onChooseScrollMode!();
      await tester.pumpAndSettle();
      expect(repository.upsertPreferencesCallCount, savesBeforeChoice + 1);
      expect(repository.preferences.flowMode, NovelReaderFlowMode.vertical);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      expect(repository.upsertPreferencesCallCount, savesBeforeChoice + 1);
      expect(repository.preferences.flowMode, NovelReaderFlowMode.vertical);
      expect(
        find.byKey(const Key('novel-reader-html-document-view')),
        findsOneWidget,
      );
      expect(find.byType(NovelReaderHtmlPagedSurface), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelReaderPage)),
        listen: false,
      );
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      expect(
        container
            .read(novelReaderControllerProvider(args))
            .value!
            .currentEpisode
            .episodeId,
        surface.episode.episodeId,
      );
    },
  );

  testWidgets('retired scroll mode choice cannot save another chapter mode', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();
    final oldSurface = tester.widget<NovelReaderHtmlPagedSurface>(
      find.byType(NovelReaderHtmlPagedSurface),
    );
    final oldChoice = oldSurface.onChooseScrollMode!;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NovelReaderPage)),
      listen: false,
    );
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final controller = container.read(
      novelReaderControllerProvider(args).notifier,
    );
    expect(
      await tester.runAsync(
        () => controller.openEpisodeFromCatalog('novel:49:100:5002'),
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    final currentSurface = tester.widget<NovelReaderHtmlPagedSurface>(
      find.byType(NovelReaderHtmlPagedSurface),
    );
    expect(currentSurface.episode.episodeId, 'novel:49:100:5002');
    final savesBeforeLateCallback = repository.upsertPreferencesCallCount;

    oldChoice();
    await tester.pumpAndSettle();

    expect(repository.upsertPreferencesCallCount, savesBeforeLateCallback);
    expect(repository.preferences.flowMode, NovelReaderFlowMode.pagedLtr);
    expect(
      tester
          .widget<NovelReaderHtmlPagedSurface>(
            find.byType(NovelReaderHtmlPagedSurface),
          )
          .episode
          .episodeId,
      'novel:49:100:5002',
    );
  });

  testWidgets(
    'old scroll mode choices are inert after same chapter mode and layout changes',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();
      final oldLtrSurface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelReaderPage)),
        listen: false,
      );
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final controller = container.read(provider.notifier);
      final initial = container.read(provider).value!;
      final chapterLoads = List<String>.of(repository.chapterLoadEpisodeIds);
      final rtl = initial.preferences.copyWith(
        flowMode: NovelReaderFlowMode.pagedRtl,
      );
      await controller.commitPreferences(rtl);
      final savesAfterModeChange = repository.upsertPreferencesCallCount;
      final progressAfterModeChange = container
          .read(provider)
          .value!
          .progressSnapshot;

      // The provider changed before the page rebuilt; the captured choice must
      // inspect that live surface rather than the widget still on screen.
      oldLtrSurface.onChooseScrollMode!();
      expect(
        container.read(provider).value!.progressSnapshot,
        progressAfterModeChange,
      );
      await tester.pumpAndSettle();

      expect(repository.upsertPreferencesCallCount, savesAfterModeChange);
      expect(repository.preferences, rtl);
      expect(container.read(provider).value!.preferences, rtl);
      final oldRtlSurface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      expect(oldRtlSurface.preferences, rtl);
      final relayout = rtl.copyWith(fontSize: rtl.fontSize + 2);
      await controller.commitPreferences(relayout);
      final savesAfterLayoutChange = repository.upsertPreferencesCallCount;
      final progressAfterLayoutChange = container
          .read(provider)
          .value!
          .progressSnapshot;

      oldRtlSurface.onChooseScrollMode!();
      expect(
        container.read(provider).value!.progressSnapshot,
        progressAfterLayoutChange,
      );
      await tester.pumpAndSettle();

      expect(repository.upsertPreferencesCallCount, savesAfterLayoutChange);
      expect(repository.preferences, relayout);
      final current = container.read(provider).value!;
      expect(current.preferences, relayout);
      expect(
        current.currentEpisode.episodeId,
        initial.currentEpisode.episodeId,
      );
      expect(repository.chapterLoadEpisodeIds, chapterLoads);
      expect(
        tester
            .widget<NovelReaderHtmlPagedSurface>(
              find.byType(NovelReaderHtmlPagedSurface),
            )
            .preferences,
        relayout,
      );
    },
  );

  testWidgets('NovelReaderPage persists paged mode across reconstruction', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List<String>.generate(
        12,
        (index) => '持久化分页段落 $index ${List<String>.filled(60, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text(
          AppLocalizations.of(tester.element(find.byType(NovelReaderPage)))
              .novelReading,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pagedLtr = find.descendant(
      of: find.byKey(const Key('novel-reader-flow-mode-control')),
      matching: find.text('分页 LTR'),
    );
    await tester.tap(pagedLtr);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(repository.preferences.flowMode, NovelReaderFlowMode.pagedLtr);
    expect(
      find.byKey(const Key('novel-reader-paged-page-view')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('novel-reader-paragraph-list')), findsNothing);
    expect(
      find.byKey(const Key('novel-reader-paged-page-view')),
      findsOneWidget,
    );
  });

  testWidgets('NovelReaderPage restores a visible page for the same layout', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
      firstParagraphs: List<String>.generate(
        36,
        (index) => '持久化分页段落 $index ${List<String>.filled(120, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    final pageViewFinder = find.byKey(
      const Key('novel-reader-paged-page-view'),
    );
    await tester.drag(pageViewFinder, const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 260));

    final savedIndex = repository.readingProgress?.pageIndex;
    expect(savedIndex, greaterThan(0));
    expect(repository.readingProgress?.paginationKey, isNotNull);
    expect(repository.readingProgress?.anchorNodeId, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('${savedIndex! + 1} /'), findsOneWidget);
  });
}
