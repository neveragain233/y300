part of 'forum_webview_page_test.dart';

void _routeBackCases() {
  testWidgets('standalone forum home has a working route back button', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [forumWebViewPopOnRootBackProvider.overrideWithValue(true)],
        child: _buildRoutedTestApp(driver: driver),
      ),
    );
    await tester.tap(find.byKey(const Key('open-forum-webview-page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forum-webview-back-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('forum-webview-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forum-webview-page')), findsNothing);
    expect(find.byKey(const Key('open-forum-webview-page')), findsOneWidget);
    expect(driver.goBackCallCount, 0);
    expect(driver.loadedUris, hasLength(1));
  });
}

void _backCases() {
  testWidgets(
    'ForumWebViewPage back button uses driver.goBack when history exists',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(driver.goBackCallCount, 1);
      expect(
        driver.loadedUris.single.toString(),
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
    },
  );

  testWidgets(
    'ForumWebViewPage back button loads home when history is unavailable',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      driver.canGoBackValue = false;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(driver.goBackCallCount, 0);
      expect(driver.loadedUris.length, 2);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
    },
  );

  testWidgets(
    'ForumWebViewPage system back uses driver.goBack when history exists',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';

      await tester.pumpWidget(_buildRoutedTestApp(driver: driver));
      await tester.tap(find.byKey(const Key('open-forum-webview-page')));
      await tester.pumpAndSettle();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(driver.goBackCallCount, 1);
      expect(find.byKey(const Key('forum-webview-page')), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage system back loads home when history is unavailable away from home',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';

      await tester.pumpWidget(_buildRoutedTestApp(driver: driver));
      await tester.tap(find.byKey(const Key('open-forum-webview-page')));
      await tester.pumpAndSettle();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(driver.goBackCallCount, 0);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
      expect(find.byKey(const Key('forum-webview-page')), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage system back allows route pop on home without history',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildRoutedTestApp(driver: driver));
      await tester.tap(find.byKey(const Key('open-forum-webview-page')));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-webview-page')), findsNothing);
      expect(find.byKey(const Key('open-forum-webview-page')), findsOneWidget);
    },
  );
}
