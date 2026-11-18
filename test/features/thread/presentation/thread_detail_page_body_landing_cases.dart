part of 'thread_detail_page_test.dart';

void _bodyLandingCases() {
  testWidgets('body-end landing reveals the target body above its footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: '正文末尾定位',
          author: 'author',
          replies: 1,
          views: 12,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'before',
              author: 'author',
              authorId: '1',
              message: List.generate(70, (i) => '<p>前楼 $i</p>').join(),
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
            ThreadPost(
              pid: 'target',
              author: 'author',
              authorId: '1',
              message: List.generate(45, (i) => '<p>目标正文 $i</p>').join(),
              number: 2,
              isFirst: false,
              dateline: 'today',
            ),
          ],
        ),
      ),
    );

    final textScale = ValueNotifier<double>(1);
    addTearDown(textScale.dispose);

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: ValueListenableBuilder<double>(
          valueListenable: textScale,
          builder: (context, scale, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: const ThreadDetailPage(
              tid: '100',
              targetPid: 'target',
              landing: ThreadPostLanding.bodyEnd,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewport = find.byKey(const Key('thread-detail-list'));
    final body = find.byKey(const Key('thread-post-body-entry-target'));
    final footer = find.byKey(const Key('thread-post-footer-entry-target'));
    expect(body, findsOneWidget);
    expect(footer, findsOneWidget);
    expect(
      find.byKey(const Key('thread-post-card-entry-before')),
      findsNothing,
    );
    final viewportTop = tester.getTopLeft(viewport).dy;
    final footerTop = tester.getTopLeft(footer).dy;
    final viewportHeight = tester.getSize(viewport).height;
    final headerHeight = _repliesHeaderHeight(tester);
    expect(
      footerTop - viewportTop,
      inInclusiveRange(
        25 + headerHeight,
        viewportHeight * 0.18 + 2 + headerHeight,
      ),
    );
    expect(tester.getBottomLeft(body).dy, closeTo(footerTop, 1));
    final initialAnchor = tester.widget<CustomScrollView>(viewport).anchor;
    expect(initialAnchor, greaterThan(0));

    await _longPressVisibleTop(tester, footer);
    await _pumpThreadUiTransition(tester);
    expect(find.byKey(const Key('thread-post-action-sheet')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('thread-post-action-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.drag(viewport, const Offset(0, -90));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: viewport, matching: find.byType(Scrollable)),
    );
    final scrolledPixels = scrollable.position.pixels;
    expect(scrolledPixels, greaterThan(0));
    textScale.value = 1.4;
    await tester.pumpAndSettle();
    expect(
      tester.widget<CustomScrollView>(viewport).anchor,
      greaterThan(initialAnchor),
    );
    expect(scrollable.position.pixels, closeTo(scrolledPixels, 1));
  });

  testWidgets('body-end landing keeps an empty footer on a short last post', (
    tester,
  ) async {
    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: '短正文定位',
          author: 'author',
          replies: 0,
          views: 12,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'only',
              author: 'author',
              authorId: '1',
              message: '<p>短正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
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
          targetPid: 'only',
          landing: ThreadPostLanding.bodyEnd,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footer = find.byKey(const Key('thread-post-footer-entry-only'));
    final body = find.byKey(const Key('thread-post-body-entry-only'));
    expect(footer, findsOneWidget);
    expect(
      tester.getBottomLeft(body).dy,
      closeTo(tester.getTopLeft(footer).dy, 1),
    );
    expect(
      find.byKey(const Key('thread-detail-target-scroll-spacer')),
      findsOneWidget,
    );
  });

  testWidgets('floor navigation walks reply images in body order and back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeThreadRepository(
      (tid, page, query) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            _post(
              pid: 'image-nav-p1',
              author: 'alice',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: List.generate(8, (line) => '<p>首楼段落 $line</p>').join(),
            ),
            _post(
              pid: 'image-nav-p2',
              author: 'bob',
              authorId: '2',
              number: 2,
              message:
                  '<img src="https://example.com/nav-a.jpg" width="300" height="400">'
                  '<p>图间文字</p>'
                  '<img src="https://example.com/nav-b.jpg" width="300" height="500">'
                  '<p>本楼尾部</p>',
            ),
            _post(
              pid: 'image-nav-p3',
              author: 'carol',
              authorId: '3',
              number: 3,
              message: List.generate(40, (line) => '<p>第三楼段落 $line</p>').join(),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        imageCacheService: _RecordingImageCacheService(),
      ),
    );
    await _pumpThreadBodyUntil(
      tester,
      () => find
          .byKey(const Key('thread-post-card-image-nav-p2'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('thread-detail-list'));
    final listTop = tester.getTopLeft(list).dy;
    final headerHeight = _repliesHeaderHeight(tester);
    expect(headerHeight, greaterThan(0));
    final next = find.byKey(const Key('thread-next-post-button'));
    final previous = find.byKey(const Key('thread-previous-post-button'));
    final imageA = find.byKey(
      const Key('thread-post-html-first-readable-image-image-nav-p2-0'),
    );
    final imageB = find.byKey(
      const Key('thread-post-html-first-readable-image-image-nav-p2-1'),
    );
    final p2 = find.byKey(const Key('thread-post-card-image-nav-p2'));
    final p3 = find.byKey(const Key('thread-post-card-image-nav-p3'));

    Future<void> settleNavigation() async {
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> expectBelowHeader(Finder finder) async {
      await settleNavigation();
      expect(finder, findsOneWidget);
      expect(tester.getTopLeft(finder).dy, closeTo(listTop + headerHeight, 2));
    }

    await tester.tap(next);
    await expectBelowHeader(p2);
    await tester.tap(next);
    await expectBelowHeader(imageA);

    // 手动滚入长图中部后，前进与后退都从实测位置取相邻落点。
    await tester.drag(list, const Offset(0, -120));
    await settleNavigation();
    await tester.tap(next);
    await expectBelowHeader(imageB);
    await tester.tap(previous);
    await expectBelowHeader(imageA);

    await tester.tap(next);
    await expectBelowHeader(imageB);
    await tester.tap(next);
    await expectBelowHeader(p3);

    // 向上按相反顺序退入图片楼，先落在最后一个图片点。
    await tester.tap(previous);
    await expectBelowHeader(imageB);
    await tester.tap(previous);
    await expectBelowHeader(imageA);
    await tester.tap(previous);
    await expectBelowHeader(p2);
  });

  testWidgets(
    'a tall single image is one stop between its floor header and next floor',
    (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeThreadRepository(
        (tid, page, query) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'tall-image-p1',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: '<p>主楼正文</p>',
              ),
              _post(
                pid: 'tall-image-p2',
                author: 'bob',
                authorId: '2',
                number: 2,
                message:
                    '<img src="https://example.com/tall.jpg" width="300" height="1800">'
                    '<p>长图之后的文字</p>',
              ),
              _post(
                pid: 'tall-image-p3',
                author: 'carol',
                authorId: '3',
                number: 3,
                message: List.generate(
                  30,
                  (line) => '<p>第三楼段落 $line</p>',
                ).join(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          imageCacheService: _RecordingImageCacheService(),
        ),
      );
      final tallImage = find.byKey(
        const Key('thread-post-html-first-readable-image-tall-image-p2-0'),
      );
      await _pumpThreadBodyUntil(tester, () => tallImage.evaluate().isNotEmpty);
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('thread-detail-list'));
      final listTop = tester.getTopLeft(list).dy;
      final headerHeight = _repliesHeaderHeight(tester);
      final next = find.byKey(const Key('thread-next-post-button'));
      final previous = find.byKey(const Key('thread-previous-post-button'));
      final p1 = find.byKey(const Key('thread-post-card-tall-image-p1'));
      final p2 = find.byKey(const Key('thread-post-card-tall-image-p2'));
      final p3 = find.byKey(const Key('thread-post-card-tall-image-p3'));

      Future<void> settleNavigation() async {
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> expectBelowHeader(Finder finder) async {
        await settleNavigation();
        expect(finder, findsOneWidget);
        expect(
          tester.getTopLeft(finder).dy,
          closeTo(listTop + headerHeight, 2),
        );
      }

      await tester.tap(next);
      await expectBelowHeader(p2);
      await tester.tap(next);
      await expectBelowHeader(tallImage);
      await tester.tap(next);
      await expectBelowHeader(p3);
      await tester.tap(previous);
      await expectBelowHeader(tallImage);
      await tester.tap(previous);
      await expectBelowHeader(p2);
      await tester.tap(previous);
      await settleNavigation();
      expect(tester.getTopLeft(p1).dy, closeTo(listTop, 2));
    },
  );

  testWidgets('late body image dimensions keep the footer landing stable', (
    tester,
  ) async {
    const message =
        '<p>章节末段</p>'
        '<img file="data/attachment/forum/late.jpg">'
        '<p>正文最后一行</p>';
    final post = ThreadPost(
      pid: 'image-target',
      author: 'alice',
      authorId: '1',
      message: message,
      number: 1,
      isFirst: true,
      dateline: 'today',
    );
    final state = ThreadDetailPageState.initial(
      tid: '100',
      subject: '图片定位',
    ).copyWith(posts: [post]);
    final dimensions = _DelayedForumImageDimensions();
    final images = _FailedThreadInlineImageCacheService();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var visibleCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(images),
          forumImageDimensionIndexProvider.overrideWithValue(dimensions),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ThreadDetailContent(
              state: state,
              scrollController: controller,
              targetPid: post.pid,
              landing: ThreadPostLanding.bodyEnd,
              onTargetVisible: (_) => visibleCount++,
              imageReferer: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
              onLoadPreviousPage: () {},
              onLoadNextPage: () {},
              onLoadPageNumber: (_) {},
              onOpenAuthorProfile: (_) {},
              onOpenCommentAuthorProfile: (_) {},
              onCopyActionUrl: (_, _) {},
              onOpenPostLink: (_) {},
              onOpenPostActions: (_) {},
              onTogglePollOption: (_, _) {},
              onSubmitPollVote: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final footer = find.byKey(
      const Key('thread-post-footer-entry-image-target'),
    );
    final body = find.byKey(const Key('thread-post-body-entry-image-target'));
    final imageLayout = find.descendant(
      of: body,
      matching: find.byElementPredicate(
        (element) =>
            element is RenderObjectElement &&
            element.renderObject is RenderAspectRatio,
      ),
    );
    expect(imageLayout, findsOneWidget);
    final initialImageSize = tester.getSize(imageLayout);
    final initialBodyHeight = tester.getSize(body).height;
    final initialTop = tester.getTopLeft(footer).dy;
    expect(
      dimensions.queriedSpecs.map((spec) => spec.sourceUrl),
      contains('https://bbs.yamibo.com/data/attachment/forum/late.jpg'),
    );
    expect(visibleCount, 1);

    dimensions.pending.complete(
      const ForumImageDimensions(
        width: 100,
        height: 280,
        source: ForumImageDimensionSource.cacheMetadata,
      ),
    );
    await tester.pumpAndSettle();
    final resizedImage = tester.getSize(imageLayout);
    expect(resizedImage.height, greaterThan(initialImageSize.height + 100));
    expect(resizedImage.aspectRatio, closeTo(100 / 280, 0.001));
    expect(tester.getSize(body).height, greaterThan(initialBodyHeight + 100));
    expect(tester.getTopLeft(footer).dy, closeTo(initialTop, 1));
    expect(controller.offset, closeTo(0, 1));
    expect(visibleCount, 1);
  });

  testWidgets('rating expansion does not move a body-end landing', (
    tester,
  ) async {
    final ratings = _FakeThreadPostRatingsRepository();
    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: '评分定位',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'rated',
              author: 'alice',
              authorId: '1',
              message: '<p>正文尾声</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              ratingSummary: const ThreadPostRatingSummary(
                participantText: '参与人数 1',
                scoreText: '积分 +2',
                viewAllUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=viewratings&tid=100&pid=rated',
                ratings: [
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
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        postRatingsRepository: ratings,
        home: const ThreadDetailPage(
          tid: '100',
          targetPid: 'rated',
          landing: ThreadPostLanding.bodyEnd,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final footer = find.byKey(const Key('thread-post-footer-entry-rated'));
    final initialTop = tester.getTopLeft(footer).dy;
    await tester.tap(find.byKey(const Key('thread-post-rating-body')));
    await tester.pumpAndSettle();
    expect(ratings.loadCount, 1);
    expect(find.text('完整评分用户'), findsOneWidget);
    expect(tester.getTopLeft(footer).dy, closeTo(initialTop, 1));
  });

  testWidgets('locates findpost link before opening native thread page', (
    tester,
  ) async {
    final historyRecorder = _RecordingHistoryVisitRecorder();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: tid == '572057' ? '目标帖子' : '来源帖子',
          author: 'alice',
          replies: 2,
          views: 12,
          currentPage: page,
          lastPage: 2,
          perPage: 20,
          posts: [
            if (tid == '572057' && page == 2)
              ThreadPost(
                pid: '41554030',
                author: 'target',
                authorId: '2',
                message: '<p>定位后的楼层</p>',
                number: 2,
                isFirst: false,
                dateline: 'today',
              )
            else
              ThreadPost(
                pid: 'source',
                author: 'alice',
                authorId: '1',
                message: '<a href="https://bbs.yamibo.com/forum.php?mod=redirect&goto=findpost&ptid=572057&pid=41554030&fromuid=420637">findpost</a>',
                number: 1,
                isFirst: true,
                dateline: 'today',
              ),
          ],
        ),
      );
    });
    final locator = _FakeThreadPostLocator(
      const ThreadPostLocation(
        tid: '572057',
        pid: '41554030',
        page: 2,
        url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=572057&page=2#pid41554030',
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        threadPostLocator: locator,
        historyVisitRecorder: historyRecorder,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(historyRecorder.drafts, hasLength(1));
    expect(historyRecorder.drafts.single.target.id, '100');

    await tester.tapAt(
      tester.getTopLeft(_richTextContaining('findpost')) + const Offset(4, 8),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(locator.lastTid, '572057');
    expect(locator.lastPid, '41554030');
    expect(locator.lastSourceUri?.query, contains('goto=findpost'));
    expect(find.byKey(const Key('thread-post-card-41554030')), findsOneWidget);
    expect(_richTextContaining('定位后的楼层'), findsOneWidget);
    expect(historyRecorder.drafts, hasLength(2));
    expect(historyRecorder.drafts.last.target.id, '572057');
  });

  for (final lowRam in [false, true]) {
    testWidgets(
      'keeps large pages lazy with the ${lowRam ? 'low-memory' : 'ordinary'} production window',
      (tester) async {
        final previousProfile = DeviceMemoryProfileStore.current;
        DeviceMemoryProfileStore.current = DeviceMemoryProfile(
          isLowRamDevice: lowRam,
          memoryClassMb: 256,
        );
        addTearDown(() => DeviceMemoryProfileStore.current = previousProfile);
        final repository = _FakeThreadRepository((tid, page) async {
          return ApiSuccess(
            ThreadDetailData(
              tid: tid,
              fid: '55',
              subject: '大文本帖子',
              author: 'alice',
              replies: 80,
              views: 12,
              currentPage: 1,
              lastPage: 1,
              perPage: 80,
              posts: [
                for (var index = 0; index < 80; index++)
                  ThreadPost(
                    pid: 'bulk-$index',
                    author: 'author',
                    authorId: '$index',
                    message: '<p>正文 $index ${'长文本 '.padRight(260, 'x')}</p>',
                    number: index + 1,
                    isFirst: index == 0,
                    dateline: 'today',
                  ),
              ],
            ),
          );
        });

        await tester.pumpWidget(
          _buildTestApp(
            repository,
            forumImagePrecacheService: _RecordingForumImagePrecacheService(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final list = tester.widget<ScrollView>(
          find.byKey(const Key('thread-detail-list')),
        );
        expect(
          list.scrollCacheExtent,
          ScrollCacheExtent.viewport(lowRam ? 1 : 3),
        );
        final body = tester
            .widgetList<ThreadPostHtmlFirstBody>(
              find.byType(ThreadPostHtmlFirstBody),
            )
            .first;
        final viewport = body.imageViewportCoordinator!;
        expect(viewport.maxVisibleFirstFrames, lowRam ? 2 : 4);
        expect(viewport.maxConcurrentOptionalWork, lowRam ? 1 : 2);
        expect(viewport.predecodePolicy!.forwardImageCount, lowRam ? 1 : 3);
        expect(
          viewport.predecodePolicy!.forwardDiskExtentFactor,
          lowRam ? 1 : 3,
        );
        expect(
          find.byKey(const Key('thread-post-card-bulk-0')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('thread-post-card-bulk-79')), findsNothing);
      },
    );
  }
}
