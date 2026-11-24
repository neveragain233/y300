import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_theme.dart';
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
    this.onRightStackHeightChanged,
    this.currentPage = 1,
    this.totalPages,
    this.onJumpPage,
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
  final ValueChanged<double>? onRightStackHeightChanged;
  final int currentPage;
  final int? totalPages;
  final VoidCallback? onJumpPage;
  final bool hasContent;

  /// FAB 子树移除了系统安全区内边距，横向避让由页面传入后在这里补齐。
  final EdgeInsets horizontalSafeInsets;

  @override
  State<ThreadFloatingControls> createState() => _ThreadFloatingControlsState();
}

class _ThreadFloatingControlsState extends State<ThreadFloatingControls> {
  final _measureKey = GlobalKey();
  final _mainMeasureKey = GlobalKey();
  double? _height;
  double? _rightStackHeight;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mainHeight = _mainMeasureKey.currentContext?.size?.height;
      final totalHeight = _measureKey.currentContext?.size?.height;
      final effectiveMainHeight = mainHeight ?? totalHeight;
      if (effectiveMainHeight != null && effectiveMainHeight != _height) {
        _height = effectiveMainHeight;
        widget.onHeightChanged(effectiveMainHeight);
      }
      if (totalHeight != null && totalHeight != _rightStackHeight) {
        _rightStackHeight = totalHeight;
        widget.onRightStackHeightChanged?.call(totalHeight);
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
    final reduceMotion = AppMotion.reduceMotion(context);

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

        final Widget body;
        if (compact) {
          body = _buildCompactBody(
            context,
            l10n: l10n,
            theme: theme,
            preferences: preferences,
            color: color,
            foreground: foreground,
            showFavorite: showFavorite,
            reduceMotion: reduceMotion,
            usableWidth: usableWidth,
            navigationEnabled: navigationEnabled,
          );
        } else {
          body = _buildFullBody(
            context,
            l10n: l10n,
            theme: theme,
            preferences: preferences,
            color: color,
            foreground: foreground,
            showFavorite: showFavorite,
            reduceMotion: reduceMotion,
            usableWidth: usableWidth,
            navigationEnabled: navigationEnabled,
          );
        }

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
                child: body,
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

  Widget _buildCompactBody(
    BuildContext context, {
    required AppLocalizations l10n,
    required ThemeData theme,
    required ThreadControlsPreferences preferences,
    required Color color,
    required Color foreground,
    required bool showFavorite,
    required bool reduceMotion,
    required double usableWidth,
    required bool navigationEnabled,
  }) {
    final actionCount =
        2 + (showFavorite ? 1 : 0) + (widget.reply != null ? 1 : 0);
    final mainWidth = 8.0 + actionCount * 48 + (actionCount - 1) * 8;
    final navWidth = (preferences.singleNavigationButton ? 48.0 : 104.0) + 8;
    final main = KeyedSubtree(
      key: _mainMeasureKey,
      child: _surface(
        context,
        color,
        borderRadius: 28,
        padding: const EdgeInsets.all(4),
        child: Row(
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
      ),
    );
    final nav = _buildNavigationPill(
      context,
      l10n: l10n,
      preferences: preferences,
      color: color,
      foreground: foreground,
      reduceMotion: reduceMotion,
      verticalDouble: false,
    );
    final inline =
        !navigationEnabled || mainWidth + navWidth + 12 <= usableWidth;
    final mainAlignment = preferences.side == ThreadControlsSide.right
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final mainControl = usableWidth < mainWidth
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: mainWidth, child: main),
          )
        : SizedBox(width: math.min(mainWidth, usableWidth), child: main);
    if (!navigationEnabled) {
      return Align(
        alignment: mainAlignment,
        heightFactor: 1,
        child: mainControl,
      );
    }
    if (inline) {
      if (preferences.side == ThreadControlsSide.right) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [mainControl, const SizedBox(width: 12), nav],
        );
      }
      return Row(children: [mainControl, const Spacer(), nav]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, heightFactor: 1, child: nav),
        const SizedBox(height: 12),
        Align(alignment: mainAlignment, heightFactor: 1, child: mainControl),
      ],
    );
  }

  Widget _buildFullBody(
    BuildContext context, {
    required AppLocalizations l10n,
    required ThemeData theme,
    required ThreadControlsPreferences preferences,
    required Color color,
    required Color foreground,
    required bool showFavorite,
    required bool reduceMotion,
    required double usableWidth,
    required bool navigationEnabled,
  }) {
    final fullBarWidth = math.min(AppLayoutTokens.readingMaxWidth, usableWidth);
    final eInk = EInkModeScope.of(context);
    final scheme = theme.colorScheme;
    final canReply = widget.reply != null;
    final isBrowseOnly = !canReply && widget.hasContent;
    final actionWidgets = <Widget>[
      if (showFavorite) widget.favorite!,
      if (canReply) widget.jumpPage,
      widget.more,
    ];
    final minBarWidth = 12.0 + 48.0 + actionWidgets.length * 48.0;

    final Widget slot;
    if (canReply) {
      slot = _FullBarSlot(
        buttonKey: const Key('thread-detail-appbar-reply-button'),
        semanticsLabel: l10n.threadDetailReplyPost,
        icon: Icons.edit_outlined,
        label: l10n.threadControlsReplyPrompt,
        onTap: widget.reply,
        foreground: foreground,
        eInk: eInk,
        scheme: scheme,
        textStyle: theme.textTheme.bodyMedium,
      );
    } else if (isBrowseOnly) {
      final page = math.max(1, widget.currentPage);
      final total = widget.totalPages;
      final pageLabel = total == null
          ? l10n.threadControlsPageUnknown(page)
          : l10n.threadControlsPageSummary(page, math.max(page, total));
      slot = _FullBarSlot(
        buttonKey:
            widget.jumpPage.key ?? const Key('thread-detail-jump-page-button'),
        semanticsLabel: l10n.threadControlsJumpPage,
        icon: Icons.menu_book_outlined,
        label: pageLabel,
        onTap: widget.onJumpPage,
        foreground: foreground,
        eInk: eInk,
        scheme: scheme,
        textStyle: theme.textTheme.bodyMedium,
      );
    } else {
      slot = _FullBarSlot(
        buttonKey: const Key('thread-detail-loading-slot'),
        semanticsLabel: null,
        icon: null,
        label: null,
        onTap: null,
        foreground: foreground,
        eInk: eInk,
        scheme: scheme,
        textStyle: theme.textTheme.bodyMedium,
      );
    }

    final barContent = SizedBox(
      height: 56,
      child: _surface(
        context,
        color,
        borderRadius: 28,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 4, 4),
        child: Row(
          children: [
            Expanded(child: slot),
            const SizedBox(width: 4),
            ...actionWidgets,
          ],
        ),
      ),
    );

    final mainBar = KeyedSubtree(
      key: _mainMeasureKey,
      child: usableWidth < minBarWidth
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minBarWidth, child: barContent),
            )
          : SizedBox(width: fullBarWidth, child: barContent),
    );

    final nav = navigationEnabled
        ? _buildNavigationPill(
            context,
            l10n: l10n,
            preferences: preferences,
            color: color,
            foreground: foreground,
            reduceMotion: reduceMotion,
            verticalDouble: true,
          )
        : null;

    return Align(
      alignment: Alignment.center,
      heightFactor: 1,
      child: SizedBox(
        width: fullBarWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nav != null) ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                heightFactor: 1,
                child: nav,
              ),
              const SizedBox(height: 12),
            ],
            mainBar,
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationPill(
    BuildContext context, {
    required AppLocalizations l10n,
    required ThreadControlsPreferences preferences,
    required Color color,
    required Color foreground,
    required bool reduceMotion,
    required bool verticalDouble,
  }) {
    return AnimatedBuilder(
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

        final singleButton = Tooltip(
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
                          (states) => states.contains(WidgetState.pressed)
                              ? foreground.withValues(alpha: .10)
                              : Colors.transparent,
                        )
                      : const WidgetStatePropertyAll(Colors.transparent),
                ),
            onPressed: singleEnabled
                ? atEnd
                      ? firstPost
                      : () => widget.navigation.advance(animate: !reduceMotion)
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
        );

        if (preferences.singleNavigationButton) {
          return _surface(
            context,
            color,
            borderRadius: verticalDouble ? 24 : 28,
            padding: verticalDouble ? EdgeInsets.zero : const EdgeInsets.all(4),
            child: singleButton,
          );
        }

        if (verticalDouble) {
          final scheme = Theme.of(context).colorScheme;
          final eInk = EInkModeScope.of(context);
          final dividerColor = eInk
              ? AppTheme.eInkBorderColor(scheme.brightness)
                    .withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.45);
          return _surface(
            context,
            color,
            borderRadius: 24,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 48,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [button(false), button(true)],
                  ),
                  IgnorePointer(
                    child: Container(width: 24, height: 1, color: dividerColor),
                  ),
                ],
              ),
            ),
          );
        }

        return _surface(
          context,
          color,
          borderRadius: 28,
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [button(false), const SizedBox(width: 8), button(true)],
          ),
        );
      },
    );
  }

  Widget _surface(
    BuildContext context,
    Color color, {
    required double borderRadius,
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final eInk = EInkModeScope.of(context);
    final reduceMotion = AppMotion.reduceMotion(context);
    final inner = Padding(padding: padding, child: child);
    final pill = AppGlassSurface(
      borderRadius: borderRadius,
      level: eInk ? AppGlassLevel.off : null,
      baseColor: eInk ? scheme.surface : color,
      child: inner,
    );
    return reduceMotion ? pill : ElasticPress(child: pill);
  }
}

class _FullBarSlot extends StatelessWidget {
  const _FullBarSlot({
    required this.buttonKey,
    required this.semanticsLabel,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.foreground,
    required this.eInk,
    required this.scheme,
    required this.textStyle,
  });

  final Key buttonKey;
  final String? semanticsLabel;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final Color foreground;
  final bool eInk;
  final ColorScheme scheme;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = scheme.brightness == Brightness.dark;
    final fillColor = eInk
        ? scheme.surface
        : isDark
        ? Colors.black.withValues(alpha: 0.24)
        : scheme.onSurface.withValues(alpha: 0.06);
    final border = eInk
        ? Border.all(
            color: AppTheme.eInkBorderColor(scheme.brightness),
            width: 1,
          )
        : null;
    final enabled = onTap != null;
    final contentColor = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.45);

    final inner = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: label == null
          ? const SizedBox.expand()
          : Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: contentColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (textStyle ?? const TextStyle()).copyWith(
                      color: contentColor,
                    ),
                  ),
                ),
              ],
            ),
    );

    if (semanticsLabel == null) {
      return SizedBox(
        key: buttonKey,
        height: 48,
        child: Center(child: inner),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: SizedBox(
        key: buttonKey,
        height: 48,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Center(child: inner),
          ),
        ),
      ),
    );
  }
}
