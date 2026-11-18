part of 'user_profile_page_test.dart';

void _selfSessionCases() {
  testWidgets('MyProfilePage uses self view and opens structured blog feed', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository(data: _myProfile);
    final blogRepository = _FakeBlogDirectoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...forumAuthOverrides(const _FakeAuthRepository()),
          forumUserProfileRepositoryProvider.overrideWithValue(
            profileRepository,
          ),
          userBlogDirectoryRepositoryProvider.overrideWithValue(blogRepository),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: const LocalizedTestApp(home: MyProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(profileRepository.queries.single.view, ForumUserProfileView.self);
    expect(profileRepository.queries.single.userId, '654321');
    expect(profileRepository.policies.single, CacheLoadPolicy.networkFirst);
    expect(find.text('我的资料'), findsWidgets);
    expect(find.byKey(const Key('user-profile-actions')), findsOneWidget);
    expect(find.text('我的日志'), findsOneWidget);
    expect(find.text('消息提醒'), findsOneWidget);
    expect(find.text('论坛收藏'), findsNothing);
    expect(find.byKey(const Key('user-profile-action-settings')), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byKey(const Key('daily-sign-in-panel')), findsNothing);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(MyProfilePage)))
          .exists(dailySignInControllerProvider),
      isFalse,
    );

    await _reveal(tester, find.byKey(const Key('user-profile-action-blogs')));
    await tester.tap(find.text('我的日志'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-blog-list')), findsOneWidget);
    expect(find.text('还没有相关的日志'), findsOneWidget);
    expect(blogRepository.queries.single.scope, UserBlogFeedScope.self);
    expect(blogRepository.queries.single.order, isNull);
  });

  testWidgets('MyProfilePage opens the structured message center', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...forumAuthOverrides(const _FakeAuthRepository()),
          forumUserProfileRepositoryProvider.overrideWithValue(
            _FakeProfileRepository(data: _myProfile),
          ),
          messageRepositoryProvider.overrideWithValue(
            _EmptyMessageRepository(),
          ),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: const LocalizedTestApp(home: MyProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    await _reveal(
      tester,
      find.byKey(const Key('user-profile-action-messages')),
    );
    await tester.tap(find.text('消息提醒'));
    await tester.pumpAndSettle();

    expect(find.byType(MessageCenterPage), findsOneWidget);
  });

  testWidgets('MyProfilePage hides data as soon as the session is cleared', (
    tester,
  ) async {
    final store = YamiboSessionStore()..saveExtracted(_sessionFor('654321'));
    final opened = <ForumWebViewLaunchConfig>[];
    await _pumpMyProfile(
      tester,
      repository: _FakeProfileRepository(data: _allActionsProfile),
      store: store,
      routeFactory: (config) {
        opened.add(config);
        return MaterialPageRoute<Object?>(builder: (_) => const SizedBox());
      },
    );
    expect(find.text('sample-member'), findsOneWidget);
    final openSettings = tester
        .widget<IconButton>(
          find.byKey(const Key('user-profile-action-settings')),
        )
        .onPressed!;

    store.clear();
    await tester.pumpAndSettle();
    openSettings();
    await tester.pumpAndSettle();

    expect(find.text('sample-member'), findsNothing);
    expect(find.byKey(const Key('user-profile-action-settings')), findsNothing);
    expect(opened, isEmpty);
    expect(find.byKey(const Key('daily-sign-in-panel')), findsNothing);
    expect(find.byKey(const Key('my-profile-open-forum-page')), findsNothing);
    expect(
      find.text(_profileL10n(tester).profileLoginRequired),
      findsOneWidget,
    );
    expect(find.byKey(const Key('user-profile-actions')), findsNothing);
  });

  testWidgets('MyProfilePage does not query a mismatched session owner', (
    tester,
  ) async {
    final store = YamiboSessionStore()..saveExtracted(_sessionFor('777777'));
    final repository = _FakeProfileRepository(data: _allActionsProfile);
    await _pumpMyProfile(tester, repository: repository, store: store);

    expect(
      find.text(_profileL10n(tester).profileLoginRequired),
      findsOneWidget,
    );
    expect(repository.queries, isEmpty);
    expect(find.byKey(const Key('user-profile-action-settings')), findsNothing);
  });

  for (final oldResultFails in [false, true]) {
    testWidgets(
      'MyProfilePage rejects late old-owner ${oldResultFails ? 'network failure' : 'success'}',
      (tester) async {
        final store = YamiboSessionStore()
          ..saveExtracted(_sessionFor('654321'));
        final oldRefresh = Completer<_ProfileReadResult>();
        final repository = _ScriptedProfileRepository((query, call) {
          if (call == 1) return oldRefresh.future;
          return Future.value(
            _profileSuccess(
              query.userId == '654321'
                  ? _myProfile
                  : _selfProfile('777777', 'second-member'),
            ),
          );
        });
        await _pumpMyProfile(tester, repository: repository, store: store);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MyProfilePage)),
        );
        unawaited(container.read(myUserProfileProvider.notifier).refresh());
        await tester.pump();
        expect(
          find.byKey(const Key('user-profile-refresh-progress')),
          findsOneWidget,
        );

        store.saveExtracted(_sessionFor('777777'));
        container
            .read(authSessionControllerProvider.notifier)
            .acceptSession(
              const ForumSessionIdentity(
                userId: '777777',
                username: 'second-member',
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('sample-member'), findsNothing);
        expect(find.text('second-member'), findsOneWidget);

        oldRefresh.complete(
          oldResultFails
              ? const DataReadFailure(
                  kind: DataReadFailureKind.network,
                  diagnosticMessage: 'old owner failure',
                )
              : _profileSuccess(_myProfile),
        );
        await tester.pumpAndSettle();
        expect(find.text('second-member'), findsOneWidget);
        expect(find.text('sample-member'), findsNothing);
        expect(
          find.byKey(const Key('my-profile-open-forum-page')),
          findsNothing,
        );
        expect(repository.queries.last.userId, '777777');
        expect(find.byType(SnackBar), findsNothing);
        final l10n = _profileL10n(tester);
        expect(
          find.text(l10n.profileLoadFailed(l10n.commonNetworkError)),
          findsNothing,
        );
      },
    );
  }
  testWidgets('same UID signing in again has a fresh profile owner', (
    tester,
  ) async {
    final store = YamiboSessionStore()..saveExtracted(_sessionFor('654321'));
    final newSession = Completer<_ProfileReadResult>();
    final opened = <ForumWebViewLaunchConfig>[];
    final repository = _ScriptedProfileRepository((query, call) {
      if (call == 0) return Future.value(_profileSuccess(_allActionsProfile));
      return newSession.future;
    });
    await _pumpMyProfile(
      tester,
      repository: repository,
      store: store,
      routeFactory: (config) {
        opened.add(config);
        return MaterialPageRoute<Object?>(builder: (_) => const SizedBox());
      },
    );
    expect(find.text('sample-member'), findsOneWidget);
    final openOldSettings = tester
        .widget<IconButton>(
          find.byKey(const Key('user-profile-action-settings')),
        )
        .onPressed!;

    store.clear();
    store.saveExtracted(_sessionFor('654321'));
    await tester.pump();
    expect(find.text('sample-member'), findsNothing);
    expect(find.byKey(const Key('user-profile-action-settings')), findsNothing);
    expect(
      find.byKey(const Key('user-profile-identity-skeleton')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('user-profile-name')), findsNothing);
    expect(find.byKey(const Key('user-profile-avatar')), findsNothing);
    expect(find.byKey(const Key('user-profile-copy-uid')), findsNothing);
    expect(find.byKey(const Key('user-profile-actions')), findsNothing);

    newSession.complete(_profileSuccess(_selfProfile('654321', 'new-session')));
    await tester.pumpAndSettle();
    openOldSettings();
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('new-session'), findsOneWidget);
    expect(repository.queries.length, greaterThanOrEqualTo(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyProfilePage)),
    );
    expect(
      container.read(myUserProfileProvider).asData!.value.ownerRevision,
      container.read(verifiedSessionOwnerProvider)!.revision,
    );
    expect(
      repository.cancellations
          .skip(1)
          .take(repository.queries.length - 2)
          .every((cancellation) => cancellation!.isCancelled),
      isTrue,
    );
  });

  testWidgets('MyProfilePage retains content on network refresh failure', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(
      data: _myProfile,
      failAfterSuccess: true,
    );
    await _pumpMyProfile(tester, repository: repository);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyProfilePage)),
    );
    await container.read(myUserProfileProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('sample-member'), findsOneWidget);
    expect(find.textContaining('网络连接失败'), findsOneWidget);
    expect(repository.policies, <CacheLoadPolicy>[
      CacheLoadPolicy.networkFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('MyProfilePage clears content on unauthorized refresh', (
    tester,
  ) async {
    final repository = _ScriptedProfileRepository((query, call) async {
      if (call == 0) return _profileSuccess(_myProfile);
      return const DataReadFailure(
        kind: DataReadFailureKind.unauthorized,
        diagnosticMessage: 'auth_required',
      );
    });
    await _pumpMyProfile(tester, repository: repository);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyProfilePage)),
    );
    await container.read(myUserProfileProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('sample-member'), findsNothing);
    expect(find.byKey(const Key('user-profile-actions')), findsNothing);
    expect(
      find.text(_profileL10n(tester).profileLoginRequired),
      findsOneWidget,
    );
    expect(find.byKey(const Key('my-profile-open-forum-page')), findsNothing);
  });

  for (final failureKind in <DataReadFailureKind>[
    DataReadFailureKind.parse,
    DataReadFailureKind.unsupported,
  ]) {
    testWidgets('MyProfilePage offers explicit fallback for $failureKind', (
      tester,
    ) async {
      final opened = <ForumWebViewLaunchConfig>[];
      final repository = _ScriptedProfileRepository(
        (query, call) async => DataReadFailure(
          kind: failureKind,
          diagnosticMessage: 'synthetic_profile_failure',
        ),
      );
      await _pumpMyProfile(
        tester,
        repository: repository,
        routeFactory: (config) {
          opened.add(config);
          return MaterialPageRoute<Object?>(
            builder: (_) => const Scaffold(body: Text('managed destination')),
          );
        },
      );

      final fallback = find.byKey(const Key('my-profile-open-forum-page'));
      expect(fallback, findsOneWidget);
      expect(
        find.text(_profileL10n(tester).profileOpenForumPage),
        findsOneWidget,
      );
      expect(opened, isEmpty);

      await tester.tap(fallback);
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single.popOnRootBack, isTrue);
      expect(
        opened.single.initialUri.toString(),
        'https://bbs.yamibo.com/home.php?mod=space&uid=654321&do=profile&mycenter=1&mobile=2',
      );
    });
  }

  for (final failureKind in <DataReadFailureKind>[
    DataReadFailureKind.unauthorized,
    DataReadFailureKind.network,
    DataReadFailureKind.timeout,
  ]) {
    testWidgets('MyProfilePage omits forum fallback for $failureKind', (
      tester,
    ) async {
      await _pumpMyProfile(
        tester,
        repository: _ScriptedProfileRepository(
          (query, call) async => DataReadFailure(
            kind: failureKind,
            diagnosticMessage: 'synthetic_profile_failure',
          ),
        ),
      );

      expect(find.byKey(const Key('my-profile-open-forum-page')), findsNothing);
    });
  }

  testWidgets('MyProfilePage fallback follows only the new verified owner', (
    tester,
  ) async {
    final store = YamiboSessionStore()..saveExtracted(_sessionFor('654321'));
    final oldRefresh = Completer<_ProfileReadResult>();
    final opened = <ForumWebViewLaunchConfig>[];
    final repository = _ScriptedProfileRepository((query, call) {
      if (call == 1) return oldRefresh.future;
      return Future.value(
        const DataReadFailure(
          kind: DataReadFailureKind.parse,
          diagnosticMessage: 'synthetic_profile_failure',
        ),
      );
    });
    await _pumpMyProfile(
      tester,
      repository: repository,
      store: store,
      routeFactory: (config) {
        opened.add(config);
        return MaterialPageRoute<Object?>(
          builder: (_) => const Scaffold(body: Text('managed destination')),
        );
      },
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyProfilePage)),
    );
    unawaited(container.read(myUserProfileProvider.notifier).refresh());
    await tester.pump();

    store.saveExtracted(_sessionFor('777777'));
    container
        .read(authSessionControllerProvider.notifier)
        .acceptSession(
          const ForumSessionIdentity(
            userId: '777777',
            username: 'second-member',
          ),
        );
    await tester.pumpAndSettle();
    expect(repository.queries.last.userId, '777777');

    oldRefresh.complete(
      const DataReadFailure(
        kind: DataReadFailureKind.parse,
        diagnosticMessage: 'old_owner_failure',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-profile-open-forum-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('my-profile-open-forum-page')));
    await tester.pumpAndSettle();

    expect(opened.single.initialUri.queryParameters['uid'], '777777');
  });
}
