import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';

const Duration kTransientSnackBarDuration = Duration(seconds: 3);
const Duration kTransientSnackBarActionDuration = Duration(seconds: 4);
const AnimationStyle kTransientSnackBarAnimationStyle = AnimationStyle(
  duration: Duration(milliseconds: 280),
  reverseDuration: Duration(milliseconds: 220),
);

/// Returns an explicit animation style for SnackBars.
///
/// Always returns a non-null [AnimationStyle] because Flutter's
/// `ScaffoldMessengerState` only updates its controller durations when a
/// non-null style is passed; returning `null` after showing an e-ink toast
/// would leave `_snackBarController` stuck at `Duration.zero`.
AnimationStyle transientSnackBarAnimationStyle(BuildContext context) {
  return AppMotion.reduceMotion(context)
      ? AnimationStyle.noAnimation
      : kTransientSnackBarAnimationStyle;
}

/// Captures themed SnackBar styling before async gaps or overlay actions.
@immutable
final class TransientFeedbackStyle {
  const TransientFeedbackStyle({
    required this.backgroundColor,
    required this.textStyle,
    required this.detailTextStyle,
    required this.actionTextColor,
    required this.elevation,
    required this.shape,
    required this.animationStyle,
  });

  factory TransientFeedbackStyle.capture(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final background = eInk
        ? scheme.surface
        : scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    final borderColor = eInk
        ? AppTheme.eInkBorderColor(scheme.brightness)
        : scheme.outlineVariant.withValues(alpha: 0.6);
    return TransientFeedbackStyle(
      backgroundColor: background,
      textStyle: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      detailTextStyle: theme.textTheme.bodySmall?.copyWith(
        color: eInk ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
      actionTextColor: eInk ? scheme.onSurface : scheme.primary,
      elevation: eInk ? 0 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      animationStyle: transientSnackBarAnimationStyle(context),
    );
  }

  final Color backgroundColor;
  final TextStyle? textStyle;
  final TextStyle? detailTextStyle;
  final Color actionTextColor;
  final double elevation;
  final ShapeBorder shape;
  final AnimationStyle animationStyle;

  SnackBar buildSnackBar(
    String message, {
    String? detail,
    SnackBarAction? action,
    Key? snackBarKey,
    Duration? duration,
    EdgeInsetsGeometry? margin,
    double actionOverflowThreshold = 0.25,
  }) {
    final trimmed = message.trim();
    final trimmedDetail = detail?.trim();
    final hasDetail = trimmedDetail != null && trimmedDetail.isNotEmpty;
    return SnackBar(
      key: snackBarKey,
      content: hasDetail
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trimmed, style: textStyle),
                Text(trimmedDetail, style: detailTextStyle),
              ],
            )
          : Text(trimmed, style: textStyle),
      behavior: margin != null ? SnackBarBehavior.floating : null,
      margin: margin,
      dismissDirection: DismissDirection.down,
      duration:
          duration ??
          (action != null
              ? kTransientSnackBarActionDuration
              : kTransientSnackBarDuration),
      // Flutter otherwise keeps snackbars with an action visible indefinitely.
      persist: false,
      // 主题的动作色面向反向表面；换到页面表面后按主色或墨水屏前景色重新着色。
      action: action == null
          ? null
          : SnackBarAction(
              key: action.key,
              label: action.label,
              onPressed: action.onPressed,
              textColor: action.textColor ?? actionTextColor,
              disabledTextColor: action.disabledTextColor,
              backgroundColor: action.backgroundColor,
              disabledBackgroundColor: action.disabledBackgroundColor,
            ),
      actionOverflowThreshold: actionOverflowThreshold,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
    );
  }
}

/// 构造与页面表面协调的短时提示。
///
/// `ScaffoldMessenger` 位于应用根玻璃宿主之外，SnackBar 读不到
/// `LiquidGlassScope` 的采样输入，因此这里保留原 SnackBar 端口，改用与页面
/// 分组一致的实色表面、圆角、描边和文字层级，避免反向色块与浅色页面脱节。
/// 队列、时限、撤销动作、遮挡避让和 key 仍沿用原实现。
SnackBar buildTransientSnackBar(
  BuildContext context,
  String message, {
  String? detail,
  SnackBarAction? action,
  Key? snackBarKey,
  Duration? duration,
  EdgeInsetsGeometry? margin,
  double actionOverflowThreshold = 0.25,
}) {
  return TransientFeedbackStyle.capture(context).buildSnackBar(
    message,
    detail: detail,
    action: action,
    snackBarKey: snackBarKey,
    duration: duration,
    margin: margin,
    actionOverflowThreshold: actionOverflowThreshold,
  );
}

/// Shows short-lived user feedback without adding a persistent layout region.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showTransientSnackBar(
  BuildContext context,
  String message, {
  String? detail,
  SnackBarAction? action,
  Key? snackBarKey,
  Duration? duration,
  EdgeInsetsGeometry? margin,
  double actionOverflowThreshold = 0.25,
  bool replaceCurrent = true,
}) {
  return showTransientSnackBarWithMessenger(
    ScaffoldMessenger.maybeOf(context),
    TransientFeedbackStyle.capture(context),
    message,
    detail: detail,
    action: action,
    snackBarKey: snackBarKey,
    duration: duration,
    margin: margin,
    actionOverflowThreshold: actionOverflowThreshold,
    replaceCurrent: replaceCurrent,
  );
}

/// Shows short-lived user feedback using a pre-captured messenger and style.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
showTransientSnackBarWithMessenger(
  ScaffoldMessengerState? messenger,
  TransientFeedbackStyle style,
  String message, {
  String? detail,
  SnackBarAction? action,
  Key? snackBarKey,
  Duration? duration,
  EdgeInsetsGeometry? margin,
  double actionOverflowThreshold = 0.25,
  bool replaceCurrent = true,
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || messenger == null || !messenger.mounted) {
    return null;
  }
  if (replaceCurrent) {
    messenger.hideCurrentSnackBar();
  }
  return messenger.showSnackBar(
    style.buildSnackBar(
      trimmed,
      detail: detail,
      action: action,
      snackBarKey: snackBarKey,
      duration: duration,
      margin: margin,
      actionOverflowThreshold: actionOverflowThreshold,
    ),
    snackBarAnimationStyle: style.animationStyle,
  );
}
