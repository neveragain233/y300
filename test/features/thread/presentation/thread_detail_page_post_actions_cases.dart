part of 'thread_detail_page_test.dart';

void _postActionsCases() {
  testWidgets('renders long text post as one HTML-first body', (tester) async {
    tester.view.physicalSize = const Size(390, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final longParagraph = List.filled(520, '长正文片段').join();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: '长正文帖子',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'long-1',
              author: 'author',
              authorId: '1',
              message: '<p>$longParagraph</p>',
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

    expect(find.byKey(const Key('thread-post-card-long-1')), findsOneWidget);
    expect(find.byKey(const Key('thread-post-body-long-1')), findsOneWidget);
    expect(find.byKey(const Key('thread-post-body-long-1-0')), findsNothing);
    expect(find.byType(ThreadPostHtmlBody), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('thread-detail-list')),
        matching: find.byType(SelectionArea),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(Scrollable).first,
        matching: find.byType(SelectionArea),
      ),
      findsNothing,
    );
    final bodyRichTexts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byKey(const Key('thread-post-body-long-1')),
        matching: find.byType(RichText),
      ),
    );
    expect(bodyRichTexts, isNotEmpty);
    expect(
      bodyRichTexts.every((text) => text.selectionRegistrar == null),
      isTrue,
    );
  });

  testWidgets('uses one HTML-first body entry for image dense posts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final imageHtml = List.generate(
      7,
      (index) =>
          '<img src="static/image/common/none.gif" file="data/attachment/forum/page-$index.jpg" />',
    ).join();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: '多图帖子',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'image-1',
              author: 'author',
              authorId: '1',
              message: '<p>开头</p>$imageHtml<p>结尾</p>',
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

    expect(find.byKey(const Key('thread-post-card-image-1')), findsOneWidget);
    expect(find.byKey(const Key('thread-post-body-image-1')), findsOneWidget);
    expect(find.byKey(const Key('thread-post-body-image-1-0')), findsNothing);
    expect(find.byKey(const Key('thread-post-body-image-1-6')), findsNothing);
    expect(
      find.byKey(const Key('thread-post-html-first-readable-image-image-1-0')),
      findsOneWidget,
    );
  });

  for (final canVote in [true, false]) {
    testWidgets(
      'poll option long press copies converted text, canVote=$canVote',
      (tester) async {
        final writes = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes.add((call.arguments as Map)['text'] as String);
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
              fid: '33',
              subject: 'Poll copy',
              author: 'alice',
              replies: 0,
              views: 1,
              currentPage: page,
              perPage: 20,
              posts: [
                ThreadPost(
                  pid: 'poll-copy',
                  author: 'alice',
                  authorId: '1',
                  message: '<p>软件内容</p>',
                  number: 1,
                  isFirst: true,
                  dateline: 'today',
                  poll: ThreadPoll(
                    isMultipleChoice: false,
                    canVote: canVote,
                    summary: '',
                    options: const [
                      ThreadPollOption(
                        id: '1',
                        label: '软件区内容\n完整文字',
                        voteCount: 8,
                        percent: 25,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        final command = _FakeThreadPollVoteCommand();
        await tester.pumpWidget(
          _buildTestApp(
            repository,
            pollVoteCommand: command,
            additionalOverrides: [
              appServerContentConversionModeProvider.overrideWithValue(
                TextConversionMode.toTraditional,
              ),
              textConverterProvider.overrideWith(
                (ref, mode) => _ThreadProjectionTestConverter(mode),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final option = find.byKey(const Key('thread-poll-option-1'));
        await tester.ensureVisible(option);
        await tester.longPress(option);
        await tester.pumpAndSettle();
        final sheet = find.byKey(const Key('thread-post-action-sheet'));
        expect(sheet, findsOneWidget);
        final strings = AppLocalizations.of(tester.element(sheet));
        expect(find.text(strings.threadPollCopyOptionText), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('thread-post-copy-poll-option-action')),
        );
        await tester.pumpAndSettle();
        expect(writes, ['軟體區內容\n完整文字']);
        expect(command.called, isFalse);
        await _longPressVisibleTop(
          tester,
          find.byKey(const Key('thread-post-header-poll-copy')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('thread-post-copy-poll-option-action')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('thread-post-copy-all-action')));
        await tester.pumpAndSettle();
        expect(writes, ['軟體區內容\n完整文字', '軟體內容']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('long pressing post body opens copy actions and copy page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    final longParagraph = List.filled(360, '长正文片段').join();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '55',
          subject: '复制测试',
          author: 'alice',
          replies: 1,
          views: 12,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'copy-1',
              author: 'author',
              authorId: '1',
              message:
                  '<p>第一段 <a href="thread-1-1-1.html">链接文本</a> $longParagraph</p>'
                  '<div class="quote"><blockquote><b>作者</b>: 引用正文</blockquote></div>'
                  '<img file="data/attachment/forum/page.jpg" />'
                  '<p>尾段 <img src="static/image/smiley/comcom/2.gif" alt="[笑]"></p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
            ThreadPost(
              pid: 'copy-2',
              author: 'other',
              authorId: '2',
              message: '<p>其它楼正文</p>',
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

    expect(find.byKey(const Key('thread-post-body-copy-1')), findsOneWidget);
    expect(find.byKey(const Key('thread-post-body-copy-1-0')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('thread-post-body-copy-1')),
        matching: find.byType(SelectionArea),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('thread-detail-list')),
        matching: find.byType(SelectionArea),
      ),
      findsNothing,
    );
    final headerRichTexts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byKey(const Key('thread-post-card-copy-1')),
        matching: find.byType(RichText),
      ),
    );
    expect(headerRichTexts, isNotEmpty);
    expect(
      headerRichTexts.every((text) => text.selectionRegistrar == null),
      isTrue,
    );
    expect(find.byKey(const Key('thread-post-card-copy-1')), findsOneWidget);

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-copy-1')),
    );
    await _pumpThreadUiTransition(tester);

    expect(find.byKey(const Key('thread-post-action-sheet')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('thread-post-action-sheet')),
        matching: find.text(
          AppLocalizations.of(tester.element(find.byType(ThreadDetailPage)))
              .threadDetailReply,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('选择复制'), findsOneWidget);
    expect(find.text('全部复制'), findsOneWidget);

    await _tapPostActionSheetItem(
      tester,
      const Key('thread-post-copy-all-action'),
    );
    await _pumpThreadUiTransition(tester);

    expect(copiedTexts.single, contains('第一段 链接文本'));
    expect(copiedTexts.single, contains(longParagraph));
    expect(copiedTexts.single, contains('作者: 引用正文'));
    expect(copiedTexts.single, contains('尾段 [笑]'));
    expect(copiedTexts.single, isNot(contains('page.jpg')));
    expect(find.text('1# 正文已复制'), findsOneWidget);

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-copy-1')),
    );
    await _pumpThreadUiTransition(tester);
    await _tapPostActionSheetItem(
      tester,
      const Key('thread-post-select-copy-action'),
    );
    await _pumpThreadUiTransition(tester);

    expect(
      find.byKey(const Key('thread-post-html-selection-copy-page')),
      findsOneWidget,
    );
    expect(find.text('选择复制'), findsOneWidget);
    expect(
      find.byKey(const Key('thread-post-html-selection-copy-body-copy-1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('thread-post-html-selection-copy-body-copy-1'),
        ),
        matching: find.byType(SelectionArea),
      ),
      findsNothing,
    );
    final copyPageRichTexts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byKey(
          const Key('thread-post-html-selection-copy-body-copy-1'),
        ),
        matching: find.byType(RichText),
      ),
    );
    expect(
      copyPageRichTexts.any((text) => text.selectionRegistrar != null),
      isTrue,
    );
  });

  testWidgets('opens a valid floor edit link in the existing WebView', (
    tester,
  ) async {
    final webViewDriver = _FakeForumWebViewDriver();
    const editUri =
        'https://bbs.yamibo.com/forum.php?mod=post&action=edit&fid=33&tid=100&pid=101&page=1&mobile=2';
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '编辑测试',
          author: 'alice',
          replies: 1,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: '101',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              editUrl: editUri,
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, forumWebViewDriverFactory: () => webViewDriver),
    );
    await tester.pumpAndSettle();

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-101')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-post-edit-action')), findsOneWidget);
    await _tapPostActionSheetItem(tester, const Key('thread-post-edit-action'));
    await tester.pumpAndSettle();

    expect(find.byType(ForumWebViewPage), findsOneWidget);
    expect(webViewDriver.bootstrapConfig?.initialUri, Uri.parse(editUri));
    expect(webViewDriver.loadedUris, contains(Uri.parse(editUri)));
    expect(
      webViewDriver.bootstrapConfig?.visualPolicy.earlyHiddenSelectors,
      containsAll(<String>['#header-padding', '.header.cl']),
    );
    expect(
      webViewDriver.bootstrapConfig?.visualPolicy.lateRemovedSelectors,
      containsAll(<String>['.footer.mt10.cl', '.foot.flex-box']),
    );
  });

  testWidgets('hides the floor edit action for missing or invalid links', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '编辑测试',
          author: 'alice',
          replies: 2,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: '101',
              author: 'alice',
              authorId: '1',
              message: '<p>错误目标</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              editUrl: 'https://bbs.yamibo.com/forum.php?mod=post&action=edit&fid=33&tid=100&pid=999',
            ),
            ThreadPost(
              pid: '102',
              author: 'bob',
              authorId: '2',
              message: '<p>没有编辑链接</p>',
              number: 2,
              isFirst: false,
              dateline: 'today',
            ),
            ThreadPost(
              pid: '103',
              author: 'carol',
              authorId: '3',
              message: '<p>错误帖子</p>',
              number: 3,
              isFirst: false,
              dateline: 'today',
              editUrl: 'https://bbs.yamibo.com/forum.php?mod=post&action=edit&fid=33&tid=999&pid=103',
            ),
            ThreadPost(
              pid: '104',
              author: 'dave',
              authorId: '4',
              message: '<p>外站链接</p>',
              number: 4,
              isFirst: false,
              dateline: 'today',
              editUrl: 'https://example.com/forum.php?mod=post&action=edit&fid=33&tid=100&pid=104',
            ),
            ThreadPost(
              pid: '105',
              author: 'erin',
              authorId: '5',
              message: '<p>错误动作</p>',
              number: 5,
              isFirst: false,
              dateline: 'today',
              editUrl: 'https://bbs.yamibo.com/forum.php?mod=post&action=reply&fid=33&tid=100&pid=105',
            ),
            ThreadPost(
              pid: '106',
              author: 'frank',
              authorId: '6',
              message: '<p>非法 fid</p>',
              number: 6,
              isFirst: false,
              dateline: 'today',
              editUrl: 'https://bbs.yamibo.com/forum.php?mod=post&action=edit&fid=abc&tid=100&pid=106',
            ),
            ThreadPost(
              pid: '107',
              author: 'grace',
              authorId: '7',
              message: '<p>非 HTTPS</p>',
              number: 7,
              isFirst: false,
              dateline: 'today',
              editUrl: 'http://bbs.yamibo.com/forum.php?mod=post&action=edit&fid=33&tid=100&pid=107',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    for (final pid in <String>[
      '101',
      '102',
      '103',
      '104',
      '105',
      '106',
      '107',
    ]) {
      await _longPressVisibleTop(
        tester,
        find.byKey(Key('thread-post-body-$pid')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-post-edit-action')),
        findsNothing,
        reason: 'Invalid edit target must stay hidden for pid=$pid.',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('copies a source floor redirect with the current uid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
          fid: '55',
          subject: '楼层链接测试',
          author: 'alice',
          replies: 1,
          views: 12,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: '41585107',
              author: 'author',
              authorId: '11',
              message: '<p>正文</p>',
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
        additionalOverrides: [
          authSessionControllerProvider.overrideWith(
            () => _FakeAuthSessionController(
              const AuthSessionViewState(
                isLoggedIn: true,
                uid: '597454',
                username: 'alice',
                isLoggingOut: false,
              ),
            ),
          ),
        ],
        home: Consumer(
          builder: (context, ref, child) {
            ref.watch(authSessionControllerProvider);
            return const ThreadDetailPage(tid: '100', subject: '楼层链接测试');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-41585107')),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.threadDetailCopyFloorLink), findsOneWidget);
    await _tapPostActionSheetItem(
      tester,
      const Key('thread-post-copy-floor-link-action'),
    );
    await tester.pumpAndSettle();

    expect(copiedTexts, <String>[
      'https://bbs.yamibo.com/forum.php?mod=redirect&goto=findpost&ptid=100&pid=41585107&fromuid=597454',
    ]);
    expect(
      find.text(l10n.threadDetailCopySuccess(l10n.threadDetailFloorLink)),
      findsOneWidget,
    );
  });

  testWidgets('uses current thread page as post image referer', (tester) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '30',
          subject: '带图主题',
          author: 'alice',
          replies: 0,
          views: 12,
          currentPage: page,
          perPage: 20,
          desktopUrl:
              'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=$tid&page=$page',
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<img src="static/image/common/none.gif" file="data/attachment/forum/page-1.jpg" />',
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
    await tester.pump();

    final image = tester.widget<CachedLibraryImage>(
      find.descendant(
        of: find.byKey(const Key('thread-post-html-first-readable-image-p1-0')),
        matching: find.byType(CachedLibraryImage),
      ),
    );
    final request = image.request;
    expect(request, isNotNull);
    expect(
      request!.sourceUrl,
      'https://bbs.yamibo.com/data/attachment/forum/page-1.jpg',
    );
    expect(
      image.referer,
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100&page=1',
    );
  });

  testWidgets('opens native rate sheet and submits post rating', (
    tester,
  ) async {
    var loadCount = 0;
    final repository = _FakeThreadRepository((tid, page) async {
      loadCount++;
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
              rateUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=rate&tid=100&pid=p1',
            ),
          ],
        ),
      );
    });
    final rateRepository = _FakeThreadPostRatingInteraction();
    final invalidationService = _FakeNativePageCacheInvalidationService();

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        postRateInteraction: rateRepository,
        pageCacheInvalidationService: invalidationService,
      ),
    );
    await tester.pumpAndSettle();

    await _openPostAction(
      tester,
      bodyKey: const Key('thread-post-body-p1'),
      actionKey: const Key('thread-post-rate-action'),
    );
    await tester.pumpAndSettle();

    expect(rateRepository.loadedRequest?.tid, '100');
    expect(rateRepository.loadedRequest?.pid, 'p1');
    expect(find.byKey(const Key('thread-post-rate-sheet')), findsOneWidget);
    expect(find.text('范围 0~5，今日剩余 10'), findsOneWidget);

    await tester.tap(find.byKey(const Key('thread-post-rate-reason-我很赞同')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('thread-post-rate-submit-button')));
    await tester.pumpAndSettle();

    expect(rateRepository.loadedRequest?.referer?.fragment, 'pidp1');
    expect(rateRepository.lastSubmission?.scores, <String, int>{'score1': 5});
    expect(rateRepository.lastSubmission?.reason, '我很赞同');
    expect(rateRepository.lastSubmission?.notifyAuthor, isFalse);
    expect(invalidationService.invalidatedThreadIds, <String>['100']);
    expect(loadCount, 2);
    expect(find.text('评分成功'), findsOneWidget);
  });

  testWidgets('opens native comment sheet and submits post comment', (
    tester,
  ) async {
    var loadCount = 0;
    final repository = _FakeThreadRepository((tid, page) async {
      loadCount++;
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
              commentUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=comment&tid=100&pid=p1',
            ),
          ],
        ),
      );
    });
    final commentRepository = _FakeThreadPostCommentInteraction();
    final invalidationService = _FakeNativePageCacheInvalidationService();

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        postCommentInteraction: commentRepository,
        pageCacheInvalidationService: invalidationService,
      ),
    );
    await tester.pumpAndSettle();

    await _openPostAction(
      tester,
      bodyKey: const Key('thread-post-body-p1'),
      actionKey: const Key('thread-post-comment-action'),
    );
    await tester.pumpAndSettle();

    expect(commentRepository.loadedRequest?.tid, '100');
    expect(commentRepository.loadedRequest?.pid, 'p1');
    expect(find.byKey(const Key('thread-post-comment-sheet')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('thread-post-comment-message-input')),
      '这是测试点评',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('thread-post-comment-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(commentRepository.lastSubmission?.preparation.pid, 'p1');
    expect(commentRepository.lastSubmission?.message, '这是测试点评');
    expect(invalidationService.invalidatedThreadIds, <String>['100']);
    expect(loadCount, 2);
    expect(find.text('点评成功'), findsOneWidget);
  });

  testWidgets('hides comment action when post has no comment url', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 1,
          views: 1,
          currentPage: 2,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p2',
              author: 'bob',
              authorId: '2',
              message: '<p>第二楼</p>',
              number: 2,
              isFirst: false,
              dateline: 'today',
            ),
          ],
        ),
      );
    });
    final commentRepository = _FakeThreadPostCommentInteraction();

    await tester.pumpWidget(
      _buildTestApp(repository, postCommentInteraction: commentRepository),
    );
    await tester.pumpAndSettle();

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-p2')),
    );
    await tester.pumpAndSettle();

    final actionSheet = find.byKey(const Key('thread-post-action-sheet'));
    expect(actionSheet, findsOneWidget);
    expect(
      find.descendant(of: actionSheet, matching: find.text('点评')),
      findsNothing,
    );
    expect(
      find.descendant(of: actionSheet, matching: find.text('回复')),
      findsOneWidget,
    );
    expect(commentRepository.loadedRequest, isNull);
  });

  testWidgets('post actions do not expose HTML-first comparison', (
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
              message: '<p>对照正文</p>',
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

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-p1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('thread-post-html-first-compare-action')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('thread-post-select-copy-action')),
      findsOneWidget,
    );
  });
}
