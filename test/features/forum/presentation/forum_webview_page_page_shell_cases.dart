part of 'forum_webview_page_test.dart';

void _bootstrapShellCases() {
  testWidgets(
    'ForumWebViewPage waits for bootstrap config without skeleton page',
    (tester) async {
      final driver = _FakeForumWebViewDriver()
        ..capabilityProfile = const ForumWebViewCapabilityProfile(
          documentStartMode: ForumWebViewDocumentStartMode.unavailable,
          supportsContentBlockers: false,
          supportsTransparentBackground: false,
          supportsPlatformScrollTuning: false,
          supportsCookieHooks: false,
        );

      await tester.pumpWidget(_buildTestApp(driver: driver));

      expect(
        find.byKey(const Key('forum-webview-bootstrap-blank')),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
      expect(find.byKey(const Key('forum-webview-surface')), findsNothing);
      expect(driver.buildWidgetCallCount, 0);

      await tester.pump();

      expect(find.byKey(const Key('forum-webview-surface')), findsOneWidget);
      expect(driver.buildWidgetCallCount, greaterThanOrEqualTo(1));
    },
  );
}

void _conversionModeCases() {
  testWidgets(
    'manual content mode does not resolve a converter for WebView DOM',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '软件原文标题';
      var converterProviderReadCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServerContentConversionModeProvider.overrideWithValue(
              TextConversionMode.toTraditional,
            ),
            textConverterProvider.overrideWith((ref, mode) {
              converterProviderReadCount += 1;
              throw StateError('WebView must not resolve OpenCC');
            }),
          ],
          child: _buildTestApp(driver: driver),
        ),
      );
      await tester.pumpAndSettle();

      expect(converterProviderReadCount, 0);
      expect(driver.bootstrapConfig?.initialUri.host, 'bbs.yamibo.com');
      expect(find.byKey(const Key('forum-webview-surface')), findsOneWidget);
    },
  );
}

void _homeShellCases() {
  testWidgets(
    'ForumWebViewPage shows home app bar and seeds raw cookies before load',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final cookieStore = _FakeCookieStore(
        cookies: <String, String>{
          'auth': 'token%2B123',
          'saltkey': 'abc%7Cxyz',
          'removed': 'deleted',
          'empty': '',
        },
      );

      final jar = _MemoryWebViewCookieJar()..cookies['waf'] = 'live-flow';
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          cookieStore: cookieStore,
          cookieSyncService: WebViewCookieSyncService(
            cookieJar: jar,
            cookieStore: cookieStore,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('forum-webview-page')), findsOneWidget);
      expect(find.text('论坛首页'), findsOneWidget);
      expect(find.byKey(const Key('forum-webview-back-button')), findsNothing);
      expect(
        find.byKey(const Key('forum-webview-search-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('forum-webview-more-button')),
        findsOneWidget,
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.systemOverlayStyle?.statusBarColor, Colors.transparent);
      expect(driver.events, <String>[
        'probeCapabilities',
        'initialize',
        'load',
      ]);
      expect(driver.probeCapabilitiesCallCount, 1);
      expect(
        driver.bootstrapConfig?.initialUri.toString(),
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
      final bootstrapConfig = driver.bootstrapConfig!;
      expect(bootstrapConfig.visualPolicy.earlyHiddenSelectors, const <String>{
        '#header-padding',
        '.header.cl',
        '.footer.mt10.cl',
        '.foot.flex-box',
      });
      expect(bootstrapConfig.visualPolicy.lateRemovedSelectors, const <String>{
        '#header-padding',
        '.header.cl',
        '.footer.mt10.cl',
        '.foot.flex-box',
      });
      expect(bootstrapConfig.initialUserScripts, hasLength(1));
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        isNot(containsCssSelector('.foot_height')),
      );
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        isNot(containsCssSelector('.foot-pwa')),
      );
      expect(bootstrapConfig.networkPolicy.customUserAgent, isNull);
      expect(bootstrapConfig.networkPolicy.preferAppLocale, isTrue);
      expect(driver.seededCookies, isEmpty);
      expect(jar.clearCount, 0);
      expect(jar.cookies, <String, String>{
        'waf': 'live-flow',
        'auth': 'token%2B123',
        'saltkey': 'abc%7Cxyz',
      });
      final initialLoadRequest = driver.loadRequests.single;
      final initialHeaderKeys = initialLoadRequest.headers.keys
          .map((key) => key.toLowerCase())
          .toSet();
      expect(initialLoadRequest.headers['Referer'], 'https://bbs.yamibo.com/');
      expect(initialHeaderKeys, contains('accept-language'));
      expect(initialHeaderKeys, isNot(contains('cookie')));
      expect(initialHeaderKeys, isNot(contains('user-agent')));
      expect(
        initialLoadRequest.uri.toString(),
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
    },
  );
}

void _earlyUserScriptCases() {
  testWidgets(
    'ForumWebViewPage passes early user scripts into bootstrap config when document-start is available',
    (tester) async {
      final driver = _FakeForumWebViewDriver()
        ..capabilityProfile = const ForumWebViewCapabilityProfile(
          documentStartMode: ForumWebViewDocumentStartMode.bestEffort,
          supportsContentBlockers: false,
          supportsTransparentBackground: true,
          supportsPlatformScrollTuning: true,
          supportsCookieHooks: true,
        );

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      final bootstrapConfig = driver.bootstrapConfig!;
      expect(bootstrapConfig.initialUserScripts, hasLength(1));
      expect(
        bootstrapConfig.initialUserScripts.single.injectionTime,
        ForumWebViewInitialUserScriptInjectionTime.documentStart,
      );
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        contains("window.location.host !== 'bbs.yamibo.com'"),
      );
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        isNot(containsCssSelector('.foot_height')),
      );
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        isNot(containsCssSelector('.foot-pwa')),
      );
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        containsCssSelector('.foot.foot_reply.flex-box.cl'),
      );
      expect(
        bootstrapConfig.initialUserScripts.single.source,
        containsCssSelector('.foot_height_view'),
      );
    },
  );
}

void _homeChromeCases() {
  testWidgets(
    'ForumWebViewPage cleans baseline chrome when home finishes loading',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
      await tester.pump();

      expect(driver.scripts.length, 1);
      expect(driver.scripts.single, containsCssSelector('#header-padding'));
      expect(driver.scripts.single, containsCssSelector('.header.cl'));
      expect(driver.scripts.single, isNot(containsCssSelector('.foot_height')));
      expect(driver.scripts.single, isNot(containsCssSelector('.foot-pwa')));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(driver.scripts.length, 2);
    },
  );
}

void _threadChromeCases() {
  testWidgets(
    'ForumWebViewPage uses thread-detail cleanup selectors after thread detail navigation',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      expect(driver.scripts.length, 1);
      expect(
        driver.scripts.single,
        containsCssSelector('.foot.foot_reply.flex-box.cl'),
      );
      expect(driver.scripts.single, containsCssSelector('.foot_height_view'));
    },
  );
}

void _searchChromeCases() {
  testWidgets(
    'ForumWebViewPage uses pwa cleanup selectors after search navigation',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '帖子搜索';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/search.php?mod=forum&searchid=777&mobile=2',
      );
      await tester.pump();

      expect(driver.scripts.length, 1);
      expect(driver.scripts.single, containsCssSelector('.foot_height'));
      expect(driver.scripts.single, containsCssSelector('.foot-pwa'));
    },
  );
}

void _surfaceCases() {
  testWidgets(
    'ForumWebViewPage renders the WebView surface without loading masks',
    (tester) async {
      for (final profile in <ForumWebViewCapabilityProfile>[
        const ForumWebViewCapabilityProfile(
          documentStartMode: ForumWebViewDocumentStartMode.bestEffort,
          supportsContentBlockers: false,
          supportsTransparentBackground: true,
          supportsPlatformScrollTuning: true,
          supportsCookieHooks: true,
          supportsPageCommitVisible: true,
        ),
        const ForumWebViewCapabilityProfile(
          documentStartMode: ForumWebViewDocumentStartMode.unavailable,
          supportsContentBlockers: false,
          supportsTransparentBackground: false,
          supportsPlatformScrollTuning: false,
          supportsCookieHooks: false,
          supportsPageCommitVisible: false,
        ),
      ]) {
        final driver = _FakeForumWebViewDriver()..capabilityProfile = profile;

        await tester.pumpWidget(_buildTestApp(driver: driver));
        await tester.pump();

        expect(find.byKey(const Key('forum-webview-surface')), findsOneWidget);
        expect(
          find.byKey(const Key('forum-webview-loading-mask')),
          findsNothing,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);

        await driver.dispatchPageStarted(
          'https://bbs.yamibo.com/index.php?mobile=2',
        );
        await driver.dispatchPageFinished(
          'https://bbs.yamibo.com/index.php?mobile=2',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('forum-webview-loading-mask')),
          findsNothing,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(driver.scripts.length, 1);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}

void _refreshIndicatorCases() {
  testWidgets('ForumWebViewPage no longer wraps webview in refresh indicator', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();

    await tester.pumpWidget(_buildTestApp(driver: driver));
    await tester.pump();

    expect(
      find.byKey(const Key('forum-webview-refresh-indicator')),
      findsNothing,
    );
    expect(find.byKey(const Key('forum-webview-refresh-scroll')), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });
}
