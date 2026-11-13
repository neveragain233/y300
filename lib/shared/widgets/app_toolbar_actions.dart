import 'package:flutter/material.dart';

/// 相关动作共用胶囊，末项保留独立圆键；触区沿用原按钮尺寸。
class AppToolbarActions extends StatelessWidget {
  const AppToolbarActions({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final actionTheme = theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(foregroundColor: foreground),
      iconButtonTheme: IconButtonThemeData(
        style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? foreground.withValues(alpha: .38)
                : foreground,
          ),
        ),
      ),
    );
    Widget surface(List<Widget> actions) => Theme(
      data: actionTheme,
      child: IconButtonTheme(
        data: actionTheme.iconButtonTheme,
        child: IconTheme(
          data: IconTheme.of(context).copyWith(color: foreground),
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (children.length > 1) ...[
            surface(children.take(children.length - 1).toList()),
            const SizedBox(width: 8),
          ],
          surface([children.last]),
        ],
      ),
    );
  }
}

class AppToolbarBackButton extends StatelessWidget {
  const AppToolbarBackButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: BackButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
