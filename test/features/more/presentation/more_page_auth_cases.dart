part of 'more_page_test.dart';

void _authCases() {
  testWidgets('MorePage login entry navigates to the WebView login page', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(isLoggedIn: false);
    final routeObserver = _RouteNameObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(repository),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: LocalizedTestApp(
          home: const MorePage(),
          navigatorObservers: [routeObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final login = tester
        .widget<TextButton>(find.byKey(const Key('more-login-entry')))
        .onPressed!;
    login();
    login();
    // 不 pump 目标页：Navigator.push 会同步通知 observer.didPush 记录路由名，
    // 而目标页（含真实 InAppWebView 平台视图）的 build 被推迟到下一帧。此处
    // 只断言“入栈了正确的登录路由”，避免在纯 widget 测试环境构建平台视图。
    // 登录检测/校验逻辑已由 resolver 单测覆盖。

    expect(routeObserver.pushedNames, contains(LoginWebViewPage.routeName));
    expect(
      routeObserver.pushedNames.where(
        (name) => name == LoginWebViewPage.routeName,
      ),
      hasLength(1),
    );
  });

  testWidgets('account avatar opens the current account after login', (
    tester,
  ) async {
    final routeObserver = _RouteNameObserver();
    final profileRepository = _SignedProfileRepository();
    final webLaunches = <ForumWebViewLaunchConfig>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),
          forumWebViewRouteFactoryProvider.overrideWithValue(
            _profileWebRoutes(webLaunches),
          ),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
          forumUserProfileRepositoryProvider.overrideWithValue(
            profileRepository,
          ),
          dailySignInRepositoryProvider.overrideWithValue(
            _SignedDailySignInRepository(),
          ),
        ],
        child: LocalizedTestApp(
          home: const MorePage(),
          navigatorObservers: [routeObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MorePage)),
    );

    await tester.tap(find.byKey(const Key('more-login-entry')));
    expect(routeObserver.pushedNames.last, LoginWebViewPage.routeName);

    // LoginWebViewPage verifies the session before returning true. Simulate
    // that handoff without constructing a platform WebView in this widget test.
    container
        .read(authSessionControllerProvider.notifier)
        .acceptSession(
          const ForumSessionIdentity(userId: '200', username: 'next-account'),
        );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop(true);
    await tester.pumpAndSettle();

    expect(find.byType(MyProfilePage), findsNothing);
    await tester.tap(find.byKey(const Key('more-account-avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(MyProfilePage), findsOneWidget);
    expect(find.byKey(const Key('test-profile-webview')), findsNothing);
    expect(profileRepository.queries.single.userId, '200');
    expect(profileRepository.queries.single.view, ForumUserProfileView.self);
    expect(webLaunches, isEmpty);
  });

  testWidgets('account avatar stays disabled when login is cancelled', (
    tester,
  ) async {
    final routeObserver = _RouteNameObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: LocalizedTestApp(
          home: const MorePage(),
          navigatorObservers: [routeObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more-login-entry')));
    expect(routeObserver.pushedNames.last, LoginWebViewPage.routeName);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop(false);
    await tester.pumpAndSettle();

    expect(find.byType(MorePage), findsOneWidget);
    expect(find.byType(MyProfilePage), findsNothing);
    expect(routeObserver.pushedNames.length, 2);
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('more-account-avatar')))
          .onTap,
      isNull,
    );
  });

  testWidgets('account avatar ignores duplicate taps while navigating', (
    tester,
  ) async {
    final routeObserver = _RouteNameObserver();
    final webLaunches = <ForumWebViewLaunchConfig>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: true)),
          forumWebViewRouteFactoryProvider.overrideWithValue(
            _profileWebRoutes(webLaunches),
          ),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
          forumUserProfileRepositoryProvider.overrideWithValue(
            _SignedProfileRepository(),
          ),
          dailySignInRepositoryProvider.overrideWithValue(
            _SignedDailySignInRepository(),
          ),
        ],
        child: LocalizedTestApp(
          home: const MorePage(),
          navigatorObservers: [routeObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tap = tester
        .widget<InkWell>(find.byKey(const Key('more-account-avatar')))
        .onTap!;
    tap();
    tap();
    await tester.pumpAndSettle();

    expect(find.byType(MyProfilePage), findsOneWidget);
    expect(find.byKey(const Key('test-profile-webview')), findsNothing);
    expect(webLaunches, isEmpty);
    expect(routeObserver.pushedNames.length, 2);
  });

  testWidgets(
    'unused images entry resumes navigation after WebView login succeeds',
    (tester) async {
      final routeObserver = _RouteNameObserver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

            appAppearanceControllerProvider.overrideWith(
              () => _FakeAppAppearanceController(),
            ),
            composerUnusedImageManagementControllerProvider.overrideWith(
              _FakeUnusedImagesController.new,
            ),
          ],
          child: LocalizedTestApp(
            home: const MorePage(),
            navigatorObservers: [routeObserver],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('more-unused-images-entry')));
      expect(routeObserver.pushedNames.last, LoginWebViewPage.routeName);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop(true);
      await tester.pump();
      await tester.pump();

      expect(
        routeObserver.pushedNames,
        contains(ComposerUnusedImageManagementPage.routeName),
      );
      expect(find.byType(ComposerUnusedImageManagementPage), findsOneWidget);
    },
  );

  testWidgets('unused images entry stays on More after login is cancelled', (
    tester,
  ) async {
    final routeObserver = _RouteNameObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
          composerUnusedImageManagementControllerProvider.overrideWith(
            _FakeUnusedImagesController.new,
          ),
        ],
        child: LocalizedTestApp(
          home: const MorePage(),
          navigatorObservers: [routeObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more-unused-images-entry')));
    tester.state<NavigatorState>(find.byType(Navigator).first).pop(false);
    await tester.pumpAndSettle();

    expect(find.byType(MorePage), findsOneWidget);
    expect(find.byType(ComposerUnusedImageManagementPage), findsNothing);
    expect(
      routeObserver.pushedNames
          .where((name) => name == ComposerUnusedImageManagementPage.routeName)
          .length,
      0,
    );
  });
}
