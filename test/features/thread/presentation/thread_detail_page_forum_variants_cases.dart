part of 'thread_detail_page_test.dart';

void _forumVariantsCases() {
  testWidgets('renders comic forum posts without eager shelf parsing', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '30',
          typeid: '398',
          subject: '【测试汉化组】第1话',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>漫画正文</p><img src="https://img.test/1.jpg"/><img src="https://img.test/%E3.jpg"/><a href="thread-100-1-1.html">1</a><a href="thread-101-1-1.html">2</a>',
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

    expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
    expect(
      find.byKey(const Key('thread-post-html-first-body-p1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('comic-add-to-shelf-button')), findsNothing);
    expect(find.byKey(const Key('comic-in-shelf-button')), findsNothing);
    expect(find.text('漫画 · 韩国漫画'), findsNothing);
    expect(find.textContaining('漫画候选（评分'), findsNothing);
  });

  testWidgets('hides local shelf entry for fid 49 novel first post', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '49',
          typeid: '293',
          subject: '测试小说帖',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>第1章 开始</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    final novelRepository = _FakeNovelRepository();

    await tester.pumpWidget(
      _buildTestApp(repository, novelRepository: novelRepository),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('小说 · 原创'), findsNothing);
    expect(find.byKey(const Key('comic-add-to-shelf-button')), findsNothing);
    expect(find.byKey(const Key('comic-in-shelf-button')), findsNothing);
  });

  testWidgets(
    'keeps comic second-floor content as normal post detail content',
    (tester) async {
      final repository = _FakeThreadRepository((tid, page) async {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '30',
            typeid: '398',
            subject: '【测试汉化组】第1话',
            author: 'alice',
            replies: 1,
            views: 12,
            currentPage: 1,
            perPage: 20,
            posts: [
              ThreadPost(
                pid: 'p1',
                author: 'alice',
                authorId: '1',
                message: '<p>前言</p><img src="https://img.test/cover.jpg"/>',
                number: 1,
                isFirst: true,
                dateline: 'today',
              ),
              ThreadPost(
                pid: 'p2',
                author: 'alice',
                authorId: '1',
                message: '<img src="https://img.test/page-1.jpg"/><img src="https://img.test/page-2.jpg"/>',
                number: 2,
                isFirst: false,
                dateline: 'today',
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
      expect(
        find.byKey(const Key('thread-post-html-first-body-p1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('comic-add-to-shelf-button')), findsNothing);
    },
  );

  testWidgets('hides search-in-forum action on thread detail page', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '30',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
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
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-detail-search-button')), findsNothing);
    expect(
      find.byKey(const Key('thread-detail-favorite-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('thread-detail-appbar-reply-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('thread-detail-more-menu')), findsOneWidget);
  });

  testWidgets('opens compact display settings from more menu', (tester) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
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
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('thread-detail-display-settings-menu-item')),
      findsOneWidget,
    );

    await tester.tap(find.text('显示设置'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('thread-detail-display-settings-sheet')),
      findsOneWidget,
    );
    // 显示设置统一由自适应面板承载：宽屏为侧面板、窄屏为底部抽屉，
    // 两者都不使用 Material 拖拽手柄，这里不再断言 BottomSheet 形态。
    final sidePanel = find.byKey(const Key('adaptive-side-panel'));
    if (sidePanel.evaluate().isNotEmpty) {
      expect(find.byKey(const Key('adaptive-panel-close')), findsOneWidget);
    } else {
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        isNull,
      );
    }
    expect(
      find.byKey(const Key('forum-html-reader-conversion-mode-control')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-conversion-none')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-conversion-simplified')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-conversion-traditional')),
      findsNothing,
    );
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('间隔'), findsOneWidget);
    expect(
      find.byKey(const Key('forum-html-reader-font-scale-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('forum-html-reader-line-height-slider')),
      findsOneWidget,
    );
    final fontScaleSlider = find.descendant(
      of: find.byKey(const Key('forum-html-reader-font-scale-slider')),
      matching: find.byType(Slider),
    );
    final lineHeightSlider = find.descendant(
      of: find.byKey(const Key('forum-html-reader-line-height-slider')),
      matching: find.byType(Slider),
    );
    expect(fontScaleSlider, findsOneWidget);
    expect(lineHeightSlider, findsOneWidget);
    expect(tester.getSize(fontScaleSlider).height, greaterThanOrEqualTo(48));
    expect(
      tester.getCenter(lineHeightSlider).dy -
          tester.getCenter(fontScaleSlider).dy,
      greaterThanOrEqualTo(72),
    );
    expect(
      find.byKey(const Key('forum-html-reader-paragraph-spacing-slider')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-preserve-font-size-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-preserve-color-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-preserve-background-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forum-html-reader-reset-button')),
      findsNothing,
    );
    // 关闭面板后仍停留在帖子详情，关闭动作不吞掉详情路由。
    if (sidePanel.evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('adaptive-panel-close')));
    } else {
      await tester.binding.handlePopRoute();
    }
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('thread-detail-display-settings-sheet')),
      findsNothing,
    );
    expect(find.byKey(const Key('thread-detail-more-menu')), findsOneWidget);
  });

  testWidgets('legacy conversion preference does not affect production body', (
    tester,
  ) async {
    final preferencesRepository = _FakeForumHtmlReaderPreferencesRepository(
      ForumHtmlReaderPreferences.defaults().copyWith(
        conversionMode: TextConversionMode.toSimplified,
      ),
    );
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '測試主题',
          author: 'alice樣',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice樣',
              authorId: '1',
              message: '<p>正文樣本</p>',
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
        forumHtmlReaderPreferencesRepository: preferencesRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(_richTextContaining('正文樣本'), findsOneWidget);
    expect(find.textContaining('alice樣'), findsOneWidget);
    expect(
      preferencesRepository.current.conversionMode,
      TextConversionMode.toSimplified,
    );

    await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示设置'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('forum-html-reader-conversion-mode-control')),
      findsNothing,
    );
    expect(_richTextContaining('正文樣本'), findsOneWidget);
    expect(_richTextContaining('正文样本'), findsNothing);
    expect(find.textContaining('alice樣'), findsOneWidget);
    expect(find.textContaining('alice样'), findsNothing);
  });

  testWidgets(
    'manual language mode projects server content without another request',
    (tester) async {
      final historyRecorder = _RecordingHistoryVisitRecorder();
      final converter = _ThreadProjectionTestConverter(
        TextConversionMode.toTraditional,
      );
      final repository = _FakeThreadRepository((tid, page) async {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '33',
            forumName: '软件区',
            subject: '软件主题',
            author: '发型用户名',
            replies: 0,
            views: 1,
            currentPage: 1,
            perPage: 20,
            posts: [
              ThreadPost(
                pid: 'p1',
                author: '发型用户名',
                authorId: '1',
                message:
                    '<p>软件内容</p>'
                    '<a href="/home.php?mod=space&amp;uid=1">发型用户名</a>',
                number: 1,
                isFirst: true,
                dateline: '软件时间',
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(
          repository,
          historyVisitRecorder: historyRecorder,
          additionalOverrides: <riverpod_misc.Override>[
            appServerContentConversionModeProvider.overrideWithValue(
              TextConversionMode.toTraditional,
            ),
            textConverterProvider.overrideWith((ref, mode) => converter),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(_appBarTitleText('軟體區'), findsOneWidget);
      expect(find.text('軟體主題'), findsOneWidget);
      expect(_richTextContaining('軟體內容'), findsOneWidget);
      expect(find.textContaining('发型用户名'), findsWidgets);
      expect(find.textContaining('髮型用戶名'), findsNothing);
      expect(repository.queryHistory, hasLength(1));
      expect(converter.callCount, 2);
      expect(historyRecorder.drafts, hasLength(1));
      expect(historyRecorder.drafts.single.title, '软件主题');
      expect(historyRecorder.drafts.single.forumName, '软件区');

      await tester.pump();
      expect(converter.callCount, 2);
    },
  );
}
