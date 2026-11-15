import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/presentation/services/library_detail_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';

class UnifiedDetailChapterTile extends StatelessWidget {
  const UnifiedDetailChapterTile({
    super.key,
    required this.tileKey,
    required this.chapter,
    required this.subtitle,
    required this.isDownloading,
    required this.downloadIconSize,
    required this.onTap,
    required this.onLongPress,
    this.onToggleDownload,
    this.onToggleReadState,
    this.onMarkReadThrough,
    this.readStateMutationLocked = false,
  });

  final Key tileKey;
  final LibraryChapterItem chapter;
  final String subtitle;
  final bool isDownloading;
  final double downloadIconSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onToggleDownload;
  final Future<void> Function()? onToggleReadState;

  /// 第二阶段右划：把本章及之前章节标为已读。为空时只保留单章动作。
  final Future<void> Function()? onMarkReadThrough;
  final bool readStateMutationLocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = chapter.isRead
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    final subtitleColor = chapter.isRead
        ? scheme.onSurfaceVariant.withAlpha(170)
        : scheme.onSurfaceVariant;

    final tile = Material(
      key: tileKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (chapter.isBookmarked) ...[
                          Icon(
                            Icons.bookmark,
                            key: ValueKey<String>(
                              'unified-detail-chapter-bookmark-indicator-${chapter.episodeId}',
                            ),
                            size: 20,
                            color: scheme.primary,
                            semanticLabel: l10n.libraryChapterBookmarkSemantics,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            LibraryDetailTextResolver.chapterTitle(
                              l10n,
                              chapter.title,
                              chapter.sourceTid,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ChapterSubtitle(
                      subtitle,
                      episodeId: chapter.episodeId,
                      progress: chapter.progressInfo,
                      isRead: chapter.isRead,
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                          ) ??
                          TextStyle(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              if (onToggleDownload != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isDownloading
                      ? l10n.libraryChapterDownloading
                      : chapter.isDownloaded
                      ? l10n.libraryChapterDownloadedDelete
                      : l10n.libraryChapterDownload,
                  iconSize: downloadIconSize,
                  color: theme.y300NativeContent.soft,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: isDownloading ? null : onToggleDownload,
                  icon: isDownloading
                      ? SizedBox(
                          width: downloadIconSize,
                          height: downloadIconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: theme.y300NativeContent.soft,
                          ),
                        )
                      : Icon(
                          chapter.isDownloaded
                              ? Icons.offline_pin
                              : Icons.offline_pin_outlined,
                          size: downloadIconSize,
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final toggleReadState = onToggleReadState;
    if (toggleReadState == null) {
      return tile;
    }
    final actionLabel = chapter.isRead
        ? l10n.libraryChapterClearReadState
        : l10n.libraryChapterMarkRead;
    final actionIcon = chapter.isRead ? Icons.remove_done : Icons.done;
    final backgroundColor = chapter.isRead
        ? scheme.secondaryContainer
        : scheme.primaryContainer;
    final foregroundColor = chapter.isRead
        ? scheme.onSecondaryContainer
        : scheme.onPrimaryContainer;
    final markReadThrough = onMarkReadThrough;

    return LibraryChapterReadStateSwipe(
      key: ValueKey<String>(
        'unified-detail-chapter-read-swipe-${chapter.episodeId}',
      ),
      foregroundKey: ValueKey<String>(
        'unified-detail-chapter-read-swipe-foreground-${chapter.episodeId}',
      ),
      locked: readStateMutationLocked,
      onTriggered: toggleReadState,
      onTriggeredThrough: markReadThrough,
      background: _ChapterSwipeActionBackground(
        icon: actionIcon,
        label: actionLabel,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      backgroundThrough: markReadThrough == null
          ? null
          : _ChapterSwipeActionBackground(
              icon: Icons.done_all,
              label: l10n.libraryChapterMarkReadThrough,
              backgroundColor: scheme.tertiaryContainer,
              foregroundColor: scheme.onTertiaryContainer,
            ),
      child: tile,
    );
  }
}

class _ChapterSwipeActionBackground extends StatelessWidget {
  const _ChapterSwipeActionBackground({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: backgroundColor,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared bounded physical-right swipe for chapter completion actions.
///
/// 单章动作位于第一阶段；实现“已读到此”的页面再提供第二阶段回调。手动位移
/// 只做预览，松手时按当前所在阶段执行一次，退回第一阶段不改变单章动作。
class LibraryChapterReadStateSwipe extends StatefulWidget {
  const LibraryChapterReadStateSwipe({
    super.key,
    required this.foregroundKey,
    required this.locked,
    required this.onTriggered,
    required this.background,
    required this.child,
    this.onTriggeredThrough,
    this.backgroundThrough,
  });

  final Key foregroundKey;
  final bool locked;

  /// 第一阶段动作：单章标已读或清除阅读状态。
  final Future<void> Function() onTriggered;

  /// 第二阶段动作：把目标章及之前章节标为已读。为空时保留单阶段行为。
  final Future<void> Function()? onTriggeredThrough;

  final Widget background;
  final Widget? backgroundThrough;
  final Widget child;

  @override
  State<LibraryChapterReadStateSwipe> createState() =>
      _LibraryChapterReadStateSwipeState();
}

class _LibraryChapterReadStateSwipeState
    extends State<LibraryChapterReadStateSwipe>
    with SingleTickerProviderStateMixin {
  static const double _singleStageMaxFraction = 1 / 3;
  static const double _singleStageActivationFraction =
      _singleStageMaxFraction * 0.8;
  static const double _twoStageMaxFraction = 0.55;
  static const double _stageOneFraction = 0.27;
  static const double _stageTwoFraction = 0.45;

  late final AnimationController _returnController;
  Animation<double>? _returnAnimation;
  double _dragFraction = 0;
  bool _isExecuting = false;
  bool _stageOneHapticSent = false;
  bool _stageTwoHapticSent = false;

  bool get _supportsThroughStage => widget.onTriggeredThrough != null;

  double get _maxDragFraction =>
      _supportsThroughStage ? _twoStageMaxFraction : _singleStageMaxFraction;

  double get _activationFraction => _supportsThroughStage
      ? _stageOneFraction
      : _singleStageActivationFraction;

  double get _visibleFraction => _returnAnimation?.value ?? _dragFraction;

  bool get _interactionLocked =>
      widget.locked || _isExecuting || _returnController.isAnimating;

  @override
  void initState() {
    super.initState();
    _returnController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed || !mounted) {
            return;
          }
          setState(() {
            _dragFraction = 0;
            _returnAnimation = null;
          });
        });
  }

  @override
  void dispose() {
    _returnController.dispose();
    super.dispose();
  }

  void _startDrag(DragStartDetails details) {
    _stageOneHapticSent = false;
    _stageTwoHapticSent = false;
  }

  void _updateDrag(DragUpdateDetails details, double width) {
    if (_interactionLocked || width <= 0) {
      return;
    }
    final previous = _dragFraction;
    final next = (previous + details.delta.dx / width)
        .clamp(0, _maxDragFraction)
        .toDouble();
    if (next == previous) {
      return;
    }
    setState(() {
      _dragFraction = next;
    });
    if (!_supportsThroughStage) {
      return;
    }
    if (previous < _stageOneFraction &&
        next >= _stageOneFraction &&
        !_stageOneHapticSent) {
      _stageOneHapticSent = true;
      HapticFeedback.lightImpact();
    }
    if (previous < _stageTwoFraction &&
        next >= _stageTwoFraction &&
        !_stageTwoHapticSent) {
      _stageTwoHapticSent = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _finishDrag({required bool allowTrigger}) {
    if (_interactionLocked) {
      return;
    }
    final fraction = _dragFraction;
    _startReturnAnimation();
    if (!allowTrigger) {
      return;
    }
    if (_supportsThroughStage && fraction >= _stageTwoFraction) {
      _executeAction(widget.onTriggeredThrough!);
    } else if (fraction >= _activationFraction) {
      _executeAction(widget.onTriggered);
    }
  }

  void _startReturnAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _dragFraction = 0;
        _returnAnimation = null;
      });
      return;
    }
    _returnAnimation = Tween<double>(begin: _dragFraction, end: 0).animate(
      CurvedAnimation(parent: _returnController, curve: Curves.easeOutCubic),
    );
    _returnController.forward(from: 0);
  }

  Future<void> _executeAction(Future<void> Function() action) async {
    setState(() {
      _isExecuting = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _returnController,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final revealWidth = width.isFinite
                ? width * _visibleFraction
                : 0.0;
            final throughStage =
                _supportsThroughStage && _visibleFraction >= _stageTwoFraction;
            final background = throughStage
                ? (widget.backgroundThrough ?? widget.background)
                : widget.background;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _startDrag,
              onHorizontalDragUpdate: (details) => _updateDrag(details, width),
              onHorizontalDragEnd: (_) => _finishDrag(allowTrigger: true),
              onHorizontalDragCancel: () => _finishDrag(allowTrigger: false),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    if (revealWidth > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: revealWidth,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: width * _maxDragFraction,
                            maxWidth: width * _maxDragFraction,
                            child: SizedBox(
                              width: width * _maxDragFraction,
                              child: background,
                            ),
                          ),
                        ),
                      ),
                    FractionalTranslation(
                      key: widget.foregroundKey,
                      translation: Offset(_visibleFraction, 0),
                      child: child!,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: widget.child,
    );
  }
}

class _ChapterSubtitle extends StatelessWidget {
  const _ChapterSubtitle(
    this.subtitle, {
    required this.episodeId,
    required this.progress,
    required this.isRead,
    required this.style,
  });

  final String episodeId;
  final String subtitle;
  final LibraryChapterProgressInfo? progress;
  final bool isRead;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metadata = subtitle.trim();
    final progressLabel = progress == null
        ? ''
        : LibraryDetailTextResolver.chapterProgress(
            l10n,
            progress!,
            isRead: isRead,
          );
    if (progressLabel.isEmpty) {
      return Text(
        metadata,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final progressStyle = style.copyWith(
      color: (style.color ?? Theme.of(context).colorScheme.onSurfaceVariant)
          .withAlpha(150),
    );
    final text = RichText(
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          if (metadata.isNotEmpty) ...[
            TextSpan(text: metadata),
            const TextSpan(text: '  ·  '),
          ],
          TextSpan(text: progressLabel, style: progressStyle),
        ],
      ),
    );
    return Semantics(
      key: ValueKey<String>(
        'unified-detail-chapter-inline-progress-$episodeId',
      ),
      label: metadata.isEmpty
          ? progressLabel
          : l10n.libraryChapterProgressSemantics(metadata, progressLabel),
      child: ExcludeSemantics(child: text),
    );
  }
}
