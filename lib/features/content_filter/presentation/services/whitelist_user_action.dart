import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/content_filter/application/whitelisted_users_controller.dart';
import 'package:y300/features/content_filter/domain/models/whitelisted_user.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 判断当前作者是否可通过快捷入口加入本地可信用户白名单。
///
/// 仅当作者 UID 合法、尚未在白名单中，且未处于网页黑名单时才展示入口，
/// 避免黑名单与白名单互斥冲突。
bool whitelistUserActionAvailable(WidgetRef ref, {required String? userId}) {
  final normalized = normalizeWhitelistedUid(userId ?? '');
  if (normalized == null) {
    return false;
  }
  if (ref.watch(blacklistedUserIdsProvider).contains(normalized)) {
    return false;
  }
  if (ref.watch(whitelistedUserIdsProvider).contains(normalized)) {
    return false;
  }
  return true;
}

/// 将指定作者加入本地可信用户白名单，并提供撤销入口。
Future<bool> addAuthorToWhitelistAction(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  String username = '',
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final feedbackStyle = TransientFeedbackStyle.capture(context);
  final controller = ref.read(whitelistedUsersControllerProvider.notifier);
  final trimmedName = username.trim();
  final result = await controller.add(uid: userId, username: trimmedName);
  if (!context.mounted) {
    return result.status == WhitelistedUserMutationStatus.created ||
        result.status == WhitelistedUserMutationStatus.alreadyExists;
  }
  switch (result.status) {
    case WhitelistedUserMutationStatus.created:
      final entry = result.entry!;
      final displayName = entry.username.isNotEmpty
          ? entry.username
          : 'UID ${entry.uid}';
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterWhitelistAuthorAdded(displayName),
        action: SnackBarAction(
          label: l10n.contentFilterUndo,
          onPressed: () => unawaited(controller.remove(entry.uid)),
        ),
      );
      return true;
    case WhitelistedUserMutationStatus.alreadyExists:
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterWhitelistedUserDuplicate,
      );
      return true;
    case WhitelistedUserMutationStatus.invalidUid:
    case WhitelistedUserMutationStatus.failed:
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterSaveFailed,
      );
      return false;
  }
}
