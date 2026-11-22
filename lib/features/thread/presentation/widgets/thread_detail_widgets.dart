import 'dart:async';

import 'package:y300/app/content_rendering/native_forum_html_render_theme_factory.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/media/device_memory_profile.dart';
import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, RenderSliverPadding, SliverGeometry;
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/forum_image_precache_service.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/thread/domain/models/thread_image_open_models.dart';
import 'package:y300/features/thread/domain/models/thread_ui_feedback.dart';
import 'package:y300/features/thread/domain/models/thread_post_target.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/features/thread/presentation/html_rendering/thread_post_html_first_body.dart';
import 'package:y300/features/thread/presentation/thread_detail_render_entries.dart';
import 'package:y300/features/thread/presentation/thread_detail_content_projection.dart';

import '../thread_detail_prepared_body.dart';
import '../services/thread_body_preparation_handoff.dart';
import '../services/thread_body_chunk_preparation.dart';
import '../services/thread_body_presentation.dart';
import '../services/thread_floor_navigation_coordinator.dart';
import '../services/thread_image_visibility_diagnostics.dart';
import '../services/thread_detail_quick_scroll_coordinator.dart';

import 'package:y300/features/thread/presentation/thread_detail_state.dart';
import 'package:y300/features/thread/presentation/thread_post_rate_form_projection.dart';
import 'package:y300/features/thread/presentation/thread_post_interaction_models.dart';
import 'package:y300/features/thread/presentation/thread_text_resolver.dart';
import 'package:y300/features/thread/presentation/services/thread_post_viewport_anchor_coordinator.dart';
import 'package:y300/features/thread/presentation/services/thread_image_preload_policy.dart';
import 'package:y300/features/thread/presentation/services/thread_image_reader_return_coordinator.dart';
import 'package:y300/features/thread/presentation/services/thread_body_reading_coordinator.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/features/thread/presentation/widgets/thread_replies_header.dart';
import 'package:y300/features/thread/presentation/widgets/thread_poll_option_image.dart';
import 'package:y300/features/thread/presentation/widgets/thread_post_render_context.dart';
import 'package:y300/shared/widgets/forum_cached_avatar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';
import 'package:y300/shared/widgets/forum_content_spacing.dart';
import 'package:y300/shared/widgets/forum_metric_pill.dart';
import 'package:y300/shared/widgets/forum_native_surface.dart';
import 'package:y300/shared/widgets/forum_pull_to_refresh.dart';
import 'package:y300/shared/widgets/native_pagination_bar.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

// File split (Phase 5b): cohesive widget groups live in part files under the
// same library so private members and shared helpers remain accessible without
// changing visibility or call sites.
part 'thread_detail_pagination.dart';
part 'thread_detail_poll.dart';
part 'thread_detail_sheets.dart';
part 'thread_detail_footer.dart';
part 'thread_detail_atoms.dart';
part 'thread_detail_card.dart';
part 'thread_detail_loading.dart';
part 'thread_detail_chunk_body.dart';
part 'thread_detail_endpoint_navigation.dart';
part 'thread_detail_floor_navigation.dart';
part 'thread_topic_tag_bar.dart';
part 'thread_blacklisted_post.dart';

typedef ThreadPollOptionActionCallback = void Function(
  ThreadPost post,
  ThreadPollOption option,
);

class ThreadDetailContent extends ConsumerStatefulWidget {
  const ThreadDetailContent({
    super.key,
    required this.state,
    this.projection,
    this.scrollController,
    this.imageReaderReturnCoordinator,
    this.bodyReadingCoordinator,
    this.quickScrollCoordinator,
    this.highlightPostPid,
    this.targetPid,
    this.landing = ThreadPostLanding.top,
    this.onTargetVisible,
    required this.imageReferer,
    required this.onLoadPreviousPage,
    required this.onLoadNextPage,
    required this.onLoadPageNumber,
    required this.onOpenAuthorProfile,
    required this.onOpenCommentAuthorProfile,
    required this.onCopyActionUrl,
    required this.onOpenPostLink,
    this.onOpenPostImages,
    required this.onOpenPostActions,
    this.onOpenPollOptionActions,
    this.htmlImagePrecacheService,
    this.imageVisibilityObserver,
    this.onPostBuilt,
    this.onScrollStabilizerEvent,
    required this.onTogglePollOption,
    required this.onSubmitPollVote,
    this.onLoadAllRatings,
    this.onLoadMoreComments,
    this.displayExtraCommentsByPostId = const {},
    this.enableBodyChunking = true,
    this.allowedBlacklistedAuthorId,
    this.replyTailPosts = const <ThreadPost>[],
    this.movedBlacklistedPids = const <String>{},
    this.showReplyTail = false,
    this.replyTailRevision = 0,
    this.onToggleAuthorFilter,
    this.onOrderChanged,
    this.floorNavigation,
    this.bottomInset = 0,
    this.onRepliesHeaderHeightChanged,
    this.firstPostTitleKey,
    this.repliesHeaderAnchorRevision = 0,
    this.defaultRatingsExpanded = true,
  });

  final ThreadDetailPageState state;
  final ThreadDetailContentProjection? projection;
  final VoidCallback? onToggleAuthorFilter;
  final ValueChanged<bool>? onOrderChanged;
  final ThreadFloorNavigationCoordinator? floorNavigation;
  final double bottomInset;
  final ValueChanged<double>? onRepliesHeaderHeightChanged;

  /// 首楼标题测点，同时覆盖整卡与分块 header 两条渲染路径。
  final GlobalKey? firstPostTitleKey;

  /// 从倒序切回正序时递增，令列表将回复栏作为锚点落在首屏顶部。
  final int repliesHeaderAnchorRevision;

  /// 帖子评分默认是否展开，由偏好设置注入。
  final bool defaultRatingsExpanded;
  final bool enableBodyChunking;

  /// Blocked replies collected for the end of the last page.
  final List<ThreadPost> replyTailPosts;

  /// Stable pids removed from their source floor position.
  final Set<String> movedBlacklistedPids;

  /// Whether the current page is the thread's last page.
  final bool showReplyTail;

  /// Display generation for the reply tail projection.
  final int replyTailRevision;

  /// Topic author allowed for this route when the whole-thread prompt was
  /// accepted; their floors are not collapsed for this session.
  final String? allowedBlacklistedAuthorId;
  final ScrollController? scrollController;
  final ThreadImageReaderReturnCoordinator? imageReaderReturnCoordinator;
  final ThreadBodyReadingCoordinator? bodyReadingCoordinator;
  final ThreadDetailQuickScrollCoordinator? quickScrollCoordinator;
  final String? highlightPostPid;
  final String? targetPid;
  final ThreadPostLanding landing;
  final ValueChanged<String>? onTargetVisible;
  final String imageReferer;
  final VoidCallback onLoadPreviousPage;
  final VoidCallback onLoadNextPage;
  final ValueChanged<int> onLoadPageNumber;
  final ValueChanged<ThreadPost> onOpenAuthorProfile;
  final ValueChanged<ThreadPostCommentEntry> onOpenCommentAuthorProfile;
  final void Function(String label, String url) onCopyActionUrl;
  final ValueChanged<String> onOpenPostLink;
  final void Function(ThreadPost post, ThreadImageOpenRequest request)?
  onOpenPostImages;
  final ValueChanged<ThreadPost> onOpenPostActions;
  final ThreadPollOptionActionCallback? onOpenPollOptionActions;
  final ForumImagePrecacheService? htmlImagePrecacheService;
  final ForumHtmlImageVisibilityObserver? imageVisibilityObserver;
  final ValueChanged<int>? onPostBuilt;

  final ValueChanged<ThreadDetailScrollStabilizerEvent>?
  onScrollStabilizerEvent;
  final void Function(ThreadPoll poll, ThreadPollOption option)
  onTogglePollOption;
  final ValueChanged<ThreadPoll> onSubmitPollVote;
  final ValueChanged<ThreadPost>? onLoadAllRatings;
  final ValueChanged<ThreadPost>? onLoadMoreComments;
  final Map<String, List<ThreadPostCommentEntry>> displayExtraCommentsByPostId;

  @override
  ConsumerState<ThreadDetailContent> createState() =>
      _ThreadDetailContentState();
}

class _ThreadDetailContentState extends ConsumerState<ThreadDetailContent>
    with _ThreadDetailEndpointNavigation, _ThreadDetailFloorNavigation {
  late final _isLowRamDevice =
      DeviceMemoryProfileStore.current?.isLowRamDevice ?? false;
  @override
  late final _preparedBodies = ThreadDetailPreparedBodyStore(
    maxRetainedCodeUnits: (_isLowRamDevice ? 2 : 4) * 1024 * 1024,
  );
  late final _bodyHandoffs = ThreadBodyPreparationHandoff(_preparedBodies);
  late final _chunkPreparation = ThreadBodyChunkPreparation(_preparedBodies);
  final _footerExpansions = <String, _ThreadPostFooterExpansion>{};
  final _expandedBlacklistedPids = <String>{};
  final _wholeBodyPresentations = ThreadBodyPresentationStore();
  // Saved body percentages require complete actual geometry. Source reading
  // pages keep their existing whole-body renderer and reading observer.
  @override
  bool get _canChunkBodies =>
      widget.enableBodyChunking && widget.bodyReadingCoordinator == null;
  int _bodyGeneration = 0;
  @override
  Object? _renderLayoutIdentity;
  @override
  ThreadPostViewportAnchorSnapshot? _pendingChunkAnchor;
  final _entryPlanner = const ThreadDetailRenderEntryPlanner();
  @override
  final GlobalKey _viewportKey = GlobalKey(debugLabel: 'thread-detail-list');
  @override
  final GlobalKey _listEndKey = GlobalKey(debugLabel: 'thread-detail-list-end');
  @override
  GlobalKey _targetCenterKey = GlobalKey(
    debugLabel: 'thread-detail-target-center',
  );
  final GlobalKey _targetVisibilityKey = GlobalKey(
    debugLabel: 'thread-detail-target-visible',
  );
  String? _reportedTargetIdentity;
  int _readingContentRevision = 0;
  late ThreadDetailScrollStabilizer _scrollStabilizer;
  @override
  late ThreadPostViewportAnchorCoordinator _projectionAnchorCoordinator;
  ForumHtmlImageViewportCoordinator? _imageViewportCoordinator;
  final _imageVisibilityDiagnostics = ThreadImageVisibilityDiagnostics();
  late final _imagePreloadPolicy = ThreadImagePreloadPolicy(
    imageCacheBudgetBytes: PaintingBinding.instance.imageCache.maximumSizeBytes,
    isLowRamDevice: _isLowRamDevice,
  );
  ValueListenable<TickerModeData>? _tickerModeNotifier;
  final _imageAspectRatioTracker = _ThreadDetailImageAspectRatioTracker();
  final GlobalKey _repliesHeaderKey = GlobalKey(
    debugLabel: 'thread-replies-header',
  );
  final GlobalKey _stickyRepliesHeaderKey = GlobalKey(
    debugLabel: 'thread-replies-header-sticky',
  );
  @override
  double _repliesHeaderHeight = 0;
  double? _repliesHeaderContentOffset;
  @override
  bool _repliesHeaderPinned = false;
  @override
  bool _anchorToRepliesHeader = false;
  bool _stickyHeaderSyncScheduled = false;
  List<ThreadDetailRenderEntry> _lastEntries = const [];
  bool _lastAnchoredListMode = false;

  @override
  void initState() {
    super.initState();
    _scrollStabilizer = ThreadDetailScrollStabilizer(
      scrollController: widget.scrollController,
      viewportKey: _viewportKey,
      onEvent: widget.onScrollStabilizerEvent,
    );
    _projectionAnchorCoordinator = ThreadPostViewportAnchorCoordinator(
      scrollController: widget.scrollController,
      viewportKey: _viewportKey,
    );
    _syncImageViewportCoordinator();
    _bindEndpointNavigation();
    _bindFloorNavigation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getValuesNotifier(context);
    if (!identical(_tickerModeNotifier, notifier)) {
      _tickerModeNotifier?.removeListener(_handleTickerModeChanged);
      _tickerModeNotifier = notifier;
      notifier.addListener(_handleTickerModeChanged);
    }
    _handleTickerModeChanged();
  }

  @override
  void didUpdateWidget(covariant ThreadDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.state.currentPage != widget.state.currentPage ||
        oldWidget.state.queryParameters['authorid'] !=
            widget.state.queryParameters['authorid'] ||
        oldWidget.state.queryParameters['ordertype'] !=
            widget.state.queryParameters['ordertype']) {
      _imageVisibilityDiagnostics.reset();
      _imageViewportCoordinator?.reset();
    }
    _updateEndpointNavigation(oldWidget);
    _updateFloorNavigation(oldWidget);
    if (widget.repliesHeaderAnchorRevision !=
            oldWidget.repliesHeaderAnchorRevision &&
        !widget.state.isReverseOrderView) {
      _anchorToRepliesHeader = true;
    } else if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.state.currentPage != widget.state.currentPage ||
        oldWidget.state.queryParameters['authorid'] !=
            widget.state.queryParameters['authorid'] ||
        oldWidget.state.queryParameters['ordertype'] !=
            widget.state.queryParameters['ordertype'] ||
        oldWidget.targetPid != widget.targetPid ||
        oldWidget.landing != widget.landing ||
        !identical(oldWidget.scrollController, widget.scrollController)) {
      _anchorToRepliesHeader = false;
    }
    if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.state.currentPage != widget.state.currentPage ||
        oldWidget.state.queryParameters['authorid'] !=
            widget.state.queryParameters['authorid'] ||
        oldWidget.state.queryParameters['ordertype'] !=
            widget.state.queryParameters['ordertype'] ||
        !identical(oldWidget.scrollController, widget.scrollController)) {
      _repliesHeaderContentOffset = null;
      _repliesHeaderPinned = false;
    }
    if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.state.currentPage != widget.state.currentPage ||
        oldWidget.state.queryParameters['authorid'] !=
            widget.state.queryParameters['authorid'] ||
        oldWidget.state.queryParameters['ordertype'] !=
            widget.state.queryParameters['ordertype'] ||
        !identical(oldWidget.scrollController, widget.scrollController) ||
        oldWidget.bodyReadingCoordinator != widget.bodyReadingCoordinator) {
      _wholeBodyPresentations.clear();
    }
    if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.state.currentPage != widget.state.currentPage) {
      _clearFooterExpansions();
    } else if (oldWidget.defaultRatingsExpanded !=
        widget.defaultRatingsExpanded) {
      for (final expansion in _footerExpansions.values) {
        if (!expansion.ratingsOverridden) {
          expansion.value = (
            comments: expansion.value.comments,
            ratings: widget.defaultRatingsExpanded,
            poll: expansion.value.poll,
          );
        }
      }
    }
    if (oldWidget.state.tid != widget.state.tid) {
      _expandedBlacklistedPids.clear();
    }
    if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.state.currentPage != widget.state.currentPage ||
        oldWidget.enableBodyChunking != widget.enableBodyChunking ||
        oldWidget.bodyReadingCoordinator != widget.bodyReadingCoordinator) {
      _retirePreparedBodies();
    }
    if (widget.bodyReadingCoordinator != null &&
        (oldWidget.state.posts.length != widget.state.posts.length ||
            List.generate(widget.state.posts.length, (index) => index).any(
              (index) =>
                  index >= oldWidget.state.posts.length ||
                  oldWidget.state.posts[index].pid !=
                      widget.state.posts[index].pid ||
                  oldWidget.state.posts[index].message !=
                      widget.state.posts[index].message,
            ))) {
      _readingContentRevision++;
    }
    if (oldWidget.state.tid != widget.state.tid ||
        oldWidget.targetPid != widget.targetPid ||
        oldWidget.landing != widget.landing) {
      _reportedTargetIdentity = null;
    }
    final oldProjection = oldWidget.projection;
    final newProjection = widget.projection;
    final tailChanged =
        oldWidget.replyTailRevision != widget.replyTailRevision ||
        oldWidget.showReplyTail != widget.showReplyTail ||
        !setEquals(oldWidget.movedBlacklistedPids, widget.movedBlacklistedPids);
    final shouldRestoreProjectionAnchor =
        identical(oldWidget.scrollController, widget.scrollController) &&
        ((oldProjection != null &&
                newProjection != null &&
                oldProjection.sourceRevision == newProjection.sourceRevision &&
                oldProjection.displayIdentity !=
                    newProjection.displayIdentity) ||
            tailChanged);
    final projectionAnchor = shouldRestoreProjectionAnchor
        ? _projectionAnchorCoordinator.capture(_sourcePidsFor(oldWidget))
        : null;
    if (widget.enableBodyChunking && projectionAnchor != null) {
      _pendingChunkAnchor = projectionAnchor;
    }
    if (!identical(oldWidget.scrollController, widget.scrollController) ||
        !identical(
          oldWidget.onScrollStabilizerEvent,
          widget.onScrollStabilizerEvent,
        )) {
      _scrollStabilizer.dispose();
      _scrollStabilizer = ThreadDetailScrollStabilizer(
        scrollController: widget.scrollController,
        viewportKey: _viewportKey,
        onEvent: widget.onScrollStabilizerEvent,
      );
      _projectionAnchorCoordinator.updateScrollController(
        widget.scrollController,
      );
    }
    if (oldWidget.imageVisibilityObserver != widget.imageVisibilityObserver ||
        !identical(
          oldWidget.htmlImagePrecacheService,
          widget.htmlImagePrecacheService,
        )) {
      _imageViewportCoordinator?.dispose();
      _imageVisibilityDiagnostics.reset();
      _imageViewportCoordinator = null;
      _syncImageViewportCoordinator();
    }
    if (!identical(oldWidget.state.posts, widget.state.posts) ||
        oldWidget.state.currentPage != widget.state.currentPage) {
      _imageViewportCoordinator?.reset();
    }
    _projectionAnchorCoordinator.restoreAfterFrame(projectionAnchor);
  }

  @override
  void dispose() {
    _disposeEndpointNavigation();
    _disposeFloorNavigation();
    _clearFooterExpansions();
    _wholeBodyPresentations.clear();
    _retirePreparedBodies();
    _chunkPreparation.dispose();
    _tickerModeNotifier?.removeListener(_handleTickerModeChanged);
    _imageViewportCoordinator?.dispose();
    _imageVisibilityDiagnostics.dispose();
    _scrollStabilizer.dispose();
    _projectionAnchorCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wholeBodyHtml = {
      for (final post in _postProjections)
        post.sourcePost.pid: post.displayPost.message,
    };
    _wholeBodyPresentations.retainWhere(
      (pid, html) =>
          widget.bodyReadingCoordinator == null &&
          wholeBodyHtml[pid] == html &&
          _preparedBodies[pid] == null,
    );
    final footerPids = _sourcePidsFor(widget).toSet();
    _footerExpansions.removeWhere((pid, expansion) {
      if (footerPids.contains(pid)) return false;
      expansion.dispose();
      return true;
    });
    if (_canChunkBodies) {
      final activePids = _sourcePidsFor(widget).toSet();
      _bodyHandoffs.retainPids(activePids);
      _preparedBodies.retainWhere((pid, _) => activePids.contains(pid));
      _chunkPreparation.retainCurrent();
      if (_preparedBodies.bodies.isNotEmpty) {
        final fontBinding = ref.watch(forumHtmlReaderFontBindingProvider);
        final layoutIdentity = (
          fontBinding.preferences.renderOptions,
          fontBinding.isReady,
          fontBinding.cacheKey,
          Theme.of(context),
          MediaQuery.sizeOf(context),
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
        );
        if (_renderLayoutIdentity != null &&
            _renderLayoutIdentity != layoutIdentity) {
          final snapshot = _projectionAnchorCoordinator.capture(
            _sourcePidsFor(widget),
          );
          _pendingChunkAnchor = snapshot;
          _projectionAnchorCoordinator.restoreAfterFrame(snapshot);
        }
        _renderLayoutIdentity = layoutIdentity;
      }
    }
    // Validate a queued rebase against this build's actual layout inputs first.
    _prepareEndpointBuild();
    _prepareFloorBuild();
    final palette = ThreadDetailNativePalette.resolve(
      Theme.of(context),
      continuous: true,
    );
    widget.bodyReadingCoordinator?.bindContent(
      tid: widget.state.tid,
      page: widget.state.currentPage,
      identity: (
        widget.state.tid,
        widget.state.currentPage,
        widget.state.queryParameters['authorid'],
        widget.state.queryParameters['ordertype'],
        _readingContentRevision,
        widget.projection?.displayIdentity,
      ),
      viewportKey: _viewportKey,
    );
    widget.imageReaderReturnCoordinator?.updatePage(
      tid: widget.state.tid,
      page: widget.state.currentPage,
      bodyHtmlByPid: {
        for (final projection in _postProjections)
          projection.sourcePost.pid: projection.displayPost.message,
      },
    );
    final blacklistedUserIds = ref.watch(blacklistedUserIdsProvider);
    final entries = _entryPlanner.buildProjectionEntries(
      posts: _postProjections,
      targetPid: _endpointTarget == null ? _activeTargetPid : null,
      landing: _endpointTarget == null ? _activeLanding : ThreadPostLanding.top,
      bodyManifests: _preparedBodies.manifests,
      isCollapsed: (post) {
        final authorId = post.authorId.trim();
        if (authorId.isNotEmpty &&
            authorId == widget.allowedBlacklistedAuthorId) {
          return false;
        }
        return authorId.isNotEmpty &&
            blacklistedUserIds.contains(authorId) &&
            !_expandedBlacklistedPids.contains(post.pid);
      },
    );
    _projectionAnchorCoordinator.prune(
      _postProjections.map((post) => post.sourcePost.pid),
    );
    final hasRepliesHeader = entries.any(
      (entry) => entry.kind == ThreadDetailRenderEntryKind.repliesHeader,
    );
    _imageAspectRatioTracker.resetFor(_imageAspectRatioSignature());
    final endpointAnchored = _endpointTarget != null && entries.isNotEmpty;
    final repliesHeaderAnchorIndex =
        _anchorToRepliesHeader && !endpointAnchored && _floorTargetPid == null
        ? entries.indexWhere(
            (entry) => entry.kind == ThreadDetailRenderEntryKind.repliesHeader,
          )
        : -1;
    final repliesHeaderAnchored = repliesHeaderAnchorIndex > 0;
    final targetPid = _activeTargetPid?.trim();
    final targetEntryIndex =
        endpointAnchored ||
            repliesHeaderAnchored ||
            targetPid == null ||
            targetPid.isEmpty
        ? -1
        : entries.indexWhere(
            (entry) =>
                (_activeLanding == ThreadPostLanding.bodyEnd
                    ? entry.kind == ThreadDetailRenderEntryKind.postFooter ||
                          entry.kind ==
                              ThreadDetailRenderEntryKind.blacklistedPost
                    : entry.kind == ThreadDetailRenderEntryKind.postCard ||
                          entry.kind ==
                              ThreadDetailRenderEntryKind.postHeader ||
                          entry.kind ==
                              ThreadDetailRenderEntryKind.blacklistedPost) &&
                entry.sourcePost?.pid == targetPid,
          );
    final anchored =
        endpointAnchored || repliesHeaderAnchored || targetEntryIndex >= 0;
    if (anchored != _lastAnchoredListMode) {
      // 切换居中定位列表与标准列表时坐标系不同，丢弃旧偏移避免误判吸顶。
      _repliesHeaderContentOffset = null;
    }
    _lastEntries = entries;
    _lastAnchoredListMode = anchored;
    if (endpointAnchored) {
      return _buildTargetAnchoredList(entries: entries, palette: palette);
    }
    if (repliesHeaderAnchored) {
      return _buildTargetAnchoredList(
        entries: entries,
        targetEntryIndex: repliesHeaderAnchorIndex,
        anchorAtRepliesHeader: true,
        palette: palette,
      );
    }
    if (targetEntryIndex >= 0) {
      return _buildTargetAnchoredList(
        entries: entries,
        targetEntryIndex: targetEntryIndex,
        palette: palette,
      );
    }
    if (_canChunkBodies) {
      return _withStickyRepliesHeader(
        SizedBox.expand(
          key: _viewportKey,
          child: CustomScrollView(
            key: const Key('thread-detail-list'),
            controller: widget.scrollController,
            physics: ForumPullToRefresh.scrollPhysics,
            scrollCacheExtent: _imagePreloadPolicy.layoutCacheExtent,
            semanticChildCount: entries.length,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  ForumContentSpacing.pageHorizontal,
                  ForumContentSpacing.listTop,
                  ForumContentSpacing.pageHorizontal,
                  ForumContentSpacing.listBottom + widget.bottomInset,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => KeyedSubtree(
                      key: ValueKey(entries[index].key),
                      child: _withListEndMarker(
                        entries: entries,
                        index: index,
                        child: _buildEntry(context, entries[index], palette),
                      ),
                    ),
                    childCount: entries.length,
                    addAutomaticKeepAlives: true,
                    findChildIndexCallback: (key) =>
                        _entryIndexForKey(entries, key),
                  ),
                ),
              ),
            ],
          ),
        ),
        present: hasRepliesHeader,
        palette: palette,
      );
    }
    return _withStickyRepliesHeader(
      SizedBox.expand(
        key: _viewportKey,
        child: ListView.builder(
          key: const Key('thread-detail-list'),
          controller: widget.scrollController,
          // 只有一楼的短帖也要能下拉刷新，见 ForumPullToRefresh.scrollPhysics。
          physics: ForumPullToRefresh.scrollPhysics,
          padding: EdgeInsets.fromLTRB(
            ForumContentSpacing.pageHorizontal,
            ForumContentSpacing.listTop,
            ForumContentSpacing.pageHorizontal,
            ForumContentSpacing.listBottom + widget.bottomInset,
          ),
          scrollCacheExtent: _imagePreloadPolicy.layoutCacheExtent,
          itemCount: entries.length,
          findChildIndexCallback: (key) => _entryIndexForKey(entries, key),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return KeyedSubtree(
              key: ValueKey(entry.key),
              child: _withListEndMarker(
                entries: entries,
                index: index,
                child: _buildEntry(context, entry, palette),
              ),
            );
          },
        ),
      ),
      present: hasRepliesHeader,
      palette: palette,
    );
  }

  int? _entryIndexForKey(List<ThreadDetailRenderEntry> entries, Key key) {
    for (var index = 0; index < entries.length; index++) {
      if (key == ValueKey(entries[index].key)) return index;
    }
    return null;
  }

  /// Marks the last rendered entry so page-end detection can require actual
  /// layout of the pagination/footer instead of a stale scroll extent.
  Widget _withListEndMarker({
    required List<ThreadDetailRenderEntry> entries,
    required int index,
    required Widget child,
  }) {
    if (index != entries.length - 1) return child;
    return KeyedSubtree(key: _listEndKey, child: child);
  }

  void _clearFooterExpansions() {
    for (final expansion in _footerExpansions.values) {
      expansion.dispose();
    }
    _footerExpansions.clear();
  }

  _ThreadPostFooterExpansion _footerExpansionFor(String pid) =>
      _footerExpansions.putIfAbsent(
        pid,
        () =>
            _ThreadPostFooterExpansion(ratings: widget.defaultRatingsExpanded),
      );

  ThreadBodyPresentation? _wholeBodyPresentationFor(String pid, String html) =>
      widget.bodyReadingCoordinator != null || _preparedBodies[pid] != null
      ? null
      : _wholeBodyPresentations.obtain(pid, html);

  void _retirePreparedBodies() {
    _bodyGeneration++;
    _bodyHandoffs.clear();
    _chunkPreparation.clear();
    _preparedBodies.clear();
    _pendingChunkAnchor = null;
    _renderLayoutIdentity = null;
  }

  bool _handoffPreparedBody(
    BuildContext bodyContext,
    ForumHtmlPreparationRequest request,
    ForumHtmlPreparedRenderDocument document,
  ) {
    if (!_canChunkBodies) {
      return false;
    }
    final pid = request.sourceId;
    final identity = request.identity;
    _bodyHandoffs.retireDeclinedInput(pid, identity);
    if (_bodyHandoffs.isDeclined(pid, identity)) return false;
    if (_bodyHandoffs.pendingFor(pid)?.identity == identity) return true;
    final candidate = ThreadDetailPreparedBody(
      request: request,
      document: document,
    );
    final previousLease = _bodyHandoffs.pendingFor(pid);
    if (previousLease != null) _bodyHandoffs.release(previousLease);
    final generation = _bodyGeneration;
    if (!_bodyHandoffs.canReserve(pid, candidate)) {
      if (_preparedBodies[pid] == null) return false;
      final rejected = _bodyHandoffs.begin(pid: pid, identity: identity);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _bodyGeneration ||
            !_bodyHandoffs.isCurrent(rejected)) {
          return;
        }
        if (!_isCurrentPreparedRequest(request)) {
          _bodyHandoffs.release(rejected);
          return;
        }
        setState(() => _bodyHandoffs.decline(rejected));
      });
      return true;
    }
    final lease = _bodyHandoffs.begin(pid: pid, identity: identity);
    final seedOrdinal = _preparationSeedOrdinal(bodyContext, pid, document);
    void publish() {
      if (!mounted ||
          !bodyContext.mounted ||
          generation != _bodyGeneration ||
          !_bodyHandoffs.isCurrent(lease) ||
          !_isCurrentPreparedRequest(request)) {
        _bodyHandoffs.release(lease);
        return;
      }
      late ThreadBodyPreparationHandoffResult result;
      setState(() {
        result = _bodyHandoffs.complete(
          lease,
          candidate,
          currentInput: true,
          seedOrdinal: seedOrdinal,
        );
        if (result == ThreadBodyPreparationHandoffResult.admitted) {
          _wholeBodyPresentations.remove(pid);
        }
      });
      if (result == ThreadBodyPreparationHandoffResult.admitted &&
          _pendingChunkAnchor?.pid == pid) {
        _projectionAnchorCoordinator.restoreAfterFrame(_pendingChunkAnchor);
        _pendingChunkAnchor = null;
      }
    }

    // Worker completion can publish between frames. A synchronous result
    // discovered while building still waits until the layout is finished.
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      publish();
    } else {
      binding.addPostFrameCallback((_) => publish());
    }
    return true;
  }

  int _preparationSeedOrdinal(
    BuildContext bodyContext,
    String pid,
    ForumHtmlPreparedRenderDocument document,
  ) {
    final plan = document.safeDisplayPlan!;
    final anchor = _pendingChunkAnchor;
    if (anchor?.pid == pid && anchor?.chunkStartUnit != null) {
      return plan.chunkForUnit(anchor!.chunkStartUnit!)?.ordinal ?? 0;
    }
    if (bodyContext.widget case _ThreadPostChunkBody(:final ordinal)) {
      return ordinal.clamp(0, plan.chunks.length - 1);
    }
    if (widget.landing == ThreadPostLanding.bodyEnd &&
            widget.targetPid == pid ||
        _endpointTarget == ThreadDetailQuickScrollTarget.bottom &&
            _postProjections.last.sourcePost.pid == pid) {
      return plan.chunks.length - 1;
    }
    return 0;
  }

  @override
  bool _isCurrentPreparedRequest(ForumHtmlPreparationRequest request) {
    final post = _postProjections
        .where((post) => post.sourcePost.pid.trim() == request.sourceId)
        .firstOrNull;
    if (post == null || request.threadId != widget.state.tid) return false;
    final preferences =
        ref.read(forumHtmlReaderPreferencesControllerProvider).value ??
        ForumHtmlReaderPreferences.defaults();
    // 异步结果校验与可见正文使用同一表面，保证准备结果能交接到分块列表。
    final palette = ThreadDetailNativePalette.resolve(
      Theme.of(context),
      continuous: true,
    );
    final theme = const ForumHtmlRenderThemeFactory().fromThreadPalette(
      palette: palette,
      brightness: Theme.of(context).brightness,
    );
    return post.displayPost.message.trim() == request.html &&
        theme.signature == request.theme.signature &&
        request.preparer.preparationPreferencesIdentity(preferences) ==
            request.preparer.preparationPreferencesIdentity(
              request.preferences,
            ) &&
        _canChunkBodies;
  }

  ThreadDetailContent? _displayProjectionOwner;
  List<ThreadDetailPostProjection>? _displayProjectionCache;

  @override
  List<ThreadDetailPostProjection> get _postProjections {
    // The display list is the single projection shared by rendering, the floor
    // navigation sequence and anchor capture; compute it once per widget build.
    // A new widget instance is the only way the tail projection can change.
    final cached = _displayProjectionCache;
    if (cached != null && identical(_displayProjectionOwner, widget)) {
      return cached;
    }
    _displayProjectionOwner = widget;
    return _displayProjectionCache = _buildDisplayProjections(widget);
  }

  List<ThreadDetailPostProjection> _buildDisplayProjections(
    ThreadDetailContent target,
  ) {
    final moved = target.movedBlacklistedPids;
    final seen = <String>{};
    final projections = <ThreadDetailPostProjection>[];
    final projected = target.projection?.posts;
    if (projected != null) {
      for (final item in projected) {
        final pid = item.sourcePost.pid;
        if (moved.contains(pid) || !seen.add(pid)) continue;
        projections.add(item);
      }
    } else {
      for (final post in target.state.posts) {
        if (moved.contains(post.pid) || !seen.add(post.pid)) continue;
        projections.add(
          ThreadDetailPostProjection(sourcePost: post, displayPost: post),
        );
      }
    }
    if (!target.showReplyTail) return List.unmodifiable(projections);
    for (final post in target.replyTailPosts) {
      if (!seen.add(post.pid)) continue;
      final converted = target.projection?.findByPid(post.pid);
      projections.add(
        converted ??
            ThreadDetailPostProjection(sourcePost: post, displayPost: post),
      );
    }
    return List.unmodifiable(projections);
  }

  List<String> _displayPidsFor(ThreadDetailContent target) {
    final moved = target.movedBlacklistedPids;
    final seen = <String>{};
    final pids = <String>[];
    final projected = target.projection?.posts;
    if (projected != null) {
      for (final item in projected) {
        final pid = item.sourcePost.pid;
        if (moved.contains(pid) || !seen.add(pid)) continue;
        pids.add(pid);
      }
    } else {
      for (final post in target.state.posts) {
        if (moved.contains(post.pid) || !seen.add(post.pid)) continue;
        pids.add(post.pid);
      }
    }
    if (!target.showReplyTail) return pids;
    for (final post in target.replyTailPosts) {
      if (seen.add(post.pid)) pids.add(post.pid);
    }
    return pids;
  }

  @override
  Iterable<String> _sourcePidsFor(ThreadDetailContent target) =>
      _displayPidsFor(target);

  Widget _buildTargetAnchoredList({
    required List<ThreadDetailRenderEntry> entries,
    int targetEntryIndex = 0,
    required ThreadDetailNativePalette palette,
    bool anchorAtRepliesHeader = false,
  }) {
    final endpoint = anchorAtRepliesHeader ? null : _endpointTarget;
    final fromBottom = endpoint == ThreadDetailQuickScrollTarget.bottom;
    final atBodyEnd =
        endpoint == null &&
        !anchorAtRepliesHeader &&
        _activeLanding == ThreadPostLanding.bodyEnd;
    if (endpoint == null && !anchorAtRepliesHeader) {
      _scheduleTargetVisibilityCheck();
    }
    final targetPid = _activeTargetPid?.trim();
    // 落点位于回复栏之下时，为吸顶栏留出与正文一致的顶部遮挡量。
    final headerOcclusion =
        endpoint == null &&
            !anchorAtRepliesHeader &&
            targetPid != null &&
            _targetBelowRepliesHeader(targetPid)
        ? _repliesHeaderHeight
        : 0.0;
    return _withStickyRepliesHeader(
      SizedBox.expand(
        key: _viewportKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final textStyle = Theme.of(context).textTheme.bodyMedium;
            final lineHeight =
                MediaQuery.textScalerOf(context)
                    .scale(textStyle?.fontSize ?? 14) *
                (textStyle?.height ?? 1.5);
            // The footer starts below a small, viewport-relative glimpse of
            // the rendered body; the center remains stable as that body grows.
            final reveal = atBodyEnd
                ? (lineHeight * 2.5).clamp(height * 0.06, height * 0.18)
                : 0.0;
            final topOffset = anchorAtRepliesHeader
                ? 0.0
                : headerOcclusion + reveal;
            return NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _scheduleTargetVisibilityCheck();
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ForumContentSpacing.pageHorizontal,
                ),
                child: KeyedSubtree(
                  key: ValueKey(_endpointViewRevision),
                  child: CustomScrollView(
                    key: const Key('thread-detail-list'),
                    controller: widget.scrollController,
                    physics: ForumPullToRefresh.scrollPhysics,
                    center: _targetCenterKey,
                    anchor: fromBottom
                        ? 1
                        : height <= 0
                        ? 0
                        : (topOffset / height).clamp(0.0, 1.0),
                    scrollCacheExtent: _imagePreloadPolicy.layoutCacheExtent,
                    semanticChildCount: entries.length,
                    slivers: [
                      if (targetEntryIndex > 0)
                        _buildTargetEntrySliver(
                          entries: entries,
                          start: 0,
                          count: targetEntryIndex,
                          reverse: true,
                          stabilizeImageLayout: false,
                          addPageTopPadding: true,
                          palette: palette,
                        ),
                      _ThreadTargetPadding(
                        key: fromBottom ? null : _targetCenterKey,
                        initialScrollOffset: endpoint == null
                            ? 0
                            : _endpointArrivalDistance,
                        padding: EdgeInsets.only(
                          top: atBodyEnd ? 0 : ForumContentSpacing.listTop,
                          bottom:
                              ForumContentSpacing.listBottom +
                              widget.bottomInset,
                        ),
                        sliver: _buildTargetEntrySliver(
                          entries: entries,
                          start: targetEntryIndex,
                          count: entries.length - targetEntryIndex,
                          reverse: fromBottom,
                          stabilizeImageLayout: !fromBottom,
                          addPageTopPadding: false,
                          palette: palette,
                        ),
                      ),
                      // Put zero at the page's trailing edge. The list then lays
                      // out backwards from the pagination row by actual height.
                      if (fromBottom) SliverToBoxAdapter(key: _targetCenterKey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      present: entries.any(
        (entry) => entry.kind == ThreadDetailRenderEntryKind.repliesHeader,
      ),
      palette: palette,
    );
  }

  void _scheduleTargetVisibilityCheck() {
    if (_floorTargetPid != null) return;
    final pid = widget.targetPid?.trim();
    if (pid == null || pid.isEmpty || widget.onTargetVisible == null) return;
    final identity = '${widget.state.tid}:$pid:${widget.landing.name}';
    if (_reportedTargetIdentity == identity) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.targetPid?.trim() != pid ||
          '${widget.state.tid}:$pid:${widget.landing.name}' != identity ||
          _reportedTargetIdentity == identity) {
        return;
      }
      final viewport = _viewportKey.currentContext?.findRenderObject();
      final marker = _targetVisibilityKey.currentContext?.findRenderObject();
      if (viewport is! RenderBox || marker is! RenderBox || !marker.attached) {
        return;
      }
      final top = marker.localToGlobal(Offset.zero, ancestor: viewport).dy;
      // A built keep-alive child can be offscreen. Highlight only after its
      // landing edge is actually visible, and report it once per destination.
      if (top >= -1 && top < viewport.size.height) {
        _reportedTargetIdentity = identity;
        widget.onTargetVisible?.call(pid);
      }
    });
  }

  SliverList _buildTargetEntrySliver({
    required List<ThreadDetailRenderEntry> entries,
    required int start,
    required int count,
    required bool reverse,
    required bool stabilizeImageLayout,
    required bool addPageTopPadding,
    required ThreadDetailNativePalette palette,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entryIndex = reverse
              ? start + count - index - 1
              : start + index;
          final entry = entries[entryIndex];
          Widget child = _buildEntry(
            context,
            entry,
            palette,
            stabilizeImageLayout: stabilizeImageLayout,
          );
          if (_endpointTarget != null &&
              entryIndex ==
                  (_endpointTarget == ThreadDetailQuickScrollTarget.top
                      ? 0
                      : entries.length - 1)) {
            child = KeyedSubtree(key: _endpointBoundaryKey, child: child);
          }
          if (_endpointTarget == null &&
              entry.sourcePost?.pid == _activeTargetPid &&
              (entry.kind == ThreadDetailRenderEntryKind.postFooter &&
                      _activeLanding == ThreadPostLanding.bodyEnd ||
                  (entry.kind == ThreadDetailRenderEntryKind.postCard ||
                          entry.kind ==
                              ThreadDetailRenderEntryKind.postHeader ||
                          entry.kind ==
                              ThreadDetailRenderEntryKind.blacklistedPost) &&
                      _activeLanding == ThreadPostLanding.top)) {
            child = KeyedSubtree(key: _targetVisibilityKey, child: child);
          }
          if (widget.bodyReadingCoordinator != null &&
              (entry.kind == ThreadDetailRenderEntryKind.postHeader ||
                  entry.kind == ThreadDetailRenderEntryKind.postBody ||
                  entry.kind == ThreadDetailRenderEntryKind.postFooter)) {
            child = _TargetPostSegmentKeepAlive(
              key: Key('keep-alive-${entry.key}'),
              child: child,
            );
          }
          if (addPageTopPadding && entryIndex == 0) {
            child = Padding(
              padding: const EdgeInsets.only(top: ForumContentSpacing.listTop),
              child: child,
            );
          }
          child = _withListEndMarker(
            entries: entries,
            index: entryIndex,
            child: child,
          );
          return KeyedSubtree(
            key: ValueKey(entry.key),
            child: IndexedSemantics(index: entryIndex, child: child),
          );
        },
        childCount: count,
        addAutomaticKeepAlives: true,
        addSemanticIndexes: false,
        findChildIndexCallback: (key) {
          final index = _entryIndexForKey(entries, key);
          if (index == null || index < start || index >= start + count) {
            return null;
          }
          return reverse ? start + count - index - 1 : index - start;
        },
      ),
    );
  }

  void _handlePostBuilt(int index) {
    widget.onPostBuilt?.call(index);
  }

  Widget _buildRepliesHeader(
    ThreadDetailNativePalette palette, {
    Key? key,
    Key? debugKey,
    bool interactionKeys = true,
  }) {
    final canSwitchViews = widget.state.supports(
      ThreadDetailCapability.alternateViews,
    );
    final header = ThreadRepliesHeader(
      key: key,
      replyCount: widget.state.replies,
      isOnlyAuthor: widget.state.isOnlyAuthorView,
      isReverseOrder: widget.state.isReverseOrderView,
      palette: palette,
      enabled: !widget.state.isLoadingInitial && !widget.state.isLoadingMore,
      onToggleAuthorFilter: canSwitchViews ? widget.onToggleAuthorFilter : null,
      onToggleOrder: canSwitchViews
          ? () => widget.onOrderChanged?.call(!widget.state.isReverseOrderView)
          : null,
      authorFilterKey: interactionKeys
          ? const Key('thread-replies-author-filter')
          : null,
      orderToggleKey: interactionKeys
          ? const Key('thread-replies-order-toggle')
          : null,
    );
    return debugKey == null
        ? header
        : KeyedSubtree(key: debugKey, child: header);
  }

  /// 目标楼在回复栏之下时才需要让出吸顶栏高度；首楼与倒序末栏不避让。
  @override
  bool _targetBelowRepliesHeader(String pid) {
    final posts = _postProjections;
    if (posts.isEmpty) return false;
    final firstIndex = posts.indexWhere((item) => item.sourcePost.isFirst);
    if (firstIndex < 0) return true;
    final index = posts.indexWhere((item) => item.sourcePost.pid == pid);
    return index > firstIndex;
  }

  Widget _withStickyRepliesHeader(
    Widget child, {
    required bool present,
    required ThreadDetailNativePalette palette,
  }) {
    if (!present) return child;
    _scheduleStickyHeaderSync();
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _scheduleStickyHeaderSync();
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _scheduleStickyHeaderSync();
              return false;
            },
            child: child,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            visible: _repliesHeaderPinned,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: ColoredBox(
              key: const Key('thread-detail-sticky-replies-header-surface'),
              color: palette.background,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ForumContentSpacing.pageHorizontal,
                ),
                child: _repliesHeaderPinned || _repliesHeaderHeight <= 0
                    ? _buildRepliesHeader(
                        palette,
                        key: _stickyRepliesHeaderKey,
                        debugKey: const Key(
                          'thread-detail-sticky-replies-header',
                        ),
                        interactionKeys: false,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _scheduleStickyHeaderSync() {
    if (_stickyHeaderSyncScheduled) return;
    _stickyHeaderSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stickyHeaderSyncScheduled = false;
      if (mounted) _syncStickyHeader();
    });
  }

  void _syncStickyHeader() {
    final headerContext = _repliesHeaderKey.currentContext;
    final viewportContext = _viewportKey.currentContext;
    final height = _stickyRepliesHeaderKey.currentContext?.size?.height;
    final controller = widget.scrollController;
    final viewportRaw = viewportContext?.findRenderObject();
    final viewportBox =
        viewportRaw is RenderBox && viewportRaw.attached && viewportRaw.hasSize
        ? viewportRaw
        : null;
    if (headerContext != null && viewportBox != null) {
      final header = headerContext.findRenderObject();
      if (header is RenderBox && header.attached && header.hasSize) {
        final top = header.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
        if (controller != null && controller.hasClients) {
          _repliesHeaderContentOffset = controller.position.pixels + top;
        }
        _updateStickyHeader(pinned: top <= 0, height: height);
        return;
      }
    }
    final pinned = _inferStickyPinnedWhenUnmounted(
      viewport: viewportBox,
      controller: controller,
    );
    _updateStickyHeader(pinned: pinned, height: height);
  }

  RenderBox? _mountedEntryBox(ThreadDetailRenderEntry entry) {
    final post = entry.sourcePost;
    final key = switch (entry.kind) {
      ThreadDetailRenderEntryKind.postCard ||
      ThreadDetailRenderEntryKind.blacklistedPost =>
        post == null ? null : _projectionAnchorCoordinator.keyForPid(post.pid),
      ThreadDetailRenderEntryKind.postHeader =>
        post == null
            ? null
            : (_preparedBodies[post.pid] != null
                  ? _projectionAnchorCoordinator.keyForPid(post.pid)
                  : _floorHeaderKeys[post.pid]),
      ThreadDetailRenderEntryKind.postBodyChunk =>
        post == null || entry.bodyManifest == null || entry.chunkOrdinal == null
            ? null
            : _projectionAnchorCoordinator.keyForChunk(
                post.pid,
                entry.bodyManifest!.chunks[entry.chunkOrdinal!].startUnit,
                endUnit:
                    entry.bodyManifest!.chunks[entry.chunkOrdinal!].endUnit,
              ),
      ThreadDetailRenderEntryKind.postFooter =>
        post != null && _preparedBodies[post.pid] == null
            ? _projectionAnchorCoordinator.keyForPid(post.pid)
            : null,
      _ => null,
    };
    final renderObject = key?.currentContext?.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      return renderObject;
    }
    return null;
  }

  /// 内联回复栏被列表回收（例如倒序切换后仍停在回复区，或墨水屏 85% 单次跳页直接越过）
  /// 时，依据前后仍在视口中的条目与滚动偏移推断是否应继续吸顶。
  bool _inferStickyPinnedWhenUnmounted({
    required RenderBox? viewport,
    required ScrollController? controller,
  }) {
    final headerIndex = _lastEntries.indexWhere(
      (entry) => entry.kind == ThreadDetailRenderEntryKind.repliesHeader,
    );
    if (headerIndex < 0) return false;
    if (headerIndex == 0) {
      if (_lastAnchoredListMode) {
        return _endpointTarget != ThreadDetailQuickScrollTarget.top;
      }
      return controller != null &&
          controller.hasClients &&
          controller.position.pixels >= ForumContentSpacing.listTop;
    }
    if (viewport != null) {
      for (var index = 0; index < headerIndex; index++) {
        final box = _mountedEntryBox(_lastEntries[index]);
        if (box == null) continue;
        final bottom = box
            .localToGlobal(Offset(0, box.size.height), ancestor: viewport)
            .dy;
        if (bottom > 0) return false;
      }
      for (var index = headerIndex + 1; index < _lastEntries.length; index++) {
        final box = _mountedEntryBox(_lastEntries[index]);
        if (box == null) continue;
        final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (top < viewport.size.height) return true;
      }
    }
    final offset = _repliesHeaderContentOffset;
    if (offset != null && controller != null && controller.hasClients) {
      return controller.position.pixels >= offset;
    }
    if (!_lastAnchoredListMode &&
        controller != null &&
        controller.hasClients &&
        controller.position.pixels > 0) {
      return true;
    }
    return false;
  }

  void _updateStickyHeader({required bool pinned, double? height}) {
    final measured = height == null || !height.isFinite || height < 0
        ? null
        : height;
    final heightChanged =
        measured != null && (measured - _repliesHeaderHeight).abs() > .5;
    if (pinned == _repliesHeaderPinned && !heightChanged) return;
    if (heightChanged) {
      _repliesHeaderHeight = measured;
      widget.onRepliesHeaderHeightChanged?.call(measured);
    }
    setState(() {
      _repliesHeaderPinned = pinned;
    });
  }

  void _syncImageViewportCoordinator() {
    if (widget.htmlImagePrecacheService == null) {
      _imageViewportCoordinator?.dispose();
      _imageViewportCoordinator = null;
      return;
    }
    _imageViewportCoordinator ??= ForumHtmlImageViewportCoordinator(
      maxVisibleFirstFrames: _imagePreloadPolicy.maxVisibleFirstFrames,
      maxConcurrentOptionalWork: _imagePreloadPolicy.maxConcurrentOptionalWork,
      predecodePolicy: _imagePreloadPolicy.predecode,
      visibilityObserver:
          widget.imageVisibilityObserver ??
          _imageVisibilityDiagnostics.observer,
    );
  }

  void _handleTickerModeChanged() {
    _imageViewportCoordinator?.setActive(
      _tickerModeNotifier?.value.enabled ?? true,
    );
    if (!(_tickerModeNotifier?.value.enabled ?? true)) {
      _imageVisibilityDiagnostics.checkpoint('inactive');
    }
  }

  Widget _buildEntry(
    BuildContext context,
    ThreadDetailRenderEntry entry,
    ThreadDetailNativePalette palette, {
    bool stabilizeImageLayout = true,
  }) {
    switch (entry.kind) {
      case ThreadDetailRenderEntryKind.repliesHeader:
        return Visibility(
          visible: !_repliesHeaderPinned,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          child: _buildRepliesHeader(
            palette,
            key: _repliesHeaderKey,
            debugKey: const Key('thread-detail-replies-header'),
          ),
        );
      case ThreadDetailRenderEntryKind.postCard:
        return KeyedSubtree(
          key: _projectionAnchorCoordinator.keyForPid(entry.sourcePost!.pid),
          child: _ThreadPostCardEntry(
            keepAlive: widget.bodyReadingCoordinator != null,
            wholeBodyPresentation: _wholeBodyPresentationFor(
              entry.sourcePost!.pid,
              entry.displayPost!.message,
            ),
            footerExpansion: _footerExpansionFor(entry.sourcePost!.pid),
            sourcePost: entry.sourcePost!,
            displayPost: entry.displayPost!,
            displaySubject:
                widget.projection?.displaySubject ?? widget.state.subject,
            displayRatingsByPostId:
                widget.projection?.displayRatingsByPostId ??
                widget.state.ratingsByPostId,
            postIndex: entry.postIndex,
            state: widget.state,
            highlighted: entry.sourcePost!.pid == widget.highlightPostPid,
            imageReferer: widget.imageReferer,
            palette: palette,
            onOpenAuthorProfile: widget.onOpenAuthorProfile,
            onOpenPostLink: widget.onOpenPostLink,
            onOpenPostImages: widget.onOpenPostImages,
            onHtmlFirstImageFallback: _copyHtmlFirstImageUrl,
            onHtmlFirstImageLayoutShift: stabilizeImageLayout
                ? _scrollStabilizer.handleLayoutShift
                : _ignoreImageLayoutShift,
            onHtmlFirstImageFallbackAspectRatio:
                _fallbackAspectRatioForBlockImage,
            onHtmlFirstBlockImageResolved: _handleBlockImageResolved,
            imageViewportCoordinator: _imageViewportCoordinator,
            imageAnchorController: widget.imageReaderReturnCoordinator
                ?.anchorsFor(entry.sourcePost!.pid),
            imagePrecacheService: widget.htmlImagePrecacheService,
            bodyReadingCoordinator: widget.bodyReadingCoordinator,
            onPreparedBody: _canChunkBodies ? _handoffPreparedBody : null,
            preparerSelector: _canChunkBodies
                ? _bodyHandoffs.selectPreparer
                : null,
            enableSafeDisplayPlanning: _canChunkBodies,
            onOpenPostActions: widget.onOpenPostActions,
            onOpenPollOptionActions: widget.onOpenPollOptionActions,
            onOpenCommentAuthorProfile: widget.onOpenCommentAuthorProfile,
            onTogglePollOption: widget.onTogglePollOption,
            onSubmitPollVote: widget.onSubmitPollVote,
            onLoadAllRatings: widget.onLoadAllRatings ?? _ignoreRatingLoad,
            onLoadMoreComments: widget.onLoadMoreComments,
            displayExtraComments:
                widget.displayExtraCommentsByPostId[entry.sourcePost!.pid],
            showEmptyInteractionHint:
                widget.landing == ThreadPostLanding.bodyEnd &&
                widget.targetPid == entry.sourcePost!.pid,
            onPostBuilt: _handlePostBuilt,
            firstPostTitleKey: widget.firstPostTitleKey,
          ),
        );
      case ThreadDetailRenderEntryKind.postHeader:
        final header = _ThreadPostCardHeaderEntry(
          key: widget.floorNavigation == null
              ? null
              : _floorHeaderKey(entry.sourcePost!.pid),
          sourcePost: entry.sourcePost!,
          displayPost: entry.displayPost!,
          displaySubject:
              widget.projection?.displaySubject ?? widget.state.subject,
          state: widget.state,
          highlighted: entry.sourcePost!.pid == widget.highlightPostPid,
          palette: palette,
          imageReferer: widget.imageReferer,
          onOpenAuthorProfile: widget.onOpenAuthorProfile,
          onOpenPostActions: widget.onOpenPostActions,
          firstPostTitleKey: widget.firstPostTitleKey,
        );
        return KeyedSubtree(
          key: _preparedBodies[entry.sourcePost!.pid] == null
              ? null
              : _projectionAnchorCoordinator.keyForPid(entry.sourcePost!.pid),
          child: _PostBuildObserver(
            index: entry.postIndex,
            onPostBuilt: _handlePostBuilt,
            child: header,
          ),
        );
      case ThreadDetailRenderEntryKind.postBody:
      case ThreadDetailRenderEntryKind.postBodyChunk:
        return KeyedSubtree(
          key: entry.bodyManifest == null
              ? null
              : _projectionAnchorCoordinator.keyForChunk(
                  entry.sourcePost!.pid,
                  entry.bodyManifest!.chunks[entry.chunkOrdinal!].startUnit,
                  endUnit:
                      entry.bodyManifest!.chunks[entry.chunkOrdinal!].endUnit,
                ),
          child: _ThreadPostCardBodyEntry(
            wholeBodyPresentation: entry.bodyManifest == null
                ? _wholeBodyPresentationFor(
                    entry.sourcePost!.pid,
                    entry.displayPost!.message,
                  )
                : null,
            sourcePost: entry.sourcePost!,
            displayPost: entry.displayPost!,
            threadId: widget.state.tid,
            highlighted: entry.sourcePost!.pid == widget.highlightPostPid,
            imageReferer: widget.imageReferer,
            palette: palette,
            onOpenPostLink: widget.onOpenPostLink,
            onOpenPostImages: widget.onOpenPostImages,
            onHtmlFirstImageFallback: _copyHtmlFirstImageUrl,
            onHtmlFirstImageLayoutShift: stabilizeImageLayout
                ? _scrollStabilizer.handleLayoutShift
                : _ignoreImageLayoutShift,
            onHtmlFirstImageFallbackAspectRatio:
                _fallbackAspectRatioForBlockImage,
            onHtmlFirstBlockImageResolved: _handleBlockImageResolved,
            imageViewportCoordinator: _imageViewportCoordinator,
            imageAnchorController: widget.imageReaderReturnCoordinator
                ?.anchorsFor(entry.sourcePost!.pid),
            imagePrecacheService: widget.htmlImagePrecacheService,
            bodyReadingCoordinator: widget.bodyReadingCoordinator,
            onPreparedBody: _canChunkBodies ? _handoffPreparedBody : null,
            preparerSelector: _canChunkBodies
                ? _bodyHandoffs.selectPreparer
                : null,
            enableSafeDisplayPlanning: _canChunkBodies,
            bodyManifest: entry.bodyManifest,
            chunkPreparation: _chunkPreparation,
            preparedBodyStore: _preparedBodies,
            layoutIdentity: _renderLayoutIdentity,
            chunkOrdinal: entry.chunkOrdinal,
            onOpenPostActions: widget.onOpenPostActions,
          ),
        );
      case ThreadDetailRenderEntryKind.postFooter:
        return KeyedSubtree(
          key: _preparedBodies[entry.sourcePost!.pid] != null
              ? null
              : _projectionAnchorCoordinator.keyForPid(entry.sourcePost!.pid),
          child: _ThreadPostCardFooterEntry(
            footerExpansion: _footerExpansionFor(entry.sourcePost!.pid),
            sourcePost: entry.sourcePost!,
            displayPost: entry.displayPost!,
            displayRatingsByPostId:
                widget.projection?.displayRatingsByPostId ??
                widget.state.ratingsByPostId,
            state: widget.state,
            highlighted: entry.sourcePost!.pid == widget.highlightPostPid,
            imageReferer: widget.imageReferer,
            onOpenPostActions: widget.onOpenPostActions,
            onOpenPollOptionActions: widget.onOpenPollOptionActions,
            onOpenPostLink: widget.onOpenPostLink,
            onOpenCommentAuthorProfile: widget.onOpenCommentAuthorProfile,
            onTogglePollOption: widget.onTogglePollOption,
            onSubmitPollVote: widget.onSubmitPollVote,
            onLoadAllRatings: widget.onLoadAllRatings ?? _ignoreRatingLoad,
            onLoadMoreComments: widget.onLoadMoreComments,
            displayExtraComments:
                widget.displayExtraCommentsByPostId[entry.sourcePost!.pid],
            showEmptyInteractionHint:
                widget.landing == ThreadPostLanding.bodyEnd &&
                widget.targetPid == entry.sourcePost!.pid,
            palette: palette,
          ),
        );
      case ThreadDetailRenderEntryKind.blacklistedPost:
        final pid = entry.sourcePost!.pid;
        return KeyedSubtree(
          key: _projectionAnchorCoordinator.keyForPid(pid),
          child: ThreadBlacklistedPostPlaceholder(
            continuous: true,
            post: entry.displayPost!,
            palette: palette,
            onExpand: () {
              setState(() => _expandedBlacklistedPids.add(pid));
            },
          ),
        );
      case ThreadDetailRenderEntryKind.pagination:
        return ThreadLoadMoreSection(
          failure: widget.state.loadFailure == null
              ? null
              : ThreadTextResolver.loadFailure(
                  AppLocalizations.of(context),
                  widget.state.loadFailure!.code,
                  widget.state.loadFailure!.detail,
                ),
          hasMore: widget.state.hasMore,
          isLoadingMore: widget.state.isLoadingMore,
          currentPage: widget.state.currentPage <= 0
              ? 1
              : widget.state.currentPage,
          lastPage: widget.state.lastPage,
          canLoadPrevious: widget.state.currentPage > 1,
          onLoadPreviousPage: widget.onLoadPreviousPage,
          onLoadNextPage: widget.onLoadNextPage,
          onLoadPageNumber: widget.onLoadPageNumber,
        );
      case ThreadDetailRenderEntryKind.targetSpacer:
        return SizedBox(height: MediaQuery.sizeOf(context).height * 0.72);
    }
  }

  void _ignoreImageLayoutShift(ForumHtmlImageLayoutShift _) {
    // Entries before CustomScrollView.center grow into negative scroll space;
    // applying the legacy positive-offset compensation would move the target.
  }

  void _ignoreRatingLoad(ThreadPost _) {}

  void _copyHtmlFirstImageUrl(ThreadPost post, ForumHtmlImageRequest request) {
    widget.onCopyActionUrl('${post.number}# 图片', request.url);
  }

  String _imageAspectRatioSignature() {
    final postIds = widget.state.posts.map((post) => post.pid).join(',');
    return '${widget.state.tid}:${widget.state.currentPage}:$postIds';
  }

  double? _fallbackAspectRatioForBlockImage(
    ThreadPost post,
    ForumImageLoadSpec spec,
    ImageCacheRequest request,
  ) {
    return _imageAspectRatioTracker.fallbackAspectRatioFor(
      post: post,
      spec: spec,
      request: request,
    );
  }

  void _handleBlockImageResolved(
    ThreadPost post,
    ForumImageLoadSpec spec,
    ImageCacheRequest request,
    Size size,
  ) {
    _imageAspectRatioTracker.record(
      post: post,
      spec: spec,
      request: request,
      size: size,
    );
  }
}

class _TargetPostSegmentKeepAlive extends StatefulWidget {
  const _TargetPostSegmentKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<_TargetPostSegmentKeepAlive> createState() =>
      _TargetPostSegmentKeepAliveState();
}

class _TargetPostSegmentKeepAliveState
    extends State<_TargetPostSegmentKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ThreadDetailImageAspectRatioTracker {
  static const double _minAspectRatio = 0.25;
  static const double _maxAspectRatio = 4.0;

  final Map<String, double> _imageAspectRatios = <String, double>{};
  final Map<String, Map<String, double>> _postImageAspectRatios =
      <String, Map<String, double>>{};
  String? _signature;

  void resetFor(String signature) {
    if (_signature == signature) {
      return;
    }
    _signature = signature;
    _imageAspectRatios.clear();
    _postImageAspectRatios.clear();
  }

  double? fallbackAspectRatioFor({
    required ThreadPost post,
    required ForumImageLoadSpec spec,
    required ImageCacheRequest request,
  }) {
    final imageKey = _imageKey(spec, request);
    final direct = _imageAspectRatios[imageKey];
    if (_isUsable(direct)) {
      return direct;
    }
    final postAverage = _average(_postImageAspectRatios[post.pid]?.values);
    if (_isUsable(postAverage)) {
      return postAverage;
    }
    return _average(_imageAspectRatios.values);
  }

  bool record({
    required ThreadPost post,
    required ForumImageLoadSpec spec,
    required ImageCacheRequest request,
    required Size size,
  }) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return false;
    }
    final imageKey = _imageKey(spec, request);
    if (imageKey.isEmpty) {
      return false;
    }
    final aspectRatio = _normalize(size.width / size.height);
    if (aspectRatio == null) {
      return false;
    }
    final previous = _imageAspectRatios[imageKey];
    if (previous == aspectRatio) {
      return false;
    }
    _imageAspectRatios[imageKey] = aspectRatio;
    (_postImageAspectRatios[post.pid] ??= <String, double>{})[imageKey] =
        aspectRatio;
    return true;
  }

  String _imageKey(ForumImageLoadSpec spec, ImageCacheRequest request) {
    final cacheKey = request.cacheKey.trim();
    if (cacheKey.isNotEmpty) {
      return cacheKey;
    }
    return spec.sourceUrl.trim();
  }

  double? _average(Iterable<double>? values) {
    if (values == null) {
      return null;
    }
    var total = 0.0;
    var count = 0;
    for (final value in values) {
      if (!_isUsable(value)) {
        continue;
      }
      total += value;
      count += 1;
    }
    if (count == 0) {
      return null;
    }
    return _normalize(total / count);
  }

  bool _isUsable(double? value) {
    return value != null && value.isFinite && value > 0;
  }

  double? _normalize(double value) {
    if (!_isUsable(value)) {
      return null;
    }
    return value.clamp(_minAspectRatio, _maxAspectRatio).toDouble();
  }
}

enum ThreadDetailScrollStabilizerEventType {
  ignored,
  queued,
  merged,
  skipped,
  applied,
}

@immutable
class ThreadDetailScrollStabilizerEvent {
  const ThreadDetailScrollStabilizerEvent({
    required this.type,
    required this.reason,
    required this.sourceUrl,
    required this.cacheKey,
    required this.deltaHeight,
    required this.oldAspectRatio,
    required this.newAspectRatio,
    this.scrollPixels,
    this.minScrollExtent,
    this.maxScrollExtent,
    this.viewportDimension,
    this.viewportTop,
    this.imageBottom,
    this.pendingDelta,
    this.targetPixels,
    this.userScrollDirection,
    this.isScrolling,
  });

  final ThreadDetailScrollStabilizerEventType type;
  final String reason;
  final String sourceUrl;
  final String cacheKey;
  final double deltaHeight;
  final double oldAspectRatio;
  final double newAspectRatio;
  final double? scrollPixels;
  final double? minScrollExtent;
  final double? maxScrollExtent;
  final double? viewportDimension;
  final double? viewportTop;
  final double? imageBottom;
  final double? pendingDelta;
  final double? targetPixels;
  final String? userScrollDirection;
  final bool? isScrolling;
}

class ThreadDetailScrollStabilizer {
  ThreadDetailScrollStabilizer({
    required this.scrollController,
    required this.viewportKey,
    this.onEvent,
  });

  final ScrollController? scrollController;
  final GlobalKey viewportKey;
  final ValueChanged<ThreadDetailScrollStabilizerEvent>? onEvent;
  double _pendingDelta = 0;
  bool _scheduled = false;
  bool _disposed = false;

  @visibleForTesting
  double get debugPendingDelta => _pendingDelta;

  void handleLayoutShift(ForumHtmlImageLayoutShift shift) {
    if (_disposed || shift.deltaHeight.abs() < 0.5) {
      _emit(
        shift,
        type: ThreadDetailScrollStabilizerEventType.ignored,
        reason: _disposed ? 'disposed' : 'delta-too-small',
      );
      return;
    }
    final controller = scrollController;
    if (controller == null || !controller.hasClients) {
      _emit(
        shift,
        type: ThreadDetailScrollStabilizerEventType.ignored,
        reason: controller == null ? 'no-controller' : 'no-scroll-clients',
      );
      return;
    }
    final viewportContext = viewportKey.currentContext;
    final viewportRenderObject = viewportContext?.findRenderObject();
    if (viewportRenderObject is! RenderBox || !viewportRenderObject.hasSize) {
      _emit(
        shift,
        type: ThreadDetailScrollStabilizerEventType.ignored,
        reason: 'viewport-unavailable',
      );
      return;
    }
    final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
    if (shift.oldGlobalRect.bottom > viewportTop + 0.5) {
      _emit(
        shift,
        type: ThreadDetailScrollStabilizerEventType.ignored,
        reason: 'image-intersects-or-below-viewport',
        viewportTop: viewportTop,
        imageBottom: shift.oldGlobalRect.bottom,
      );
      return;
    }
    _pendingDelta += shift.deltaHeight;
    _emit(
      shift,
      type: _scheduled
          ? ThreadDetailScrollStabilizerEventType.merged
          : ThreadDetailScrollStabilizerEventType.queued,
      reason: _scheduled ? 'merged-with-pending-frame' : 'above-viewport',
      viewportTop: viewportTop,
      imageBottom: shift.oldGlobalRect.bottom,
      pendingDelta: _pendingDelta,
    );
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final delta = _pendingDelta;
      _pendingDelta = 0;
      if (_disposed || delta.abs() < 0.5) {
        _emit(
          shift,
          type: ThreadDetailScrollStabilizerEventType.skipped,
          reason: _disposed
              ? 'disposed-before-apply'
              : 'pending-delta-too-small',
          pendingDelta: delta,
        );
        return;
      }
      final controller = scrollController;
      if (controller == null || !controller.hasClients) {
        _emit(
          shift,
          type: ThreadDetailScrollStabilizerEventType.skipped,
          reason: controller == null
              ? 'no-controller-before-apply'
              : 'no-clients-before-apply',
          pendingDelta: delta,
        );
        return;
      }
      final position = controller.position;
      final target = (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((target - position.pixels).abs() < 0.5) {
        _emit(
          shift,
          type: ThreadDetailScrollStabilizerEventType.skipped,
          reason: 'target-unchanged-after-clamp',
          pendingDelta: delta,
          targetPixels: target,
        );
        return;
      }
      _emit(
        shift,
        type: ThreadDetailScrollStabilizerEventType.applied,
        reason: 'jump-to-compensate-above-viewport',
        pendingDelta: delta,
        targetPixels: target,
      );
      controller.jumpTo(target);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _emit(
    ForumHtmlImageLayoutShift shift, {
    required ThreadDetailScrollStabilizerEventType type,
    required String reason,
    double? viewportTop,
    double? imageBottom,
    double? pendingDelta,
    double? targetPixels,
  }) {
    final callback = onEvent;
    if (callback == null) {
      return;
    }
    final position = scrollController?.hasClients == true
        ? scrollController!.position
        : null;
    callback(
      ThreadDetailScrollStabilizerEvent(
        type: type,
        reason: reason,
        sourceUrl: shift.sourceUrl,
        cacheKey: shift.cacheKey,
        deltaHeight: shift.deltaHeight,
        oldAspectRatio: shift.oldAspectRatio,
        newAspectRatio: shift.newAspectRatio,
        scrollPixels: position?.pixels,
        minScrollExtent: position?.minScrollExtent,
        maxScrollExtent: position?.maxScrollExtent,
        viewportDimension: position?.viewportDimension,
        viewportTop: viewportTop,
        imageBottom: imageBottom,
        pendingDelta: pendingDelta,
        targetPixels: targetPixels,
        userScrollDirection: position?.userScrollDirection.name,
        isScrolling: position?.isScrollingNotifier.value,
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _pendingDelta = 0;
  }
}
