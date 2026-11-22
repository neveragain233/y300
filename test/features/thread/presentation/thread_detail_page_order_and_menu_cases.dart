part of 'thread_detail_page_test.dart';

void _orderAndMenuCases() {
  testWidgets(
    'long first post order switch resets reverse to top and anchors normal to replies header',
    (tester) async {
      tester.view.physicalSize = const Size(411, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final longFirstBody = List.generate(
        45,
        (index) => '<p>超长首楼第$index段正文内容</p>',
      ).join();
      final repository = _FakeThreadRepository((tid, page, query) async {
        final orderType = query['ordertype'];
        final reverse = orderType == '1';
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '2',
            forumName: '动漫区',
            subject: '长首楼正倒序测试',
            author: 'alice',
            replies: 10,
            views: 99,
            currentPage: page,
            lastPage: 1,
            perPage: 20,
            reverseOrderUrl: reverse
                ? 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=$tid&extra=&ordertype=2'
                : 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=$tid&extra=&ordertype=1',
            homeUrl: 'https://bbs.yamibo.com/index.php',
            posts: reverse
                ? [
                    _post(
                      pid: 'r10',
                      author: 'bob',
                      authorId: '2',
                      number: 10,
                      message: '<p>倒序最新十楼回复</p>',
                    ),
                    _post(
                      pid: 'r9',
                      author: 'carol',
                      authorId: '3',
                      number: 9,
                      message: '<p>倒序九楼回复</p>',
                    ),
                    _post(
                      pid: 'r8',
                      author: 'dave',
                      authorId: '4',
                      number: 8,
                      message: '<p>倒序八楼回复</p>',
                    ),
                  ]
                : [
                    _post(
                      pid: 'p1',
                      author: 'alice',
                      authorId: '1',
                      number: 1,
                      isFirst: true,
                      message: longFirstBody,
                    ),
                    _post(
                      pid: 'p2',
                      author: 'bob',
                      authorId: '2',
                      number: 2,
                      message: '<p>正序二楼回复</p>',
                    ),
                    _post(
                      pid: 'p3',
                      author: 'carol',
                      authorId: '3',
                      number: 3,
                      message: '<p>正序三楼回复</p>',
                    ),
                  ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pumpAndSettle();

      // Scroll deeply into the long 1st post before switching to reverse order.
      await tester.drag(
        find.byKey(const Key('thread-detail-list')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final preSwitchFirstParagraph = _richTextContaining('超长首楼第0段正文内容');
      if (preSwitchFirstParagraph.evaluate().isNotEmpty) {
        expect(
          tester.getBottomRight(preSwitchFirstParagraph).dy,
          lessThanOrEqualTo(0),
        );
      }

      await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('倒序浏览'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      expect(repository.queryHistory.last['ordertype'], '1');
      expect(_richTextContaining('倒序最新十楼回复'), findsOneWidget);
      final reverseCardTop = tester
          .getTopLeft(find.byKey(const Key('thread-post-card-r10')))
          .dy;
      expect(reverseCardTop, lessThan(180));

      // Switch back to normal order: anchor cleanly at repliesHeader above 2#.
      await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('正序浏览'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      expect(repository.queryHistory.last['ordertype'], '2');
      expect(
        find.byKey(const Key('thread-detail-replies-header')),
        findsOneWidget,
      );
      final headerTop = tester
          .getTopLeft(find.byKey(const Key('thread-detail-replies-header')))
          .dy;
      final secondPostTop = tester
          .getTopLeft(find.byKey(const Key('thread-post-card-p2')))
          .dy;
      expect(headerTop, lessThan(140));
      expect(secondPostTop, greaterThanOrEqualTo(headerTop));
      expect(secondPostTop, lessThan(260));
      final firstParagraph = _richTextContaining('超长首楼第0段正文内容');
      if (firstParagraph.evaluate().isNotEmpty) {
        expect(
          tester.getBottomRight(firstParagraph).dy,
          lessThanOrEqualTo(headerTop),
        );
      }
    },
  );

  testWidgets('back home menu returns to root instead of copying home url', (
    tester,
  ) async {
    final clipboardWrites = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>?;
          final text = args?['text'] as String?;
          if (text != null) {
            clipboardWrites.add(text);
          }
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '2',
          forumName: '动漫区',
          subject: '返回首页测试',
          author: 'alice',
          replies: 0,
          views: 5,
          currentPage: page,
          lastPage: 1,
          perPage: 20,
          homeUrl: 'https://bbs.yamibo.com/index.php',
          posts: [
            _post(
              pid: 'h1',
              author: 'alice',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>正文</p>',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _threadDetailOverrides(repository),
        child: LocalizedTestApp(
          home: AdaptiveDetailHost(
            child: Builder(
              builder: (context) => Scaffold(
                key: const Key('root-home-marker'),
                body: Center(
                  child: FilledButton(
                    key: const Key('open-thread-from-root'),
                    onPressed: () {
                      unawaited(
                        openAdaptiveDetail<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ThreadDetailPage(
                              tid: '100',
                              subject: '返回首页测试',
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-thread-from-root')));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadDetailPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('thread-detail-back-home-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ThreadDetailPage), findsNothing);
    expect(find.byKey(const Key('root-home-marker')), findsOneWidget);
    expect(clipboardWrites, isEmpty);
  });

  testWidgets('ratings start collapsed when expandRatingsByDefault is false', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferenceKeys.threadControlsV1.name: jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'expandRatingsByDefault': false,
      }),
    });

    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '2',
          forumName: '动漫区',
          subject: '评分默认折叠测试',
          author: 'alice',
          replies: 0,
          views: 10,
          currentPage: page,
          lastPage: 1,
          perPage: 20,
          posts: [
            _post(
              pid: 'r1',
              author: 'alice',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>带评分的正文</p>',
              ratingSummary: const ThreadPostRatingSummary(
                participantText: '参与人数 1',
                scoreText: '积分 +2',
                ratings: [
                  ThreadPostRating(
                    userName: '评分用户甲',
                    score: '+2',
                    reason: '很棒',
                    dateline: 'today',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-post-rating-section')), findsOneWidget);
    expect(find.text('评分用户甲'), findsNothing);
    expect(find.text('1'), findsWidgets);

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('thread-post-rating-header'))),
      alignment: 0.5,
    );
    await tester.tap(find.byKey(const Key('thread-post-rating-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('评分用户甲'), findsOneWidget);
  });
}
