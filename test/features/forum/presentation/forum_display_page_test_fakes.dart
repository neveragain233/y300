part of 'forum_display_page_test.dart';

Widget _buildTestApp(
  ForumDisplayRepository repository, {
  Widget home = const ForumDisplayPage(fid: '2', title: '公告区'),
  ThreadRepository? threadRepository,
  ImageCacheService? imageCacheService,
  _FakeForumFavoriteRepository? favoriteRepository,
  List<riverpod_misc.Override> extraOverrides =
      const <riverpod_misc.Override>[],
}) {
  final overrides = [
    forumDisplayRepositoryProvider.overrideWithValue(repository),
    imageCacheServiceProvider.overrideWithValue(
      imageCacheService ?? _NoopImageCacheService(),
    ),
    if (favoriteRepository != null)
      favoriteForumCommandProvider.overrideWithValue(favoriteRepository),
    if (favoriteRepository != null)
      favoriteForumDirectoryRepositoryProvider.overrideWithValue(
        favoriteRepository.directory,
      ),
    if (threadRepository != null)
      threadRepositoryProvider.overrideWithValue(threadRepository),
    ...extraOverrides,
  ];
  return ProviderScope(
    overrides: overrides,
    child: LocalizedTestApp(home: home),
  );
}

void _expectCardFullyVisible(WidgetTester tester, String tid) {
  final card = find.byKey(Key('forum-thread-$tid'));
  expect(card, findsOneWidget);
  final ancestors = find
      .ancestor(of: card, matching: find.byType(FadeTransition))
      .evaluate()
      .toSet();
  // The route may still animate; only inspect fades inside the list itself.
  final listFades = find
      .descendant(
        of: find.byKey(const Key('forum-display-list')),
        matching: find.byType(FadeTransition),
      )
      .evaluate()
      .where(ancestors.contains);
  for (final element in listFades) {
    expect(
      (element.widget as FadeTransition).opacity.value,
      1,
      reason: 'Ready card content must not start transparent.',
    );
  }
}

ForumDisplayData _displayData({
  String fid = '2',
  required int page,
  required int total,
  required List<ForumThreadSummary> threads,
  int todayPosts = 3,
  int rank = 1,
  List<ForumDisplayTopEntry>? topEntries,
  String? headImageUrl,
  List<ForumDisplaySubForum>? subForums,
  int? lastPage,
  ForumDisplayFavoriteAction favoriteAction =
      ForumDisplayFavoriteAction.unknown,
}) {
  return ForumDisplayData(
    fid: fid,
    forumName: '公告区',
    currentPage: page,
    perPage: 1,
    totalThreads: total,
    headImageUrl: headImageUrl,
    todayPosts: todayPosts,
    rank: rank,
    lastPage: lastPage,
    previousPageUrl: page > 1
        ? 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&page=${page - 1}&mobile=2'
        : null,
    nextPageUrl: page < (lastPage ?? total)
        ? 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&page=${page + 1}&mobile=2'
        : null,
    hasMoreOverride: page < (lastPage ?? total),
    favoriteAction: favoriteAction,
    primaryFilters: const <ForumDisplayFilterItem>[
      ForumDisplayFilterItem(
        label: '全部',
        url: 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&mobile=2',
        isSelected: true,
      ),
      ForumDisplayFilterItem(
        label: '最新',
        url: 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&filter=lastpost&mobile=2',
      ),
    ],
    typeFilters: const <ForumDisplayFilterItem>[
      ForumDisplayFilterItem(
        label: '公告',
        url: 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&filter=typeid&typeid=65&mobile=2',
        typeid: '65',
      ),
    ],
    subForums: subForums ?? const <ForumDisplaySubForum>[],
    topEntries:
        topEntries ??
        const <ForumDisplayTopEntry>[
          ForumDisplayTopEntry(
            title: '欢迎光临。',
            url: 'https://bbs.yamibo.com/forum.php?mod=announcement&id=17',
            badgeLabel: '公告',
            isAnnouncement: true,
          ),
        ],
    threads: threads,
  );
}

List<ForumThreadSummary> _manyThreads({
  required String suffix,
  required int count,
  bool includeTagUrl = false,
}) {
  return [
    for (var index = 0; index < count; index++)
      ForumThreadSummary(
        tid: '$suffix-$index',
        subject: '帖子 $suffix-$index',
        author: 'alice',
        replies: index,
        views: 100 + index,
        dateline: 'today',
        excerpt: '用于制造滚动空间的摘要 $index',
        sourceTagName: '長篇連載',
        sourceTagUrl: includeTagUrl
            ? 'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&filter=typeid&typeid=69&mobile=2'
            : null,
      ),
  ];
}

Future<void> _dragWellPastFilter(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('forum-display-list')),
    const Offset(0, -620),
  );
  await tester.pumpAndSettle();
}

Future<void> _jumpNearBottomAndTap(WidgetTester tester, Finder finder) async {
  await _dragWellPastFilter(tester);
  final position = _scrollPosition(tester);
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

double _scrollOffset(WidgetTester tester) {
  return _scrollPosition(tester).pixels;
}

ScrollPosition _scrollPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byKey(const Key('forum-display-list')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  return tester.state<ScrollableState>(scrollable).position;
}

void _expectReturnedToFilterStart(WidgetTester tester, double expectedOffset) {
  expect((_scrollOffset(tester) - expectedOffset).abs(), lessThanOrEqualTo(1));
}

BoxDecoration _decorationAroundText(WidgetTester tester, String text) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(text), matching: find.byType(DecoratedBox))
        .first,
  );
  return decoratedBox.decoration as BoxDecoration;
}

class _FakeForumDisplayRepository implements ForumDisplayRepository {
  _FakeForumDisplayRepository(this._loader);

  final Future<ApiResult<ForumDisplayData>> Function(
    String fid,
    int page,
    ForumDisplayQuery? query,
  )
  _loader;
  ForumDisplayQuery? lastQuery;
  final cachePolicies = <CacheLoadPolicy>[];

  @override
  ForumDisplaySourceCapabilities get capabilities =>
      ForumDisplaySourceCapabilities.full;

  @override
  Future<DataReadResult<ForumDisplayData, ForumDisplayReadCapabilities>>
  getForumDisplayByQuery(
    ForumDisplayQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    lastQuery = query;
    cachePolicies.add(cachePolicy);
    return dataReadResultFromApiResult(
      await _loader(query.fid, query.page, query),
      capabilities: capabilities.toReadCapabilities(),
    );
  }
}

FavoriteForumEntry _favoriteForum({
  required String fid,
  required String favid,
  required String title,
}) {
  return FavoriteForumEntry(
    fid: fid,
    title: title,
    remoteFavoriteId: favid,
    description: '',
    threadCount: 0,
    postCount: 0,
    todayPostCount: 0,
  );
}

class _FakeForumFavoriteRepository implements FavoriteForumCommand {
  _FakeForumFavoriteRepository({List<FavoriteForumEntry>? favoriteForums})
    : directory = _FakeFavoriteForumDirectoryRepository(
        favoriteForums ?? <FavoriteForumEntry>[],
      );

  final _FakeFavoriteForumDirectoryRepository directory;
  final favoriteFids = <String>[];
  final unfavoriteFavids = <String>[];
  final commandRequests = <SetForumFavoriteRequest>[];

  @override
  FavoriteMutationCapabilities get capabilities =>
      allFavoriteMutationCapabilities;

  @override
  Future<DataCommandResult<ForumFavoriteReceipt>> execute(
    SetForumFavoriteRequest request,
  ) async {
    commandRequests.add(request);
    if (request.targetState == FavoriteTargetState.favorited) {
      favoriteFids.add(request.fid);
      return appliedForumFavorite(
        fid: request.fid,
        targetState: request.targetState,
      );
    }
    FavoriteForumEntry? entry;
    for (final item in directory.favoriteForums) {
      if (item.fid == request.fid) {
        entry = item;
        break;
      }
    }
    final favid = entry?.remoteFavoriteId;
    if (favid != null) {
      unfavoriteFavids.add(favid);
    }
    return appliedForumFavorite(
      fid: request.fid,
      targetState: request.targetState,
      remoteFavoriteId: favid,
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
      _favoriteForumDirectoryCapabilities;

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

final _favoriteForumDirectoryCapabilities =
    FavoriteForumDirectorySourceCapabilities(
      values: DataCapabilitySet<FavoriteForumDirectoryCapability>.supported(
        FavoriteForumDirectoryCapability.values,
      ),
    );

class _ProjectionPrefixBatchConversionService
    implements PlainTextBatchConversionService {
  int callCount = 0;

  @override
  Future<List<String>> convertAll({
    required List<String> sources,
    required TextConverter converter,
  }) async {
    callCount += 1;
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

class _FixedForumImageDimensionIndex implements ForumImageDimensionIndex {
  const _FixedForumImageDimensionIndex(this.dimensions);

  final ForumImageDimensions? dimensions;

  @override
  Future<ForumImageDimensions?> getBySpec(ForumImageLoadSpec spec) async {
    return dimensions;
  }

  @override
  Future<ForumImageDimensions?> getLastKnownBySpec(
    ForumImageLoadSpec spec,
  ) async {
    return dimensions;
  }

  @override
  Future<void> recordDecodedDimensions({
    required ForumImageLoadSpec spec,
    required Size size,
  }) async {}
}

class _NoopImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: 'memory://${request.cacheKey}',
      fromCache: true,
    );
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: request.sourcePath,
      fromCache: true,
    );
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async => 0;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}
}

class _RecordingImageCacheService extends _NoopImageCacheService {
  final requests = <ImageCacheRequest>[];

  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) {
    requests.add(request);
    return super.ensureCached(request);
  }
}

class _FakeThreadRepository implements ThreadRepository {
  @override
  ThreadDetailSourceCapabilities get capabilities =>
      ThreadDetailSourceCapabilities.full;

  @override
  Future<DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities>>
  getThreadDetail({
    required String tid,
    int page = 1,
    ThreadDetailQuery query = const ThreadDetailQuery(),
  }) async {
    return DataReadSuccess(
      data: ThreadDetailData(
        tid: tid,
        fid: '2',
        forumName: '公告区',
        subject: '帖子A',
        author: 'alice',
        replies: 0,
        views: 1,
        currentPage: 1,
        perPage: 20,
        posts: [
          ThreadPost(
            pid: 'p1',
            author: 'alice',
            authorId: '1',
            message: '<p>正文</p>',
            number: 1,
            isFirst: true,
            dateline: 'today',
          ),
        ],
      ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

ForumThreadSummary _blockedTestThread({
  required String tid,
  required String subject,
  String uid = '',
}) {
  return ForumThreadSummary(
    tid: tid,
    subject: subject,
    uid: uid,
    author: 'alice',
    replies: 0,
    views: 1,
    dateline: 'today',
  );
}

void _seedBlockedThreads(Map<String, String> subjects) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'content_filter.blocked_threads.v1': jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'threads': [
        for (final entry in subjects.entries)
          <String, Object?>{
            'tid': entry.key,
            'subject': entry.value,
            'blockedAt': 1000,
          },
      ],
    }),
  });
}
