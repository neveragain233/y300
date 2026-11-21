part of 'novel_reader_page_test.dart';

void _conversionSessionCases() {
  for (final flowMode in [
    NovelReaderFlowMode.pagedLtr,
    NovelReaderFlowMode.pagedRtl,
  ]) {
    testWidgets(
      'middle conversion in ${flowMode.name} preserves the visible point across consecutive previews and keeps persisted progress',
      (tester) async {
        const channel = MethodChannel('flutter_open_chinese_convert');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as List<Object?>;
          final text = arguments.first as String;
          return arguments[1] == 't2s'
              ? text.replaceAll('臺', '台')
              : text.replaceAll('台', '臺');
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final paragraphs = ['開頭：${List.filled(1000, '臺正文').join()}。'];
        final repository = _FakeNovelRepository(
          preferences: NovelReaderPreferences.defaults().copyWith(
            flowMode: flowMode,
          ),
          firstParagraphs: paragraphs,
          firstRawHtml: paragraphs.map((text) => '<p>$text</p>').join(),
        );
        await tester.pumpWidget(_buildReaderApp(repository: repository));
        await _pumpPagedCacheReady(tester);
        final surfaces = find.byType(NovelReaderHtmlPagedSurface);
        for (var turn = 0; turn < 3; turn++) {
          expect(
            tester
                .widget<NovelReaderHtmlPagedSurface>(surfaces)
                .navigationController!
                .turnNext(),
            isTrue,
          );
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(milliseconds: 300));
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
        final original = tester
            .widget<NovelReaderHtmlPagedSurface>(surfaces)
            .conversionPosition!;
        expect(original.anchor.textOffset, greaterThan(0));
        final saved = container.read(provider).value!.progressSnapshot;
        expect(saved.pageIndex, greaterThan(0));
        final persisted = repository.readingProgress!;
        final chapterLoads = List<String>.of(repository.chapterLoadEpisodeIds);
        for (final mode in [
          NovelReaderConversionMode.toSimplified,
          NovelReaderConversionMode.toTraditional,
          NovelReaderConversionMode.none,
        ]) {
          controller.previewPreferences(
            container
                .read(provider)
                .value!
                .preferences
                .copyWith(conversionMode: mode),
          );
          for (var frame = 0; frame < 200; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final surface = tester.widget<NovelReaderHtmlPagedSurface>(
              surfaces,
            );
            if (surface.conversionPosition?.conversionIdentity == mode.name &&
                find
                    .byKey(const Key('novel-reader-paged-page-view'))
                    .evaluate()
                    .isNotEmpty) {
              break;
            }
          }
          final converted = tester
              .widget<NovelReaderHtmlPagedSurface>(surfaces)
              .conversionPosition!;
          expect(converted.conversionIdentity, mode.name);
          expect(converted.anchor.nodeId, original.anchor.nodeId);
          expect(converted.anchor.textOffset, original.anchor.textOffset);
          expect(
            _progressFields(container.read(provider).value!.progressSnapshot),
            _progressFields(saved),
          );
          expect(
            repository.readingProgress!.anchorTextIdentity,
            persisted.anchorTextIdentity,
          );
          expect(
            repository.readingProgress!.anchorTextOffset,
            persisted.anchorTextOffset,
          );
          final body = tester.element(
            find.byKey(const Key('novel-reader-paged-page-view')),
          );
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.element(
                find.byKey(const Key('novel-reader-paged-page-view')),
              ),
              same(body),
            );
          }
          expect(container.read(provider).value!.progressSnapshot, saved);
        }
        expect(repository.chapterLoadEpisodeIds, chapterLoads);
        expect(
          tester
              .widget<NovelReaderHtmlPagedSurface>(surfaces)
              .navigationController!
              .turnNext(),
          isTrue,
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(container.read(provider).value!.progressSnapshot, isNot(saved));
        expect(
          repository.readingProgress!.pageIndex,
          greaterThan(saved.pageIndex),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final flowMode in [
    NovelReaderFlowMode.vertical,
    NovelReaderFlowMode.pagedLtr,
    NovelReaderFlowMode.pagedRtl,
  ]) {
    testWidgets(
      'conversion in ${flowMode.name} keeps content while pending and does not reload after save',
      (tester) async {
        const channel = MethodChannel('flutter_open_chinese_convert');
        final nativeCalls = <MethodCall>[];
        final conversionGate = Completer<void>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          await conversionGate.future;
          return ((call.arguments as List<Object?>).first as String).replaceAll(
            '臺',
            '台',
          );
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final repository = _FakeNovelRepository(
          preferences: NovelReaderPreferences.defaults().copyWith(
            flowMode: flowMode,
          ),
          firstRawHtml: '<p>臺正文第一段。</p><p>臺正文第二段。</p>',
          firstParagraphs: ['臺回退第一段。', '臺回退第二段。'],
        );
        final preferenceStore = _ControlledPagePreferencesRepository(
          repository,
        );
        await tester.pumpWidget(
          _buildReaderApp(
            repository: repository,
            preferencesRepository: preferenceStore,
          ),
        );
        if (flowMode == NovelReaderFlowMode.vertical) {
          await _pumpVerticalReaderReady(tester);
        } else {
          await _pumpPagedCacheReady(tester);
        }
        final body = find.byKey(
          Key(
            flowMode == NovelReaderFlowMode.vertical
                ? 'novel-reader-html-document-view'
                : 'novel-reader-paged-page-view',
          ),
        );
        final initialBody = tester.element(body);
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
        final l10n = AppLocalizations.of(
          tester.element(find.byType(NovelReaderPage)),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('reader-display-panel-tabs')),
            matching: find.text(l10n.novelReading),
          ),
        );
        await tester.pumpAndSettle();
        final option = find.descendant(
          of: find.byKey(const Key('novel-reader-conversion-mode-control')),
          matching: find.text(l10n.novelConversionSimplified),
        );
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump(const Duration(milliseconds: 650));
        expect(tester.element(body), same(initialBody));
        expect(
          container.read(provider).value!.renderPreferences.conversionMode,
          NovelReaderConversionMode.none,
        );
        expect(preferenceStore.saves, isEmpty);
        expect(nativeCalls, hasLength(1));

        conversionGate.complete();
        if (flowMode == NovelReaderFlowMode.vertical) {
          await _pumpVerticalReaderReady(tester);
        } else {
          await _pumpPagedCacheReady(tester);
        }
        expect(
          container.read(provider).value!.document.plainText,
          contains('台正文'),
        );
        expect(
          container.read(provider).value!.renderPreferences.conversionMode,
          NovelReaderConversionMode.toSimplified,
        );
        expect(nativeCalls, hasLength(2));
        final convertedDocument = container.read(provider).value!.document;
        final convertedBody = tester.element(body);
        final convertedText = tester.element(_readerText('台正文第一段。').first);
        expect(preferenceStore.saves, hasLength(1));
        preferenceStore.saves.single.complete();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.element(body), same(convertedBody));
          expect(
            tester.element(_readerText('台正文第一段。').first),
            same(convertedText),
          );
          expect(
            find.byKey(const Key('novel-reader-html-loading')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('novel-reader-paged-layout-loading')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('novel-reader-delayed-loading-surface')),
            findsNothing,
          );
        }
        expect(
          container.read(provider).value!.document,
          same(convertedDocument),
        );
        expect(repository.chapterLoadEpisodeIds, ['novel:49:100:5001']);
        expect(nativeCalls, hasLength(2));
        expect(
          repository.latestPreferences?.conversionMode,
          NovelReaderConversionMode.toSimplified,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'reader session caches survive a paged scroll paged mode round trip',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
        firstRawHtml: '<p><span style="font-style:italic">会话缓存正文。</span><ruby>保护<rt>reading</rt></ruby></p>',
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await _pumpPagedCacheReady(tester);
      final initialSurface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      final caches = _pagedSurfaceCaches(initialSurface);
      expect(caches, everyElement(isNotNull));
      _expectPagedCachesOpen(initialSurface);
      final planCount = initialSurface.paginationCache!.length;
      final preparedCount = initialSurface.preparedChapterCache!.length;
      expect(planCount, greaterThan(0));
      expect(preparedCount, greaterThan(0));
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
      final preferences = container.read(provider).value!.preferences;

      controller.previewPreferences(
        preferences.copyWith(flowMode: NovelReaderFlowMode.vertical),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NovelReaderHtmlPagedSurface), findsNothing);
      expect(find.byType(NovelReaderHtmlDocumentView), findsOneWidget);
      _expectPagedCachesOpen(initialSurface);
      expect(initialSurface.paginationCache!.length, planCount);
      expect(
        initialSurface.preparedChapterCache!.length,
        greaterThanOrEqualTo(preparedCount),
      );

      controller.previewPreferences(preferences);
      await _pumpPagedCacheReady(tester);
      final returnedSurface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      expect(_pagedSurfaceCaches(returnedSurface), orderedEquals(caches));
      _expectPagedCachesOpen(returnedSurface);
      expect(returnedSurface.paginationCache!.length, planCount);
      expect(
        returnedSurface.preparedChapterCache!.length,
        greaterThanOrEqualTo(preparedCount),
      );
      expect(
        find.byKey(const Key('novel-reader-paged-page-view')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      _expectPagedCachesClosed(returnedSurface);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'motion preview retains the ready page and its current position',
    (tester) async {
      final paragraphs = [List.filled(1000, '阅读正文').join()];
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults(),
        firstParagraphs: paragraphs,
        firstRawHtml: '<p>${paragraphs.single}</p>',
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await _pumpPagedCacheReady(tester);
      final surfaces = find.byType(NovelReaderHtmlPagedSurface);
      final first = tester.widget<NovelReaderHtmlPagedSurface>(surfaces);
      expect(first.navigationController!.turnNext(), isTrue);
      await tester.pumpAndSettle();
      final pageFinder = find.byKey(const Key('novel-reader-paged-page-view'));
      final pageController = tester.widget<PageView>(pageFinder).controller!;
      final planCount = first.paginationCache!.length;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelReaderPage)),
      );
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final controller = container.read(provider.notifier);
      controller.previewPreferences(
        container
            .read(provider)
            .value!
            .preferences
            .copyWith(
              pageEffect: NovelReaderPageEffect.staggered,
              pageSpeed: NovelReaderPageSpeed.relaxed,
            ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(pageFinder).controller,
        same(pageController),
      );
      expect(pageController.page, 1);
      expect(first.paginationCache!.length, planCount);
      expect(
        find.byKey(const Key('novel-reader-delayed-loading-indicator')),
        findsNothing,
      );
      final current = tester.widget<NovelReaderHtmlPagedSurface>(surfaces);
      expect(current.navigationController!.turnNext(), isTrue);
      await tester.pumpAndSettle();
      expect(pageController.page, 2);
      expect(container.read(provider).value!.progressSnapshot.pageIndex, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'display sheet applies and saves margins, page effect and speed',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults(),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await _pumpPagedCacheReady(tester);
      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('novel-reader-page-padding-value')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('novel-reader-page-padding-input')),
        '24',
      );
      await tester.tap(
        find.byKey(const Key('novel-reader-page-padding-confirm')),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NovelReaderPage)),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text(l10n.novelReading),
        ),
      );
      await tester.pumpAndSettle();
      for (final (key, label) in [
        ('novel-reader-page-effect-control', l10n.novelPageEffectStaggered),
        ('novel-reader-page-speed-control', l10n.novelPageSpeedRelaxed),
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(repository.latestPreferences!.pagePadding, 24);
      expect(
        repository.latestPreferences!.pageEffect,
        NovelReaderPageEffect.staggered,
      );
      expect(
        repository.latestPreferences!.pageSpeed,
        NovelReaderPageSpeed.relaxed,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'reader argument rebinding retires old session caches on the same Page',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults(),
      );
      final episode = ValueNotifier('novel:49:100:5001');
      addTearDown(episode.dispose);
      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          home: ValueListenableBuilder<String>(
            valueListenable: episode,
            builder: (_, episodeId, _) => NovelReaderPage(
              novelId: 'novel:49:100',
              initialEpisodeId: episodeId,
            ),
          ),
        ),
      );
      await _pumpPagedCacheReady(tester);
      final pageElement = tester.element(find.byType(NovelReaderPage));
      final container = ProviderScope.containerOf(pageElement, listen: false);
      const oldArgs = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      const newArgs = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5002',
      );
      final oldController = container.read(
        novelReaderControllerProvider(oldArgs).notifier,
      );
      final oldSurface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      final oldCaches = _pagedSurfaceCaches(oldSurface);
      expect(oldSurface.paginationCache!.length, greaterThan(0));

      episode.value = newArgs.episodeId;
      await _pumpPagedCacheReady(tester);
      expect(tester.element(find.byType(NovelReaderPage)), same(pageElement));
      expect(
        container.read(novelReaderControllerProvider(newArgs).notifier),
        isNot(same(oldController)),
      );
      _expectPagedCachesClosed(oldSurface);
      final currentSurface = tester.widget<NovelReaderHtmlPagedSurface>(
        find.byType(NovelReaderHtmlPagedSurface),
      );
      expect(currentSurface.episode.episodeId, newArgs.episodeId);
      final currentCaches = _pagedSurfaceCaches(currentSurface);
      for (var index = 0; index < currentCaches.length; index++) {
        expect(currentCaches[index], isNot(same(oldCaches[index])));
      }
      _expectPagedCachesOpen(currentSurface);
      expect(currentSurface.paginationCache!.length, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      _expectPagedCachesClosed(currentSurface);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short paged chapter starts preparing during route entrance', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
    );
    late BuildContext hostContext;
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final route = PageRouteBuilder<void>(
      transitionDuration: const Duration(seconds: 1),
      pageBuilder: (_, _, _) => const NovelReaderPage(
        novelId: 'novel:49:100',
        initialEpisodeId: 'novel:49:100:5001',
      ),
    );
    unawaited(Navigator.of(hostContext).push(route));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byKey(const Key('novel-reader-delayed-loading-indicator')),
        findsNothing,
      );
    }
    expect(route.animation!.status, AnimationStatus.forward);
    expect(
      find.byKey(const Key('novel-reader-paged-page-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-surface')),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });
}
