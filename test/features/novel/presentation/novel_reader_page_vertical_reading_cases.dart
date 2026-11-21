part of 'novel_reader_page_test.dart';

void _verticalReadingCases() {
  for (final (fraction, chunked) in [
    (0.5, false),
    (1.0, false),
    (0.5, true),
    (1.0, true),
  ]) {
    testWidgets(
      'vertical resume $fraction chunks=$chunked reveals only its settled position',
      (tester) async {
        final repository = _FakeNovelRepository(
          firstRawHtml: chunked
              ? List.generate(
                  400,
                  (index) => 'fixture-$index ${'正文保留🙂' * 12}<br><br>',
                ).join()
              : null,
          firstParagraphs: List.generate(
            80,
            (index) => 'fixture $index ${'正文' * (index < 10 ? 2 : 20)}',
          ),
          readingProgress: NovelReadingProgress(
            novelId: 'novel:49:100',
            episodeId: 'novel:49:100:5001',
            scrollOffset: 10,
            progressPercent: fraction,
            updatedAt: DateTime(2026),
          ),
        );
        final originalProgress = repository.readingProgress;
        final originalSaveCount = repository.savedProgressOffsets.length;
        await tester.pumpWidget(_buildReaderApp(repository: repository));
        double? firstVisibleOffset;
        var visibleFrames = 0;
        for (var frame = 0; frame < 300 && visibleFrames < 20; frame++) {
          // The semantic document can be built on a real worker isolate.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          final finder = find.descendant(
            of: find.byKey(const Key('novel-reader-paragraph-list')),
            matching: find.byType(Scrollable),
          );
          if (finder.evaluate().isEmpty ||
              find
                  .byKey(const Key('novel-reader-delayed-loading-surface'))
                  .evaluate()
                  .isNotEmpty) {
            continue;
          }
          final position = tester.state<ScrollableState>(finder).position;
          if (fraction == 1) {
            expect(position.pixels, closeTo(position.maxScrollExtent, 1));
          } else {
            // HTML margins are separate sliver children. Their active-range
            // average can change the lazy total-height estimate even when the
            // visible position is settled; it is not an exact chapter height.
            expect(
              position.pixels,
              greaterThan(originalProgress!.scrollOffset),
            );
            expect(position.pixels, lessThan(position.maxScrollExtent));
          }
          expect(position.isScrollingNotifier.value, isFalse);
          firstVisibleOffset ??= position.pixels;
          expect(position.pixels, closeTo(firstVisibleOffset, 0.01));
          visibleFrames++;
        }
        expect(visibleFrames, 20);
        expect(firstVisibleOffset, isNotNull);
        expect(firstVisibleOffset, greaterThan(0));
        expect(repository.readingProgress, same(originalProgress));
        expect(repository.savedProgressOffsets, hasLength(originalSaveCount));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('NovelReaderPage shows immersive menu from center tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReaderApp(repository: _FakeNovelRepository()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-paragraph-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-episode-selector')),
      findsNothing,
    );

    var topGate = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(topGate.ignoring, isTrue);

    await _showReaderMenu(tester);

    topGate = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(topGate.ignoring, isFalse);
    expect(find.text('测试小说'), findsOneWidget);
    final subtitle = tester.widget<Text>(
      find.byKey(const Key('shared-reader-top-subtitle')),
    );
    expect(subtitle.data, '第1章');
  });

  testWidgets('vertical side taps turn pages and keep rapid taps distinct', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          firstParagraphs: List<String>.generate(40, (index) => '第一章段落 $index'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position = _verticalPosition(tester);
    final start = position.pixels;
    expect(start, closeTo(0, 0.01));

    await tester.tapAt(const Offset(650, 300));
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pumpAndSettle();

    final afterFirst = position.pixels;
    expect(afterFirst, greaterThan(start));

    await tester.tapAt(const Offset(650, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(const Offset(650, 300));
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pumpAndSettle();

    final afterRapid = position.pixels;
    expect(afterRapid, greaterThan(afterFirst));

    await tester.tapAt(const Offset(130, 300));
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pumpAndSettle();

    expect(position.pixels, lessThan(afterRapid));
  });

  testWidgets('novel reader enters immersive mode and restores on disposal', (
    tester,
  ) async {
    final systemUi = _RecordingReaderSystemUiController();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(),
        systemUiController: systemUi,
      ),
    );
    await tester.pumpAndSettle();
    expect(systemUi.enterCount, greaterThan(0));
    expect(systemUi.immersive, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(systemUi.restoreCount, greaterThan(0));
    expect(systemUi.immersive, isFalse);
  });

  testWidgets(
    'novel reader restores system bars while a page route covers it',
    (tester) async {
      final systemUi = _RecordingReaderSystemUiController();
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(),
          systemUiController: systemUi,
        ),
      );
      await tester.pumpAndSettle();
      expect(systemUi.immersive, isTrue);

      final navigator = Navigator.of(
        tester.element(find.byType(NovelReaderPage)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('覆盖页面')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(systemUi.immersive, isFalse);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(systemUi.immersive, isTrue);
    },
  );

  testWidgets(
    'vertical reading window respects the top inset and updates the footer',
    (tester) async {
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(
            firstParagraphs: List<String>.generate(
              40,
              (index) => '安全区段落 $index ${List<String>.filled(20, '正文').join()}',
            ),
          ),
          safeArea: const EdgeInsets.only(top: 24, bottom: 18),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('novel-reader-paragraph-list'));
      expect(tester.getTopLeft(list).dy, greaterThanOrEqualTo(24));
      expect(
        find.byKey(const Key('shared-reader-persistent-status-bar')),
        findsOneWidget,
      );
      final before = _readingStatusTrailing(tester);
      expect(before, contains('本章'));
      expect(before, contains('剩'));

      final scroll = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      final viewport = scroll.viewportDimension;
      final start = scroll.pixels;
      await tester.tapAt(const Offset(650, 300));
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pumpAndSettle();

      final delta = scroll.pixels - start;
      // 滚动模式与翻页模式一致，一次推进一个完整视口。
      expect(delta, closeTo(viewport, 0.5));
      expect(_readingStatusTrailing(tester), isNot(before));
      expect(
        tester
            .getBottomLeft(
              find.byKey(const Key('shared-reader-persistent-status-trailing')),
            )
            .dy,
        lessThanOrEqualTo(tester.getSize(find.byType(Scaffold)).height - 18),
      );
    },
  );

  testWidgets('paged page content fills the reading window above the footer', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
      firstParagraphs: <String>['${List.filled(2000, '正文内容').join()}。'],
      firstRawHtml: '<p>${List.filled(2000, '正文内容').join()}。</p>',
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await _pumpPagedCacheReady(tester);

    final pageView = find.byKey(const Key('novel-reader-paged-page-view'));
    final pageBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('novel-reader-paged-page-0')),
    );
    final content = find.descendant(
      of: pageView,
      matching: find.byType(ForumHtmlWidgetPostRenderer),
    );
    final contentBox = tester.renderObject<RenderBox>(content.first);
    expect(contentBox.size.height, closeTo(pageBox.size.height, 2));
    expect(
      find.byKey(const Key('shared-reader-persistent-status-bar')),
      findsOneWidget,
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
  });

  testWidgets('NovelReaderPage hides menu after content scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          firstParagraphs: List<String>.generate(30, (index) => '第一章段落 $index'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);

    var topGate = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(topGate.ignoring, isFalse);

    await tester.drag(
      find.byKey(const Key('novel-reader-paragraph-list')),
      const Offset(0, -180),
    );
    await tester.pump();

    topGate = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(topGate.ignoring, isTrue);
  });

  testWidgets(
    'NovelReaderPage first drag does not get reset by restore logic',
    (tester) async {
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(
            firstParagraphs: List<String>.generate(
              30,
              (index) => '第一章段落 $index',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('novel-reader-paragraph-list'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);

      await tester.drag(list, const Offset(0, -80));
      await tester.pumpAndSettle();

      final scrollableState = tester.state<ScrollableState>(scrollable);
      final firstOffset = scrollableState.position.pixels;
      expect(firstOffset, greaterThan(0));

      await tester.drag(list, const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('novel-reader-paragraph-list')),
        findsOneWidget,
      );
      expect(scrollableState.position.pixels, greaterThan(firstOffset));
    },
  );

  testWidgets(
    'NovelReaderPage restores vertical progress after HTML content is ready',
    (tester) async {
      final repository = _FakeNovelRepository(
        firstParagraphs: List<String>.generate(
          60,
          (index) => '第一章恢复测试段落 $index',
        ),
        readingProgress: NovelReadingProgress(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5001',
          scrollOffset: 320,
          updatedAt: DateTime(2026, 7, 21),
          progressPercent: 0.25,
        ),
      );

      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byKey(const Key('novel-reader-paragraph-list')),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;

      expect(position.maxScrollExtent, greaterThan(320));
      final expectedOffset = position.maxScrollExtent * 0.25;
      expect(position.pixels, closeTo(expectedOffset, 0.01));
      // Passive layout restoration preserves the original persisted record.
      await tester.pump(const Duration(seconds: 1));
      expect(repository.readingProgress?.scrollOffset, 320);
    },
  );

  testWidgets(
    'old vertical callbacks cannot project into a rebuilt provider before paint',
    (tester) async {
      final repository = _FakeNovelRepository(
        firstParagraphs: List.generate(
          80,
          (index) => '恢复隔离正文 $index ${'正文' * 12}',
        ),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await _pumpVerticalReaderReady(tester);
      final oldHtml = tester.widget<NovelReaderHtmlDocumentView>(
        find.byType(NovelReaderHtmlDocumentView),
      );
      final oldPosition = _verticalPosition(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelReaderPage)),
        listen: false,
      );
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      repository.readingProgress = NovelReadingProgress(
        novelId: args.novelId,
        episodeId: args.episodeId,
        scrollOffset: 444,
        progressPercent: 0.4,
        updatedAt: DateTime(2026),
      );
      container.invalidate(provider);
      final rebuilt = (await tester.runAsync(
        () => container.read(provider.future),
      ))!;

      // Provider state has changed, while the old viewport has not rebuilt yet.
      oldPosition.jumpTo(60);
      oldHtml.onContentReady?.call();
      oldHtml.onContentTerminal?.call();
      expect(
        container.read(provider).value!.progressSnapshot,
        rebuilt.progressSnapshot,
      );
      expect(
        container.read(provider).value!.readingProgress,
        rebuilt.readingProgress,
      );

      await _pumpVerticalReaderReady(tester);
      final position = _verticalPosition(tester);
      expect(position.pixels, closeTo(position.maxScrollExtent * 0.4, 1));
      expect(
        find.byKey(const Key('novel-reader-delayed-loading-surface')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed vertical chapter switch restores the visible offset and resumes progress',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes(
        firstParagraphs: List.generate(
          80,
          (index) => '失败恢复正文 $index ${'正文' * 12}',
        ),
        failedEpisodeIds: const {'novel:49:100:5002'},
        chapterLoadDelay: const Duration(milliseconds: 120),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await _pumpVerticalReaderReady(tester);
      final failure = AppLocalizations.of(
        tester.element(find.byType(NovelReaderPage)),
      ).novelChapterSwitchFailed;
      await tester.drag(
        find.byKey(const Key('novel-reader-paragraph-list')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      final before = _verticalPosition(tester).pixels;
      expect(before, greaterThan(0));
      repository.savedProgressOffsets.clear();

      await _showReaderMenu(tester);
      await tester.tap(find.byKey(const Key('shared-reader-next-button')));
      await tester.pumpAndSettle();
      expect(_verticalPosition(tester).pixels, closeTo(before, 0.01));
      expect(find.text(failure), findsOneWidget);
      expect(
        find.byKey(const Key('novel-reader-delayed-loading-surface')),
        findsNothing,
      );
      expect(repository.savedProgressOffsets, everyElement(greaterThan(0)));

      await tester.drag(
        find.byKey(const Key('novel-reader-paragraph-list')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      final after = _verticalPosition(tester).pixels;
      expect(after, greaterThan(before));
      expect(repository.readingProgress?.scrollOffset, closeTo(after, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'returning to the same chapter does not revive its old ready callback',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes(
        firstParagraphs: List.generate(
          80,
          (index) => '往返隔离正文 $index ${'正文' * 12}',
        ),
      );
      final committer = _ControlledPageProgressCommitter(
        repository,
        forwardScheduledCommits: true,
      );
      await tester.pumpWidget(
        _buildReaderApp(repository: repository, progressCommitter: committer),
      );
      await _pumpVerticalReaderReady(tester);
      await tester.drag(
        find.byKey(const Key('novel-reader-paragraph-list')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_verticalPosition(tester).pixels, greaterThan(0));
      expect(repository.readingProgress?.scrollOffset, greaterThan(0));
      final oldHtml = tester.widget<NovelReaderHtmlDocumentView>(
        find.byType(NovelReaderHtmlDocumentView),
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
      committer.autoCompleteFlushes = true;
      // Withdraw the old producer while replacing the chapter twice. The
      // stale callbacks must not revive that retired surface afterwards.
      controller.updateReadingVisibility(frontmost: false, resumed: true);
      expect(
        await tester.runAsync(
          () => controller.openEpisodeFromCatalog('novel:49:100:5002'),
        ),
        isTrue,
      );
      expect(
        await tester.runAsync(
          () => controller.openEpisodeFromCatalog('novel:49:100:5001'),
        ),
        isTrue,
      );
      controller.updateReadingVisibility(frontmost: true, resumed: true);
      final flushesBeforeLateCallback = committer.flushes.length;
      oldHtml.onContentReady?.call();
      oldHtml.onContentTerminal?.call();
      expect(committer.flushes, hasLength(flushesBeforeLateCallback));

      await _pumpVerticalReaderReady(tester);
      for (final flush in committer.flushes) {
        flush.complete();
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_verticalPosition(tester).pixels, greaterThan(0));
      expect(
        container.read(provider).value!.progressSnapshot.scrollOffset,
        greaterThan(0),
      );
      expect(repository.readingProgress?.scrollOffset, greaterThan(0));
      expect(
        container.read(provider).value!.currentEpisode.episodeId,
        'novel:49:100:5001',
      );
      expect(
        find.byKey(const Key('novel-reader-delayed-loading-surface')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late pre-switch flush cannot advance a different chapter', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes();
    final committer = _ControlledPageProgressCommitter(repository);
    await tester.pumpWidget(
      _buildReaderApp(repository: repository, progressCommitter: committer),
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
    committer.flushes.clear();
    committer.autoCompleteFlushes = false;
    await _showReaderMenu(tester);
    await tester.tap(find.byKey(const Key('shared-reader-next-button')));
    await tester.pump();
    expect(committer.flushes, hasLength(1));
    // A covered producer loses save authority. A newer navigation can replace
    // the surface while the page still awaits its older flush.
    container
        .read(provider.notifier)
        .updateReadingVisibility(frontmost: false, resumed: true);
    expect(
      await container
          .read(provider.notifier)
          .openEpisodeFromCatalog('novel:49:100:5002'),
      isTrue,
    );
    container
        .read(provider.notifier)
        .updateReadingVisibility(frontmost: true, resumed: true);
    await tester.pumpAndSettle();
    committer.flushes.first.complete();
    await tester.pumpAndSettle();
    for (final flush in committer.flushes) {
      flush.complete();
    }
    await tester.pumpAndSettle();

    expect(
      container.read(provider).value!.currentEpisode.episodeId,
      'novel:49:100:5002',
    );
    expect(
      repository.chapterLoadEpisodeIds,
      isNot(contains('novel:49:100:5003')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposed page does not switch after its progress flush completes',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes();
      final committer = _ControlledPageProgressCommitter(repository);
      await tester.pumpWidget(
        _buildReaderApp(repository: repository, progressCommitter: committer),
      );
      await tester.pumpAndSettle();
      committer.flushes.clear();
      committer.autoCompleteFlushes = false;
      await _showReaderMenu(tester);
      await tester.tap(find.byKey(const Key('shared-reader-next-button')));
      await tester.pump();
      expect(committer.flushes, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      committer.flushes.first.complete();
      await tester.pumpAndSettle();
      expect(
        repository.chapterLoadEpisodeIds,
        isNot(contains('novel:49:100:5002')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late failed chapter switch stays silent on a newer chapter', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes(
      failedEpisodeIds: const {'novel:49:100:5002'},
    );
    final chapterGate = Completer<void>();
    repository.chapterLoadGates['novel:49:100:5002'] = chapterGate;
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(NovelReaderPage));
    final failure = AppLocalizations.of(context).novelChapterSwitchFailed;
    final container = ProviderScope.containerOf(context, listen: false);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    await _showReaderMenu(tester);
    await tester.tap(find.byKey(const Key('shared-reader-next-button')));
    await tester.pump();
    await tester.pump();
    expect(repository.chapterLoadEpisodeIds, contains('novel:49:100:5002'));

    expect(
      await container
          .read(provider.notifier)
          .openEpisodeFromCatalog('novel:49:100:5003'),
      isTrue,
    );
    await tester.pumpAndSettle();
    chapterGate.complete();
    await tester.pumpAndSettle();
    expect(
      container.read(provider).value!.currentEpisode.episodeId,
      'novel:49:100:5003',
    );
    expect(find.text(failure), findsNothing);
    expect(
      find.byKey(const Key('novel-reader-delayed-loading-surface')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('old vertical seek completion cannot unlock a newer seek', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List.generate(
        80,
        (index) => '定位隔离正文 $index ${'正文' * 12}',
      ),
    );
    final committer = _ControlledPageProgressCommitter(repository);
    await tester.pumpWidget(
      _buildReaderApp(repository: repository, progressCommitter: committer),
    );
    await _pumpVerticalReaderReady(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NovelReaderPage)),
      listen: false,
    );
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    committer.flushes.clear();
    committer.autoCompleteFlushes = false;
    await _showReaderMenu(tester);
    tester
        .widget<Slider>(find.byKey(const Key('shared-reader-progress-slider')))
        .onChangeEnd!(0.2);
    await tester.pump();
    expect(committer.flushes, hasLength(1));

    container.invalidate(provider);
    await tester.runAsync(() => container.read(provider.future));
    await _pumpVerticalReaderReady(tester);
    await _showReaderMenu(tester);
    tester
        .widget<Slider>(find.byKey(const Key('shared-reader-progress-slider')))
        .onChangeEnd!(0.7);
    await tester.pump();
    expect(committer.flushes.last.snapshot.progressPercent, closeTo(0.7, 0.01));
    // A new readable bootstrap may also queue zero before the seek. Release
    // that older revision while keeping the new seek's save blocked.
    for (final flush in committer.flushes.skip(1)) {
      if (flush.snapshot.progressPercent == 0) flush.complete();
    }
    committer.flushes.first.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AbsorbPointer>(
            find
                .ancestor(
                  of: find.byKey(const Key('shared-reader-progress-slider')),
                  matching: find.byType(AbsorbPointer),
                )
                .first,
          )
          .absorbing,
      isTrue,
    );
    expect(
      container.read(provider).value!.progressSnapshot.progressPercent,
      closeTo(0.7, 0.01),
    );

    committer.flushes.last.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AbsorbPointer>(
            find
                .ancestor(
                  of: find.byKey(const Key('shared-reader-progress-slider')),
                  matching: find.byType(AbsorbPointer),
                )
                .first,
          )
          .absorbing,
      isFalse,
    );
    expect(repository.readingProgress?.progressPercent, closeTo(0.7, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'vertical progress survives exit and a new continue-reading session',
    (tester) async {
      final repository = _FakeNovelRepository(
        firstParagraphs: List<String>.generate(
          60,
          (index) => '第一章往返测试段落 $index',
        ),
      );
      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          home: const _NovelReaderRoundTripHost(),
        ),
      );

      await tester.tap(find.byKey(const Key('open-novel-from-beginning')));
      await tester.pumpAndSettle();
      await _showReaderMenu(tester);
      final firstSlider = tester.widget<Slider>(
        find.byKey(const Key('shared-reader-progress-slider')),
      );
      firstSlider.onChangeStart?.call(0.59);
      firstSlider.onChanged?.call(0.59);
      firstSlider.onChangeEnd?.call(0.59);
      await tester.pumpAndSettle();

      expect(repository.readingProgress?.progressPercent, closeTo(0.59, 0.01));
      final savedOffset = repository.readingProgress!.scrollOffset;
      expect(savedOffset, greaterThan(0));

      await tester.tap(find.byKey(const Key('shared-reader-top-back-button')));
      await tester.pumpAndSettle();
      expect(find.byType(NovelReaderPage), findsNothing);
      final saved = repository.readingProgress!;
      // Seeking lays out previously estimated sliver children. Exit records the
      // final visible position, whose percentage can refine from the slider's.
      expect(saved.progressPercent, closeTo(0.59, 0.01));
      final savedCount = repository.savedProgressOffsets.length;

      await tester.tap(find.byKey(const Key('continue-novel-reading')));
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byKey(const Key('novel-reader-paragraph-list')),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      // The legacy repository port retains the existing whole-layout basis.
      expect(
        position.pixels,
        closeTo(position.maxScrollExtent * saved.progressPercent, 0.01),
      );
      expect(repository.readingProgress, same(saved));
      expect(repository.readingProgress!.updatedAt, saved.updatedAt);
      expect(repository.savedProgressOffsets, hasLength(savedCount));

      await _showReaderMenu(tester);
      expect(find.text('59%'), findsOneWidget);
    },
  );
}
