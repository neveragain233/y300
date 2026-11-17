import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';

/// Whole-thread prompt for a topic whose author is on the web blacklist.
///
/// Members are now added from native menus; this view only offers a one-route
/// exception so direct links and saved positions can still be read. Removal
/// stays in the managed web page.
class BlacklistAuthorGateView extends StatelessWidget {
  const BlacklistAuthorGateView({
    super.key,
    required this.subject,
    required this.author,
    required this.onViewOnce,
  });

  final String subject;
  final String author;
  final VoidCallback onViewOnce;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('blacklist-author-gate'),
      appBar: AppPageAppBar(title: l10n.blacklistAuthorGateTitle),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 44,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                if (subject.trim().isNotEmpty)
                  Text(
                    subject,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (author.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    author,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  l10n.blacklistAuthorGateMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('blacklist-author-view-once-button'),
                    onPressed: onViewOnce,
                    child: Text(l10n.blacklistAuthorGateViewOnce),
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
