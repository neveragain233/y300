import 'dart:convert';

import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_pending_mutation.dart';

abstract final class BlacklistPendingMutationCodec {
  static const int version = 1;
  static final RegExp _positiveUserId = RegExp(r'^[1-9]\d{0,19}$');

  static String encode(BlacklistPendingSnapshot snapshot) {
    return jsonEncode(<String, Object?>{
      'version': version,
      'accounts': <String, Object?>{
        for (final entry in snapshot.accounts.entries)
          if (entry.value.isNotEmpty)
            entry.key: <Object?>[
              for (final mutation in entry.value)
                <String, Object?>{
                  'userId': mutation.userId,
                  'username': mutation.username,
                  'action': mutation.action.name,
                  'status': mutation.status.name,
                  'updatedAtMs': mutation.updatedAt.millisecondsSinceEpoch,
                },
            ],
      },
    });
  }

  static BlacklistPendingSnapshot decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return BlacklistPendingSnapshot.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<Object?, Object?>) {
        return BlacklistPendingSnapshot.empty;
      }
      if (decoded['version'] != version) {
        return BlacklistPendingSnapshot.empty;
      }
      final rawAccounts = decoded['accounts'];
      if (rawAccounts is! Map<Object?, Object?>) {
        return BlacklistPendingSnapshot.empty;
      }
      final accounts = <String, List<BlacklistPendingMutation>>{};
      for (final entry in rawAccounts.entries) {
        final ownerUid = entry.key;
        if (ownerUid is! String || !_positiveUserId.hasMatch(ownerUid)) {
          continue;
        }
        final rawList = entry.value;
        if (rawList is! List<Object?>) {
          continue;
        }
        final parsed = <BlacklistPendingMutation>[];
        final seenUserIds = <String>{};
        for (final item in rawList) {
          if (item is! Map<Object?, Object?>) {
            continue;
          }
          final userId = item['userId'];
          final username = item['username'];
          final actionName = item['action'];
          final statusName = item['status'];
          final updatedAtMs = item['updatedAtMs'];
          if (userId is! String ||
              !_positiveUserId.hasMatch(userId) ||
              username is! String ||
              username.isEmpty ||
              !seenUserIds.add(userId) ||
              updatedAtMs is! int) {
            continue;
          }
          final action = switch (actionName) {
            'add' => BlacklistPendingAction.add,
            'remove' => BlacklistPendingAction.remove,
            _ => null,
          };
          final status = switch (statusName) {
            'queued' => BlacklistPendingStatus.queued,
            'needsVerification' => BlacklistPendingStatus.needsVerification,
            _ => null,
          };
          if (action == null || status == null) {
            continue;
          }
          parsed.add(
            BlacklistPendingMutation(
              userId: userId,
              username: username,
              action: action,
              status: status,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
            ),
          );
        }
        if (parsed.isNotEmpty) {
          accounts[ownerUid] = parsed;
        }
      }
      while (accounts.length > BlacklistSnapshotCodec.maxAccounts) {
        accounts.remove(accounts.keys.first);
      }
      return BlacklistPendingSnapshot(accounts: accounts);
    } catch (_) {
      return BlacklistPendingSnapshot.empty;
    }
  }
}
