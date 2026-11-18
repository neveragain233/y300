part of 'main_shell_page_test.dart';

void _sessionCases() {
  testWidgets(
    'MainShellPage notification permission wiring does not block shell build',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final notificationService = _FakeLibraryTaskNotificationService(
        initialPermission: LibraryTaskNotificationPermissionState.denied,
      );
      final webViewDriver = _FakeForumWebViewDriver();
      addTearDown(queueSnapshot.dispose);
      addTearDown(notificationService.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            localFavoriteRepositoryProvider.overrideWith(
              (ref) => _FakeLocalFavoriteRepository(),
            ),
            favoriteSyncServiceProvider.overrideWith(
              (ref) => _FakeFavoriteSyncService(),
            ),
            comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
              queueSnapshot,
            ),
            mainShellBackgroundTaskStarterProvider.overrideWithValue(
              (_) async {},
            ),
            libraryTaskNotificationServiceProvider.overrideWithValue(
              notificationService,
            ),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          ],
          child: const LocalizedTestApp(home: MainShellPage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MainShellPage warms up Yamibo profile session on startup', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    var warmupCalls = 0;
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellReplyDraftAttachmentMaintenanceStarterProvider
              .overrideWithValue(() async {}),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {
            warmupCalls += 1;
          }),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );

    await tester.pump();

    expect(warmupCalls, 1);
  });

  testWidgets('MainShellPage ignores Yamibo profile warmup failure', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellReplyDraftAttachmentMaintenanceStarterProvider
              .overrideWithValue(() async {}),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {
            throw StateError('warmup failed');
          }),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
