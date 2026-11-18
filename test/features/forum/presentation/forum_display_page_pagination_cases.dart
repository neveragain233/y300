part of 'forum_display_page_test.dart';

void _paginationCases() {
  testWidgets('loads next page when tapping load more', (tester) async {
    var callCount = 0;
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      callCount++;
      if (page == 1) {
        return ApiSuccess(
          _displayData(
            page: 1,
            total: 2,
            threads: [
              ForumThreadSummary(
                tid: '100',
                subject: '帖子A',
                author: 'alice',
                replies: 1,
                views: 5,
                dateline: 'today',
              ),
            ],
          ),
        );
      }

      return ApiSuccess(
        _displayData(
          page: 2,
          total: 2,
          threads: [
            ForumThreadSummary(
              tid: '101',
              subject: '帖子B',
              author: 'bob',
              replies: 2,
              views: 6,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const Key('forum-display-load-more-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('forum-display-load-more-button')));
    await tester.pumpAndSettle();

    expect(find.text('帖子A'), findsNothing);
    expect(find.text('帖子B'), findsOneWidget);
    expect(callCount, 2);
  });

  testWidgets('holding a thread opens it on release without copying', (
    tester,
  ) async {
    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          copiedTexts.add(data['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          threads: [
            ForumThreadSummary(
              tid: '572604',
              subject: '有源链接的帖子',
              author: 'alice',
              replies: 0,
              views: 1,
              dateline: 'today',
              threadUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=572604&mobile=2',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, threadRepository: _FakeThreadRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final card = find.byKey(const Key('forum-thread-572604'));
    final restingBounds = tester.getRect(card);
    final gesture = await tester.startGesture(restingBounds.center);
    await tester.pump(const Duration(seconds: 1));

    expect(copiedTexts, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getRect(card), restingBounds);
    expect(find.byType(ThreadDetailPage), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(ThreadDetailPage), findsOneWidget);
    expect(
      tester.widget<ThreadDetailPage>(find.byType(ThreadDetailPage)).tid,
      '572604',
    );
    expect(copiedTexts, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging after holding a thread cancels opening it', (
    tester,
  ) async {
    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          copiedTexts.add(data['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          threads: [
            ForumThreadSummary(
              tid: '100',
              subject: '只有 tid 的帖子',
              author: 'alice',
              replies: 0,
              views: 1,
              dateline: 'today',
            ),
            ..._manyThreads(suffix: 'hold-drag', count: 20),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final card = find.byKey(const Key('forum-thread-100'));
    final restingBounds = tester.getRect(card);
    final gesture = await tester.startGesture(restingBounds.center);
    await tester.pump(const Duration(seconds: 1));

    expect(copiedTexts, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getRect(card), restingBounds);
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -140));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_scrollOffset(tester), greaterThan(0));
    expect(find.byType(ThreadDetailPage), findsNothing);
    expect(copiedTexts, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter and thread tag taps reload using link query', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      final typeid = query?.parameters['typeid'];
      return ApiSuccess(
        _displayData(
          page: page,
          total: 10,
          threads: [
            ForumThreadSummary(
              tid: typeid == '65' ? 'top-filtered' : 'tag-filtered',
              subject: typeid == '65' ? '公告筛选结果' : '分类筛选结果',
              author: 'alice',
              replies: 0,
              views: 1,
              dateline: 'today',
              sourceTagName: '長篇連載',
              sourceTagUrl: 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&filter=typeid&typeid=69&mobile=2',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const Key('forum-display-type-filter-menu')));
    await tester.pumpAndSettle();
    final openTypeArrowFinder = find.descendant(
      of: find.byKey(const Key('forum-display-type-filter-menu')),
      matching: find.byType(RotationTransition),
    );
    final openTypeArrow =
        openTypeArrowFinder.evaluate().single.widget as RotationTransition;
    expect(openTypeArrow.turns.value, 0.5);
    final menuItemCenter = tester.getCenter(
      find.byKey(
        const Key(
          'forum-display-type-filter-65:'
          'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&'
          'filter=typeid&typeid=65&mobile=2',
        ),
      ),
    );
    final menuTextCenter = tester.getCenter(find.text('公告').last);
    expect((menuItemCenter.dx - menuTextCenter.dx).abs(), lessThan(1));

    await tester.tap(
      find.byKey(
        const Key(
          'forum-display-type-filter-65:'
          'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&'
          'filter=typeid&typeid=65&mobile=2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.parameters['filter'], 'typeid');
    expect(repository.lastQuery?.parameters['typeid'], '65');
    expect(find.text('公告筛选结果'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forum-thread-tag-top-filtered')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(repository.lastQuery?.parameters['typeid'], '69');
    expect(find.text('分类筛选结果'), findsOneWidget);
  });

  testWidgets(
    'filters and pagination reset locally while tag routes preserve the source',
    (tester) async {
      final repository = _FakeForumDisplayRepository((_, page, query) async {
        final typeid = query?.parameters['typeid'];
        final suffix = typeid == null ? 'page-$page' : 'type-$typeid';
        return ApiSuccess(
          _displayData(
            page: page,
            total: 24,
            lastPage: 8,
            headImageUrl: 'https://bbs.yamibo.com/data/attachment/album/202603/02/head.png',
            threads: _manyThreads(
              suffix: suffix,
              count: 12,
              includeTagUrl: true,
            ),
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final filterStartOffset = tester
          .getSize(find.byKey(const Key('forum-display-head-image')))
          .height;
      expect(_scrollOffset(tester), 0);
      expect(filterStartOffset, greaterThan(0));

      await _dragWellPastFilter(tester);
      expect(_scrollOffset(tester), greaterThan(filterStartOffset + 120));

      await tester.tap(
        find.byKey(
          const Key(
            'forum-display-filter-'
            'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&'
            'filter=lastpost&mobile=2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectReturnedToFilterStart(tester, filterStartOffset);
      expect(repository.lastQuery?.parameters['filter'], 'lastpost');

      await _dragWellPastFilter(tester);
      await tester.tap(find.byKey(const Key('forum-display-type-filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key(
            'forum-display-type-filter-65:'
            'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&'
            'filter=typeid&typeid=65&mobile=2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectReturnedToFilterStart(tester, filterStartOffset);
      expect(repository.lastQuery?.parameters['typeid'], '65');

      await _dragWellPastFilter(tester);
      final tag = find.byKey(const Key('forum-thread-tag-type-65-5'));
      await tester.ensureVisible(tag);
      await tester.pumpAndSettle();
      final parentList = tester.element(
        find.byKey(const Key('forum-display-list')),
      );
      final parentPosition = _scrollPosition(tester);
      final parentOffset = parentPosition.pixels;
      await tester.tap(tag);
      await tester.pumpAndSettle();
      expect(repository.lastQuery?.parameters['typeid'], '69');
      expect(
        find.byType(ForumDisplayPage, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(_scrollOffset(tester), 0);
      expect(parentPosition.pixels, parentOffset);
      await _jumpNearBottomAndTap(
        tester,
        find.byKey(const Key('forum-display-load-more-button')),
      );
      await tester.pumpAndSettle();
      expect(repository.lastQuery?.page, 2);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const Key('forum-display-list'))),
        same(parentList),
      );
      expect(_scrollOffset(tester), parentOffset);

      await _jumpNearBottomAndTap(
        tester,
        find.byKey(const Key('forum-display-load-more-button')),
      );
      await tester.pumpAndSettle();
      _expectReturnedToFilterStart(tester, filterStartOffset);
      expect(repository.lastQuery?.page, 2);

      await _jumpNearBottomAndTap(
        tester,
        find.byKey(const Key('forum-display-prev-page-button')),
      );
      await tester.pumpAndSettle();
      _expectReturnedToFilterStart(tester, filterStartOffset);
      expect(repository.lastQuery?.page, 1);

      await _jumpNearBottomAndTap(
        tester,
        find.byKey(const Key('forum-display-current-page-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('forum-display-page-option-3')));
      await tester.pumpAndSettle();

      _expectReturnedToFilterStart(tester, filterStartOffset);
      expect(repository.lastQuery?.page, 3);
    },
  );

  testWidgets('pinned entry opens thread detail', (tester) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          topEntries: const <ForumDisplayTopEntry>[
            ForumDisplayTopEntry(
              title: '置顶跳转',
              url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=535389&mobile=2',
              tid: '535389',
              badgeLabel: '置顶',
            ),
          ],
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, threadRepository: _FakeThreadRepository()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final palette = ForumDisplayThemePalette.resolve(
      Theme.of(tester.element(find.byType(ForumDisplayPage))),
    );

    expect(find.text('置顶跳转'), findsNothing);
    expect(
      find.byKey(const Key('forum-display-top-entries-toggle')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('forum-display-top-entries-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('置顶跳转'), findsOneWidget);
    final topBadgeDecoration = _decorationAroundText(tester, '置顶');
    expect(topBadgeDecoration.border, isNull);
    expect(
      topBadgeDecoration.color,
      palette.surfaceContainerHigh.withValues(alpha: 0.42),
    );
    expect(topBadgeDecoration.boxShadow, isNotNull);
    expect(topBadgeDecoration.boxShadow, isNotEmpty);

    await tester.tap(find.byKey(const Key('forum-display-top-entries-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('置顶跳转'), findsNothing);

    await tester.tap(find.byKey(const Key('forum-display-top-entries-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('置顶跳转'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('置顶跳转'), findsWidgets);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);
  });

  testWidgets('current page button opens page menu and loads selected page', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 10,
          lastPage: 8,
          threads: [
            ForumThreadSummary(
              tid: 'page-$page',
              subject: '第$page页结果',
              author: 'alice',
              replies: 0,
              views: 1,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(
      find.byKey(const Key('forum-display-current-page-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forum-display-page-list')), findsOneWidget);
    expect(find.byKey(const Key('forum-display-page-input')), findsNothing);
    expect(
      find.byKey(const Key('forum-display-page-option-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('forum-display-page-option-8')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('forum-display-page-option-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(repository.lastQuery?.page, 3);
    expect(find.text('第3页结果'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('forum-display-current-page-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-display-page-option-8')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(repository.lastQuery?.page, 8);
    expect(find.text('第8页结果'), findsOneWidget);
  });
}
