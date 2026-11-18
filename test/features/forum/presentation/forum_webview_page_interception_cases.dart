part of 'forum_webview_page_test.dart';

void _externalLinkInterceptionCases() {
  testWidgets('ForumWebViewPage copies external links and reports success', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final launcher = _FakeForumWebViewExternalLauncher();
    final clipboard = _FakeClipboardTextWriter();

    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        launcher: launcher,
        clipboardWriter: clipboard,
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ForumWebViewPage)),
    );

    final decision = await driver.dispatchNavigationRequest(
      'https://example.com/thread/123?ref=a%2Fb&value=two#part',
    );
    await tester.pumpAndSettle();

    expect(decision, ForumWebViewNavigationDecision.prevent);
    expect(
      clipboard.written.single,
      'https://example.com/thread/123?ref=a%2Fb&value=two#part',
    );
    expect(launcher.launchedUris, isEmpty);
    expect(find.text(l10n.linkCopied), findsOneWidget);
  });

  testWidgets('ForumWebViewPage reports an external link copy failure', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final launcher = _FakeForumWebViewExternalLauncher();
    final clipboard = _FakeClipboardTextWriter(error: StateError('clipboard'));

    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        launcher: launcher,
        clipboardWriter: clipboard,
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ForumWebViewPage)),
    );

    final decision = await driver.dispatchNavigationRequest(
      'https://example.com/thread/123',
    );
    await tester.pumpAndSettle();

    expect(decision, ForumWebViewNavigationDecision.prevent);
    expect(clipboard.written.single, 'https://example.com/thread/123');
    expect(launcher.launchedUris, isEmpty);
    expect(find.text(l10n.linkCopyFailed), findsOneWidget);
    expect(find.text(l10n.linkCopied), findsNothing);
  });

  for (final invalidation in ['owner', 'navigation', 'dispose']) {
    testWidgets(
      'ForumWebViewPage suppresses stale copy feedback after $invalidation',
      (tester) async {
        final driver = _FakeForumWebViewDriver();
        final clipboard = _FakeClipboardTextWriter(pending: Completer<void>());
        final launcher = _FakeForumWebViewExternalLauncher();
        var accountCurrent = true;
        await tester.pumpWidget(
          _buildTestApp(
            driver: driver,
            launcher: launcher,
            clipboardWriter: clipboard,
            isAccountCurrent: () => accountCurrent,
          ),
        );
        await tester.pump();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ForumWebViewPage)),
        );
        await driver.dispatchNavigationRequest('https://example.com/late');
        expect(clipboard.written, ['https://example.com/late']);
        switch (invalidation) {
          case 'owner':
            accountCurrent = false;
          case 'navigation':
            await driver.dispatchPageStarted(
              'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=6',
            );
          case 'dispose':
            await tester.pumpWidget(const SizedBox());
        }
        clipboard.pending!.complete();
        await tester.pump();
        expect(launcher.launchedUris, isEmpty);
        expect(find.text(l10n.linkCopied), findsNothing);
        expect(find.text(l10n.linkCopyFailed), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ForumWebViewPage still rejects javascript without copying', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final clipboard = _FakeClipboardTextWriter();
    final launcher = _FakeForumWebViewExternalLauncher();
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        launcher: launcher,
        clipboardWriter: clipboard,
      ),
    );
    await tester.pump();
    expect(
      await driver.dispatchNavigationRequest('javascript:void(0)'),
      ForumWebViewNavigationDecision.prevent,
    );
    expect(clipboard.written, isEmpty);
    expect(launcher.launchedUris, isEmpty);
  });
}

void _composerInterceptionCases() {
  testWidgets('ForumWebViewPage opens thread reply composer with fid and tid', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver()..title = '主题标题';
    final replyRepository = _FakeThreadReplyAdapter();

    await tester.pumpWidget(
      _buildTestApp(driver: driver, replyRepository: replyRepository),
    );
    await tester.pump();

    await driver.dispatchPageStarted(
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&fid=55&mobile=2',
    );
    await driver.dispatchPageFinished(
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&fid=55&mobile=2',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('forum-webview-thread-reply-button')),
      findsOneWidget,
    );
    // 动作已收进公共顶栏胶囊，按 AppBar 内的实际按钮与几何顺序断言。
    final appBar = find.byType(AppBar);
    final replyButton = find.byKey(
      const Key('forum-webview-thread-reply-button'),
    );
    expect(find.descendant(of: appBar, matching: replyButton), findsOneWidget);
    expect(
      find.descendant(
        of: appBar,
        matching: find.byKey(const Key('forum-webview-more-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: appBar,
        matching: find.byKey(const Key('forum-webview-search-button')),
      ),
      findsNothing,
    );
    expect(
      tester.getCenter(replyButton).dx,
      lessThan(
        tester.getCenter(find.byKey(const Key('forum-webview-more-button'))).dx,
      ),
    );

    await tester.tap(
      find.byKey(const Key('forum-webview-thread-reply-button')),
    );
    await _pumpRouteWithoutSettlingEditor(
      tester,
      readyWhen: find.byKey(const Key('reply-composer-source-button')),
      requireEnabled: true,
    );

    expect(find.text('回复帖子'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reply-composer-source-button')));
    await _pumpRouteWithoutSettlingEditor(
      tester,
      readyWhen: find.byKey(const Key('reply-composer-message-input')),
    );
    await tester.enterText(
      find.byKey(const Key('reply-composer-message-input')),
      '来自 WebView 的回复',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    expect(replyRepository.sentDrafts, hasLength(1));
    expect(replyRepository.sentDrafts.single.target.fid, '55');
    expect(replyRepository.sentDrafts.single.target.tid, '123');
    expect(replyRepository.sentDrafts.single.message, '来自 WebView 的回复');
    expect(driver.reloadCallCount, 1);
    expect(find.text('回复成功'), findsOneWidget);
  });

  testWidgets(
    'ForumWebViewPage intercepts post reply navigation and reloads after sent',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';
      final replyRepository = _FakeThreadReplyAdapter();

      await tester.pumpWidget(
        _buildTestApp(driver: driver, replyRepository: replyRepository),
      );
      await tester.pump();

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=post&action=reply'
        '&fid=55&tid=123&repquote=41554317'
        '&extra=page%3D1&page=1&mobile=2',
      );
      await _pumpRouteWithoutSettlingEditor(
        tester,
        readyWhen: find.byKey(const Key('reply-composer-source-button')),
        requireEnabled: true,
      );

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.text('回复楼层'), findsOneWidget);
      expect(replyRepository.prepareCallCount, 1);
      expect(
        find.byKey(const Key('reply-composer-reference-banner')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('reply-composer-source-button')));
      await _pumpRouteWithoutSettlingEditor(
        tester,
        readyWhen: find.byKey(const Key('reply-composer-message-input')),
      );
      await tester.enterText(
        find.byKey(const Key('reply-composer-message-input')),
        '来自 WebView 的楼层回复',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('reply-composer-send-button')));
      await tester.pumpAndSettle();

      expect(replyRepository.sentDrafts, hasLength(1));
      expect(replyRepository.sentDrafts.single.target.fid, '55');
      expect(replyRepository.sentDrafts.single.target.tid, '123');
      expect(replyRepository.sentDrafts.single.target.pid, '41554317');
      expect(
        replyRepository.sentDrafts.single.preparation?.token,
        isA<_TestThreadReplyToken>(),
      );
      expect(driver.reloadCallCount, 1);
    },
  );

  testWidgets(
    'ForumWebViewPage intercepts newthread navigation and reloads after sent',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';
      final newThreadRepository = _FakeThreadCreationCommand();
      final metadataRepository = _FakeThreadCreationPreparationRepository(
        metadata: const ThreadCreationPreparation(
          fid: '33',
          forumName: '日常版',
          threadTypes: <ThreadCreationType>[],
          threadSorts: <ThreadCreationSort>[],
          typeRequired: false,
          sortRequired: false,
          maxSubjectLength: 0,
          maxMessageLength: 0,
          token: _TestThreadCreationToken(),
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          newThreadRepository: newThreadRepository,
          postingFormMetadataRepository: metadataRepository,
        ),
      );
      await tester.pump();

      // WebView 拦截到形如 forum.php?mod=post&action=newthread&fid=33&mobile=2 的 URL，
      // 应该 prevent 并打开自制发帖页。`&amp;` HTML 转义场景同时覆盖。
      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=post&amp;action=newthread'
        '&amp;fid=33&amp;mobile=2',
      );
      await _pumpRouteWithoutSettlingEditor(
        tester,
        readyWhen: find.byKey(const Key('posting-composer-source-button')),
        requireEnabled: true,
      );

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.text('发帖 — 日常版'), findsOneWidget);
      expect(metadataRepository.callCount, 1);

      await tester.enterText(
        find.byKey(const Key('posting-composer-subject-input')),
        '来自 WebView 的标题',
      );
      await tester.tap(find.byKey(const Key('posting-composer-source-button')));
      await _pumpRouteWithoutSettlingEditor(
        tester,
        readyWhen: find.byKey(const Key('posting-composer-message-input')),
      );
      await tester.enterText(
        find.byKey(const Key('posting-composer-message-input')),
        '来自 WebView 的正文',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('posting-composer-send-button')));
      await tester.pumpAndSettle();

      expect(newThreadRepository.submittedPayloads, hasLength(1));
      expect(
        newThreadRepository.submittedPayloads.single.preparation.fid,
        '33',
      );
      expect(
        newThreadRepository.submittedPayloads.single.subject,
        '来自 WebView 的标题',
      );
      expect(
        newThreadRepository.submittedPayloads.single.message,
        '来自 WebView 的正文',
      );
      expect(newThreadRepository.submittedPayloads.single.minimumReadAccess, 0);
      // 提交成功 → SnackBar + WebView reload。
      expect(driver.reloadCallCount, 1);
      expect(find.text('发布成功'), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage does not intercept reply newthread without fid',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '论坛首页';
      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      // mod=post & action=newthread 但 fid 为空 → navigator 返回 null，
      // 当前是站内 URL 应该回退到 navigate（让 WebView 自己渲染兜底）。
      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=post&action=newthread',
      );

      expect(decision, ForumWebViewNavigationDecision.navigate);
      expect(find.text('发帖 — 日常版'), findsNothing);
    },
  );
}
