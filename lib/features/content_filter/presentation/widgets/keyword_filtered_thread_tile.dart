import 'package:flutter/material.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_theme.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/forum_native_surface.dart';

/// In-place placeholder for a thread hidden in a list by keyword filter rules.
///
/// Intentionally avoids displaying the matched keyword so blocked terms are not
/// re-exposed in list views.
class KeywordFilteredThreadPlaceholder extends StatelessWidget {
  const KeywordFilteredThreadPlaceholder({
    super.key,
    required this.tid,
    required this.palette,
    required this.onRevealOnce,
  });

  final String tid;
  final ForumDisplayThemePalette palette;
  final VoidCallback onRevealOnce;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eInk = EInkModeScope.of(context);
    return DecoratedBox(
      key: Key('keyword-filtered-thread-$tid'),
      decoration: BoxDecoration(
        color: eInk ? palette.background : palette.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: eInk ? Border.all(color: palette.outlineSoft, width: 1) : null,
        boxShadow: eInk
            ? null
            : ForumNativeSurfaceShadows.card(palette.stateLayer),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 18, color: palette.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.contentFilterListThreadHidden,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.bodyText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: Key('keyword-filtered-thread-reveal-$tid'),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: onRevealOnce,
              child: Text(l10n.contentFilterRevealOnce),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a temporarily revealed thread card with a compact bar to hide it again.
class KeywordRevealedThreadWrapper extends StatelessWidget {
  const KeywordRevealedThreadWrapper({
    super.key,
    required this.tid,
    required this.palette,
    required this.onHideAgain,
    required this.child,
  });

  final String tid;
  final ForumDisplayThemePalette palette;
  final VoidCallback onHideAgain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 2, 4),
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 14, color: palette.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.contentFilterRevealedNotice,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ),
              TextButton(
                key: Key('keyword-filtered-thread-hide-$tid'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onHideAgain,
                child: Text(l10n.threadBlacklistHideAgain),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
