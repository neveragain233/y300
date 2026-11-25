part of 'thread_detail_page_test.dart';

void _imageAndLayoutCases() {
  testWidgets('HTML-first smiley taps do not open image reader', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>表情 <img src="static/image/smiley/comcom/2.gif"></p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        imageCacheService: _RecordingImageCacheService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const Key('thread-post-html-first-readable-image-p1-0')),
      findsNothing,
    );
    expect(find.byType(ThreadImageReaderPage), findsNothing);
  });

  testWidgets('visible HTML-first images do not start a second predecode', (
    tester,
  ) async {
    final precacheService = _RecordingForumImagePrecacheService();
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message:
                  '<p>HTML-first 图片预热</p>'
                  '<img src="data/attachment/forum/page-1.jpg">'
                  '<p>表情 <img src="static/image/smiley/comcom/2.gif"></p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, forumImagePrecacheService: precacheService),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(precacheService.decodedSpecs, isEmpty);
  });

  testWidgets('production HTML-first renderer avoids post-build predecode', (
    tester,
  ) async {
    final precacheService = _RecordingForumImagePrecacheService();
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<img src="data/attachment/forum/page-1.jpg">',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, forumImagePrecacheService: precacheService),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(precacheService.decodedSpecs, isEmpty);
  });

  testWidgets('long pressing app bar copies thread link', (tester) async {
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

    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          forumName: '海域區',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          lastPage: 1,
          desktopUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
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
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.longPress(
      find.byKey(const Key('thread-detail-appbar-copy-link-area')),
    );
    await tester.pump();

    expect(copiedTexts, [
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
    ]);
    expect(find.text('帖子链接已复制'), findsOneWidget);
  });

  testWidgets('default svg author avatar uses the local default asset', (
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
              avatarUrl:
                  'https://bbs.yamibo.com/uc_server/data/avatar/noavatar.svg',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final avatar = find.byKey(const Key('thread-author-avatar-p1'));
    final image = tester.widget<CachedLibraryImage>(
      find.descendant(of: avatar, matching: find.byType(CachedLibraryImage)),
    );
    expect(image.request, isNull);
    expect(
      image.imageProviderOverride,
      isA<AssetImage>().having(
        (provider) => provider.assetName,
        'assetName',
        forumDefaultAvatarAsset,
      ),
    );
  });

  testWidgets('normal author avatar uses avatar cache request', (tester) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/00/00/01_avatar_small.jpg',
              message: '<p>正文</p>',
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
    await tester.pump();

    final avatarImage = tester.widget<CachedLibraryImage>(
      find.descendant(
        of: find.byKey(const Key('thread-author-avatar-p1')),
        matching: find.byType(CachedLibraryImage),
      ),
    );
    expect(avatarImage.request?.role, ImageCacheRole.avatar);
    expect(avatarImage.request?.ownerType, ImageCacheOwnerType.thread);
    expect(avatarImage.request?.ownerId, '1');
    expect(avatarImage.fadeInDuration, ForumCachedAvatar.fadeInDuration);
    expect(
      avatarImage.request?.sourceUrl,
      'https://bbs.yamibo.com/uc_server/data/avatar/000/00/00/01_avatar_small.jpg',
    );
  });

  testWidgets('does not predecode images from a distant built post', (
    tester,
  ) async {
    final imagePrecacheService = _RecordingForumImagePrecacheService();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message:
                  '<img file="data/attachment/forum/page-1.jpg" />'
                  '<p>表情 <img src="static/image/smiley/comcom/2.gif" /></p>'
                  '${List.filled(80, '<p>用于把第二楼推出初始 cacheExtent 的长正文。</p>').join()}',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
            ThreadPost(
              pid: 'p2',
              author: 'bob',
              authorId: '2',
              message: '<img file="data/attachment/forum/page-2.jpg" />',
              number: 2,
              isFirst: false,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _threadDetailOverrides(
          repository,
          forumImagePrecacheService: imagePrecacheService,
        ),
        child: const LocalizedTestApp(
          home: ThreadDetailPage(tid: '100', subject: '测试主题'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(
      imagePrecacheService.decodedSpecs.any(
        (spec) => spec.sourceUrl.contains('page-2.jpg'),
      ),
      isFalse,
    );
    expect(imagePrecacheService.decodedSpecs, isEmpty);
    expect(imagePrecacheService.diskSpecs.length, lessThanOrEqualTo(1));
  });

  testWidgets('stretches whole post card segments to the same width', (
    tester,
  ) async {
    final state = ThreadDetailPageState.initial(tid: '100', subject: '测试主题')
        .copyWith(
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>短正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ThreadDetailContent(
              state: state,
              imageReferer: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
              onLoadPreviousPage: () {},
              onLoadNextPage: () {},
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
    await tester.pump();

    final headerWidth = tester
        .getSize(find.byKey(const Key('thread-post-card-p1')))
        .width;
    final bodyWidth = tester
        .getSize(find.byKey(const Key('thread-post-body-p1')))
        .width;
    final footerWidth = tester
        .getSize(find.byKey(const Key('thread-post-footer-p1')))
        .width;

    expect(bodyWidth, headerWidth);
    expect(footerWidth, headerWidth);
  });

  testWidgets('collapsing comments reduces post card height', (tester) async {
    final state = ThreadDetailPageState.initial(tid: '100', subject: '测试主题')
        .copyWith(
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>短正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'alice',
                  message: '第一条点评内容',
                  dateline: 'today',
                ),
                ThreadPostCommentEntry(
                  author: 'bob',
                  message: '第二条点评内容',
                  dateline: 'today',
                ),
                ThreadPostCommentEntry(
                  author: 'carol',
                  message: '第三条点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: ThreadDetailContent(
              state: state,
              imageReferer: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
              onLoadPreviousPage: () {},
              onLoadNextPage: () {},
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

    await tester.pump();

    final expandedHeight = tester
        .getSize(find.byKey(const Key('thread-post-comment-section')))
        .height;

    await tester.tap(find.byKey(const Key('thread-post-comment-header')));
    await tester.pump();

    final collapsedHeight = tester
        .getSize(find.byKey(const Key('thread-post-comment-section')))
        .height;
    expect(collapsedHeight, lessThan(expandedHeight));
    expect(find.text('第一条点评内容'), findsNothing);
  });

  testWidgets(
    'ThreadDetailContent builds reader image request with thread context',
    (tester) async {
      ThreadImageOpenRequest? opened;
      final state = ThreadDetailPageState.initial(tid: '100', subject: '测试主题')
          .copyWith(
            currentPage: 1,
            posts: [
              ThreadPost(
                pid: 'p1',
                author: 'alice',
                authorId: '1',
                message:
                    '<img file="data/attachment/forum/page-1.jpg" width="200" height="120">'
                    '<img file="data/attachment/forum/page-2.jpg" width="200" height="120">',
                number: 1,
                isFirst: true,
                dateline: 'today',
              ),
            ],
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(
              _NoopImageCacheService(),
            ),
          ],
          child: LocalizedTestApp(
            home: Scaffold(
              body: ThreadDetailContent(
                state: state,
                imageReferer: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
                onLoadPreviousPage: () {},
                onLoadNextPage: () {},
                onOpenAuthorProfile: (_) {},
                onOpenCommentAuthorProfile: (_) {},
                onCopyActionUrl: (_, _) {},
                onOpenPostLink: (_) {},
                onOpenPostImages: (_, request) => opened = request,
                onOpenPostActions: (_) {},
                onTogglePollOption: (_, _) {},
                onSubmitPollVote: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ThreadPostHtmlBody), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('thread-post-html-first-readable-image-p1-0')),
      );
      await tester.pump();

      final readerRequest = opened;
      expect(readerRequest, isNotNull);
      expect(readerRequest!.tid, '100');
      expect(readerRequest.pid, 'p1');
      expect(readerRequest.postNumber, 1);
      expect(
        readerRequest.referer,
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
      );
      expect(readerRequest.initialIndex, 0);
      expect(readerRequest.group.entries, hasLength(2));
      expect(
        readerRequest.initialEntry?.cacheKey,
        startsWith('thread/inline/'),
      );
      expect(
        readerRequest.initialEntry?.url,
        'https://bbs.yamibo.com/data/attachment/forum/page-1.jpg',
      );
      expect(readerRequest.continuousImages, hasLength(2));
      expect(
        readerRequest.continuousImages.first.sourceKind,
        ContinuousImageSourceKind.threadImageReader,
      );
      expect(
        readerRequest.continuousImages.first.cacheKey,
        readerRequest.initialEntry?.cacheKey,
      );
    },
  );

  testWidgets('opens thread image reader page when tapping post image', (
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
              message:
                  '<img file="data/attachment/forum/page-1.jpg" width="200" height="120">'
                  '<img file="data/attachment/forum/page-2.jpg" width="200" height="120">',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await _pumpThreadBodyUntil(
      tester,
      () => find
          .byKey(const Key('thread-post-html-first-readable-image-p1-0'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(
      find.byKey(const Key('thread-post-html-first-readable-image-p1-0')),
    );
    await _pumpThreadUiTransition(tester);

    expect(find.byType(ThreadImageLightboxPage), findsOneWidget);
    expect(find.byKey(const Key('image-lightbox-page-view')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets(
    'general thread lightbox ignores comic RTL preference and stays LTR',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'reader_pref_mode': 'rtl',
      });
      final repository = _FakeThreadRepository((tid, page, query) async {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '2',
            subject: '测试主题',
            author: 'alice',
            replies: 0,
            views: 10,
            currentPage: 1,
            lastPage: 1,
            perPage: 20,
            posts: [
              _post(
                pid: 'p1',
                author: 'alice',
                authorId: '1',
                message:
                    '<img file="data/attachment/forum/page-1.jpg" width="200" height="120">'
                    '<img file="data/attachment/forum/page-2.jpg" width="200" height="120">',
                number: 1,
                isFirst: true,
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await _pumpThreadBodyUntil(
        tester,
        () => find
            .byKey(const Key('thread-post-html-first-readable-image-p1-0'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.byKey(const Key('thread-post-html-first-readable-image-p1-0')),
      );
      await _pumpThreadUiTransition(tester);

      expect(find.byType(ThreadImageLightboxPage), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.fling(
        find.byKey(const Key('image-lightbox-page-view')),
        const Offset(-300, 0),
        1200,
      );
      await _pumpImageReturnTransition(tester);
      expect(find.text('2 / 2'), findsOneWidget);
    },
  );

  testWidgets(
    'comic-section OP uses comic reader while comic-section reply uses lightbox',
    (tester) async {
      final repository = _FakeThreadRepository((tid, page, query) async {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '30',
            subject: '测试漫画',
            author: 'alice',
            replies: 1,
            views: 10,
            currentPage: 1,
            lastPage: 1,
            perPage: 20,
            posts: [
              _post(
                pid: 'op-1',
                author: 'alice',
                authorId: '1',
                message:
                    '<img file="data/attachment/forum/op-1.jpg" width="200" height="120">'
                    '<img file="data/attachment/forum/op-2.jpg" width="200" height="120">',
                number: 1,
                isFirst: true,
              ),
              _post(
                pid: 'reply-2',
                author: 'bob',
                authorId: '2',
                message: '<img file="data/attachment/forum/reply-1.jpg" width="200" height="120">',
                number: 2,
                isFirst: false,
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await _pumpThreadBodyUntil(
        tester,
        () => find
            .byKey(const Key('thread-post-html-first-readable-image-op-1-0'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.byKey(const Key('thread-post-html-first-readable-image-op-1-0')),
      );
      await _pumpThreadUiTransition(tester);
      expect(find.byType(ThreadImageReaderPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _pumpImageReturnTransition(tester);
      expect(find.byType(ThreadImageReaderPage), findsNothing);

      await _tapVisibleTop(
        tester,
        find.byKey(
          const Key('thread-post-html-first-readable-image-reply-2-0'),
        ),
      );
      await _pumpThreadUiTransition(tester);
      expect(find.byType(ThreadImageLightboxPage), findsOneWidget);
      expect(find.byType(ThreadImageReaderPage), findsNothing);
    },
  );
}
