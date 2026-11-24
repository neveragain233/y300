import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/content_filter/presentation/content_filter_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

final _positiveUserId = RegExp(r'^[1-9]\d{0,19}$');

/// Whether the current account can add [userId] to the web blacklist.
///
/// Missing identity, an unauthenticated session, the account itself, an
/// installed-client gap and already listed members all hide the entry instead
/// of submitting a command that cannot succeed.
bool blacklistUserActionAvailable(
  WidgetRef ref, {
  required String userId,
  required String username,
}) {
  final normalized = userId.trim();
  if (!_positiveUserId.hasMatch(normalized) ||
      username.isEmpty ||
      username.trim() != username) {
    return false;
  }
  // 入口只用同步会话身份判断可见性；命令执行时再由控制器复核已验证账号。
  final identity = ref.watch(blacklistSessionUidProvider);
  if (identity == null || identity.uid == normalized) {
    return false;
  }
  if (ref.watch(blacklistedUserIdsProvider).contains(normalized)) {
    return false;
  }
  return ref.watch(blacklistAddSupportedProvider);
}

/// Adds one user to the account's web blacklist and reports the outcome.
///
/// All thread, list-card and floor entries call this so capability checks,
/// duplicate submissions and result handling stay identical.
Future<void> blockBlacklistUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String username,
}) async {
  final l10n = AppLocalizations.of(context);
  final outcome = await ref
      .read(blacklistSyncControllerProvider.notifier)
      .addUser(userId: userId, username: username);
  if (!context.mounted) {
    return;
  }
  switch (outcome) {
    case BlacklistAddOutcome.applied:
      showTransientSnackBar(context, l10n.blacklistBlockApplied(username));
    case BlacklistAddOutcome.queued:
      showTransientSnackBar(context, l10n.blacklistBlockQueued(username));
    case BlacklistAddOutcome.alreadyListed:
      showTransientSnackBar(context, l10n.blacklistBlockAlready(username));
    case BlacklistAddOutcome.notLoggedIn:
      showTransientSnackBar(context, l10n.blacklistBlockLogIn);
    case BlacklistAddOutcome.invalidTarget:
      showTransientSnackBar(context, l10n.blacklistBlockInvalidTarget);
    case BlacklistAddOutcome.self:
      showTransientSnackBar(context, l10n.blacklistBlockSelf);
    case BlacklistAddOutcome.unsupported:
      showTransientSnackBar(context, l10n.blacklistBlockUnsupported);
    case BlacklistAddOutcome.rejected:
      showTransientSnackBar(context, l10n.blacklistBlockFailed);
    case BlacklistAddOutcome.outcomeUnknown:
      showTransientSnackBar(
        context,
        l10n.blacklistBlockUnknown,
        action: SnackBarAction(
          label: l10n.blacklistReviewList,
          onPressed: () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ContentFilterPage(),
                ),
              ),
            );
          },
        ),
      );
    case BlacklistAddOutcome.stale:
    case BlacklistAddOutcome.cancelled:
      return;
  }
}
