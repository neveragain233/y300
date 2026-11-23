part of 'thread_detail_page_test.dart';

void _pageKeysCases() {
  testWidgets(
    'eInk corner paging clears both floor buttons on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeThreadRepository(
        (tid, page, query) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'floor',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: List.filled(24, '<p>长帖分页正文</p>').join(),
              ),
            ],
          ),
        ),
      );
      const root = Key('eink-thread-page');
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          home: const EInkModeScope(
            enabled: true,
            child: ThreadDetailPage(key: root, tid: '100', subject: '测试主题'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      Finder within(String id) =>
          find.descendant(of: find.byKey(root), matching: find.byKey(Key(id)));
      final bottom = tester.getBottomRight(within('eink-corner-page-down')).dy;
      expect(
        bottom + 8,
        lessThanOrEqualTo(
          tester.getTopLeft(within('thread-next-post-button')).dy,
        ),
      );
      expect(
        bottom + 8,
        lessThanOrEqualTo(
          tester.getTopLeft(within('thread-detail-appbar-reply-button')).dy,
        ),
      );
    },
  );

  testWidgets('the last page down key returns to the first page topic body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <int>[];
    final repository = _FakeThreadRepository((tid, page, query) async {
      requests.add(page);
      return ApiSuccess(
        page == 2
            ? _threadDetailData(
                tid: tid,
                currentPage: 2,
                lastPage: 2,
                posts: [
                  _post(
                    pid: 'body-return-p21',
                    author: 'bob',
                    authorId: '2',
                    number: 21,
                    message: List.generate(
                      40,
                      (line) => '<p>末页回复段落 $line</p>',
                    ).join(),
                  ),
                ],
              )
            : _threadDetailData(
                tid: tid,
                currentPage: 1,
                lastPage: 2,
                posts: [
                  _post(
                    pid: 'body-return-p1',
                    author: 'alice',
                    authorId: '1',
                    number: 1,
                    isFirst: true,
                    message: List.generate(
                      20,
                      (line) => '<p>首楼正文段落 $line</p>',
                    ).join(),
                  ),
                  _post(
                    pid: 'body-return-p2',
                    author: 'bob',
                    authorId: '2',
                    number: 2,
                    message: '<p>普通回复</p>',
                  ),
                ],
              ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: const ThreadDetailPage(
          tid: '100',
          subject: '测试主题',
          initialPage: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('thread-detail-list'));
    await tester.drag(list, const Offset(0, -4000));
    await tester.pumpAndSettle();
    final next = find.byKey(const Key('thread-next-post-button'));
    expect(
      find.descendant(
        of: next,
        matching: find.byIcon(Icons.vertical_align_top),
      ),
      findsOneWidget,
    );

    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(requests, <int>[2, 1]);
    final firstPost = find.byKey(const Key('thread-post-card-body-return-p1'));
    expect(firstPost, findsOneWidget);
    expect(
      tester.getTopLeft(firstPost).dy,
      closeTo(tester.getTopLeft(list).dy, 20),
    );
  });

  testWidgets('one tap at the real page bottom loads the next page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <int>[];
    final repository = _FakeThreadRepository((tid, page, query) async {
      requests.add(page);
      return ApiSuccess(
        page == 2
            ? _threadDetailData(
                tid: tid,
                currentPage: 2,
                lastPage: 2,
                posts: [
                  _post(
                    pid: 'bottom-p21',
                    author: 'bob',
                    authorId: '2',
                    number: 21,
                    message: '<p>第二页回复</p>',
                  ),
                ],
              )
            : _threadDetailData(
                tid: tid,
                currentPage: 1,
                lastPage: 2,
                posts: [
                  _post(
                    pid: 'bottom-p1',
                    author: 'alice',
                    authorId: '1',
                    number: 1,
                    isFirst: true,
                    message: List.generate(
                      30,
                      (line) => '<p>首楼正文段落 $line</p>',
                    ).join(),
                  ),
                  for (var index = 2; index <= 4; index++)
                    _post(
                      pid: 'bottom-p$index',
                      author: 'bob',
                      authorId: '2',
                      number: index,
                      message: '<p>短回复 $index</p>',
                    ),
                ],
              ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();
    final list = find.byKey(const Key('thread-detail-list'));
    await tester.drag(list, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thread-post-card-bottom-p3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('thread-next-post-button')));
    await tester.pumpAndSettle();

    expect(requests, <int>[1, 2]);
  });

  testWidgets('first post topic tags render in the native tag bar', (
    tester,
  ) async {
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            ThreadPost(
              pid: 'tag-p1',
              author: 'fixture-user',
              authorId: '1',
              message: '<p>fixture-body</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              tagLinks: const [
                ThreadPostTagLink(
                  label: '漫画',
                  url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=86',
                  tagId: '86',
                ),
                ThreadPostTagLink(
                  label: '讨论',
                  url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=87',
                  tagId: '87',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-topic-tag-bar')), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '漫画'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '讨论'), findsOneWidget);
  });

  testWidgets('direct blocked entry prompts before touching the thread body', (
    tester,
  ) async {
    _seedBlockedThread(tid: '100', subject: '被屏蔽的主题');
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            _post(
              pid: 'blocked-gate-p1',
              author: 'fixture-user',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>fixture-body</p>',
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
          subject: '被屏蔽的主题',
          gateBlockedEntry: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-gate')),
      findsOneWidget,
    );
    expect(repository.queryHistory, isEmpty);

    await tester.tap(find.byKey(const Key('content-filter-view-once-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-gate')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('thread-post-card-blocked-gate-p1')),
      findsOneWidget,
    );
    expect(repository.queryHistory, isNotEmpty);
  });

  testWidgets('unblocking from the prompt opens the thread', (tester) async {
    _seedBlockedThread(tid: '100', subject: '被屏蔽的主题');
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            _post(
              pid: 'unblocked-gate-p1',
              author: 'fixture-user',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>fixture-body</p>',
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
          subject: '被屏蔽的主题',
          gateBlockedEntry: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('content-filter-unblock-and-view-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-gate')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('thread-post-card-unblocked-gate-p1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'floor menu opens only that floor author and bars empty identities',
    (tester) async {
      final repository = _FakeThreadRepository((tid, page, query) async {
        final authorId = query['authorid'];
        final posts = authorId == '2'
            ? [
                _post(
                  pid: 'author-menu-p2',
                  author: 'bob',
                  authorId: '2',
                  number: 2,
                  message: '<p>bob 的回复</p>',
                ),
              ]
            : [
                _post(
                  pid: 'author-menu-p1',
                  author: 'alice',
                  authorId: '1',
                  number: 1,
                  isFirst: true,
                  message: '<p>主楼正文</p>',
                ),
                _post(
                  pid: 'author-menu-p2',
                  author: 'bob',
                  authorId: '2',
                  number: 2,
                  message: '<p>bob 的回复</p>',
                ),
                ThreadPost(
                  pid: 'author-menu-p3',
                  author: 'carol',
                  authorId: '',
                  message: '<p>身份缺失的回复</p>',
                  number: 3,
                  isFirst: false,
                  dateline: 'today',
                ),
              ];
        return ApiSuccess(_threadDetailData(tid: tid, posts: posts));
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      // 作者编号缺失的楼层不显示该操作。
      await _longPressVisibleTop(
        tester,
        find.byKey(const Key('thread-post-body-author-menu-p3')),
      );
      await _pumpThreadUiTransition(tester);
      final sheet = find.byKey(const Key('thread-post-action-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.byKey(const Key('thread-post-only-author-action')),
        findsNothing,
      );
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();

      await _longPressVisibleTop(
        tester,
        find.byKey(const Key('thread-post-body-author-menu-p2')),
      );
      await _pumpThreadUiTransition(tester);
      await _tapPostActionSheetItem(
        tester,
        const Key('thread-post-only-author-action'),
      );
      await _pumpThreadUiTransition(tester);

      expect(repository.queryHistory.last['authorid'], '2');
      expect(repository.queryHistory.last.containsKey('page'), isFalse);
    },
  );

  testWidgets('blocks the selected floor author from the long-press menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'content_filter.web_blacklist.snapshot.v1': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'accounts': <String, Object?>{
          '11': <String, Object?>{
            'lastSuccessAt': 1000,
            'members': <Object?>[],
          },
        },
      }),
    });
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final submissions = <ForumBlacklistAddSubmission>[];
    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            _post(
              pid: 'block-floor-p1',
              author: 'alice',
              authorId: '42',
              number: 1,
              isFirst: true,
              message: '<p>主楼正文</p>',
            ),
            _post(
              pid: 'block-floor-p2',
              author: 'bob',
              authorId: '44',
              number: 2,
              message: '<p>bob 的回复</p>',
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        additionalOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '11',
            revision: 0,
          )),
          blacklistAddSupportedProvider.overrideWithValue(true),
          blacklistAddCommandProvider.overrideWithValue((submission) async {
            submissions.add(submission);
            return DataCommandApplied(
              ForumBlacklistAddReceipt(
                userId: submission.userId,
                username: submission.username,
              ),
            );
          }),
          blacklistRemoteLoaderProvider.overrideWithValue(
            (_) async => DataReadSuccess(
              data: const ForumBlacklistData(
                entries: <ForumBlacklistEntry>[
                  ForumBlacklistEntry(userId: '44', username: 'bob'),
                ],
                pagesRead: 1,
              ),
              capabilities: ForumBlacklistReadCapabilities(
                values: DataCapabilitySet.supported(
                  ForumBlacklistCapability.values,
                ),
              ),
              metadata: const DataReadMetadata.network(),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _longPressVisibleTop(
      tester,
      find.byKey(const Key('thread-post-body-block-floor-p2')),
    );
    await _pumpThreadUiTransition(tester);
    expect(
      find.byKey(const Key('thread-post-block-user-action')),
      findsOneWidget,
    );
    await _tapPostActionSheetItem(
      tester,
      const Key('thread-post-block-user-action'),
    );
    await tester.pumpAndSettle();

    expect(submissions.single.userId, '44');
    expect(submissions.single.username, 'bob');
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    expect(find.text(l10n.blacklistBlockApplied('bob')), findsOneWidget);
    expect(
      find.byKey(const Key('thread-blacklisted-post-block-floor-p2')),
      findsOneWidget,
    );
  });

  testWidgets('blocks the topic author from the detail more menu', (
    tester,
  ) async {
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final submissions = <ForumBlacklistAddSubmission>[];
    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            _post(
              pid: 'block-author-p1',
              author: 'alice',
              authorId: '42',
              number: 1,
              isFirst: true,
              message: '<p>主楼正文</p>',
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        additionalOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '11',
            revision: 0,
          )),
          blacklistAddSupportedProvider.overrideWithValue(true),
          blacklistAddCommandProvider.overrideWithValue((submission) async {
            submissions.add(submission);
            return DataCommandApplied(
              ForumBlacklistAddReceipt(
                userId: submission.userId,
                username: submission.username,
              ),
            );
          }),
          blacklistRemoteLoaderProvider.overrideWithValue(
            (_) async => DataReadSuccess(
              data: const ForumBlacklistData(
                entries: <ForumBlacklistEntry>[
                  ForumBlacklistEntry(userId: '42', username: 'alice'),
                ],
                pagesRead: 1,
              ),
              capabilities: ForumBlacklistReadCapabilities(
                values: DataCapabilitySet.supported(
                  ForumBlacklistCapability.values,
                ),
              ),
              metadata: const DataReadMetadata.network(),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    expect(find.text(l10n.blacklistBlockAuthor), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('thread-detail-block-author-menu-item')),
    );
    await tester.pumpAndSettle();

    expect(submissions.single.userId, '42');
    expect(submissions.single.username, 'alice');
    expect(find.text(l10n.blacklistBlockApplied('alice')), findsOneWidget);
  });

  testWidgets('app bar action returns to the first post and resets direction', (
    tester,
  ) async {
    final repository = _FakeThreadRepository(
      (tid, page, query) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            for (var index = 1; index <= 3; index++)
              _post(
                pid: 'first-action-p$index',
                author: 'alice',
                authorId: '1',
                number: index,
                isFirst: index == 1,
                message: List.generate(
                  8,
                  (line) => '<p>第$index楼段落 $line</p>',
                ).join(),
              ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final firstPost = find.byKey(const Key('thread-post-card-first-action-p1'));
    final next = find.byKey(const Key('thread-next-post-button'));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    final backToFirst = find.byKey(
      const Key('thread-detail-first-post-button'),
    );
    expect(backToFirst, findsOneWidget);
    expect(
      tester.getSemantics(backToFirst).tooltip,
      l10n.threadControlsFirstPost,
    );

    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('thread-post-card-first-action-p3')),
      findsOneWidget,
    );
    expect(firstPost, findsNothing);

    await tester.tap(backToFirst);
    await tester.pumpAndSettle();
    final listTop = tester.getTopLeft(
      find.byKey(const Key('thread-detail-list')),
    );
    expect(tester.getTopLeft(firstPost).dy, closeTo(listTop.dy, 20));

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(find.byKey(const Key('thread-post-card-first-action-p2')))
          .dy,
      lessThan(
        tester.getSize(find.byKey(const Key('thread-detail-list'))).height,
      ),
    );
  });

  testWidgets(
    'replies header pins below the viewport top and returns to its place',
    (tester) async {
      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeThreadRepository(
        (tid, page) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'sticky-p1',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: List.generate(
                  60,
                  (index) => '<p>首楼段落 $index</p>',
                ).join(),
              ),
              for (var index = 2; index <= 3; index++)
                _post(
                  pid: 'sticky-p$index',
                  author: 'bob',
                  authorId: '2',
                  number: index,
                  message: List.generate(
                    30,
                    (line) => '<p>回复 $index 段落 $line</p>',
                  ).join(),
                ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('thread-detail-list'));
      final inline = find.byKey(const Key('thread-detail-replies-header'));
      final sticky = find.byKey(
        const Key('thread-detail-sticky-replies-header'),
      );
      expect(sticky, findsNothing);
      // 首楼很长时回复栏尚未进入惰性列表可见区，先滚动到自然位置。
      await tester.dragUntilVisible(inline, list, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(inline, findsOneWidget);

      final listTop = tester.getTopLeft(list).dy;
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final headerOffset =
          scrollable.position.pixels + (tester.getTopLeft(inline).dy - listTop);
      scrollable.position.jumpTo(headerOffset + 80);
      await tester.pumpAndSettle();

      expect(sticky, findsOneWidget);
      expect(tester.getTopLeft(sticky).dy, closeTo(listTop, .5));
      expect(
        find.descendant(
          of: sticky,
          matching: find.byKey(const Key('thread-replies-author-filter')),
        ),
        findsNothing,
        reason: '吸顶层只显示同一份操作，不复制列表里的交互键',
      );

      // 回到首楼区域时恢复自然位置并退出吸顶。
      scrollable.position.jumpTo(headerOffset - 120);
      await tester.pumpAndSettle();
      expect(sticky, findsNothing);
      expect(inline, findsOneWidget);
      expect(tester.getTopLeft(inline).dy, closeTo(listTop + 120, 1));
    },
  );

  testWidgets(
    'sticky replies header uses measured height at large text and wide width',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeThreadRepository(
        (tid, page) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _post(
                pid: 'wide-p1',
                author: 'alice',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: List.generate(
                  10,
                  (line) => '<p>首楼段落 $line</p>',
                ).join(),
              ),
              _post(
                pid: 'wide-p2',
                author: 'bob',
                authorId: '2',
                number: 2,
                message: List.generate(
                  40,
                  (line) => '<p>回复段落 $line</p>',
                ).join(),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          repository,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: const ThreadDetailPage(tid: '100', subject: '测试主题'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('thread-detail-list'));
      final sticky = find.byKey(
        const Key('thread-detail-sticky-replies-header'),
      );
      final listTop = tester.getTopLeft(list).dy;
      final headerHeight = _repliesHeaderHeight(tester);
      expect(headerHeight, greaterThanOrEqualTo(60));

      await tester.tap(find.byKey(const Key('thread-next-post-button')));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.getTopLeft(find.byKey(const Key('thread-post-card-wide-p2'))).dy,
        closeTo(listTop + headerHeight, 2),
      );
      expect(sticky, findsOneWidget);
      expect(tester.getTopLeft(sticky).dy, closeTo(listTop, .5));
      expect(tester.getSize(sticky).height, closeTo(headerHeight, .5));
      expect(
        tester
            .getSize(
              find.byKey(
                const Key('thread-detail-sticky-replies-header-surface'),
              ),
            )
            .width,
        tester.getSize(list).width,
      );
    },
  );

  testWidgets('reply-only pages start with a sticky-capable replies header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeThreadRepository(
      (tid, page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          currentPage: page,
          lastPage: 2,
          posts: [
            for (var index = 21; index <= 22; index++)
              _post(
                pid: 'reply-only-$index',
                author: 'bob',
                authorId: '2',
                number: index,
                message: List.generate(
                  40,
                  (line) => '<p>第$index楼段落 $line</p>',
                ).join(),
              ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('thread-detail-list'));
    final inline = find.byKey(const Key('thread-detail-replies-header'));
    final sticky = find.byKey(const Key('thread-detail-sticky-replies-header'));
    expect(inline, findsOneWidget);
    expect(
      tester.getTopLeft(inline).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('thread-post-card-reply-only-21')))
            .dy,
      ),
    );

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(120);
    await tester.pumpAndSettle();
    expect(sticky, findsOneWidget);
    expect(
      tester.getTopLeft(sticky).dy,
      closeTo(tester.getTopLeft(list).dy, .5),
    );
  });
}
