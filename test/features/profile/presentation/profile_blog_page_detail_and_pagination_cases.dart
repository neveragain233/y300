part of 'profile_blog_page_test.dart';

void _detailAndPaginationCases() {
  testWidgets('ProfileBlogPage switches structured queries and opens detail', (
    tester,
  ) async {
    final directoryRepository = _FakeBlogDirectoryRepository();
    final detailRepository = _FakeBlogDetailRepository();
    await _pumpBlogPage(
      tester,
      directoryRepository: directoryRepository,
      detailRepository: detailRepository,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileBlogPage)),
    );

    expect(find.byKey(const Key('profile-blog-list')), findsOneWidget);
    expect(find.byKey(const Key('profile-blog-view-tabs')), findsOneWidget);
    expect(find.text('随便看看'), findsOneWidget);
    expect(find.text(l10n.profileBlogLatestShort), findsOneWidget);
    expect(find.text('一种体验'), findsOneWidget);

    await tester.tap(find.text(l10n.profileBlogRecommendedShort));
    await tester.pumpAndSettle();

    expect(directoryRepository.queries.last.order, UserBlogOrder.recommended);
    expect(find.text('我们小区的公共交通极其不便利'), findsOneWidget);

    await tester.tap(find.text('我的日志'));
    await tester.pumpAndSettle();

    expect(directoryRepository.queries.last.scope, UserBlogFeedScope.self);
    expect(directoryRepository.queries.last.order, isNull);
    expect(find.text('还没有相关的日志'), findsOneWidget);

    await tester.tap(find.text('随便看看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.profileBlogRecommendedShort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我们小区的公共交通极其不便利'));
    await tester.pumpAndSettle();

    expect(detailRepository.queries.single.ownerUserId, '257582');
    expect(detailRepository.queries.single.blogId, '117548');
    expect(find.byKey(const Key('profile-blog-detail')), findsOneWidget);
    expect(find.text('2026-6-18 00:25'), findsOneWidget);
    final views = find.byKey(const Key('blog-detail-views'));
    final comments = find.byKey(const Key('blog-detail-comment-count'));
    expect(
      find.descendant(
        of: views,
        matching: find.byIcon(Icons.visibility_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: views, matching: find.text('39')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: comments,
        matching: find.byIcon(Icons.forum_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: comments, matching: find.text('1')),
      findsOneWidget,
    );
    expect(find.text(l10n.profileBlogViews(39)), findsNothing);
    expect(find.text(l10n.profileBlogCommentCount(1)), findsNothing);
    expect(find.text('hsyhlj'), findsOneWidget);
    expect(_richTextContaining('一直对着电脑屏幕'), findsOneWidget);
    expect(find.text(l10n.profileBlogComments), findsOneWidget);
    expect(_richTextContaining('探险的感觉'), findsOneWidget);
  });

  testWidgets(
    'an empty article keeps zero-count badges and AppBar reply without comment placeholders or web action',
    (tester) async {
      final details = _FakeBlogDetailRepository(
        emptyComments: true,
        viewCount: 0,
        commentCount: 0,
      );
      final comments = BlogCommentFixture(autoPrepare: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            blogAccountIdProvider.overrideWithValue('101'),
            userBlogDetailRepositoryProvider.overrideWithValue(details),
            userBlogCommentServiceProvider.overrideWithValue(comments),
            forumImageRefererProvider.overrideWithValue(
              'https://bbs.yamibo.com/',
            ),
          ],
          child: const LocalizedTestApp(
            home: ProfileBlogDetailPage(ownerUserId: '202', blogId: '11'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileBlogDetailPage)),
      );
      expect(find.text(l10n.profileBlogComments), findsNothing);
      expect(find.text(l10n.profileBlogCommentsEmpty), findsNothing);
      expect(
        find.byKey(const Key('profile-blog-comments-heading')),
        findsNothing,
      );
      for (final key in ['blog-detail-views', 'blog-detail-comment-count']) {
        expect(
          find.descendant(of: find.byKey(Key(key)), matching: find.text('0')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('blog-detail-open-web')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppPageAppBar),
          matching: find.byIcon(Icons.open_in_browser),
        ),
        findsNothing,
      );
      expect(_richTextContaining('一直对着电脑屏幕'), findsOneWidget);
      await tester.tap(find.byKey(const Key('blog-detail-reply')));
      await tester.pumpAndSettle();
      expect(find.byType(BlogCommentPage), findsOneWidget);
      expect(
        comments.preparations.single.target,
        const UserBlogCommentTarget(
          actorUserId: '101',
          ownerUserId: '202',
          blogId: '11',
          action: UserBlogCommentAction.add,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final missing in [
    'values',
    'unknown capabilities',
    'unsupported capabilities',
  ]) {
    testWidgets('detail hides statistics with $missing', (tester) async {
      final supported = UserBlogDetailCapability.values.where(
        (capability) =>
            capability != UserBlogDetailCapability.viewCount &&
            capability != UserBlogDetailCapability.commentCount,
      );
      final capabilities = switch (missing) {
        'unknown capabilities' => UserBlogDetailReadCapabilities(
          values: DataCapabilitySet<UserBlogDetailCapability>.from(
            supported: supported,
          ),
        ),
        'unsupported capabilities' => _detailCapabilities(supported: supported),
        _ => _detailCapabilities(),
      };
      await _pumpBlogPage(
        tester,
        directoryRepository: _FakeBlogDirectoryRepository(),
        detailRepository: _FakeBlogDetailRepository(
          capabilities: capabilities,
          viewCount: missing == 'values' ? null : 39,
          commentCount: missing == 'values' ? null : 1,
        ),
      );
      await tester.tap(find.byKey(const Key('profile-blog-item-117558')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blog-detail-views')), findsNothing);
      expect(find.byKey(const Key('blog-detail-comment-count')), findsNothing);
      expect(find.text('2026-6-18 00:25'), findsOneWidget);
      expect(find.byKey(const Key('blog-detail-reply')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pagination replaces each page and can return from the last page',
    (tester) async {
      final repository = _FakeBlogDirectoryRepository();
      await _pumpBlogPage(
        tester,
        directoryRepository: repository,
        detailRepository: _FakeBlogDetailRepository(),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileBlogPage)),
      );
      expect(find.byKey(const Key('profile-blog-pagination')), findsOneWidget);
      expect(find.text(l10n.commonPage(1)), findsOneWidget);
      expect(find.text(l10n.commonPreviousPage), findsOneWidget);
      expect(_paginationButton(tester, 'previous-page').onPressed, isNull);

      await tester.tap(find.byKey(const Key('profile-blog-next-page-button')));
      await tester.pumpAndSettle();

      expect(repository.queries.last.page, 2);
      expect(repository.queries.last.scope, UserBlogFeedScope.public);
      expect(repository.queries.last.order, UserBlogOrder.latest);
      expect(find.text('第二页日志'), findsOneWidget);
      expect(find.text('一种体验'), findsNothing);
      expect(find.text(l10n.commonPage(2)), findsOneWidget);
      expect(find.text(l10n.forumDisplayNoMore), findsOneWidget);
      expect(_paginationButton(tester, 'next-page').onPressed, isNull);
      expect(_paginationButton(tester, 'previous-page').onPressed, isNotNull);

      await tester.tap(
        find.byKey(const Key('profile-blog-previous-page-button')),
      );
      await tester.pumpAndSettle();
      expect(repository.queries.map((query) => query.page), [1, 2, 1]);
      expect(find.text('一种体验'), findsOneWidget);
      expect(find.text('第二页日志'), findsNothing);
      expect(find.text(l10n.commonPage(1)), findsOneWidget);
      expect(_paginationButton(tester, 'previous-page').onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final unknownTotalPages in [false, true]) {
    testWidgets(
      'page picker navigates with ${unknownTotalPages ? 'unknown' : 'exact'} page counts',
      (tester) async {
        final repository = _FakeBlogDirectoryRepository(
          unknownTotalPages: unknownTotalPages,
        );
        await _pumpBlogPage(
          tester,
          directoryRepository: repository,
          detailRepository: _FakeBlogDetailRepository(),
        );

        await tester.tap(
          find.byKey(const Key('profile-blog-current-page-button')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('profile-blog-page-list')), findsOneWidget);
        expect(
          find.byKey(const Key('profile-blog-page-option-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('profile-blog-page-option-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('profile-blog-page-option-3')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('profile-blog-page-option-2')));
        await tester.pumpAndSettle();
        expect(repository.queries.map((query) => query.page), [1, 2]);
        expect(find.text('第二页日志'), findsOneWidget);
        expect(find.text('一种体验'), findsNothing);

        await tester.tap(
          find.byKey(const Key('profile-blog-current-page-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('profile-blog-page-option-3')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('profile-blog-page-option-1')));
        await tester.pumpAndSettle();
        expect(repository.queries.map((query) => query.page), [1, 2, 1]);
        expect(find.text('一种体验'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending page navigation keeps the displayed page and disables controls',
    (tester) async {
      final nextPageGate = Completer<void>();
      final repository = _FakeBlogDirectoryRepository(
        nextPageGate: nextPageGate,
      );
      await _pumpBlogPage(
        tester,
        directoryRepository: repository,
        detailRepository: _FakeBlogDetailRepository(),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileBlogPage)),
      );

      await tester.tap(find.byKey(const Key('profile-blog-next-page-button')));
      await tester.pump();
      expect(repository.queries.last.page, 2);
      expect(find.text('一种体验'), findsOneWidget);
      expect(find.text(l10n.commonPage(1)), findsOneWidget);
      expect(_paginationButton(tester, 'previous-page').onPressed, isNull);
      expect(_paginationButton(tester, 'current-page').onPressed, isNull);
      expect(_paginationButton(tester, 'next-page').onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text(l10n.profileBlogLoadingPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-blog-pagination')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      nextPageGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('第二页日志'), findsOneWidget);
      expect(find.text(l10n.commonPage(2)), findsOneWidget);
      expect(_paginationButton(tester, 'previous-page').onPressed, isNotNull);
      expect(_paginationButton(tester, 'current-page').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('page navigation failure retains its page and can be retried', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository()..failedPages.add(2);
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileBlogPage)),
    );

    await tester.tap(find.byKey(const Key('profile-blog-next-page-button')));
    await tester.pumpAndSettle();
    expect(find.text('一种体验'), findsOneWidget);
    expect(find.text('第二页日志'), findsNothing);
    expect(find.text(l10n.commonPage(1)), findsOneWidget);
    expect(_paginationButton(tester, 'previous-page').onPressed, isNull);
    expect(_paginationButton(tester, 'next-page').onPressed, isNotNull);
    expect(find.text(l10n.profileBlogRetryPage(2)), findsOneWidget);

    repository.failedPages.clear();
    await tester.tap(find.byKey(const Key('profile-blog-next-page-button')));
    await tester.pumpAndSettle();
    expect(repository.queries.map((query) => query.page), [1, 2, 2]);
    expect(find.text('第二页日志'), findsOneWidget);
    expect(find.text(l10n.commonPage(2)), findsOneWidget);
    expect(find.text('一种体验'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('previous and next pages smoothly return long lists to the top', (
    tester,
  ) async {
    final nextPageGate = Completer<void>();
    final repository = _FakeBlogDirectoryRepository(
      longList: true,
      longListPages: const {1, 2},
      nextPageGate: nextPageGate,
    );
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
    );
    final list = find.byKey(const Key('profile-blog-list'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    for (final direction in ['next', 'previous']) {
      final button = find.byKey(Key('profile-blog-$direction-page-button'));
      await tester.scrollUntilVisible(button, 500, scrollable: scrollable);
      await tester.pumpAndSettle();
      final oldOffset = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      expect(oldOffset, greaterThan(400));
      await tester.tap(button);
      if (direction == 'next') {
        await tester.pump();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          oldOffset,
        );
        nextPageGate.complete();
      }
      await tester.pump();
      await tester.pump();
      final animationStart = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      expect(animationStart, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 55));
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        allOf(greaterThan(0), lessThan(animationStart)),
      );
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    }
    expect(find.text('Entry 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching blog scopes retires an in-progress pagination return',
    (tester) async {
      final repository = _FakeBlogDirectoryRepository(
        longList: true,
        longListPages: const {1, 2},
      );
      await _pumpBlogPage(
        tester,
        directoryRepository: repository,
        detailRepository: _FakeBlogDetailRepository(),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileBlogPage)),
      );
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('profile-blog-list')).hitTestable(),
            matching: find.byType(Scrollable),
          )
          .hitTestable();
      double offset() =>
          tester.state<ScrollableState>(scrollable).position.pixels;
      final next = find.byKey(const Key('profile-blog-next-page-button'));
      await tester.scrollUntilVisible(next, 500, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump();
      await tester.pump();
      final animationStart = offset();
      await tester.pump(const Duration(milliseconds: 55));
      final interruptedOffset = offset();
      expect(
        interruptedOffset,
        allOf(greaterThan(0), lessThan(animationStart)),
      );

      await tester.tap(find.text(l10n.profileBlogFriends));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repository.queries.last.scope, UserBlogFeedScope.friends);
      await tester.tap(find.text(l10n.profileBlogExplore));
      await tester.pumpAndSettle();
      expect(offset(), closeTo(interruptedOffset, 0.5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(offset(), closeTo(interruptedOffset, 0.5));
      expect(repository.queries, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );
}
