part of 'thread_detail_page_test.dart';

void _htmlRenderingCases() {
  testWidgets('uses HTML-first body renderer by default', (tester) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>默认旧正文</p>',
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

    expect(find.byKey(const Key('thread-post-body-p1')), findsOneWidget);
    expect(find.byType(ThreadPostHtmlBody), findsOneWidget);
    expect(find.byType(ThreadPostHtmlFirstBody), findsOneWidget);
    expect(_richTextContaining('默认旧正文'), findsOneWidget);
  });

  testWidgets(
    'HTML-first diagnostic renderer keeps native poll footer separate',
    (tester) async {
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
                    '<p>HTML-first 正文</p>'
                    '<div class="showcollapse_box">'
                    '<div class="showcollapse_title">目录</div>'
                    '<div class="showcollapse_content">隐藏内容</div>'
                    '</div>',
                number: 1,
                isFirst: true,
                dateline: 'today',
                poll: const ThreadPoll(
                  isMultipleChoice: false,
                  summary: '单选投票',
                  options: <ThreadPollOption>[
                    ThreadPollOption(id: '1', label: '投票选项'),
                  ],
                ),
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const Key('thread-post-html-first-body-p1')),
        findsOneWidget,
      );
      expect(find.byType(ThreadPostHtmlFirstBody), findsOneWidget);
      expect(find.byKey(const Key('thread-poll-card')), findsOneWidget);
      expect(find.text('投票选项'), findsOneWidget);
      expect(_richTextContaining('HTML-first 正文'), findsOneWidget);
    },
  );

  testWidgets(
    'HTML-first theme changes reprepare colors without reloading the thread',
    (tester) async {
      var requestCount = 0;
      final repository = _FakeThreadRepository((tid, page, query) async {
        requestCount++;
        return ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              ThreadPost(
                pid: 'theme-p1',
                author: 'alice',
                authorId: '1',
                message: '<font id="theme-body" color="black">正文</font>',
                number: 1,
                isFirst: true,
                dateline: 'today',
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(repository, theme: AppTheme.dark()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final darkHtml = tester
          .widget<HtmlWidget>(
            find.byKey(const Key('forum-html-renderer-theme-p1')),
          )
          .html;
      final darkBody = const CsslibAuthorColorParser().parseOwn(
        html_parser.parseFragment(darkHtml).querySelector('#theme-body')!,
      );
      expect(darkBody.foreground?.toARGB32(), isNot(0xFF000000));
      expect(requestCount, 1);

      await tester.pumpWidget(
        _buildTestApp(repository, theme: AppTheme.light()),
      );
      await tester.pumpAndSettle();

      final lightHtml = tester
          .widget<HtmlWidget>(
            find.byKey(const Key('forum-html-renderer-theme-p1')),
          )
          .html;
      final lightBody = const CsslibAuthorColorParser().parseOwn(
        html_parser.parseFragment(lightHtml).querySelector('#theme-body')!,
      );
      expect(lightBody.foreground?.toARGB32(), 0xFF000000);
      expect(lightHtml, isNot(darkHtml));
      expect(requestCount, 1);
    },
  );

  testWidgets('HTML-first images use project cache requests', (tester) async {
    final imageCacheService = _RecordingImageCacheService();
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
                  '<p>HTML-first 图片</p>'
                  '<img src="data/attachment/forum/page-1.jpg" width="200" height="120">'
                  '<p>表情 <img src="static/image/smiley/comcom/2.gif" alt=""></p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, imageCacheService: imageCacheService),
    );
    await _pumpThreadBodyUntil(tester, () {
      final roles = imageCacheService.requests.map((request) => request.role);
      return roles.contains(ImageCacheRole.threadInline) &&
          roles.contains(ImageCacheRole.remoteSmiley);
    });

    expect(
      imageCacheService.requests.map((request) => request.role),
      containsAll(<ImageCacheRole>[
        ImageCacheRole.threadInline,
        ImageCacheRole.remoteSmiley,
      ]),
    );
    final threadImage = imageCacheService.requests.firstWhere(
      (request) => request.role == ImageCacheRole.threadInline,
    );
    expect(threadImage.ownerType, ImageCacheOwnerType.thread);
    expect(threadImage.ownerId, '100');
    expect(threadImage.sourceUrl, contains('page-1.jpg'));

    final smiley = imageCacheService.requests.firstWhere(
      (request) => request.role == ImageCacheRole.remoteSmiley,
    );
    expect(smiley.ownerType, ImageCacheOwnerType.sticker);
    expect(smiley.effectiveRetentionClass, ImageRetentionClass.sticky);
    expect(smiley.sourceUrl, contains('static/image/smiley/comcom/2.gif'));
  });

  testWidgets('HTML-first image taps open reader by readable sequence index', (
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
              message:
                  '<img src="https://example.com/page-same.jpg">'
                  '<img src="https://example.com/page-same.jpg">'
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
      _buildTestApp(
        repository,
        imageCacheService: _RecordingImageCacheService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final secondImage = find.byKey(
      const Key('thread-post-html-first-readable-image-p1-1'),
    );
    await _tapVisibleTop(tester, secondImage);
    await _pumpThreadUiTransition(tester);

    expect(find.byType(ThreadImageReaderPage), findsOneWidget);
    expect(
      find.byKey(const Key('thread-image-reader-page-view')),
      findsOneWidget,
    );
  });

  testWidgets('image reader return prepares the last read body image', (
    tester,
  ) async {
    final repository = _imageReturnRepository(_imageReturnMessage());
    await _openImageReturnReader(tester, repository);
    final origin = _imageReturnScrollable(tester).position.pixels;
    final viewportHeight = tester
        .getSize(
          find.byKey(const Key('thread-detail-list'), skipOffstage: false),
        )
        .height;

    await _readImageReturnPages(tester, 9);
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('shared-reader-center-tap-zone'))),
    );
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.byKey(const Key('shared-reader-top-back-button')));
    await _pumpImageReturnTransition(tester);

    expect(find.byType(ThreadImageReaderPage), findsNothing);
    expect(
      tester.getTopLeft(_imageReturnBodyImage(9)).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('thread-detail-list'))).dy,
        1,
      ),
    );
    expect(
      _imageReturnScrollable(tester).position.pixels,
      greaterThan(origin + viewportHeight),
    );
  });

  testWidgets(
    'image reader return clears the sticky replies header below the first floor',
    (tester) async {
      final repository = _FakeThreadRepository(
        (tid, page, query) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'sticky-p1',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: '<p>主楼正文</p>',
              ),
              _post(
                pid: 'sticky-p2',
                author: 'bob',
                authorId: '2',
                number: 2,
                message: _imageReturnMessage(),
              ),
            ],
          ),
        ),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'reader_pref_mode': 'ltr',
      });
      tester.view.physicalSize = const Size(450, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          imageCacheService: _FailedThreadInlineImageCacheService(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      await _tapVisibleTop(
        tester,
        find.byKey(
          const Key('thread-post-html-first-readable-image-sticky-p2-0'),
        ),
      );
      await _pumpThreadUiTransition(tester);
      expect(find.byType(ThreadImageReaderPage), findsOneWidget);

      await _readImageReturnPages(tester, 9);
      await tester.tapAt(
        tester.getCenter(
          find.byKey(const Key('shared-reader-center-tap-zone')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pump(const Duration(milliseconds: 260));
      await tester.tap(find.byKey(const Key('shared-reader-top-back-button')));
      await _pumpImageReturnTransition(tester);

      expect(find.byType(ThreadImageReaderPage), findsNothing);
      final listTop = tester
          .getTopLeft(find.byKey(const Key('thread-detail-list')))
          .dy;
      final headerHeight = tester
          .getSize(find.byKey(const Key('thread-detail-sticky-replies-header')))
          .height;
      expect(headerHeight, greaterThan(0));
      final target = find.byKey(
        const Key('thread-post-html-first-readable-image-sticky-p2-9'),
      );
      expect(target, findsOneWidget);
      expect(tester.getTopLeft(target).dy, closeTo(listTop + headerHeight, 1));
    },
  );

  testWidgets('image reader system return distinguishes duplicate URLs', (
    tester,
  ) async {
    final repository = _imageReturnRepository(
      _imageReturnMessage(duplicateFirstPair: true),
    );
    final reader = await _openImageReturnReader(tester, repository);
    expect(
      reader.request.group.entries[0].url,
      reader.request.group.entries[1].url,
    );

    await _readImageReturnPages(tester, 1);
    await tester.binding.handlePopRoute();
    await _pumpImageReturnTransition(tester);

    expect(find.byType(ThreadImageReaderPage), findsNothing);
    final viewportTop = tester
        .getTopLeft(find.byKey(const Key('thread-detail-list')))
        .dy;
    expect(
      tester.getTopLeft(_imageReturnBodyImage(1)).dy,
      closeTo(viewportTop, 1),
    );
    expect(
      tester.getTopLeft(_imageReturnBodyImage(0)).dy,
      lessThan(viewportTop - 100),
    );
  });

  testWidgets('image reader return without navigation preserves the origin', (
    tester,
  ) async {
    final repository = _imageReturnRepository(_imageReturnMessage());
    await _openImageReturnReader(tester, repository, initialIndex: 2);
    final origin = _imageReturnScrollable(tester).position.pixels;
    expect(origin, greaterThan(100));

    await tester.binding.handlePopRoute();
    await _pumpImageReturnTransition(tester);

    expect(find.byType(ThreadImageReaderPage), findsNothing);
    expect(
      _imageReturnScrollable(tester).position.pixels,
      closeTo(origin, 0.1),
    );
  });

  testWidgets('image reader return positions the body before route removal', (
    tester,
  ) async {
    final repository = _imageReturnRepository(_imageReturnMessage());
    final reader = await _openImageReturnReader(tester, repository);
    await _prepareImageReturn(tester, reader, _imageReturnResult(reader, 9));

    // The reader still covers the body: return must be ready before it is
    // removed, rather than exposing the old position for a visible frame.
    expect(find.byType(ThreadImageReaderPage), findsOneWidget);
    expect(
      tester.getTopLeft(_imageReturnBodyImage(9, skipOffstage: false)).dy,
      closeTo(
        tester
            .getTopLeft(
              find.byKey(const Key('thread-detail-list'), skipOffstage: false),
            )
            .dy,
        1,
      ),
    );

    await tester.binding.handlePopRoute();
    await _pumpImageReturnTransition(tester);
    expect(
      tester.getTopLeft(_imageReturnBodyImage(9)).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('thread-detail-list'))).dy,
        1,
      ),
    );
  });

  testWidgets('image reader return rejects malformed and unchanged targets', (
    tester,
  ) async {
    final repository = _imageReturnRepository(_imageReturnMessage());
    final reader = await _openImageReturnReader(
      tester,
      repository,
      initialIndex: 2,
    );
    final origin = _imageReturnScrollable(tester).position.pixels;
    final target = _imageReturnResult(reader, 9);
    final invalidResults = [
      _imageReturnResult(reader, 2),
      ThreadImageReaderExitResult(
        tid: 'other-thread',
        pid: target.pid,
        indexInPost: target.indexInPost,
        cacheKey: target.cacheKey,
        url: target.url,
      ),
      ThreadImageReaderExitResult(
        tid: target.tid,
        pid: 'missing-post',
        indexInPost: target.indexInPost,
        cacheKey: target.cacheKey,
        url: target.url,
      ),
      ThreadImageReaderExitResult(
        tid: target.tid,
        pid: target.pid,
        indexInPost: target.indexInPost,
        cacheKey: 'stale-image-key',
        url: target.url,
      ),
      ThreadImageReaderExitResult(
        tid: target.tid,
        pid: target.pid,
        indexInPost: target.indexInPost,
        cacheKey: target.cacheKey,
        url: 'https://example.com/changed.jpg',
      ),
      ThreadImageReaderExitResult(
        tid: target.tid,
        pid: target.pid,
        indexInPost: 999,
        cacheKey: target.cacheKey,
        url: target.url,
      ),
    ];
    for (final result in invalidResults) {
      await _prepareImageReturn(tester, reader, result);
      expect(
        _imageReturnScrollable(tester).position.pixels,
        closeTo(origin, 0.1),
      );
    }

    await tester.binding.handlePopRoute();
    await _pumpImageReturnTransition(tester);
    expect(
      _imageReturnScrollable(tester).position.pixels,
      closeTo(origin, 0.1),
    );
  });

  testWidgets('image reader return preserves origin for a closed fold target', (
    tester,
  ) async {
    final repository = _imageReturnRepository(
      '<img src="https://example.com/visible.jpg">'
      '<div class="showcollapse_box">'
      '<div class="showcollapse_title">Hidden pages</div>'
      '<div class="showcollapse_content"><img src="https://example.com/hidden.jpg"></div>'
      '</div><p>After the fold</p>',
    );
    final reader = await _openImageReturnReader(tester, repository);
    expect(reader.request.group.entries, hasLength(2));
    expect(_imageReturnBodyImage(1, skipOffstage: false), findsNothing);
    final origin = _imageReturnScrollable(tester).position.pixels;

    await _prepareImageReturn(tester, reader, _imageReturnResult(reader, 1));
    expect(
      _imageReturnScrollable(tester).position.pixels,
      closeTo(origin, 0.1),
    );
    await tester.binding.handlePopRoute();
    await _pumpImageReturnTransition(tester);
    expect(
      _imageReturnScrollable(tester).position.pixels,
      closeTo(origin, 0.1),
    );
    expect(_imageReturnBodyImage(1), findsNothing);
  });

  testWidgets('image reader return rejects a refreshed source snapshot', (
    tester,
  ) async {
    var message = _imageReturnMessage();
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _threadDetailData(tid: tid, posts: [_imageReturnPost(message)]),
      );
    });
    final reader = await _openImageReturnReader(tester, repository);
    final oldResult = _imageReturnResult(reader, 9);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThreadDetailPage, skipOffstage: false)),
    );
    final controller = container.read(
      threadDetailControllerProvider(
        const ThreadDetailArgs(tid: '100', subject: '测试主题'),
      ).notifier,
    );
    message = _imageReturnMessage().replaceAll(
      'page-9.jpg',
      'replacement-9.jpg',
    );
    await controller.refresh();
    await _pumpImageReturnTransition(tester);
    final refreshedOrigin = _imageReturnScrollable(tester).position.pixels;

    await _prepareImageReturn(tester, reader, oldResult);
    expect(
      _imageReturnScrollable(tester).position.pixels,
      closeTo(refreshedOrigin, 0.1),
    );
    await tester.binding.handlePopRoute();
    await _pumpImageReturnTransition(tester);
    expect(find.byType(ThreadImageReaderPage), findsNothing);
    expect(
      _imageReturnScrollable(tester).position.pixels,
      closeTo(refreshedOrigin, 0.1),
    );
  });
}
