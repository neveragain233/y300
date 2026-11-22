part of 'thread_detail_widgets.dart';

/// In-place placeholder for a floor whose author is on the web blacklist.
///
/// It keeps the floor's position, number and author, and builds no body,
/// images or interaction preview until the reader expands it for this session.
class ThreadBlacklistedPostPlaceholder extends StatelessWidget {
  const ThreadBlacklistedPostPlaceholder({
    super.key,
    required this.post,
    required this.palette,
    required this.onExpand,
    this.continuous = false,
  });

  final ThreadPost post;
  final ThreadDetailNativePalette palette;
  final VoidCallback onExpand;
  final bool continuous;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final card = Container(
      key: Key('thread-blacklisted-post-${post.pid}'),
      margin: continuous
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: ForumContentSpacing.postCardGap),
      padding: const EdgeInsets.fromLTRB(
        ForumContentSpacing.postBodyHorizontal,
        ForumContentSpacing.postCardHeaderTop,
        ForumContentSpacing.postBodyHorizontal,
        ForumContentSpacing.postCardSingleBottom,
      ),
      decoration: continuous
          ? BoxDecoration(color: palette.background)
          : _cardDecoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_off_outlined, size: 18, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.threadBlacklistCollapsed(post.author),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.bodyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.threadBlacklistCollapsedFloor(post.number),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ),
              TextButton(
                key: Key('thread-blacklisted-expand-${post.pid}'),
                onPressed: onExpand,
                child: Text(l10n.threadBlacklistExpandOnce),
              ),
            ],
          ),
        ],
      ),
    );
    if (!continuous) {
      return card;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        _ThreadFloorSeparatorBand(palette: palette, isFirstPost: post.isFirst),
      ],
    );
  }
}
