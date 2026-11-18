part of 'forum_home_page_test.dart';

void _refreshAuthCases() {
  testWidgets('pull to refresh forces forum home network reload', (
    tester,
  ) async {
    var requestCount = 0;
    final refreshCompleter = Completer<ForumHomeReadResult>();
    final repository = _FakeForumHomeRepository(() {
      requestCount += 1;
      if (requestCount == 1) {
        return Future<ForumHomeReadResult>.value(
          forumHomeReadSuccess(_loggedOutPayload()),
        );
      }
      return refreshCompleter.future;
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
    ]);
    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refreshIndicator.onRefresh();
    await tester.pump();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(find.byKey(const Key('forum-home-refresh-progress')), findsNothing);

    refreshCompleter.complete(forumHomeReadSuccess(_loggedOutPayload()));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
    expect(repository.requestProfiles, <DocumentRequestProfile?>[
      DocumentRequestProfile.anonymous,
      DocumentRequestProfile.anonymous,
    ]);
  });

  testWidgets('auth and network pending still render cached home immediately', (
    tester,
  ) async {
    final authRepository = _PendingAuthRepository(
      session: const SessionInfo(
        uid: '0',
        username: '',
        formhash: '',
        isLoggedIn: false,
      ),
    );
    final refreshCompleter = Completer<ForumHomeReadResult>();
    final repository = _FakeForumHomeRepository(
      () => refreshCompleter.future,
      cachedEntry: ForumHomeCacheEntry(
        payload: _loggedOutPayloadNoToday(),
        capabilities: forumHomeTestCapabilities,
        metadata: const DataReadMetadata(
          origin: DataReadOrigin.freshSnapshot,
          freshness: DataReadFreshness.freshCache,
        ),
        updatedAt: DateTime(2026, 6, 29, 11),
      ),
    );
    final container = ProviderContainer(
      overrides: _overrides(
        repository,
        authRepository: authRepository,
        requestProfileResolver: const _FakeForumHomeRequestProfileResolver(
          DocumentRequestProfile.anonymous,
        ),
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(home: ForumHomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(find.byKey(const Key('forum-card-2')), findsOneWidget);
    expect(find.byKey(const Key('forum-home-blank-body')), findsNothing);
    expect(repository.cachedRequestProfiles, <DocumentRequestProfile>[
      DocumentRequestProfile.anonymous,
    ]);
    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.networkFirst,
    ]);
    expect(find.byKey(const Key('forum-home-refresh-progress')), findsNothing);

    authRepository.complete();
    refreshCompleter.complete(forumHomeReadSuccess(_loggedOutPayload()));
    await tester.pumpAndSettle();
  });

  testWidgets('source invalidation discards the old home background refresh', (
    tester,
  ) async {
    final pending = Completer<ForumHomeReadResult>();
    var calls = 0;
    final repository = _FakeForumHomeRepository(
      () => ++calls == 1
          ? pending.future
          : Future.value(
              forumHomeReadSuccess(_loggedOutPayloadWithTodayCount(12)),
            ),
      cachedEntry: ForumHomeCacheEntry(
        payload: _loggedOutPayload(),
        capabilities: forumHomeTestCapabilities,
        metadata: const DataReadMetadata.network(),
        updatedAt: DateTime(2026),
      ),
    );
    var profile = const Y300ForumSourceProfile(id: 'old_fixture', revision: 1);
    final container = ProviderContainer(
      overrides: [
        ..._overrides(repository),
        yamiboForumSourceProfileProvider.overrideWith((ref) => profile),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(home: ForumHomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    final oldScope = container.read(yamiboForumSourceScopeProvider);
    profile = const Y300ForumSourceProfile(id: 'new_fixture', revision: 1);
    container.invalidate(yamiboForumSourceProfileProvider);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(oldScope.isCurrent, isFalse);
    pending.complete(forumHomeReadSuccess(_loggedOutPayloadWithTodayCount(1)));
    await tester.pumpAndSettle();
    final value = container.read(forumHomeControllerProvider).requireValue;
    expect(value.viewData.sections.single.items.single.todayPosts, 12);
    expect(value.isRefreshing, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'exact owner confirmation preserves the home element, another UID hides it',
    (tester) async {
      final auth = _PendingAuthRepository(session: _loggedInSession(uid: '10'));
      final firstRefresh = Completer<ForumHomeReadResult>();
      final nextRefresh = Completer<ForumHomeReadResult>();
      final otherCache = Completer<ForumHomeCacheEntry?>();
      final sessions = YamiboSessionStore();
      var calls = 0;
      final entry = ForumHomeCacheEntry(
        payload: _loggedInPayloadWithFavorites(),
        capabilities: forumHomeTestCapabilities,
        metadata: const DataReadMetadata.network(),
        updatedAt: DateTime(2026),
        cacheAccountId: '10',
      );
      final repository = _FakeForumHomeRepository(
        () => ++calls == 1 ? firstRefresh.future : nextRefresh.future,
        cacheLoader: () async =>
            sessions.readCurrent()?.uid == '20' ? otherCache.future : entry,
      );
      final container = ProviderContainer(
        overrides: [
          ..._overrides(
            repository,
            authRepository: auth,
            requestProfileResolver: const _FakeForumHomeRequestProfileResolver(
              DocumentRequestProfile.loggedIn,
            ),
          ),
          yamiboSessionStoreProvider.overrideWithValue(sessions),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LocalizedTestApp(home: ForumHomePage()),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.element(find.byKey(const Key('forum-home-list')));
      final oldScope = container.read(yamiboForumSourceScopeProvider);
      expect(oldScope.accountId, 'unverified');
      void confirm(String uid) => sessions.saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: uid,
          username: 'fixture',
          formhash: '',
          updatedAt: DateTime.now(),
          source: 'test',
        ),
      );
      confirm('10');
      auth.complete();
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump();
        expect(find.byKey(const Key('forum-home-blank-body')), findsNothing);
        expect(
          tester.element(find.byKey(const Key('forum-home-list'))),
          same(before),
        );
      }
      expect(oldScope.isCurrent, isFalse);
      expect(repository.cachedRequestProfiles, hasLength(1));
      await tester.pump(Duration.zero);
      expect(calls, 2);
      firstRefresh.complete(
        forumHomeReadSuccess(_loggedOutPayloadWithTodayCount(1)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(before),
      );
      nextRefresh.complete(
        forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
      );
      await tester.pumpAndSettle();
      confirm('20');
      await tester.pump();
      await tester.pump();
      // 换号后旧内容必须消失；等待新账号内容时显示公共加载态。
      expect(find.byKey(const Key('forum-home-loading')), findsOneWidget);
      expect(find.byKey(const Key('forum-home-list')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background cache refresh keeps today subtree and applies updated value',
    (tester) async {
      final refreshCompleter = Completer<ForumHomeReadResult>();
      final repository = _FakeForumHomeRepository(
        () => refreshCompleter.future,
        cachedEntry: ForumHomeCacheEntry(
          payload: _loggedOutPayload(),
          capabilities: forumHomeTestCapabilities,
          metadata: const DataReadMetadata(
            origin: DataReadOrigin.freshSnapshot,
            freshness: DataReadFreshness.freshCache,
          ),
          updatedAt: DateTime(2026, 6, 29, 11),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump();

      final beforeElement = tester.element(
        find.byKey(const ValueKey('forum-home-today-badge-filled')),
      );
      expect(find.text('2'), findsOneWidget);

      refreshCompleter.complete(
        forumHomeReadSuccess(_loggedOutPayloadWithTodayCount(8)),
      );
      await tester.pump();

      final afterElement = tester.element(
        find.byKey(const ValueKey('forum-home-today-badge-filled')),
      );
      expect(identical(beforeElement, afterElement), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
    },
  );

  testWidgets('background refresh failure keeps cached content visible', (
    tester,
  ) async {
    final repository = _FakeForumHomeRepository(
      () async => const DataReadFailure(
        kind: DataReadFailureKind.network,
        diagnosticMessage: 'offline',
      ),
      cachedEntry: ForumHomeCacheEntry(
        payload: _loggedOutPayload(),
        capabilities: forumHomeTestCapabilities,
        metadata: const DataReadMetadata(
          origin: DataReadOrigin.freshSnapshot,
          freshness: DataReadFreshness.freshCache,
        ),
        updatedAt: DateTime(2026, 6, 29, 11),
      ),
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(find.byKey(const Key('forum-home-blank-body')), findsNothing);
    expect(find.byKey(const Key('forum-home-retry-button')), findsNothing);
  });

  testWidgets(
    'login transition invalidates cached home and shows a blank body',
    (tester) async {
      final authRepository = _FakeAuthRepository();
      var requestCount = 0;
      final reloadCompleter = Completer<ForumHomeReadResult>();
      final repository = _FakeForumHomeRepository(() {
        requestCount += 1;
        if (requestCount == 1) {
          return Future<ForumHomeReadResult>.value(
            forumHomeReadSuccess(_loggedOutPayload()),
          );
        }
        return reloadCompleter.future;
      });
      final invalidationService =
          _RecordingNativePageCacheInvalidationService();
      final container = ProviderContainer(
        overrides: [
          ..._overrides(repository, authRepository: authRepository),
          nativePageCacheInvalidationServiceProvider.overrideWithValue(
            invalidationService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LocalizedTestApp(home: ForumHomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);

      authRepository.setSession(_loggedInSession());
      await container.read(authSessionControllerProvider.notifier).refresh();
      await tester.pump();

      expect(find.byKey(const Key('forum-home-blank-body')), findsOneWidget);
      expect(find.byKey(const Key('forum-home-list')), findsNothing);

      reloadCompleter.complete(
        forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
      );
      await tester.pumpAndSettle();

      expect(repository.cachePolicies, <CacheLoadPolicy>[
        CacheLoadPolicy.cacheFirst,
        CacheLoadPolicy.cacheFirst,
      ]);
      expect(repository.requestProfiles, <DocumentRequestProfile?>[
        DocumentRequestProfile.anonymous,
        DocumentRequestProfile.loggedIn,
      ]);
      expect(invalidationService.invalidateForumHomeCalls, 1);
      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    },
  );

  testWidgets('account switch invalidates cached home and shows a blank body', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(
      session: _loggedInSession(uid: '10001', username: 'alice'),
    );
    var requestCount = 0;
    final reloadCompleter = Completer<ForumHomeReadResult>();
    final repository = _FakeForumHomeRepository(() {
      requestCount += 1;
      if (requestCount == 1) {
        return Future<ForumHomeReadResult>.value(
          forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
        );
      }
      return reloadCompleter.future;
    });
    final invalidationService = _RecordingNativePageCacheInvalidationService();
    final container = ProviderContainer(
      overrides: [
        ..._overrides(repository, authRepository: authRepository),
        nativePageCacheInvalidationServiceProvider.overrideWithValue(
          invalidationService,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(home: ForumHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);

    authRepository.setSession(_loggedInSession(uid: '20002', username: 'bob'));
    await container.read(authSessionControllerProvider.notifier).refresh();
    await tester.pump();

    expect(find.byKey(const Key('forum-home-blank-body')), findsOneWidget);
    expect(find.byKey(const Key('forum-home-list')), findsNothing);

    reloadCompleter.complete(
      forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
    );
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.cacheFirst,
    ]);
    expect(repository.requestProfiles, <DocumentRequestProfile?>[
      DocumentRequestProfile.loggedIn,
      DocumentRequestProfile.loggedIn,
    ]);
    expect(invalidationService.invalidateForumHomeCalls, 1);
    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
  });
}
