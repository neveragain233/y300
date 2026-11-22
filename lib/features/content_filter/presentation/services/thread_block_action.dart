import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// Shared "block this thread" gesture used by native cards and thread detail.
final class ThreadBlockAction {
  const ThreadBlockAction._();

  /// Blocks [tid], hides it from native lists immediately and offers one undo.
  ///
  /// Returns whether the thread is now blocked (including an existing rule).
  static Future<bool> block(
    BuildContext context,
    WidgetRef ref, {
    required String tid,
    required String subject,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final controller = ref.read(blockedThreadsControllerProvider.notifier);
    final result = await controller.block(tid: tid, subject: subject);
    switch (result.status) {
      case BlockedThreadBlockStatus.failed:
        showTransientSnackBarWithMessenger(
          messenger,
          feedbackStyle,
          l10n.contentFilterSaveFailed,
        );
        return false;
      case BlockedThreadBlockStatus.alreadyBlocked:
        showTransientSnackBarWithMessenger(
          messenger,
          feedbackStyle,
          l10n.contentFilterAlreadyBlocked(result.entry!.subject),
        );
        return true;
      case BlockedThreadBlockStatus.created:
        final entry = result.entry!;
        showTransientSnackBarWithMessenger(
          messenger,
          feedbackStyle,
          l10n.contentFilterBlocked(entry.subject),
          action: SnackBarAction(
            label: l10n.contentFilterUndo,
            onPressed: () {
              unawaited(
                controller.undo(entry).then((restored) {
                  if (!restored) {
                    showTransientSnackBarWithMessenger(
                      messenger,
                      feedbackStyle,
                      l10n.contentFilterSaveFailed,
                    );
                  }
                }),
              );
            },
          ),
        );
        return true;
    }
  }
}
