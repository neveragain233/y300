import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';

/// Whole-thread prompt for a topic whose title or body matched a keyword rule.
///
/// Intentionally omits the matched keyword itself.
class BlockedKeywordThreadGateView extends StatelessWidget {
  const BlockedKeywordThreadGateView({
    super.key,
    required this.subject,
    required this.onViewOnce,
    this.onManageRules,
  });

  final String subject;
  final VoidCallback onViewOnce;
  final VoidCallback? onManageRules;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('keyword-thread-gate'),
      appBar: AppPageAppBar(title: l10n.keywordThreadGateTitle),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_off_outlined,
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
                const SizedBox(height: 12),
                Text(
                  l10n.keywordThreadGateGenericMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('keyword-thread-view-once-button'),
                    onPressed: onViewOnce,
                    child: Text(l10n.keywordThreadGateViewOnce),
                  ),
                ),
                if (onManageRules != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('keyword-thread-manage-rules-button'),
                      onPressed: onManageRules,
                      child: Text(l10n.keywordThreadGateManageRules),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
