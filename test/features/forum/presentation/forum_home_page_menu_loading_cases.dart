part of 'forum_home_page_test.dart';

void _menuLoadingCases() {
  testWidgets('more menu exposes refresh and unfavorite actions', (
    tester,
  ) async {
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayload()),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('forum-home-more-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-refresh-action')), findsOneWidget);
    expect(
      find.byKey(const Key('forum-home-unfavorite-action')),
      findsOneWidget,
    );
    expect(find.text('刷新页面'), findsOneWidget);
    expect(find.text('取消收藏'), findsOneWidget);
  });

  testWidgets('more menu refresh forces a network request', (tester) async {
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayload()),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-home-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-home-refresh-action')));
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('more menu opens the shared unfavorite picker', (tester) async {
    final homeRepository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_loggedOutPayload()),
    );
    final favoriteRepository = _FakeForumFavoriteRepository(
      favoriteForums: <FavoriteForumEntry>[
        _favoriteDirectoryForum(
          fid: '55',
          remoteFavoriteId: 'fav-55',
          title: '综合区',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        homeRepository,
        extraOverrides: [
          favoriteForumCommandProvider.overrideWithValue(favoriteRepository),
          favoriteForumDirectoryRepositoryProvider.overrideWithValue(
            favoriteRepository.directory,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-home-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-home-unfavorite-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('forum-favorite-forum-picker')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('forum-favorite-forum-picker')),
        matching: find.text('综合区'),
      ),
      findsOneWidget,
    );
    expect(favoriteRepository.loadCallCount, 1);

    await tester.tap(find.byKey(const Key('forum-favorite-forum-item-fav-55')));
    await tester.pumpAndSettle();

    expect(favoriteRepository.unfavoriteFavids, <String>['fav-55']);
    expect(find.byKey(const Key('forum-favorite-forum-picker')), findsNothing);
    expect(find.text('已取消收藏本版'), findsOneWidget);
    expect(homeRepository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('stays buildable before data returns and then renders list', (
    tester,
  ) async {
    final completer = Completer<ForumHomeReadResult>();
    final repository = _FakeForumHomeRepository(() => completer.future);

    await tester.pumpWidget(_buildTestApp(repository));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const Key('forum-home-list')), findsNothing);
    expect(find.byKey(const Key('forum-home-loading')), findsOneWidget);
    expect(
      find.text(
        AppLocalizations.of(tester.element(find.byType(ForumHomePage)))
            .commonLoading,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forum-home-refresh-progress')), findsNothing);

    completer.complete(forumHomeReadSuccess(_loggedOutPayload()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(find.text('综合区'), findsOneWidget);
    expect(find.text('公告区'), findsOneWidget);
  });

  testWidgets('empty directory shows the shared empty state', (tester) async {
    final repository = _FakeForumHomeRepository(
      () async => forumHomeReadSuccess(_emptyPayload()),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-empty-state')), findsOneWidget);
    expect(
      find.text(
        AppLocalizations.of(tester.element(find.byType(ForumHomePage)))
            .forumHomeEmpty,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
  });

  testWidgets('load failure uses the shared error state and retries', (
    tester,
  ) async {
    var requests = 0;
    final repository = _FakeForumHomeRepository(() async {
      requests += 1;
      if (requests == 1) {
        return const DataReadFailure(
          kind: DataReadFailureKind.network,
          diagnosticMessage: 'fixture-offline',
        );
      }
      return forumHomeReadSuccess(_loggedOutPayload());
    });

    await tester.pumpWidget(_buildTestApp(repository, retry: (_, _) => null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-retry-button')), findsOneWidget);
    expect(
      find.text(
        AppLocalizations.of(tester.element(find.byType(ForumHomePage)))
            .commonRetry,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forum-home-list')), findsNothing);

    await tester.tap(find.byKey(const Key('forum-home-retry-button')));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(find.byKey(const Key('forum-home-retry-button')), findsNothing);
  });
}
