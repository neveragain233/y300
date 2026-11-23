part of 'forum_home_page_test.dart';

Widget _buildTestApp(
  ForumHomeRepository repository, {
  ForumWebViewExternalLauncher? launcher,
  List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
  bool isActive = true,
  DateTime Function()? nowProvider,
  ImageCacheService? imageCacheService,
  ForumImagePrecacheService? forumImagePrecacheService,
  List<riverpod_misc.Override> extraOverrides =
      const <riverpod_misc.Override>[],
  Duration? Function(int, Object)? retry,
}) {
  return ProviderScope(
    retry: retry,
    overrides: _overrides(
      repository,
      launcher: launcher,
      nowProvider: nowProvider,
      imageCacheService: imageCacheService,
      forumImagePrecacheService: forumImagePrecacheService,
    )..addAll(extraOverrides),
    child: LocalizedTestApp(
      navigatorObservers: navigatorObservers,
      home: ForumHomePage(isActive: isActive),
    ),
  );
}

List<riverpod_misc.Override> _overrides(
  ForumHomeRepository repository, {
  ForumWebViewExternalLauncher? launcher,
  AuthRepository? authRepository,
  DateTime Function()? nowProvider,
  ImageCacheService? imageCacheService,
  ForumImagePrecacheService? forumImagePrecacheService,
  ForumHomeRequestProfileResolver? requestProfileResolver,
}) {
  return [
    forumHomeRepositoryProvider.overrideWithValue(repository),
    ...forumAuthOverrides(authRepository ?? _FakeAuthRepository()),
    imageCacheServiceProvider.overrideWithValue(
      imageCacheService ?? _FakeImageCacheService(),
    ),
    forumImagePrecacheServiceProvider.overrideWithValue(
      forumImagePrecacheService ?? _FakeForumImagePrecacheService(),
    ),
    forumImageRefererProvider.overrideWithValue('https://bbs.yamibo.com/'),
    forumHomeRequestProfileResolverProvider.overrideWithValue(
      requestProfileResolver ??
          const _FakeForumHomeRequestProfileResolver(
            DocumentRequestProfile.anonymous,
          ),
    ),
    if (nowProvider != null)
      forumHomeNowProvider.overrideWithValue(nowProvider),
    if (launcher != null)
      forumWebViewExternalLauncherProvider.overrideWithValue(launcher),
  ];
}

ForumDirectoryData _sampleDirectory({
  int? todayPosts = 2,
  String description = '站点公告与维护信息',
}) {
  return ForumDirectoryData(
    sections: [
      ForumDirectorySection(
        identity: '1',
        title: '综合区',
        forums: [
          ForumDirectoryForum(
            fid: '2',
            title: '公告区',
            description: description,
            todayPosts: todayPosts,
          ),
        ],
      ),
    ],
  );
}

ForumHomePayload _loggedOutPayload({
  List<ForumHomeCarouselItem> carouselItems = const <ForumHomeCarouselItem>[],
  int? todayPosts = 2,
  String description = '站点公告与维护信息',
}) {
  return ForumHomePayload(
    directory: _sampleDirectory(
      todayPosts: todayPosts,
      description: description,
    ),
    isLoggedIn: false,
    favoriteForums: const [],
    chromeData: ForumHomeChromeData(carouselItems: carouselItems),
  );
}

ForumHomePayload _emptyPayload() {
  return ForumHomePayload(
    directory: const ForumDirectoryData(sections: []),
    isLoggedIn: false,
    favoriteForums: const [],
  );
}

ForumHomePayload _loggedOutPayloadNoToday() {
  return ForumHomePayload(
    directory: _sampleDirectory(todayPosts: null),
    isLoggedIn: false,
    favoriteForums: const [],
  );
}

ForumHomePayload _loggedOutPayloadWithTodayCount(int todayPosts) {
  return ForumHomePayload(
    directory: _sampleDirectory(todayPosts: todayPosts, description: '站务公告'),
    isLoggedIn: false,
    favoriteForums: [
      ForumHomeFavoriteForum(
        fid: '2',
        title: '公告区',
        description: '站务公告',
        todayPosts: todayPosts,
      ),
    ],
    chromeData: ForumHomeChromeData(
      favoriteForums: [
        ForumHomeChromeForumItem(
          fid: '2',
          title: '公告区',
          description: '站务公告',
          todayPosts: todayPosts,
        ),
      ],
    ),
  );
}

ForumHomePayload _loggedOutPayloadWithCarousel() {
  return _loggedOutPayload(
    carouselItems: const [
      ForumHomeCarouselItem(
        imageUrl: 'https://bbs.yamibo.com/banner.jpg',
        targetUrl: 'https://bbs.yamibo.com/thread-570956-1-1.html',
      ),
    ],
  );
}

ForumHomePayload _loggedInPayloadWithFavorites() {
  return ForumHomePayload(
    directory: _sampleDirectory(),
    isLoggedIn: true,
    favoriteForums: [
      const ForumHomeFavoriteForum(
        fid: '2',
        title: '百合会综合讨论区',
        description: '常逛版块',
        todayPosts: 1,
      ),
      const ForumHomeFavoriteForum(
        fid: '55',
        title: '漫画交流区',
        description: '',
        todayPosts: 2,
      ),
    ],
  );
}

ForumHomePayload _loggedInPayloadWithEmptyFavoriteDescription() {
  return ForumHomePayload(
    directory: _sampleDirectory(),
    isLoggedIn: true,
    favoriteForums: [
      const ForumHomeFavoriteForum(
        fid: '2',
        title: '公告区',
        description: '',
        todayPosts: 0,
      ),
    ],
  );
}

ForumHomePayload _loggedInPayloadWithChromeFavoriteDescriptions() {
  return ForumHomePayload(
    directory: _sampleDirectory(),
    isLoggedIn: true,
    favoriteForums: [
      const ForumHomeFavoriteForum(
        fid: '33',
        title: '海域區',
        description: '',
        todayPosts: 0,
      ),
      const ForumHomeFavoriteForum(
        fid: '30',
        title: '中文百合漫画区',
        description: '',
        todayPosts: 0,
      ),
      const ForumHomeFavoriteForum(
        fid: '55',
        title: '轻小说/译文区',
        description: '',
        todayPosts: 0,
      ),
    ],
    chromeData: const ForumHomeChromeData(
      favoriteForums: [
        ForumHomeChromeForumItem(
          fid: '33',
          title: '海域區',
          description: '风声水起。',
          todayPosts: 122,
        ),
        ForumHomeChromeForumItem(
          fid: '30',
          title: '中文百合漫画区',
          description: '爱的推广会。',
          todayPosts: 105,
        ),
        ForumHomeChromeForumItem(
          fid: '55',
          title: '轻小说/译文区',
          description: '外文作品翻译的分享与赏析。',
          todayPosts: 69,
        ),
      ],
    ),
  );
}

class _FakeForumHomeRepository implements ForumHomeRepository {
  _FakeForumHomeRepository(this._loader, {this.cachedEntry, this.cacheLoader});
  final Future<ForumHomeCacheEntry?> Function()? cacheLoader;

  final Future<ForumHomeReadResult> Function() _loader;
  final ForumHomeCacheEntry? cachedEntry;
  final cachePolicies = <CacheLoadPolicy>[];
  final requestProfiles = <DocumentRequestProfile?>[];
  final cachedRequestProfiles = <DocumentRequestProfile>[];

  @override
  Future<ForumHomeCacheEntry?> readCachedPayload({
    required DocumentRequestProfile requestProfile,
  }) async {
    cachedRequestProfiles.add(requestProfile);
    return cacheLoader == null ? cachedEntry : await cacheLoader!();
  }

  @override
  Future<ForumHomeReadResult> getForumHomePayload({
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    DocumentRequestProfile? requestProfileOverride,
  }) {
    cachePolicies.add(cachePolicy);
    requestProfiles.add(requestProfileOverride);
    return _loader();
  }
}

FavoriteForumEntry _favoriteDirectoryForum({
  required String fid,
  required String remoteFavoriteId,
  required String title,
}) {
  return FavoriteForumEntry(
    fid: fid,
    title: title,
    remoteFavoriteId: remoteFavoriteId,
    description: '',
    threadCount: 0,
    postCount: 0,
    todayPostCount: 0,
  );
}

class _FakeForumFavoriteRepository implements FavoriteForumCommand {
  _FakeForumFavoriteRepository({
    required List<FavoriteForumEntry> favoriteForums,
  }) : directory = _FakeFavoriteForumDirectoryRepository(favoriteForums);

  final _FakeFavoriteForumDirectoryRepository directory;
  final favoriteFids = <String>[];
  final unfavoriteFavids = <String>[];

  int get loadCallCount => directory.loadCallCount;

  @override
  FavoriteMutationCapabilities get capabilities =>
      allFavoriteMutationCapabilities;

  @override
  Future<DataCommandResult<ForumFavoriteReceipt>> execute(
    SetForumFavoriteRequest request,
  ) async {
    if (request.targetState == FavoriteTargetState.favorited) {
      favoriteFids.add(request.fid);
    } else {
      final favid = request.knownRemoteFavoriteId;
      if (favid != null) {
        unfavoriteFavids.add(favid);
      }
    }
    return appliedForumFavorite(
      fid: request.fid,
      targetState: request.targetState,
      remoteFavoriteId: request.knownRemoteFavoriteId,
    );
  }
}

class _FakeFavoriteForumDirectoryRepository
    implements FavoriteForumDirectoryRepository {
  _FakeFavoriteForumDirectoryRepository(this.favoriteForums);

  final List<FavoriteForumEntry> favoriteForums;
  int loadCallCount = 0;

  @override
  FavoriteForumDirectorySourceCapabilities get capabilities =>
      _favoriteForumSourceCapabilities;

  @override
  Future<
    DataReadResult<
      FavoriteForumDirectoryData,
      FavoriteForumDirectoryReadCapabilities
    >
  >
  load(
    FavoriteForumDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    loadCallCount += 1;
    return DataReadSuccess(
      data: FavoriteForumDirectoryData(items: favoriteForums),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

final _favoriteForumSourceCapabilities =
    FavoriteForumDirectorySourceCapabilities(
      values: DataCapabilitySet<FavoriteForumDirectoryCapability>.supported(
        FavoriteForumDirectoryCapability.values,
      ),
    );

class _MutableNow {
  _MutableNow(this.value);

  DateTime value;

  DateTime call() => value;
}

SessionInfo _loggedInSession({
  String uid = '597454',
  String username = 'tester',
}) {
  return SessionInfo(
    uid: uid,
    username: username,
    formhash: '14502ecf',
    isLoggedIn: true,
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({SessionInfo? session}) : _session = session;

  SessionInfo? _session;

  void setSession(SessionInfo session) {
    _session = session;
  }

  void setSignedOut() {
    _session = null;
  }

  @override
  Future<ApiResult<SessionInfo>> refreshSession() async {
    final session = _session;
    if (session != null) {
      return ApiSuccess(session);
    }
    return const ApiSuccess(
      SessionInfo(uid: '0', username: '', formhash: '', isLoggedIn: false),
    );
  }

  @override
  Future<ApiResult<SessionInfo>> login({
    required String username,
    required String password,
    String questionId = '0',
    String answer = '',
  }) async {
    throw StateError('login is not part of this test');
  }

  @override
  Future<void> logout() async {
    throw StateError('logout is not part of this test');
  }

  @override
  Future<ApiResult<bool>> verifyAuthByForumIndex() async {
    throw StateError('verifyAuthByForumIndex is not part of this test');
  }
}

class _PendingAuthRepository extends _FakeAuthRepository {
  _PendingAuthRepository({required super.session});

  final Completer<ApiResult<SessionInfo>> _completer =
      Completer<ApiResult<SessionInfo>>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete(super.refreshSession());
    }
  }

  @override
  Future<ApiResult<SessionInfo>> refreshSession() {
    return _completer.future;
  }
}

class _FakeForumHomeRequestProfileResolver
    implements ForumHomeRequestProfileResolver {
  const _FakeForumHomeRequestProfileResolver(this.profile);

  final DocumentRequestProfile profile;

  @override
  Future<DocumentRequestProfile> resolve() async => profile;
}

class _RecordingNativePageCacheInvalidationService
    implements NativePageCacheInvalidationService {
  int invalidateForumHomeCalls = 0;

  @override
  Future<void> invalidateForumDisplay(String fid) async {}

  @override
  Future<void> invalidateForumHome() async {
    invalidateForumHomeCalls += 1;
  }

  @override
  Future<void> invalidateThread(String tid) async {}
}

class _FakeImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      fromCache: true,
    );
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async {
    return null;
  }

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult(success: true, cacheKey: request.cacheKey);
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async {
    return 0;
  }

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}

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

class _RecordingImageCacheService extends _FakeImageCacheService {
  final requests = <ImageCacheRequest>[];

  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    requests.add(request);
    return super.ensureCached(request);
  }
}

class _FakeForumImagePrecacheService implements ForumImagePrecacheService {
  @override
  Future<ForumImagePrecacheResult> ensureDiskCached(
    ForumImageLoadSpec spec,
  ) async {
    return const ForumImagePrecacheResult(success: true);
  }

  @override
  Future<ForumImagePrecacheResult> precacheDecoded({
    required BuildContext context,
    required ForumImageLoadSpec spec,
    Size? expectedDisplaySize,
  }) async {
    return const ForumImagePrecacheResult(success: true, decoded: true);
  }
}

class _RecordingForumImagePrecacheService
    extends _FakeForumImagePrecacheService {
  final decodedSpecs = <ForumImageLoadSpec>[];

  @override
  Future<ForumImagePrecacheResult> precacheDecoded({
    required BuildContext context,
    required ForumImageLoadSpec spec,
    Size? expectedDisplaySize,
  }) async {
    decodedSpecs.add(spec);
    return super.precacheDecoded(
      context: context,
      spec: spec,
      expectedDisplaySize: expectedDisplaySize,
    );
  }
}

class _FakeForumWebViewExternalLauncher
    implements ForumWebViewExternalLauncher {
  bool succeeds = true;
  final launchedUris = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return succeeds;
  }
}

class _FakeClipboardTextWriter implements ClipboardTextWriter {
  _FakeClipboardTextWriter({this.error, this.pending});

  final Object? error;
  final Completer<void>? pending;
  final written = <String>[];

  @override
  Future<void> writeText(String text) async {
    written.add(text);
    await pending?.future;
    if (error != null) {
      throw error!;
    }
  }
}

class _ProjectionPrefixBatchConversionService
    implements PlainTextBatchConversionService {
  @override
  Future<List<String>> convertAll({
    required List<String> sources,
    required TextConverter converter,
  }) async {
    return <String>[for (final source in sources) 'T:$source'];
  }
}

class _ProjectionTestConverter implements TextConverter {
  const _ProjectionTestConverter(this.mode);

  @override
  String get id => 'projection-test:${mode.name}';

  @override
  final TextConversionMode mode;

  @override
  Future<String> convertHtml(String html) async => html;
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}
