part of 'thread_detail_widgets.dart';

/// Compact strip of the thread's own topic tags.
///
/// Tags with a stable tag id open the native tag directory; the thread body
/// keeps its normal interaction and scrolling behavior.
class ThreadTopicTagBar extends StatelessWidget {
  const ThreadTopicTagBar({
    super.key,
    required this.tags,
    required this.onOpenTag,
  });

  final List<ThreadPostTagLink> tags;
  final ValueChanged<String> onOpenTag;

  @override
  Widget build(BuildContext context) {
    final palette = ThreadDetailNativePalette.resolve(Theme.of(context));
    final l10n = AppLocalizations.of(context);
    return Material(
      key: const Key('thread-topic-tag-bar'),
      color: palette.background,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.sell_outlined, size: 16, color: palette.muted),
            const SizedBox(width: 6),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                itemCount: tags.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  final tagId = tag.tagId?.trim() ?? '';
                  return ActionChip(
                    key: Key(
                      'thread-topic-tag-${tagId.isEmpty ? index : tagId}',
                    ),
                    label: Text(
                      tag.label.trim().isEmpty
                          ? l10n.threadTopicTagFallback
                          : tag.label.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    visualDensity: VisualDensity.compact,
                    labelStyle: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w600,
                        ),
                    side: BorderSide(color: palette.outlineSoft),
                    backgroundColor: palette.chipBackground,
                    onPressed: tagId.isEmpty ? null : () => onOpenTag(tagId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
