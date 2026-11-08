import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/recent_search/application/recent_searches_controller.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/l10n/app_localizations.dart';

/// Reusable recent-keyword list for a visible search surface.
///
/// The host owns the current business scope, submission behavior and rate
/// limits; this widget only displays, selects, deletes and clears keywords.
class RecentSearchView extends ConsumerWidget {
  const RecentSearchView({
    super.key,
    required this.scope,
    required this.onSelected,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 0),
  });

  final RecentSearchScope scope;
  final ValueChanged<String> onSelected;
  final String? title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(recentSearchesProvider(scope));
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: Key('recent-search-panel-${scope.key}'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title ?? l10n.recentSearchTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: Key('recent-search-clear-${scope.key}'),
                onPressed: () => ref
                    .read(recentSearchesControllerProvider.notifier)
                    .clear(scope),
                child: Text(l10n.commonClear),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final entry in entries)
                InputChip(
                  key: Key('recent-search-chip-${scope.key}-${entry.keyword}'),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      entry.keyword,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onSelected(entry.keyword),
                  onDeleted: () => ref
                      .read(recentSearchesControllerProvider.notifier)
                      .remove(scope, entry.keyword),
                  deleteButtonTooltipMessage: l10n.recentSearchDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
