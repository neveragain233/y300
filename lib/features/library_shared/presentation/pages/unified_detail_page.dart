import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_system_ui.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_chapter_browser.dart';

import 'package:y300/core/config/app_config.dart';
import 'package:y300/features/library_shared/domain/contracts/detail_module_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_category_targets.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_system_categories.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/library_shared/presentation/controllers/unified_detail_controller.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_catalog_sheet.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_chapter_management_sheet.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_cover_candidates_sheet.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_chapter_tile.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_filter_sheet.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_header.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_metadata_sheet.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_misc_sections.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_palette.dart';
import 'package:y300/features/library_shared/presentation/services/route_content_presentation_guard.dart';
import 'package:y300/features/library_shared/presentation/services/library_detail_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/services/library_shelf_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/widgets/cover_focal_point_picker.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_sort_option_tile.dart';
import 'package:y300/features/tags/presentation/yamibo_tag_thread_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/eink_scroll_pager.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 统一详情页骨架（Phase 4）
///
/// 设计要点：
/// 1. 顶部视觉区是一个整体：背景模糊图 + 封面 + 元信息。
/// 2. AppBar 标题在顶部展开态隐藏，滚动折叠到阈值后再显示。
/// 3. 详情逻辑仅依赖 DetailModuleAdapter，避免与具体模块耦合。
class UnifiedDetailPage extends StatefulWidget {
  const UnifiedDetailPage({
    super.key,
    required this.adapter,
    required this.workId,
    required this.onOpenReader,
    required this.onOpenThread,
    this.imageReferer,
    this.pickCoverImage,
    this.importCoverImage,
    this.shelfRefreshBus,
    this.chapterStatus,
    this.chapterModeControl,
    this.onOpenChapter,
    this.onOpenChapterFromBeginning,
    this.onContinue,
    this.onRefreshCompleted,
    this.onFirstContentPresented,
  });

  final DetailModuleAdapter adapter;
  final String workId;
  final Future<void> Function(BuildContext context, ReaderRouteTarget target)
  onOpenReader;
  final Future<void> Function(BuildContext context, ThreadRouteTarget target)
  onOpenThread;
  final String? imageReferer;

  /// 选择本地封面图片的回调，返回所选图片的本地路径（取消返回 null）。
  ///
  /// 由具体模块外壳（如漫画详情页）用各自的图片选择器注入，使本共享页不直接
  /// 依赖 image_picker。仅当 adapter 实现 [DetailCoverEditor] 时才会被调用。
  final Future<String?> Function()? pickCoverImage;

  /// 把帖子候选图片取到本地临时文件，返回路径；失败时抛出异常。
  ///
  /// 与 [pickCoverImage] 一样由模块外壳注入，共享页不直接持有图片传输。
  final Future<String> Function(String imageUrl)? importCoverImage;
  final LibraryShelfRefreshBus? shelfRefreshBus;
  final Widget? chapterStatus;
  final Widget? chapterModeControl;
  final Future<void> Function(BuildContext context, LibraryChapterItem chapter)?
  onOpenChapter;
  final Future<void> Function(BuildContext context, LibraryChapterItem chapter)?
  onOpenChapterFromBeginning;
  final Future<void> Function(BuildContext context, ReaderRouteTarget target)?
  onContinue;
  final Future<void> Function(DetailRefreshResult result)? onRefreshCompleted;
  final FutureOr<void> Function(
    LibraryDetailHeader header,
    List<LibraryChapterItem> chapters,
  )?
  onFirstContentPresented;

  @override
  State<UnifiedDetailPage> createState() => _UnifiedDetailPageHostState();
}

class _UnifiedDetailPageHostState extends State<UnifiedDetailPage> {
  final _presentationGuard = RouteContentPresentationGuard();

  @override
  Widget build(BuildContext context) => _UnifiedDetailPageContent(
    // Retire every callback together when the work or adapter owner changes.
    key: ValueKey((ObjectKey(widget.adapter), widget.workId)),
    configuration: widget,
    presentationGuard: _presentationGuard,
  );
}

class _UnifiedDetailPageContent extends StatefulWidget {
  const _UnifiedDetailPageContent({
    super.key,
    required this.configuration,
    required this.presentationGuard,
  });

  final UnifiedDetailPage configuration;
  final RouteContentPresentationGuard presentationGuard;

  @override
  State<_UnifiedDetailPageContent> createState() => _UnifiedDetailPageState();
}

class _UnifiedDetailPageState extends State<_UnifiedDetailPageContent> {
  UnifiedDetailPage get _page => widget.configuration;
  // 阈值适当降低，确保常见拖动距离能稳定触发折叠标题显示。
  static const double _collapsedTitleRevealOffset = 120;
  static const double _chapterDownloadIconSize = 28;

  late final UnifiedDetailController _controller;
  late final ScrollController _scrollController;

  bool _introExpanded = false;
  bool _showCollapsedTitle = false;
  int _lastHandledRefreshSignalSequence = 0;
  bool get _isResettingWorkReading => _controller.isResettingWorkReading;
  // The controller coalesces work; this slot coalesces route callbacks/toasts.
  Future<void>? _refreshFeedbackInFlight;
  // 批量“已读至此”与封面写入仍由本页持有交互准入。
  bool _isMarkingReadThrough = false;
  bool _coverMutationInFlight = false;
  Listenable? _chapterDownloadActivityListenable;
  RouteContentPresentationGuard get _contentPresentationGuard =>
      widget.presentationGuard;

  DetailChapterDownloadAdapter? get _downloadAdapter {
    final adapter = _page.adapter;
    return adapter is DetailChapterDownloadAdapter
        ? adapter as DetailChapterDownloadAdapter
        : null;
  }

  bool get _supportsChapterDownloads => _downloadAdapter != null;

  // The bulk implementation stays available for persisted tasks and a
  // reversible product-policy change, but the current UI only exposes
  // chapter-level offline caching.
  bool get _showsBulkDownloadActions => false;

  DetailChapterDownloadActivityAdapter? get _downloadActivityAdapter {
    final adapter = _page.adapter;
    return adapter is DetailChapterDownloadActivityAdapter
        ? adapter as DetailChapterDownloadActivityAdapter
        : null;
  }

  DetailChapterReadStateAdapter? get _readStateAdapter {
    final adapter = _page.adapter;
    return adapter is DetailChapterReadStateAdapter
        ? adapter as DetailChapterReadStateAdapter
        : null;
  }

  bool get _supportsChapterReadState => _readStateAdapter != null;

  bool get _supportsChapterReadThrough =>
      _page.adapter is DetailChapterReadThroughAdapter;

  bool get _supportsFullRefresh => _page.adapter is DetailFullRefreshAdapter;

  DetailWorkReadingResetAdapter? get _workReadingResetAdapter {
    final adapter = _page.adapter;
    return adapter is DetailWorkReadingResetAdapter
        ? adapter as DetailWorkReadingResetAdapter
        : null;
  }

  DetailChapterManagementAdapter? get _chapterManagementAdapter {
    final adapter = _page.adapter;
    return adapter is DetailChapterManagementAdapter
        ? adapter as DetailChapterManagementAdapter
        : null;
  }

  DetailSourceTagsAdapter? get _sourceTagsAdapter {
    final adapter = _page.adapter;
    return adapter is DetailSourceTagsAdapter
        ? adapter as DetailSourceTagsAdapter
        : null;
  }

  @override
  void initState() {
    super.initState();
    _controller = UnifiedDetailController(
      adapter: _page.adapter,
      workId: _page.workId,
    );
    _scrollController = ScrollController()..addListener(_handleScroll);
    _page.shelfRefreshBus?.signal.addListener(_handleShelfRefreshSignal);
    _bindChapterDownloadActivity();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
      _scheduleFirstContentPresented();
    });
  }

  @override
  void dispose() {
    _controller.close();
    _page.shelfRefreshBus?.signal.removeListener(_handleShelfRefreshSignal);
    _chapterDownloadActivityListenable?.removeListener(
      _handleChapterDownloadActivityChanged,
    );
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _UnifiedDetailPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.configuration.shelfRefreshBus,
      _page.shelfRefreshBus,
    )) {
      oldWidget.configuration.shelfRefreshBus?.signal.removeListener(
        _handleShelfRefreshSignal,
      );
      _page.shelfRefreshBus?.signal.addListener(_handleShelfRefreshSignal);
    }
  }

  void _bindChapterDownloadActivity() {
    final next = _downloadActivityAdapter?.chapterDownloadActivityListenable;
    if (identical(next, _chapterDownloadActivityListenable)) {
      return;
    }
    _chapterDownloadActivityListenable?.removeListener(
      _handleChapterDownloadActivityChanged,
    );
    _chapterDownloadActivityListenable = next;
    next?.addListener(_handleChapterDownloadActivityChanged);
  }

  void _handleChapterDownloadActivityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isChapterDownloading(String episodeId) {
    if (_controller.isChapterDownloadPending(episodeId)) {
      return true;
    }
    return _downloadActivityAdapter?.isChapterDownloadActive(
          workId: _page.workId,
          episodeId: episodeId,
        ) ??
        false;
  }

  void _handleScroll() {
    final shouldShow =
        _scrollController.hasClients &&
        _scrollController.offset >= _collapsedTitleRevealOffset;
    if (shouldShow != _showCollapsedTitle && mounted) {
      setState(() => _showCollapsedTitle = shouldShow);
    }
  }

  void _handleShelfRefreshSignal() {
    final signal = _page.shelfRefreshBus?.signal.value;
    if (signal == null ||
        signal.sequence <= _lastHandledRefreshSignalSequence ||
        !signal.modules.contains(_page.adapter.moduleKey)) {
      return;
    }
    final workId = signal.workId?.trim();
    if (workId == null || workId.isEmpty || workId != _page.workId) {
      return;
    }
    _lastHandledRefreshSignalSequence = signal.sequence;
    _reloadAfterExternalMutation();
  }

  Future<void> _reloadAfterExternalMutation() async {
    await _controller.reload();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _scheduleFirstContentPresented() {
    if (_page.onFirstContentPresented == null) {
      return;
    }
    final routeWorkId = _page.workId;
    final state = _controller.state;
    final header = state.header;
    if (header == null || state.isLoading || state.errorMessage != null) {
      return;
    }
    final chapters = List<LibraryChapterItem>.unmodifiable(state.chapters);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _page.workId != routeWorkId) {
        return;
      }
      if (!_contentPresentationGuard.tryCommit(routeWorkId)) {
        return;
      }
      try {
        await _page.onFirstContentPresented?.call(header, chapters);
      } catch (error, stackTrace) {
        debugPrint(
          '[UnifiedDetailPage][first_content_callback_failure] '
          'workId=$routeWorkId error=${error.runtimeType}\n$stackTrace',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _controller.state;
    final header = state.header;
    final topInset = MediaQuery.paddingOf(context).top;
    final detailPalette = const UnifiedDetailPaletteResolver().resolve(
      Theme.of(context),
    );
    final headerHasCover = header != null && hasUnifiedDetailCover(header);
    final expandedAppBarForeground = headerHasCover
        ? detailPalette.onHeader
        : detailPalette.collapsedAppBarForeground;

    return LibraryChapterBrowser<LibraryChapterItem>(
      key: ValueKey('detail-chapters-${_page.workId}'),
      workId: _page.workId,
      keyPrefix: 'unified-detail-chapter',
      controlsInList: true,
      currentId: state.chapters
          .where((chapter) => chapter.progressInfo?.isCurrent == true)
          .firstOrNull
          ?.episodeId,
      locateCurrentOnOpen: false,
      scrollController: _scrollController,
      topObstruction:
          topInset +
          kToolbarHeight +
          LibraryChapterBrowser.controlsHeight(context),
      itemExtent: math.max(
        80,
        24 +
            2 *
                MediaQuery.textScalerOf(context).scale(
                  Theme.of(context).textTheme.titleSmall?.fontSize ?? 14,
                ) *
                1.5 +
            MediaQuery.textScalerOf(
                  context,
                ).scale(Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                1.5,
      ),
      entries: [
        for (final chapter in state.chapters)
          ChapterSearchEntry(
            id: chapter.episodeId,
            title: chapter.title,
            aliases: [if (chapter.sourceTitle != null) chapter.sourceTitle!],
            metadata: [chapter.sourceTid ?? '', chapter.sourcePid ?? ''],
            value: chapter,
          ),
      ],
      leadingSlivers: [
        if (header != null)
          SliverToBoxAdapter(
            child: UnifiedDetailHeaderSection(
              header: header,
              moduleKey: _page.adapter.moduleKey,
              topInset: topInset,
              palette: detailPalette,
              imageReferer: _page.imageReferer,
              onToggleShelf: () => _showMoveCategorySheet(),
              onRefresh: _refreshAndShowFeedback,
              onRefreshLongPress: _supportsFullRefresh
                  ? () => _refreshAndShowFeedback(full: true)
                  : null,
              onOpenThread: () async {
                final target = await _page.adapter.getThreadRouteTarget(
                  workId: _page.workId,
                );
                if (!context.mounted || target == null) {
                  return;
                }
                await _page.onOpenThread(context, target);
              },
            ),
          ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          SliverToBoxAdapter(
            child: UnifiedDetailErrorPanel(
              message: state.errorMessage!,
              topPadding: header == null ? topInset + kToolbarHeight : 10,
              onRetry: _retryLoad,
            ),
          ),
        if (header != null)
          SliverToBoxAdapter(
            child: UnifiedDetailIntroSection(
              intro: header.intro?.trim().isNotEmpty == true
                  ? header.intro!
                  : l10n.libraryDetailNoIntro,
              expanded: _introExpanded,
              onToggle: () => setState(() => _introExpanded = !_introExpanded),
            ),
          ),
        if (header != null)
          SliverToBoxAdapter(
            child: UnifiedDetailTagStrip(
              sourceTagName: header.sourceTagName,
              sourceTypeId: header.sourceTypeId,
            ),
          ),
        if (_page.chapterStatus != null)
          SliverToBoxAdapter(child: _page.chapterStatus),
        SliverToBoxAdapter(
          child: UnifiedDetailChapterToolbar(
            chapterCount: state.chapters.length,
            filterSummary: _chapterFilterSummary(state.filters),
            hasActiveFilter: _hasActiveChapterFilter(state.filters),
            modeControl: _page.chapterModeControl,
          ),
        ),
      ],
      trailingSlivers: const [SliverToBoxAdapter(child: SizedBox(height: 320))],
      rowBuilder: (context, chapter, confirmSearch) => UnifiedDetailChapterTile(
        tileKey: ValueKey<String>(
          'unified-detail-chapter-${chapter.episodeId}',
        ),
        chapter: chapter,
        subtitle: _chapterSubtitle(chapter),
        isDownloading: _isChapterDownloading(chapter.episodeId),
        downloadIconSize: _chapterDownloadIconSize,
        onTap: () {
          confirmSearch();
          _openChapter(chapter);
        },
        onLongPress: () => _showChapterActions(chapter),
        onToggleReadState: _supportsChapterReadState
            ? () => _toggleChapterReadingState(chapter)
            : null,
        onMarkReadThrough: _supportsChapterReadThrough
            ? () => _markReadThroughChapter(chapter)
            : null,
        readStateMutationLocked:
            _isMarkingReadThrough ||
            _controller.isChapterReadingStateLocked(chapter.episodeId),
        onToggleDownload: _supportsChapterDownloads
            ? () => _toggleChapterDownload(chapter)
            : null,
      ),
      layoutBuilder: (context, searchControls, chapterList) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: detailPalette.pageBackground,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _showCollapsedTitle ? 1 : 0),
            duration: AppLayoutTokens.motionDuration(context),
            curve: Curves.easeInOutCubic,
            builder: (context, progress, _) {
              final appBarForeground = Color.lerp(
                expandedAppBarForeground,
                detailPalette.collapsedAppBarForeground,
                progress,
              )!;
              return AppBar(
                leading: adaptiveDetailBackButton(context),
                systemOverlayStyle: AppSystemUi.onSurfaces(
                  top: headerHasCover && progress < 0.5
                      ? Colors.black
                      : detailPalette.pageBackground,
                  bottom: detailPalette.pageBackground,
                ),
                backgroundColor: detailPalette.collapsedAppBarBackground
                    .withValues(alpha: progress),
                forceMaterialTransparency: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: appBarForeground,
                iconTheme: IconThemeData(color: appBarForeground),
                titleTextStyle: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(
                      color: appBarForeground,
                      fontWeight: FontWeight.normal,
                    ),
                // Fade this single text directly, without an opacity layer.
                title: ExcludeSemantics(
                  excluding: progress == 0,
                  child: Text(
                    header == null
                        ? ''
                        : LibraryShelfTextResolver.workTitle(
                            l10n,
                            _page.adapter.moduleKey,
                            header.title,
                            header.workId,
                          ),
                    key: const Key('unified-detail-collapsed-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appBarForeground.withValues(
                        alpha: appBarForeground.a * progress,
                      ),
                    ),
                  ),
                ),
                actions: [
                  AppToolbarActions(
                    children: [
                      const AdaptiveDetailExpandAction(),
                      if (_supportsChapterDownloads &&
                          _showsBulkDownloadActions)
                        AppPopupMenuButton<String>(
                          key: const Key('unified-detail-appbar-download'),
                          tooltip: l10n.libraryDetailDownload,
                          icon: const Icon(Icons.file_download),
                          onSelected: _handleDownloadMenuAction,
                          itemBuilder: _downloadMenuItems,
                        ),
                      IconButton(
                        key: const Key('unified-detail-appbar-filter'),
                        tooltip: l10n.libraryDetailFilterAndSort,
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showChapterFilterSheet,
                      ),
                      AppPopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          AppPopupMenuItem<String>(
                            value: 'refresh',
                            label: l10n.libraryDetailRefresh,
                            icon: const Icon(Icons.refresh),
                          ),
                          AppPopupMenuItem<String>(
                            value: 'change-category',
                            label: l10n.libraryDetailChangeCategory,
                            icon: const Icon(Icons.category_outlined),
                          ),
                          if (_page.adapter is DetailMetadataEditor)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-edit-metadata'),
                              value: 'edit-metadata',
                              label: l10n.libraryDetailEditMetadata,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          if (_page.adapter is DetailCatalogEditor)
                            AppPopupMenuItem<String>(
                              key: const Key(
                                'unified-detail-configure-catalog',
                              ),
                              value: 'configure-catalog',
                              label: l10n.libraryDetailConfigureCatalog,
                              icon: const Icon(Icons.list_alt),
                            ),
                          if (_sourceTagsAdapter != null)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-source-tags'),
                              value: 'source-tags',
                              label: l10n.libraryDetailSourceTags,
                              icon: const Icon(Icons.local_offer_outlined),
                            ),
                          // 章节长按之外的第二个入口：隐藏全部章节后列表为空，
                          // 长按目标随之消失，只靠长按会把“全部显示”永久锁死。
                          if (_chapterManagementAdapter != null)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-manage-chapters'),
                              value: 'manage-chapters',
                              label: l10n.libraryDetailManageChapters,
                              icon: const Icon(Icons.checklist),
                            ),
                          if (_supportsCoverEditing)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-set-cover'),
                              value: 'set-custom-cover',
                              label: l10n.libraryDetailSetCustomCover,
                              icon: const Icon(Icons.image_outlined),
                            ),
                          if (_supportsCoverCandidates)
                            AppPopupMenuItem<String>(
                              key: const Key(
                                'unified-detail-set-cover-from-post',
                              ),
                              value: 'set-cover-from-post',
                              label: l10n.libraryDetailSetCoverFromPost,
                              icon: const Icon(Icons.photo_library_outlined),
                            ),
                          if (_supportsCoverEditing && _canRemoveCover)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-remove-cover'),
                              value: 'remove-custom-cover',
                              label: l10n.libraryDetailRemoveCustomCover,
                              icon: const Icon(Icons.hide_image_outlined),
                              danger: true,
                            ),
                          AppPopupMenuItem<String>(
                            value: 'edit-intro',
                            label: l10n.libraryDetailEditIntro,
                            icon: const Icon(Icons.notes_outlined),
                          ),
                        ],
                        onSelected: (value) async {
                          await _handleMoreAction(value);
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        body: state.isLoading && header == null
            ? AppLoadingState(label: AppLocalizations.of(context).commonLoading)
            : RefreshIndicator(
                // 从屏幕顶部出现刷新指示器。
                edgeOffset: 0,
                displacement: 28,
                elevation: 0,
                onRefresh: _refreshAndShowFeedback,
                // 角标避让底部“继续阅读”按钮。
                child: EInkScrollPager(
                  controller: _scrollController,
                  edgeTapAllowed: true,
                  cornerPadding: const EdgeInsets.only(right: 12, bottom: 88),
                  child: chapterList,
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final target = await _page.adapter.getReaderRouteTarget(
              workId: _page.workId,
              preferContinue: true,
            );
            if (!context.mounted || target == null) {
              return;
            }
            final handler = _page.onContinue ?? _page.onOpenReader;
            await handler(context, target);
            if (!context.mounted) {
              return;
            }
            await _controller.reload();
            if (mounted) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.libraryDetailContinue),
        ),
      ),
    );
  }

  Future<void> _openChapter(LibraryChapterItem chapter) async {
    final customHandler = _page.onOpenChapter;
    if (customHandler != null) {
      await customHandler(context, chapter);
    } else {
      final target = ReaderRouteTarget(
        workId: _page.workId,
        episodeId: chapter.episodeId,
      );
      await _page.onOpenReader(context, target);
    }
    if (!mounted) {
      return;
    }
    await _controller.reload();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleChapterDownload(LibraryChapterItem chapter) async {
    if (_isChapterDownloading(chapter.episodeId)) {
      return;
    }

    if (chapter.isDownloaded) {
      try {
        final operation = _controller.deleteChapterDownload(
          episodeId: chapter.episodeId,
        );
        setState(() {});
        await operation;
      } catch (error) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showDetailSnackBar(
            l10n.libraryDetailDeleteDownloadFailed(
              LibraryDetailTextResolver.safeError(l10n, error),
            ),
          );
        }
      } finally {
        if (mounted) setState(() {});
      }
      return;
    }

    try {
      final operation = _controller.markChapterDownloaded(
        episodeId: chapter.episodeId,
        isDownloaded: true,
      );
      setState(() {});
      await operation;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showDetailSnackBar(
          l10n.libraryDetailDownloadFailed(
            LibraryDetailTextResolver.safeError(l10n, error),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _toggleChapterReadingState(LibraryChapterItem chapter) async {
    if (_isMarkingReadThrough ||
        _controller.isChapterReadingStateLocked(chapter.episodeId)) {
      return;
    }
    try {
      final operation = _controller.toggleChapterReadingState(
        episodeId: chapter.episodeId,
        isCurrentlyRead: chapter.isRead,
      );
      setState(() {});
      await operation;
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailReadStateUpdateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// 控制器只公开单章读状态准入；批量“已读至此”开始前按当前章节集合确认
  /// 没有未结算的单章写入，避免批量结果与单章结果互相覆盖。
  bool get _hasPendingChapterReadingStateMutation =>
      _controller.state.chapters.any(
        (chapter) => _controller.isChapterReadingStateLocked(chapter.episodeId),
      );

  Future<void> _markReadThroughChapter(LibraryChapterItem chapter) async {
    if (!_supportsChapterReadThrough ||
        _isMarkingReadThrough ||
        _isResettingWorkReading ||
        _hasPendingChapterReadingStateMutation) {
      return;
    }
    setState(() {
      _isMarkingReadThrough = true;
    });
    try {
      final outcome = await _controller.markReadThroughChapter(
        targetEpisodeId: chapter.episodeId,
      );
      if (!mounted) {
        return;
      }
      setState(() {});
      if (outcome == null) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailReadStateUpdateFailed,
        );
        return;
      }
      _notifyReadingStateChanged('chapter_read_through_completed');
      if (outcome.hasChanges) {
        _showReadThroughFeedback(outcome);
      }
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailReadStateUpdateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingReadThrough = false;
        });
      }
    }
  }

  void _showReadThroughFeedback(ChapterReadThroughOutcome outcome) {
    final l10n = AppLocalizations.of(context);
    showTransientSnackBar(
      context,
      l10n.libraryChapterMarkReadThroughDone,
      action: SnackBarAction(
        label: l10n.libraryChapterMarkReadThroughUndo,
        onPressed: () => _undoMarkReadThrough(outcome),
      ),
    );
  }

  Future<void> _undoMarkReadThrough(ChapterReadThroughOutcome outcome) async {
    if (_isMarkingReadThrough ||
        _isResettingWorkReading ||
        _hasPendingChapterReadingStateMutation) {
      return;
    }
    setState(() {
      _isMarkingReadThrough = true;
    });
    try {
      await _controller.restoreChaptersRead(
        episodeIds: outcome.changedEpisodeIds,
        readAt: outcome.readAt,
      );
      if (!mounted) {
        return;
      }
      _notifyReadingStateChanged('chapter_read_through_undone');
      setState(() {});
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailReadStateUpdateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingReadThrough = false;
        });
      }
    }
  }

  void _notifyReadingStateChanged(String reason) {
    _page.shelfRefreshBus?.notify(
      modules: <LibraryModuleKey>{_page.adapter.moduleKey},
      reason: reason,
      source: LibraryMutationSource.readingStateBatch,
      workId: _page.workId,
    );
  }

  String _chapterSubtitle(LibraryChapterItem chapter) {
    if (!chapter.showSourceIdentifier) {
      return chapter.publishTimeText?.trim() ?? '';
    }
    final date = chapter.publishTimeText ?? '-';
    final sourcePid = chapter.sourcePid?.trim();
    if (sourcePid != null && sourcePid.isNotEmpty) {
      return '$date  Pid:$sourcePid';
    }
    return '$date  Tid:${chapter.sourceTid ?? '-'}';
  }

  List<PopupMenuEntry<String>> _downloadMenuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      AppPopupMenuItem<String>(
        value: 'download-unread',
        label: l10n.libraryDetailDownloadUnread,
        icon: const Icon(Icons.download_for_offline_outlined),
      ),
      AppPopupMenuItem<String>(
        value: 'download-all',
        label: l10n.libraryDetailDownloadAll,
        icon: const Icon(Icons.download_outlined),
      ),
    ];
  }

  Future<void> _handleDownloadMenuAction(String value) async {
    final downloadAdapter = _downloadAdapter;
    if (downloadAdapter == null) {
      return;
    }
    try {
      if (value == 'download-unread') {
        await downloadAdapter.downloadUnread(workId: _page.workId);
        return;
      }
      if (value == 'download-all') {
        await downloadAdapter.downloadAll(workId: _page.workId);
      }
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showDetailSnackBar(
          l10n.libraryDetailDownloadFailed(
            LibraryDetailTextResolver.safeError(l10n, error),
          ),
        );
      }
    }
  }

  String _chapterFilterSummary(LibraryFilterSet filters) {
    final l10n = AppLocalizations.of(context);
    if (!_hasActiveChapterFilter(filters)) {
      return l10n.libraryDetailAllChapters;
    }
    final labels = <String>[
      if (_supportsChapterDownloads)
        ?_filterSummaryPart(l10n.libraryDetailDownloaded, filters.downloaded),
      if (_supportsChapterReadState)
        ?_filterSummaryPart(l10n.libraryDetailUnread, filters.unread),
      ?_filterSummaryPart(l10n.libraryDetailBookmarked, filters.bookmarked),
    ];
    return labels.isEmpty ? l10n.libraryDetailAllChapters : labels.join(' / ');
  }

  bool _hasActiveChapterFilter(LibraryFilterSet filters) {
    return (_supportsChapterDownloads &&
            filters.downloaded != TriStateFilterValue.ignore) ||
        (_supportsChapterReadState &&
            filters.unread != TriStateFilterValue.ignore) ||
        filters.bookmarked != TriStateFilterValue.ignore;
  }

  String? _filterSummaryPart(String label, TriStateFilterValue value) {
    return switch (value) {
      TriStateFilterValue.ignore => null,
      TriStateFilterValue.include => label,
      TriStateFilterValue.exclude => AppLocalizations.of(
        context,
      ).libraryDetailExcludeFilter(label),
    };
  }

  Future<void> _showChapterFilterSheet() async {
    var selectedFilters = _controller.state.filters;
    if (!_supportsChapterDownloads &&
        selectedFilters.downloaded != TriStateFilterValue.ignore) {
      selectedFilters = selectedFilters.copyWith(
        downloaded: TriStateFilterValue.ignore,
      );
    }
    if (!_supportsChapterReadState &&
        selectedFilters.unread != TriStateFilterValue.ignore) {
      selectedFilters = selectedFilters.copyWith(
        unread: TriStateFilterValue.ignore,
      );
    }
    var selectedDirection = _controller.state.chapterSortOption.direction;

    await showAdaptivePanel<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final l10n = AppLocalizations.of(context);
            final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.86;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: SingleChildScrollView(
                  child: Padding(
                    key: const Key('unified-detail-chapter-filter-sheet'),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UnifiedDetailSheetSectionHeader(
                          title: l10n.libraryDetailFilter,
                        ),
                        if (_supportsChapterDownloads)
                          UnifiedDetailTriStateLine(
                            lineKey: const Key(
                              'unified-detail-filter-downloaded',
                            ),
                            label: l10n.libraryDetailDownloaded,
                            value: selectedFilters.downloaded,
                            onChanged: (v) => setSheetState(
                              () => selectedFilters = selectedFilters.copyWith(
                                downloaded: v,
                              ),
                            ),
                          ),
                        if (_supportsChapterReadState)
                          UnifiedDetailTriStateLine(
                            lineKey: const Key('unified-detail-filter-unread'),
                            label: l10n.libraryDetailUnread,
                            value: selectedFilters.unread,
                            onChanged: (v) => setSheetState(
                              () => selectedFilters = selectedFilters.copyWith(
                                unread: v,
                              ),
                            ),
                          ),
                        UnifiedDetailTriStateLine(
                          lineKey: const Key(
                            'unified-detail-filter-bookmarked',
                          ),
                          label: l10n.libraryDetailBookmarked,
                          value: selectedFilters.bookmarked,
                          onChanged: (v) => setSheetState(
                            () => selectedFilters = selectedFilters.copyWith(
                              bookmarked: v,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        UnifiedDetailSheetSectionHeader(
                          title: l10n.libraryDetailSort,
                        ),
                        LibrarySortOptionTile(
                          key: const Key('unified-detail-sort-source'),
                          label: l10n.libraryDetailSortBySource,
                          selected: true,
                          direction: selectedDirection,
                          onTap: () {
                            setSheetState(() {
                              selectedDirection =
                                  selectedDirection == LibrarySortDirection.asc
                                  ? LibrarySortDirection.desc
                                  : LibrarySortDirection.asc;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                child: Text(l10n.commonCancel),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                key: const Key(
                                  'unified-detail-apply-filter-sort',
                                ),
                                onPressed: () async {
                                  await _controller.updateChapterQuery(
                                    filters: selectedFilters,
                                    sortOption: LibraryChapterSortOption(
                                      direction: selectedDirection,
                                    ),
                                  );
                                  if (!mounted || !sheetContext.mounted) {
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop();
                                  setState(() {});
                                },
                                child: Text(l10n.commonApply),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showChapterActions(LibraryChapterItem chapter) async {
    await showAdaptivePanel<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_page.onOpenChapterFromBeginning != null)
                  ListTile(
                    key: ValueKey<String>(
                      'unified-detail-chapter-start-action-${chapter.episodeId}',
                    ),
                    leading: const Icon(Icons.first_page),
                    title: Text(l10n.libraryDetailStartFromBeginning),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _page.onOpenChapterFromBeginning!(context, chapter);
                      if (!mounted) return;
                      await _controller.reload();
                      if (mounted) setState(() {});
                    },
                  ),
                ListTile(
                  key: ValueKey<String>(
                    'unified-detail-chapter-bookmark-action-${chapter.episodeId}',
                  ),
                  leading: Icon(
                    chapter.isBookmarked
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                  ),
                  title: Text(
                    chapter.isBookmarked
                        ? l10n.libraryDetailRemoveBookmark
                        : l10n.libraryDetailAddBookmark,
                  ),
                  onTap: () async {
                    await _controller.markChapterBookmarked(
                      episodeId: chapter.episodeId,
                      isBookmarked: !chapter.isBookmarked,
                    );
                    if (!mounted || !sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    setState(() {});
                  },
                ),
                if (_supportsChapterReadThrough)
                  ListTile(
                    key: ValueKey<String>(
                      'unified-detail-chapter-mark-read-through-action-${chapter.episodeId}',
                    ),
                    leading: const Icon(Icons.done_all),
                    title: Text(l10n.libraryChapterMarkReadThrough),
                    subtitle: Text(l10n.libraryChapterMarkReadThroughScope),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _markReadThroughChapter(chapter);
                    },
                  ),
                if (_workReadingResetAdapter != null)
                  ListTile(
                    key: const Key('unified-detail-work-reset-reading-action'),
                    leading: const Icon(Icons.remove_done),
                    title: Text(l10n.libraryDetailResetWorkReading),
                    onTap: () async {
                      if (!sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      await _confirmAndResetWorkReadingState();
                    },
                  ),
                if (_supportsChapterDownloads && chapter.isDownloaded)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.libraryDetailDeleteChapterDownload),
                    onTap: () async {
                      await _controller.deleteChapterDownload(
                        episodeId: chapter.episodeId,
                      );
                      if (!mounted || !sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      setState(() {});
                    },
                  ),
                if (_chapterManagementAdapter != null)
                  ListTile(
                    key: const Key('unified-detail-chapter-management-action'),
                    leading: const Icon(Icons.playlist_add_check),
                    title: Text(l10n.libraryDetailManageChapters),
                    onTap: () async {
                      if (!sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      await _showChapterManagementSheet();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChapterManagementSheet() async {
    final adapter = _chapterManagementAdapter;
    if (adapter == null) {
      return;
    }
    var changed = false;
    await showAdaptivePanel<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return UnifiedDetailChapterManagementSheet(
          workId: _page.workId,
          adapter: adapter,
          onChanged: () => changed = true,
        );
      },
    );
    // 章节可见性直接决定详情列表与阅读器导航，关闭后必须重新加载一次；
    // 没有任何写入时跳过，避免长列表白重排一遍。
    if (!changed || !mounted) {
      return;
    }
    await _controller.reload();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmAndResetWorkReadingState() async {
    if (_isResettingWorkReading) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.libraryDetailResetReadingTitle,
      message: l10n.libraryDetailResetReadingBody,
      confirmLabel: l10n.libraryDetailResetReadingConfirm,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      confirmKey: const Key('unified-detail-work-reset-reading-confirm'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      final operation = _controller.resetWorkReadingState();
      setState(() {});
      await operation;
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailResetReadingFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleMoreAction(String value) async {
    if (value == 'refresh') {
      await _refreshAndShowFeedback();
      return;
    }
    if (value == 'change-category') {
      await _showMoveCategorySheet();
      return;
    }
    if (value == 'edit-metadata') {
      await _showEditMetadataSheet();
      return;
    }
    if (value == 'configure-catalog') {
      await _showCatalogConfigurationSheet();
      return;
    }
    if (value == 'source-tags') {
      await _showSourceTagsSheet();
      return;
    }
    if (value == 'manage-chapters') {
      await _showChapterManagementSheet();
      return;
    }
    if (value == 'set-custom-cover') {
      await _handleSetCustomCover();
      return;
    }
    if (value == 'set-cover-from-post') {
      await _handleSetCoverFromPostImages();
      return;
    }
    if (value == 'remove-custom-cover') {
      await _handleRemoveCustomCover();
      return;
    }
    if (value == 'edit-intro') {
      await _showEditIntroDialog();
    }
  }

  Future<void> _showSourceTagsSheet() async {
    final adapter = _sourceTagsAdapter;
    if (adapter == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final canSetCatalog = _page.adapter is DetailCatalogEditor;
    await showAdaptivePanel<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.libraryDetailSourceTags,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: FutureBuilder<List<DetailSourceTag>>(
                    future: adapter.loadSourceTags(workId: _page.workId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return AppLoadingState(label: l10n.commonLoading);
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            l10n.libraryDetailSourceTagsLoadFailed,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final tags = snapshot.data ?? const <DetailSourceTag>[];
                      if (tags.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.libraryDetailSourceTagsEmpty,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.builder(
                        key: const Key('unified-detail-source-tags-list'),
                        itemCount: tags.length,
                        itemBuilder: (context, index) {
                          final tag = tags[index];
                          return ListTile(
                            key: Key('unified-detail-source-tag-${tag.tagId}'),
                            leading: const Icon(Icons.sell_outlined),
                            title: Text(tag.label),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canSetCatalog)
                                  IconButton(
                                    key: Key(
                                      'unified-detail-source-tag-catalog-${tag.tagId}',
                                    ),
                                    tooltip: l10n.libraryDetailUseTagAsCatalog,
                                    icon: const Icon(Icons.playlist_add),
                                    onPressed: () {
                                      navigator.pop(sheetContext);
                                      unawaited(
                                        _confirmAndSetSourceTagAsCatalog(tag),
                                      );
                                    },
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              navigator.pop(sheetContext);
                              navigator.push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      YamiboTagThreadPage(tagId: tag.tagId),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndSetSourceTagAsCatalog(DetailSourceTag tag) async {
    final editor = _page.adapter is DetailCatalogEditor
        ? _page.adapter as DetailCatalogEditor
        : null;
    if (editor == null || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.libraryDetailUseTagAsCatalogTitle,
      message: l10n.libraryDetailUseTagAsCatalogMessage(tag.label),
      confirmLabel: l10n.commonConfirm,
      cancelLabel: l10n.commonCancel,
      confirmKey: const Key('unified-detail-source-tag-catalog-confirm'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    final catalogUrl = Uri.parse(AppConfig.siteBaseUrl)
        .replace(
          path: '/misc.php',
          queryParameters: <String, String>{'mod': 'tag', 'id': tag.tagId},
        )
        .toString();
    final DetailCatalogUpdateOutcome outcome;
    try {
      outcome = await editor.updateCatalogOverride(
        workId: _page.workId,
        catalogUrl: catalogUrl,
      );
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(l10n.libraryDetailUseTagAsCatalogFailed);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (outcome.code != DetailCatalogUpdateOutcomeCode.saved) {
      _showDetailSnackBar(l10n.libraryDetailUseTagAsCatalogFailed);
      return;
    }
    // The existing refresh pipeline reads the new catalog and merges chapters
    // by source identity while preserving progress and offline data.
    await _refreshAndShowFeedback();
  }

  Future<void> _refreshAndShowFeedback({bool full = false}) {
    final active = _refreshFeedbackInFlight;
    if (active != null) {
      return active;
    }
    late final Future<void> guardedRun;
    guardedRun = _performRefreshAndShowFeedback(full: full).whenComplete(() {
      if (identical(_refreshFeedbackInFlight, guardedRun)) {
        _refreshFeedbackInFlight = null;
      }
    });
    _refreshFeedbackInFlight = guardedRun;
    return guardedRun;
  }

  Future<void> _performRefreshAndShowFeedback({required bool full}) async {
    try {
      final result = full
          ? await _controller.refreshFully()
          : await _controller.refresh();
      if (!mounted) return;
      await _page.onRefreshCompleted?.call(result);
      if (!mounted) {
        return;
      }
      _showDetailSnackBar(_refreshFeedbackMessage(result));
      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      _showDetailSnackBar(
        l10n.libraryDetailRefreshFailed(
          LibraryDetailTextResolver.safeError(l10n, error),
        ),
      );
      setState(() {});
    }
  }

  String _refreshFeedbackMessage(DetailRefreshResult result) {
    return LibraryDetailTextResolver.refreshOutcome(
      AppLocalizations.of(context),
      result,
    );
  }

  Future<void> _retryLoad() async {
    await _controller.reload();
    if (mounted) {
      setState(() {});
      _scheduleFirstContentPresented();
    }
  }

  void _showDetailSnackBar(String message) {
    if (!mounted) {
      return;
    }
    showTransientSnackBar(context, message);
  }

  Future<void> _showEditMetadataSheet() async {
    final editor = _page.adapter is DetailMetadataEditor
        ? _page.adapter as DetailMetadataEditor
        : null;
    final header = _controller.state.header;
    if (editor == null || header == null) {
      return;
    }
    final config = editor.metadataEditorConfig;
    await showAdaptivePanel<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return UnifiedDetailMetadataSheet(
          initialTitle: _metadataInitialValue(
            customValue: header.customTitle,
            displayValue: header.title,
            sourceValue: header.sourceTitle,
          ),
          initialAuthor: _metadataInitialValue(
            customValue: header.customAuthor,
            displayValue: header.author,
            sourceValue: header.sourceAuthor,
          ),
          initialTranslationGroup: _metadataInitialValue(
            customValue: header.customTranslationGroup,
            displayValue: header.translationGroup,
            sourceValue: header.sourceTranslationGroup,
          ),
          initialSearchTitle: header.customSearchTitle ?? '',
          titleSourceText: LibraryDetailTextResolver.sourceValue(
            AppLocalizations.of(sheetContext),
            LibraryDetailTextResolver.metadataSourceField(
              AppLocalizations.of(sheetContext),
              LibraryMetadataField.title,
            ),
            header.sourceTitle ?? header.title,
          ),
          authorSourceText: LibraryDetailTextResolver.sourceValue(
            AppLocalizations.of(sheetContext),
            LibraryDetailTextResolver.metadataSourceField(
              AppLocalizations.of(sheetContext),
              LibraryMetadataField.author,
            ),
            header.sourceAuthor ??
                (config.fallbackToDisplaySourceValues ? header.author : null),
          ),
          groupSourceText: LibraryDetailTextResolver.sourceValue(
            AppLocalizations.of(sheetContext),
            LibraryDetailTextResolver.metadataSourceField(
              AppLocalizations.of(sheetContext),
              LibraryMetadataField.translationGroup,
            ),
            header.sourceTranslationGroup ??
                (config.fallbackToDisplaySourceValues
                    ? header.translationGroup
                    : null),
          ),
          fields: config.fields,
          onSave:
              ({
                customTitle,
                customAuthor,
                customTranslationGroup,
                customSearchTitle,
              }) async {
                await editor.updateCustomMetadata(
                  workId: _page.workId,
                  customTitle: customTitle,
                  customAuthor: customAuthor,
                  customTranslationGroup: customTranslationGroup,
                  customSearchTitle: customSearchTitle,
                );
                await _controller.reload();
                if (!mounted) {
                  return;
                }
                setState(() {});
              },
        );
      },
    );
  }

  Future<void> _showCatalogConfigurationSheet() async {
    final editor = _page.adapter is DetailCatalogEditor
        ? _page.adapter as DetailCatalogEditor
        : null;
    if (editor == null) {
      return;
    }

    late final DetailCatalogConfiguration configuration;
    try {
      configuration = await editor.loadCatalogConfiguration(
        workId: _page.workId,
      );
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showDetailSnackBar(
          l10n.libraryDetailCatalogLoadFailed(
            LibraryDetailTextResolver.safeError(l10n, error),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }

    await showAdaptivePanel<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return UnifiedDetailCatalogSheet(
          initialCatalogUrl: configuration.initialInputValue,
          sourceCatalogUrl: configuration.sourceCatalogUrl,
          onSave: (catalogUrl) async {
            final outcome = await editor.updateCatalogOverride(
              workId: _page.workId,
              catalogUrl: catalogUrl,
            );
            if (outcome.code == DetailCatalogUpdateOutcomeCode.saved) {
              await _controller.reload();
              if (mounted) {
                setState(() {});
              }
            }
            return outcome;
          },
        );
      },
    );
  }

  /// 是否支持自定义封面编辑：adapter 实现合同且外壳注入了图片选择器。
  bool get _supportsCoverEditing =>
      _page.adapter is DetailCoverEditor && _page.pickCoverImage != null;

  /// 是否支持从帖子图片选封面：模块能给出候选且外壳能取回图片文件。
  bool get _supportsCoverCandidates =>
      _page.adapter is DetailCoverCandidateSource &&
      _page.importCoverImage != null;

  DetailCoverCandidateSource? get _coverCandidateSource {
    final adapter = _page.adapter;
    return adapter is DetailCoverCandidateSource
        ? adapter as DetailCoverCandidateSource
        : null;
  }

  bool get _canRemoveCover {
    final editor = _coverEditor;
    final header = _controller.state.header;
    return editor != null && header != null && editor.canRemoveCover(header);
  }

  DetailCoverEditor? get _coverEditor => _page.adapter is DetailCoverEditor
      ? _page.adapter as DetailCoverEditor
      : null;

  /// 自定义封面：选图 → 焦点选区 → 落盘保存 → 刷新。
  Future<void> _handleSetCustomCover() async {
    final editor = _coverEditor;
    final pick = _page.pickCoverImage;
    if (editor == null || pick == null || _coverMutationInFlight) {
      return;
    }
    final sourcePath = await pick();
    if (sourcePath == null || sourcePath.trim().isEmpty || !mounted) {
      return;
    }
    await _applyCustomCoverFromLocalPath(editor, sourcePath);
  }

  /// 帖子图片封面：候选 → 取回本地文件 → 焦点选区 → 既有自定义封面链。
  Future<void> _handleSetCoverFromPostImages() async {
    final source = _coverCandidateSource;
    final importer = _page.importCoverImage;
    if (source == null || importer == null || _coverMutationInFlight) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    // 面板 builder 会随动画重建；候选请求只发起一次。
    final candidates = source.loadCoverCandidates(workId: _page.workId);
    final selectedImageUrl = await showAdaptivePanel<String>(
      context: context,
      builder: (sheetContext) => UnifiedDetailCoverCandidatesSheet(
        candidates: candidates,
        imageReferer: _page.imageReferer,
      ),
    );
    if (selectedImageUrl == null || selectedImageUrl.isEmpty || !mounted) {
      return;
    }
    final editor = _coverEditor;
    if (editor == null) {
      return;
    }
    final String localPath;
    try {
      localPath = await importer(selectedImageUrl);
    } catch (error) {
      if (mounted) {
        _showDetailSnackBar(
          l10n.libraryDetailCoverCandidateImportFailed(
            LibraryDetailTextResolver.safeError(l10n, error),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await _applyCustomCoverFromLocalPath(editor, localPath);
  }

  Future<void> _applyCustomCoverFromLocalPath(
    DetailCoverEditor editor,
    String sourcePath,
  ) async {
    final focus = await CoverFocalPointPicker.show(
      context,
      image: FileImage(io.File(sourcePath)),
    );
    if (focus == null || !mounted) {
      return;
    }
    await _runCoverMutation(
      () => editor.setCustomCoverFromLocalFile(
        workId: _page.workId,
        sourceLocalPath: sourcePath,
        focusX: focus.x,
        focusY: focus.y,
      ),
      failureBuilder: AppLocalizations.of(context)
          .libraryDetailCoverUpdateFailed,
      successMessage: AppLocalizations.of(context).libraryDetailCoverUpdated,
    );
  }

  Future<void> _handleRemoveCustomCover() async {
    final editor = _coverEditor;
    if (editor == null || !_canRemoveCover || _coverMutationInFlight) {
      return;
    }
    await _runCoverMutation(
      () => editor.removeCustomCover(workId: _page.workId),
      failureBuilder: AppLocalizations.of(context)
          .libraryDetailCoverRemoveFailed,
      successMessage: AppLocalizations.of(context).libraryDetailCoverRemoved,
    );
  }

  Future<void> _runCoverMutation(
    Future<void> Function() action, {
    required String Function(String error) failureBuilder,
    required String successMessage,
  }) async {
    _coverMutationInFlight = true;
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      _showDetailSnackBar(
        failureBuilder(LibraryDetailTextResolver.safeError(l10n, error)),
      );
      return;
    } finally {
      _coverMutationInFlight = false;
    }
    if (!mounted) {
      return;
    }
    await _controller.reload();
    if (!mounted) {
      return;
    }
    _showDetailSnackBar(successMessage);
    _notifyCoverChanged();
    setState(() {});
  }

  /// 封面保存在作品表中，书架与收藏页读的是同一份模块封面列；主动发布
  /// 信号避免返回已打开的列表后仍显示旧封面。
  void _notifyCoverChanged() {
    final bus = _page.shelfRefreshBus;
    if (bus == null) {
      return;
    }
    bus.notify(
      modules: <LibraryModuleKey>{
        _page.adapter.moduleKey,
        LibraryModuleKey.favorite,
      },
      reason: 'cover_updated',
      source: LibraryMutationSource.coverEdit,
      workId: _page.workId,
    );
    // 本页已用最新数据重载，跳过自己发出的这条信号。
    _lastHandledRefreshSignalSequence = bus.signal.value?.sequence ?? 0;
  }

  Future<void> _showMoveCategorySheet() async {
    final categories = await _page.adapter.loadCategories();
    final currentCategoryId = await _page.adapter.currentCategoryId(
      workId: _page.workId,
    );
    if (!mounted) {
      return;
    }
    final targets = categories
        .where(
          (item) =>
              !item.isSynthetic &&
              !item.isSystemCategory &&
              item.categoryId != currentCategoryId,
        )
        .toList(growable: false);
    final canRemoveFromCollection =
        currentCategoryId != null &&
        !LibrarySystemCategories.isSystem(currentCategoryId);
    if (targets.isEmpty && !canRemoveFromCollection) {
      return;
    }
    await showAdaptivePanel<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        Future<void> moveTo(String categoryId) async {
          await _page.adapter.moveWorkToCategory(
            workId: _page.workId,
            toCategoryId: categoryId,
          );
          if (!mounted || !sheetContext.mounted) {
            return;
          }
          Navigator.of(sheetContext).pop();
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final item in targets)
                ListTile(
                  title: Text(
                    LibraryShelfTextResolver.categoryName(l10n, item),
                  ),
                  onTap: () => moveTo(item.categoryId),
                ),
              if (canRemoveFromCollection)
                ListTile(
                  leading: const Icon(Icons.playlist_remove),
                  title: Text(l10n.libraryShelfRemoveFromCategory),
                  onTap: () => moveTo(LibraryCategoryTargets.home),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditIntroDialog() async {
    final current = _controller.state.header?.intro ?? '';
    final inputController = TextEditingController(text: current);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    await showAppFormDialog<void>(
      context: context,
      title: l10n.libraryDetailEditIntro,
      hasFields: true,
      content: AppTextInput(
        controller: inputController,
        maxLines: 6,
        hintText: l10n.libraryDetailIntroHint,
      ),
      actions: [
        AppDialogAction(
          label: l10n.commonCancel,
          onPressed: () => navigator.pop(),
        ),
        AppDialogAction(
          label: l10n.commonSave,
          onPressed: () async {
            await _page.adapter.updateIntro(
              workId: _page.workId,
              intro: inputController.text.trim(),
            );
            await _controller.reload();
            if (!mounted || !navigator.mounted) {
              return;
            }
            navigator.pop();
            setState(() {});
          },
        ),
      ],
    );
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _metadataInitialValue({
  required String? customValue,
  required String? displayValue,
  String? sourceValue,
}) {
  // 编辑框优先展示已保存的自定义值；未自定义时回填当前展示信息，
  // 让用户只改需要调整的字段，仍可清空输入框来恢复来源值。
  return _emptyToNull(customValue ?? '') ??
      _emptyToNull(displayValue ?? '') ??
      _emptyToNull(sourceValue ?? '') ??
      '';
}
