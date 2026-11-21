part of 'novel_reader_page_test.dart';

void _dockActionsCases() {
  testWidgets('vertical chapter action opens body end and preserves position', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List.generate(40, (index) => '第 $index 段正文。'),
    );
    final locator = _ReaderPostLocator(tid: '100');
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        threadRepository: _FakeThreadRepository(targetPid: '5001'),
        threadPostLocator: locator,
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const Key('novel-reader-paragraph-list')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = position.pixels;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final action = find.byKey(
      const Key('novel-reader-chapter-interactions-button'),
    );
    expect(
      tester.widget<ReaderCornerDock>(find.byType(ReaderCornerDock)).visible,
      isTrue,
    );
    expect(action, findsOneWidget);
    final atAction = position.pixels;
    expect(atAction, greaterThanOrEqualTo(before));
    await tester.tap(action);
    await tester.pumpAndSettle();
    final detail = tester.widget<ThreadDetailPage>(
      find.byType(ThreadDetailPage),
    );
    expect(
      (detail.tid, detail.targetPid, detail.landing),
      ('100', '5001', ThreadPostLanding.bodyEnd),
    );
    expect(locator.calls, 1);
    Navigator.of(tester.element(find.byType(ThreadDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(atAction, 0.01));
  });

  testWidgets('paged final-page action returns to the same page', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
    );
    final locator = _ReaderPostLocator(tid: '100');
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        threadRepository: _FakeThreadRepository(targetPid: '5001'),
        threadPostLocator: locator,
      ),
    );
    await tester.pumpAndSettle();
    final before = _readingStatusTrailing(tester);
    final action = find.byKey(
      const Key('novel-reader-chapter-interactions-button'),
    );
    expect(action, findsOneWidget);
    expect(
      tester.getRect(action).bottom,
      lessThan(
        tester
            .getRect(
              find.byKey(const Key('shared-reader-persistent-status-bar')),
            )
            .top,
      ),
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    final detail = tester.widget<ThreadDetailPage>(
      find.byType(ThreadDetailPage),
    );
    expect(
      (detail.tid, detail.targetPid, detail.landing),
      ('100', '5001', ThreadPostLanding.bodyEnd),
    );
    Navigator.of(tester.element(find.byType(ThreadDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(_readingStatusTrailing(tester), before);
    expect(locator.calls, 1);
  });

  testWidgets('display switch hides only the dock without rebuilding pages', (
    tester,
  ) async {
    final dockRepository = _FakeNovelChapterDockRepository();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          preferences: NovelReaderPreferences.defaults().copyWith(
            flowMode: NovelReaderFlowMode.pagedLtr,
          ),
        ),
        dockRepository: dockRepository,
      ),
    );
    await tester.pumpAndSettle();
    const buttonKey = Key('novel-reader-chapter-interactions-button');
    expect(find.byKey(buttonKey), findsOneWidget);
    final page = tester.element(
      find.byKey(const Key('novel-reader-paged-page-session')),
    );
    final status = _readingStatusTrailing(tester);

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
    const switchKey = Key('novel-reader-chapter-interactions-dock-switch');
    await tester.tap(find.byKey(switchKey));
    await tester.pumpAndSettle();
    expect(dockRepository.current.enabled, isFalse);
    Navigator.of(
      tester.element(
        find.byKey(const Key('novel-reader-display-settings-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(buttonKey), findsNothing);
    expect(
      tester.element(find.byKey(const Key('novel-reader-paged-page-session'))),
      same(page),
    );
    expect(_readingStatusTrailing(tester), status);
    await _showReaderMenu(tester);
    expect(
      find.byKey(const Key('shared-reader-bottom-action-chapter-interactions')),
      findsOneWidget,
    );
  });

  testWidgets('novel dock long press snaps left without changing thread side', (
    tester,
  ) async {
    final dockRepository = _FakeNovelChapterDockRepository();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          preferences: NovelReaderPreferences.defaults().copyWith(
            flowMode: NovelReaderFlowMode.pagedLtr,
          ),
        ),
        dockRepository: dockRepository,
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(
      const Key('novel-reader-chapter-interactions-button'),
    );
    final initial = tester.getCenter(action);
    final gesture = await tester.startGesture(initial);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-650, -50));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dockRepository.current.side, ReaderCornerDockSide.left);
    expect(tester.getCenter(action).dx, lessThan(initial.dx));
  });

  testWidgets('failed novel dock move restores the saved side', (tester) async {
    final dockRepository = _FakeNovelChapterDockRepository(failSave: true);
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          preferences: NovelReaderPreferences.defaults().copyWith(
            flowMode: NovelReaderFlowMode.pagedLtr,
          ),
        ),
        dockRepository: dockRepository,
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(
      const Key('novel-reader-chapter-interactions-button'),
    );
    final initial = tester.getCenter(action);
    final gesture = await tester.startGesture(initial);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-650, -50));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dockRepository.current.side, ReaderCornerDockSide.right);
    expect(tester.getCenter(action).dx, initial.dx);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'vertical dock appears only within three quarters of a viewport',
    (tester) async {
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(
            firstParagraphs: List.generate(40, (i) => '第 $i 段正文。'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byKey(const Key('novel-reader-paragraph-list')),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      const buttonKey = Key('novel-reader-chapter-interactions-button');
      expect(find.byKey(buttonKey), findsNothing);
      position.jumpTo(
        position.maxScrollExtent - position.viewportDimension * 0.8,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(buttonKey), findsNothing);
      position.jumpTo(
        position.maxScrollExtent - position.viewportDimension * 0.7,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(buttonKey), findsOneWidget);
    },
  );

  testWidgets('chapter menu action coalesces taps and targets current pid', (
    tester,
  ) async {
    final locator = _ReaderPostLocator(tid: '100', pid: '5002')
      ..pending = Completer<ApiResult<ThreadPostLocation>>();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository.threeEpisodes(),
        initialEpisodeId: 'novel:49:100:5002',
        threadRepository: _FakeThreadRepository(targetPid: '5002'),
        threadPostLocator: locator,
      ),
    );
    await tester.pumpAndSettle();
    await _showReaderMenu(tester);
    final action = find.byKey(
      const Key('shared-reader-bottom-action-chapter-interactions'),
    );
    expect(
      find.byKey(const Key('shared-reader-top-action-chapter-interactions')),
      findsNothing,
    );
    expect(
      tester.getCenter(action).dx,
      lessThan(
        tester
            .getCenter(
              find.byKey(const Key('shared-reader-bottom-action-catalog')),
            )
            .dx,
      ),
    );
    final onPressed = tester.widget<prism_button.IconButton>(action).onPressed;
    onPressed!();
    onPressed();
    await tester.pump();
    expect(locator.calls, 1);
    locator.pending!.complete(locator.location);
    await tester.pumpAndSettle();
    final detail = tester.widget<ThreadDetailPage>(
      find.byType(ThreadDetailPage),
    );
    expect(
      (detail.tid, detail.targetPid, detail.landing),
      ('100', '5002', ThreadPostLanding.bodyEnd),
    );
  });

  testWidgets('chapter change discards late interactions location', (
    tester,
  ) async {
    final locator = _ReaderPostLocator(tid: '100')
      ..pending = Completer<ApiResult<ThreadPostLocation>>();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository.threeEpisodes(),
        threadPostLocator: locator,
        threadRepository: _FakeThreadRepository(targetPid: '5001'),
      ),
    );
    await tester.pumpAndSettle();
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-chapter-interactions')),
    );
    await tester.pump();
    expect(locator.calls, 1);
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('第2章').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('第2章').last);
    await tester.pumpAndSettle();
    locator.pending!.complete(locator.location);
    await tester.pumpAndSettle();
    expect(find.byType(ThreadDetailPage), findsNothing);
    expect(_readerText('第三段。'), findsOneWidget);
  });

  testWidgets('invalid chapter pid hides dedicated actions', (tester) async {
    final original = _FakeNovelRepository();
    final episode = original.episodes.first;
    final repository = _FakeNovelRepository(
      episodes: [
        NovelEpisodeItem(
          episodeId: episode.episodeId,
          novelId: episode.novelId,
          sourceTid: episode.sourceTid,
          episodeTitle: episode.episodeTitle,
          orderIndex: episode.orderIndex,
        ),
      ],
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('novel-reader-chapter-interactions-button')),
      findsNothing,
    );
    await _showReaderMenu(tester);
    expect(
      find.byKey(const Key('shared-reader-bottom-action-chapter-interactions')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('shared-reader-top-action-open-thread')),
      findsOneWidget,
    );
  });

  testWidgets('NovelReaderPage back button saves progress before pop', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List<String>.generate(30, (index) => '第一章段落 $index'),
    );
    await tester.pumpWidget(
      LocalizedTestApp(
        home: ProviderScope(
          overrides: [
            novelRepositoryProvider.overrideWithValue(repository),
            novelReaderPreferencesRepositoryProvider.overrideWithValue(
              _FakeNovelReaderPreferencesRepository(repository),
            ),
            forumImageRefererProvider.overrideWithValue(
              'https://bbs.yamibo.com/',
            ),
            libraryStateRepositoryProvider.overrideWithValue(
              _MemoryLibraryStateRepository(),
            ),
          ],
          child: const NovelReaderPage(
            novelId: 'novel:49:100',
            initialEpisodeId: 'novel:49:100:5001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('novel-reader-paragraph-list')),
      const Offset(0, -220),
    );
    await tester.pump();
    await _showReaderMenu(tester);

    await tester.tap(find.byKey(const Key('shared-reader-top-back-button')));
    await tester.pumpAndSettle();

    expect(repository.lastSavedOffset, greaterThan(0));
  });

  testWidgets('NovelReaderPage system pop saves progress before pop', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List<String>.generate(30, (index) => '第一章段落 $index'),
    );
    await tester.pumpWidget(
      LocalizedTestApp(
        home: ProviderScope(
          overrides: [
            novelRepositoryProvider.overrideWithValue(repository),
            novelReaderPreferencesRepositoryProvider.overrideWithValue(
              _FakeNovelReaderPreferencesRepository(repository),
            ),
            forumImageRefererProvider.overrideWithValue(
              'https://bbs.yamibo.com/',
            ),
            libraryStateRepositoryProvider.overrideWithValue(
              _MemoryLibraryStateRepository(),
            ),
          ],
          child: const NovelReaderPage(
            novelId: 'novel:49:100',
            initialEpisodeId: 'novel:49:100:5001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('novel-reader-paragraph-list')),
      const Offset(0, -220),
    );
    await tester.pump();

    final navigator = Navigator.of(
      tester.element(find.byType(NovelReaderPage)),
    );
    navigator.maybePop();
    await tester.pumpAndSettle();

    expect(repository.lastSavedOffset, greaterThan(0));
  });

  testWidgets('NovelReaderPage flushes progress when app goes inactive', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List<String>.generate(30, (index) => '第一章段落 $index'),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('novel-reader-paragraph-list')),
      const Offset(0, -220),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(repository.lastSavedOffset, greaterThan(0));
  });

  testWidgets('NovelReaderPage next chapter transition opens next episode', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-next-chapter-transition')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('novel-reader-next-chapter-button')));
    await tester.pumpAndSettle();

    expect(_readerText('第三段。'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(repository.readingProgress?.episodeId, 'novel:49:100:5002');
    expect(repository.readingProgress?.scrollOffset, 0);
    expect(repository.readingProgress?.progressPercent, 0);
  });

  testWidgets('NovelReaderPage turns chapters repeatedly by paged overscroll', (
    tester,
  ) async {
    // The gesture used to work exactly once per visit to the reader: the entry
    // request armed by the first turn was never retired, so it kept reporting a
    // turn as in flight forever.
    final repository = _FakeNovelRepository.threeEpisodes(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(_readerText('第一段。'), findsOneWidget);

    final pageView = find.byKey(const Key('novel-reader-paged-page-view'));
    await tester.drag(pageView, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(_readerText('第三段。'), findsOneWidget);

    await tester.drag(pageView, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(_readerText('第五段。'), findsOneWidget);
    expect(repository.readingProgress?.episodeId, 'novel:49:100:5003');
  });

  testWidgets(
    'NovelReaderPage paged overscroll returns to the previous chapter',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
      );
      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          initialEpisodeId: 'novel:49:100:5002',
        ),
      );
      await tester.pumpAndSettle();

      expect(_readerText('第三段。'), findsOneWidget);

      final pageView = find.byKey(const Key('novel-reader-paged-page-view'));
      await tester.drag(pageView, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(_readerText('第一段。'), findsOneWidget);

      // And forward again from there, proving neither direction latches.
      await tester.drag(pageView, const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(_readerText('第三段。'), findsOneWidget);
    },
  );

  testWidgets('NovelReaderPage hides next chapter transition on last episode', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        initialEpisodeId: 'novel:49:100:5003',
      ),
    );
    await tester.pumpAndSettle();

    expect(_readerText('第五段。'), findsOneWidget);
    await _showReaderMenu(tester);
    expect(find.byKey(const Key('shared-reader-prev-button')), findsOneWidget);
    expect(find.byKey(const Key('shared-reader-next-button')), findsOneWidget);
    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-prev-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-next-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const Key('novel-reader-next-chapter-transition')),
      findsNothing,
    );
  });

  testWidgets('NovelReaderPage opens thread links from reader document', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          firstRawHtml:
              '<p><a href="forum.php?mod=viewthread&amp;tid=200">跳转原帖</a></p>',
          firstParagraphs: const <String>['跳转原帖'],
        ),
        threadRepository: _FakeThreadRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final linkText = _readerText('跳转原帖');
    await tester.tapAt(tester.getTopLeft(linkText) + const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(ThreadDetailPage), findsOneWidget);
  });

  for (final flowMode in [
    NovelReaderFlowMode.vertical,
    NovelReaderFlowMode.pagedLtr,
  ]) {
    testWidgets('reader external links are copied in ${flowMode.name}', (
      tester,
    ) async {
      const url = 'https://elsewhere.test/read?a=1&a=2#section';
      final clipboard = _ClipboardWriter();
      final launcher = _FakeForumWebViewExternalLauncher();
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(
            preferences: NovelReaderPreferences.defaults().copyWith(
              flowMode: flowMode,
            ),
            firstRawHtml: '<p><a href="https://elsewhere.test/read?a=1&amp;a=2#section">External link</a></p>',
            firstParagraphs: const ['External link'],
          ),
          clipboardWriter: clipboard,
          externalLauncher: launcher,
        ),
      );
      if (flowMode == NovelReaderFlowMode.vertical) {
        await tester.pumpAndSettle();
      } else {
        await _pumpPagedCacheReady(tester);
      }
      await tester.tapAt(
        tester.getTopLeft(_readerText('External link')) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      expect(clipboard.writes, [url]);
      expect(launcher.opened, isEmpty);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NovelReaderPage)),
      );
      expect(find.text(l10n.linkCopied), findsOneWidget);
      expect(find.byType(ThreadDetailPage), findsNothing);
    });
  }

  testWidgets('reader keeps the existing same-site non-thread fallback', (
    tester,
  ) async {
    const url = 'https://bbs.yamibo.com/misc.php?mod=tag&id=28';
    final clipboard = _ClipboardWriter();
    final launcher = _FakeForumWebViewExternalLauncher();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          firstRawHtml: '<p><a href="https://bbs.yamibo.com/misc.php?mod=tag&amp;id=28">Forum tag</a></p>',
          firstParagraphs: const ['Forum tag'],
        ),
        clipboardWriter: clipboard,
        externalLauncher: launcher,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(_readerText('Forum tag')) + const Offset(8, 8),
    );
    await tester.pumpAndSettle();
    expect(launcher.opened, [Uri.parse(url)]);
    expect(clipboard.writes, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reader discards late copy feedback after changing chapters', (
    tester,
  ) async {
    final clipboard = _ClipboardWriter()..pending = Completer<void>();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          firstRawHtml:
              '<p><a href="https://elsewhere.test/read">External link</a></p>',
          firstParagraphs: const ['External link'],
        ),
        clipboardWriter: clipboard,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(_readerText('External link')) + const Offset(8, 8),
    );
    await tester.pump();
    expect(clipboard.writes, ['https://elsewhere.test/read']);
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('第2章').last);
    await tester.pumpAndSettle();
    clipboard.pending!.complete();
    await tester.pumpAndSettle();
    expect(_readerText('第三段。'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final filtered in [false, true]) {
    testWidgets(
      'reader floor link preserves identity and return position filtered=$filtered',
      (tester) async {
        final locator = _ReaderPostLocator();
        final repository = _FakeNovelRepository(
          firstRawHtml:
              '<p><a href="forum.php?mod=viewthread&amp;tid=200&amp;page=4${filtered ? '&amp;authorid=10&amp;ordertype=1' : ''}#pid5001">Target floor</a></p>'
              '${List.filled(80, '<p>Chapter body.</p>').join()}',
          firstParagraphs: const ['Target floor'],
        );
        await tester.pumpWidget(
          _buildReaderApp(
            repository: repository,
            threadRepository: _FakeThreadRepository(targetPid: '5001'),
            threadPostLocator: locator,
          ),
        );
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: find.byKey(const Key('novel-reader-paragraph-list')),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        final before = position.pixels;
        await tester.tapAt(
          tester.getTopLeft(_readerText('Target floor')) + const Offset(8, 8),
        );
        await tester.pumpAndSettle();
        final page = tester.widget<ThreadDetailPage>(
          find.byType(ThreadDetailPage),
        );
        expect(page.tid, '200');
        expect(page.targetPid, '5001');
        expect(page.initialPage, filtered ? 2 : 4);
        expect(locator.calls, filtered ? 1 : 0);
        Navigator.of(tester.element(find.byType(ThreadDetailPage))).pop();
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(before, 0.01));
        expect(find.byType(NovelReaderPage), findsOneWidget);
      },
    );
  }

  testWidgets(
    'reader double click opens once and chapter switch discards late location',
    (tester) async {
      final locator = _ReaderPostLocator()
        ..pending = Completer<ApiResult<ThreadPostLocation>>();
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(
            firstRawHtml: '<p><a href="forum.php?mod=redirect&amp;goto=findpost&amp;ptid=200&amp;pid=5001">Target floor</a></p>',
            firstParagraphs: const ['Target floor'],
          ),
          threadPostLocator: locator,
          threadRepository: _FakeThreadRepository(targetPid: '5001'),
        ),
      );
      await tester.pumpAndSettle();
      final point =
          tester.getTopLeft(_readerText('Target floor')) + const Offset(8, 8);
      await tester.tapAt(point);
      await tester.tapAt(point);
      await tester.pump();
      expect(locator.calls, 1);
      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-catalog')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('第2章').last);
      await tester.pumpAndSettle();
      locator.pending!.complete(locator.location);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadDetailPage), findsNothing);
      expect(_readerText('第三段。'), findsOneWidget);
    },
  );

  testWidgets('NovelReaderPage toggles episode bookmark', (tester) async {
    final repository = _FakeNovelRepository.threeEpisodes();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-top-action-bookmark')),
    );
    await tester.pumpAndSettle();

    expect(
      repository.bookmarks.map((bookmark) => bookmark.bookmarkId),
      contains('episode-bookmark:novel:49:100:5001'),
    );
  });

  testWidgets('NovelReaderPage catalog shows bookmark badge', (tester) async {
    final repository = _FakeNovelRepository.threeEpisodes();
    repository.bookmarks.add(
      NovelReaderBookmark(
        bookmarkId: 'episode-bookmark:novel:49:100:5001',
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
        anchor: const NovelReaderTextAnchor(episodeId: 'novel:49:100:5001'),
        title: '第1章',
        snippet: '章节书签',
        createdAt: DateTime(2026, 6, 8),
        updatedAt: DateTime(2026, 6, 8),
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    final reader = tester.element(
      find.byKey(const Key('novel-reader-paragraph-list')),
    );
    await _showReaderMenu(tester);
    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-chapter-bookmark-novel:49:100:5001')),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('reader-chapter-panel-tabs'))),
    );
    await tester.tap(find.text(l10n.readerBookmarks));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('novel-reader-bookmark-episode-bookmark:novel:49:100:5001'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'novel-reader-bookmark-delete-episode-bookmark:novel:49:100:5001',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('novel-reader-chapter-novel:49:100:5002')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('adaptive-panel-close')));
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byKey(const Key('novel-reader-paragraph-list'))),
      same(reader),
    );
  });

  testWidgets('NovelReaderPage has no duplicate chapter cache action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReaderApp(repository: _FakeNovelRepository()),
    );
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);

    expect(
      find.byKey(const Key('shared-reader-bottom-action-cache')),
      findsNothing,
    );
    expect(find.text('缓存'), findsNothing);
  });

  testWidgets('NovelReaderPage renders hydrated repository content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReaderApp(
        repository: _FakeNovelRepository(
          firstRawHtml: '<h2>水合标题</h2><p>水合正文。</p>',
          firstParagraphs: const <String>['水合标题', '水合正文。'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_readerText('水合标题'), findsOneWidget);
    expect(_readerText('水合正文。'), findsOneWidget);
    expect(
      find.byKey(const Key('novel-reader-html-document-view')),
      findsOneWidget,
    );
  });

  testWidgets('NovelReaderPage error view can update the work', (tester) async {
    final repository = _FakeNovelRepository(
      contentsByEpisodeId: const <String, NovelChapterContent>{},
    );
    final updateService = _RecordingNovelChapterUpdateService();
    await tester.pumpWidget(
      _buildReaderApp(
        repository: repository,
        chapterUpdateService: updateService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('novel-reader-error-view')), findsOneWidget);
    await tester.tap(find.byKey(const Key('novel-reader-error-update-work')));
    await tester.pumpAndSettle();

    expect(updateService.novelIds, <String>['novel:49:100']);
    expect(find.text('更新作品'), findsOneWidget);
  });

  testWidgets(
    'NovelReaderPage large document build delay still enters reader',
    (tester) async {
      final repository = _FakeNovelRepository(
        firstRawHtml: '<p>${List<String>.filled(15000, '文').join()}</p>',
        firstParagraphs: const <String>['大章节正文'],
      );
      final documentBuildService = _DelayedNovelReaderDocumentBuildService(
        const Duration(milliseconds: 120),
      );

      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          documentBuildService: documentBuildService,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('novel-reader-delayed-loading-indicator')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump();

      expect(
        find.byKey(const Key('novel-reader-paragraph-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('novel-reader-html-document-view')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'NovelReaderPage chapter sheet updates bookmark badge after late hydration',
    (tester) async {
      final repository = _FakeNovelRepository.threeEpisodes();
      final hydrationService =
          _ControlledNovelReaderSupplementalHydrationService();

      await tester.pumpWidget(
        _buildReaderApp(
          repository: repository,
          supplementalHydrationService: hydrationService,
        ),
      );
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-catalog')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('novel-reader-chapter-bookmark-novel:49:100:5001'),
        ),
        findsNothing,
      );

      hydrationService.completeBookmarks(<NovelReaderBookmark>[
        NovelReaderBookmark(
          bookmarkId: 'episode-bookmark:novel:49:100:5001',
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5001',
          anchor: const NovelReaderTextAnchor(episodeId: 'novel:49:100:5001'),
          title: '章节书签',
          snippet: '章节书签',
          createdAt: DateTime(2026, 6, 8),
          updatedAt: DateTime(2026, 6, 8),
        ),
      ]);
      hydrationService.completeNovelTitle('测试小说');
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('novel-reader-chapter-bookmark-novel:49:100:5001'),
        ),
        findsOneWidget,
      );
    },
  );
}
