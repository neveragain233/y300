import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:y300/app/eink/eink_epdc_channel.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../domain/models/thread_controls_preferences.dart';
import '../services/thread_floor_navigation_coordinator.dart';

class ThreadFloatingControls extends StatefulWidget {
  const ThreadFloatingControls({
    super.key,
    required this.preferences,
    required this.navigation,
    required this.visibility,
    required this.favorite,
    required this.reply,
    required this.jumpPage,
    required this.more,
    required this.onFirstPost,
    required this.onHeightChanged,
    this.hasContent = true,
    this.horizontalSafeInsets = EdgeInsets.zero,
  });
  final ThreadControlsPreferences preferences;
  final ThreadFloorNavigationCoordinator navigation;
  final ValueListenable<bool> visibility;
  final Widget? favorite;
  final VoidCallback? reply;
  final Widget jumpPage;
  final Widget more;
  final VoidCallback onFirstPost;
  final ValueChanged<double> onHeightChanged;
  final bool hasContent;

  /// FAB 子树移除了系统安全区内边距，横向避让由页面传入后在这里补齐。
  final EdgeInsets horizontalSafeInsets;
  @override
  State<ThreadFloatingControls> createState() => _ThreadFloatingControlsState();
}

class _ThreadFloatingControlsState extends State<ThreadFloatingControls> {
  final _measureKey = GlobalKey();
  double? _height;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _measureKey.currentContext?.size?.height;
      if (height != null && height != _height) {
        _height = height;
        widget.onHeightChanged(height);
      }
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preferences = widget.preferences;
    final compact = preferences.compact;
    final color =
        theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainerHigh;
    final foreground = theme.colorScheme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final showFavorite =
        widget.favorite != null && (!compact || preferences.showFavorite);
    final actionCount =
        2 + (showFavorite ? 1 : 0) + (widget.reply != null ? 1 : 0);
    final mainWidth = 8.0 + actionCount * 48 + (actionCount - 1) * 8;
    final navWidth = (preferences.singleNavigationButton ? 48.0 : 104.0) + 8;
    final main = _surface(
      color,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFavorite) ...[widget.favorite!, const SizedBox(width: 8)],
          if (widget.reply != null) ...[
            IconButton(
              key: const Key('thread-detail-appbar-reply-button'),
              tooltip: l10n.threadDetailReplyPost,
              onPressed: widget.reply,
              icon: const Icon(Icons.reply),
            ),
            const SizedBox(width: 8),
          ],
          widget.jumpPage,
          const SizedBox(width: 8),
          widget.more,
        ],
      ),
    );
    final nav = AnimatedBuilder(
      animation: widget.navigation,
      builder: (context, _) {
        final singleEnabled = widget.hasContent && widget.navigation.canAdvance;
        final atEnd = widget.navigation.atEnd;
        final singleLabel = atEnd
            ? l10n.threadControlsFirstPost
            : widget.navigation.forward
            ? l10n.threadControlsNextPost
            : l10n.threadControlsPreviousPost;
        void firstPost() {
          widget.navigation.resetDirection();
          widget.onFirstPost();
        }

        Widget button(bool forward) {
          // 已确认全帖末端时，向下键与单键一样转为返回主题正文，图标、
          // 读屏名称和执行动作共用同一状态。
          final endAction = forward && atEnd;
          final label = endAction
              ? l10n.threadControlsFirstPost
              : forward
              ? l10n.threadControlsNextPost
              : l10n.threadControlsPreviousPost;
          return IconButton(
            key: Key(
              forward
                  ? 'thread-next-post-button'
                  : 'thread-previous-post-button',
            ),
            tooltip: label,
            onPressed: widget.hasContent && widget.navigation.canMove(forward)
                ? () => widget.navigation.move(
                    forward,
                    animate: !MediaQuery.disableAnimationsOf(context),
                  )
                : null,
            icon: Icon(
              endAction
                  ? Icons.vertical_align_top
                  : forward
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              semanticLabel: label,
            ),
          );
        }

        return _surface(
          color,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: preferences.singleNavigationButton
                ? [
                    Tooltip(
                      message: singleLabel,
                      excludeFromSemantics: true,
                      triggerMode: TooltipTriggerMode.manual,
                      child: TextButton(
                        key: const Key('thread-single-navigation-button'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          fixedSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: singleEnabled
                            ? atEnd
                                  ? firstPost
                                  : () => widget.navigation.advance(
                                      animate: !MediaQuery.disableAnimationsOf(
                                        context,
                                      ),
                                    )
                            : null,
                        onLongPress: !singleEnabled || atEnd
                            ? null
                            : preferences.holdToFirstPost
                            ? firstPost
                            : widget.navigation.reverseDirection,
                        child: Icon(
                          atEnd
                              ? Icons.vertical_align_top
                              : widget.navigation.forward
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          size: 32,
                          semanticLabel: singleLabel,
                        ),
                      ),
                    ),
                  ]
                : [button(false), const SizedBox(width: 8), button(true)],
          ),
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // 系统配置切换的预热帧可能暂时没有可用宽度。
        if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 24) {
          return const SizedBox.shrink();
        }
        const margin = 16.0;
        final leftInset =
            math.max(0.0, widget.horizontalSafeInsets.left) + margin;
        final rightInset =
            math.max(0.0, widget.horizontalSafeInsets.right) + margin;
        final usableWidth = math.max(
          0.0,
          constraints.maxWidth - leftInset - rightInset,
        );
        final navigationEnabled =
            !EInkModeScope.of(context) &&
            preferences.navigationEnabled &&
            widget.hasContent;
        // 非紧凑主栏居中，只有整条栏本身放得下、且不与右侧导航重叠时才并排。
        final inline =
            !navigationEnabled ||
            (compact
                ? mainWidth + navWidth + 12 <= usableWidth
                : mainWidth + 2 * (navWidth + 12) <= usableWidth);
        final mainAlignment = !compact
            ? Alignment.center
            : preferences.side == ThreadControlsSide.right
            ? Alignment.centerRight
            : Alignment.centerLeft;
        final mainControl = SizedBox(width: mainWidth, child: main);
        final controls = SizedBox(
          key: _measureKey,
          width: constraints.maxWidth,
          child: Padding(
            padding: EdgeInsets.only(left: leftInset, right: rightInset),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  fixedSize: const Size(48, 48),
                  foregroundColor: foreground,
                ),
              ),
              child: !navigationEnabled
                  ? Align(
                      alignment: mainAlignment,
                      heightFactor: 1,
                      child: mainControl,
                    )
                  : inline
                  ? _inlineControls(
                      compact: compact,
                      side: preferences.side,
                      mainAlignment: mainAlignment,
                      mainControl: mainControl,
                      nav: nav,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          heightFactor: 1,
                          child: nav,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: mainAlignment,
                          heightFactor: 1,
                          child: mainControl,
                        ),
                      ],
                    ),
            ),
          ),
        );
        return ValueListenableBuilder<bool>(
          valueListenable: widget.visibility,
          builder: (context, shown, _) {
            final visible =
                (!preferences.hideOnScroll || shown) &&
                MediaQuery.viewInsetsOf(context).bottom == 0;
            final duration = MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160);
            return ExcludeFocus(
              excluding: !visible,
              child: ExcludeSemantics(
                excluding: !visible,
                child: IgnorePointer(
                  key: const Key('thread-floating-controls-pointer-gate'),
                  ignoring: !visible,
                  child: AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(0, 1.6),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: duration,
                      child: controls,
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

  Widget _inlineControls({
    required bool compact,
    required ThreadControlsSide side,
    required AlignmentGeometry mainAlignment,
    required Widget mainControl,
    required Widget nav,
  }) {
    // 单键导航始终贴视口右缘；紧凑主栏按停靠侧靠在它左边。
    if (!compact) {
      return Stack(
        children: [
          Align(alignment: mainAlignment, heightFactor: 1, child: mainControl),
          Align(alignment: Alignment.centerRight, heightFactor: 1, child: nav),
        ],
      );
    }
    if (side == ThreadControlsSide.right) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [mainControl, const SizedBox(width: 12), nav],
      );
    }
    return Row(children: [mainControl, const Spacer(), nav]);
  }

  Widget _surface(Color color, Widget child) => Material(
    color: color,
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: .18),
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(4), child: child),
  );
}
