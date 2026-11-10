import 'package:flutter/material.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_theme.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/forum_thread_list_tile.dart';

class ForumSearchResultCard extends StatelessWidget {
  const ForumSearchResultCard({
    super.key,
    required this.item,
    required this.onTap,
    this.capabilities,
    this.action,
  });
  final ForumSearchTopicSummary item;
  final VoidCallback onTap;
  final ForumSearchReadCapabilities? capabilities;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ForumDisplayThemePalette.resolve(theme);
    final metadata = _metadataText(item);
    return ForumThreadListTile(
      title: item.title,
      titleKey: Key('forum-search-result-title-${item.tid}'),
      titleColor: palette.threadTitle,
      surfaceColor: palette.surfaceContainerLow,
      shadowColor: palette.stateLayer,
      onTap: onTap,
      trailing: action,
      metadata: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata != null)
                  Text(
                    metadata,
                    key: Key('forum-search-result-metadata-${item.tid}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  AppLocalizations.of(context).searchResultTid(item.tid),
                  key: Key('forum-search-result-tid-${item.tid}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _metadataText(ForumSearchTopicSummary item) {
    final values = <String>[
      if (_supports(ForumSearchCapability.topicAuthor) &&
          item.authorName?.trim().isNotEmpty == true)
        item.authorName!.trim(),
      if (_supports(ForumSearchCapability.topicPublishedAt) &&
          item.publishedAtText?.trim().isNotEmpty == true)
        item.publishedAtText!.trim(),
    ];
    return values.isEmpty ? null : values.join(' · ');
  }

  bool _supports(ForumSearchCapability capability) {
    final readCapabilities = capabilities;
    return readCapabilities == null || readCapabilities.supports(capability);
  }
}
