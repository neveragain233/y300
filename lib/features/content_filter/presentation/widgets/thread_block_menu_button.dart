import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/presentation/services/thread_block_action.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';

/// Compact overflow menu that blocks one thread from a native topic card.
class ThreadBlockMenuButton extends ConsumerWidget {
  const ThreadBlockMenuButton({
    super.key,
    required this.tid,
    required this.subject,
    this.iconSize = 18,
    this.color,
  });

  final String tid;
  final String subject;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPopupMenuButton<String>(
      key: Key('thread-block-menu-$tid'),
      tooltip: l10n.contentFilterMenuTooltip,
      icon: Icon(Icons.more_horiz_rounded, size: iconSize, color: color),
      itemBuilder: (context) => [
        AppPopupMenuItem<String>(
          key: Key('thread-block-action-$tid'),
          value: 'block',
          label: l10n.contentFilterBlockAction,
        ),
      ],
      onSelected: (_) {
        unawaited(
          ThreadBlockAction.block(context, ref, tid: tid, subject: subject),
        );
      },
    );
  }
}
