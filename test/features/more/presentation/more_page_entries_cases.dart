part of 'more_page_test.dart';

void _entriesCases() {
  testWidgets('MorePage builds dark theme chrome', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: LocalizedTestApp(theme: AppTheme.dark(), home: const MorePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    final login = tester.widget<TextButton>(
      find.byKey(const Key('more-login-entry')),
    );
    expect(
      login.style?.foregroundColor?.resolve({}),
      AppTheme.dark().colorScheme.onSurface,
    );
    await _scrollUntilVisibleIfNeeded(
      tester,
      find.byKey(const Key('more-settings-entry')),
    );
    expect(find.byKey(const Key('more-settings-entry')), findsOneWidget);
    expect(find.byKey(const Key('more-appearance-entry')), findsNothing);
    expect(find.byKey(const Key('more-data-storage-entry')), findsNothing);
  });

  testWidgets('MorePage renders entries without descriptions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: const LocalizedTestApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        AppLocalizations.of(tester.element(find.byType(MorePage)))
            .appNavigationMy,
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('more-login-entry')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const Key('more-login-entry')),
      ),
      findsOneWidget,
    );
    expect(find.text('登录'), findsOneWidget);
    expect(find.byKey(const Key('more-my-profile-entry')), findsNothing);
    expect(find.byKey(const Key('more-daily-sign-in-entry')), findsNothing);
    expect(find.byKey(const Key('more-unused-images-entry')), findsOneWidget);
    expect(find.text('未使用图片管理'), findsOneWidget);
    expect(find.byKey(const Key('more-forum-mode-entry')), findsNothing);
    expect(find.byKey(const Key('more-cache-settings-entry')), findsNothing);
    expect(find.byKey(const Key('more-settings-entry')), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(MorePage)));
    await _expectMyContentEntryOrderAndLabels(tester, l10n);
    expect(find.text(l10n.moreMyProfile), findsNothing);
    expect(find.text(l10n.moreMyProfileSignedOutSubtitle), findsNothing);
    expect(find.text(l10n.moreUnusedImagesSubtitle), findsNothing);
    expect(find.text(l10n.moreVisibleNavigationCount(5)), findsNothing);
    await _scrollUntilVisibleIfNeeded(
      tester,
      find.byKey(const Key('more-download-queue-entry')),
    );
    expect(find.byKey(const Key('more-download-queue-entry')), findsOneWidget);
    expect(find.text('缓存队列'), findsOneWidget);
    expect(find.text(l10n.moreDownloadEmpty), findsNothing);
    expect(find.byIcon(Icons.offline_pin_outlined), findsOneWidget);
    expect(find.byKey(const Key('about-check-update-entry')), findsNothing);
    expect(
      find.byKey(const Key('more-reader-settings-placeholder')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('more-thread-detail-diagnostic-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('more-thread-detail-diagnostic-copy-entry')),
      findsNothing,
    );
  });

  testWidgets('settings entry opens the migrated settings page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),
          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: const LocalizedTestApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();

    final settingsEntry = find.byKey(const Key('more-settings-entry'));
    await _scrollUntilVisibleIfNeeded(tester, settingsEntry);
    await tester.tap(settingsEntry);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(SettingsPage)));
    Future<void> expectVisible(Finder finder) async {
      await _scrollUntilVisibleIfNeeded(tester, finder);
      expect(finder, findsOneWidget);
    }

    await expectVisible(find.text(l10n.settingsSectionAppearanceNavigation));
    await expectVisible(find.byKey(const Key('more-appearance-entry')));
    expect(
      find.descendant(
        of: find.byKey(const Key('more-appearance-entry')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    await expectVisible(
      find.byKey(const Key('more-navigation-management-entry')),
    );
    await expectVisible(find.text(l10n.settingsSectionBrowsingPosts));
    await expectVisible(find.byKey(const Key('more-content-filter-entry')));
    await expectVisible(find.byKey(const Key('more-thread-controls-entry')));
    await expectVisible(find.text(l10n.settingsSectionStorageAbout));
    await expectVisible(find.byKey(const Key('more-data-storage-entry')));
    expect(
      find.descendant(
        of: find.byKey(const Key('more-data-storage-entry')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    await expectVisible(find.byKey(const Key('more-about-entry')));
    await expectVisible(find.text(l10n.settingsSectionDebug));
    await expectVisible(
      find.byKey(const Key('more-composer-quill-prototype-entry')),
    );
    await expectVisible(
      find.byKey(const Key('more-html-renderer-prototype-entry')),
    );
    expect(find.text(l10n.moreAboutSubtitle), findsNothing);

    await tester.tap(find.byKey(const Key('more-about-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MorePage cache queue entry supports large Traditional text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: const LocalizedTestApp(
          locale: Locale('zh', 'TW'),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.6),
            ),
            child: MorePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _expectMyContentEntryOrderAndLabels(
      tester,
      AppLocalizations.of(tester.element(find.byType(MorePage))),
    );
    await _scrollUntilVisibleIfNeeded(tester, find.text('快取佇列'));
    expect(find.text('快取佇列'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(MorePage)));
    expect(find.text(l10n.moreDownloadEmpty), findsNothing);
    expect(find.byIcon(Icons.offline_pin_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MorePage opens the HTML renderer prototype in debug builds', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
        ],
        child: const LocalizedTestApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();

    final settingsEntry = find.byKey(const Key('more-settings-entry'));
    await _scrollUntilVisibleIfNeeded(tester, settingsEntry);
    await tester.tap(settingsEntry);
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('more-html-renderer-prototype-entry'));
    await _scrollUntilVisibleIfNeeded(tester, entry);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ForumHtmlRendererPrototypePage), findsOneWidget);
    expect(find.text('HTML 正文渲染原型'), findsWidgets);
  });

  testWidgets('MorePage renders logout entry when signed in', (tester) async {
    final repository = _FakeAuthRepository(isLoggedIn: true);
    final profileRepository = _SignedProfileRepository();
    final signInRepository = _SignedDailySignInRepository();
    final webLaunches = <ForumWebViewLaunchConfig>[];
    final summaryRepository = _AccountSummaryRepository(
      () => const CurrentUserProfileData(
        identity: ProfileUserIdentity(userId: '100', displayName: 'tester'),
        groupName: '普通会员',
        creditTotal: 42,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._moreAuthOverrides(
            repository,
            summaryRepository: summaryRepository,
          ),
          dailySignInRepositoryProvider.overrideWithValue(signInRepository),
          forumWebViewRouteFactoryProvider.overrideWithValue(
            _profileWebRoutes(webLaunches),
          ),
          forumUserProfileRepositoryProvider.overrideWithValue(
            profileRepository,
          ),

          appAppearanceControllerProvider.overrideWith(
            () => _FakeAppAppearanceController(),
          ),
          webViewCookieSyncServiceProvider.overrideWithValue(
            _FakeWebViewCookieSyncService(),
          ),
        ],
        child: const LocalizedTestApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MorePage)));
    expect(find.byKey(const Key('more-login-entry')), findsNothing);
    expect(find.byKey(const Key('more-logout-entry')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const Key('more-logout-entry')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('more-my-profile-entry')), findsNothing);
    expect(find.text(l10n.moreLogout), findsNothing);
    expect(find.byTooltip(l10n.moreLogout), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('more-logout-entry')))
          .onPressed,
      isNotNull,
    );
    expect(find.text('tester'), findsOneWidget);
    expect(find.text('普通会员'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('more-account-credits')),
        matching: find.byWidgetPredicate(
          (widget) => widget is AnimatedFlipCounter && widget.value == 42,
        ),
      ),
      findsOneWidget,
    );
    expect(summaryRepository.reads, 1);

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('more-page-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(summaryRepository.reads, 1);

    expect(find.byKey(const Key('more-daily-sign-in-entry')), findsNothing);
    expect(find.byKey(const Key('daily-auto-sign-in-toggle')), findsOneWidget);
    expect(signInRepository.reads, 0);

    await tester.tap(find.byKey(const Key('more-account-name')));
    await tester.pumpAndSettle();

    expect(find.byType(MyProfilePage), findsOneWidget);
    expect(find.byKey(const Key('test-profile-webview')), findsNothing);
    expect(profileRepository.queries.single.userId, '100');
    expect(profileRepository.queries.single.view, ForumUserProfileView.self);
    expect(profileRepository.queries.single.viewerUserId, '100');
    expect(webLaunches, isEmpty);

    Navigator.of(tester.element(find.byType(MyProfilePage))).pop();
    await tester.pumpAndSettle();
    expect(summaryRepository.reads, 2);

    await tester.drag(
      find.byKey(const Key('more-page-list')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(summaryRepository.reads, 3);

    // Cancelling the existing confirmation leaves the current account intact.
    await tester.tap(find.byKey(const Key('more-logout-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(repository.logoutCount, 0);
    expect(find.text('tester'), findsOneWidget);

    await tester.tap(find.byKey(const Key('more-logout-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more-logout-confirm-button')));
    await tester.pumpAndSettle();

    expect(repository.logoutCount, 1);
    expect(find.byKey(const Key('more-login-entry')), findsOneWidget);
    expect(find.text('已退出登录'), findsOneWidget);
    expect(find.byKey(const Key('more-account-group')), findsNothing);
    expect(find.byKey(const Key('more-account-credits')), findsNothing);
  });
}
