import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
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
        final singleLabel = widget.navigation.atEnd
            ? l10n.threadControlsFirstPost
            : widget.navigation.forward
            ? l10n.threadControlsNextPost
            : l10n.threadControlsPreviousPost;
        void firstPost() {
          widget.navigation.resetDirection();
          widget.onFirstPost();
        }

        Widget button(bool forward) => IconButton(
          key: Key(
            forward ? 'thread-next-post-button' : 'thread-previous-post-button',
          ),
          tooltip: forward
              ? l10n.threadControlsNextPost
              : l10n.threadControlsPreviousPost,
          onPressed: widget.hasContent && widget.navigation.canMove(forward)
              ? () => widget.navigation.move(
                  forward,
                  animate: !MediaQuery.disableAnimationsOf(context),
                )
              : null,
          icon: Icon(
            forward ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
          ),
        );
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
                            ? widget.navigation.atEnd
                                  ? firstPost
                                  : () => widget.navigation.advance(
                                      animate: !MediaQuery.disableAnimationsOf(
                                        context,
                                      ),
                                    )
                            : null,
                        onLongPress: !singleEnabled || widget.navigation.atEnd
                            ? null
                            : preferences.holdToFirstPost
                            ? firstPost
                            : widget.navigation.reverseDirection,
                        child: Icon(
                          widget.navigation.atEnd
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
        final width = math.min(720.0, constraints.maxWidth - 24);
        final navigationEnabled =
            preferences.navigationEnabled && widget.hasContent;
        final inline = !navigationEnabled || mainWidth + navWidth + 12 <= width;
        final mainControl = SizedBox(width: mainWidth, child: main);
        final controls = SizedBox(
          key: _measureKey,
          width: width,
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                fixedSize: const Size(48, 48),
                foregroundColor: foreground,
              ),
            ),
            child: inline
                ? Row(
                    mainAxisAlignment: !compact
                        ? MainAxisAlignment.spaceBetween
                        : preferences.side == ThreadControlsSide.right
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (navigationEnabled &&
                          compact &&
                          preferences.side == ThreadControlsSide.right) ...[
                        nav,
                        const SizedBox(width: 12),
                      ],
                      mainControl,
                      if (navigationEnabled &&
                          (!compact ||
                              preferences.side == ThreadControlsSide.left)) ...[
                        const SizedBox(width: 12),
                        nav,
                      ],
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        preferences.side == ThreadControlsSide.left
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [nav, const SizedBox(height: 12), mainControl],
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

  Widget _surface(Color color, Widget child) => Material(
    color: color,
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: .18),
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(4), child: child),
  );
}
