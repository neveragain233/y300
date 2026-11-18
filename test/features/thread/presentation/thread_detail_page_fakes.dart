part of 'thread_detail_page_test.dart';

class _FakeForumHtmlReaderPreferencesRepository
    implements ForumHtmlReaderPreferencesRepository {
  _FakeForumHtmlReaderPreferencesRepository(this.current);

  ForumHtmlReaderPreferences current;

  @override
  Future<ForumHtmlReaderPreferences> load() async => current;

  @override
  Future<void> save(ForumHtmlReaderPreferences preferences) async {
    current = preferences;
  }
}

class _DelayedForumImageDimensions implements ForumImageDimensionIndex {
  final pending = Completer<ForumImageDimensions?>();
  final queriedSpecs = <ForumImageLoadSpec>[];

  @override
  Future<ForumImageDimensions?> getBySpec(ForumImageLoadSpec spec) {
    queriedSpecs.add(spec);
    return pending.future;
  }

  @override
  Future<ForumImageDimensions?> getLastKnownBySpec(ForumImageLoadSpec spec) =>
      getBySpec(spec);

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
      localPath: io.File('assets/noavatar.png').absolute.path,
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
    );
  }

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async {
    return 0;
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

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
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    requests.add(request);
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: io.File('assets/noavatar.png').absolute.path,
    );
  }
}

class _FailedThreadInlineImageCacheService extends _NoopImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) {
    // This test controls layout metadata separately from image-byte loading.
    // A finite miss avoids asynchronous file decoding and its loading spinner.
    return request.role == ImageCacheRole.threadInline
        ? Future.value(CachedImageResult.failed)
        : super.ensureCached(request);
  }
}

class _RecordingForumImagePrecacheService implements ForumImagePrecacheService {
  final decodedSpecs = <ForumImageLoadSpec>[];
  final diskSpecs = <ForumImageLoadSpec>[];

  @override
  Future<ForumImagePrecacheResult> ensureDiskCached(
    ForumImageLoadSpec spec,
  ) async {
    diskSpecs.add(spec);
    return const ForumImagePrecacheResult(success: true);
  }

  @override
  Future<ForumImagePrecacheResult> precacheDecoded({
    required BuildContext context,
    required ForumImageLoadSpec spec,
    Size? expectedDisplaySize,
  }) async {
    decodedSpecs.add(spec);
    return const ForumImagePrecacheResult(success: true, decoded: true);
  }
}

class _FakeNativePageCacheInvalidationService
    implements NativePageCacheInvalidationService {
  final invalidatedThreadIds = <String>[];
  final invalidatedForumDisplayIds = <String>[];
  var homeInvalidationCount = 0;

  @override
  Future<void> invalidateThread(String tid) async {
    invalidatedThreadIds.add(tid);
  }

  @override
  Future<void> invalidateForumDisplay(String fid) async {
    invalidatedForumDisplayIds.add(fid);
  }

  @override
  Future<void> invalidateForumHome() async {
    homeInvalidationCount++;
  }
}

ThreadPost _post({
  required String pid,
  required String author,
  required String authorId,
  required int number,
  required String message,
  bool isFirst = false,
  ThreadPostRatingSummary? ratingSummary,
}) {
  return ThreadPost(
    pid: pid,
    author: author,
    authorId: authorId,
    message: message,
    number: number,
    isFirst: isFirst,
    dateline: 'today',
    ratingSummary: ratingSummary,
  );
}

Finder _appBarTitleText(String text) {
  return find.descendant(
    of: find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(NavigationToolbar),
    ),
    matching: find.text(text),
  );
}

double _centerDxOf(WidgetTester tester, Finder finder) {
  return tester.getCenter(finder).dx;
}

/// 回复栏吸顶后目标楼对齐到栏下沿；测试按实际栏高核对落点。
double _repliesHeaderHeight(WidgetTester tester) {
  final header = find.byKey(const Key('thread-detail-sticky-replies-header'));
  if (header.evaluate().isNotEmpty) {
    return tester.getSize(header).height;
  }
  final inline = find.byKey(const Key('thread-detail-replies-header'));
  return inline.evaluate().isEmpty ? 0 : tester.getSize(inline).height;
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is RichText && widget.text.toPlainText().contains(text);
  });
}

ThreadPost _imageReturnPost(String message) => ThreadPost(
  pid: 'p1',
  author: 'alice',
  authorId: '1',
  message: message,
  number: 1,
  isFirst: true,
  dateline: 'today',
);

String _imageReturnMessage({bool duplicateFirstPair = false}) => [
  for (var index = 0; index < 14; index++)
    '<img src="https://example.com/page-${duplicateFirstPair && index == 1 ? 0 : index}.jpg" width="300" height="180">',
  for (var index = 0; index < 20; index++) '<p>Remaining post text $index</p>',
].join();

ThreadRepository _imageReturnRepository(String message) =>
    _FakeThreadRepository(
      (tid, page, query) async => ApiSuccess(
        _threadDetailData(tid: tid, posts: [_imageReturnPost(message)]),
      ),
    );

Finder _imageReturnBodyImage(int index, {bool skipOffstage = true}) =>
    find.byKey(
      Key('thread-post-html-first-readable-image-p1-$index'),
      skipOffstage: skipOffstage,
    );

ScrollableState _imageReturnScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('thread-detail-list'), skipOffstage: false),
        matching: find.byType(Scrollable, skipOffstage: false),
        skipOffstage: false,
      ),
    );

Future<ThreadImageReaderPage> _openImageReturnReader(
  WidgetTester tester,
  ThreadRepository repository, {
  int initialIndex = 0,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'reader_pref_mode': 'ltr',
  });
  tester.view.physicalSize = const Size(450, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _buildTestApp(
      repository,
      imageCacheService: _FailedThreadInlineImageCacheService(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await _tapVisibleTop(tester, _imageReturnBodyImage(initialIndex));
  await _pumpThreadUiTransition(tester);
  final reader = tester.widget<ThreadImageReaderPage>(
    find.byType(ThreadImageReaderPage),
  );
  expect(reader.onBeforeExit, isNotNull);
  return reader;
}

ThreadImageReaderExitResult _imageReturnResult(
  ThreadImageReaderPage reader,
  int index,
) {
  final entry = reader.request.group.entries[index];
  return ThreadImageReaderExitResult(
    tid: reader.request.tid,
    pid: reader.request.pid,
    indexInPost: entry.indexInPost,
    cacheKey: entry.cacheKey,
    url: entry.url,
  );
}

Future<void> _prepareImageReturn(
  WidgetTester tester,
  ThreadImageReaderPage reader,
  ThreadImageReaderExitResult result,
) async {
  var completed = false;
  final preparation = reader.onBeforeExit!(result).then(
    (_) => completed = true,
  );
  for (var attempt = 0; attempt < 20 && !completed; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    completed,
    isTrue,
    reason: 'Body positioning must finish within a bounded number of frames',
  );
  await preparation;
}

Future<void> _readImageReturnPages(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('shared-reader-right-tap-zone'))),
    );
    await tester.pump(const Duration(milliseconds: 330));
    await _pumpThreadUiTransition(tester);
  }
  final pageView = tester.widget<PageView>(
    find.byKey(const Key('thread-image-reader-page-view')),
  );
  expect(pageView.controller!.page, closeTo(count, 0.01));
}

Future<void> _pumpImageReturnTransition(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Taps near a widget's visible top edge instead of its center.
///
/// `tester.tap` aims at the center, which lands outside the viewport whenever
/// the target is taller than the remaining space — `ensureVisible` only
/// guarantees partial visibility. Full-bleed post images hit that case.
Future<void> _tapVisibleTop(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  final topLeft = tester.getTopLeft(finder);
  final size = tester.getSize(finder);
  final viewHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final viewWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final y = (topLeft.dy + 8).clamp(1.0, viewHeight - 1);
  final x = (topLeft.dx + size.width / 2).clamp(1.0, viewWidth - 1);
  await tester.tapAt(Offset(x, y));
}

Future<void> _pumpThreadUiTransition(WidgetTester tester) async {
  // A post can keep remote media loading while navigation or a bottom sheet
  // has already finished animating. Bound the UI transition instead of
  // waiting for unrelated image streams to become idle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpThreadBodyUntil(
  WidgetTester tester,
  bool Function() ready,
) async {
  // Initial preferences and the selected runtime font resolve before body
  // publication; media visibility then needs the following layout frame.
  for (var frame = 0; frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (ready()) return;
  }
  fail('Thread body did not become ready');
}

Future<void> _longPressVisibleTop(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  final topLeft = tester.getTopLeft(finder);
  final size = tester.getSize(finder);
  final viewHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final y = (topLeft.dy + 8).clamp(1.0, viewHeight - 1);
  final x = (topLeft.dx + size.width / 2).clamp(
    1.0,
    tester.view.physicalSize.width / tester.view.devicePixelRatio - 1,
  );
  await tester.longPressAt(Offset(x, y));
}

Future<void> _openPostAction(
  WidgetTester tester, {
  required Key bodyKey,
  required Key actionKey,
}) async {
  await _longPressVisibleTop(tester, find.byKey(bodyKey));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('thread-post-action-sheet')), findsOneWidget);
  await _tapPostActionSheetItem(tester, actionKey);
}

Future<void> _tapPostActionSheetItem(WidgetTester tester, Key key) async {
  final item = find.byKey(key);
  await tester.ensureVisible(item);
  await tester.pump();
  await tester.tap(item);
}

class _FakeForumTagRepository implements ForumTagRepository {
  @override
  Future<ForumTagLookup> loadLookup() async {
    return ForumTagLookup(const <ForumBoardTagSet>[
      ForumBoardTagSet(
        fid: '30',
        name: '中文百合漫画区',
        tags: <ForumTagDefinition>[
          ForumTagDefinition(fid: '30', typeid: '398', name: '韩国漫画'),
          ForumTagDefinition(fid: '30', typeid: '65', name: '公告'),
        ],
      ),
      ForumBoardTagSet(
        fid: '49',
        name: '文学区',
        tags: <ForumTagDefinition>[
          ForumTagDefinition(fid: '49', typeid: '293', name: '原创'),
          ForumTagDefinition(fid: '49', typeid: '121', name: '公告'),
        ],
      ),
    ]);
  }
}

class _FakeForumTagDirectoryRepository implements ForumTagDirectoryRepository {
  final List<ForumTagDirectoryQuery> requestedQueries =
      <ForumTagDirectoryQuery>[];

  @override
  ForumTagDirectorySourceCapabilities get capabilities =>
      ForumTagDirectorySourceCapabilities(
        values: DataCapabilitySet<ForumTagDirectoryCapability>.from(
          supported: const <ForumTagDirectoryCapability>[
            ForumTagDirectoryCapability.stableTagIdentity,
            ForumTagDirectoryCapability.orderedTopics,
            ForumTagDirectoryCapability.stableTopicIdentity,
            ForumTagDirectoryCapability.topicTitle,
            ForumTagDirectoryCapability.tagName,
            ForumTagDirectoryCapability.topicForum,
            ForumTagDirectoryCapability.topicReplyCount,
            ForumTagDirectoryCapability.topicViewCount,
            ForumTagDirectoryCapability.directionalPagination,
            ForumTagDirectoryCapability.totalPageCount,
          ],
        ),
        paginationPrecision: PaginationPrecision.exact,
      );

  @override
  Future<
    DataReadResult<ForumTagDirectoryData, ForumTagDirectoryReadCapabilities>
  >
  load(
    ForumTagDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    requestedQueries.add(query);
    return DataReadSuccess(
      data: const ForumTagDirectoryData(
        tag: ForumTagIdentity(id: '20674', name: '狱门抚子在此'),
        topics: <ForumTagTopicSummary>[
          ForumTagTopicSummary(
            tid: '549277',
            title: '狱门抚子在此 00',
            forumName: '中文百合漫画区',
            replyCount: 24,
            viewCount: 6111,
          ),
        ],
        pagination: ForumTagPagination(
          currentPage: 1,
          totalPages: 1,
          hasPrevious: false,
          hasNext: false,
        ),
      ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _FakeThreadFavoriteActionService implements ThreadFavoriteActionService {
  final DataCommandResult<ThreadFavoriteActionResult> result =
      const DataCommandApplied<ThreadFavoriteActionResult>(
        ThreadFavoriteActionResult(parseQueued: true, alreadyFavorited: false),
      );
  bool called = false;
  String? lastTid;

  @override
  Future<DataCommandResult<ThreadFavoriteActionResult>> favoriteThread({
    required String tid,
    String? title,
  }) async {
    called = true;
    lastTid = tid;
    return result;
  }
}

class _FakeThreadPollVoteCommand implements ThreadPollVoteCommand {
  bool called = false;
  ThreadPollVoteSubmission? lastSubmission;
  DataCommandResult<ThreadPollVoteReceipt> result = const DataCommandApplied(
    ThreadPollVoteReceipt(fid: '33', tid: '100', optionIds: <String>['1']),
  );

  @override
  ThreadPollVoteCapabilities get capabilities => ThreadPollVoteCapabilities(
    values: DataCapabilitySet.supported(ThreadPollVoteCapability.values),
  );

  @override
  Future<DataCommandResult<ThreadPollVoteReceipt>> execute(
    ThreadPollVoteSubmission submission,
  ) async {
    called = true;
    lastSubmission = submission;
    return result;
  }
}

class _FakeThreadPostLocator implements ThreadPostLocator {
  _FakeThreadPostLocator(this.location);

  final ThreadPostLocation? location;
  int calls = 0;
  String? lastTid;
  String? lastPid;
  Uri? lastSourceUri;

  @override
  Future<ApiResult<ThreadPostLocation>> locate({
    required String tid,
    required String pid,
    required Uri sourceUri,
  }) async {
    calls++;
    lastTid = tid;
    lastPid = pid;
    lastSourceUri = sourceUri;
    final value = location;
    if (value == null) {
      return const ApiFailure<ThreadPostLocation>(
        ApiError(type: ApiErrorType.business, message: '测试未配置楼层定位'),
      );
    }
    return ApiSuccess<ThreadPostLocation>(value);
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
  Future<Map<String, String>> syncToStore(
    Uri uri, {
    bool Function()? isCurrent,
  }) async {
    return const <String, String>{};
  }

  @override
  Future<void> clearWebViewCookies() async {}
}

class _FakeForumWebViewDriver implements ForumWebViewDriver {
  final List<Uri> loadedUris = <Uri>[];
  ForumWebViewBootstrapConfig? bootstrapConfig;
  ForumWebViewCallbacks? _callbacks;

  @override
  Widget buildWidget({Key? key}) {
    return SizedBox.expand(key: key);
  }

  @override
  Future<bool> canGoBack() async {
    return false;
  }

  @override
  Future<bool> clearCookies() async {
    return true;
  }

  @override
  Future<String?> getTitle() async {
    return '个人资料';
  }

  @override
  Future<void> goBack() async {}

  @override
  Future<void> initialize({
    required ForumWebViewCallbacks callbacks,
    required ForumWebViewBootstrapConfig bootstrapConfig,
  }) async {
    _callbacks = callbacks;
    this.bootstrapConfig = bootstrapConfig;
  }

  @override
  Future<void> load(Uri uri, {Map<String, String> headers = const {}}) async {
    loadedUris.add(uri);
    _callbacks?.onPageStarted(uri.toString());
    _callbacks?.onProgress(100);
    await _callbacks?.onPageFinished(uri.toString());
  }

  @override
  Future<ForumWebViewCapabilityProfile> probeCapabilities() async {
    return const ForumWebViewCapabilityProfile(
      documentStartMode: ForumWebViewDocumentStartMode.reliable,
      supportsContentBlockers: false,
      supportsTransparentBackground: true,
      supportsPlatformScrollTuning: true,
      supportsCookieHooks: true,
      supportsPageCommitVisible: true,
    );
  }

  @override
  Future<void> reload() async {}

  @override
  Future<void> runJavaScript(String script) async {}

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    return null;
  }

  @override
  Future<void> seedCookies({
    required String domain,
    required Map<String, String> cookies,
    String path = '/',
  }) async {}
}

class _FakeThreadPostRatingInteraction
    implements ThreadPostRatingPreparationRepository, ThreadPostRatingCommand {
  ThreadPostRatingPreparationRequest? loadedRequest;
  ThreadPostRatingSubmission? lastSubmission;

  @override
  ThreadPostRatingCapabilities get capabilities => ThreadPostRatingCapabilities(
    values: DataCapabilitySet.supported(ThreadPostRatingCapability.values),
  );

  @override
  Future<
    DataReadResult<ThreadPostRatingPreparation, ThreadPostRatingCapabilities>
  >
  load(ThreadPostRatingPreparationRequest request) async {
    loadedRequest = request;
    return DataReadSuccess(
      data: ThreadPostRatingPreparation(
        tid: request.tid,
        pid: request.pid,
        dimensions: const <ThreadPostRatingDimension>[
          ThreadPostRatingDimension(
            id: 'score1',
            label: '积分',
            minimum: 0,
            maximum: 5,
            initialScore: 0,
            todayRemaining: 10,
          ),
        ],
        reasonSuggestions: const <String>['我很赞同', '精品文章'],
        notificationPolicy: ThreadPostRatingNotificationPolicy.optional,
        notifyAuthorByDefault: false,
        token: const _FakeRatingToken(),
      ),
      capabilities: capabilities,
      metadata: const DataReadMetadata.network(),
    );
  }

  @override
  Future<DataCommandResult<ThreadPostRatingReceipt>> execute(
    ThreadPostRatingSubmission submission,
  ) async {
    lastSubmission = submission;
    return DataCommandApplied(
      ThreadPostRatingReceipt(
        tid: submission.preparation.tid,
        pid: submission.preparation.pid,
      ),
    );
  }
}

final class _FakeRatingToken implements ThreadPostRatingPreparationToken {
  const _FakeRatingToken();
}

class _FakeThreadPostRatingsRepository implements ThreadPostRatingsRepository {
  _FakeThreadPostRatingsRepository({
    List<ApiResult<ThreadPostRatingDetails>> results =
        const <ApiResult<ThreadPostRatingDetails>>[],
  }) : _results = List<ApiResult<ThreadPostRatingDetails>>.from(results);

  final List<ApiResult<ThreadPostRatingDetails>> _results;
  int loadCount = 0;
  String? loadedUrl;

  @override
  Future<ApiResult<ThreadPostRatingDetails>> loadAll(String viewAllUrl) async {
    loadCount += 1;
    loadedUrl = viewAllUrl;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (_results.isNotEmpty) {
      return _results.removeAt(0);
    }
    return const ApiSuccess<ThreadPostRatingDetails>(
      ThreadPostRatingDetails(
        participantCount: 2,
        totalScoreText: '积分 +5 点',
        ratings: <ThreadPostRating>[
          ThreadPostRating(
            userName: '子子子车',
            userId: '736594',
            score: '+2',
            reason: '我很赞同',
          ),
          ThreadPostRating(
            userName: '完整评分用户',
            score: '+3',
            reason: '补充评分',
            dateline: '2026-7-24 10:00',
          ),
        ],
      ),
    );
  }
}

class _ControlledThreadPostRatingsRepository
    implements ThreadPostRatingsRepository {
  final _result = Completer<ApiResult<ThreadPostRatingDetails>>();
  int loadCount = 0;

  @override
  Future<ApiResult<ThreadPostRatingDetails>> loadAll(String viewAllUrl) {
    loadCount += 1;
    return _result.future;
  }

  void completeSuccess() {
    _result.complete(
      const ApiSuccess<ThreadPostRatingDetails>(
        ThreadPostRatingDetails(
          participantCount: 2,
          totalScoreText: '积分 +5 点',
          ratings: <ThreadPostRating>[
            ThreadPostRating(userName: '预览用户', score: '+2', reason: '预览理由'),
            ThreadPostRating(userName: '完整评分用户', score: '+3', reason: '补充评分'),
          ],
        ),
      ),
    );
  }
}

class _FakeThreadPostCommentInteraction
    implements
        ThreadPostCommentPreparationRepository,
        ThreadPostCommentCommand {
  ThreadPostCommentPreparationRequest? loadedRequest;
  ThreadPostCommentSubmission? lastSubmission;

  @override
  ThreadPostCommentCapabilities get capabilities =>
      ThreadPostCommentCapabilities(
        values: DataCapabilitySet.supported(ThreadPostCommentCapability.values),
      );

  @override
  Future<
    DataReadResult<ThreadPostCommentPreparation, ThreadPostCommentCapabilities>
  >
  load(ThreadPostCommentPreparationRequest request) async {
    loadedRequest = request;
    return DataReadSuccess(
      data: ThreadPostCommentPreparation(
        tid: request.tid,
        pid: request.pid,
        maxLength: 200,
        token: const _FakeCommentToken(),
      ),
      capabilities: capabilities,
      metadata: const DataReadMetadata.network(),
    );
  }

  @override
  Future<DataCommandResult<ThreadPostCommentReceipt>> execute(
    ThreadPostCommentSubmission submission,
  ) async {
    lastSubmission = submission;
    return DataCommandApplied(
      ThreadPostCommentReceipt(
        tid: submission.preparation.tid,
        pid: submission.preparation.pid,
      ),
    );
  }
}

final class _FakeCommentToken implements ThreadPostCommentPreparationToken {
  const _FakeCommentToken();
}

final ThreadReplyCapabilities _threadReplyCapabilities =
    ThreadReplyCapabilities(
      values: DataCapabilitySet<ThreadReplyCapability>.supported(
        ThreadReplyCapability.values,
      ),
    );

class _FakeThreadReplyCommand implements ThreadReplyCommand {
  bool called = false;
  ThreadReplySubmission? lastSubmission;

  @override
  ThreadReplyCapabilities get capabilities => _threadReplyCapabilities;

  @override
  Future<DataCommandResult<ThreadReplyReceipt>> execute(
    ThreadReplySubmission submission,
  ) async {
    called = true;
    lastSubmission = submission;
    return const DataCommandApplied<ThreadReplyReceipt>(
      ThreadReplyReceipt(
        tid: '100',
        pid: 'p2',
        publicationState: ThreadPublicationState.published,
      ),
    );
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this._session);

  final AuthSessionViewState _session;

  @override
  Future<AuthSessionViewState> build() async => _session;
}

class _ReadingLifecycleObserver implements ThreadBodyReadingObserver {
  Completer<void>? flushGate;
  int flushCalls = 0;
  bool retired = false;
  @override
  bool tracks(String tid, String pid) => pid == '200';
  @override
  ThreadBodyRestoreTarget? restoreTarget({
    required String tid,
    required String pid,
    required Object bodyIdentity,
  }) => null;
  @override
  void onContentChanged(Object contentIdentity) {}
  @override
  void onViewport(ThreadBodyReadingViewport viewport) {}
  @override
  void onVisibility({required bool frontmost, required bool resumed}) {}
  @override
  void cancelPendingCompletion() {}
  @override
  Future<void> flush() {
    flushCalls++;
    return flushGate?.future ?? Future<void>.value();
  }

  @override
  void retire() {
    retired = true;
  }
}

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository(this._loader);

  final Function _loader;
  final List<Map<String, String>> queryHistory = <Map<String, String>>[];

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
    final queryParameters = query.toRequestParameters();
    queryHistory.add(Map<String, String>.from(queryParameters));
    final loader = _loader;
    final ApiResult<ThreadDetailData> result;
    if (loader
        is Future<ApiResult<ThreadDetailData>> Function(
          String,
          int,
          Map<String, String>,
        )) {
      result = await loader(tid, page, queryParameters);
    } else {
      result =
          await (loader
              as Future<ApiResult<ThreadDetailData>> Function(String, int))(
            tid,
            page,
          );
    }
    return dataReadResultFromApiResult(
      result,
      capabilities: capabilities.toReadCapabilities(),
    );
  }
}

final class _PageHandoff implements ThreadDetailHandoff {}

final class _HandoffThreadRepository
    implements ThreadRepository, ThreadDetailHandoffReader {
  _HandoffThreadRepository(this._handoff);

  final _PageHandoff _handoff;
  int handoffReads = 0;
  int ordinaryReads = 0;

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
    ordinaryReads++;
    return _result(page);
  }

  @override
  Future<DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities>?>
  consumeHandoff(
    ThreadDetailHandoff handoff, {
    required String tid,
    required String pid,
    required int page,
    ThreadDetailQuery query = const ThreadDetailQuery(),
  }) async {
    handoffReads++;
    if (!identical(handoff, _handoff) ||
        tid != '100' ||
        pid != '200' ||
        page != 3 ||
        !query.isEmpty) {
      return null;
    }
    return _result(page);
  }

  DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities> _result(
    int page,
  ) => DataReadSuccess(
    data: _navigationData(page, pid: '200'),
    capabilities: capabilities.toReadCapabilities(),
    metadata: const DataReadMetadata.network(),
  );
}

class _ThreadProjectionTestConverter implements TextConverter {
  _ThreadProjectionTestConverter(this.mode);

  @override
  final TextConversionMode mode;
  int callCount = 0;

  @override
  String get id => 'thread-page-test:${mode.name}';

  @override
  Future<String> convertHtml(String html) async {
    callCount += 1;
    return html
        .replaceAll('软件', '軟體')
        .replaceAll('区', '區')
        .replaceAll('主题', '主題')
        .replaceAll('内容', '內容')
        .replaceAll('发型', '髮型')
        .replaceAll('用户', '用戶')
        .replaceAll('时间', '時間');
  }
}

class _MemoryComposerDraftRepository implements ComposerDraftRepository {
  final Map<ComposerDraftIdentity, ComposerDraftSnapshot> _drafts =
      <ComposerDraftIdentity, ComposerDraftSnapshot>{};

  @override
  Future<void> deleteDraft(ComposerDraftIdentity identity) async {
    _drafts.remove(identity);
  }

  @override
  Future<ComposerDraftSnapshot?> loadDraft(
    ComposerDraftIdentity identity,
  ) async {
    return _drafts[identity];
  }

  @override
  Future<ComposerDraftPruneResult> pruneDrafts({
    Duration maxAge = const Duration(days: 30),
    int maxCount = 100,
  }) async {
    return ComposerDraftPruneResult(removedCount: 0, keptCount: _drafts.length);
  }

  @override
  Future<void> saveDraft(ComposerDraftSnapshot snapshot) async {
    _drafts[snapshot.identity] = snapshot;
  }

  @override
  Future<List<ComposerDraftSnapshot>> listDraftsForThread({
    required String fid,
    required String tid,
    String? title,
  }) async {
    return _drafts.values
        .where(
          (draft) => draft.identity.fid == fid && draft.identity.tid == tid,
        )
        .toList(growable: false);
  }
}

class _NoopComposerImagePicker implements ComposerImagePicker {
  @override
  Future<List<ComposerPickedImage>> pickImagesInOrder() async {
    return const <ComposerPickedImage>[];
  }
}

class _NoopComposerImageUploadCoordinator
    implements ComposerImageUploadCoordinator {
  @override
  void cancel() {}

  @override
  Stream<ComposerImageUploadEvent> uploadInOrder({
    required String fid,
    required List<ComposerImageAttachment> attachments,
  }) {
    return const Stream<ComposerImageUploadEvent>.empty();
  }
}

class _FakeNovelRepository implements NovelRepository {
  final Set<String> _ids = <String>{};

  @override
  Future<String> createCategory({required String name}) async => 'default';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<NovelShelfCategory>> getCategories() async {
    return <NovelShelfCategory>[
      NovelShelfCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<NovelItem?> getDetail({required String novelId}) async {
    if (!_ids.contains(novelId)) {
      return null;
    }
    return NovelItem(
      novelId: novelId,
      sourceTid: '100',
      sourceFid: '49',
      sourceTypeId: null,
      sourceTagName: null,
      title: '测试小说',
      author: '作者A',
      coverImageUrl: null,
      updatedAt: DateTime(2026, 5, 3),
      episodeCount: 1,
    );
  }

  @override
  Future<NovelChapterContent?> getChapterContent({
    required String episodeId,
  }) async => null;

  @override
  Future<List<NovelEpisodeItem>> getEpisodes({
    required String novelId,
    bool descending = false,
  }) async {
    return const <NovelEpisodeItem>[];
  }

  @override
  Future<List<NovelItem>> getShelfItems({
    String categoryId = 'default',
  }) async => const <NovelItem>[];

  @override
  Future<void> moveNovelToCategory({
    required String novelId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<NovelReadingProgress?> getReadingProgress({
    required String novelId,
  }) async => null;

  @override
  Future<void> removeFromShelf({required String novelId}) async {
    _ids.remove(novelId);
  }

  @override
  Future<void> purgeWork({required String novelId}) async {
    _ids.remove(novelId);
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> saveReadingProgress({
    required String novelId,
    required String episodeId,
    required double scrollOffset,
    NovelReaderFlowMode flowMode = NovelReaderFlowMode.vertical,
    int pageIndex = 0,
    int? pageCount,
    String? anchorNodeId,
    int anchorTextOffset = 0,
    int anchorFormatVersion = 0,
    String? anchorTextIdentity,
    bool? isProgressPercentValid,
    String? paginationKey,
    double progressPercent = 0,
  }) async {}

  @override
  Future<void> addReaderBookmark({
    required NovelReaderBookmark bookmark,
  }) async {}

  @override
  Future<List<NovelReaderBookmark>> listReaderBookmarks({
    required String novelId,
  }) async {
    return const <NovelReaderBookmark>[];
  }

  @override
  Future<void> removeReaderBookmark({required String bookmarkId}) async {}

  @override
  Future<void> toggleEpisodeBookmark({
    required String novelId,
    required String episodeId,
    required bool isBookmarked,
  }) async {}
}

ThreadPost _postWithAuthor({
  required String pid,
  required String author,
  required String authorId,
  required int number,
  bool isFirst = false,
}) {
  return ThreadPost(
    pid: pid,
    author: author,
    authorId: authorId,
    message: '<p>body</p>',
    number: number,
    isFirst: isFirst,
    dateline: 'today',
  );
}
