part of 'thread_detail_widgets.dart';

/// In-place placeholder for a floor filtered by the web blacklist or a local
/// keyword rule.
///
/// It keeps the floor's position, number and author, and builds no body,
/// images or interaction preview until the reader expands it for this session.
class ThreadBlacklistedPostPlaceholder extends StatelessWidget {
  const ThreadBlacklistedPostPlaceholder({
    super.key,
    required this.post,
    required this.palette,
    required this.onExpand,
    this.filterReason,
    this.continuous = false,
  });

  final ThreadPost post;
  final ThreadDetailNativePalette palette;
  final VoidCallback onExpand;
  final ThreadReplyFilterReason? filterReason;
  final bool continuous;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reason = filterReason;
    final headline = switch ((
      reason?.isBlacklistedAuthor ?? true,
      reason?.matchedKeyword,
    )) {
      (true, final String keyword) => l10n.threadBlacklistAndKeywordCollapsed(
        post.author,
        keyword,
      ),
      (false, final String keyword) => l10n.threadKeywordCollapsed(keyword),
      _ => l10n.threadBlacklistCollapsed(post.author),
    };
    final icon = (reason?.isBlacklistedAuthor ?? true)
        ? Icons.person_off_outlined
        : Icons.filter_alt_off_outlined;
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
              Icon(icon, size: 18, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
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

/// Single collapsible banner placed at the end of the thread's last page for
/// replies hidden by the web blacklist or local keyword rules.
class ThreadFilteredRepliesTailBanner extends StatelessWidget {
  const ThreadFilteredRepliesTailBanner({
    super.key,
    required this.count,
    required this.expanded,
    required this.collecting,
    required this.hasFailure,
    required this.hasBudgetLimitation,
    required this.palette,
    required this.onToggle,
    this.onRetry,
    this.continuous = true,
  });

  final int count;
  final bool expanded;
  final bool collecting;
  final bool hasFailure;
  final bool hasBudgetLimitation;
  final ThreadDetailNativePalette palette;
  final VoidCallback onToggle;
  final VoidCallback? onRetry;
  final bool continuous;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eInk = EInkModeScope.of(context);
    final title = count > 0
        ? (expanded
              ? l10n.threadFilteredTailCollapse(count)
              : l10n.threadFilteredTailExpand(count))
        : l10n.threadFilteredTailScanning;
    final statusText = collecting
        ? l10n.threadFilteredTailCollecting
        : hasFailure
        ? l10n.threadFilteredTailFailed
        : hasBudgetLimitation
        ? l10n.threadFilteredTailBudgetReached
        : null;
    final showRetry = !collecting && (hasFailure || hasBudgetLimitation);

    final banner = Container(
      key: const Key('thread-filtered-tail-banner'),
      margin: continuous
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: ForumContentSpacing.postCardGap),
      decoration: BoxDecoration(
        color: eInk ? palette.background : palette.card,
        border: eInk
            ? Border.all(color: palette.border, width: 1)
            : Border(
                top: BorderSide(color: palette.border, width: 0.75),
                bottom: BorderSide(color: palette.border, width: 0.75),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: count > 0,
            expanded: count > 0 ? expanded : null,
            child: InkWell(
              key: const Key('thread-filtered-tail-toggle'),
              onTap: count > 0 ? onToggle : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ForumContentSpacing.postBodyHorizontal,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_off_outlined,
                        size: 18,
                        color: palette.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.bodyText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (collecting && !eInk) ...[
                        const SizedBox(width: 8),
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: palette.muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (statusText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ForumContentSpacing.postBodyHorizontal,
                0,
                ForumContentSpacing.postBodyHorizontal,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                  if (showRetry && onRetry != null)
                    TextButton(
                      key: const Key('thread-filtered-tail-retry'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: onRetry,
                      child: Text(
                        hasFailure
                            ? l10n.commonRetry
                            : l10n.threadFilteredTailLoadMore,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (!continuous) {
      return banner;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banner,
        if (expanded && count > 0)
          _ThreadFloorSeparatorBand(palette: palette, isFirstPost: false),
      ],
    );
  }
}
