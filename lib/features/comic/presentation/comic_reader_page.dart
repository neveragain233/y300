import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:y300/features/library_shared/presentation/detail/unified_detail_chapter_tile.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_chapter_browser.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/comic/domain/models/comic_reader_exit_result.dart';
import 'package:y300/features/comic/domain/services/comic_episode_sequence.dart';
import 'package:y300/features/comic/domain/services/comic_episode_images_unavailable.dart';
import 'package:y300/features/comic/data/providers/comic_source_tag_providers.dart';
import 'package:y300/features/comic/presentation/comic_presentation_models.dart';
import 'package:y300/features/comic/presentation/comic_reader_capability.dart';
import 'package:y300/features/comic/presentation/comic_text_resolver.dart';
import 'package:y300/features/comic/presentation/controllers/comic_reader_controller.dart';
import 'package:y300/features/comic/presentation/controllers/comic_comment_session_controller.dart';
import 'package:y300/features/comic/presentation/providers/comic_comment_providers.dart';
import 'package:y300/features/comic/presentation/widgets/comic_source_tags_sheet.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/library_shared/presentation/widgets/cover_focal_point_picker.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/engine/engine.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/reader_preferences_provider.dart';
import 'package:y300/features/thread/presentation/thread_detail_page.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:y300/l10n/app_localizations.dart';

enum _ComicReaderMoreAction {
  refreshEpisode,
  markReadToggle,
  setCurrentPageAsCover,
}

/// 漫画阅读器页面。
///
/// 通用阅读壳（模式/缩放/overlay/滑块/页码/显示设置/滚动锚定）已下沉到
/// [ImageReaderEngine]；本页只负责漫画专属编排：加载/错误态、章节切换、更多操作、
/// 章节列表、原帖跳转、下一章过场卡，并通过 [ComicReaderCapability] 注入引擎。
class ComicReaderPage extends ConsumerStatefulWidget {
  const ComicReaderPage({
    super.key,
    required this.comicId,
    required this.episodeId,
    this.openPolicy = ComicEpisodeOpenPolicy.resumeIfUnread,
    this.diagnosticRecorder = const NoopContinuousImageDiagnosticRecorder(),
  });

  final String comicId;
  final String episodeId;
  final ComicEpisodeOpenPolicy openPolicy;
  final ContinuousImageDiagnosticRecorder diagnosticRecorder;

  @override
  ConsumerState<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends ConsumerState<ComicReaderPage> {
  ComicReaderArgs get _readerArgs => ComicReaderArgs(
    comicId: widget.comicId,
    episodeId: widget.episodeId,
    openPolicy: widget.openPolicy,
  );

  ComicReaderController _controller() {
    return ref.read(comicReaderControllerProvider(_readerArgs).notifier);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preferencesState = ref.watch(readerPreferencesControllerProvider);
    final preferences = preferencesState.value ?? ReaderPreferences.defaults();
    final state = ref.watch(comicReaderControllerProvider(_readerArgs));
    final imageReferer = ref.watch(forumImageRefererProvider);

    return Scaffold(
      body: state.when(
        loading: () => _ReaderOpeningPlaceholder(
          background: _readerBackgroundColor(preferences),
        ),
        error: (error, stackTrace) => _buildReaderErrorState(error),
        data: (viewState) {
          if (viewState.images.isEmpty) {
            return _buildNoImagesState(viewState);
          }
          final controller = _controller();
          final commentSessionKey = ComicCommentSessionKey(
            episodeId: viewState.episodeId,
            sourceTid: viewState.sourceTid,
          );
          final commentTail = ref.watch(
            comicCommentTailSurfaceProvider(commentSessionKey),
          );
          final commentSession = ref.watch(
            comicCommentSessionControllerProvider(commentSessionKey),
          );
          commentTail.updateChapterImages(
            viewState.images.map((image) => image.imageUrl),
          );
          commentTail.updateNavigation(
            hasNextEpisode: viewState.hasNextEpisode,
            onAdvanceEpisode: viewState.nextChapter == null
                ? null
                : () => _openAdjacentEpisode(
                    sourceEpisodeId: viewState.episodeId,
                    direction: ComicEpisodeDirection.next,
                  ),
          );
          return AnimatedBuilder(
            animation: commentTail,
            builder: (context, _) {
              final reader = ImageReaderEngine(
                key: const Key('comic-reader-engine'),
                listKey: const Key('comic-reader-image-list'),
                pageKey: const Key('comic-reader-page-view'),
                slotKeyPrefix: 'comic-reader-image-slot',
                capability: ComicReaderCapability(
                  viewState: viewState,
                  preferences: preferences,
                  imageReferer: imageReferer,
                  controller: controller,
                  l10n: l10n,
                  diagnosticRecorder: widget.diagnosticRecorder,
                  exitResult: _exitResultFor(viewState),
                  commentTailSurface: commentTail,
                  onLastImageVisible: () => unawaited(commentSession.load()),
                  onToggleBookmark: () => unawaited(_toggleBookmark()),
                  onOpenSourceThread: () => _openSourceThread(viewState),
                  moreMenu: _buildMoreMenu(viewState),
                  onShowChapterList: () =>
                      unawaited(_showChapterListSheet(viewState)),
                  onOpenAdjacentEpisode: ({required direction}) => unawaited(
                    _openAdjacentEpisode(
                      sourceEpisodeId: viewState.episodeId,
                      direction: direction,
                    ),
                  ),
                  buildNextChapterTransition: (context) =>
                      _ReaderNextChapterTransition(
                        nextChapter: viewState.nextChapter,
                        isSwitchingEpisode: viewState.isSwitchingEpisode,
                        onOpenNext: () => unawaited(
                          _openAdjacentEpisode(
                            sourceEpisodeId: viewState.episodeId,
                            direction: ComicEpisodeDirection.next,
                          ),
                        ),
                      ),
                ),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  reader,
                  if (viewState.isSwitchingEpisode ||
                      viewState.isRefreshingEpisode)
                    Positioned.fill(
                      child: _ComicReaderSwitchOverlay(
                        background: _readerBackgroundColor(preferences),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
  // COMIC_PAGE_BODY_PLACEHOLDER

  /// 阅读器错误态：拉单话图片失败显示根因 + 重试；解析失败不出重试按钮。
  Widget _buildReaderErrorState(Object error) {
    final l10n = AppLocalizations.of(context);
    final hint = ComicTextResolver.readerFailure(l10n, error);
    final retryable =
        error is! ComicEpisodeImagesUnavailable || error.isRetryable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hint, textAlign: TextAlign.center),
            if (retryable) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(comicReaderControllerProvider(_readerArgs)),
                child: Text(l10n.commonRetry),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  key: const Key('comic-reader-error-source-tags'),
                  onPressed: () => unawaited(_showSourceTagsForReader()),
                  child: Text(l10n.libraryDetailSourceTags),
                ),
                OutlinedButton(
                  key: const Key('comic-reader-error-source-thread'),
                  onPressed: () => unawaited(_openSourceThreadForReader()),
                  child: Text(l10n.comicOpenSourceThread),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagesState(ComicReaderViewState viewState) {
    final l10n = AppLocalizations.of(context);
    final hasSource = viewState.sourceTid.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.comicNoImages, textAlign: TextAlign.center),
            if (hasSource) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    key: const Key('comic-reader-no-images-source-tags'),
                    onPressed: () => unawaited(
                      _showSourceTagsForReader(episodeId: viewState.episodeId),
                    ),
                    child: Text(l10n.libraryDetailSourceTags),
                  ),
                  OutlinedButton(
                    key: const Key('comic-reader-no-images-source-thread'),
                    onPressed: () => unawaited(_openSourceThread(viewState)),
                    child: Text(l10n.comicOpenSourceThread),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  ComicReaderExitResult _exitResultFor(ComicReaderViewState viewState) {
    return ComicReaderExitResult(
      comicId: viewState.comicId,
      lastReadEpisodeId: viewState.episodeId,
      completedEpisodeIds: viewState.isCurrentEpisodeRead
          ? <String>[viewState.episodeId]
          : const <String>[],
    );
  }

  Color _readerBackgroundColor(ReaderPreferences preferences) {
    return resolveReaderBackground(
      themeSurface: Theme.of(context).colorScheme.surface,
      background: preferences.background,
      readerMode: preferences.readerMode,
      eInkMode: EInkModeScope.of(context),
    );
  }

  Future<void> _openSourceThread(ComicReaderViewState viewState) async {
    await _openThreadByTid(viewState.sourceTid, viewState.episodeTitle);
  }

  Future<void> _openThreadByTid(String tid, String? subject) async {
    final normalized = tid.trim();
    if (normalized.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadDetailPage(
          tid: normalized,
          subject: subject ?? '',
          gateBlockedEntry: true,
        ),
      ),
    );
  }

  Future<void> _showSourceTagsForReader({String? episodeId}) async {
    final args = _readerArgs;
    await showComicSourceTagsSheet(
      context,
      loadTags: () => ref
          .read(comicSourceTagReaderProvider)
          .readSourceTags(
            comicId: args.comicId,
            episodeId: episodeId ?? args.episodeId,
          ),
    );
  }

  Future<void> _openSourceThreadForReader() async {
    final l10n = AppLocalizations.of(context);
    final tid = await ref
        .read(comicSourceTagReaderProvider)
        .resolveSourceTid(
          comicId: _readerArgs.comicId,
          episodeId: _readerArgs.episodeId,
        );
    if (!mounted) {
      return;
    }
    if (tid == null) {
      showTransientSnackBar(context, l10n.comicSourceThreadUnavailable);
      return;
    }
    await _openThreadByTid(tid, null);
  }

  Future<void> _openAdjacentEpisode({
    required String sourceEpisodeId,
    required ComicEpisodeDirection direction,
  }) async {
    await _controller().openAdjacentEpisode(
      sourceEpisodeId: sourceEpisodeId,
      direction: direction,
    );
  }

  Future<void> _handleReaderMoreAction(
    _ComicReaderMoreAction action,
    ComicReaderViewState viewState,
  ) async {
    final controller = _controller();
    switch (action) {
      case _ComicReaderMoreAction.refreshEpisode:
        final result = await controller.refreshCurrentEpisode();
        if (!mounted) {
          return;
        }
        final l10n = AppLocalizations.of(context);
        final message = switch (result.status) {
          ComicReaderEpisodeRefreshStatus.refreshed =>
            l10n.comicReaderEpisodeRefreshed,
          ComicReaderEpisodeRefreshStatus.noImages =>
            l10n.comicReaderRefreshNoImages,
          ComicReaderEpisodeRefreshStatus.failed =>
            l10n.comicReaderRefreshFailed,
          ComicReaderEpisodeRefreshStatus.stale => null,
        };
        if (message != null) {
          showTransientSnackBar(context, message);
        }
      case _ComicReaderMoreAction.markReadToggle:
        final notice = await controller.setCurrentEpisodeRead(
          !viewState.isCurrentEpisodeRead,
        );
        if (mounted && notice != null) {
          showTransientSnackBar(
            context,
            ComicTextResolver.readerNotice(
              AppLocalizations.of(context),
              notice,
            ),
          );
        }
      case _ComicReaderMoreAction.setCurrentPageAsCover:
        await _handleSetCoverWithFocus();
    }
  }

  Future<void> _toggleBookmark() async {
    final notice = await _controller().toggleBookmark();
    if (mounted && notice != null) {
      showTransientSnackBar(
        context,
        ComicTextResolver.readerNotice(AppLocalizations.of(context), notice),
      );
    }
  }

  /// 设当前页为封面：先落盘取本地文件，弹出焦点选区器让用户取景，再保存焦点。
  Future<void> _handleSetCoverWithFocus() async {
    final controller = _controller();
    final localPath = await controller.prepareCurrentImageForCover();
    if (localPath == null || localPath.trim().isEmpty || !mounted) {
      if (mounted) {
        showTransientSnackBar(
          context,
          AppLocalizations.of(context).comicCoverImageUnavailable,
        );
      }
      return;
    }
    final focus = await CoverFocalPointPicker.show(
      context,
      image: FileImage(io.File(localPath)),
      title: AppLocalizations.of(context).comicSetCoverFocus,
    );
    if (focus == null || !mounted) {
      // 取消选区则不改动封面。
      return;
    }
    final notice = await controller.setCurrentImageAsCover(
      focusX: focus.x,
      focusY: focus.y,
    );
    if (mounted && notice != null) {
      showTransientSnackBar(
        context,
        ComicTextResolver.readerNotice(AppLocalizations.of(context), notice),
      );
    }
  }

  /// “更多”动作走与三个点菜单相同的锚定菜单，顺序与状态按当前阅读态生成。
  List<ReaderToolbarMenuEntry> _buildMoreMenu(ComicReaderViewState viewState) {
    final l10n = AppLocalizations.of(context);
    return [
      ReaderToolbarMenuEntry(
        id: 'refresh-episode',
        icon: Icons.refresh,
        label: l10n.comicReaderRefreshEpisode,
        onSelected: () => unawaited(
          _handleReaderMoreAction(
            _ComicReaderMoreAction.refreshEpisode,
            viewState,
          ),
        ),
      ),
      ReaderToolbarMenuEntry(
        id: 'mark-read-toggle',
        icon: viewState.isCurrentEpisodeRead
            ? Icons.radio_button_unchecked
            : Icons.check_circle_outline,
        label: viewState.isCurrentEpisodeRead
            ? l10n.comicMarkEpisodeUnread
            : l10n.comicMarkEpisodeRead,
        onSelected: () => unawaited(
          _handleReaderMoreAction(
            _ComicReaderMoreAction.markReadToggle,
            viewState,
          ),
        ),
      ),
      ReaderToolbarMenuEntry(
        id: 'set-cover',
        icon: Icons.image_outlined,
        label: l10n.comicSetCurrentPageCover,
        onSelected: () => unawaited(
          _handleReaderMoreAction(
            _ComicReaderMoreAction.setCurrentPageAsCover,
            viewState,
          ),
        ),
      ),
    ];
  }

  Future<void> _showChapterListSheet(ComicReaderViewState viewState) async {
    final l10n = AppLocalizations.of(context);
    final preferences =
        ref.read(readerPreferencesControllerProvider).value ??
        ReaderPreferences.defaults();
    final panelPalette = ReaderPanelPalette.fromCanvas(
      canvasBackground: _readerBackgroundColor(preferences),
      baseTheme: Theme.of(context),
    );
    final selected = await showAdaptivePanel<ComicReaderChapterEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: panelPalette.panelSurface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: math.min(
              MediaQuery.sizeOf(context).height * 0.8,
              math.max(
                0,
                MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    MediaQuery.paddingOf(context).vertical,
              ),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final latest =
                    ref
                        .watch(comicReaderControllerProvider(_readerArgs))
                        .value ??
                    viewState;
                final bookmarked = latest.chapters
                    .where((chapter) => chapter.isBookmarked)
                    .toList(growable: false);
                return ReaderContentPanel(
                  palette: panelPalette,
                  bookmarks: [
                    for (final chapter in bookmarked)
                      ReaderBookmarkEntry(
                        id: chapter.episodeId,
                        rowKey: ValueKey<String>(
                          'comic-reader-bookmark-${chapter.episodeId}',
                        ),
                        deleteKey: ValueKey<String>(
                          'comic-reader-bookmark-delete-${chapter.episodeId}',
                        ),
                        title: ComicTextResolver.chapterTitle(
                          l10n,
                          chapter.title,
                          chapter.sourceTid,
                        ),
                        subtitle: chapter.isCurrent
                            ? l10n.comicCurrentChapter
                            : null,
                        isCurrent: chapter.isCurrent,
                        onTap: () => Navigator.of(context).pop(chapter),
                        onDelete: () => unawaited(
                          _controller().setEpisodeBookmarked(
                            chapter.episodeId,
                            false,
                          ),
                        ),
                      ),
                  ],
                  catalogBuilder: (context) =>
                      LibraryChapterBrowser<ComicReaderChapterEntry>(
                        workId: latest.comicId,
                        keyPrefix: 'comic-reader-chapter',
                        currentId: latest.episodeId,
                        itemExtent: math.max(
                          64,
                          MediaQuery.textScalerOf(context).scale(16) * 1.5 + 24,
                        ),
                        entries: [
                          for (final chapter in latest.chapters)
                            ChapterSearchEntry(
                              id: chapter.episodeId,
                              title: chapter.title,
                              aliases: [
                                if (chapter.sourceTitle != null)
                                  chapter.sourceTitle!,
                              ],
                              metadata: [chapter.sourceTid],
                              value: chapter,
                            ),
                        ],
                        rowBuilder: (context, chapter, confirmSearch) =>
                            _ComicReaderCatalogRow(
                              chapter: chapter,
                              panelPalette: panelPalette,
                              onTap: () {
                                confirmSearch();
                                Navigator.of(context).pop(chapter);
                              },
                              onToggleRead: () => _controller().setEpisodeRead(
                                chapter.episodeId,
                                !chapter.isRead,
                              ),
                              onLongPress: () => _showChapterRowActions(
                                context,
                                chapter,
                                panelPalette,
                              ),
                            ),
                      ),
                );
              },
            ),
          ),
        ),
      ),
    );
    if (selected == null || selected.isCurrent || !mounted) {
      return;
    }
    await _controller().openEpisode(
      episodeId: selected.episodeId,
      policy: ComicEpisodeOpenPolicy.startAtBeginning,
    );
  }

  Future<void> _showChapterRowActions(
    BuildContext sheetContext,
    ComicReaderChapterEntry chapter,
    ReaderPanelPalette panelPalette,
  ) async {
    final l10n = AppLocalizations.of(sheetContext);
    await showAdaptivePanel<void>(
      context: sheetContext,
      backgroundColor: panelPalette.panelSurface,
      builder: (context) => ReaderPanelTheme(
        palette: panelPalette,
        child: Material(
          color: panelPalette.panelSurface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppGroupedSection(
                margin: EdgeInsets.zero,
                children: [
                  AppGroupedRow(
                    leading: Icon(
                      chapter.isRead ? Icons.remove_done : Icons.done,
                    ),
                    title: chapter.isRead
                        ? l10n.libraryChapterClearReadState
                        : l10n.libraryChapterMarkRead,
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(
                        _controller().setEpisodeRead(
                          chapter.episodeId,
                          !chapter.isRead,
                        ),
                      );
                    },
                  ),
                  AppGroupedRow(
                    leading: Icon(
                      chapter.isBookmarked
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined,
                    ),
                    title: chapter.isBookmarked
                        ? l10n.comicBookmarkRemove
                        : l10n.comicBookmarkAdd,
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(
                        _controller().setEpisodeBookmarked(
                          chapter.episodeId,
                          !chapter.isBookmarked,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicReaderCatalogRow extends StatelessWidget {
  const _ComicReaderCatalogRow({
    required this.chapter,
    required this.panelPalette,
    required this.onTap,
    required this.onToggleRead,
    required this.onLongPress,
  });

  final ComicReaderChapterEntry chapter;
  final ReaderPanelPalette panelPalette;
  final VoidCallback onTap;
  final Future<void> Function() onToggleRead;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = chapter.isRead
        ? scheme.onSecondaryContainer
        : scheme.onPrimaryContainer;
    return LibraryChapterReadStateSwipe(
      key: Key('comic-reader-chapter-read-swipe-${chapter.episodeId}'),
      foregroundKey: Key(
        'comic-reader-chapter-read-swipe-foreground-${chapter.episodeId}',
      ),
      locked: false,
      onTriggered: onToggleRead,
      background: ColoredBox(
        color: chapter.isRead
            ? scheme.secondaryContainer
            : scheme.primaryContainer,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  chapter.isRead ? Icons.remove_done : Icons.done,
                  size: 20,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      chapter.isRead
                          ? l10n.libraryChapterClearReadState
                          : l10n.libraryChapterMarkRead,
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Material(
        color: panelPalette.cardSurface,
        child: ListTile(
          key: ValueKey<String>('comic-reader-chapter-${chapter.episodeId}'),
          selected: chapter.isCurrent,
          leading: Icon(
            chapter.isBookmarked
                ? Icons.bookmark
                : chapter.isRead
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            color: chapter.isBookmarked ? scheme.primary : null,
          ),
          title: Text(
            ComicTextResolver.chapterTitle(
              l10n,
              chapter.title,
              chapter.sourceTid,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: chapter.isCurrent ? Text(l10n.comicCurrentChapter) : null,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}

class _ComicReaderSwitchOverlay extends StatelessWidget {
  const _ComicReaderSwitchOverlay({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    final onDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    return AbsorbPointer(
      child: ColoredBox(
        color: background,
        child: Center(
          child: CircularProgressIndicator(
            color: onDark ? Colors.white70 : null,
          ),
        ),
      ),
    );
  }
}

/// 垂直模式列表尾部的"下一章过场卡"。只展示已加载的章节元数据；图片列表和
/// owner session 均在用户确认切换后创建。
class _ReaderNextChapterTransition extends StatelessWidget {
  const _ReaderNextChapterTransition({
    required this.nextChapter,
    required this.isSwitchingEpisode,
    required this.onOpenNext,
  });

  final ComicReaderChapterEntry? nextChapter;
  final bool isSwitchingEpisode;
  final VoidCallback onOpenNext;

  @override
  Widget build(BuildContext context) {
    final chapter = nextChapter;
    if (chapter == null) {
      return const SizedBox.shrink(
        key: Key('comic-reader-next-chapter-transition-empty'),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chromePalette = const ReaderChromePaletteResolver().resolve(theme);
    final canOpen = !isSwitchingEpisode;
    return Padding(
      key: const Key('comic-reader-next-chapter-transition'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Material(
        color: chromePalette.transitionCardBackground,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const Key('comic-reader-next-chapter-transition-button'),
          borderRadius: BorderRadius.circular(8),
          onTap: canOpen ? onOpenNext : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.skip_next, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context).comicNextChapterTitle(
                          ComicTextResolver.chapterTitle(
                            AppLocalizations.of(context),
                            chapter.title,
                            chapter.sourceTid,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isSwitchingEpisode
                            ? AppLocalizations.of(context).comicSwitchingEpisode
                            : AppLocalizations.of(context).comicOpenNextEpisode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isSwitchingEpisode)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: canOpen ? scheme.primary : scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 章节打开中的占位：短暂延迟后再显示文案，避免一闪而过的页级占位。
class _ReaderOpeningPlaceholder extends StatefulWidget {
  const _ReaderOpeningPlaceholder({required this.background});

  final Color background;

  @override
  State<_ReaderOpeningPlaceholder> createState() =>
      _ReaderOpeningPlaceholderState();
}

class _ReaderOpeningPlaceholderState extends State<_ReaderOpeningPlaceholder> {
  static const Duration _revealDelay = Duration(milliseconds: 160);

  Timer? _timer;
  bool _showCopy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_revealDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _showCopy = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onDark =
        ThemeData.estimateBrightnessForColor(widget.background) ==
        Brightness.dark;
    return ColoredBox(
      key: const Key('comic-reader-page-opening'),
      color: widget.background,
      child: Center(
        child: _showCopy
            ? Text(
                AppLocalizations.of(context).comicOpeningEpisode,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: onDark ? Colors.white70 : null),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
