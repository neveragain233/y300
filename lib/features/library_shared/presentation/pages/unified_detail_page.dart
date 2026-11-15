import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_system_ui.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
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
  State<UnifiedDetailPage> createState() => _UnifiedDetailPageState();
}

class _UnifiedDetailPageState extends State<UnifiedDetailPage> {
  // 阈值适当降低，确保常见拖动距离能稳定触发折叠标题显示。
  static const double _collapsedTitleRevealOffset = 120;
  static const double _chapterDownloadIconSize = 28;

  late final UnifiedDetailController _controller;
  late final ScrollController _scrollController;

  bool _introExpanded = false;
  bool _showCollapsedTitle = false;
  int _lastHandledRefreshSignalSequence = 0;
  final Set<String> _downloadingEpisodeIds = <String>{};
  final Set<String> _readingStateMutationEpisodeIds = <String>{};
  bool _isResettingWorkReading = false;
  bool _isMarkingReadThrough = false;
  Future<void>? _refreshInFlight;
  Listenable? _chapterDownloadActivityListenable;
  final RouteContentPresentationGuard _contentPresentationGuard =
      RouteContentPresentationGuard();

  DetailChapterDownloadAdapter? get _downloadAdapter {
    final adapter = widget.adapter;
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
    final adapter = widget.adapter;
    return adapter is DetailChapterDownloadActivityAdapter
        ? adapter as DetailChapterDownloadActivityAdapter
        : null;
  }

  DetailChapterReadStateAdapter? get _readStateAdapter {
    final adapter = widget.adapter;
    return adapter is DetailChapterReadStateAdapter
        ? adapter as DetailChapterReadStateAdapter
        : null;
  }

  bool get _supportsChapterReadState => _readStateAdapter != null;

  bool get _supportsChapterReadThrough =>
      widget.adapter is DetailChapterReadThroughAdapter;

  bool get _supportsFullRefresh => widget.adapter is DetailFullRefreshAdapter;

  DetailWorkReadingResetAdapter? get _workReadingResetAdapter {
    final adapter = widget.adapter;
    return adapter is DetailWorkReadingResetAdapter
        ? adapter as DetailWorkReadingResetAdapter
        : null;
  }

  DetailChapterManagementAdapter? get _chapterManagementAdapter {
    final adapter = widget.adapter;
    return adapter is DetailChapterManagementAdapter
        ? adapter as DetailChapterManagementAdapter
        : null;
  }

  DetailSourceTagsAdapter? get _sourceTagsAdapter {
    final adapter = widget.adapter;
    return adapter is DetailSourceTagsAdapter
        ? adapter as DetailSourceTagsAdapter
        : null;
  }

  @override
  void initState() {
    super.initState();
    _controller = UnifiedDetailController(
      adapter: widget.adapter,
      workId: widget.workId,
    );
    _scrollController = ScrollController()..addListener(_handleScroll);
    widget.shelfRefreshBus?.signal.addListener(_handleShelfRefreshSignal);
    _bindChapterDownloadActivity();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    widget.shelfRefreshBus?.signal.removeListener(_handleShelfRefreshSignal);
    _chapterDownloadActivityListenable?.removeListener(
      _handleChapterDownloadActivityChanged,
    );
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UnifiedDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.shelfRefreshBus, widget.shelfRefreshBus)) {
      oldWidget.shelfRefreshBus?.signal.removeListener(
        _handleShelfRefreshSignal,
      );
      widget.shelfRefreshBus?.signal.addListener(_handleShelfRefreshSignal);
    }
    if (!identical(oldWidget.adapter, widget.adapter)) {
      _bindChapterDownloadActivity();
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
    if (_downloadingEpisodeIds.contains(episodeId)) {
      return true;
    }
    return _downloadActivityAdapter?.isChapterDownloadActive(
          workId: widget.workId,
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
    final signal = widget.shelfRefreshBus?.signal.value;
    if (signal == null ||
        signal.sequence <= _lastHandledRefreshSignalSequence ||
        !signal.modules.contains(widget.adapter.moduleKey)) {
      return;
    }
    final workId = signal.workId?.trim();
    if (workId == null || workId.isEmpty || workId != widget.workId) {
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
    if (widget.onFirstContentPresented == null) {
      return;
    }
    final routeWorkId = widget.workId;
    final state = _controller.state;
    final header = state.header;
    if (header == null || state.isLoading || state.errorMessage != null) {
      return;
    }
    final chapters = List<LibraryChapterItem>.unmodifiable(state.chapters);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.workId != routeWorkId) {
        return;
      }
      if (!_contentPresentationGuard.tryCommit(routeWorkId)) {
        return;
      }
      try {
        await widget.onFirstContentPresented?.call(header, chapters);
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
      key: ValueKey('detail-chapters-${widget.workId}'),
      workId: widget.workId,
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
              moduleKey: widget.adapter.moduleKey,
              topInset: topInset,
              palette: detailPalette,
              imageReferer: widget.imageReferer,
              onToggleShelf: () => _showMoveCategorySheet(),
              onRefresh: _refreshAndShowFeedback,
              onRefreshLongPress: _supportsFullRefresh
                  ? () => _refreshAndShowFeedback(full: true)
                  : null,
              onOpenThread: () async {
                final target = await widget.adapter.getThreadRouteTarget(
                  workId: widget.workId,
                );
                if (!context.mounted || target == null) {
                  return;
                }
                await widget.onOpenThread(context, target);
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
        if (widget.chapterStatus != null)
          SliverToBoxAdapter(child: widget.chapterStatus),
        SliverToBoxAdapter(
          child: UnifiedDetailChapterToolbar(
            chapterCount: state.chapters.length,
            filterSummary: _chapterFilterSummary(state.filters),
            hasActiveFilter: _hasActiveChapterFilter(state.filters),
            modeControl: widget.chapterModeControl,
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
            _isResettingWorkReading ||
            _isMarkingReadThrough ||
            _readingStateMutationEpisodeIds.contains(chapter.episodeId),
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
                            widget.adapter.moduleKey,
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
                          ),
                          AppPopupMenuItem<String>(
                            value: 'change-category',
                            label: l10n.libraryDetailChangeCategory,
                          ),
                          if (widget.adapter is DetailMetadataEditor)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-edit-metadata'),
                              value: 'edit-metadata',
                              label: l10n.libraryDetailEditMetadata,
                            ),
                          if (widget.adapter is DetailCatalogEditor)
                            AppPopupMenuItem<String>(
                              key: const Key(
                                'unified-detail-configure-catalog',
                              ),
                              value: 'configure-catalog',
                              label: l10n.libraryDetailConfigureCatalog,
                            ),
                          if (_sourceTagsAdapter != null)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-source-tags'),
                              value: 'source-tags',
                              label: l10n.libraryDetailSourceTags,
                            ),
                          // 章节长按之外的第二个入口：隐藏全部章节后列表为空，
                          // 长按目标随之消失，只靠长按会把“全部显示”永久锁死。
                          if (_chapterManagementAdapter != null)
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-manage-chapters'),
                              value: 'manage-chapters',
                              label: l10n.libraryDetailManageChapters,
                            ),
                          if (_supportsCoverEditing) ...[
                            AppPopupMenuItem<String>(
                              key: const Key('unified-detail-set-cover'),
                              value: 'set-custom-cover',
                              label: l10n.libraryDetailSetCustomCover,
                            ),
                            if (_canRemoveCover)
                              AppPopupMenuItem<String>(
                                key: const Key('unified-detail-remove-cover'),
                                value: 'remove-custom-cover',
                                label: l10n.libraryDetailRemoveCustomCover,
                              ),
                          ],
                          AppPopupMenuItem<String>(
                            value: 'edit-intro',
                            label: l10n.libraryDetailEditIntro,
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
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                // 从屏幕顶部出现刷新指示器。
                edgeOffset: 0,
                displacement: 28,
                elevation: 0,
                onRefresh: _refreshAndShowFeedback,
                child: chapterList,
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final target = await widget.adapter.getReaderRouteTarget(
              workId: widget.workId,
              preferContinue: true,
            );
            if (!context.mounted || target == null) {
              return;
            }
            final handler = widget.onContinue ?? widget.onOpenReader;
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
    final customHandler = widget.onOpenChapter;
    if (customHandler != null) {
      await customHandler(context, chapter);
    } else {
      final target = ReaderRouteTarget(
        workId: widget.workId,
        episodeId: chapter.episodeId,
      );
      await widget.onOpenReader(context, target);
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
        await _controller.deleteChapterDownload(episodeId: chapter.episodeId);
        if (mounted) {
          setState(() {});
        }
      } catch (error) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showDetailSnackBar(
            l10n.libraryDetailDeleteDownloadFailed(
              LibraryDetailTextResolver.safeError(l10n, error),
            ),
          );
        }
      }
      return;
    }

    setState(() {
      _downloadingEpisodeIds.add(chapter.episodeId);
    });
    try {
      await _controller.markChapterDownloaded(
        episodeId: chapter.episodeId,
        isDownloaded: true,
      );
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
        setState(() {
          _downloadingEpisodeIds.remove(chapter.episodeId);
        });
      }
    }
  }

  Future<void> _toggleChapterReadingState(LibraryChapterItem chapter) async {
    if (_isResettingWorkReading ||
        _isMarkingReadThrough ||
        _readingStateMutationEpisodeIds.contains(chapter.episodeId)) {
      return;
    }
    setState(() {
      _readingStateMutationEpisodeIds.add(chapter.episodeId);
    });
    try {
      await _controller.toggleChapterReadingState(
        episodeId: chapter.episodeId,
        isCurrentlyRead: chapter.isRead,
      );
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailReadStateUpdateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _readingStateMutationEpisodeIds.remove(chapter.episodeId);
        });
      }
    }
  }

  Future<void> _markReadThroughChapter(LibraryChapterItem chapter) async {
    if (!_supportsChapterReadThrough ||
        _isMarkingReadThrough ||
        _isResettingWorkReading ||
        _readingStateMutationEpisodeIds.isNotEmpty) {
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
        _readingStateMutationEpisodeIds.isNotEmpty) {
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
    widget.shelfRefreshBus?.notify(
      modules: <LibraryModuleKey>{widget.adapter.moduleKey},
      reason: reason,
      source: LibraryMutationSource.readingStateBatch,
      workId: widget.workId,
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
      ),
      AppPopupMenuItem<String>(
        value: 'download-all',
        label: l10n.libraryDetailDownloadAll,
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
        await downloadAdapter.downloadUnread(workId: widget.workId);
        return;
      }
      if (value == 'download-all') {
        await downloadAdapter.downloadAll(workId: widget.workId);
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
                if (widget.onOpenChapterFromBeginning != null)
                  ListTile(
                    key: ValueKey<String>(
                      'unified-detail-chapter-start-action-${chapter.episodeId}',
                    ),
                    leading: const Icon(Icons.first_page),
                    title: Text(l10n.libraryDetailStartFromBeginning),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await widget.onOpenChapterFromBeginning!(
                        context,
                        chapter,
                      );
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
          workId: widget.workId,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.libraryDetailResetReadingTitle),
          content: Text(l10n.libraryDetailResetReadingBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('unified-detail-work-reset-reading-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.libraryDetailResetReadingConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _isResettingWorkReading = true;
    });
    try {
      await _controller.resetWorkReadingState();
    } catch (_) {
      if (mounted) {
        _showDetailSnackBar(
          AppLocalizations.of(context).libraryDetailResetReadingFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResettingWorkReading = false;
        });
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
    final canSetCatalog = widget.adapter is DetailCatalogEditor;
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
                    future: adapter.loadSourceTags(workId: widget.workId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
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
    final editor = widget.adapter is DetailCatalogEditor
        ? widget.adapter as DetailCatalogEditor
        : null;
    if (editor == null || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.libraryDetailUseTagAsCatalogTitle),
        content: Text(l10n.libraryDetailUseTagAsCatalogMessage(tag.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('unified-detail-source-tag-catalog-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
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
        workId: widget.workId,
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
    final active = _refreshInFlight;
    if (active != null) {
      return active;
    }
    late final Future<void> guardedRun;
    guardedRun = _performRefreshAndShowFeedback(full: full).whenComplete(() {
      if (identical(_refreshInFlight, guardedRun)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = guardedRun;
    return guardedRun;
  }

  Future<void> _performRefreshAndShowFeedback({required bool full}) async {
    try {
      final result = full
          ? await _controller.refreshFully()
          : await _controller.refresh();
      await widget.onRefreshCompleted?.call(result);
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showEditMetadataSheet() async {
    final editor = widget.adapter is DetailMetadataEditor
        ? widget.adapter as DetailMetadataEditor
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
                  workId: widget.workId,
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
    final editor = widget.adapter is DetailCatalogEditor
        ? widget.adapter as DetailCatalogEditor
        : null;
    if (editor == null) {
      return;
    }

    late final DetailCatalogConfiguration configuration;
    try {
      configuration = await editor.loadCatalogConfiguration(
        workId: widget.workId,
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
              workId: widget.workId,
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
      widget.adapter is DetailCoverEditor && widget.pickCoverImage != null;

  bool get _canRemoveCover {
    final editor = _coverEditor;
    final header = _controller.state.header;
    return editor != null && header != null && editor.canRemoveCover(header);
  }

  DetailCoverEditor? get _coverEditor => widget.adapter is DetailCoverEditor
      ? widget.adapter as DetailCoverEditor
      : null;

  /// 自定义封面：选图 → 焦点选区 → 落盘保存 → 刷新。
  Future<void> _handleSetCustomCover() async {
    final editor = _coverEditor;
    final pick = widget.pickCoverImage;
    if (editor == null || pick == null) {
      return;
    }
    final sourcePath = await pick();
    if (sourcePath == null || sourcePath.trim().isEmpty || !mounted) {
      return;
    }
    final focus = await CoverFocalPointPicker.show(
      context,
      image: FileImage(io.File(sourcePath)),
    );
    if (focus == null || !mounted) {
      return;
    }
    try {
      await editor.setCustomCoverFromLocalFile(
        workId: widget.workId,
        sourceLocalPath: sourcePath,
        focusX: focus.x,
        focusY: focus.y,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      _showDetailSnackBar(
        l10n.libraryDetailCoverUpdateFailed(
          LibraryDetailTextResolver.safeError(l10n, error),
        ),
      );
      return;
    }
    await _controller.reload();
    if (!mounted) {
      return;
    }
    _showDetailSnackBar(AppLocalizations.of(context).libraryDetailCoverUpdated);
    setState(() {});
  }

  Future<void> _handleRemoveCustomCover() async {
    final editor = _coverEditor;
    if (editor == null || !_canRemoveCover) {
      return;
    }
    try {
      await editor.removeCustomCover(workId: widget.workId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      _showDetailSnackBar(
        l10n.libraryDetailCoverRemoveFailed(
          LibraryDetailTextResolver.safeError(l10n, error),
        ),
      );
      return;
    }
    await _controller.reload();
    if (!mounted) {
      return;
    }
    _showDetailSnackBar(AppLocalizations.of(context).libraryDetailCoverRemoved);
    setState(() {});
  }

  Future<void> _showMoveCategorySheet() async {
    final categories = await widget.adapter.loadCategories();
    final currentCategoryId = await widget.adapter.currentCategoryId(
      workId: widget.workId,
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
          await widget.adapter.moveWorkToCategory(
            workId: widget.workId,
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.libraryDetailEditIntro),
          content: TextField(
            controller: inputController,
            maxLines: 6,
            decoration: InputDecoration(hintText: l10n.libraryDetailIntroHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () async {
                await widget.adapter.updateIntro(
                  workId: widget.workId,
                  intro: inputController.text.trim(),
                );
                await _controller.reload();
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                setState(() {});
              },
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
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
