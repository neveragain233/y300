part of 'thread_detail_page_test.dart';

void _pagingCases() {
  testWidgets('rating date uses the full row width on narrow screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final theme = AppTheme.dark();
    final palette = ThreadDetailNativePalette.resolve(theme);

    await tester.pumpWidget(
      LocalizedTestApp(
        theme: theme,
        home: Scaffold(
          body: ThreadPostRatingRow(
            rating: const ThreadPostRating(
              userName: 'narrow-screen-user',
              score: '+2',
              reason: '评分理由',
              dateline: '2026-7-24 10:00',
            ),
            palette: palette,
          ),
        ),
      ),
    );

    final dateFinder = find.text('2026-7-24 10:00');
    final dateText = tester.widget<Text>(dateFinder);
    final dateParagraph = tester.renderObject<RenderParagraph>(dateFinder);
    expect(dateText.maxLines, isNull);
    expect(dateText.overflow, isNull);
    expect(dateParagraph.didExceedMaxLines, isFalse);
    expect(
      tester.getTopLeft(dateFinder).dy,
      greaterThan(tester.getTopLeft(find.text('+2')).dy),
    );
  });

  testWidgets(
    'floor navigation stops at the last loaded post before a separate cross-page tap',
    (tester) async {
      tester.view.physicalSize = const Size(411, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = <int>[];
      final next = Completer<ApiResult<ThreadDetailData>>();
      ThreadDetailData data(String tid, int page) => ThreadDetailData(
        tid: tid,
        fid: '33',
        subject: '测试主题',
        author: 'alice',
        replies: 5,
        views: 12,
        currentPage: page,
        lastPage: 2,
        perPage: 3,
        posts: [
          for (var index = 0; index < 3; index++)
            _post(
              pid: 'floor-${(page - 1) * 3 + index + 1}',
              author: 'alice',
              authorId: '1',
              number: (page - 1) * 3 + index + 1,
              isFirst: page == 1 && index == 0,
              message: List.generate(
                60,
                (line) => '<p>第$page页第$index楼正文第$line段</p>',
              ).join(),
            ),
        ],
      );
      final repository = _FakeThreadRepository((tid, page, query) async {
        pages.add(page);
        if (page == 2) return await next.future;
        return ApiSuccess(data(tid, page));
      });
      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-detail-quick-scroll-button')),
        findsNothing,
      );
      final forward = find.byKey(const Key('thread-next-post-button'));
      await tester.tap(forward);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thread-post-card-floor-2')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-floor-2'))).dy,
        // 顶栏改为两行 64 后，近顶端判定随之下移 8 逻辑像素。
        lessThan(128),
      );
      expect(pages, [1]);
      await tester.tap(forward);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-floor-3'))).dy,
        lessThan(120 + _repliesHeaderHeight(tester)),
      );
      expect(pages, [1]);
      // 末楼楼头可见不算页尾：先读到底，再用下一次操作翻页。
      await tester.tap(forward);
      await tester.pumpAndSettle();
      expect(pages, [1]);
      await tester.tap(forward);
      await tester.pump();
      expect(pages, [1, 2]);
      next.complete(ApiSuccess(data('100', 2)));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-floor-4'))).dy,
        lessThan(120 + _repliesHeaderHeight(tester)),
      );
      await tester.tap(find.byKey(const Key('thread-previous-post-button')));
      await tester.pumpAndSettle();
      expect(pages, [1, 2, 1]);
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-floor-3'))).dy,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('thread-detail-list'))).dy +
              _repliesHeaderHeight(tester),
          1,
        ),
      );
    },
  );

  testWidgets(
    'cancelled adjacent load preserves the visible page and ignores the late response',
    (tester) async {
      var failNext = false;
      final next = Completer<ApiResult<ThreadDetailData>>();
      final repository = _FakeThreadRepository((tid, page, query) async {
        if (page == 2) {
          if (failNext) throw StateError('test transport failure');
          return next.future;
        }
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '33',
            subject: '测试主题',
            author: 'alice',
            replies: 2,
            views: 12,
            currentPage: 1,
            lastPage: 2,
            perPage: 1,
            posts: [
              _post(
                pid: 'p1',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: '<p>原页正文</p>',
              ),
            ],
          ),
        );
      });
      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ThreadDetailPage)),
      );
      const args = ThreadDetailArgs(tid: '100', subject: '测试主题');
      final controller = container.read(
        threadDetailControllerProvider(args).notifier,
      );
      final pending = controller.loadAdjacentForFloor(
        forward: true,
        isCurrent: () => true,
      );
      await tester.pump();
      controller.cancelFloorPageLoad();
      next.complete(
        ApiSuccess(
          ThreadDetailData(
            tid: '100',
            fid: '33',
            subject: '测试主题',
            author: 'alice',
            replies: 2,
            views: 12,
            currentPage: 2,
            lastPage: 2,
            perPage: 1,
            posts: [
              _post(
                pid: 'p2',
                author: 'bob',
                authorId: '2',
                number: 2,
                message: '<p>迟到正文</p>',
              ),
            ],
          ),
        ),
      );
      expect(await pending, isFalse);
      await tester.pumpAndSettle();
      final state = container
          .read(threadDetailControllerProvider(args))
          .requireValue;
      expect(state.currentPage, 1);
      expect(state.isLoadingMore, isFalse);
      expect(state.posts.single.pid, 'p1');
      expect(_richTextContaining('原页正文'), findsOneWidget);
      expect(_richTextContaining('迟到正文'), findsNothing);
      failNext = true;
      expect(
        await controller.loadAdjacentForFloor(
          forward: true,
          isCurrent: () => true,
        ),
        isFalse,
      );
      await tester.pumpAndSettle();
      final failed = container
          .read(threadDetailControllerProvider(args))
          .requireValue;
      expect(failed.currentPage, 1);
      expect(failed.posts.single.pid, 'p1');
      expect(failed.isLoadingMore, isFalse);
      expect(failed.loadFailure, isNotNull);
    },
  );

  testWidgets(
    'single navigation reads the last body before returning to its header',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.threadControlsV1.name: jsonEncode({
          'schemaVersion': 1,
          'singleNavigationButton': true,
        }),
      });
      final requests = <int>[];
      final repository = _FakeThreadRepository((tid, page, query) async {
        requests.add(page);
        return ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'single-last',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: List.generate(
                  180,
                  (line) => '<p>末楼正文第$line段</p>',
                ).join(),
              ),
            ],
          ),
        );
      });
      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('thread-single-navigation-button'));
      Finder icon(IconData icon) =>
          find.descendant(of: button, matching: find.byIcon(icon));
      expect(icon(Icons.keyboard_arrow_down), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(icon(Icons.vertical_align_top), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(icon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('thread-post-card-single-last')))
            .dy,
        lessThan(120),
      );
      expect(requests, [1]);
    },
  );

  testWidgets(
    'first-post navigation from a body-end landing reveals the header',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.threadControlsV1.name: jsonEncode({
          'schemaVersion': 1,
          'singleNavigationButton': true,
          'holdToFirstPost': true,
        }),
      });
      final repository = _FakeThreadRepository(
        (tid, page, query) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'p1',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: List.generate(
                  100,
                  (line) => '<p>正文第$line段</p>',
                ).join(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          home: const ThreadDetailPage(
            tid: '100',
            subject: '测试主题',
            targetPid: 'p1',
            landing: ThreadPostLanding.bodyEnd,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const Key('thread-single-navigation-button')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-p1'))).dy,
        lessThan(120),
      );
    },
  );

  testWidgets('floating controls survive a dark theme and font scale change', (
    tester,
  ) async {
    final repository = _FakeThreadRepository(
      (tid, page, query) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            for (var i = 0; i < 4; i++)
              _post(
                pid: 'p$i',
                author: 'alice',
                authorId: '1',
                number: i + 1,
                isFirst: i == 0,
                message: '<p>测试正文</p>',
              ),
          ],
        ),
      ),
    );
    Widget app(bool dark, double scale) => _buildTestApp(
      repository,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: const ThreadDetailPage(tid: '100', subject: '测试主题'),
        ),
      ),
    );
    await tester.pumpWidget(app(false, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(true, 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('thread-next-post-button')), findsOneWidget);
  });

  testWidgets('keeps rating preview on failure and retries inline', (
    tester,
  ) async {
    final ratingsRepository = _FakeThreadPostRatingsRepository(
      results: <ApiResult<ThreadPostRatingDetails>>[
        const ApiFailure<ThreadPostRatingDetails>(
          ApiError(type: ApiErrorType.network, message: '完整评分加载失败'),
        ),
        const ApiSuccess<ThreadPostRatingDetails>(
          ThreadPostRatingDetails(
            participantCount: 2,
            totalScoreText: '积分 +5 点',
            ratings: <ThreadPostRating>[
              ThreadPostRating(userName: '预览用户', score: '+2', reason: '预览理由'),
              ThreadPostRating(userName: '完整评分用户', score: '+3', reason: '补充评分'),
            ],
          ),
        ),
      ],
    );
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            _post(
              pid: '1',
              author: 'alice',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>正文</p>',
              ratingSummary: const ThreadPostRatingSummary(
                participantText: '参与人数 1',
                scoreText: '积分 +2',
                viewAllUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=viewratings&tid=100&pid=1',
                ratings: <ThreadPostRating>[
                  ThreadPostRating(
                    userName: '预览用户',
                    score: '+2',
                    reason: '预览理由',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, postRatingsRepository: ratingsRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-post-rating-body')));
    await tester.pumpAndSettle();

    expect(find.text('预览用户'), findsOneWidget);
    expect(find.text('预览理由'), findsOneWidget);
    expect(find.text('完整评分加载失败'), findsOneWidget);
    expect(find.text('完整评分用户'), findsNothing);
    expect(ratingsRepository.loadCount, 1);

    await tester.tap(find.byKey(const Key('thread-post-rating-retry-button')));
    await tester.pumpAndSettle();

    expect(find.text('完整评分加载失败'), findsNothing);
    expect(find.text('完整评分用户'), findsOneWidget);
    expect(find.text('参与人数 2'), findsOneWidget);
    expect(ratingsRepository.loadCount, 2);
  });

  testWidgets('discards a rating response from an older page generation', (
    tester,
  ) async {
    final ratingsRepository = _ControlledThreadPostRatingsRepository();
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            _post(
              pid: '1',
              author: 'alice',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>正文</p>',
              ratingSummary: const ThreadPostRatingSummary(
                participantText: '参与人数 1',
                scoreText: '积分 +2',
                viewAllUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=viewratings&tid=100&pid=1',
                ratings: <ThreadPostRating>[
                  ThreadPostRating(
                    userName: '预览用户',
                    score: '+2',
                    reason: '预览理由',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, postRatingsRepository: ratingsRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thread-post-rating-body')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThreadDetailPage)),
    );
    const args = ThreadDetailArgs(tid: '100', subject: '测试主题');
    await container
        .read(threadDetailControllerProvider(args).notifier)
        .refresh();
    await tester.pump();

    ratingsRepository.completeSuccess();
    await tester.pumpAndSettle();

    expect(find.text('预览用户'), findsOneWidget);
    expect(find.text('完整评分用户'), findsNothing);
    expect(
      container
          .read(threadDetailControllerProvider(args))
          .value
          ?.ratingsByPostId,
      isEmpty,
    );
    expect(ratingsRepository.loadCount, 1);
  });

  testWidgets('pull to refresh reloads a short thread from network', (
    tester,
  ) async {
    // 只有一楼的帖子撑不满一屏。默认滚动物理会直接拒绝这种列表的拖拽，
    // 手势永远到不了 RefreshIndicator，所以这条用真实拖拽而不是直接调
    // onRefresh——它同时守住 ForumPullToRefresh.scrollPhysics 的接线。
    var callCount = 0;
    final repository = _FakeThreadRepository((tid, page, query) async {
      callCount++;
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            _post(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>第 $callCount 次加载</p>',
            ),
          ],
        ),
      );
    });
    final invalidationService = _FakeNativePageCacheInvalidationService();

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        pageCacheInvalidationService: invalidationService,
      ),
    );
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(_richTextContaining('第 1 次加载'), findsOneWidget);
    expect(
      tester
          .widget<ScrollView>(find.byKey(const Key('thread-detail-list')))
          .physics,
      ForumPullToRefresh.scrollPhysics,
    );

    await tester.fling(
      find.byKey(const Key('thread-detail-list')),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    // 解析快照有 5 分钟新鲜期，不清缓存的话这次刷新会命中快照、看不到新回复。
    expect(invalidationService.invalidatedThreadIds, <String>['100']);
    expect(callCount, 2);
    expect(_richTextContaining('第 2 次加载'), findsOneWidget);
  });

  testWidgets('pull to refresh keeps the current page and filters', (
    tester,
  ) async {
    final requests = <({int page, Map<String, String> query})>[];
    final repository = _FakeThreadRepository((tid, page, query) async {
      requests.add((page: page, query: Map<String, String>.from(query)));
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            _post(
              pid: 'p$page',
              author: 'alice',
              authorId: '1',
              number: page,
              isFirst: page == 1,
              message: '<p>第 $page 页</p>',
            ),
          ],
          currentPage: page,
          lastPage: 3,
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThreadDetailPage)),
    );
    const args = ThreadDetailArgs(tid: '100', subject: '测试主题');
    final controller = container.read(
      threadDetailControllerProvider(args).notifier,
    );
    await controller.openOnlyAuthor();
    await tester.pumpAndSettle();
    await controller.loadPage(2);
    await tester.pumpAndSettle();

    final beforeRefresh = requests.last;
    expect(beforeRefresh.page, 2);
    expect(beforeRefresh.query, isNotEmpty);

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(requests.last.page, 2);
    expect(requests.last.query, beforeRefresh.query);
  });

  testWidgets('shows posts and switches thread pages', (tester) async {
    var callCount = 0;
    final ratingsRepository = _FakeThreadPostRatingsRepository();
    final repository = _FakeThreadRepository((tid, page, query) async {
      callCount++;
      if (page == 1) {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '2',
            typeid: '410',
            typeName: '理性探讨',
            forumName: '海域區',
            forumUrl:
                'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=33',
            subject: '测试主题',
            author: 'alice',
            replies: 1,
            views: 12,
            currentPage: 1,
            lastPage: 2,
            nextPageUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=2',
            reverseOrderUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&ordertype=1',
            onlyAuthorUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&authorid=1',
            favoriteUrl: 'https://bbs.yamibo.com/home.php?mod=spacecp&ac=favorite&type=thread&id=100',
            shareUrl: 'https://bbs.yamibo.com/home.php?mod=spacecp&ac=share&type=thread&id=100',
            homeUrl: 'https://bbs.yamibo.com/index.php',
            desktopUrl:
                'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
            perPage: 1,
            posts: [
              ThreadPost(
                pid: 'p1',
                author: 'alice',
                authorId: '1',
                message: '<p>第一条回复</p>',
                number: 1,
                isFirst: true,
                dateline: 'today',
                rateUrl:
                    'https://bbs.yamibo.com/forum.php?mod=misc&action=rate',
                commentUrl:
                    'https://bbs.yamibo.com/forum.php?mod=misc&action=comment',
                replyUrl:
                    'https://bbs.yamibo.com/forum.php?mod=post&action=reply',
                comments: const <ThreadPostCommentEntry>[
                  ThreadPostCommentEntry(
                    author: '花実',
                    authorId: '231169',
                    avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/23/11/69_avatar_small.jpg',
                    message: '活该你日和你国同性恋权益烂的要死',
                    dateline: '2026-6-21 12:31',
                  ),
                ],
                ratingSummary: const ThreadPostRatingSummary(
                  participantText: '参与人数 1',
                  scoreText: '积分 +2',
                  viewAllUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=viewratings&tid=100&pid=1',
                  ratings: <ThreadPostRating>[
                    ThreadPostRating(
                      userName: '子子子车',
                      userId: '736594',
                      score: '+ 2',
                      reason: '我很赞同',
                    ),
                  ],
                ),
                poll: const ThreadPoll(
                  isMultipleChoice: false,
                  summary: '单选投票 , 投票后结果可见, 共有 2 人参与投票',
                  participantCount: 2,
                  rulesText: '单选投票 , 投票后结果可见',
                  options: <ThreadPollOption>[
                    ThreadPollOption(id: '1', label: '选项A'),
                    ThreadPollOption(id: '2', label: '选项B'),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '2',
          subject: '测试主题',
          author: 'alice',
          replies: 1,
          views: 12,
          currentPage: 2,
          lastPage: 2,
          previousPageUrl:
              'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
          reverseOrderUrl: null,
          onlyAuthorUrl: null,
          shareUrl: 'https://bbs.yamibo.com/home.php?mod=spacecp&ac=share&type=thread&id=100',
          homeUrl: 'https://bbs.yamibo.com/index.php',
          desktopUrl:
              'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=2',
          perPage: 1,
          posts: [
            ThreadPost(
              pid: 'p2',
              author: 'bob',
              authorId: '2',
              message: '<div>第二条回复</div>',
              number: 2,
              isFirst: false,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, postRatingsRepository: ratingsRepository),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('thread-detail-list')), findsOneWidget);
    expect(find.text('海域區'), findsOneWidget);
    expect(_appBarTitleText('海域區'), findsOneWidget);
    expect(_appBarTitleText('测试主题'), findsNothing);
    expect(
      find.byKey(const Key('thread-detail-appbar-reply-button')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.star_border_outlined), findsOneWidget);
    expect(find.byKey(const Key('thread-detail-share-button')), findsNothing);
    expect(
      _centerDxOf(
        tester,
        find.byKey(const Key('thread-detail-appbar-reply-button')),
      ),
      lessThan(
        _centerDxOf(
          tester,
          find.byKey(const Key('thread-detail-favorite-button')),
        ),
      ),
    );
    expect(find.byKey(const Key('thread-detail-header-card')), findsNothing);
    expect(
      find.byKey(const Key('thread-detail-first-post-summary')),
      findsOneWidget,
    );
    expect(find.text('理性探讨'), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('第 1 / 2 页'), findsNothing);
    expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
    expect(find.byType(ThreadPostCard), findsNothing);
    final detailPalette = ThreadDetailNativePalette.resolve(
      Theme.of(tester.element(find.byType(ThreadDetailPage))),
      continuous: true,
    );
    expect(_richTextContaining('第一条回复'), findsOneWidget);
    expect(find.byKey(const Key('thread-poll-card')), findsOneWidget);
    expect(find.text('选项A'), findsOneWidget);
    final pollSubmitBeforeSelection = tester.widget<FilledButton>(
      find.byKey(const Key('thread-poll-submit-button')),
    );
    expect(pollSubmitBeforeSelection.onPressed, isNull);
    expect(find.byKey(const Key('thread-post-actions-p1')), findsNothing);
    expect(find.text('评分'), findsOneWidget);
    expect(find.text('点评'), findsOneWidget);
    expect(
      find.byKey(const Key('thread-post-comment-section')),
      findsOneWidget,
    );
    final pollCard = tester.widget<Container>(
      find.byKey(const Key('thread-poll-card')),
    );
    final pollCardDecoration = pollCard.decoration as BoxDecoration;
    expect(pollCardDecoration.color, detailPalette.panelBackground);
    expect(pollCardDecoration.border, isNull);
    final pollSummaryText = tester.widget<Text>(find.text('单选投票 , 投票后结果可见'));
    expect(pollSummaryText.style?.fontWeight, FontWeight.w400);
    final pollOptionText = tester.widget<Text>(find.text('选项A'));
    expect(pollOptionText.style?.fontWeight, FontWeight.w400);

    await tester.tap(find.byKey(const Key('thread-poll-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('选项A'), findsNothing);
    expect(find.byKey(const Key('thread-poll-submit-button')), findsNothing);
    expect(find.text('2项'), findsNothing);
    expect(find.text('2人'), findsNothing);

    await tester.tap(find.byKey(const Key('thread-poll-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('选项A'), findsOneWidget);
    expect(find.byKey(const Key('thread-poll-submit-button')), findsOneWidget);
    final commentSection = tester.widget<Container>(
      find.byKey(const Key('thread-post-comment-section')),
    );
    final commentSectionDecoration = commentSection.decoration as BoxDecoration;
    expect(commentSectionDecoration.color, isNull);
    expect(
      commentSectionDecoration.border,
      Border(left: BorderSide(color: detailPalette.ratingBar, width: 2.5)),
    );
    expect(find.text('花実'), findsOneWidget);
    expect(find.text('活该你日和你国同性恋权益烂的要死'), findsOneWidget);
    expect(find.text('2026-6-21 12:31'), findsOneWidget);
    expect(find.byKey(const Key('thread-post-rating-section')), findsOneWidget);
    final ratingSection = tester.widget<Container>(
      find.byKey(const Key('thread-post-rating-section')),
    );
    final ratingSectionDecoration = ratingSection.decoration as BoxDecoration;
    expect(ratingSectionDecoration.color, isNull);
    expect(
      ratingSectionDecoration.border,
      Border(left: BorderSide(color: detailPalette.ratingBar, width: 2.5)),
    );
    expect(find.text('参与人数 1'), findsOneWidget);
    expect(find.text('积分 +2'), findsOneWidget);
    expect(find.text('子子子车'), findsOneWidget);
    expect(find.text('我很赞同'), findsOneWidget);
    expect(find.text('查看全部评分'), findsNothing);
    expect(
      find.byKey(const Key('thread-post-rating-load-all-indicator')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('thread-post-comment-header')),
        matching: find.byIcon(Icons.keyboard_arrow_down),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('thread-post-comment-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('花実'), findsNothing);
    expect(find.text('活该你日和你国同性恋权益烂的要死'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('thread-post-comment-section')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('thread-post-comment-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('花実'), findsOneWidget);
    expect(find.text('活该你日和你国同性恋权益烂的要死'), findsOneWidget);

    await tester.tap(find.byKey(const Key('thread-post-rating-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('参与人数 1'), findsNothing);
    expect(find.text('积分 +2'), findsNothing);
    expect(find.text('子子子车'), findsNothing);
    expect(find.text('查看全部评分'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('thread-post-rating-section')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('thread-post-rating-section')),
        matching: find.text('+2'),
      ),
      findsOneWidget,
    );

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('thread-post-rating-header'))),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('thread-post-rating-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('参与人数 1'), findsOneWidget);
    expect(find.text('积分 +2'), findsOneWidget);
    expect(find.text('子子子车'), findsOneWidget);
    expect(find.text('查看全部评分'), findsNothing);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('thread-post-rating-body'))),
      alignment: .5,
    );
    await tester.pump();
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('thread-post-rating-body'))) +
          const Offset(30, 25),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('thread-post-rating-body'))) +
          const Offset(30, 25),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('thread-post-rating-loading-indicator')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('完整评分用户'), findsOneWidget);
    expect(find.text('2026-7-24 10:00'), findsOneWidget);
    expect(find.text('参与人数 2'), findsOneWidget);
    expect(find.text('积分 +5 点'), findsOneWidget);
    expect(ratingsRepository.loadCount, 1);

    await tester.tap(find.byKey(const Key('thread-post-rating-header')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('thread-post-rating-header')));
    await tester.pump();
    expect(find.text('完整评分用户'), findsOneWidget);
    expect(ratingsRepository.loadCount, 1);
    expect(
      find.byKey(const Key('thread-detail-replies-header')),
      findsOneWidget,
    );
    expect(find.text('全部回复'), findsNothing);
    expect(find.byKey(const Key('thread-reply-input')), findsNothing);
    expect(find.byKey(const Key('thread-reply-submit-button')), findsNothing);

    await tester.dragUntilVisible(
      find.byKey(const Key('thread-detail-load-more-button')),
      find.byKey(const Key('thread-detail-list')),
      const Offset(0, -260),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('thread-detail-load-more-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('thread-detail-jump-page-button')),
      findsOneWidget,
    );
    expect(find.text('下一页'), findsOneWidget);
    expect(find.byKey(const Key('thread-detail-page-label')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('thread-detail-page-label')),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('thread-detail-load-more-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(_richTextContaining('第一条回复'), findsNothing);
    expect(_richTextContaining('第二条回复'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('thread-post-card-p2'))).dy,
      lessThan(120 + _repliesHeaderHeight(tester)),
    );
    expect(
      find.byKey(const Key('thread-detail-bottom-favorite-button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('返回首页'), findsOneWidget);
    expect(find.text('电脑版'), findsNothing);
    expect(callCount, 2);

    await tester.tap(find.text('倒序浏览'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(repository.queryHistory.last['ordertype'], '1');
    expect(_richTextContaining('第一条回复'), findsOneWidget);
    expect(callCount, 3);
  });

  testWidgets(
    'Phase 0 baseline commits non-empty posts then changes pages in place',
    (tester) async {
      final firstPageResult = Completer<ApiResult<ThreadDetailData>>();
      final historyRecorder = _RecordingHistoryVisitRecorder();
      final historyDiagnostics = _RecordingHistoryDiagnostics();
      var callCount = 0;
      final repository = _FakeThreadRepository((tid, page, query) async {
        callCount++;
        if (page == 1) {
          return firstPageResult.future;
        }
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '2',
            forumName: '测试版块',
            subject: '测试主题',
            author: 'alice',
            replies: 2,
            views: 12,
            currentPage: 2,
            lastPage: 2,
            previousPageUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
            desktopUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=2',
            perPage: 1,
            posts: <ThreadPost>[
              ThreadPost(
                pid: 'phase0-p2',
                author: 'bob',
                authorId: '2',
                message: '<p>第二页正文</p>',
                number: 2,
                isFirst: false,
                dateline: 'today',
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(
          repository,
          historyVisitRecorder: historyRecorder,
          historyDiagnosticRecorder: historyDiagnostics,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('thread-detail-list')), findsNothing);
      expect(callCount, 1);
      expect(historyRecorder.drafts, isEmpty);

      firstPageResult.complete(
        ApiSuccess<ThreadDetailData>(
          ThreadDetailData(
            tid: '100',
            fid: '2',
            forumName: '测试版块',
            subject: '测试主题',
            author: 'alice',
            replies: 2,
            views: 12,
            currentPage: 1,
            lastPage: 2,
            nextPageUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=2',
            desktopUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
            perPage: 1,
            posts: <ThreadPost>[
              ThreadPost(
                pid: 'phase0-p1',
                author: 'alice',
                authorId: '1',
                message: '<p>第一页正文</p>',
                number: 1,
                isFirst: true,
                dateline: 'today',
                avatarUrl: 'https://bbs.yamibo.com/avatar/alice.jpg',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(const Key('thread-detail-list')), findsOneWidget);
      expect(
        find.byKey(const Key('thread-post-card-phase0-p1')),
        findsOneWidget,
      );
      expect(callCount, 1);
      expect(historyRecorder.drafts, hasLength(1));
      final draft = historyRecorder.drafts.single;
      expect(
        draft.target,
        const HistoryTargetKey(type: HistoryTargetType.thread, id: '100'),
      );
      expect(draft.title, '测试主题');
      expect(draft.forumName, '测试版块');
      expect(draft.page, 1);
      expect(draft.thumbnail, isNull);

      await tester.dragUntilVisible(
        find.byKey(const Key('thread-detail-load-more-button')),
        find.byKey(const Key('thread-detail-list')),
        const Offset(0, -260),
      );
      await tester.tap(find.byKey(const Key('thread-detail-load-more-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(find.byKey(const Key('thread-post-card-phase0-p1')), findsNothing);
      expect(
        find.byKey(const Key('thread-post-card-phase0-p2')),
        findsOneWidget,
      );
      expect(callCount, 2);
      expect(historyRecorder.drafts, hasLength(1));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ThreadDetailPage)),
      );
      const args = ThreadDetailArgs(tid: '100', subject: '测试主题');
      await container
          .read(threadDetailControllerProvider(args).notifier)
          .refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(historyRecorder.drafts, hasLength(1));
      expect(
        historyDiagnostics.skipReasons,
        contains('route_session_duplicate'),
      );
    },
  );

  testWidgets(
    'failed next page keeps content, stays scrolled, and bottom label opens picker',
    (tester) async {
      final repository = _FakeThreadRepository((
        String tid,
        int page,
        Map<String, String> query,
      ) async {
        if (page == 2) {
          return const ApiFailure<ThreadDetailData>(
            ApiError(type: ApiErrorType.network, message: 'page 2 failed'),
          );
        }
        return ApiSuccess<ThreadDetailData>(
          ThreadDetailData(
            tid: tid,
            fid: '2',
            subject: '测试主题',
            author: 'alice',
            replies: 20,
            views: 100,
            currentPage: 1,
            lastPage: 2,
            perPage: 1,
            nextPageUrl: 'https://bbs.yamibo.com/thread-100-2-1.html',
            posts: [
              for (var i = 1; i <= 5; i++)
                _post(
                  pid: 'keep-p$i',
                  author: 'alice',
                  authorId: '1',
                  number: i,
                  isFirst: i == 1,
                  message: List.generate(
                    6,
                    (line) => '<p>第 $i 楼 第 $line 段内容</p>',
                  ).join(),
                ),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();

      await tester.dragUntilVisible(
        find.byKey(const Key('thread-detail-load-more-button')),
        find.byKey(const Key('thread-detail-list')),
        const Offset(0, -260),
      );
      final listController = tester
          .widget<CustomScrollView>(find.byKey(const Key('thread-detail-list')))
          .controller!;
      listController.jumpTo(listController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final offsetBefore = listController.offset;
      expect(offsetBefore, greaterThan(0));

      await tester.tap(find.byKey(const Key('thread-detail-load-more-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(const Key('thread-post-card-keep-p5')), findsOneWidget);
      final offsetAfter = listController.offset;
      expect(offsetAfter, closeTo(offsetBefore, 40));

      await tester.tap(find.byKey(const Key('thread-detail-page-label')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('thread-page-picker-popup')), findsOneWidget);
    },
  );
}
