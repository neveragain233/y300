import 'package:flutter/material.dart';

/// 构造与页面表面协调的短时提示。
///
/// `ScaffoldMessenger` 位于应用根玻璃宿主之外，SnackBar 读不到
/// `LiquidGlassScope` 的采样输入，因此这里保留原 SnackBar 端口，改用与页面
/// 分组一致的实色表面、圆角、描边和文字层级，避免反向色块与浅色页面脱节。
/// 队列、时限、撤销动作、遮挡避让和 key 仍沿用原实现。
SnackBar buildTransientSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Key? snackBarKey,
  double actionOverflowThreshold = 0.25,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final background = scheme.brightness == Brightness.dark
      ? scheme.surfaceContainerHigh
      : scheme.surfaceContainerLowest;
  return SnackBar(
    key: snackBarKey,
    content: Text(
      message.trim(),
      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    duration: const Duration(seconds: 4),
    // Flutter otherwise keeps snackbars with an action visible indefinitely.
    persist: false,
    // 主题的动作色面向反向表面；换到页面表面后按主色重新着色。
    action: action == null
        ? null
        : SnackBarAction(
            key: action.key,
            label: action.label,
            onPressed: action.onPressed,
            textColor: action.textColor ?? scheme.primary,
            disabledTextColor: action.disabledTextColor,
            backgroundColor: action.backgroundColor,
            disabledBackgroundColor: action.disabledBackgroundColor,
          ),
    actionOverflowThreshold: actionOverflowThreshold,
    backgroundColor: background,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    ),
  );
}

/// Shows short-lived user feedback without adding a persistent layout region.
void showTransientSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Key? snackBarKey,
  double actionOverflowThreshold = 0.25,
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      buildTransientSnackBar(
        context,
        trimmed,
        action: action,
        snackBarKey: snackBarKey,
        actionOverflowThreshold: actionOverflowThreshold,
      ),
    );
}
