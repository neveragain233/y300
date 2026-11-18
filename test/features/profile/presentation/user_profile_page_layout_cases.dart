part of 'user_profile_page_test.dart';

void _layoutCases() {
  testWidgets('MyProfilePage fallback fits 300dp with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...forumAuthOverrides(const _FakeAuthRepository()),
          forumUserProfileRepositoryProvider.overrideWithValue(
            _ScriptedProfileRepository(
              (query, call) async => const DataReadFailure(
                kind: DataReadFailureKind.parse,
                diagnosticMessage: 'synthetic_profile_failure',
              ),
            ),
          ),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: LocalizedTestApp(home: MyProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('my-profile-open-forum-page')), findsOneWidget);
  });

  testWidgets('MyProfilePage can retry an unexpected initial read failure', (
    tester,
  ) async {
    final repository = _ScriptedProfileRepository((query, call) async {
      if (call == 0) throw StateError('synthetic failure');
      return _profileSuccess(_myProfile);
    });
    await _pumpMyProfile(tester, repository: repository);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('sample-member'), findsNothing);
    expect(find.byKey(const Key('daily-sign-in-panel')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyProfilePage)),
    );
    expect(container.exists(dailySignInControllerProvider), isFalse);

    await tester.tap(find.text(_profileL10n(tester).commonRetry));
    await tester.pumpAndSettle();

    expect(find.text('sample-member'), findsOneWidget);
    expect(repository.queries.length, 2);
    expect(find.byKey(const Key('daily-sign-in-panel')), findsNothing);
    expect(container.exists(dailySignInControllerProvider), isFalse);
  });

  testWidgets('MyProfilePage shows an empty hint for UID-only details', (
    tester,
  ) async {
    await _pumpMyProfile(
      tester,
      repository: _FakeProfileRepository(
        data: const ForumUserProfileData(
          identity: ProfileUserIdentity(userId: '654321'),
          metrics: <ForumUserProfileMetric>[],
          details: <ForumUserProfileDetail>[
            ForumUserProfileDetail(label: 'UID', value: '654321'),
          ],
        ),
      ),
    );

    expect(
      find.text(_profileL10n(tester).profileNoAdditionalDetails),
      findsOneWidget,
    );
    expect(find.byKey(const Key('user-profile-actions')), findsNothing);
  });

  testWidgets('MyProfilePage opens its native topic directory', (tester) async {
    final directory = _ProfileThreadDirectoryRepository();
    await _pumpMyProfile(
      tester,
      repository: _FakeProfileRepository(data: _allActionsProfile),
      threadDirectory: directory,
    );
    final entry = find.byKey(const Key('user-profile-action-threads'));
    await _reveal(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(MyThreadPage), findsOneWidget);
    expect(directory.queries.single.userId, '654321');
    expect(directory.queries.single.type, UserThreadDirectoryType.threads);
  });

  for (final locale in [const Locale('zh'), const Locale('zh', 'TW')]) {
    testWidgets(
      'MyProfilePage labels and opens the self friends action for $locale',
      (tester) async {
        final directory = FriendFeedFixture(autoComplete: true);
        await _pumpMyProfile(
          tester,
          repository: _FakeProfileRepository(data: _allActionsProfile),
          friendDirectory: directory,
          locale: locale,
        );
        expect(directory.requests, isEmpty);
        final entry = find.byKey(const Key('user-profile-action-friends'));
        await _reveal(tester, entry);
        final l10n = _profileL10n(tester);
        expect(
          find.descendant(
            of: entry,
            matching: find.text(l10n.profileMyFriendsTitle),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: entry, matching: find.text(l10n.profileFriends)),
          findsNothing,
        );
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(MyFriendsPage), findsOneWidget);
        expect(directory.requests.single.query.accountUserId, '654321');
        expect(
          directory.requests.single.query.scope,
          ForumFriendFeedScope.friends,
        );
        expect(
          find.byType(ForumWebViewPage, skipOffstage: false),
          findsNothing,
        );
        Navigator.of(tester.element(find.byType(MyFriendsPage))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(MyProfilePage), findsOneWidget);
        expect(directory.requests, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('MyProfilePage opens advertised managed WebView action targets', (
    tester,
  ) async {
    final opened = <ForumWebViewLaunchConfig>[];
    final repository = _FakeProfileRepository(data: _allActionsProfile);
    await _pumpMyProfile(
      tester,
      repository: repository,
      routeFactory: (config) {
        opened.add(config);
        return MaterialPageRoute<Object?>(
          builder: (_) => Scaffold(
            appBar: AppBar(),
            body: const Text('managed destination'),
          ),
        );
      },
    );

    final settings = find.byKey(const Key('user-profile-action-settings'));
    expect(settings, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppPageAppBar), matching: settings),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('user-profile-page-list')),
        matching: settings,
      ),
      findsNothing,
    );
    expect(
      tester.widget<IconButton>(settings).tooltip,
      _profileL10n(tester).profileSettings,
    );
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byKey(const Key('user-profile-open-web')), findsOneWidget);

    const targets = <ForumUserProfileActionKind>[
      ForumUserProfileActionKind.forumFavorites,
      ForumUserProfileActionKind.settings,
      ForumUserProfileActionKind.creditHistory,
    ];
    for (final kind in targets) {
      await _reveal(
        tester,
        find.byKey(Key('user-profile-action-${kind.name}')),
      );
      await tester.tap(find.byKey(Key('user-profile-action-${kind.name}')));
      await tester.pumpAndSettle();
      expect(opened.last.initialUri.host, 'bbs.yamibo.com');
      expect(opened.last.initialUri.path, '/home.php');
      expect(
        opened.last.initialUri,
        _allActionsProfile.actionLinks
            .singleWhere((link) => link.kind == kind)
            .uri,
      );
      expect(opened.last.popOnRootBack, isTrue);
      expect(opened.last.expectedAccountId, '654321');
      expect(
        opened.last.initialUri.queryParameters['uid'],
        kind == ForumUserProfileActionKind.forumFavorites ? '654321' : null,
      );
      Navigator.of(tester.element(find.text('managed destination'))).pop();
      await tester.pumpAndSettle();
    }
    expect(
      opened.map((config) => config.initialUri.queryParameters),
      <Map<String, String>>[
        {
          'mod': 'space',
          'uid': '654321',
          'do': 'favorite',
          'view': 'me',
          'type': 'thread',
        },
        {'mod': 'spacecp', 'ac': 'profile'},
        {'mod': 'spacecp', 'ac': 'credit', 'op': 'log'},
      ],
    );
    expect(repository.queries, hasLength(targets.length + 1));
    expect(
      repository.policies.every(
        (policy) => policy == CacheLoadPolicy.networkFirst,
      ),
      isTrue,
    );
  });

  testWidgets('MyProfilePage hides actions without the actions capability', (
    tester,
  ) async {
    await _pumpMyProfile(
      tester,
      repository: _FakeProfileRepository(
        data: _allActionsProfile,
        capabilities: _profileCapabilities(
          supported: ForumUserProfileCapability.values.where(
            (capability) =>
                capability != ForumUserProfileCapability.orderedActions,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('user-profile-actions')), findsNothing);
    expect(find.byKey(const Key('user-profile-action-settings')), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('MyProfilePage actions fit 300dp at enlarged text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...forumAuthOverrides(const _FakeAuthRepository()),
          forumUserProfileRepositoryProvider.overrideWithValue(
            _FakeProfileRepository(data: _allActionsProfile),
          ),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: LocalizedTestApp(home: MyProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _reveal(
      tester,
      find.byKey(const Key('user-profile-action-creditHistory')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('user-profile-actions')), findsOneWidget);
  });

  testWidgets('profile layout remains usable at 300dp with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '654321',
            revision: 0,
          )),
          forumUserProfileRepositoryProvider.overrideWithValue(
            _FakeProfileRepository(),
          ),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: LocalizedTestApp(home: UserProfilePage(uid: '123456')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('user-profile-page-list')), findsOneWidget);
  });
}
