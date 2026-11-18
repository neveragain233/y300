part of 'thread_detail_page_test.dart';

void _pageChromeCases() {
  testWidgets('uses initial forum name before parsed thread detail arrives', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>缓存正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _threadDetailOverrides(repository),
        child: const LocalizedTestApp(
          home: ThreadDetailPage(
            tid: '100',
            subject: '测试主题',
            initialForumName: '公告区',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(_appBarTitleText('公告区'), findsOneWidget);
    expect(_appBarTitleText('帖子详情'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
    expect(_appBarTitleText('公告区'), findsOneWidget);
  });

  testWidgets('current page button opens page menu and returns top', (
    tester,
  ) async {
    final requestedPages = <int>[];
    final repository = _FakeThreadRepository((tid, page, query) async {
      requestedPages.add(page);
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 80,
          views: 120,
          currentPage: page,
          lastPage: 20,
          previousPageUrl: page > 1
              ? 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=${page - 1}'
              : null,
          nextPageUrl: page < 20
              ? 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=${page + 1}'
              : null,
          perPage: 1,
          posts: [
            ThreadPost(
              pid: 'p$page',
              author: 'alice',
              authorId: '1',
              message: '<p>第$page页正文</p>',
              number: page,
              isFirst: page == 1,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.dragUntilVisible(
      find.byKey(const Key('thread-detail-jump-page-button')),
      find.byKey(const Key('thread-detail-list')),
      const Offset(0, -260),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('thread-detail-jump-page-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-detail-page-list')), findsOneWidget);
    expect(find.byKey(const Key('thread-detail-page-input')), findsOneWidget);
    expect(
      find.byKey(const Key('thread-detail-page-option-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('thread-detail-page-option-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(requestedPages, <int>[1, 3]);
    expect(_richTextContaining('第3页正文'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('thread-post-card-p3'))).dy,
      lessThan(120 + _repliesHeaderHeight(tester)),
    );

    await tester.dragUntilVisible(
      find.byKey(const Key('thread-detail-jump-page-button')),
      find.byKey(const Key('thread-detail-list')),
      const Offset(0, -260),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('thread-detail-jump-page-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('thread-detail-page-input')),
      '8',
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.threadControlsJumpPage),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(requestedPages, <int>[1, 3, 8]);
    expect(_richTextContaining('第8页正文'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('thread-post-card-p8'))).dy,
      lessThan(120 + _repliesHeaderHeight(tester)),
    );

    await tester.dragUntilVisible(
      find.byKey(const Key('thread-detail-previous-page-button')),
      find.byKey(const Key('thread-detail-list')),
      const Offset(0, -260),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('thread-detail-previous-page-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(requestedPages, <int>[1, 3, 8, 7]);
    expect(_richTextContaining('第7页正文'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('thread-post-card-p7'))).dy,
      lessThan(120 + _repliesHeaderHeight(tester)),
    );
  });

  testWidgets(
    'reply controls combine author and order filters and keep first post pinned',
    (tester) async {
      final historyRecorder = _RecordingHistoryVisitRecorder();
      final repository = _FakeThreadRepository((tid, page, query) async {
        final isAuthorOnly = query['authorid'] == '1';
        final isReverse = query['ordertype'] == '1';
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '33',
            subject: '测试主题',
            author: 'alice',
            replies: 2,
            views: 12,
            currentPage: page,
            lastPage: 1,
            reverseOrderUrl: isReverse ? null : 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&ordertype=1',
            onlyAuthorUrl: isAuthorOnly
                ? null
                : 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&authorid=${isReverse ? 99 : 1}',
            desktopUrl:
                'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=$page',
            perPage: 3,
            posts: isReverse
                ? <ThreadPost>[
                    _post(
                      pid: 'p3',
                      author: 'alice',
                      authorId: '1',
                      number: 3,
                      message: '<p>倒序回复</p>',
                    ),
                    _post(
                      pid: 'p1',
                      author: 'alice',
                      authorId: '1',
                      number: 1,
                      isFirst: true,
                      message: '<p>主楼正文</p>',
                    ),
                  ]
                : <ThreadPost>[
                    _post(
                      pid: 'p1',
                      author: 'alice',
                      authorId: '1',
                      number: 1,
                      isFirst: true,
                      message: '<p>主楼正文</p>',
                    ),
                    if (!isAuthorOnly)
                      _post(
                        pid: 'p2',
                        author: 'bob',
                        authorId: '2',
                        number: 2,
                        message: '<p>其他作者回复</p>',
                      ),
                  ],
          ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(repository, historyVisitRecorder: historyRecorder),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(historyRecorder.drafts, hasLength(1));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThreadDetailPage)),
      );
      final header = find.byKey(const Key('thread-detail-replies-header'));
      expect(
        find.descendant(
          of: find.byKey(const Key('thread-detail-replies-header')),
          matching: find.text(l10n.threadDetailReplyCount(2)),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(header).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('thread-post-card-p1'))).dy,
        ),
      );
      expect(
        tester.getBottomLeft(header).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const Key('thread-post-card-p2'))).dy,
        ),
      );

      await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(repository.queryHistory.last['authorid'], '1');
      expect(repository.queryHistory.last.containsKey('ordertype'), isFalse);
      await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.threadDetailAllPosts), findsOneWidget);
      expect(find.text(l10n.threadDetailReverseOrder), findsOneWidget);

      await tester.tap(find.text(l10n.threadDetailReverseOrder));
      // 菜单收回期间浮层仍拦截页面点击，等关闭完成再继续操作页面。
      await tester.pumpAndSettle();

      expect(repository.queryHistory.last['authorid'], '1');
      expect(repository.queryHistory.last['ordertype'], '1');
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-p1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('thread-post-card-p3'))).dy,
        ),
      );
      await tester.tap(find.byKey(const Key('thread-replies-order-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(repository.queryHistory.last['authorid'], '1');
      expect(repository.queryHistory.last['ordertype'], '2');
      await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(repository.queryHistory.last.containsKey('authorid'), isFalse);
      expect(repository.queryHistory.last['ordertype'], '2');
      expect(historyRecorder.drafts, hasLength(1));

      await tester.tap(find.byKey(const Key('thread-replies-order-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(repository.queryHistory.last['ordertype'], '1');
      expect(repository.queryHistory.last['authorid'], '1');
    },
  );

  testWidgets('selects and submits poll vote then reloads current page', (
    tester,
  ) async {
    var callCount = 0;
    final repository = _FakeThreadRepository((tid, page) async {
      callCount++;
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          typeid: '410',
          subject: '投票主题',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              poll: ThreadPoll(
                isMultipleChoice: false,
                summary: '单选投票 , 投票后结果可见',
                options: <ThreadPollOption>[
                  ThreadPollOption(
                    id: '1',
                    label: '选项A',
                    percent: callCount > 1 ? 100 : null,
                    voteCount: callCount > 1 ? 1 : null,
                  ),
                  const ThreadPollOption(id: '2', label: '选项B'),
                ],
              ),
            ),
          ],
        ),
      );
    });
    final pollVoteCommand = _FakeThreadPollVoteCommand();
    final invalidationService = _FakeNativePageCacheInvalidationService();

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        pollVoteCommand: pollVoteCommand,
        pageCacheInvalidationService: invalidationService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const Key('thread-poll-option-1')));
    await tester.pump();
    final submitButton = tester.widget<FilledButton>(
      find.byKey(const Key('thread-poll-submit-button')),
    );
    expect(submitButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('thread-poll-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(pollVoteCommand.called, isTrue);
    expect(pollVoteCommand.lastSubmission?.fid, '33');
    expect(pollVoteCommand.lastSubmission?.tid, '100');
    expect(pollVoteCommand.lastSubmission?.optionIds, <String>['1']);
    expect(invalidationService.invalidatedThreadIds, <String>['100']);
    expect(callCount, 2);
    expect(find.text('投票成功'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 票'), findsOneWidget);
  });

  testWidgets('shows already-voted poll results without submit action', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          typeid: '410',
          subject: '投票主题',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              poll: const ThreadPoll(
                isMultipleChoice: true,
                canVote: false,
                maxChoices: 3,
                summary: '多选投票: ( 最多可选 3 项 ), 共有 331 人参与投票',
                statusText: '您已经投过票，谢谢您的参与',
                options: <ThreadPollOption>[
                  ThreadPollOption(
                    id: '1',
                    label: '两个心灵靠近的过程',
                    percent: 38.82,
                    voteCount: 276,
                    colorHex: '#E92725',
                  ),
                  ThreadPollOption(
                    id: '2',
                    label: '背德扭曲神人爆爆爆',
                    percent: 11.25,
                    voteCount: 80,
                    colorHex: '#F27B21',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
    final pollVoteCommand = _FakeThreadPollVoteCommand();

    await tester.pumpWidget(
      _buildTestApp(repository, pollVoteCommand: pollVoteCommand),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('两个心灵靠近的过程'), findsOneWidget);
    expect(find.text('38.82%'), findsOneWidget);
    expect(find.text('276 票'), findsOneWidget);
    expect(find.text('您已经投过票，谢谢您的参与'), findsOneWidget);
    expect(find.byKey(const Key('thread-poll-submit-button')), findsNothing);

    await tester.tap(find.byKey(const Key('thread-poll-option-1')));
    await tester.pump();

    expect(pollVoteCommand.called, isFalse);
    expect(find.byIcon(Icons.check_box), findsNothing);
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
  });

  testWidgets('opens same-domain tag link from post body natively', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '30',
          subject: '漫画主题',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<a href="https://bbs.yamibo.com/misc.php?mod=tag&id=20674">目录</a>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });
    final tagRepository = _FakeForumTagDirectoryRepository();

    await tester.pumpWidget(
      _buildTestApp(repository, tagDirectoryRepository: tagRepository),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tapAt(
      tester.getTopLeft(_richTextContaining('目录')) + const Offset(4, 8),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(tagRepository.requestedQueries.single.tagId, '20674');
    expect(find.byKey(const Key('yamibo-tag-thread-page')), findsOneWidget);
  });

  testWidgets('opens same-domain thread link from post body natively', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '30',
          subject: tid == '572514' ? '跳转后的帖子' : '漫画主题',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p$tid',
              author: 'alice',
              authorId: '1',
              message: tid == '572514' ? '<p>新帖子正文</p>' : '<a href="https://bbs.yamibo.com/thread-572514-1-1.html">00</a>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tapAt(
      tester.getTopLeft(_richTextContaining('00')) + const Offset(4, 8),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('跳转后的帖子'), findsWidgets);
    expect(_richTextContaining('新帖子正文'), findsOneWidget);
  });

  testWidgets('opens viewthread pid link at target page natively', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: tid == '572057' ? '目标帖子' : '来源帖子',
          author: 'alice',
          replies: 3,
          views: 12,
          currentPage: page,
          lastPage: 3,
          perPage: 20,
          posts: tid == '572057' && page == 3
              ? [
                  for (var index = 0; index < 18; index++)
                    ThreadPost(
                      pid: index == 17 ? '41560047' : 'target-$index',
                      author: 'target',
                      authorId: '2',
                      message: index == 17
                          ? '<p>目标楼层正文</p>'
                          : '<p>占位回复 $index</p>',
                      number: index + 1,
                      isFirst: index == 0,
                      dateline: 'today',
                    ),
                ]
              : [
                  ThreadPost(
                    pid: 'source',
                    author: 'alice',
                    authorId: '1',
                    message: '<a href="https://bbs.yamibo.com/forum.php?mod=viewthread&tid=572057&page=3&extra=#pid41560047">跳到楼层</a>',
                    number: 1,
                    isFirst: true,
                    dateline: 'today',
                  ),
                ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tapAt(
      tester.getTopLeft(_richTextContaining('跳到楼层')) + const Offset(4, 8),
    );
    await tester.pumpAndSettle();

    // 目标居中列表不在首楼，顶栏直接显示帖子标题。
    expect(_appBarTitleText('目标帖子'), findsOneWidget);
    expect(find.byKey(const Key('thread-post-card-41560047')), findsOneWidget);
    expect(_richTextContaining('目标楼层正文'), findsOneWidget);
    final listTop = tester.getTopLeft(
      find.byKey(const Key('thread-detail-list')),
    );
    final targetTop = tester.getTopLeft(
      find.byKey(const Key('thread-post-card-41560047')),
    );
    expect(
      targetTop.dy,
      closeTo(
        listTop.dy + ForumContentSpacing.listTop + _repliesHeaderHeight(tester),
        28,
      ),
      reason: '目标楼层应贴在 AppBar 下方吸顶回复栏的下沿，而不是落在屏幕中部',
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('thread-detail-list')),
        matching: find.byType(Scrollable),
      ),
    );
    for (var attempt = 0; attempt < 4; attempt++) {
      scrollable.position.jumpTo(scrollable.position.minScrollExtent);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final firstPost = find.byKey(const Key('thread-post-card-target-0'));
    expect(firstPost, findsOneWidget);
    expect(
      tester.getTopLeft(firstPost).dy,
      closeTo(listTop.dy + ForumContentSpacing.listTop, 1),
    );
  });

  testWidgets(
    'locates the second post after an exceptionally long first post',
    (tester) async {
      final historyRecorder = _RecordingHistoryVisitRecorder();
      tester.view.physicalSize = const Size(390, 260);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final longFirstPost = [
        for (var index = 0; index < 120; index++) '<p>首楼中的长篇简介和目录内容 $index</p>',
      ].join();
      final repository = _FakeThreadRepository((tid, page) async {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '55',
            subject: '超长首楼定位测试',
            author: 'author',
            replies: 1,
            views: 12,
            currentPage: 1,
            lastPage: 1,
            perPage: 20,
            posts: <ThreadPost>[
              ThreadPost(
                pid: 'first-post',
                author: 'author',
                authorId: '1',
                message: longFirstPost,
                number: 1,
                isFirst: true,
                dateline: 'today',
              ),
              ThreadPost(
                pid: 'target-second-post',
                author: 'author',
                authorId: '1',
                message: '<p>第一话 姐姐的日记</p>',
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
          home: const ThreadDetailPage(
            tid: '556943',
            initialPage: 1,
            targetPid: 'target-second-post',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final listTop = tester.getTopLeft(
        find.byKey(const Key('thread-detail-list')),
      );
      final targetTop = tester.getTopLeft(
        find.byKey(const Key('thread-post-card-target-second-post')),
      );
      expect(
        targetTop.dy,
        closeTo(
          listTop.dy +
              ForumContentSpacing.listTop +
              _repliesHeaderHeight(tester),
          28,
        ),
      );
      expect(_richTextContaining('第一话 姐姐的日记'), findsOneWidget);
      expect(historyRecorder.drafts, hasLength(1));
      expect(historyRecorder.drafts.single.target.id, '556943');
      // 锚定分支走的是另一个滚动视图，下拉刷新的物理必须一起挂上。
      expect(
        tester
            .widget<CustomScrollView>(
              find.byKey(const Key('thread-detail-list')),
            )
            .physics,
        ForumPullToRefresh.scrollPhysics,
      );
    },
  );
}
