part of 'thread_detail_page_test.dart';

void _seedBlockedThread({required String tid, required String subject}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'content_filter.blocked_threads.v1': jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'threads': [
        <String, Object?>{'tid': tid, 'subject': subject, 'blockedAt': 1000},
      ],
    }),
  });
}

final commentsCapabilities = ThreadPostCommentsReadCapabilities(
  values: DataCapabilitySet.supported(ThreadPostCommentsCapability.values),
);

forum_client.YamiboForumClient _clientWithPagedComments(
  ThreadPostCommentsRepository repository,
) => forum_client.YamiboForumClient(
  config: forum_client.ForumClientConfig(
    siteOrigin: Uri.parse('https://bbs.example.test'),
    apiOrigin: Uri.parse('https://api.example.test/mobile/index.php'),
    userAgent: 'test',
    desktopUserAgent: 'test',
  ),
  network: _UnusedForumNetwork(),
  sourcePlan: forum_client.ForumClientSourcePlan(postComments: repository),
);

final class _FakePagedCommentsRepository
    implements ThreadPostCommentsRepository {
  _FakePagedCommentsRepository(this._load);

  final Future<
    DataReadResult<ThreadPostCommentsPage, ThreadPostCommentsReadCapabilities>
  >
  Function(ThreadPostCommentsQuery)
  _load;
  final List<ThreadPostCommentsQuery> queries = [];

  @override
  ThreadPostCommentsSourceCapabilities get capabilities =>
      ThreadPostCommentsSourceCapabilities(
        values: DataCapabilitySet.supported(
          ThreadPostCommentsCapability.values,
        ),
      );

  @override
  Future<
    DataReadResult<ThreadPostCommentsPage, ThreadPostCommentsReadCapabilities>
  >
  load(
    ThreadPostCommentsQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.networkFirst,
  }) {
    queries.add(query);
    return _load(query);
  }
}

final class _UnusedForumNetwork implements forum_client.ForumClientNetwork {
  @override
  Future<forum_client.ForumTransportResult<forum_client.ForumResponse<Object?>>>
  send(forum_client.ForumRequest request) {
    throw StateError('The comment repository should handle this read');
  }
}

ThreadDetailData _navigationData(int page, {required String pid}) =>
    ThreadDetailData(
      tid: '100',
      fid: '33',
      subject: 'Navigation fixture',
      author: 'Author',
      replies: 60,
      views: 1,
      currentPage: page,
      perPage: 20,
      lastPage: 4,
      posts: [
        ThreadPost(
          pid: pid,
          author: 'Author',
          authorId: '10',
          message: '<p>Verified body</p>',
          number: 21,
          isFirst: false,
          dateline: '',
        ),
      ],
    );

Widget _buildTestApp(
  ThreadRepository repository, {
  ThreadReplyCommand? replyRepository,
  NovelRepository? novelRepository,
  ThreadFavoriteActionService? favoriteActionService,
  _FakeThreadPostRatingInteraction? postRateInteraction,
  ThreadPostRatingsRepository? postRatingsRepository,
  _FakeThreadPostCommentInteraction? postCommentInteraction,
  ThreadPollVoteCommand? pollVoteCommand,
  ForumTagDirectoryRepository? tagDirectoryRepository,
  ThreadPostLocator? threadPostLocator,
  NativePageCacheInvalidationService? pageCacheInvalidationService,
  ImageCacheService? imageCacheService,
  ForumImagePrecacheService? forumImagePrecacheService,
  ForumWebViewDriverFactory? forumWebViewDriverFactory,
  ForumHtmlReaderPreferencesRepository? forumHtmlReaderPreferencesRepository,
  HistoryVisitRecorder? historyVisitRecorder,
  HistoryDiagnosticRecorder? historyDiagnosticRecorder,
  List<riverpod_misc.Override> additionalOverrides =
      const <riverpod_misc.Override>[],
  Widget? home,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: <riverpod_misc.Override>[
      ..._threadDetailOverrides(
        repository,
        replyRepository: replyRepository,
        novelRepository: novelRepository,
        favoriteActionService: favoriteActionService,
        postRateInteraction: postRateInteraction,
        postRatingsRepository: postRatingsRepository,
        postCommentInteraction: postCommentInteraction,
        pollVoteCommand: pollVoteCommand,
        tagDirectoryRepository: tagDirectoryRepository,
        threadPostLocator: threadPostLocator,
        pageCacheInvalidationService: pageCacheInvalidationService,
        imageCacheService: imageCacheService,
        forumImagePrecacheService: forumImagePrecacheService,
        forumWebViewDriverFactory: forumWebViewDriverFactory,
        forumHtmlReaderPreferencesRepository:
            forumHtmlReaderPreferencesRepository,
        historyVisitRecorder: historyVisitRecorder,
        historyDiagnosticRecorder: historyDiagnosticRecorder,
      ),
      ...additionalOverrides,
    ],
    child: LocalizedTestApp(
      theme: theme,
      home: home ?? const ThreadDetailPage(tid: '100', subject: '测试主题'),
    ),
  );
}

List<riverpod_misc.Override> _threadDetailOverrides(
  ThreadRepository repository, {
  ThreadReplyCommand? replyRepository,
  NovelRepository? novelRepository,
  ThreadFavoriteActionService? favoriteActionService,
  _FakeThreadPostRatingInteraction? postRateInteraction,
  ThreadPostRatingsRepository? postRatingsRepository,
  _FakeThreadPostCommentInteraction? postCommentInteraction,
  ThreadPollVoteCommand? pollVoteCommand,
  ForumTagDirectoryRepository? tagDirectoryRepository,
  ThreadPostLocator? threadPostLocator,
  NativePageCacheInvalidationService? pageCacheInvalidationService,
  ImageCacheService? imageCacheService,
  ForumImagePrecacheService? forumImagePrecacheService,
  ForumWebViewDriverFactory? forumWebViewDriverFactory,
  ForumHtmlReaderPreferencesRepository? forumHtmlReaderPreferencesRepository,
  HistoryVisitRecorder? historyVisitRecorder,
  HistoryDiagnosticRecorder? historyDiagnosticRecorder,
}) {
  return [
    historyVisitRecorderProvider.overrideWithValue(
      historyVisitRecorder ?? const _NoopHistoryVisitRecorder(),
    ),
    historyDiagnosticRecorderProvider.overrideWithValue(
      historyDiagnosticRecorder ?? const NoopHistoryDiagnosticRecorder(),
    ),
    threadRepositoryProvider.overrideWithValue(repository),
    if (forumHtmlReaderPreferencesRepository != null)
      forumHtmlReaderPreferencesRepositoryProvider.overrideWithValue(
        forumHtmlReaderPreferencesRepository,
      ),
    imageCacheServiceProvider.overrideWithValue(
      imageCacheService ?? _NoopImageCacheService(),
    ),
    if (forumImagePrecacheService != null)
      forumImagePrecacheServiceProvider.overrideWithValue(
        forumImagePrecacheService,
      ),
    nativePageCacheInvalidationServiceProvider.overrideWithValue(
      pageCacheInvalidationService ?? _FakeNativePageCacheInvalidationService(),
    ),
    novelRepositoryProvider.overrideWithValue(
      novelRepository ?? _FakeNovelRepository(),
    ),
    threadReplyCommandProvider.overrideWithValue(
      replyRepository ?? _FakeThreadReplyCommand(),
    ),
    threadFavoriteActionServiceProvider.overrideWithValue(
      favoriteActionService ?? _FakeThreadFavoriteActionService(),
    ),
    threadPostRatingPreparationProvider.overrideWithValue(
      postRateInteraction ?? _FakeThreadPostRatingInteraction(),
    ),
    threadPostRatingCommandProvider.overrideWithValue(
      postRateInteraction ?? _FakeThreadPostRatingInteraction(),
    ),
    threadPostRatingsRepositoryProvider.overrideWithValue(
      postRatingsRepository ?? _FakeThreadPostRatingsRepository(),
    ),
    threadPostCommentPreparationProvider.overrideWithValue(
      postCommentInteraction ?? _FakeThreadPostCommentInteraction(),
    ),
    threadPostCommentCommandProvider.overrideWithValue(
      postCommentInteraction ?? _FakeThreadPostCommentInteraction(),
    ),
    threadPollVoteCommandProvider.overrideWithValue(
      pollVoteCommand ?? _FakeThreadPollVoteCommand(),
    ),
    threadPostLocatorProvider.overrideWithValue(
      threadPostLocator ?? _FakeThreadPostLocator(null),
    ),
    forumWebViewDriverFactoryProvider.overrideWith(
      (ref) => forumWebViewDriverFactory ?? _FakeForumWebViewDriver.new,
    ),
    cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
    webViewCookieSyncServiceProvider.overrideWithValue(
      _FakeWebViewCookieSyncService(),
    ),
    favoriteForumCommandProvider.overrideWithValue(FakeFavoriteForumCommand()),
    forumTagRepositoryProvider.overrideWithValue(_FakeForumTagRepository()),
    forumTagDirectoryRepositoryProvider.overrideWithValue(
      tagDirectoryRepository ?? _FakeForumTagDirectoryRepository(),
    ),
    composerDraftRepositoryProvider.overrideWithValue(
      _MemoryComposerDraftRepository(),
    ),
    composerImagePickerProvider.overrideWithValue(_NoopComposerImagePicker()),
    composerImageUploadCoordinatorProvider.overrideWithValue(
      _NoopComposerImageUploadCoordinator(),
    ),
  ];
}

class _RecordingHistoryVisitRecorder implements HistoryVisitRecorder {
  final List<HistoryVisitDraft> drafts = <HistoryVisitDraft>[];

  @override
  Future<void> record(HistoryVisitDraft draft) async {
    drafts.add(draft);
  }
}

class _ThrowingHistoryVisitRecorder implements HistoryVisitRecorder {
  const _ThrowingHistoryVisitRecorder();

  @override
  Future<void> record(HistoryVisitDraft draft) {
    throw StateError('history unavailable');
  }
}

class _NoopHistoryVisitRecorder implements HistoryVisitRecorder {
  const _NoopHistoryVisitRecorder();

  @override
  Future<void> record(HistoryVisitDraft draft) async {}
}

class _RecordingHistoryDiagnostics implements HistoryDiagnosticRecorder {
  final List<String> skipReasons = <String>[];

  @override
  void recordQuery({
    required HistoryDiagnosticOutcome outcome,
    required int elapsedMs,
    required bool searching,
    int? itemCount,
    bool? hasMore,
    String? errorType,
  }) {}

  @override
  void recordSkip({
    required HistoryVisitSurface surface,
    required String reason,
  }) {
    skipReasons.add(reason);
  }

  @override
  void recordWrite({
    required HistoryTargetType targetType,
    required HistoryVisitSurface surface,
    required HistoryDiagnosticOutcome outcome,
    required int elapsedMs,
    String? errorType,
  }) {}
}

ThreadDetailData _threadDetailData({
  required String tid,
  required List<ThreadPost> posts,
  String subject = '测试主题',
  int currentPage = 1,
  int lastPage = 1,
}) {
  return ThreadDetailData(
    tid: tid,
    fid: '2',
    subject: subject,
    author: 'alice',
    replies: posts.length,
    views: 12,
    currentPage: currentPage,
    lastPage: lastPage,
    perPage: posts.length,
    posts: posts,
  );
}
