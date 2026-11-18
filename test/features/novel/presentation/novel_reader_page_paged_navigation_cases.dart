part of 'novel_reader_page_test.dart';

void _pagedNavigationCases() {
  testWidgets('NovelReaderPage turns paged LTR content from side taps', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
      firstParagraphs: List<String>.generate(
        36,
        (index) => '点击翻页段落 $index ${List<String>.filled(120, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(_readingStatusTrailing(tester), contains('第 1 /'));
    await tester.tapAt(const Offset(720, 300));
    await tester.pump(
      ReaderPagedTurnMotion.tapConfirmationDelay -
          const Duration(milliseconds: 1),
    );
    expect(_readingStatusTrailing(tester), contains('第 1 /'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(ReaderPagedTurnMotion.animationDuration);
    await tester.pumpAndSettle();
    expect(_readingStatusTrailing(tester), contains('第 2 /'));

    await _tapPagedReaderZone(tester, const Offset(80, 300));
    expect(_readingStatusTrailing(tester), contains('第 1 /'));
  });

  testWidgets('NovelReaderPage reverses side tap mapping in paged RTL', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedRtl,
      ),
      firstParagraphs: List<String>.generate(
        36,
        (index) => 'RTL 点击段落 $index ${List<String>.filled(120, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _tapPagedReaderZone(tester, const Offset(80, 300));
    expect(_readingStatusTrailing(tester), contains('第 2 /'));

    await _tapPagedReaderZone(tester, const Offset(720, 300));
    expect(_readingStatusTrailing(tester), contains('第 1 /'));
  });

  testWidgets('NovelReaderPage center tap still toggles paged chrome only', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
      firstParagraphs: List<String>.generate(
        20,
        (index) => '菜单段落 $index ${List<String>.filled(80, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    await _showReaderMenu(tester);

    final topGate = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(topGate.ignoring, isFalse);
    expect(_readingStatusTrailing(tester), contains('第 1 /'));
  });

  testWidgets('NovelReaderPage side taps continue across chapter boundaries', (
    tester,
  ) async {
    final repository = _FakeNovelRepository.threeEpisodes(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(_readerText('第一段。'), findsOneWidget);
    await _tapPagedReaderZone(tester, const Offset(720, 300));
    expect(_readerText('第三段。'), findsOneWidget);

    await _tapPagedReaderZone(tester, const Offset(80, 300));
    expect(_readerText('第一段。'), findsOneWidget);
  });

  testWidgets(
    'NovelReaderPage exposes paged semantics and mounts nearby pages only',
    (tester) async {
      final repository = _FakeNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
        firstParagraphs: List<String>.generate(
          40,
          (index) => '语义分页段落 $index ${List<String>.filled(120, '正文').join()}',
        ),
      );
      await tester.pumpWidget(_buildReaderApp(repository: repository));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('novel-reader-paged-semantics')),
      );
      expect(semantics.label, contains('第 1 页'));
      final mountedPages = find
          .byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith('novel-reader-paged-page-');
          })
          .evaluate()
          .length;
      expect(mountedPages, lessThan(6));
    },
  );

  testWidgets('NovelReaderPage vertical mode does not bind paged view', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      firstParagraphs: List<String>.generate(
        18,
        (index) => '滚动段落 $index ${List<String>.filled(70, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-paragraph-list')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('novel-reader-paged-page-view')), findsNothing);

    await tester.tapAt(const Offset(720, 300));
    await tester.pumpAndSettle();

    expect(repository.readingProgress?.pageIndex ?? 0, 0);
  });

  testWidgets('NovelReaderPage keeps logical first page in RTL mode', (
    tester,
  ) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedRtl,
      ),
      firstParagraphs: List<String>.generate(
        8,
        (index) => 'RTL 分页段落 $index ${List<String>.filled(48, '正文').join()}',
      ),
    );
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(
      find.byKey(const Key('novel-reader-paged-page-view')),
    );
    expect(pageView.reverse, isTrue);
    expect(_readingStatusTrailing(tester), contains('第 1 /'));
  });

  testWidgets('NovelReaderPage constrains wide content column', (tester) async {
    final repository = _FakeNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.vertical,
        contentMaxWidth: 360,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    final padding = tester
        .widget<SliverPadding>(
          find.byKey(const Key('novel-reader-content-column')),
        )
        .padding
        .resolve(TextDirection.ltr);
    final width =
        tester
            .getSize(find.byKey(const Key('novel-reader-paragraph-list')))
            .width -
        padding.horizontal;

    expect(width, lessThanOrEqualTo(360));
  });

  testWidgets('NovelReaderPage does not duplicate chapter title in body', (
    tester,
  ) async {
    final repository = _FakeNovelRepository();
    await tester.pumpWidget(_buildReaderApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-reader-inline-chapter-title')),
      findsNothing,
    );
    expect(_readerText('第一段。'), findsOneWidget);
  });

  testWidgets(
    'NovelReaderPage source reading locates the current chapter PID',
    (tester) async {
      final locator = _ReaderPostLocator(tid: '100');
      await tester.pumpWidget(
        _buildReaderApp(
          repository: _FakeNovelRepository(),
          threadRepository: _FakeThreadRepository(targetPid: '5001'),
          threadPostLocator: locator,
        ),
      );
      await tester.pumpAndSettle();

      await _showReaderMenu(tester);
      final openThread = find.byKey(
        const Key('shared-reader-top-action-open-thread'),
      );
      expect(
        find.byKey(const Key('shared-reader-bottom-action-open-thread')),
        findsNothing,
      );
      await tester.tap(openThread);
      await tester.pumpAndSettle();

      expect(find.byType(ThreadDetailPage), findsOneWidget);
      final detail = tester.widget<ThreadDetailPage>(
        find.byType(ThreadDetailPage),
      );
      expect(
        (detail.tid, detail.targetPid, detail.initialPage),
        ('100', '5001', 2),
      );
      expect(detail.landing, ThreadPostLanding.top);
      expect(detail.bodyReadingObserver, isNull);
      expect(locator.calls, 1);
    },
  );
}
