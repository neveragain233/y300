part of 'forum_webview_page_test.dart';

void _friendAndDirectoryCallbackCases() {
  const friendCases = [
    (
      url: 'home.php?mod=space&do=friend&mobile=2',
      scope: ForumFriendFeedScope.friends,
      page: 1,
    ),
    (
      url: 'home.php?mod=space&do=friend&uid=101&view=me&page=2&mobile=2',
      scope: ForumFriendFeedScope.friends,
      page: 2,
    ),
    (
      url: 'https://bbs.yamibo.com/home.php?mod=space&do=friend&uid=101&view=online&type=member&page=2&mobile=2',
      scope: ForumFriendFeedScope.online,
      page: 2,
    ),
    (
      url: 'home.php?mod=space&do=friend&view=visitor&page=3&mobile=2',
      scope: ForumFriendFeedScope.visitors,
      page: 3,
    ),
    (
      url: 'home.php?mod=space&do=friend&uid=101&view=trace&page=2&mobile=2',
      scope: ForumFriendFeedScope.footprints,
      page: 2,
    ),
  ];
  for (final policy in [ForumWebViewNavigationPolicy.preferNative]) {
    for (final entry in friendCases) {
      testWidgets(
        'friend callback opens ${entry.scope} page ${entry.page} natively with $policy',
        (tester) async {
          final driver = _FakeForumWebViewDriver();
          final feed = FriendFeedFixture(autoComplete: true);
          await tester.pumpWidget(
            _buildTestApp(
              driver: driver,
              navigationPolicy: policy,
              friendFeed: feed,
            ),
          );
          await tester.pumpAndSettle();

          final decision = await driver.dispatchNavigationRequest(entry.url);
          await tester.pumpAndSettle();

          expect(decision, ForumWebViewNavigationDecision.prevent);
          final page = tester.widget<MyFriendsPage>(find.byType(MyFriendsPage));
          expect(page.initialScope, entry.scope);
          expect(page.initialPage, entry.page);
          final query = feed.requests.single.query;
          expect(query.accountUserId, '101');
          expect(query.scope, entry.scope);
          expect(query.page, entry.page);
          expect(driver.loadedUris, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final purpose in [
    ForumWebViewHostPurpose.selfProfile,
    ForumWebViewHostPurpose.postEditFallback,
  ]) {
    testWidgets('friend callback respects $purpose browser purpose', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final feed = FriendFeedFixture(autoComplete: true);
      await tester.pumpWidget(
        _buildTestApp(driver: driver, friendFeed: feed, hostPurpose: purpose),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'home.php?mod=space&do=friend&mobile=2',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.navigate);
      expect(find.byType(MyFriendsPage, skipOffstage: false), findsNothing);
      expect(find.byType(ForumWebViewPage), findsOneWidget);
      expect(feed.requests, isEmpty);
      expect(driver.loadedUris, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('duplicate friend callbacks push only one native route', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final feed = FriendFeedFixture(autoComplete: true);
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        friendFeed: feed,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();
    const url = 'home.php?mod=space&do=friend&mobile=2';

    final decisions = await Future.wait([
      driver.dispatchNavigationRequest(url),
      driver.dispatchNavigationRequest(url),
    ]);
    await tester.pumpAndSettle();

    expect(decisions, everyElement(ForumWebViewNavigationDecision.prevent));
    expect(find.byType(MyFriendsPage), findsOneWidget);
    expect(feed.requests, hasLength(1));
    Navigator.of(tester.element(find.byType(MyFriendsPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MyFriendsPage, skipOffstage: false), findsNothing);
    expect(find.byType(ForumWebViewPage), findsOneWidget);
    expect(driver.loadedUris, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final boundary in ['background', 'accountExpired']) {
    testWidgets('$boundary browser cannot open a friend feed route', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final feed = FriendFeedFixture(autoComplete: true);
      var accountCurrent = true;
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          friendFeed: feed,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          isAccountCurrent: () => accountCurrent,
        ),
      );
      await tester.pumpAndSettle();
      if (boundary == 'background') {
        unawaited(
          Navigator.of(tester.element(find.byType(ForumWebViewPage)))
              .push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(key: Key('friend-browser-cover')),
                ),
              ),
        );
        await tester.pumpAndSettle();
      } else {
        accountCurrent = false;
      }

      final decision = await driver.dispatchNavigationRequest(
        'home.php?mod=space&do=friend&mobile=2',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.prevent);
      expect(find.byType(MyFriendsPage, skipOffstage: false), findsNothing);
      expect(feed.requests, isEmpty);
      if (boundary == 'background') {
        expect(find.byKey(const Key('friend-browser-cover')), findsOneWidget);
      }
      expect(driver.loadedUris, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final query in [
    'uid=260328',
    'view=all',
    'view=online&type=group',
    'view=visitor&type=member',
    'page=0',
    'uid=101&uid=101',
  ]) {
    testWidgets('unsupported friend callback $query stays in WebView', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final feed = FriendFeedFixture(autoComplete: true);
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          friendFeed: feed,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'home.php?mod=space&do=friend&$query&mobile=2',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.navigate);
      expect(find.byType(MyFriendsPage, skipOffstage: false), findsNothing);
      expect(find.byType(ForumWebViewPage), findsOneWidget);
      expect(feed.requests, isEmpty);
      expect(driver.loadedUris, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final explicitUser in [false, true]) {
    testWidgets(
      'unverified friend callback explicitUser=$explicitUser is owner-safe',
      (tester) async {
        final driver = _FakeForumWebViewDriver();
        final feed = FriendFeedFixture(autoComplete: true);
        await tester.pumpWidget(
          _buildTestApp(
            driver: driver,
            friendFeed: feed,
            profileOwner: null,
            navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          ),
        );
        await tester.pumpAndSettle();

        final decision = await driver.dispatchNavigationRequest(
          'home.php?mod=space&do=friend${explicitUser ? '&uid=101' : ''}&mobile=2',
        );
        await tester.pumpAndSettle();

        if (explicitUser) {
          expect(decision, ForumWebViewNavigationDecision.navigate);
          expect(find.byType(MyFriendsPage, skipOffstage: false), findsNothing);
        } else {
          expect(decision, ForumWebViewNavigationDecision.prevent);
          expect(find.byType(MyFriendsPage), findsOneWidget);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(MyFriendsPage)),
          );
          expect(find.text(l10n.profileFriendsLoginRequired), findsOneWidget);
        }
        expect(feed.requests, isEmpty);
        expect(driver.loadedUris, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final policy in [ForumWebViewNavigationPolicy.preferNative]) {
    for (final type in UserThreadDirectoryType.values) {
      testWidgets(
        'ForumWebViewPage opens user $type directory natively with $policy',
        (tester) async {
          final driver = _FakeForumWebViewDriver();
          final directory = ThreadDirectoryFixture(autoComplete: true);
          final pageNumber = type == UserThreadDirectoryType.replies ? 3 : 1;
          final url = type == UserThreadDirectoryType.replies
              ? 'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&type=reply&page=3&mobile=2'
              : 'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&mobile=2';
          await tester.pumpWidget(
            _buildTestApp(
              driver: driver,
              navigationPolicy: policy,
              threadDirectory: directory,
            ),
          );
          await tester.pumpAndSettle();

          final decision = await driver.dispatchNavigationRequest(url);
          await tester.pumpAndSettle();

          expect(decision, ForumWebViewNavigationDecision.prevent);
          final page = tester.widget<UserThreadPage>(
            find.byType(UserThreadPage),
          );
          expect(page.userId, '260328');
          expect(page.initialType, type);
          expect(page.initialPage, pageNumber);
          final request = directory.requests.single.query;
          expect(request.userId, '260328');
          expect(request.viewerUserId, '101');
          expect(request.type, type);
          expect(request.page, pageNumber);
          expect(driver.loadedUris, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final purpose in [
    ForumWebViewHostPurpose.selfProfile,
    ForumWebViewHostPurpose.postEditFallback,
  ]) {
    testWidgets('directory callback respects $purpose browser purpose', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final directory = ThreadDirectoryFixture(autoComplete: true);
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          threadDirectory: directory,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
          hostPurpose: purpose,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&mobile=2',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.navigate);
      expect(find.byType(UserThreadPage, skipOffstage: false), findsNothing);
      expect(find.byType(ForumWebViewPage), findsOneWidget);
      expect(directory.requests, isEmpty);
      expect(driver.loadedUris, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ForumWebViewPage self directory uses the same native page', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final directory = ThreadDirectoryFixture(autoComplete: true);
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        threadDirectory: directory,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();

    final decision = await driver.dispatchNavigationRequest(
      'home.php?mod=space&uid=101&do=thread&view=me&type=reply&mobile=2',
    );
    await tester.pumpAndSettle();

    expect(decision, ForumWebViewNavigationDecision.prevent);
    final page = tester.widget<UserThreadPage>(find.byType(UserThreadPage));
    expect(page.userId, '101');
    expect(page.initialType, UserThreadDirectoryType.replies);
    expect(directory.requests.single.query.userId, '101');
    expect(driver.loadedUris, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate directory callbacks push only one native route', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final directory = ThreadDirectoryFixture(autoComplete: true);
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        threadDirectory: directory,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();
    const url =
        'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&mobile=2';

    final decisions = await Future.wait([
      driver.dispatchNavigationRequest(url),
      driver.dispatchNavigationRequest(url),
    ]);
    await tester.pumpAndSettle();

    expect(decisions, everyElement(ForumWebViewNavigationDecision.prevent));
    expect(find.byType(UserThreadPage), findsOneWidget);
    expect(directory.requests, hasLength(1));
    Navigator.of(tester.element(find.byType(UserThreadPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(UserThreadPage, skipOffstage: false), findsNothing);
    expect(find.byType(ForumWebViewPage), findsOneWidget);
    expect(driver.loadedUris, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background browser cannot open a user directory route', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final directory = ThreadDirectoryFixture(autoComplete: true);
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        threadDirectory: directory,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(tester.element(find.byType(ForumWebViewPage))).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(key: Key('browser-cover-route')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decision = await driver.dispatchNavigationRequest(
      'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&mobile=2',
    );
    await tester.pumpAndSettle();

    expect(decision, ForumWebViewNavigationDecision.prevent);
    expect(find.byKey(const Key('browser-cover-route')), findsOneWidget);
    expect(find.byType(UserThreadPage, skipOffstage: false), findsNothing);
    expect(directory.requests, isEmpty);
    expect(driver.loadedUris, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired account browser cannot open a user directory route', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final directory = ThreadDirectoryFixture(autoComplete: true);
    var accountCurrent = true;
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        isAccountCurrent: () => accountCurrent,
        threadDirectory: directory,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();
    accountCurrent = false;

    final decision = await driver.dispatchNavigationRequest(
      'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&mobile=2',
    );
    await tester.pumpAndSettle();

    expect(decision, ForumWebViewNavigationDecision.prevent);
    expect(find.byType(UserThreadPage, skipOffstage: false), findsNothing);
    expect(directory.requests, isEmpty);
    expect(driver.loadedUris, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('self directory without view=me keeps its browser semantics', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final directory = ThreadDirectoryFixture(autoComplete: true);
    await tester.pumpWidget(
      _buildTestApp(
        driver: driver,
        threadDirectory: directory,
        navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
      ),
    );
    await tester.pumpAndSettle();

    final decision = await driver.dispatchNavigationRequest(
      'https://bbs.yamibo.com/home.php?mod=space&uid=101&do=thread&mobile=2',
    );
    await tester.pumpAndSettle();

    expect(decision, ForumWebViewNavigationDecision.navigate);
    expect(find.byType(UserThreadPage, skipOffstage: false), findsNothing);
    expect(find.byType(ForumWebViewPage), findsOneWidget);
    expect(directory.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final query in [
    'type=postcomment',
    'type=unknown',
    'view=we',
    'view=all',
    'view=admin',
    'view=eccredit',
  ]) {
    testWidgets('unsupported user directory $query stays in WebView', (
      tester,
    ) async {
      final driver = _FakeForumWebViewDriver();
      final directory = ThreadDirectoryFixture(autoComplete: true);
      await tester.pumpWidget(
        _buildTestApp(
          driver: driver,
          threadDirectory: directory,
          navigationPolicy: ForumWebViewNavigationPolicy.preferNative,
        ),
      );
      await tester.pumpAndSettle();

      final decision = await driver.dispatchNavigationRequest(
        'https://bbs.yamibo.com/home.php?mod=space&uid=260328&do=thread&$query&mobile=2',
      );
      await tester.pumpAndSettle();

      expect(decision, ForumWebViewNavigationDecision.navigate);
      expect(find.byType(UserThreadPage, skipOffstage: false), findsNothing);
      expect(find.byType(ForumWebViewPage), findsOneWidget);
      expect(directory.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
