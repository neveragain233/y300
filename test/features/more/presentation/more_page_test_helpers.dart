part of 'more_page_test.dart';

Future<void> _expectMyContentEntryOrderAndLabels(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final blogs = find.byKey(const Key('more-my-blogs-entry'));
  await tester.scrollUntilVisible(
    blogs,
    -160,
    scrollable: find.descendant(
      of: find.byKey(const Key('more-page-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  double? previousBottom;
  for (final (name, label) in [
    if (find.byKey(const Key('more-my-messages-entry')).evaluate().isNotEmpty)
      ('messages', l10n.moreMyMessages),
    ('blogs', l10n.profileMyBlogs),
    ('friends', l10n.profileMyFriendsTitle),
  ]) {
    final finder = find.byKey(Key('more-my-$name-entry'));
    final row = tester.widget<AppGroupedRow>(finder);
    expect(row.title, label);
    expect(row.onTap, isNotNull);
    final rect = tester.getRect(finder);
    if (previousBottom != null) {
      expect(rect.top, greaterThanOrEqualTo(previousBottom));
    }
    previousBottom = rect.bottom;
    if (name == 'messages') {
      final icon = row.leading! as MessageAttentionIcon;
      expect(icon.icon, Icons.mail_outline);
      expect(icon.showAttention, isFalse);
    }
  }
}

FriendFeedFixture _emptyFriends() => FriendFeedFixture(autoComplete: true)
  ..items = []
  ..hasNext = false
  ..totalPages = 1;

Future<void> _pumpMyContentPage(
  WidgetTester tester, {
  required bool isLoggedIn,
  required FriendFeedFixture friends,
  required List<ForumWebViewLaunchConfig> launches,
  _ThreadDirectoryRepository? directory,
  MessageTestRepository? messages,
  BlogDirectoryFixture? blogs,
  _AccountSummaryRepository? summary,
  _RouteNameObserver? observer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._moreAuthOverrides(
          _FakeAuthRepository(isLoggedIn: isLoggedIn),
          summaryRepository: summary,
        ),
        userThreadDirectoryRepositoryProvider.overrideWithValue(
          directory ?? _ThreadDirectoryRepository(),
        ),
        if (messages != null)
          messageRepositoryProvider.overrideWithValue(messages),
        userBlogDirectoryRepositoryProvider.overrideWithValue(
          blogs ?? BlogDirectoryFixture(),
        ),
        friendFeedRepositoryProvider.overrideWithValue(friends),
        friendRemovalCommandProvider.overrideWithValue(FriendRemovalFixture()),
        forumImageRefererProvider.overrideWithValue('https://bbs.yamibo.com/'),
        forumWebViewRouteFactoryProvider.overrideWithValue(
          _profileWebRoutes(launches),
        ),

        appAppearanceControllerProvider.overrideWith(
          () => _FakeAppAppearanceController(),
        ),
      ],
      child: LocalizedTestApp(
        home: const MorePage(),
        navigatorObservers: [?observer],
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MorePage)),
  );
  await container
      .read(mainNavigationSettingsControllerProvider.notifier)
      .setVisibility(MainShellDestination.forum, false);
  await tester.pumpAndSettle();
}

void _completeMessageReads(
  MessageTestRepository repository, {
  required String owner,
}) {
  for (final read in repository.reads) {
    if (!read.result.isCompleted) {
      read.result.complete(messageTestPage([], owner: owner));
    }
  }
  for (final read in repository.notificationReads) {
    if (!read.result.isCompleted) {
      read.result.complete(notificationTestPage([]));
    }
  }
}

Future<void> _pumpCreditPage(
  WidgetTester tester, {
  required _AccountSummaryRepository summary,
  required List<ForumWebViewLaunchConfig> launches,
  NavigatorObserver? observer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._moreAuthOverrides(
          _FakeAuthRepository(isLoggedIn: true),
          summaryRepository: summary,
        ),
        userThreadDirectoryRepositoryProvider.overrideWithValue(
          _ThreadDirectoryRepository(),
        ),
        forumWebViewRouteFactoryProvider.overrideWithValue(
          _profileWebRoutes(launches),
        ),

        appAppearanceControllerProvider.overrideWith(
          () => _FakeAppAppearanceController(),
        ),
      ],
      child: LocalizedTestApp(
        home: const MorePage(),
        navigatorObservers: [?observer],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InkWell _accountStatisticButton(
  WidgetTester tester,
  String name, {
  bool skipOffstage = true,
}) => tester.widget<InkWell>(
  find.descendant(
    of: find.byKey(Key('more-account-$name'), skipOffstage: skipOffstage),
    matching: find.byType(InkWell, skipOffstage: skipOffstage),
    skipOffstage: skipOffstage,
  ),
);

ForumWebViewRouteFactory _profileWebRoutes(
  List<ForumWebViewLaunchConfig> launches,
) => (config) {
  launches.add(config);
  return MaterialPageRoute<Object?>(
    builder: (_) => const Scaffold(key: Key('test-profile-webview')),
  );
};

Future<void> _scrollUntilVisibleIfNeeded(
  WidgetTester tester,
  Finder finder,
) async {
  if (finder.evaluate().isNotEmpty) {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(finder, 160);
}

List<Override> _moreAuthOverrides(
  AuthRepository repository, {
  CurrentAccountSummaryRepository? summaryRepository,
}) => [
  ...forumAuthOverrides(repository),
  if (summaryRepository != null)
    currentAccountSummaryRepositoryProvider.overrideWithValue(summaryRepository)
  else
    currentAccountSummaryRepositoryProvider.overrideWith((ref) {
      return _AccountSummaryRepository(() {
        final session = ref.read(authSessionControllerProvider).asData!.value;
        return CurrentUserProfileData(
          identity: ProfileUserIdentity(
            userId: session.uid,
            displayName: session.username,
          ),
          groupName: '普通会员',
          creditTotal: 42,
        );
      });
    }),
];

class _AccountSummaryRepository implements CurrentAccountSummaryRepository {
  _AccountSummaryRepository(this.currentData);

  final CurrentUserProfileData Function() currentData;
  int reads = 0;

  @override
  CurrentUserProfileSourceCapabilities get capabilities =>
      CurrentUserProfileSourceCapabilities(
        values: DataCapabilitySet.supported(
          CurrentUserProfileCapability.values,
        ),
      );

  @override
  Future<
    DataReadResult<CurrentUserProfileData, CurrentUserProfileReadCapabilities>
  >
  load(
    CurrentAccountSummaryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    reads++;
    return DataReadSuccess(
      data: currentData(),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _ThreadDirectoryRepository extends Fake
    implements UserThreadDirectoryRepository {
  final queries = <UserThreadDirectoryQuery>[];

  @override
  Future<
    DataReadResult<UserThreadDirectoryData, UserThreadDirectoryReadCapabilities>
  >
  load(
    UserThreadDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    return DataReadSuccess(
      data: const UserThreadDirectoryData(
        items: [],
        pagination: UserThreadDirectoryPagination(
          currentPage: 1,
          hasNext: false,
          hasPrevious: false,
        ),
      ),
      capabilities: UserThreadDirectoryReadCapabilities(
        values: DataCapabilitySet<UserThreadDirectoryCapability>({}),
      ),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _RouteNameObserver extends NavigatorObserver {
  final List<String?> pushedNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

class _FakeUnusedImagesController
    extends ComposerUnusedImageManagementController {
  @override
  Future<ComposerUnusedImageManagementState> build() async {
    return ComposerUnusedImageManagementState(images: const []);
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required bool isLoggedIn}) : _isLoggedIn = isLoggedIn;
  bool _isLoggedIn;
  var logoutCount = 0;
  @override
  Future<ApiResult<SessionInfo>> login({
    required String username,
    required String password,
    String questionId = '0',
    String answer = '',
  }) async {
    _isLoggedIn = true;
    return ApiSuccess(_session);
  }

  @override
  Future<void> logout() async {
    logoutCount++;
    _isLoggedIn = false;
  }

  @override
  Future<ApiResult<SessionInfo>> refreshSession() async {
    return ApiSuccess(
      _isLoggedIn
          ? _session
          : const SessionInfo(
              uid: '0',
              username: '',
              formhash: 'fh_guest',
              isLoggedIn: false,
            ),
    );
  }

  @override
  Future<ApiResult<bool>> verifyAuthByForumIndex() async {
    return ApiSuccess(_isLoggedIn);
  }

  SessionInfo get _session {
    return const SessionInfo(
      uid: '100',
      username: 'tester',
      formhash: 'fh',
      isLoggedIn: true,
    );
  }
}

class _FakeAppAppearanceController extends AppAppearanceController {
  var _settings = AppAppearanceSettings.defaults();

  @override
  Future<AppAppearanceSettings> build() async {
    return _settings;
  }

  @override
  Future<void> setThemeFamily(AppThemeFamily family) async {
    _settings = _settings.copyWith(themeFamily: family);
    state = AsyncData(_settings);
  }

  @override
  Future<void> setBrightnessPreference(
    AppBrightnessPreference preference,
  ) async {
    _settings = _settings.copyWith(brightnessPreference: preference);
    state = AsyncData(_settings);
  }

  @override
  Future<void> setLanguagePreference(AppLanguage language) async {
    _settings = _settings.copyWith(languagePreference: language);
    state = AsyncData(_settings);
  }
}

class _FakeCookieStore extends CookieStore {
  @override
  Future<Map<String, String>> readCookieMap(Uri uri) async {
    return const <String, String>{};
  }

  @override
  Future<void> saveCookies(Uri uri, Map<String, String> cookies) async {}
}

class _FakeWebViewCookieJar implements WebViewCookieJar {
  @override
  Future<void> clear() async {}

  @override
  Future<Map<String, String>> readCookies(Uri uri) async {
    return const <String, String>{};
  }

  @override
  Future<void> writeCookies(Uri uri, Map<String, String> cookies) async {}
}

class _FakeWebViewCookieSyncService extends WebViewCookieSyncService {
  _FakeWebViewCookieSyncService()
    : super(
        cookieJar: _FakeWebViewCookieJar(),
        cookieStore: _FakeCookieStore(),
      );

  @override
  Future<void> clearWebViewCookies() async {}

  @override
  Future<Map<String, String>> syncToStore(
    Uri uri, {
    bool Function()? isCurrent,
  }) async {
    return const <String, String>{};
  }
}

class _SignedProfileRepository implements ForumUserProfileRepository {
  final queries = <ForumUserProfileQuery>[];
  final policies = <CacheLoadPolicy>[];

  @override
  ForumUserProfileSourceCapabilities get capabilities =>
      ForumUserProfileSourceCapabilities(
        values: DataCapabilitySet.supported(ForumUserProfileCapability.values),
      );

  @override
  Future<DataReadResult<ForumUserProfileData, ForumUserProfileReadCapabilities>>
  load(
    ForumUserProfileQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    policies.add(cachePolicy);
    return DataReadSuccess(
      data: ForumUserProfileData(
        identity: ProfileUserIdentity(
          userId: query.userId,
          displayName: 'sample-member',
        ),
        metrics: const <ForumUserProfileMetric>[],
        details: <ForumUserProfileDetail>[
          ForumUserProfileDetail(label: 'UID', value: query.userId),
        ],
      ),
      capabilities: ForumUserProfileReadCapabilities(
        values: DataCapabilitySet.supported(ForumUserProfileCapability.values),
      ),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _SignedDailySignInRepository implements ForumDailySignInRepository {
  int reads = 0;

  @override
  ForumDailySignInSourceCapabilities get capabilities =>
      ForumDailySignInSourceCapabilities(
        values: DataCapabilitySet.supported(
          ForumDailySignInReadCapability.values,
        ),
      );

  @override
  Future<
    DataReadResult<ForumDailySignInSnapshot, ForumDailySignInReadCapabilities>
  >
  load(ForumDailySignInQuery query) async {
    reads++;
    return DataReadSuccess(
      data: ForumDailySignInSnapshot(
        userId: query.userId,
        forumDay: '20260925',
        status: ForumDailySignInStatus.signed,
      ),
      capabilities: ForumDailySignInReadCapabilities(
        values: DataCapabilitySet.supported(
          ForumDailySignInReadCapability.values,
        ),
      ),
      metadata: const DataReadMetadata.network(),
    );
  }
}
