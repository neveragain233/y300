part of 'forum_webview_page_test.dart';

void _unboundSessionCookieCases() {
  for (final action in ['login', 'logout', 'confirmAnonymous']) {
    testWidgets('unbound browser cookie return respects session $action', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final sessions = YamiboSessionStore();
      YamiboSessionSnapshot snapshot(bool loggedIn) => YamiboSessionSnapshot(
        isLoggedIn: loggedIn,
        uid: loggedIn ? '101' : '0',
        username: loggedIn ? 'actor' : '',
        formhash: 'proof',
        updatedAt: DateTime(2026),
        source: 'test',
      );
      if (action == 'logout') sessions.saveExtracted(snapshot(true));
      final jar = _PendingWebViewCookieJar();
      final store = CookieStore();
      final uri = Uri.parse(
        'https://bbs.yamibo.com/home.php?mod=space&do=blog',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboSessionStoreProvider.overrideWithValue(sessions),
            webViewCookieSyncServiceProvider.overrideWithValue(
              WebViewCookieSyncService(cookieJar: jar, cookieStore: store),
            ),
          ],
          child: _buildTestApp(driver: driver),
        ),
      );
      await tester.pumpAndSettle();
      await driver.dispatchPageFinished(uri.toString());
      expect(jar.readCount, 1);
      if (action == 'logout') {
        sessions.clear();
      } else {
        sessions.saveExtracted(snapshot(action == 'login'));
      }
      jar.pending.complete({'auth': 'previous-browser'});
      await tester.pumpAndSettle();
      expect(
        await store.readCookieMap(uri),
        action == 'confirmAnonymous' ? {'auth': 'previous-browser'} : isEmpty,
      );
      expect(
        find.byKey(const Key('forum-webview-surface')),
        action == 'confirmAnonymous' ? findsOneWidget : findsNothing,
      );
      if (action != 'confirmAnonymous') {
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ForumWebViewPage)),
        );
        expect(find.text(l10n.forumWebViewAccountChanged), findsOneWidget);
        expect(
          await driver.dispatchNavigationRequest('index.php?mobile=2'),
          ForumWebViewNavigationDecision.prevent,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

void _pendingCookieSyncCases() {
  for (final action in ['stay', 'navigate', 'dispose', 'accountChange']) {
    testWidgets(
      'page-finished cookie sync respects $action while the read is pending',
      (tester) async {
        final driver = _FakeForumWebViewDriver();
        final jar = _PendingWebViewCookieJar();
        final store = CookieStore();
        var active = true;
        final uri = Uri.parse(
          'https://bbs.yamibo.com/home.php?mod=space&do=blog&uid=101&id=42',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              webViewCookieSyncServiceProvider.overrideWithValue(
                WebViewCookieSyncService(cookieJar: jar, cookieStore: store),
              ),
            ],
            child: _buildTestApp(
              driver: driver,
              isAccountCurrent: () => active,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await driver.dispatchPageFinished(uri.toString());
        expect(jar.readCount, 1);
        switch (action) {
          case 'navigate':
            await driver.dispatchPageStarted(
              'https://bbs.yamibo.com/forum.php',
            );
          case 'dispose':
            await tester.pumpWidget(const SizedBox());
          case 'accountChange':
            active = false;
        }
        jar.pending.complete({'auth': 'browser-actor'});
        await tester.pumpAndSettle();
        expect(
          await store.readCookieMap(uri),
          action == 'stay' ? {'auth': 'browser-actor'} : isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
