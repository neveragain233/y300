import 'dart:async';

import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/features/thread/presentation/services/thread_image_reader_return_coordinator.dart';
import 'package:y300/features/thread/presentation/services/thread_post_actions.dart';
import 'package:y300/features/thread/presentation/services/thread_post_navigation.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';

import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/presentation/thread_controls_preferences_controller.dart';
import 'package:y300/features/thread/presentation/thread_controls_settings_page.dart';
import 'package:y300/features/thread/presentation/services/thread_floor_navigation_coordinator.dart';
import 'package:y300/features/thread/presentation/services/thread_reply_tail_coordinator.dart';
import 'package:y300/features/thread/presentation/services/thread_controls_visibility_controller.dart';
import 'package:y300/features/thread/presentation/widgets/thread_floating_controls.dart';
import 'package:y300/features/thread/presentation/widgets/thread_page_picker_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/eink_scroll_pager.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:y300/features/thread/domain/services/thread_post_navigation_session.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/localization/app_server_content_conversion_provider.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/core/config/app_config.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/composer_shared/domain/models/composer_kind.dart';
import 'package:y300/features/composer_shared/presentation/services/composer_text_resolver.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/services/keyword_filter_matcher.dart';
import 'package:y300/features/content_filter/domain/services/thread_block_identity.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/blacklist/presentation/blacklist_author_gate_view.dart';
import 'package:y300/features/content_filter/presentation/services/blacklist_user_action.dart';
import 'package:y300/features/content_filter/presentation/services/thread_block_action.dart';
import 'package:y300/features/content_filter/presentation/widgets/blocked_keyword_thread_gate_view.dart';
import 'package:y300/features/content_filter/presentation/widgets/blocked_thread_gate_view.dart';
import 'package:y300/features/history/data/providers/history_providers.dart';
import 'package:y300/features/history/domain/models/history_models.dart';
import 'package:y300/features/history/domain/services/history_diagnostic_recorder.dart';
import 'package:y300/features/history/domain/services/history_visit_recorder.dart';
import 'package:y300/features/reply/domain/models/reply_models.dart';
import 'package:y300/features/reply/presentation/reply_composer_page.dart';
import 'package:y300/features/reply/presentation/reply_composer_state.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter_factory.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/thread/domain/models/thread_image_open_models.dart';
import 'package:y300/features/thread/domain/models/thread_ui_feedback.dart';
import 'package:y300/features/thread/domain/models/thread_post_target.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/features/thread/presentation/thread_detail_controller.dart';
import 'package:y300/features/thread/presentation/thread_post_comment_projection_provider.dart';
import 'package:y300/features/thread/presentation/thread_content_projection_providers.dart';
import 'package:y300/features/thread/presentation/thread_detail_content_projection.dart';
import 'package:y300/features/thread/presentation/thread_detail_content_projector.dart';
import 'package:y300/features/thread/presentation/mappers/thread_history_visit_mapper.dart';
import 'package:y300/features/thread/presentation/services/thread_history_commit_guard.dart';
import 'package:y300/features/thread/presentation/thread_detail_state.dart';
import 'package:y300/features/thread/presentation/thread_text_resolver.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_app_bar.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_widgets.dart';
import 'package:y300/features/tags/presentation/yamibo_tag_thread_page.dart';
import 'package:y300/shared/widgets/forum_pull_to_refresh.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/features/thread/domain/contracts/thread_body_reading_observer.dart';
import 'package:y300/features/thread/presentation/services/thread_body_reading_coordinator.dart';

class ThreadDetailPage extends ConsumerStatefulWidget {
  const ThreadDetailPage({
    super.key,
    required this.tid,
    this.subject = '',
    this.initialPage,
    this.targetPid,
    this.initialHandoff,
    this.landing = ThreadPostLanding.top,
    this.initialForumName,
    this.bodyReadingObserver,
    this.gateBlockedEntry = false,
  }) : assert(
         landing == ThreadPostLanding.top ||
             (targetPid != null && targetPid != ''),
         'A body-end landing requires a target post.',
       );

  final String tid;
  final String subject;
  final int? initialPage;
  final String? targetPid;
  final ThreadDetailHandoff? initialHandoff;
  final ThreadPostLanding landing;
  final String? initialForumName;
  final ThreadBodyReadingObserver? bodyReadingObserver;

  /// Whether this entry must consult local blocked-thread rules before
  /// requesting the body.
  ///
  /// Direct links, favorites and history opt in; list entries already filter
  /// their rows and keep their existing first-frame behavior.
  final bool gateBlockedEntry;

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  late final ThreadImageReaderReturnCoordinator _imageReaderReturnCoordinator;
  late final ThreadFloorNavigationCoordinator _floorNavigation;
  late final ThreadReplyTailCoordinator _replyTail;
  late final ThreadDetailScrollTitleObserver _titleObserver;
  Set<String> _tailMembership = const <String>{};
  int _blacklistRevision = 0;
  String? _tailPageKey;
  bool _tailAutoAttempted = false;
  bool _filteredTailExpanded = false;
  bool _allowedKeywordThreadView = false;
  String? _lastTailContextKey;
  final _controlsVisibility = ThreadControlsVisibilityController();
  double _controlsHeight = 56;
  double _rightControlsHeight = 56;
  double _repliesHeaderHeight = 0;
  int _repliesHeaderAnchorRevision = 0;
  Timer? _highlightClearTimer;
  String? _highlightPostPid;
  bool _targetHighlightStarted = false;
  String? _latestImageReferer;

  final ThreadHistoryCommitGuard _historyCommitGuard =
      ThreadHistoryCommitGuard();
  bool _didReportHistoryDuplicate = false;
  bool _postActionActive = false;
  final _postRouteSession = ThreadPostNavigationSession();
  ThreadBodyReadingCoordinator? _bodyReadingCoordinator;
  bool _readingResumed = true;
  bool _readingVisible = false;
  bool _readingClosing = false;
  int _readingSuspensions = 0;
  int _readingVisibilityRevision = 0;
  int _readingCloseRevision = 0;
  int _readingOwnerRevision = 0;
  bool _allowedBlockedView = false;
  bool _allowedBlacklistedAuthorView = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _titleObserver = ThreadDetailScrollTitleObserver(isMounted: () => mounted);
    _imageReaderReturnCoordinator = ThreadImageReaderReturnCoordinator(
      scrollController: _scrollController,
    )..topInsetForPost = _imageReturnTopInset;

    _floorNavigation = ThreadFloorNavigationCoordinator(
      readPage: _readFloorPage,
      loadAdjacent: _loadAdjacentFloor,
      loadTopicBody: _loadTopicBody,
      onStarted: () {
        ref
            .read(threadDetailControllerProvider(_currentThreadArgs).notifier)
            .cancelFloorPageLoad();
        _controlsVisibility.reset();
        _bodyReadingCoordinator?.beginExplicitNavigation();
      },
      onConfirmed: () => _bodyReadingCoordinator?.markUserNavigation(),
      onBoundaryReached: () => unawaited(HapticFeedback.lightImpact()),
      onTailPending: _retryReplyTail,
    );
    _replyTail = ThreadReplyTailCoordinator(
      readPage: (page) => ref
          .read(threadDetailControllerProvider(_currentThreadArgs).notifier)
          .readReplyTailPage(page),
    )..addListener(_handleReplyTailChanged);
    _bindReadingObserver();
  }

  void _bindReadingObserver() {
    final observer = widget.bodyReadingObserver;
    if (observer == null) return;
    WidgetsBinding.instance.addObserver(this);
    _bodyReadingCoordinator = ThreadBodyReadingCoordinator(
      observer: observer,
      scrollController: _scrollController,
      initialTargetPid: widget.targetPid,
    )..setActive(false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReadingVisibility();
    // 字体、宽度与主题变化会改变首楼标题边界，下一帧重新核对。
    _titleObserver.schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _readingResumed = state == AppLifecycleState.resumed;
    _syncReadingVisibility();
  }

  void _syncReadingVisibility() {
    if (!mounted) return;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!routeCurrent && _floorNavigation.isNavigating) {
      _cancelFloorNavigation();
    }
    final observer = widget.bodyReadingObserver;
    if (observer == null || !mounted || _readingClosing) return;
    final frontmost = routeCurrent && _readingSuspensions == 0;
    final visible = frontmost && _readingResumed;
    if (_readingVisible == visible) return;
    _readingVisible = visible;
    final revision = ++_readingVisibilityRevision;
    if (visible) {
      observer.onVisibility(frontmost: frontmost, resumed: _readingResumed);
      _bodyReadingCoordinator?.setActive(true);
      return;
    }
    _bodyReadingCoordinator?.setActive(false);
    _pauseReading(observer);
    // Stop new measurements immediately, then flush the last confirmed lease
    // before changing producer visibility and invalidating that lease.
    unawaited(() async {
      await _flushReading(observer);
      if (mounted &&
          revision == _readingVisibilityRevision &&
          identical(observer, widget.bodyReadingObserver)) {
        observer.onVisibility(frontmost: frontmost, resumed: _readingResumed);
      }
    }());
  }

  Future<void> _flushReading(ThreadBodyReadingObserver observer) async {
    try {
      await observer.flush();
    } catch (error) {
      debugPrint('[ThreadBodyReading] flush_failure=${error.runtimeType}');
    }
  }

  void _pauseReading(ThreadBodyReadingObserver observer) {
    if (observer is ThreadBodyReadingSuspension) {
      (observer as ThreadBodyReadingSuspension).suspendForFlush();
    }
    observer.cancelPendingCompletion();
  }

  Future<void> _runReadingViewAction(
    FutureOr<void> Function() action, {
    bool userNavigation = false,
    bool preserveFloorNavigation = false,
  }) async {
    final observer = widget.bodyReadingObserver;
    if (!preserveFloorNavigation) _cancelFloorNavigation();
    _controlsVisibility.reset();
    final ownerRevision = _readingOwnerRevision;
    if (observer == null) {
      await action();
      return;
    }
    _readingSuspensions++;
    if (userNavigation) _bodyReadingCoordinator?.markUserNavigation();
    _bodyReadingCoordinator?.setActive(false);
    _pauseReading(observer);
    try {
      await _flushReading(observer);
      if (mounted && ownerRevision == _readingOwnerRevision) await action();
    } finally {
      if (mounted && ownerRevision == _readingOwnerRevision) {
        _readingSuspensions--;
        _readingVisible = false;
        _syncReadingVisibility();
      }
    }
  }

  Future<void> _closeReadingAndPop() async {
    if (_readingClosing) return;
    final observer = widget.bodyReadingObserver;
    if (observer == null) return;
    final tid = widget.tid;
    final targetPid = widget.targetPid;
    final closeRevision = ++_readingCloseRevision;
    bool isCurrent() =>
        mounted &&
        closeRevision == _readingCloseRevision &&
        identical(observer, widget.bodyReadingObserver) &&
        tid == widget.tid &&
        targetPid == widget.targetPid;
    _readingClosing = true;
    _readingVisibilityRevision++;
    _bodyReadingCoordinator?.setActive(false);
    _pauseReading(observer);
    await _flushReading(observer);
    observer.retire();
    if (!isCurrent()) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isCurrent()) Navigator.of(context).pop();
    });
  }

  @override
  void didUpdateWidget(covariant ThreadDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bodyReadingObserver, widget.bodyReadingObserver) ||
        oldWidget.tid != widget.tid ||
        oldWidget.targetPid != widget.targetPid) {
      _readingCloseRevision++;
      _floorNavigation.cancel();
      _readingOwnerRevision++;
      _readingVisibilityRevision++;
      _readingClosing = false;
      _readingSuspensions = 0;
      WidgetsBinding.instance.removeObserver(this);
      _bodyReadingCoordinator?.dispose();
      _bodyReadingCoordinator = null;
      final oldObserver = oldWidget.bodyReadingObserver;
      if (oldObserver != null) {
        _pauseReading(oldObserver);
        unawaited(_flushReading(oldObserver).whenComplete(oldObserver.retire));
      }
      _readingVisible = false;
      _bindReadingObserver();
      _syncReadingVisibility();
    }
    if (oldWidget.tid != widget.tid) {
      _allowedBlacklistedAuthorView = false;
      _allowedKeywordThreadView = false;
      _filteredTailExpanded = false;
    }
    if (oldWidget.tid != widget.tid ||
        oldWidget.targetPid != widget.targetPid ||
        oldWidget.initialPage != widget.initialPage ||
        !identical(oldWidget.initialHandoff, widget.initialHandoff) ||
        oldWidget.landing != widget.landing) {
      _postRouteSession.invalidate();
      _replyTail.reset();
      _tailAutoAttempted = false;
      _filteredTailExpanded = false;
      _titleObserver.reset();
    }
    if (oldWidget.tid != widget.tid ||
        oldWidget.targetPid?.trim() != widget.targetPid?.trim() ||
        oldWidget.landing != widget.landing) {
      _highlightClearTimer?.cancel();
      _highlightPostPid = null;
      _targetHighlightStarted = false;
    }
  }

  @override
  void dispose() {
    _readingCloseRevision++;
    _readingOwnerRevision++;
    WidgetsBinding.instance.removeObserver(this);
    _bodyReadingCoordinator?.dispose();
    final observer = widget.bodyReadingObserver;
    if (observer != null && !_readingClosing) {
      _pauseReading(observer);
      unawaited(_flushReading(observer).whenComplete(observer.retire));
    }
    _postRouteSession.dispose();
    _highlightClearTimer?.cancel();
    _titleObserver.dispose();
    _replyTail
      ..removeListener(_handleReplyTailChanged)
      ..dispose();
    _floorNavigation.dispose();
    _controlsVisibility.dispose();
    _imageReaderReturnCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.gateBlockedEntry && !_allowedBlockedView) {
      final blockedRules = ref.watch(blockedThreadsControllerProvider);
      if (blockedRules.isLoading && !blockedRules.hasValue) {
        // The prompt must not flash thread content while rules load; the body
        // request starts only after this gate resolves.
        return Scaffold(
          key: const Key('thread-detail-blocked-rules-loading'),
          appBar: AppBar(),
          body: AppLoadingState(
            key: const Key('thread-detail-rules-loading'),
            label: l10n.threadDetailLoading,
          ),
        );
      }
      final rule = _blockedRuleFor(blockedRules.value);
      if (rule != null) {
        return BlockedThreadGateView(
          rule: rule,
          onViewOnce: _viewBlockedThreadOnce,
          onUnblock: () => unawaited(_unblockBlockedThread(rule)),
        );
      }
    }
    final args = ThreadDetailArgs(
      tid: widget.tid,
      subject: widget.subject,
      initialPage: widget.initialPage,
      targetPid: widget.targetPid,
      initialHandoff: widget.initialHandoff,
    );
    final asyncState = ref.watch(threadDetailControllerProvider(args));
    ref.watch(sessionRevisionProvider);
    ref.listen<AsyncValue<int>>(sessionRevisionProvider, (previous, next) {
      if (previous?.value != null && previous?.value != next.value) {
        _cancelFloorNavigation();
        _replyTail.reset();
        _tailAutoAttempted = false;
      }
    });
    final controller = ref.read(threadDetailControllerProvider(args).notifier);
    final state =
        asyncState.value ??
        ThreadDetailPageState.initial(tid: widget.tid, subject: widget.subject);
    final blacklistedUserIds = ref.watch(blacklistedUserIdsProvider);
    final hideBlacklistedThreads = ref.watch(hideBlacklistedThreadsProvider);
    final topicAuthor = _topicAuthorPost(state);
    final blacklistedTopicAuthorId = topicAuthor?.authorId.trim() ?? '';
    final blacklistedTopicAuthor =
        blacklistedTopicAuthorId.isNotEmpty &&
        blacklistedUserIds.contains(blacklistedTopicAuthorId);
    if (hideBlacklistedThreads &&
        blacklistedTopicAuthor &&
        !_allowedBlacklistedAuthorView) {
      return BlacklistAuthorGateView(
        subject: state.subject.trim().isNotEmpty
            ? state.subject
            : widget.subject,
        author: topicAuthor!.author,
        onViewOnce: () => setState(() => _allowedBlacklistedAuthorView = true),
      );
    }
    final conversionMode = ref.watch(appServerContentConversionModeProvider);
    final converter = ref.watch(textConverterProvider(conversionMode));
    final projectionCandidate = ref
        .watch(threadDetailContentProjectionProvider(args))
        .value;
    final projection = _resolveProjection(
      state,
      mode: conversionMode,
      converterId: converter.id,
      candidate: projectionCandidate,
    );
    final keywordRules = ref.watch(keywordFilterRulesProvider);
    if (!_allowedKeywordThreadView && keywordRules.hasBodyRules) {
      final rawSubject = state.subject.trim().isNotEmpty
          ? state.subject
          : widget.subject;
      final matchedKeyword =
          KeywordFilterMatcher.matchPlainText(
            rawSubject,
            keywordRules.bodyRules,
            convertedText: projection.displaySubject,
          ) ??
          (topicAuthor != null
              ? KeywordFilterMatcher.matchHtmlBody(
                  topicAuthor.message,
                  keywordRules.bodyRules,
                  excludeQuotes: false,
                  convertedHtml: projection
                      .findByPid(topicAuthor.pid)
                      ?.displayPost
                      .message,
                )
              : null);
      if (matchedKeyword != null) {
        return BlockedKeywordThreadGateView(
          subject: rawSubject,
          matchedKeyword: matchedKeyword.keyword,
          onViewOnce: () => setState(() => _allowedKeywordThreadView = true),
        );
      }
    }
    final extraCommentProjection = ref
        .watch(threadPostCommentProjectionProvider(args))
        .value;
    final extraComments =
        extraCommentProjection?.matches(state.commentsByPostId) == true
        ? extraCommentProjection!.displayLists
        : const <String, List<ThreadPostCommentEntry>>{};
    final imageReferer = ref.watch(
      forumImageRefererForSourceProvider(_imageRefererFor(state)),
    );
    final htmlFirstPrecacheService = ref.watch(
      forumImagePrecacheServiceProvider,
    );
    final historyRecorder = ref.watch(historyVisitRecorderProvider);
    final historyDiagnostics = ref.watch(historyDiagnosticRecorderProvider);
    _latestImageReferer = imageReferer;
    ref.listen<AsyncValue<ThreadDetailPageState>>(
      threadDetailControllerProvider(args),
      (previous, next) {
        final previousNotice = previous?.value?.threadFavoriteNotice;
        final nextNotice = next.value?.threadFavoriteNotice;
        if (nextNotice == null || nextNotice == previousNotice) {
          return;
        }
        showTransientSnackBar(
          context,
          ThreadTextResolver.actionNotice(l10n, nextNotice),
        );
      },
    );
    final palette = ThreadDetailNativePalette.resolve(Theme.of(context));
    final controlsPreferences =
        ref.watch(threadControlsPreferencesControllerProvider).value ??
        const ThreadControlsPreferences();
    ref.listen<AsyncValue<ThreadControlsPreferences>>(
      threadControlsPreferencesControllerProvider,
      (previous, next) {
        if (previous?.value?.hideOnScroll != next.value?.hideOnScroll) {
          _controlsVisibility.reset();
        }
      },
    );
    final tailMembership = _tailMembershipFor(
      blacklistedUserIds,
      allowedAuthorId: _allowedBlacklistedAuthorView
          ? blacklistedTopicAuthorId
          : null,
    );
    if (!_sameIds(_tailMembership, tailMembership)) {
      _tailMembership = tailMembership;
      _blacklistRevision++;
    }
    final tailContextKey =
        '${state.tid}|${_queryIdentityFor(state)}|${state.currentPage}|$_blacklistRevision|${keywordRules.revision}';
    if (_lastTailContextKey != tailContextKey) {
      _lastTailContextKey = tailContextKey;
      _filteredTailExpanded = false;
    }
    _replyTail.observe(
      threadId: state.tid.trim().isEmpty ? widget.tid : state.tid,
      queryIdentity: _queryIdentityFor(state),
      page: state.currentPage,
      posts: state.posts,
      isLastPage: _isThreadLastPage(state),
      blacklistedUserIds: _tailMembership,
      pinnedPid: widget.targetPid,
      filterIdentity: Object.hash(_blacklistRevision, keywordRules.revision),
      hasActiveFilters:
          _tailMembership.isNotEmpty || keywordRules.hasReplyRules,
      evaluatePost: (post) => _evaluateReplyFilter(
        post,
        blacklistedUserIds: _tailMembership,
        keywordRules: keywordRules,
        convertedHtml: projection.findByPid(post.pid)?.displayPost.message,
      ),
    );
    _floorNavigation.refresh();
    _scheduleReplyTailCollection(state);
    _scheduleHistoryVisit(
      asyncState: asyncState,
      state: state,
      recorder: historyRecorder,
      diagnostics: historyDiagnostics,
    );

    _syncTitleStructure(state);
    final page = Scaffold(
      backgroundColor: palette.background,
      appBar: ThreadDetailAppBar(
        toolbarHeight: ThreadDetailAppBar.resolveToolbarHeight(context),
        leading: widget.bodyReadingObserver == null
            ? adaptiveDetailBackButton(context)
            : AppToolbarBackButton(
                onPressed: () => unawaited(_closeReadingAndPop()),
              ),
        forumName: projection.displayForumName,
        initialForumName: widget.initialForumName,
        subject: projection.displaySubject,
        showSubject: _titleObserver.showSubject,
        onCopyLink: () => unawaited(_copyThreadUrl(state)),
        actions: [
          IconButton(
            key: const Key('thread-detail-first-post-button'),
            tooltip: l10n.threadControlsFirstPost,
            onPressed: asyncState.value == null || state.posts.isEmpty
                ? null
                : () => unawaited(_goToFirstPost(controller)),
            icon: const Icon(Icons.vertical_align_top),
          ),
          const AdaptiveDetailExpandAction(),
        ],
      ),
      body: Column(
        children: [
          if (_topicTagsFor(state) case final tags when tags.isNotEmpty)
            ThreadTopicTagBar(tags: tags, onOpenTag: _openThreadTag),
          Expanded(
            // pager 只包实际滚动区，边缘层不会覆盖顶部分类标签栏。
            child: EInkScrollPager(
              controller: _scrollController,
              cornerPadding: EdgeInsets.only(
                right: 12,
                bottom: 24 + _rightControlsHeight,
              ),
              edgeTapAllowed: true,
              edgeTopInset: _repliesHeaderHeight > 0
                  ? _repliesHeaderHeight
                  : 56,
              edgeBottomInset: _controlsHeight + 16,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: _handleThreadMetricsNotification,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleThreadScrollNotification,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppLayoutTokens.readingMaxWidth,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) => MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(size: constraints.biggest),
                          child: (asyncState.isLoading && state.posts.isEmpty)
                              ? ThreadDetailEntrySurface(
                                  subject: projection.displaySubject,
                                  child: AppLoadingState(
                                    key: ValueKey(args),
                                    label: l10n.threadDetailLoading,
                                  ),
                                )
                              : (asyncState.hasError ||
                                        state.errorMessage != null) &&
                                    state.posts.isEmpty
                              ? _ThreadErrorView(
                                  subject: projection.displaySubject,
                                  message: state.loadFailure == null
                                      ? ThreadTextResolver.loadFailure(
                                          l10n,
                                          ThreadUiErrorCode.loadFailed,
                                          state.errorMessage,
                                        )
                                      : ThreadTextResolver.loadFailure(
                                          l10n,
                                          state.loadFailure!.code,
                                          state.loadFailure!.detail,
                                        ),
                                  onRetry: controller.refresh,
                                  onOpenHome: widget.targetPid == null
                                      ? null
                                      : () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute<void>(
                                              builder: (_) => ThreadDetailPage(
                                                tid: widget.tid,
                                                subject: widget.subject,
                                              ),
                                            ),
                                          );
                                        },
                                )
                              : ForumPullToRefresh(
                                  onRefresh: () => _runReadingViewAction(
                                    () =>
                                        controller.refresh(forceNetwork: true),
                                  ),
                                  child: ThreadDetailContent(
                                    key: _titleObserver.viewportKey,
                                    firstPostTitleKey: _titleObserver.titleKey,
                                    repliesHeaderAnchorRevision:
                                        _repliesHeaderAnchorRevision,
                                    defaultRatingsExpanded: controlsPreferences
                                        .expandRatingsByDefault,
                                    floorNavigation: _floorNavigation,
                                    onRepliesHeaderHeightChanged: (height) {
                                      if (mounted &&
                                          (_repliesHeaderHeight - height)
                                                  .abs() >
                                              .5) {
                                        _repliesHeaderHeight = height;
                                      }
                                    },
                                    bottomInset:
                                        MediaQuery.viewInsetsOf(context)
                                                .bottom >
                                            0
                                        ? 0
                                        : _controlsHeight +
                                              32 +
                                              MediaQuery.paddingOf(context)
                                                  .bottom,
                                    imageReaderReturnCoordinator:
                                        _imageReaderReturnCoordinator,
                                    bodyReadingCoordinator:
                                        _bodyReadingCoordinator,
                                    state: state,
                                    projection: projection,
                                    allowedBlacklistedAuthorId:
                                        _allowedBlacklistedAuthorView
                                        ? blacklistedTopicAuthorId
                                        : null,
                                    displayExtraCommentsByPostId: extraComments,
                                    replyTailPosts: _replyTail.tailPosts,
                                    movedBlacklistedPids: _replyTail.movedPids,
                                    showReplyTail: _replyTail.showTail,
                                    replyTailRevision: _replyTail.revision,
                                    filteredTailExpanded: _filteredTailExpanded,
                                    onToggleFilteredTail: () {
                                      setState(() {
                                        _filteredTailExpanded =
                                            !_filteredTailExpanded;
                                      });
                                      _floorNavigation.refresh();
                                    },
                                    tailReasonsByPid: _replyTail.reasonsByPid,
                                    tailCollecting: _replyTail.isCollecting,
                                    tailHasFailure: _replyTail.hasFailure,
                                    tailHasBudgetLimitation:
                                        _replyTail.hasBudgetLimitation,
                                    onRetryTailCollect: _retryReplyTail,
                                    keywordFilterRules: keywordRules,
                                    hiddenQuotePlaceholderText:
                                        l10n.threadKeywordHiddenQuote,
                                    scrollController: _scrollController,
                                    highlightPostPid: _highlightPostPid,
                                    targetPid: widget.targetPid,
                                    landing: widget.landing,
                                    onTargetVisible: _onTargetVisible,
                                    imageReferer: _imageRefererFor(state),
                                    onLoadPreviousPage: () {
                                      unawaited(
                                        _runPageActionAndScrollTop(
                                          controller.loadPreviousPage,
                                        ),
                                      );
                                    },
                                    onLoadNextPage: () {
                                      unawaited(
                                        _runPageActionAndScrollTop(
                                          controller.loadNextPage,
                                        ),
                                      );
                                    },
                                    onLoadPageNumber: (page) {
                                      unawaited(
                                        _runPageActionAndScrollTop(
                                          () => controller.loadPage(page),
                                        ),
                                      );
                                    },
                                    onToggleAuthorFilter: () =>
                                        _runReadingViewAction(
                                          state.isOnlyAuthorView
                                              ? controller.openAllPosts
                                              : controller.openOnlyAuthor,
                                          userNavigation: true,
                                        ),
                                    onOrderChanged: (reverse) => unawaited(
                                      _runOrderViewAction(
                                        reverse
                                            ? controller.openReverseOrder
                                            : controller.openNormalOrder,
                                        anchorRepliesHeader: !reverse,
                                      ),
                                    ),
                                    onOpenAuthorProfile: _openAuthorProfile,
                                    onOpenCommentAuthorProfile:
                                        _openCommentAuthorProfile,
                                    onCopyActionUrl: _copyActionUrl,
                                    onOpenPostLink: _openForumLink,
                                    onOpenPostImages: _openPostImages,
                                    onOpenPostActions: (press) {
                                      final (post, position) = press;
                                      final postProjection = projection
                                          .findByPid(post.pid);
                                      _openPostActions(
                                        args,
                                        state,
                                        controller,
                                        post,
                                        postProjection?.displayPost ?? post,
                                        position: position,
                                      );
                                    },
                                    htmlImagePrecacheService:
                                        htmlFirstPrecacheService,
                                    onOpenPollOptionActions:
                                        (post, option, point) =>
                                            _openPostActions(
                                              args,
                                              state,
                                              controller,
                                              post,
                                              projection
                                                      .findByPid(post.pid)
                                                      ?.displayPost ??
                                                  post,
                                              position: point,
                                              pollOption: option,
                                            ),
                                    onTogglePollOption:
                                        controller.togglePollOption,
                                    onSubmitPollVote: controller.submitPollVote,
                                    onLoadAllRatings: controller.loadAllRatings,
                                    onLoadMoreComments:
                                        controller.loadMoreComments,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ThreadFloatingControls(
        preferences: controlsPreferences,
        horizontalSafeInsets: EdgeInsets.only(
          left: MediaQuery.paddingOf(context).left,
          right: MediaQuery.paddingOf(context).right,
        ),
        navigation: _floorNavigation,
        visibility: _controlsVisibility,
        hasContent: state.posts.isNotEmpty,
        currentPage: state.currentPage,
        totalPages: state.lastPage,
        onJumpPage: state.posts.isNotEmpty && !state.isLoadingMore
            ? () => _selectThreadPage(controller, state)
            : null,
        onJumpPageFromContext: state.posts.isNotEmpty && !state.isLoadingMore
            ? (anchorContext) => _selectThreadPage(
                controller,
                state,
                anchorContext: anchorContext,
              )
            : null,
        onHeightChanged: (height) {
          if (mounted && (_controlsHeight - height).abs() > .5) {
            setState(() => _controlsHeight = height);
          }
        },
        onRightStackHeightChanged: (height) {
          if (mounted && (_rightControlsHeight - height).abs() > .5) {
            setState(() => _rightControlsHeight = height);
          }
        },
        favorite: state.supports(ThreadDetailCapability.favoriteEntry)
            ? IconButton(
                key: const Key('thread-detail-favorite-button'),
                tooltip: state.isThreadFavorited
                    ? l10n.threadDetailUnfavorite
                    : l10n.threadDetailFavorite,
                onPressed:
                    asyncState.value == null ||
                        state.isThreadFavoriteActionLoading ||
                        state.isThreadFavorited
                    ? null
                    : controller.favoriteThread,
                icon: state.isThreadFavoriteActionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        state.isThreadFavorited
                            ? Icons.star
                            : Icons.star_border_outlined,
                      ),
              )
            : null,
        reply:
            state.supports(ThreadDetailCapability.replyAction) &&
                asyncState.value != null
            ? () => _openThreadReplyComposer(args, state)
            : null,
        jumpPage: Builder(
          builder: (buttonContext) => IconButton(
            key: const Key('thread-detail-jump-page-button'),
            tooltip: l10n.threadControlsJumpPage,
            onPressed: state.posts.isNotEmpty && !state.isLoadingMore
                ? () => _selectThreadPage(
                    controller,
                    state,
                    anchorContext: buttonContext,
                  )
                : null,
            icon: const Icon(Icons.numbers),
          ),
        ),
        more: _ThreadDetailMoreMenu(
          state: state,
          onOnlyAuthor: () => _runReadingViewAction(
            controller.openOnlyAuthor,
            userNavigation: true,
          ),
          onAllPosts: () => _runReadingViewAction(
            controller.openAllPosts,
            userNavigation: true,
          ),
          onReverseOrder: () => unawaited(
            _runOrderViewAction(
              controller.openReverseOrder,
              anchorRepliesHeader: false,
            ),
          ),
          onNormalOrder: () => unawaited(
            _runOrderViewAction(
              controller.openNormalOrder,
              anchorRepliesHeader: true,
            ),
          ),
          onReturnHome: () => unawaited(_returnHome()),
          onDisplaySettings: _openDisplaySettings,
          onControlsSettings: _openControlsSettings,
          onBlockThread: () => unawaited(_blockCurrentThread(state)),
          onBlockAuthor:
              topicAuthor != null &&
                  blacklistUserActionAvailable(
                    ref,
                    userId: topicAuthor.authorId,
                    username: topicAuthor.author,
                  )
              ? () => unawaited(
                  blockBlacklistUser(
                    context,
                    ref,
                    userId: topicAuthor.authorId,
                    username: topicAuthor.author,
                  ),
                )
              : null,
        ),
        onFirstPost: () => unawaited(_goToFirstPost(controller)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
    );
    final feedbackPage = ValueListenableBuilder<bool>(
      valueListenable: _controlsVisibility,
      builder: (context, visible, _) => TransientFeedbackObstacle(
        bottom: (controlsPreferences.hideOnScroll && !visible)
            ? 0
            : _controlsHeight + 32 + MediaQuery.paddingOf(context).bottom,
        child: page,
      ),
    );
    return widget.bodyReadingObserver == null
        ? feedbackPage
        : PopScope<void>(
            canPop: _readingClosing,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_closeReadingAndPop());
            },
            child: feedbackPage,
          );
  }

  bool _handleThreadScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    _bodyReadingCoordinator?.handleScroll(notification);
    _controlsVisibility.handle(
      notification,
      enabled:
          ref
              .read(threadControlsPreferencesControllerProvider)
              .value
              ?.hideOnScroll ??
          false,
    );
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _floorNavigation.userScrolled();
      ref
          .read(threadDetailControllerProvider(_currentThreadArgs).notifier)
          .cancelFloorPageLoad();
    }
    if (notification is ScrollEndNotification) _floorNavigation.refresh();
    if (notification case UserScrollNotification(:final direction)) {
      if (direction != ScrollDirection.idle) {
        _floorNavigation.userScrolled();
      }
    }
    _titleObserver.schedule();
    return false;
  }

  bool _handleThreadMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    if (notification.depth == 0) {
      _bodyReadingCoordinator?.schedule();
      _floorNavigation.refresh();
      _titleObserver.schedule();
    }
    return false;
  }

  /// 声明首楼标题是否可能出现在正文序列顶部。
  ///
  /// 翻页、倒序与只看该作者时首楼不在当前位置，顶栏直接显示“帖子标题＋板块名”；
  /// 首屏加载中保留板块名，等正文可测后再按实际几何切换。
  void _syncTitleStructure(ThreadDetailPageState state) {
    final reverseOrFiltered =
        state.isReverseOrderView || state.isOnlyAuthorView;
    final loadsFirstPage = state.currentPage == 1;
    _titleObserver.updateStructure(
      tracks: !reverseOrFiltered && loadsFirstPage && state.posts.isNotEmpty,
      forceSubject: reverseOrFiltered || state.currentPage > 1,
    );
  }

  void _scheduleHistoryVisit({
    required AsyncValue<ThreadDetailPageState> asyncState,
    required ThreadDetailPageState state,
    required HistoryVisitRecorder recorder,
    required HistoryDiagnosticRecorder diagnostics,
  }) {
    if (!asyncState.hasValue ||
        state.isLoadingInitial ||
        state.errorMessage != null ||
        state.posts.isEmpty) {
      return;
    }
    final routeTid = widget.tid.trim();
    final visibleTid = state.tid.trim().isEmpty ? routeTid : state.tid.trim();
    final routeSubject = widget.subject;
    final routeForumName = widget.initialForumName;
    final routePage = widget.initialPage;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.tid.trim() != routeTid) {
        return;
      }
      if (!_historyCommitGuard.tryCommit(visibleTid)) {
        if (!_didReportHistoryDuplicate) {
          _didReportHistoryDuplicate = true;
          diagnostics.recordSkip(
            surface: HistoryVisitSurface.threadNative,
            reason: 'route_session_duplicate',
          );
        }
        return;
      }
      try {
        final draft = const ThreadHistoryVisitMapper().map(
          state: state,
          routeTid: routeTid,
          routeSubject: routeSubject,
          routeForumName: routeForumName,
          routePage: routePage,
        );
        await recorder.record(draft);
      } catch (error) {
        debugPrint(
          '[ThreadDetail][native][history_record_failure] '
          'error=${error.runtimeType}',
        );
      }
    });
  }

  String _imageRefererFor(ThreadDetailPageState state) {
    final desktopUrl = state.desktopUrl?.trim();
    if (desktopUrl != null && desktopUrl.isNotEmpty) {
      return desktopUrl;
    }
    final currentPage = state.currentPage <= 0 ? 1 : state.currentPage;
    return Uri.parse(AppConfig.siteBaseUrl)
        .replace(
          path: '/forum.php',
          queryParameters: <String, String>{
            'mod': 'viewthread',
            'tid': widget.tid,
            'page': currentPage.toString(),
            'mobile': '2',
          },
        )
        .toString();
  }

  BlockedThread? _blockedRuleFor(List<BlockedThread>? rules) {
    if (rules == null) {
      return null;
    }
    final target = ThreadBlockIdentity.normalizeTid(widget.tid);
    if (target == null) {
      return null;
    }
    for (final rule in rules) {
      if (rule.tid == target) {
        return rule;
      }
    }
    return null;
  }

  void _viewBlockedThreadOnce() {
    setState(() => _allowedBlockedView = true);
  }

  Future<void> _unblockBlockedThread(BlockedThread rule) async {
    final l10n = AppLocalizations.of(context);
    final restored = await ref
        .read(blockedThreadsControllerProvider.notifier)
        .unblock(rule.tid);
    if (!mounted) {
      return;
    }
    if (!restored) {
      showTransientSnackBar(context, l10n.contentFilterSaveFailed);
      return;
    }
    setState(() => _allowedBlockedView = true);
  }

  Future<void> _blockCurrentThread(ThreadDetailPageState state) async {
    final subject = state.subject.trim().isNotEmpty
        ? state.subject
        : widget.subject;
    final blocked = await ThreadBlockAction.block(
      context,
      ref,
      tid: widget.tid,
      subject: subject,
    );
    if (!mounted || !blocked) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _cancelFloorNavigation() {
    _floorNavigation.cancel();
    if (mounted) {
      ref
          .read(threadDetailControllerProvider(_currentThreadArgs).notifier)
          .cancelFloorPageLoad();
    }
  }

  ThreadDetailArgs get _currentThreadArgs => ThreadDetailArgs(
    tid: widget.tid,
    subject: widget.subject,
    initialPage: widget.initialPage,
    targetPid: widget.targetPid,
    initialHandoff: widget.initialHandoff,
  );

  ThreadFloorPage? _readFloorPage() {
    if (!mounted) return null;
    final value = ref
        .read(threadDetailControllerProvider(_currentThreadArgs))
        .value;
    if (value == null) return null;
    final display = _displayPostsFor(value);
    return ThreadFloorPage(
      owner: (
        value.tid,
        _queryIdentityFor(value),
        ref.read(sessionRevisionProvider).value ?? 0,
        _blacklistRevision,
      ),
      page: value.currentPage,
      pids: display.map((post) => post.pid).toList(growable: false),
      hasPrevious: value.currentPage > 1,
      hasNext: value.hasMore,
      loading: value.isLoadingMore,
      topicPid: _topicPidOf(display),
      tailPending: _replyTail.tailPending,
    );
  }

  /// 与渲染条目共用同一份展示顺序：未展开折叠栏时不包含尾部被屏蔽回复，
  /// 使翻楼导航跳过未展开区；展开后再并入序列。
  List<ThreadPost> _displayPostsFor(ThreadDetailPageState state) {
    final moved = _replyTail.movedPids;
    final posts = <ThreadPost>[
      for (final post in state.posts)
        if (!moved.contains(post.pid)) post,
    ];
    if (!_replyTail.showTail || !_filteredTailExpanded) return posts;
    final seen = <String>{for (final post in posts) post.pid};
    for (final post in _replyTail.tailPosts) {
      if (seen.add(post.pid)) posts.add(post);
    }
    return posts;
  }

  ThreadReplyFilterReason _evaluateReplyFilter(
    ThreadPost post, {
    required Set<String> blacklistedUserIds,
    required KeywordFilterRuleSet keywordRules,
    String? convertedHtml,
  }) {
    if (post.isFirst || post.number == 1) {
      return ThreadReplyFilterReason.none;
    }
    final authorId = post.authorId.trim();
    final isBlacklisted =
        authorId.isNotEmpty && blacklistedUserIds.contains(authorId);
    final matchedKeyword = keywordRules.hasReplyRules
        ? KeywordFilterMatcher.matchHtmlBody(
            post.message,
            keywordRules.replyRules,
            excludeQuotes: true,
            convertedHtml: convertedHtml,
          )?.keyword
        : null;
    if (!isBlacklisted && matchedKeyword == null) {
      return ThreadReplyFilterReason.none;
    }
    return ThreadReplyFilterReason(
      isBlacklistedAuthor: isBlacklisted,
      matchedKeyword: matchedKeyword,
    );
  }

  String? _topicPidOf(List<ThreadPost> posts) {
    for (final post in posts) {
      if (post.isFirst || post.number == 1) return post.pid;
    }
    return null;
  }

  String _queryIdentityFor(ThreadDetailPageState state) {
    final entries = state.queryParameters.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return Uri(queryParameters: Map.fromEntries(entries)).query;
  }

  static bool _isThreadLastPage(ThreadDetailPageState state) {
    return state.currentPage > 0 &&
        !state.isLoadingInitial &&
        state.loadFailure == null &&
        state.posts.isNotEmpty &&
        !state.hasMore;
  }

  Set<String> _tailMembershipFor(
    Set<String> blacklistedUserIds, {
    required String? allowedAuthorId,
  }) {
    if (blacklistedUserIds.isEmpty) return const <String>{};
    final allowed = allowedAuthorId?.trim();
    if (allowed == null || allowed.isEmpty) {
      return Set<String>.unmodifiable(blacklistedUserIds);
    }
    return Set<String>.unmodifiable(
      blacklistedUserIds.where((id) => id != allowed),
    );
  }

  static bool _sameIds(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    for (final value in left) {
      if (!right.contains(value)) return false;
    }
    return true;
  }

  void _scheduleReplyTailCollection(ThreadDetailPageState state) {
    if (!mounted || !_replyTail.tailPending || _replyTail.isCollecting) return;
    if (_replyTail.hasFailure) return;
    final tailKey =
        '${state.tid}|${_queryIdentityFor(state)}|${state.currentPage}';
    if (_tailPageKey != tailKey) {
      _tailPageKey = tailKey;
      _tailAutoAttempted = false;
    }
    if (_tailAutoAttempted) return;
    _tailAutoAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_replyTail.tailPending || _replyTail.isCollecting) {
        return;
      }
      unawaited(_replyTail.ensureComplete(isCurrent: () => mounted));
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// 显式重试：末页末端操作发现尾部集合未完成时继续补取。
  void _retryReplyTail() {
    if (!mounted || !_replyTail.tailPending || _replyTail.isCollecting) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_replyTail.tailPending || _replyTail.isCollecting) {
        return;
      }
      _tailAutoAttempted = true;
      unawaited(
        _replyTail.ensureComplete(isCurrent: () => mounted, force: true),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _handleReplyTailChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// 返回图片阅读器时，若该楼位于回复栏下方，图片顶边让出吸顶栏高度。
  double _imageReturnTopInset(String pid) {
    if (_repliesHeaderHeight <= 0) return 0;
    final posts = ref
        .read(threadDetailControllerProvider(_currentThreadArgs))
        .value
        ?.posts;
    if (posts == null || posts.isEmpty) return 0;
    final firstIndex = posts.indexWhere((post) => post.isFirst);
    if (firstIndex < 0) return _repliesHeaderHeight;
    final index = posts.indexWhere((post) => post.pid == pid);
    if (index >= 0) return index > firstIndex ? _repliesHeaderHeight : 0;
    return _replyTail.tailPosts.any((post) => post.pid == pid)
        ? _repliesHeaderHeight
        : 0;
  }

  Future<void> _goToFirstPost(ThreadDetailController controller) async {
    // 顶栏、单键与双键向下共用“返回第一页主题正文”；过滤排除首楼时先解除
    // 作者过滤，跨页加载失败保留原页和原位置。
    _floorNavigation.resetDirection();
    final current = ref
        .read(threadDetailControllerProvider(_currentThreadArgs))
        .value;
    if (current != null && current.isOnlyAuthorView) {
      await _runReadingViewAction(
        controller.openAllPosts,
        userNavigation: true,
      );
      if (!mounted) return;
    }
    await _floorNavigation.firstPost(
      animate: !MediaQuery.disableAnimationsOf(context),
    );
  }

  Future<bool> _loadTopicBody(bool Function() current) async {
    var loaded = false;
    await _runReadingViewAction(
      () async {
        if (!current() || !mounted) return;
        final provider = threadDetailControllerProvider(_currentThreadArgs);
        final controller = ref.read(provider.notifier);
        // “只看该作者”排除主题正文时先解除作者过滤，正倒序偏好保留。
        if (ref.read(provider).value?.isOnlyAuthorView == true) {
          await controller.openAllPosts();
          if (!mounted || !current()) return;
        }
        loaded = await controller.loadTopicBody(isCurrent: current);
      },
      userNavigation: true,
      preserveFloorNavigation: true,
    );
    return loaded;
  }

  Future<bool> _loadAdjacentFloor(bool forward, bool Function() current) async {
    var loaded = false;
    await _runReadingViewAction(
      () async {
        if (!current() || !mounted) return;
        loaded = await ref
            .read(threadDetailControllerProvider(_currentThreadArgs).notifier)
            .loadAdjacentForFloor(forward: forward, isCurrent: current);
      },
      userNavigation: true,
      preserveFloorNavigation: true,
    );
    return loaded;
  }

  Future<void> _selectThreadPage(
    ThreadDetailController controller,
    ThreadDetailPageState state, {
    BuildContext? anchorContext,
  }) async {
    _cancelFloorNavigation();
    _controlsVisibility.reset();
    final owner = _readFloorPage()?.owner;
    final selected = await showThreadPagePicker(
      context,
      currentPage: state.currentPage,
      lastPage: state.lastPage,
      hasMore: state.hasMore,
      anchorContext: anchorContext,
    );
    if (!mounted ||
        selected == null ||
        selected == state.currentPage ||
        _readFloorPage()?.owner != owner) {
      return;
    }
    await _runPageActionAndScrollTop(() => controller.loadPage(selected));
  }

  void _openControlsSettings() {
    _cancelFloorNavigation();
    _controlsVisibility.reset();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ThreadControlsSettingsPage(),
      ),
    );
  }

  Future<void> _runPageActionAndScrollTop(
    FutureOr<void> Function() action,
  ) async {
    final observer = widget.bodyReadingObserver;
    final ownerRevision = _readingOwnerRevision;
    _cancelFloorNavigation();
    _controlsVisibility.reset();
    if (observer != null) {
      _readingSuspensions++;
      _bodyReadingCoordinator?.markUserNavigation();
      _bodyReadingCoordinator?.setActive(false);
      _pauseReading(observer);
      await _flushReading(observer);
    }
    try {
      if (!mounted || ownerRevision != _readingOwnerRevision) return;
      await action();
      if (!mounted || ownerRevision != _readingOwnerRevision) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          ownerRevision != _readingOwnerRevision ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final targetOffset = position.minScrollExtent;
      if ((position.pixels - targetOffset).abs() < 1) {
        return;
      }
      if (AppMotion.reduceMotion(context)) {
        _scrollController.jumpTo(targetOffset);
        return;
      }
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (observer != null && ownerRevision == _readingOwnerRevision) {
        _readingSuspensions--;
        if (mounted) {
          _readingVisible = false;
          _syncReadingVisibility();
        }
      }
    }
  }

  /// 切换正序／倒序后显式重置落点：倒序直跳页首，正序若含首楼则锚定至回复栏。
  Future<void> _runOrderViewAction(
    Future<void> Function() action, {
    required bool anchorRepliesHeader,
  }) async {
    final provider = threadDetailControllerProvider(_currentThreadArgs);
    final beforeState = ref.read(provider).value;
    final beforeQuery = beforeState == null
        ? null
        : _queryIdentityFor(beforeState);
    final observer = widget.bodyReadingObserver;
    final ownerRevision = _readingOwnerRevision;
    _cancelFloorNavigation();
    _controlsVisibility.reset();
    if (observer != null) {
      _readingSuspensions++;
      _bodyReadingCoordinator?.markUserNavigation();
      _bodyReadingCoordinator?.setActive(false);
      _pauseReading(observer);
      await _flushReading(observer);
    }
    try {
      if (!mounted || ownerRevision != _readingOwnerRevision) return;
      await action();
      if (!mounted || ownerRevision != _readingOwnerRevision) return;
      final afterState = ref.read(provider).value;
      if (afterState == null ||
          afterState.loadFailure != null ||
          _queryIdentityFor(afterState) == beforeQuery) {
        return;
      }
      final shouldAnchorReplies =
          anchorRepliesHeader &&
          !afterState.isReverseOrderView &&
          afterState.posts.any((post) => post.isFirst);
      if (shouldAnchorReplies) {
        setState(() => _repliesHeaderAnchorRevision++);
      }
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final preTarget = shouldAnchorReplies ? 0.0 : position.minScrollExtent;
        final clamped = preTarget
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if ((position.pixels - clamped).abs() >= 1) {
          _scrollController.jumpTo(clamped);
        }
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          ownerRevision != _readingOwnerRevision ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final targetOffset = shouldAnchorReplies ? 0.0 : position.minScrollExtent;
      final clamped = targetOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - clamped).abs() >= 1) {
        _scrollController.jumpTo(clamped);
      }
    } finally {
      if (observer != null && ownerRevision == _readingOwnerRevision) {
        _readingSuspensions--;
        if (mounted) {
          _readingVisible = false;
          _syncReadingVisibility();
        }
      }
    }
  }

  Future<void> _returnHome() async {
    _cancelFloorNavigation();
    _controlsVisibility.reset();
    final observer = widget.bodyReadingObserver;
    if (observer != null && !_readingClosing) {
      _readingClosing = true;
      _readingVisibilityRevision++;
      _bodyReadingCoordinator?.setActive(false);
      _pauseReading(observer);
      await _flushReading(observer);
      observer.retire();
    }
    if (!mounted) return;
    await returnToAdaptiveRoot(context);
  }

  Future<void> _openThreadReplyComposer(
    ThreadDetailArgs args,
    ThreadDetailPageState state,
  ) async {
    final fid = state.fid.trim();
    final tid = state.tid.trim();
    if (fid.isEmpty || tid.isEmpty) {
      return;
    }
    final result = await Navigator.of(context).push<ReplyComposerResult>(
      MaterialPageRoute<ReplyComposerResult>(
        builder: (_) => ReplyComposerPage(
          args: ReplyComposerArgs(
            target: ReplyTarget.thread(
              fid: fid,
              tid: tid,
              sourceUri: Uri.tryParse(_threadUrlForCopy(state)),
            ),
            title: state.subject,
          ),
        ),
      ),
    );
    await _handleReplyComposerResult(args, result);
  }

  Future<void> _handleReplyComposerResult(
    ThreadDetailArgs args,
    ReplyComposerResult? result,
  ) async {
    if (!mounted || result == null || !result.sent) {
      return;
    }
    _showActionNotice(
      ThreadActionNotice(
        code: ThreadActionNoticeCode.success,
        action: ThreadActionKind.reply,
        detail: ComposerTextResolver.submitSuccess(
          AppLocalizations.of(context),
          ComposerKind.reply,
          result.rawSuccessDetail,
        ),
      ),
    );
    await ref
        .read(threadDetailControllerProvider(args).notifier)
        .refreshAfterMutation();
  }

  Future<void> _copyActionUrl(String label, String url) {
    return _copyUrl(label, url);
  }

  Future<void> _copyThreadUrl(ThreadDetailPageState state) {
    return _copyUrl(
      AppLocalizations.of(context).threadDetailPostLink,
      _threadUrlForCopy(state),
    );
  }

  void _openDisplaySettings() {
    unawaited(
      // 显示设置统一走自适应面板：详情区窄屏为底部抽屉，宽屏为侧面板，
      // 不再依赖 Material 底部抽屉的拖拽手柄形态。
      showAdaptivePanel<void>(
        context: context,
        builder: (context) => const ForumHtmlReaderSettingsSheet(
          key: Key('thread-detail-display-settings-sheet'),
          showAuthorStyleControls: false,
          showResetButton: false,
        ),
      ),
    );
  }

  String _threadUrlForCopy(ThreadDetailPageState state) {
    final desktopUrl = state.desktopUrl?.trim();
    if (desktopUrl != null && desktopUrl.isNotEmpty) {
      return desktopUrl;
    }
    final tid = state.tid.trim().isNotEmpty
        ? state.tid.trim()
        : widget.tid.trim();
    if (tid.isEmpty) {
      return '';
    }
    final page = state.currentPage > 0
        ? state.currentPage
        : (widget.initialPage ?? 1);
    return Uri.parse(AppConfig.siteBaseUrl)
        .replace(
          path: '/forum.php',
          queryParameters: <String, String>{
            'mod': 'viewthread',
            'tid': tid,
            'mobile': '2',
            if (page > 1) 'page': page.toString(),
          },
        )
        .toString();
  }

  ThreadPostNavigation get _postNavigation => ThreadPostNavigation(
    routeSession: _postRouteSession,
    context: context,
    ref: ref,
    tid: widget.tid,
    imageReferer: _latestImageReferer,
    isCurrent: () => mounted,
  );
  void _openPostImages(ThreadPost post, ThreadImageOpenRequest request) =>
      _postNavigation.openImages(
        post,
        request,
        onBeforeExit: _imageReaderReturnCoordinator.beforeExitFor(request),
      );

  Future<void> _openPostActions(
    ThreadDetailArgs args,
    ThreadDetailPageState state,
    ThreadDetailController controller,
    ThreadPost sourcePost,
    ThreadPost displayPost, {
    Offset? position,
    ThreadPollOption? pollOption,
  }) async {
    if (_postActionActive) return;
    _postActionActive = true;
    final invalidation = ref.read(nativePageCacheInvalidationServiceProvider);
    try {
      final mutation =
          await ThreadPostActions(
            context: context,
            ref: ref,
            selectionRenderPreparer: const DefaultForumHtmlRenderPreparer(
              enablePlainTextLinks: true,
            ),
            target: ThreadPostActionContext(
              tid: args.tid,
              fid: state.fid,
              subject: state.subject,
              page: state.currentPage,
              capabilities: state.capabilities,
              sourceUri: Uri.tryParse(_threadUrlForCopy(state)),
            ),
            imageReferer: _imageRefererFor(state),
            isCurrent: () => mounted && widget.tid == args.tid,
            onViewOnlyAuthor: (authorId) => _runReadingViewAction(
              () => controller.openOnlyAuthor(authorId: authorId),
              userNavigation: true,
            ),
            onBlockUser:
                blacklistUserActionAvailable(
                  ref,
                  userId: sourcePost.authorId,
                  username: sourcePost.author,
                )
                ? (post) => blockBlacklistUser(
                    context,
                    ref,
                    userId: post.authorId,
                    username: post.author,
                  )
                : null,
          ).show(
            position: position,
            bottomInset: _controlsHeight + 16,
            sourcePost: sourcePost,
            displayPost: displayPost,
            pollOption: pollOption,
          );
      if (mutation == null) return;
      try {
        await invalidation.invalidateThread(args.tid);
      } catch (_) {
        // A confirmed write remains valid if cache maintenance fails.
      }
      if (mounted && widget.tid == args.tid) await controller.refresh();
    } finally {
      _postActionActive = false;
    }
  }

  ThreadPost? _topicAuthorPost(ThreadDetailPageState state) {
    for (final post in state.posts) {
      if (post.isFirst) {
        return post;
      }
    }
    return null;
  }

  List<ThreadPostTagLink> _topicTagsFor(ThreadDetailPageState state) {
    if (!state.supports(ThreadDetailCapability.tagLinks)) {
      return const <ThreadPostTagLink>[];
    }
    for (final post in state.posts) {
      if (post.isFirst) {
        return post.tagLinks;
      }
    }
    return const <ThreadPostTagLink>[];
  }

  void _openThreadTag(String tagId) {
    final normalized = tagId.trim();
    if (normalized.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YamiboTagThreadPage(tagId: normalized),
      ),
    );
  }

  void _openAuthorProfile(ThreadPost post) => _postNavigation.openAuthor(post);
  void _openCommentAuthorProfile(ThreadPostCommentEntry comment) =>
      _postNavigation.openCommentAuthor(comment);

  void _onTargetVisible(String pid) {
    if (!mounted ||
        _targetHighlightStarted ||
        widget.targetPid?.trim() != pid) {
      return;
    }
    _targetHighlightStarted = true;
    setState(() => _highlightPostPid = pid);
    _highlightClearTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightPostPid == pid) {
        setState(() => _highlightPostPid = null);
      }
    });
  }

  void _openForumLink(String url) => _postNavigation.openLink(url);
  Future<void> _copyUrl(String label, String url) =>
      _postNavigation.copyUrl(label, url);

  void _showActionNotice(ThreadActionNotice notice) {
    _showSnackBar(
      ThreadTextResolver.actionNotice(AppLocalizations.of(context), notice),
    );
  }

  void _showSnackBar(String message) {
    showTransientSnackBar(context, message);
  }

  ThreadDetailContentProjection _resolveProjection(
    ThreadDetailPageState source, {
    required TextConversionMode mode,
    required String converterId,
    required ThreadDetailContentProjection? candidate,
  }) {
    final sourceRevision = ThreadDetailContentProjector.sourceRevisionFor(
      source,
    );
    if (candidate != null &&
        candidate.mode == mode &&
        candidate.converterId == converterId &&
        candidate.sourceRevision == sourceRevision) {
      return candidate.rebaseTransientState(source);
    }
    return ThreadDetailContentProjection.raw(
      source,
      mode: mode,
      converterId: converterId,
      sourceRevision: sourceRevision,
    );
  }
}

class _ThreadDetailMoreMenu extends StatelessWidget {
  const _ThreadDetailMoreMenu({
    required this.state,
    required this.onOnlyAuthor,
    required this.onAllPosts,
    required this.onReverseOrder,
    required this.onNormalOrder,
    this.onReturnHome,
    required this.onDisplaySettings,
    required this.onControlsSettings,
    required this.onBlockThread,
    this.onBlockAuthor,
  });

  final ThreadDetailPageState state;
  final VoidCallback onOnlyAuthor;
  final VoidCallback onAllPosts;
  final VoidCallback onReverseOrder;
  final VoidCallback onNormalOrder;
  final VoidCallback? onReturnHome;
  final VoidCallback onDisplaySettings;
  final VoidCallback onControlsSettings;
  final VoidCallback onBlockThread;
  final VoidCallback? onBlockAuthor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPopupMenuButton<String>(
      key: const Key('thread-detail-more-menu'),
      tooltip: l10n.threadDetailMore,
      itemBuilder: (context) => [
        if (state.supports(ThreadDetailCapability.alternateViews)) ...[
          AppPopupMenuItem<String>(
            value: state.isOnlyAuthorView ? 'all-posts' : 'only-author',
            label: state.isOnlyAuthorView
                ? l10n.threadDetailAllPosts
                : l10n.threadDetailOnlyAuthor,
            icon: const Icon(Icons.person_outline),
          ),
          AppPopupMenuItem<String>(
            value: state.isReverseOrderView ? 'normal-order' : 'reverse-order',
            label: state.isReverseOrderView
                ? l10n.threadDetailNormalOrder
                : l10n.threadDetailReverseOrder,
            icon: const Icon(Icons.swap_vert),
          ),
        ],
        AppPopupMenuItem<String>(
          value: 'controls-settings',
          label: l10n.threadControlsTitle,
          icon: const Icon(Icons.settings_suggest_outlined),
        ),
        AppPopupMenuItem<String>(
          key: const Key('thread-detail-display-settings-menu-item'),
          value: 'display-settings',
          label: l10n.threadDetailDisplaySettings,
          icon: const Icon(Icons.tune),
        ),
        AppPopupMenuItem<String>(
          key: const Key('thread-detail-block-menu-item'),
          value: 'block-thread',
          label: l10n.contentFilterBlockAction,
          icon: const Icon(Icons.visibility_off_outlined),
        ),
        if (onBlockAuthor != null)
          AppPopupMenuItem<String>(
            key: const Key('thread-detail-block-author-menu-item'),
            value: 'block-author',
            label: l10n.blacklistBlockAuthor,
            icon: const Icon(Icons.person_off_outlined),
            danger: true,
          ),
        if (onReturnHome != null)
          AppPopupMenuItem<String>(
            key: const Key('thread-detail-back-home-menu-item'),
            value: 'home',
            label: l10n.threadDetailBackHome,
            icon: const Icon(Icons.home_outlined),
          ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'only-author':
            onOnlyAuthor();
            return;
          case 'all-posts':
            onAllPosts();
            return;
          case 'reverse-order':
            onReverseOrder();
            return;
          case 'normal-order':
            onNormalOrder();
            return;
          case 'controls-settings':
            onControlsSettings();
            return;
          case 'display-settings':
            onDisplaySettings();
            return;
          case 'block-thread':
            onBlockThread();
            return;
          case 'block-author':
            onBlockAuthor?.call();
            return;
          case 'home':
            onReturnHome?.call();
            return;
        }
      },
    );
  }
}

class _ThreadErrorView extends StatelessWidget {
  const _ThreadErrorView({
    required this.subject,
    required this.message,
    required this.onRetry,
    this.onOpenHome,
  });

  final String subject;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ThreadDetailEntrySurface(
      subject: subject,
      child: AppErrorState(
        message: message,
        retryLabel: l10n.commonRetry,
        retryKey: const Key('thread-detail-retry-button'),
        onRetry: onRetry,
        secondaryAction: onOpenHome == null
            ? null
            : TextButton(
                onPressed: onOpenHome,
                child: Text(l10n.threadPostOpenHome),
              ),
      ),
    );
  }
}

Widget threadDetailPreviewShell(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: ColoredBox(
            color: ThreadDetailNativePalette.resolve(AppTheme.light())
                .background,
            child: child,
          ),
        ),
      ),
    ),
  );
}

@Preview(
  name: 'Thread detail post card',
  group: 'Thread/Detail',
  size: Size(393, 520),
  wrapper: threadDetailPreviewShell,
)
Widget threadDetailPostCardPreview() {
  final state = ThreadDetailPageState.initial(tid: '572529', subject: '帖子楼卡片预览')
      .copyWith(
        fid: '33',
        typeid: '86',
        sourceTagName: '讨论',
        currentPage: 1,
        lastPage: 8,
        views: 4096,
        replies: 128,
        posts: <ThreadPost>[_threadDetailPreviewPost],
      );
  final palette = ThreadDetailNativePalette.resolve(AppTheme.light());
  return SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: ThreadPostCard(
      post: _threadDetailPreviewPost,
      state: state,
      imageReferer: null,
      onOpenAuthorProfile: (_) {},
      onCopyActionUrl: (_, _) {},
      onOpenPostLink: (_) {},
      onOpenPostImages: null,
      onTogglePollOption: (_, _) {},
      onSubmitPollVote: (_) {},
      palette: palette,
    ),
  );
}

final ThreadPost _threadDetailPreviewPost = ThreadPost(
  pid: 'preview-post',
  author: '蜥蜴少女与神明',
  authorId: '278948',
  number: 12,
  isFirst: false,
  dateline: '2026-06-23 12:48',
  avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/27/89/48_avatar_small.jpg',
  replyUrl: 'https://bbs.yamibo.com/forum.php?mod=post&action=reply&fid=33&tid=572529&repquote=preview-post',
  rateUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=rate&tid=572529&pid=preview-post',
  commentUrl: 'https://bbs.yamibo.com/forum.php?mod=misc&action=comment&tid=572529&pid=preview-post',
  message:
      '<div class="quote"><blockquote><b>hsyhlj</b>: 后面楼主参加活动的应该就是梅小雪那篇武侠了吧。</blockquote></div>'
      '<p>那篇很好啊我很喜欢 <img src="static/image/smiley/comcom/2.gif" class="vm"> '
      '角色之间的互动很轻盈，读起来像是在夏天的海边慢慢展开的一封信。</p>',
  tagLinks: const <ThreadPostTagLink>[
    ThreadPostTagLink(
      label: '百合',
      tagId: '20674',
      url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=20674&type=thread',
    ),
    ThreadPostTagLink(
      label: '读后感',
      tagId: '21920',
      url: 'https://bbs.yamibo.com/misc.php?mod=tag&id=21920&type=thread',
    ),
  ],
  comments: const <ThreadPostCommentEntry>[
    ThreadPostCommentEntry(
      author: '花実',
      authorId: '231169',
      avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/23/11/69_avatar_small.jpg',
      message: '这一段点评会展示在正文下面，头像、名称、内容和时间都保留下来。',
      dateline: '2026-06-23 13:12',
    ),
    ThreadPostCommentEntry(
      author: 'tagami',
      authorId: '14577',
      avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/01/45/77_avatar_small.jpg',
      message: '短点评也应该保持轻量，不抢正文和评分的视觉层级。',
      dateline: '2026-06-23 13:18',
    ),
  ],
  ratingSummary: const ThreadPostRatingSummary(
    participantText: '已有 2 人评分',
    scoreText: '积分 +8',
    ratings: <ThreadPostRating>[
      ThreadPostRating(userName: 'hsyhlj', score: '+5', reason: '我很赞同'),
      ThreadPostRating(userName: 'thessky', score: '+3', reason: '好萌好萌好萌'),
    ],
  ),
);
