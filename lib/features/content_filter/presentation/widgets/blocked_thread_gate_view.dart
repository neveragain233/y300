import 'package:flutter/material.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/l10n/app_localizations.dart';

/// Gate shown when a blocked thread is opened from a direct link, favorite or
/// history entry.
///
/// The thread body is not requested while this view is visible, so history and
/// image prefetching only start after the reader chooses to continue.
class BlockedThreadGateView extends StatelessWidget {
  const BlockedThreadGateView({
    super.key,
    required this.rule,
    required this.onViewOnce,
    required this.onUnblock,
  });

  final BlockedThread rule;
  final VoidCallback onViewOnce;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('content-filter-blocked-thread-gate'),
      appBar: AppBar(title: Text(l10n.contentFilterDirectTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 44,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  rule.subject,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.contentFilterDirectMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('content-filter-view-once-button'),
                    onPressed: onViewOnce,
                    child: Text(l10n.contentFilterViewOnce),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('content-filter-unblock-and-view-button'),
                    onPressed: onUnblock,
                    child: Text(l10n.contentFilterUnblockAndView),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
