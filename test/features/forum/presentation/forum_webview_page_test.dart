import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:y300/app/navigation/forum_link_routes.dart';
import 'package:y300/features/forum/domain/services/yamibo_forum_link_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/clipboard/clipboard_providers.dart';
import 'package:y300/core/clipboard/clipboard_text_writer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/localization/app_server_content_conversion_provider.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/core/network/cookie_store.dart';
import 'package:y300/core/network/webview_cookie_sync_service.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/favorites/data/providers/favorite_directory_providers.dart';
import 'package:y300/features/forum/data/services/forum_webview_redirect_resolver.dart';
import 'package:y300/features/composer_shared/domain/repositories/composer_draft_repository.dart';
import 'package:y300/features/composer_shared/data/providers/composer_providers.dart';
import 'package:y300/features/composer_shared/domain/models/composer_draft_models.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_controller.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_driver.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_external_launcher.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_page.dart';
import 'package:y300/features/history/data/providers/history_providers.dart';
import 'package:y300/features/history/domain/models/history_models.dart';
import 'package:y300/features/history/domain/services/history_visit_recorder.dart';
import 'package:y300/features/posting/data/providers/posting_providers.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/profile/data/providers/thread_read_providers.dart';
import 'package:y300/features/profile/data/providers/friend_read_providers.dart';
import 'package:y300/features/profile/presentation/friends/my_friends_page.dart';
import 'package:y300/features/profile/presentation/threads/user_thread_page.dart';

import '../../profile/test_support/thread_directory_fixture.dart';
import '../../profile/test_support/friend_read_fixture.dart';

import 'package:y300/features/reply/data/providers/reply_providers.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter_factory.dart';
import 'package:y300/features/tags/data/repositories/forum_tag_repository.dart';
import 'package:y300/features/tags/data/providers/tag_providers.dart';
import 'package:y300/features/tags/domain/forum_tag_lookup.dart';
import 'package:y300/features/tags/domain/forum_tag_models.dart';
import 'package:y300/features/thread/data/providers/thread_repository_providers.dart';
import 'package:y300/features/thread/data/services/thread_post_locator.dart';
import 'package:y300/features/thread/presentation/thread_detail_page.dart';

import '../../../support/favorite_command_test_support.dart';

part 'forum_webview_page_navigation_cases.dart';
part 'forum_webview_page_session_cases.dart';
part 'forum_webview_page_toolbar_cases.dart';
part 'forum_webview_page_back_cases.dart';
part 'forum_webview_page_page_shell_cases.dart';
part 'forum_webview_page_page_commit_cases.dart';
part 'forum_webview_page_callback_cases.dart';
part 'forum_webview_page_interception_cases.dart';

Matcher containsCssSelector(String selector) {
  final escapedSelector = RegExp.escape(selector);
  return contains(
    RegExp('(^|[^A-Za-z0-9_-])$escapedSelector(?=\$|[^A-Za-z0-9_-])'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  _navigationCases();
  _unboundSessionCookieCases();
  _unknownThreadFilterCases();
  _pendingCookieSyncCases();
  _profileAppBarCases();
  _routeBackCases();
  _bootstrapShellCases();
  _conversionModeCases();
  _homeShellCases();
  _earlyUserScriptCases();
  _homeChromeCases();
  _threadChromeCases();
  _searchChromeCases();
  _surfaceCases();
  _searchNavigationCases();
  _staleGenerationCases();
  _pageCommitRecordingCases();
  _refreshIndicatorCases();
  _refreshActionCases();
  _managedLinkCases();
  _postEditFallbackCases();
  _findpostRedirectCases();
  _friendAndDirectoryCallbackCases();
  _nativeThreadNavigationCases();
  _externalLinkInterceptionCases();
  _toolbarMenuCases();
  _composerInterceptionCases();
  _threadToolbarCases();
  _backCases();
}

Future<void> _pumpRouteWithoutSettlingEditor(
  WidgetTester tester, {
  Finder? readyWhen,
  bool requireEnabled = false,
}) async {
  // The composer intentionally keeps a caret animation alive. Waiting for
  // the route and its async controller to expose a real widget is sufficient;
  // pumpAndSettle would never converge while the editor caret is active.
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (readyWhen == null ||
        _isVisibleAndReady(tester, readyWhen, requireEnabled: requireEnabled)) {
      return;
    }
  }
  if (readyWhen != null) {
    expect(readyWhen, findsOneWidget);
  }
}

bool _isVisibleAndReady(
  WidgetTester tester,
  Finder finder, {
  required bool requireEnabled,
}) {
  final elements = finder.evaluate().toList(growable: false);
  if (elements.isEmpty) {
    return false;
  }
  if (requireEnabled &&
      elements.every(
        (element) =>
            element.widget is IconButton &&
            (element.widget as IconButton).onPressed == null,
      )) {
    return false;
  }
  final rect = tester.getRect(finder);
  final renderViews = tester.binding.renderViews;
  if (renderViews.isEmpty) {
    return false;
  }
  final viewport = Offset.zero & renderViews.first.size;
  return rect.left >= viewport.left &&
      rect.top >= viewport.top &&
      rect.right <= viewport.right &&
      rect.bottom <= viewport.bottom;
}

Widget _buildTestApp({
  required _FakeForumWebViewDriver driver,
  bool Function()? isAccountCurrent,
  CookieStore? cookieStore,
  ForumTagRepository? tagRepository,
  _FakeForumFavoriteRepository? favoriteRepository,
  ForumWebViewExternalLauncher? launcher,
  ClipboardTextWriter? clipboardWriter,
  _FakeThreadReplyAdapter? replyRepository,
  ComposerDraftRepository? replyDraftRepository,
  ThreadCreationPreparationRepository? postingFormMetadataRepository,
  ThreadCreationCommand? newThreadRepository,
  ForumWebViewNavigationPolicy navigationPolicy =
      ForumWebViewNavigationPolicy.keepWebView,
  WebViewCookieSyncService? cookieSyncService,
  ThreadRepository? threadRepository,
  ThreadPostLocator? threadPostLocator,
  ForumWebViewRedirectResolver? redirectResolver,
  HistoryVisitRecorder? historyRecorder,
  UserThreadDirectoryRepository? threadDirectory,
  ForumFriendFeedRepository? friendFeed,
  VerifiedSessionOwner? profileOwner = (uid: '101', revision: 0),
  ForumWebViewHostPurpose? hostPurpose,
}) {
  final resolvedFavoriteRepository =
      favoriteRepository ?? _FakeForumFavoriteRepository();
  return ProviderScope(
    overrides: [
      if (hostPurpose != null)
        forumWebViewHostPurposeProvider.overrideWithValue(hostPurpose),
      if (threadDirectory != null || friendFeed != null)
        verifiedSessionOwnerProvider.overrideWithValue(profileOwner),
      if (threadDirectory != null)
        userThreadDirectoryRepositoryProvider.overrideWithValue(
          threadDirectory,
        ),
      if (friendFeed != null) ...[
        friendFeedRepositoryProvider.overrideWithValue(friendFeed),
        friendRemovalCommandProvider.overrideWithValue(FriendRemovalFixture()),
      ],
      forumWebViewNavigationPolicyProvider.overrideWithValue(navigationPolicy),
      if (cookieSyncService != null)
        webViewCookieSyncServiceProvider.overrideWithValue(cookieSyncService),
      forumWebViewDriverProvider.overrideWith((ref) => driver),
      forumWebViewExternalLauncherProvider.overrideWithValue(
        launcher ?? _FakeForumWebViewExternalLauncher(),
      ),
      if (clipboardWriter != null)
        clipboardTextWriterProvider.overrideWithValue(clipboardWriter),
      cookieStoreProvider.overrideWithValue(cookieStore ?? _FakeCookieStore()),
      forumTagRepositoryProvider.overrideWithValue(
        tagRepository ?? _FakeForumTagRepository(),
      ),
      favoriteForumCommandProvider.overrideWithValue(
        resolvedFavoriteRepository,
      ),
      favoriteForumDirectoryRepositoryProvider.overrideWithValue(
        resolvedFavoriteRepository.directory,
      ),
      threadReplyPreparationProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      threadReplyCommandProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      composerDraftRepositoryProvider.overrideWithValue(
        replyDraftRepository ?? _MemoryComposerDraftRepository(),
      ),
      threadCreationPreparationProvider.overrideWithValue(
        postingFormMetadataRepository ??
            _FakeThreadCreationPreparationRepository(),
      ),
      threadCreationCommandProvider.overrideWithValue(
        newThreadRepository ?? _FakeThreadCreationCommand(),
      ),
      threadRepositoryProvider.overrideWithValue(
        threadRepository ?? _FakeThreadRepository(),
      ),
      threadPostLocatorProvider.overrideWithValue(
        threadPostLocator ?? _FakeThreadPostLocator(null),
      ),
      forumWebViewRedirectResolverProvider.overrideWithValue(
        redirectResolver ?? _FakeForumWebViewRedirectResolver(),
      ),
      imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
      historyVisitRecorderProvider.overrideWithValue(
        historyRecorder ?? _NoopHistoryVisitRecorder(),
      ),
    ],
    child: LocalizedTestApp(
      home: ForumWebViewPage(isAccountCurrent: isAccountCurrent),
    ),
  );
}

Widget _buildRoutedTestApp({
  required _FakeForumWebViewDriver driver,
  CookieStore? cookieStore,
  ForumTagRepository? tagRepository,
  _FakeForumFavoriteRepository? favoriteRepository,
  ForumWebViewExternalLauncher? launcher,
  _FakeThreadReplyAdapter? replyRepository,
  ComposerDraftRepository? replyDraftRepository,
  ThreadCreationPreparationRepository? postingFormMetadataRepository,
  ThreadCreationCommand? newThreadRepository,
  ForumWebViewNavigationPolicy navigationPolicy =
      ForumWebViewNavigationPolicy.keepWebView,
  WebViewCookieSyncService? cookieSyncService,
  ThreadRepository? threadRepository,
  ThreadPostLocator? threadPostLocator,
  ForumWebViewRedirectResolver? redirectResolver,
  HistoryVisitRecorder? historyRecorder,
}) {
  final resolvedFavoriteRepository =
      favoriteRepository ?? _FakeForumFavoriteRepository();
  return ProviderScope(
    overrides: [
      forumWebViewNavigationPolicyProvider.overrideWithValue(navigationPolicy),
      if (cookieSyncService != null)
        webViewCookieSyncServiceProvider.overrideWithValue(cookieSyncService),
      forumWebViewDriverProvider.overrideWith((ref) => driver),
      forumWebViewExternalLauncherProvider.overrideWithValue(
        launcher ?? _FakeForumWebViewExternalLauncher(),
      ),
      cookieStoreProvider.overrideWithValue(cookieStore ?? _FakeCookieStore()),
      forumTagRepositoryProvider.overrideWithValue(
        tagRepository ?? _FakeForumTagRepository(),
      ),
      favoriteForumCommandProvider.overrideWithValue(
        resolvedFavoriteRepository,
      ),
      favoriteForumDirectoryRepositoryProvider.overrideWithValue(
        resolvedFavoriteRepository.directory,
      ),
      threadReplyPreparationProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      threadReplyCommandProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      composerDraftRepositoryProvider.overrideWithValue(
        replyDraftRepository ?? _MemoryComposerDraftRepository(),
      ),
      threadCreationPreparationProvider.overrideWithValue(
        postingFormMetadataRepository ??
            _FakeThreadCreationPreparationRepository(),
      ),
      threadCreationCommandProvider.overrideWithValue(
        newThreadRepository ?? _FakeThreadCreationCommand(),
      ),
      threadRepositoryProvider.overrideWithValue(
        threadRepository ?? _FakeThreadRepository(),
      ),
      threadPostLocatorProvider.overrideWithValue(
        threadPostLocator ?? _FakeThreadPostLocator(null),
      ),
      forumWebViewRedirectResolverProvider.overrideWithValue(
        redirectResolver ?? _FakeForumWebViewRedirectResolver(),
      ),
      imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
      historyVisitRecorderProvider.overrideWithValue(
        historyRecorder ?? _NoopHistoryVisitRecorder(),
      ),
    ],
    child: LocalizedTestApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-forum-webview-page'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ForumWebViewPage(),
                    ),
                  );
                },
                child: const Text('打开论坛 WebView'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Object _threadDocumentResult({
  required String title,
  String? forumName,
  String? canonicalHref,
  int postCount = 1,
}) {
  return jsonEncode(<String, Object?>{
    'title': title,
    'forumName': forumName,
    'canonicalHref': canonicalHref,
    'firstPostImageHref': '/data/attachment/forum/cover.jpg',
    'postCount': postCount,
  });
}

class _RecordingHistoryVisitRecorder implements HistoryVisitRecorder {
  final List<HistoryVisitDraft> drafts = <HistoryVisitDraft>[];

  @override
  Future<void> record(HistoryVisitDraft draft) async {
    drafts.add(draft);
  }
}

class _NoopHistoryVisitRecorder implements HistoryVisitRecorder {
  @override
  Future<void> record(HistoryVisitDraft draft) async {}
}

class _FakeForumWebViewDriver implements ForumWebViewDriver {
  final List<String> events = <String>[];
  final List<Uri> loadedUris = <Uri>[];
  final List<_LoadRequestRecord> loadRequests = <_LoadRequestRecord>[];
  final List<String> scripts = <String>[];
  final List<String> returningScripts = <String>[];
  final List<_SeededCookieRecord> seededCookies = <_SeededCookieRecord>[];
  String? title;
  bool holdTitleReads = false;
  final List<Completer<String?>> pendingTitleReads = <Completer<String?>>[];
  Object? javaScriptResult;
  bool canGoBackValue = false;
  int goBackCallCount = 0;
  int reloadCallCount = 0;
  int buildWidgetCallCount = 0;
  int probeCapabilitiesCallCount = 0;
  ForumWebViewBootstrapConfig? bootstrapConfig;
  ForumWebViewCapabilityProfile capabilityProfile =
      const ForumWebViewCapabilityProfile(
        documentStartMode: ForumWebViewDocumentStartMode.reliable,
        supportsContentBlockers: false,
        supportsTransparentBackground: true,
        supportsPlatformScrollTuning: true,
        supportsCookieHooks: true,
        supportsPageCommitVisible: true,
      );
  ForumWebViewCallbacks? _callbacks;

  @override
  Widget buildWidget({Key? key}) {
    buildWidgetCallCount += 1;
    return Container(key: key);
  }

  Future<void> dispatchPageStarted(String url) async {
    final callbacks = _callbacks;
    if (callbacks == null) {
      return;
    }
    callbacks.onPageStarted(url);
  }

  Future<void> dispatchPageFinished(String url) async {
    final callbacks = _callbacks;
    if (callbacks == null) {
      return;
    }
    await callbacks.onPageFinished(url);
  }

  Future<void> dispatchPageCommitVisible(String url) async {
    final onPageCommitVisible = _callbacks?.onPageCommitVisible;
    if (onPageCommitVisible == null) {
      return;
    }
    onPageCommitVisible(url);
  }

  Future<ForumWebViewNavigationDecision?> dispatchNavigationRequest(
    String url,
  ) async {
    final callbacks = _callbacks;
    if (callbacks == null) {
      return null;
    }
    return callbacks.onNavigationRequest(url);
  }

  @override
  Future<ForumWebViewCapabilityProfile> probeCapabilities() async {
    probeCapabilitiesCallCount += 1;
    events.add('probeCapabilities');
    return capabilityProfile;
  }

  @override
  Future<void> initialize({
    required ForumWebViewCallbacks callbacks,
    required ForumWebViewBootstrapConfig bootstrapConfig,
  }) async {
    events.add('initialize');
    this.bootstrapConfig = bootstrapConfig;
    _callbacks = callbacks;
  }

  @override
  Future<void> load(Uri uri, {Map<String, String> headers = const {}}) async {
    events.add('load');
    loadedUris.add(uri);
    loadRequests.add(
      _LoadRequestRecord(uri: uri, headers: Map<String, String>.from(headers)),
    );
  }

  @override
  Future<void> reload() async {
    reloadCallCount += 1;
  }

  @override
  Future<bool> clearCookies() async {
    events.add('clearCookies');
    return true;
  }

  @override
  Future<String?> getTitle() async {
    if (holdTitleReads) {
      final completer = Completer<String?>();
      pendingTitleReads.add(completer);
      return completer.future;
    }
    return title;
  }

  @override
  Future<bool> canGoBack() async {
    return canGoBackValue;
  }

  @override
  Future<void> goBack() async {
    goBackCallCount += 1;
  }

  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    returningScripts.add(script);
    return javaScriptResult;
  }

  @override
  Future<void> seedCookies({
    required String domain,
    required Map<String, String> cookies,
    String path = '/',
  }) async {
    events.add('seedCookies');
    seededCookies.add(
      _SeededCookieRecord(
        domain: domain,
        cookies: Map<String, String>.from(cookies),
        path: path,
      ),
    );
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
    return DataReadSuccess<ThreadDetailData, ThreadDetailReadCapabilities>(
      data: ThreadDetailData(
        tid: tid,
        fid: '33',
        subject: '测试主题',
        author: 'alice',
        replies: 0,
        views: 1,
        currentPage: page,
        lastPage: page,
        perPage: 20,
        posts: [
          ThreadPost(
            pid: tid == '570388' ? '41575705' : 'p1',
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

class _FakeThreadPostLocator implements ThreadPostLocator {
  _FakeThreadPostLocator(this.location, {this.pending});

  ThreadPostLocation? location;
  final Completer<ApiResult<ThreadPostLocation>>? pending;
  String? lastTid;
  String? lastPid;
  Uri? lastSourceUri;

  @override
  Future<ApiResult<ThreadPostLocation>> locate({
    required String tid,
    required String pid,
    required Uri sourceUri,
  }) async {
    lastTid = tid;
    lastPid = pid;
    lastSourceUri = sourceUri;
    if (pending != null) return pending!.future;
    final value = location;
    if (value == null) {
      return const ApiFailure<ThreadPostLocation>(
        ApiError(type: ApiErrorType.business, message: '测试未配置楼层定位'),
      );
    }
    return ApiSuccess<ThreadPostLocation>(value);
  }
}

class _FakeForumWebViewRedirectResolver
    implements ForumWebViewRedirectResolver {
  _FakeForumWebViewRedirectResolver({
    Uri? finalUri,
    ApiResult<ForumWebViewRedirectResolution>? result,
    this.pending,
  }) : result =
           result ??
           ApiSuccess<ForumWebViewRedirectResolution>(
             ForumWebViewRedirectResolution(
               finalUri:
                   finalUri ??
                   Uri.parse(
                     'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=100',
                   ),
             ),
           );

  final ApiResult<ForumWebViewRedirectResolution> result;
  final Completer<ApiResult<ForumWebViewRedirectResolution>>? pending;
  int resolveCount = 0;
  Uri? lastSourceUri;

  @override
  Future<ApiResult<ForumWebViewRedirectResolution>> resolve(
    Uri sourceUri,
  ) async {
    lastSourceUri = sourceUri;
    resolveCount++;
    if (pending != null) return pending!.future;
    return result;
  }
}

class _NoopImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(
      success: false,
      cacheKey: request.cacheKey,
      fromCache: false,
    );
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
  Future<void> clearUnprotected() async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }
}

class _FakeForumWebViewExternalLauncher
    implements ForumWebViewExternalLauncher {
  final List<Uri> launchedUris = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return true;
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
    if (error != null) throw error!;
  }
}

class _MemoryComposerDraftRepository implements ComposerDraftRepository {
  final Map<String, ComposerDraftSnapshot> _drafts =
      <String, ComposerDraftSnapshot>{};

  @override
  Future<void> deleteDraft(ComposerDraftIdentity identity) async {
    _drafts.remove(identity.storageKey);
  }

  @override
  Future<List<ComposerDraftSnapshot>> listDraftsForThread({
    required String fid,
    required String tid,
  }) async {
    return _drafts.values
        .where(
          (draft) => draft.identity.fid == fid && draft.identity.tid == tid,
        )
        .toList(growable: false);
  }

  @override
  Future<ComposerDraftSnapshot?> loadDraft(
    ComposerDraftIdentity identity,
  ) async {
    return _drafts[identity.storageKey];
  }

  @override
  Future<ComposerDraftPruneResult> pruneDrafts({
    Duration maxAge = const Duration(days: 30),
    int maxCount = 100,
  }) async {
    return ComposerDraftPruneResult(removedCount: 0, keptCount: _drafts.length);
  }

  @override
  Future<void> saveDraft(ComposerDraftSnapshot draft) async {
    if (draft.isEmpty) {
      _drafts.remove(draft.identity.storageKey);
      return;
    }
    _drafts[draft.identity.storageKey] = draft;
  }
}

final class _TestThreadReplyToken implements ThreadReplyPreparationToken {
  const _TestThreadReplyToken();
}

final ThreadReplyCapabilities _threadReplyCapabilities =
    ThreadReplyCapabilities(
      values: DataCapabilitySet<ThreadReplyCapability>.supported(
        ThreadReplyCapability.values,
      ),
    );

class _FakeThreadReplyAdapter
    implements ThreadReplyPreparationRepository, ThreadReplyCommand {
  _FakeThreadReplyAdapter({
    DataCommandResult<ThreadReplyReceipt>? result,
    DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>?
    preparationResult,
  }) : result =
           result ??
           const DataCommandApplied<ThreadReplyReceipt>(
             ThreadReplyReceipt(
               tid: '123',
               pid: '41554318',
               publicationState: ThreadPublicationState.published,
             ),
           ),
       preparationResult =
           preparationResult ??
           DataReadSuccess<ThreadReplyPreparation, ThreadReplyCapabilities>(
             data: const ThreadReplyPreparation(
               target: ThreadReplyTarget.post(
                 fid: '55',
                 tid: '123',
                 pid: '41554317',
               ),
               quotePreview: '[quote]引用[/quote]',
               token: _TestThreadReplyToken(),
             ),
             capabilities: _threadReplyCapabilities,
             metadata: const DataReadMetadata.network(),
           );

  final DataCommandResult<ThreadReplyReceipt> result;
  final DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>
  preparationResult;
  final List<ThreadReplySubmission> sentDrafts = <ThreadReplySubmission>[];
  int prepareCallCount = 0;

  @override
  ThreadReplyCapabilities get capabilities => _threadReplyCapabilities;

  @override
  Future<DataCommandResult<ThreadReplyReceipt>> execute(
    ThreadReplySubmission submission,
  ) async {
    sentDrafts.add(submission);
    return result;
  }

  @override
  Future<DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>> load(
    ThreadReplyPreparationRequest request,
  ) async {
    prepareCallCount += 1;
    return preparationResult;
  }
}

class _SeededCookieRecord {
  const _SeededCookieRecord({
    required this.domain,
    required this.cookies,
    required this.path,
  });

  final String domain;
  final Map<String, String> cookies;
  final String path;
}

class _LoadRequestRecord {
  const _LoadRequestRecord({required this.uri, required this.headers});

  final Uri uri;
  final Map<String, String> headers;
}

class _PendingWebViewCookieJar implements WebViewCookieJar {
  final pending = Completer<Map<String, String>>();
  int readCount = 0;

  @override
  Future<Map<String, String>> readCookies(Uri uri) {
    readCount++;
    return pending.future;
  }

  @override
  Future<void> writeCookies(Uri uri, Map<String, String> cookies) async {}

  @override
  Future<void> clear() async {}
}

class _FakeCookieStore extends CookieStore {
  _FakeCookieStore({this.cookies = const <String, String>{}});

  final Map<String, String> cookies;

  @override
  Future<Map<String, String>> readCookieMap(Uri uri) async {
    return Map<String, String>.from(cookies);
  }

  @override
  Future<String?> readCookieHeader(Uri uri) async {
    return null;
  }
}

class _FakeForumTagRepository implements ForumTagRepository {
  @override
  Future<ForumTagLookup> loadLookup() async {
    return ForumTagLookup(const <ForumBoardTagSet>[
      ForumBoardTagSet(fid: '55', name: '综合区', tags: <ForumTagDefinition>[]),
    ]);
  }
}

typedef _FavoriteForumReadResult =
    DataReadResult<
      FavoriteForumDirectoryData,
      FavoriteForumDirectoryReadCapabilities
    >;

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
  _FakeForumFavoriteRepository({
    List<FavoriteForumEntry>? favoriteForums,
    List<_FavoriteForumReadResult>? loadResults,
    FavoriteForumDirectorySourceCapabilities? sourceCapabilities,
  }) : directory = _FakeFavoriteForumDirectoryRepository(
         favoriteForums ?? const <FavoriteForumEntry>[],
         loadResults ?? const <_FavoriteForumReadResult>[],
         sourceCapabilities ?? _favoriteForumSourceCapabilities,
       );

  final _FakeFavoriteForumDirectoryRepository directory;

  final List<String> favoriteCalls = <String>[];
  final List<String> unfavoriteCalls = <String>[];

  int get loadCallCount => directory.loadCallCount;

  @override
  FavoriteMutationCapabilities get capabilities =>
      allFavoriteMutationCapabilities;

  @override
  Future<DataCommandResult<ForumFavoriteReceipt>> execute(
    SetForumFavoriteRequest request,
  ) async {
    if (request.targetState == FavoriteTargetState.favorited) {
      favoriteCalls.add(request.fid);
      directory.favoriteForums = <FavoriteForumEntry>[
        ...directory.favoriteForums.where((item) => item.fid != request.fid),
        _favoriteForum(
          fid: request.fid,
          favid: 'fav-${request.fid}',
          title: '版块${request.fid}',
        ),
      ];
      return appliedForumFavorite(
        fid: request.fid,
        targetState: request.targetState,
        remoteFavoriteId: 'fav-${request.fid}',
      );
    }
    final favid = request.knownRemoteFavoriteId ?? '';
    unfavoriteCalls.add(favid);
    directory.favoriteForums = directory.favoriteForums
        .where(
          (item) => item.fid != request.fid && item.remoteFavoriteId != favid,
        )
        .toList();
    return appliedForumFavorite(
      fid: request.fid,
      targetState: request.targetState,
      remoteFavoriteId: favid,
    );
  }
}

class _FakeFavoriteForumDirectoryRepository
    implements FavoriteForumDirectoryRepository {
  _FakeFavoriteForumDirectoryRepository(
    List<FavoriteForumEntry> favoriteForums,
    List<_FavoriteForumReadResult> loadResults,
    this._capabilities,
  ) : favoriteForums = List<FavoriteForumEntry>.from(favoriteForums),
      _loadResults = List<_FavoriteForumReadResult>.from(loadResults);

  List<FavoriteForumEntry> favoriteForums;
  final List<_FavoriteForumReadResult> _loadResults;
  final FavoriteForumDirectorySourceCapabilities _capabilities;
  int loadCallCount = 0;

  @override
  FavoriteForumDirectorySourceCapabilities get capabilities => _capabilities;

  @override
  Future<_FavoriteForumReadResult> load(
    FavoriteForumDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    loadCallCount += 1;
    if (_loadResults.isNotEmpty) {
      final result = _loadResults.removeAt(0);
      if (result case DataReadSuccess<
        FavoriteForumDirectoryData,
        FavoriteForumDirectoryReadCapabilities
      >(
        :final data,
      )) {
        favoriteForums = List<FavoriteForumEntry>.from(data.items);
      }
      return result;
    }
    return DataReadSuccess(
      data: FavoriteForumDirectoryData(
        items: List<FavoriteForumEntry>.from(favoriteForums),
      ),
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

final _unsupportedRemoteIdentityCapabilities =
    FavoriteForumDirectorySourceCapabilities(
      values: DataCapabilitySet<FavoriteForumDirectoryCapability>.from(
        supported: FavoriteForumDirectoryCapability.values.where(
          (capability) =>
              capability !=
              FavoriteForumDirectoryCapability.stableRemoteFavoriteIdentity,
        ),
        unsupported: const <FavoriteForumDirectoryCapability>[
          FavoriteForumDirectoryCapability.stableRemoteFavoriteIdentity,
        ],
      ),
    );

final _favoriteForumReadCapabilities = _favoriteForumSourceCapabilities
    .toReadCapabilities();

final class _TestThreadCreationToken implements ThreadCreationPreparationToken {
  const _TestThreadCreationToken();
}

final ThreadCreationCapabilities _threadCreationCapabilities =
    ThreadCreationCapabilities(
      values: DataCapabilitySet<ThreadCreationCapability>.supported(
        ThreadCreationCapability.values,
      ),
    );

class _FakeThreadCreationPreparationRepository
    implements ThreadCreationPreparationRepository {
  _FakeThreadCreationPreparationRepository({this.metadata});

  final ThreadCreationPreparation? metadata;
  int callCount = 0;

  @override
  ThreadCreationCapabilities get capabilities => _threadCreationCapabilities;

  @override
  Future<DataReadResult<ThreadCreationPreparation, ThreadCreationCapabilities>>
  load(ThreadCreationPreparationRequest request) async {
    callCount += 1;
    final value =
        metadata ??
        ThreadCreationPreparation(
          fid: request.fid,
          forumName: '集成测试版块',
          threadTypes: const <ThreadCreationType>[],
          threadSorts: const <ThreadCreationSort>[],
          typeRequired: false,
          sortRequired: false,
          maxSubjectLength: 0,
          maxMessageLength: 0,
          token: const _TestThreadCreationToken(),
        );
    return DataReadSuccess<
      ThreadCreationPreparation,
      ThreadCreationCapabilities
    >(
      data: value,
      capabilities: _threadCreationCapabilities,
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _FakeThreadCreationCommand implements ThreadCreationCommand {
  _FakeThreadCreationCommand({DataCommandResult<ThreadCreationReceipt>? result})
    : _result =
          result ??
          const DataCommandApplied<ThreadCreationReceipt>(
            ThreadCreationReceipt(
              tid: '900001',
              pid: '910001',
              publicationState: ThreadPublicationState.published,
              readAccess: ThreadReadAccessEvidence(
                kind: ThreadReadAccessEvidenceKind.unrestricted,
                requested: 0,
                actual: 0,
              ),
            ),
          );

  final DataCommandResult<ThreadCreationReceipt> _result;
  final List<ThreadCreationSubmission> submittedPayloads =
      <ThreadCreationSubmission>[];

  @override
  ThreadCreationCapabilities get capabilities => _threadCreationCapabilities;

  @override
  Future<DataCommandResult<ThreadCreationReceipt>> execute(
    ThreadCreationSubmission submission,
  ) async {
    submittedPayloads.add(submission);
    return _result;
  }
}

class _MemoryWebViewCookieJar implements WebViewCookieJar {
  final cookies = <String, String>{};
  int clearCount = 0;
  @override
  Future<Map<String, String>> readCookies(Uri uri) async => Map.of(cookies);
  @override
  Future<void> writeCookies(Uri uri, Map<String, String> values) async =>
      cookies.addAll(values);
  @override
  Future<void> clear() async {
    clearCount++;
    cookies.clear();
  }
}
