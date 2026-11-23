import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

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
    final reduceMotion = AppMotion.reduceMotion(context);
    final replyExtra = !compact && widget.reply != null ? 64.0 : 0.0;
    final mainWidth =
        8.0 + actionCount * 48 + (actionCount - 1) * 8 + replyExtra;
    final navWidth = (preferences.singleNavigationButton ? 48.0 : 104.0) + 8;
    final main = _surface(
      context,
      color,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact && showFavorite) ...[
            widget.favorite!,
            const SizedBox(width: 8),
          ],
          if (widget.reply != null) ...[
            if (!compact)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    key: const Key('thread-detail-appbar-reply-button'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: theme.colorScheme.surface,
                      splashFactory: NoSplash.splashFactory,
                      side: EInkModeScope.of(context)
                          ? BorderSide(
                              color: AppTheme.eInkBorderColor(theme.brightness),
                            )
                          : null,
                      animationDuration: Duration.zero,
                    ),
                    onPressed: widget.reply,
                    icon: const Icon(Icons.reply),
                    label: Text(
                      l10n.threadDetailReply,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                key: const Key('thread-detail-appbar-reply-button'),
                tooltip: l10n.threadDetailReplyPost,
                onPressed: widget.reply,
                icon: const Icon(Icons.reply),
              ),
            const SizedBox(width: 8),
          ],
          if (!compact && showFavorite) ...[
            widget.favorite!,
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
                ? () => widget.navigation.move(forward, animate: !reduceMotion)
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
          context,
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
                        style:
                            TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              fixedSize: const Size(48, 48),
                              padding: EdgeInsets.zero,
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: Colors.transparent,
                              animationDuration: Duration.zero,
                            ).copyWith(
                              backgroundColor: reduceMotion
                                  ? WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.pressed)
                                          ? foreground.withValues(alpha: .10)
                                          : Colors.transparent,
                                    )
                                  : const WidgetStatePropertyAll(
                                      Colors.transparent,
                                    ),
                            ),
                        onPressed: singleEnabled
                            ? atEnd
                                  ? firstPost
                                  : () => widget.navigation.advance(
                                      animate: !reduceMotion,
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
            (!compact || !EInkModeScope.of(context)) &&
            preferences.navigationEnabled &&
            widget.hasContent;
        final inline =
            !navigationEnabled ||
            mainWidth - replyExtra / 2 + navWidth + 12 <= usableWidth;
        final mainAlignment = !compact
            ? Alignment.center
            : preferences.side == ThreadControlsSide.right
            ? Alignment.centerRight
            : Alignment.centerLeft;
        final minWidth = mainWidth - replyExtra;
        final mainControl = usableWidth < minWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: mainWidth, child: main),
              )
            : SizedBox(width: math.min(mainWidth, usableWidth), child: main);
        final controls = SizedBox(
          key: _measureKey,
          width: constraints.maxWidth,
          child: Padding(
            padding: EdgeInsets.only(left: leftInset, right: rightInset),
            child: Theme(
              data: theme.copyWith(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
              ),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style:
                      IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        fixedSize: const Size(48, 48),
                        foregroundColor: foreground,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: Colors.transparent,
                        animationDuration: Duration.zero,
                      ).copyWith(
                        backgroundColor: reduceMotion
                            ? WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.pressed)
                                    ? foreground.withValues(alpha: .10)
                                    : Colors.transparent,
                              )
                            : const WidgetStatePropertyAll(Colors.transparent),
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
          ),
        );
        return ValueListenableBuilder<bool>(
          valueListenable: widget.visibility,
          builder: (context, shown, _) {
            final visible =
                (!preferences.hideOnScroll || shown) &&
                MediaQuery.viewInsetsOf(context).bottom == 0;
            final duration = AppMotion.duration(
              context,
              const Duration(milliseconds: 160),
            );
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
    required Widget mainControl,
    required Widget nav,
  }) {
    // 单键导航始终贴视口右缘；紧凑主栏按停靠侧靠在它左边。
    if (!compact) {
      return Row(
        children: [
          Expanded(child: mainControl),
          const SizedBox(width: 12),
          nav,
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

  Widget _surface(BuildContext context, Color color, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    final eInk = EInkModeScope.of(context);
    final reduceMotion = AppMotion.reduceMotion(context);
    final inner = Padding(padding: const EdgeInsets.all(4), child: child);
    final pill = AppGlassSurface(
      borderRadius: 28,
      level: eInk ? AppGlassLevel.off : null,
      baseColor: eInk ? scheme.surface : color,
      child: inner,
    );
    return reduceMotion ? pill : ElasticPress(child: pill);
  }
}
