import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/presentation/services/blacklist_user_action.dart';
import 'package:y300/features/content_filter/presentation/services/thread_block_action.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';

/// Compact overflow menu that blocks one thread from a native topic card.
class ThreadBlockMenuButton extends ConsumerWidget {
  const ThreadBlockMenuButton({
    super.key,
    required this.tid,
    required this.subject,
    this.authorId,
    this.author,
    this.iconSize = 18,
    this.color,
  });

  final String tid;
  final String subject;
  final String? authorId;
  final String? author;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final targetUserId = authorId?.trim() ?? '';
    final targetAuthor = author ?? '';
    final canBlockAuthor = blacklistUserActionAvailable(
      ref,
      userId: targetUserId,
      username: targetAuthor,
    );
    return AppPopupMenuButton<String>(
      key: Key('thread-block-menu-$tid'),
      tooltip: l10n.contentFilterMenuTooltip,
      icon: Icon(Icons.more_horiz_rounded, size: iconSize, color: color),
      itemBuilder: (context) => [
        AppPopupMenuItem<String>(
          key: Key('thread-block-action-$tid'),
          value: 'block',
          label: l10n.contentFilterBlockAction,
          icon: const Icon(Icons.visibility_off_outlined),
        ),
        if (canBlockAuthor)
          AppPopupMenuItem<String>(
            key: Key('thread-block-author-action-$tid'),
            value: 'block-author',
            label: l10n.blacklistBlockUser,
            icon: const Icon(Icons.person_off_outlined),
            danger: true,
          ),
      ],
      onSelected: (value) {
        if (value == 'block-author') {
          unawaited(
            blockBlacklistUser(
              context,
              ref,
              userId: targetUserId,
              username: targetAuthor,
            ),
          );
          return;
        }
        unawaited(
          ThreadBlockAction.block(context, ref, tid: tid, subject: subject),
        );
      },
    );
  }
}
