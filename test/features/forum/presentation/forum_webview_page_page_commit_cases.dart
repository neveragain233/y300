part of 'forum_webview_page_test.dart';

void _staleGenerationCases() {
  testWidgets(
    'Phase 0 baseline ignores a stale page-finished navigation generation',
    (tester) async {
      const firstUrl =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=101&mobile=2';
      const secondUrl =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=202&mobile=2';
      final driver = _FakeForumWebViewDriver()..holdTitleReads = true;

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageStarted(firstUrl);
      final firstFinish = driver.dispatchPageFinished(firstUrl);
      await tester.pump();
      expect(driver.pendingTitleReads, hasLength(1));

      await driver.dispatchPageStarted(secondUrl);
      final secondFinish = driver.dispatchPageFinished(secondUrl);
      await tester.pump();
      expect(driver.pendingTitleReads, hasLength(2));

      driver.pendingTitleReads[1].complete('第二个主题');
      await secondFinish;
      await tester.pump();

      expect(find.text('第二个主题'), findsOneWidget);
      expect(driver.scripts, hasLength(1));

      driver.pendingTitleReads[0].complete('迟到的第一个主题');
      await firstFinish;
      await tester.pump();

      expect(find.text('第二个主题'), findsOneWidget);
      expect(find.text('迟到的第一个主题'), findsNothing);
      expect(driver.scripts, hasLength(1));
    },
  );
}

void _pageCommitRecordingCases() {
  testWidgets(
    'ForumWebViewPage with page-commit records only after visible commit and DOM proof',
    (tester) async {
      const url =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=524596&page=3&highlight=%D2%B2%CE%DE&mobile=2';
      final recorder = _RecordingHistoryVisitRecorder();
      final driver = _FakeForumWebViewDriver()
        ..title = '浏览器标题'
        ..javaScriptResult = _threadDocumentResult(
          title: '结构化主题',
          forumName: '中文百合漫画区',
          canonicalHref: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=524596&highlight=%BC%AB%CF%DE',
          postCount: 20,
        );

      await tester.pumpWidget(
        _buildTestApp(driver: driver, historyRecorder: recorder),
      );
      await tester.pump();

      await driver.dispatchPageStarted(url);
      await driver.dispatchPageFinished(url);
      await tester.pump();
      expect(recorder.drafts, isEmpty);

      await driver.dispatchPageCommitVisible(url);
      await tester.pump();

      expect(recorder.drafts, hasLength(1));
      final draft = recorder.drafts.single;
      expect(draft.target.id, '524596');
      expect(draft.surface, HistoryVisitSurface.threadWebView);
      expect(draft.title, '结构化主题');
      expect(draft.forumName, '中文百合漫画区');
      expect(draft.page, 3);
      expect(
        draft.thumbnail?.remoteUrl,
        'https://bbs.yamibo.com/data/attachment/forum/cover.jpg',
      );
      expect(draft.canonicalUri.toString(), isNot(contains('highlight')));
    },
  );

  testWidgets(
    'ForumWebViewPage with page-commit handles visible commit before finish once',
    (tester) async {
      const url =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=101&mobile=2';
      final recorder = _RecordingHistoryVisitRecorder();
      final driver = _FakeForumWebViewDriver()
        ..title = '主题'
        ..javaScriptResult = _threadDocumentResult(title: '主题');

      await tester.pumpWidget(
        _buildTestApp(driver: driver, historyRecorder: recorder),
      );
      await tester.pump();

      await driver.dispatchPageStarted(url);
      await driver.dispatchPageCommitVisible(url);
      expect(recorder.drafts, isEmpty);
      await driver.dispatchPageFinished(url);
      await tester.pump();

      expect(recorder.drafts, hasLength(1));
      await driver.dispatchPageCommitVisible(url);
      await tester.pump();
      expect(recorder.drafts, hasLength(1));
    },
  );

  testWidgets(
    'ForumWebViewPage without page-commit uses finished plus DOM proof fallback',
    (tester) async {
      const url =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=202&mobile=2';
      final recorder = _RecordingHistoryVisitRecorder();
      final driver = _FakeForumWebViewDriver()
        ..capabilityProfile = const ForumWebViewCapabilityProfile(
          documentStartMode: ForumWebViewDocumentStartMode.unavailable,
          supportsContentBlockers: false,
          supportsTransparentBackground: false,
          supportsPlatformScrollTuning: false,
          supportsCookieHooks: false,
          supportsPageCommitVisible: false,
        )
        ..title = '主题'
        ..javaScriptResult = _threadDocumentResult(title: 'Fallback 主题');

      await tester.pumpWidget(
        _buildTestApp(driver: driver, historyRecorder: recorder),
      );
      await tester.pump();
      await driver.dispatchPageStarted(url);
      await driver.dispatchPageFinished(url);
      await tester.pump();

      expect(recorder.drafts, hasLength(1));
      expect(recorder.drafts.single.target.id, '202');
      expect(recorder.drafts.single.title, 'Fallback 主题');
    },
  );

  testWidgets(
    'ForumWebViewPage does not record thread error document without post proof',
    (tester) async {
      const url =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=303&mobile=2';
      final recorder = _RecordingHistoryVisitRecorder();
      final driver = _FakeForumWebViewDriver()
        ..title = '主题不存在'
        ..javaScriptResult = _threadDocumentResult(
          title: '主题不存在',
          postCount: 0,
        );

      await tester.pumpWidget(
        _buildTestApp(driver: driver, historyRecorder: recorder),
      );
      await tester.pump();
      await driver.dispatchPageStarted(url);
      await driver.dispatchPageCommitVisible(url);
      await driver.dispatchPageFinished(url);
      await tester.pump();

      expect(recorder.drafts, isEmpty);
      expect(find.byKey(const Key('forum-webview-page')), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage records the final visible thread after redirect generation',
    (tester) async {
      const redirectUrl =
          'https://bbs.yamibo.com/forum.php?mod=redirect&goto=findpost&ptid=404&pid=1&mobile=2';
      const finalUrl =
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=404&page=2&mobile=2';
      final recorder = _RecordingHistoryVisitRecorder();
      final driver = _FakeForumWebViewDriver()
        ..title = '落地主题'
        ..javaScriptResult = _threadDocumentResult(title: '落地主题');

      await tester.pumpWidget(
        _buildTestApp(driver: driver, historyRecorder: recorder),
      );
      await tester.pump();
      await driver.dispatchPageStarted(redirectUrl);
      await driver.dispatchPageCommitVisible(finalUrl);
      await driver.dispatchPageFinished(finalUrl);
      await tester.pump();

      expect(recorder.drafts, hasLength(1));
      expect(recorder.drafts.single.target.id, '404');
      expect(recorder.drafts.single.page, 2);
    },
  );
}
