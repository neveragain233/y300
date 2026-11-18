part of 'user_profile_page_test.dart';

class _EmptyMessageRepository extends MessageTestRepository {
  @override
  Future<PrivateMessageRead> loadMessages(
    ForumPrivateMessageQuery query,
  ) async => messageTestPage([], owner: '654321');
}

Future<void> _pumpPublicProfile(
  WidgetTester tester, {
  required ForumUserProfileRepository repository,
  Locale locale = const Locale('zh'),
  ImageCacheService? imageCacheService,
  PrivateConversationRouteFactory? conversationRoute,
  UserBlogDirectoryRepository? blogRepository,
  VerifiedSessionOwner? owner = (uid: '654321', revision: 0),
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        verifiedSessionOwnerProvider.overrideWithValue(owner),
        forumUserProfileRepositoryProvider.overrideWithValue(repository),
        if (blogRepository != null) ...[
          userBlogDirectoryRepositoryProvider.overrideWithValue(blogRepository),
          blogAccountIdProvider.overrideWithValue(null),
        ],
        if (conversationRoute != null)
          privateConversationRouteFactoryProvider.overrideWithValue(
            conversationRoute,
          ),
        forumImageRefererProvider.overrideWithValue('https://bbs.yamibo.com/'),
        if (imageCacheService != null)
          imageCacheServiceProvider.overrideWithValue(imageCacheService),
      ],
      child: LocalizedTestApp(
        locale: locale,
        home: const UserProfilePage(uid: '123456'),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _pumpMyProfile(
  WidgetTester tester, {
  required ForumUserProfileRepository repository,
  Locale locale = const Locale('zh'),
  YamiboSessionStore? store,
  ForumWebViewRouteFactory? routeFactory,
  UserThreadDirectoryRepository? threadDirectory,
  ForumFriendFeedRepository? friendDirectory,
  Widget? home,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...forumAuthOverrides(const _FakeAuthRepository()),
        forumUserProfileRepositoryProvider.overrideWithValue(repository),
        if (threadDirectory != null)
          userThreadDirectoryRepositoryProvider.overrideWithValue(
            threadDirectory,
          ),
        if (friendDirectory != null) ...[
          friendFeedRepositoryProvider.overrideWithValue(friendDirectory),
          friendRemovalCommandProvider.overrideWithValue(
            FriendRemovalFixture(),
          ),
        ],
        if (store != null) yamiboSessionStoreProvider.overrideWithValue(store),
        if (routeFactory != null)
          forumWebViewRouteFactoryProvider.overrideWithValue(routeFactory),
        forumImageRefererProvider.overrideWithValue('https://bbs.yamibo.com/'),
      ],
      child: LocalizedTestApp(
        locale: locale,
        home: home ?? const MyProfilePage(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

ScrollableState _profileScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('user-profile-page-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

ForumUserProfileData _scrollableProfile({required bool self}) {
  final source = self ? _myProfile : _profile;
  return ForumUserProfileData(
    identity: source.identity,
    viewerUserId: source.viewerUserId,
    actions: source.actions,
    signatureHtml: _profile.signatureHtml,
    metrics: source.metrics,
    details: [
      ...source.details,
      for (var index = 0; index < 20; index++)
        ForumUserProfileDetail(label: 'Field $index', value: 'Value $index'),
    ],
  );
}

AppLocalizations _profileL10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MyProfilePage)));

YamiboSessionSnapshot _sessionFor(String uid) => YamiboSessionSnapshot(
  isLoggedIn: true,
  uid: uid,
  username: 'sample-member',
  formhash: '',
  updatedAt: DateTime(2026, 1, 1),
  source: 'test',
);

typedef _ProfileReadResult =
    DataReadResult<ForumUserProfileData, ForumUserProfileReadCapabilities>;

_ProfileReadResult _profileSuccess(ForumUserProfileData data) =>
    DataReadSuccess(
      data: data,
      capabilities: _profileCapabilities(),
      metadata: const DataReadMetadata.network(),
    );

ForumUserProfileData _selfProfile(String uid, String name) =>
    ForumUserProfileData(
      identity: ProfileUserIdentity(userId: uid, displayName: name),
      metrics: const <ForumUserProfileMetric>[],
      details: <ForumUserProfileDetail>[
        ForumUserProfileDetail(label: 'UID', value: uid),
      ],
    );

class _ScriptedProfileRepository implements ForumUserProfileRepository {
  _ScriptedProfileRepository(this.onLoad);

  final Future<_ProfileReadResult> Function(ForumUserProfileQuery, int) onLoad;
  final queries = <ForumUserProfileQuery>[];
  final policies = <CacheLoadPolicy>[];
  final cancellations = <ForumRequestCancellation?>[];

  @override
  ForumUserProfileSourceCapabilities get capabilities =>
      ForumUserProfileSourceCapabilities(values: _profileCapabilities().values);

  @override
  Future<_ProfileReadResult> load(
    ForumUserProfileQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) {
    final call = queries.length;
    queries.add(query);
    policies.add(cachePolicy);
    cancellations.add(cancellation);
    return onLoad(query, call);
  }
}

class _ProfileThreadDirectoryRepository extends Fake
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
    return const DataReadFailure(
      kind: DataReadFailureKind.parse,
      code: 'fixture_unavailable',
      diagnosticMessage: 'fixture_unavailable',
    );
  }
}

const _profile = ForumUserProfileData(
  identity: ProfileUserIdentity(userId: '123456', displayName: 'alice'),
  viewerUserId: '654321',
  actions: [
    ForumUserProfileActionKind.threads,
    ForumUserProfileActionKind.blogs,
    ForumUserProfileActionKind.sendMessage,
  ],
  signatureHtml: '<p>Make a deal with god</p>',
  metrics: <ForumUserProfileMetric>[
    ForumUserProfileMetric(label: '总积分', value: '2048'),
    ForumUserProfileMetric(label: '积分', value: '1800 点'),
    ForumUserProfileMetric(label: '对象', value: '333'),
  ],
  details: <ForumUserProfileDetail>[
    ForumUserProfileDetail(label: 'UID', value: '123456'),
    ForumUserProfileDetail(label: '用户组', value: '普通会员'),
  ],
);

const _myProfile = ForumUserProfileData(
  identity: ProfileUserIdentity(userId: '654321', displayName: 'sample-member'),
  actions: <ForumUserProfileActionKind>[
    ForumUserProfileActionKind.blogs,
    ForumUserProfileActionKind.messages,
  ],
  metrics: <ForumUserProfileMetric>[
    ForumUserProfileMetric(label: '总积分', value: '65'),
    ForumUserProfileMetric(label: '积分', value: '7 点'),
    ForumUserProfileMetric(label: '对象', value: '175'),
  ],
  details: <ForumUserProfileDetail>[
    ForumUserProfileDetail(label: 'UID', value: '654321'),
    ForumUserProfileDetail(label: '用户组', value: '普通会员'),
  ],
);

final _allActionsProfile = ForumUserProfileData(
  identity: const ProfileUserIdentity(
    userId: '654321',
    displayName: 'sample-member',
  ),
  metrics: const <ForumUserProfileMetric>[],
  details: const <ForumUserProfileDetail>[
    ForumUserProfileDetail(label: 'UID', value: '654321'),
  ],
  actions: const [
    ForumUserProfileActionKind.threads,
    ForumUserProfileActionKind.blogs,
    ForumUserProfileActionKind.forumFavorites,
    ForumUserProfileActionKind.messages,
    ForumUserProfileActionKind.friends,
    ForumUserProfileActionKind.settings,
    ForumUserProfileActionKind.creditHistory,
  ],
  actionLinks: [
    ForumUserProfileActionLink(
      kind: ForumUserProfileActionKind.forumFavorites,
      uri: Uri.parse(
        'https://bbs.yamibo.com/home.php?mod=space&uid=654321&do=favorite&view=me&type=thread',
      ),
    ),
    ForumUserProfileActionLink(
      kind: ForumUserProfileActionKind.friends,
      uri: Uri.parse('https://bbs.yamibo.com/home.php?mod=space&do=friend'),
    ),
    ForumUserProfileActionLink(
      kind: ForumUserProfileActionKind.settings,
      uri: Uri.parse('https://bbs.yamibo.com/home.php?mod=spacecp&ac=profile'),
    ),
    ForumUserProfileActionLink(
      kind: ForumUserProfileActionKind.creditHistory,
      uri: Uri.parse(
        'https://bbs.yamibo.com/home.php?mod=spacecp&ac=credit&op=log',
      ),
    ),
  ],
);

ForumUserProfileData _profileWith({String? avatarUrl}) {
  return ForumUserProfileData(
    identity: _profile.identity,
    avatarUrl: avatarUrl,
    viewerUserId: _profile.viewerUserId,
    actions: _profile.actions,
    signatureHtml: _profile.signatureHtml,
    metrics: _profile.metrics,
    details: _profile.details,
  );
}

ForumUserProfileReadCapabilities _profileCapabilities({
  Iterable<ForumUserProfileCapability> supported =
      ForumUserProfileCapability.values,
}) {
  return ForumUserProfileReadCapabilities(
    values: DataCapabilitySet<ForumUserProfileCapability>.from(
      supported: supported,
      unsupported: ForumUserProfileCapability.values.where(
        (value) => !supported.contains(value),
      ),
    ),
  );
}

class _FakeProfileRepository implements ForumUserProfileRepository {
  _FakeProfileRepository({
    this.data = _profile,
    ForumUserProfileReadCapabilities? capabilities,
    this.failAfterSuccess = false,
  }) : readCapabilities = capabilities ?? _profileCapabilities();

  final ForumUserProfileData data;
  final ForumUserProfileReadCapabilities readCapabilities;
  final bool failAfterSuccess;
  final List<ForumUserProfileQuery> queries = <ForumUserProfileQuery>[];
  final List<CacheLoadPolicy> policies = <CacheLoadPolicy>[];

  @override
  ForumUserProfileSourceCapabilities get capabilities =>
      ForumUserProfileSourceCapabilities(values: readCapabilities.values);

  @override
  Future<DataReadResult<ForumUserProfileData, ForumUserProfileReadCapabilities>>
  load(
    ForumUserProfileQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    policies.add(cachePolicy);
    if (failAfterSuccess && queries.length > 1) {
      return const DataReadFailure(
        kind: DataReadFailureKind.network,
        diagnosticMessage: 'network failure',
      );
    }
    return DataReadSuccess(
      data: data,
      capabilities: readCapabilities,
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _FakeBlogDirectoryRepository implements UserBlogDirectoryRepository {
  final List<UserBlogDirectoryQuery> queries = <UserBlogDirectoryQuery>[];

  @override
  UserBlogDirectorySourceCapabilities get capabilities =>
      UserBlogDirectorySourceCapabilities(
        values: DataCapabilitySet<UserBlogDirectoryCapability>.supported(
          UserBlogDirectoryCapability.values,
        ),
        paginationPrecision: PaginationPrecision.unknown,
      );

  @override
  Future<
    DataReadResult<UserBlogDirectoryData, UserBlogDirectoryReadCapabilities>
  >
  load(
    UserBlogDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    return DataReadSuccess(
      data: UserBlogDirectoryData(
        scope: query.scope,
        order: query.order,
        items: const <UserBlogSummary>[],
        pagination: UserBlogPagination(currentPage: query.page),
      ),
      capabilities: UserBlogDirectoryReadCapabilities(
        values: DataCapabilitySet<UserBlogDirectoryCapability>.supported(
          UserBlogDirectoryCapability.values,
        ),
        paginationPrecision: PaginationPrecision.unknown,
      ),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _NoopImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult.failed;
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult.failed;
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<void> clearUnprotected() async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async {
    return 0;
  }

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<ApiResult<SessionInfo>> refreshSession() async => const ApiSuccess(
    SessionInfo(
      uid: '654321',
      username: 'sample-member',
      formhash: 'fh',
      isLoggedIn: true,
    ),
  );

  @override
  Future<ApiResult<bool>> verifyAuthByForumIndex() async =>
      const ApiSuccess<bool>(true);

  @override
  Future<ApiResult<SessionInfo>> login({
    required String username,
    required String password,
    String questionId = '0',
    String answer = '',
  }) async {
    return refreshSession();
  }

  @override
  Future<void> logout() async {}
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is RichText && widget.text.toPlainText().contains(text);
  });
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}
