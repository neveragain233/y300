part of 'forum_display_page_test.dart';

void _tagMenuCases() {
  testWidgets('server tag names do not wait for the local tag catalog', (
    tester,
  ) async {
    final lookup = Completer<ForumTagLookup>();
    var lookupReads = 0;
    final repository = _FakeForumDisplayRepository((_, _, _) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 1,
          threads: [
            _manyThreads(suffix: 'tag', count: 1).single.copyWith(
              typeid: '69',
              sourceTagName: 'Fixture server tag',
            ),
          ],
        ),
      );
    });
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        extraOverrides: [
          forumTagLookupProvider.overrideWith((ref) {
            lookupReads++;
            return lookup.future;
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(lookupReads, 0);
    expect(find.text('Fixture server tag'), findsOneWidget);
  });

  testWidgets('missing server tag names still use the local catalog', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, _, _) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 1,
          threads: [
            _manyThreads(
              suffix: 'tag',
              count: 1,
            ).single.copyWith(typeid: '69', sourceTagName: ' '),
          ],
        ),
      );
    });
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        extraOverrides: [
          forumTagLookupProvider.overrideWith(
            (ref) async => ForumTagLookup([
              const ForumBoardTagSet(
                fid: '2',
                name: 'Fixture forum',
                tags: [
                  ForumTagDefinition(
                    fid: '2',
                    typeid: '69',
                    name: 'Fixture local tag',
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fixture local tag'), findsOneWidget);
  });

  testWidgets('moves create-thread entry into the more menu', (tester) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-display-compose-button')), findsNothing);

    await tester.tap(find.byKey(const Key('forum-display-more-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('forum-display-compose-action')),
      findsOneWidget,
    );
    expect(find.text('发帖'), findsOneWidget);
    expect(
      tester
          .getCenter(
            find.byKey(const Key('forum-display-favorite-unavailable-action')),
          )
          .dy,
      lessThan(
        tester
            .getCenter(find.byKey(const Key('forum-display-compose-action')))
            .dy,
      ),
    );
  });

  testWidgets('more menu always exposes a force-network refresh', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-display-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-display-refresh-action')));
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('more menu reflects a server-declared favorite action', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          favoriteAction: ForumDisplayFavoriteAction.favorite,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });
    final favoriteRepository = _FakeForumFavoriteRepository();

    await tester.pumpWidget(
      _buildTestApp(repository, favoriteRepository: favoriteRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('forum-display-more-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('forum-display-favorite-action')),
      findsOneWidget,
    );
    expect(find.text('收藏本版'), findsOneWidget);
    await tester.tap(find.byKey(const Key('forum-display-favorite-action')));
    await tester.pumpAndSettle();

    expect(favoriteRepository.favoriteFids, <String>['2']);
    expect(find.text('已收藏本版'), findsOneWidget);
    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('unfavorite action delegates the target state command', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          favoriteAction: ForumDisplayFavoriteAction.unfavorite,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });
    final favoriteRepository = _FakeForumFavoriteRepository(
      favoriteForums: <FavoriteForumEntry>[
        _favoriteForum(fid: '2', favid: 'fav-2', title: '公告区'),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(repository, favoriteRepository: favoriteRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('forum-display-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-display-unfavorite-action')));
    await tester.pumpAndSettle();

    expect(favoriteRepository.commandRequests, hasLength(1));
    expect(
      favoriteRepository.commandRequests.single.targetState,
      FavoriteTargetState.unfavorited,
    );
    expect(favoriteRepository.unfavoriteFavids, <String>['fav-2']);
    expect(find.text('已取消收藏本版'), findsOneWidget);
    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('unknown favorite state does not guess a destructive action', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          favoriteAction: ForumDisplayFavoriteAction.unknown,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forum-display-more-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('forum-display-refresh-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('forum-display-favorite-unavailable-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('forum-display-unfavorite-action')),
      findsNothing,
    );
  });
}
