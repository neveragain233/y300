part of 'forum_display_page_test.dart';

void _navigationCases() {
  testWidgets('renders sub forum entry and opens nested forum display', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      if (fid == '52') {
        return ApiSuccess(
          ForumDisplayData(
            fid: '52',
            forumName: '百合会最萌世界杯专版！',
            currentPage: 1,
            perPage: 20,
            totalThreads: 0,
            threads: const <ForumThreadSummary>[],
          ),
        );
      }

      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          subForums: const <ForumDisplaySubForum>[
            ForumDisplaySubForum(
              fid: '52',
              title: '百合会最萌世界杯专版！',
              url: 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=52&mobile=2',
              iconUrl: 'https://bbs.yamibo.com/data/attachment/common/9a/common_52_icon.gif',
            ),
          ],
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('forum-display-sub-forums')), findsOneWidget);
    expect(find.text('子版块'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('百合会最萌世界杯专版！'), findsNothing);

    await tester.tap(find.byKey(const Key('forum-display-sub-forums-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('百合会最萌世界杯专版！'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forum-display-sub-forum-52')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);
    expect(find.text('百合会最萌世界杯专版！'), findsWidgets);
    expect(repository.lastQuery?.fid, '52');
  });

  testWidgets('opens search with the current forum fid', (tester) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          fid: fid,
          page: 1,
          total: 1,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumDisplayRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LocalizedTestApp(
          home: ForumDisplayPage(fid: '30', title: '漫画区'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchButton = find.byKey(const Key('forum-display-search-button'));
    expect(searchButton, findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('forum-display-more-button'))).dx,
      greaterThan(
        tester
            .getCenter(find.byKey(const Key('forum-display-search-button')))
            .dx,
      ),
    );

    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    final searchPage = tester.widget<ForumSearchPage>(
      find.byType(ForumSearchPage),
    );
    expect(searchPage.scope, ForumSearchScope.currentForum);
    expect(searchPage.forumId, '30');
  });

  testWidgets('opens search with non-30 forum fid', (tester) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          fid: fid,
          page: 1,
          total: 1,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumDisplayRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LocalizedTestApp(
          home: ForumDisplayPage(fid: '33', title: '海域区'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchButton = find.byKey(const Key('forum-display-search-button'));
    expect(searchButton, findsOneWidget);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    final searchPage = tester.widget<ForumSearchPage>(
      find.byType(ForumSearchPage),
    );
    expect(searchPage.scope, ForumSearchScope.currentForum);
    expect(searchPage.forumId, '33');
  });

  testWidgets('hides search action when forum fid is empty', (tester) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          fid: '',
          page: 1,
          total: 1,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumDisplayRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LocalizedTestApp(
          home: ForumDisplayPage(fid: '', title: ''),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-display-search-button')), findsNothing);
  });
}
