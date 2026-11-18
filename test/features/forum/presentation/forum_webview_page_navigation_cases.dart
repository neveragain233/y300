part of 'forum_webview_page_test.dart';

void _navigationCases() {
  for (final entry in [
    (url: 'index.php?mobile=2', kind: YamiboForumLinkKind.home),
    (
      url: 'forum.php?mod=forumdisplay&fid=42&page=3',
      kind: YamiboForumLinkKind.forumDisplay,
    ),
    (
      url: 'search.php?mod=curforum&srhfid=42',
      kind: YamiboForumLinkKind.search,
    ),
    (url: 'thread-572514-4-1.html', kind: YamiboForumLinkKind.thread),
  ]) {
    testWidgets('ordinary browser link opens ${entry.kind} natively', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      YamiboForumLinkDestination? opened;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeForumLinkPageFactoryProvider.overrideWithValue((
              destination, {
              isActive = true,
            }) {
              opened = destination;
              return const Scaffold(key: Key('test-native-forum-link'));
            }),
          ],
          child: _buildTestApp(
            driver: driver,
            navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final decision = await driver.dispatchNavigationRequest(entry.url);
      await tester.pumpAndSettle();
      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(opened?.kind, entry.kind);
      expect(find.byKey(const Key('test-native-forum-link')), findsOneWidget);
      expect(driver.loadedUris, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final purpose in ForumWebViewHostPurpose.values) {
    for (final policy in ForumWebViewNavigationPolicy.values) {
      if (prefersNativeForumNavigation(purpose: purpose, policy: policy)) {
        continue;
      }
      testWidgets('$purpose with $policy keeps supported links in browser', (
        tester,
      ) async {
        final driver = _FakeForumWebViewDriver();
        await tester.pumpWidget(
          _buildTestApp(
            driver: driver,
            hostPurpose: purpose,
            navigationPolicy: policy,
          ),
        );
        await tester.pumpAndSettle();
        final decision = await driver.dispatchNavigationRequest(
          'forum.php?mod=viewthread&tid=572514&mobile=2',
        );
        await tester.pumpAndSettle();
        expect(decision, ForumWebViewNavigationDecision.navigate);
        expect(
          find.byType(ThreadDetailPage, skipOffstage: false),
          findsNothing,
        );
        expect(driver.loadedUris, hasLength(1));
      });
    }
  }
}

void _unknownThreadFilterCases() {
  testWidgets('unknown thread filters preserve browser URL semantics', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();
    final decision = await driver.dispatchNavigationRequest(
      'forum.php?mod=viewthread&tid=572514&authorid=101',
    );
    await tester.pumpAndSettle();
    expect(decision, ForumWebViewNavigationDecision.navigate);
    expect(find.byType(ThreadDetailPage, skipOffstage: false), findsNothing);
    expect(driver.loadedUris, hasLength(1));
  });
}

void _searchNavigationCases() {
  testWidgets(
    'ForumWebViewPage home search button loads managed forum search url',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-search-button')));
      await tester.pumpAndSettle();

      expect(driver.loadedUris.length, 2);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/search.php?mod=forum&mobile=2',
      );
      expect(
        driver.loadRequests.last.headers['Referer'],
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
      expect(
        driver.loadRequests.last.headers.keys
            .map((key) => key.toLowerCase())
            .toSet(),
        isNot(contains('cookie')),
      );
    },
  );
}

void _managedLinkCases() {
  testWidgets('ForumWebViewPage keeps managed site links inside webview', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final launcher = _FakeForumWebViewExternalLauncher();

    await tester.pumpWidget(_buildTestApp(driver: driver, launcher: launcher));
    await tester.pump();

    final decision = await driver.dispatchNavigationRequest(
      'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
    );

    expect(decision, ForumWebViewNavigationDecision.navigate);
    expect(launcher.launchedUris, isEmpty);
  });

  testWidgets(
    'ForumWebViewPage keepWebView policy normalizes thread links in webview',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/home.php?mod=space&uid=100&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/home.php?mod=space&uid=100&mobile=2',
      );
      await tester.pump();

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=573279&extra=',
      );
      await tester.pump();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=573279&mobile=2',
      );
    },
  );
}

void _postEditFallbackCases() {
  testWidgets(
    'post edit fallback exposes native switch and completes on target redirect',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final editUri = Uri.parse(
        'https://bbs.yamibo.com/forum.php?mod=post&action=edit&fid=5&tid=557857&pid=41587383',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            forumWebViewInitialUriProvider.overrideWithValue(editUri),
            forumWebViewHostPurposeProvider.overrideWithValue(
              ForumWebViewHostPurpose.postEditFallback,
            ),
            forumWebViewCompletionTargetProvider.overrideWithValue(
              const ForumWebViewCompletionTarget(
                tid: '557857',
                pid: '41587383',
              ),
            ),
          ],
          child: _buildRoutedTestApp(driver: driver),
        ),
      );
      await tester.tap(find.byKey(const Key('open-forum-webview-page')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('forum-webview-post-edit-native-button')),
        findsOneWidget,
      );
      final visualPolicy = driver.bootstrapConfig!.visualPolicy;
      for (final selector in <String>[
        '#postform',
        '#needmessage',
        '#imglist',
        '.post_btn',
        '#postsubmit',
      ]) {
        expect(visualPolicy.earlyHiddenSelectors, isNot(contains(selector)));
        expect(visualPolicy.lateRemovedSelectors, isNot(contains(selector)));
      }

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=redirect&goto=findpost&ptid=557857&pid=41587383',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.byKey(const Key('forum-webview-page')), findsNothing);
    },
  );
}

void _findpostRedirectCases() {
  testWidgets(
    'ForumWebViewPage keepWebView policy loads normalized findpost redirect',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      final decision = await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&amp;goto=findpost&amp;ptid=570388&amp;pid=41575705',
      );
      await tester.pump();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=redirect&goto=findpost&ptid=570388&pid=41575705&mobile=2',
      );
    },
  );
}

void _nativeThreadNavigationCases() {
  testWidgets(
    'ForumWebViewPage preferNative policy opens direct thread natively',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=573279&extra=',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.byType(ThreadDetailPage), findsOneWidget);
      expect(driver.loadedUris.length, 1);
    },
  );

  testWidgets(
    'ForumWebViewPage preferNative policy opens fragment post natively',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=570388&page=2#pid41575705',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.byType(ThreadDetailPage), findsOneWidget);
      expect(
        find.byKey(const Key('thread-detail-target-scroll-spacer')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ForumWebViewPage preferNative policy locates findpost before opening',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final locator = _FakeThreadPostLocator(
        const ThreadPostLocation(
          tid: '570388',
          pid: '41575705',
          page: 2,
          url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=570388&page=2#pid41575705',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          threadPostLocator: locator,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&goto=findpost&ptid=570388&pid=41575705',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(locator.lastTid, '570388');
      expect(locator.lastPid, '41575705');
      expect(locator.lastSourceUri?.queryParameters['ptid'], '570388');
      expect(
        locator.lastSourceUri?.queryParameters.containsKey('authorid'),
        isFalse,
      );
      expect(find.byType(ThreadDetailPage), findsOneWidget);
      expect(
        find.byKey(const Key('thread-detail-target-scroll-spacer')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pending findpost result cannot navigate after its account expires before disposal',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final pending = Completer<ApiResult<ThreadPostLocation>>();
      final locator = _FakeThreadPostLocator(null, pending: pending);
      var accountCurrent = true;
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          isAccountCurrent: () => accountCurrent,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          threadPostLocator: locator,
        ),
      );
      await tester.pumpAndSettle();
      final browserState = tester.state(find.byType(ForumWebViewPage));
      final decision = await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&goto=findpost&ptid=570388&pid=41575705',
      );
      await tester.pump();
      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(locator.lastPid, '41575705');
      expect(find.byType(ThreadDetailPage), findsNothing);

      // The guard expires synchronously; the platform view detaches next frame.
      accountCurrent = false;
      expect(browserState.mounted, isTrue);
      pending.complete(
        const ApiSuccess(
          ThreadPostLocation(tid: '570388', pid: '41575705', page: 2, url: ''),
        ),
      );
      await tester.pumpAndSettle();
      expect(browserState.mounted, isTrue);
      expect(find.byType(ThreadDetailPage), findsNothing);
      expect(
        find.byKey(const Key('thread-post-route-failure-dialog')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native filtered floor link relocates instead of trusting its page',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final locator = _FakeThreadPostLocator(
        const ThreadPostLocation(
          tid: '570388',
          pid: '41575705',
          page: 2,
          url: '',
        ),
      );
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          threadPostLocator: locator,
        ),
      );
      await tester.pumpAndSettle();
      await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=570388&page=99&authorid=10&ordertype=1#pid41575705',
      );
      await tester.pumpAndSettle();
      expect(locator.lastPid, '41575705');
      final page = tester.widget<ThreadDetailPage>(
        find.byType(ThreadDetailPage),
      );
      expect(page.initialPage, 2);
      expect(page.targetPid, '41575705');
    },
  );

  testWidgets(
    'native location failure stays in WebView until explicitly retried',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final locator = _FakeThreadPostLocator(null);
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          threadPostLocator: locator,
        ),
      );
      await tester.pumpAndSettle();
      await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&goto=findpost&ptid=570388&pid=41575705',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ThreadDetailPage), findsNothing);
      expect(
        find.byKey(const Key('thread-post-route-failure-dialog')),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ForumWebViewPage)),
      );
      expect(find.text(l10n.threadPostTargetUnconfirmed), findsOneWidget);
      locator.location = const ThreadPostLocation(
        tid: '570388',
        pid: '41575705',
        page: 2,
        url: '',
      );
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();
      expect(find.byType(ThreadDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage preferNative policy resolves empty findpost redirect',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final redirectResolver = _FakeForumWebViewRedirectResolver(
        finalUri: Uri.parse(
          'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=572051',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          redirectResolver: redirectResolver,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&goto=findpost&ptid=570388&pid=',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(redirectResolver.lastSourceUri?.queryParameters['mobile'], '2');
      expect(find.byType(ThreadDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage falls back to webview when empty redirect fails',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final redirectResolver = _FakeForumWebViewRedirectResolver(
        result: const ApiFailure<ForumWebViewRedirectResolution>(
          ApiError(type: ApiErrorType.business, message: 'redirect failed'),
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          redirectResolver: redirectResolver,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&goto=findpost&ptid=570388&pid=',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.text('帖子链接解析失败，已在网页中打开'), findsOneWidget);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=redirect&goto=findpost&ptid=570388&mobile=2',
      );
      final repeated = await driver.dispatchNavigationRequest(
        driver.loadedUris.last.toString(),
      );
      final thread = await driver.dispatchNavigationRequest(
        'forum.php?mod=viewthread&tid=570388&mobile=2',
      );
      await tester.pumpAndSettle();
      expect(repeated, ForumWebViewNavigationDecision.navigate);
      expect(thread, ForumWebViewNavigationDecision.navigate);
      expect(redirectResolver.resolveCount, 1);
      expect(find.byType(ThreadDetailPage, skipOffstage: false), findsNothing);
    },
  );

  for (final boundary in ['navigation', 'account', 'dispose']) {
    testWidgets('pending empty redirect respects $boundary expiry', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final pending = Completer<ApiResult<ForumWebViewRedirectResolution>>();
      final resolver = _FakeForumWebViewRedirectResolver(pending: pending);
      var currentAccount = true;
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          redirectResolver: resolver,
          isAccountCurrent: () => currentAccount,
        ),
      );
      await tester.pumpAndSettle();
      final first = await driver.dispatchNavigationRequest(
        'forum.php?mod=redirect&goto=findpost&ptid=570388&pid=',
      );
      await tester.pump();
      expect(first, ForumWebViewNavigationDecision.prevent);
      expect(resolver.resolveCount, 1);
      switch (boundary) {
        case 'navigation':
          await driver.dispatchPageStarted('home.php?mod=space&uid=102');
        case 'account':
          currentAccount = false;
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
      }
      pending.complete(
        ApiSuccess(
          ForumWebViewRedirectResolution(
            finalUri: Uri.parse(
              'https://bbs.yamibo.com/thread-570388-2-1.html',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ThreadDetailPage, skipOffstage: false), findsNothing);
      expect(driver.loadedUris, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
