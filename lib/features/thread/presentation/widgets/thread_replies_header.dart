import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/forum_content_spacing.dart';

import 'thread_detail_theme.dart';

class ThreadRepliesHeader extends StatelessWidget {
  const ThreadRepliesHeader({
    super.key,
    required this.replyCount,
    required this.isOnlyAuthor,
    required this.isReverseOrder,
    required this.palette,
    this.enabled = true,
    this.onToggleAuthorFilter,
    this.onOrderChanged,
  });

  final int replyCount;
  final bool isOnlyAuthor;
  final bool isReverseOrder;
  final ThreadDetailNativePalette palette;
  final bool enabled;
  final VoidCallback? onToggleAuthorFilter;
  final ValueChanged<bool>? onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ForumContentSpacing.postBodyHorizontal,
        8,
        ForumContentSpacing.postBodyHorizontal,
        4,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.threadDetailReplyCount(replyCount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (onToggleAuthorFilter != null)
                _filterButton(
                  context,
                  key: const Key('thread-replies-author-filter'),
                  label: l10n.threadDetailOnlyOriginalPoster,
                  selected: isOnlyAuthor,
                  onPressed: onToggleAuthorFilter!,
                ),
            ],
          ),
          if (onOrderChanged != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterButton(
                  context,
                  key: const Key('thread-replies-normal-order'),
                  label: l10n.threadDetailAscendingOrder,
                  selected: !isReverseOrder,
                  onPressed: () {
                    if (isReverseOrder) onOrderChanged!(false);
                  },
                ),
                const SizedBox(width: 8),
                _filterButton(
                  context,
                  key: const Key('thread-replies-reverse-order'),
                  label: l10n.threadDetailDescendingOrder,
                  selected: isReverseOrder,
                  onPressed: () {
                    if (!isReverseOrder) onOrderChanged!(true);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _filterButton(
    BuildContext context, {
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(
        foregroundColor: selected ? palette.accent : palette.muted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: enabled ? onPressed : null,
      child: Semantics(selected: selected, child: Text(label)),
    );
  }
}
