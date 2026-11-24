import 'package:flutter/foundation.dart';

/// Intended remote mutation queued locally for an authenticated account.
enum BlacklistPendingAction { add, remove }

/// Delivery state of a local pending web-blacklist mutation.
///
/// [queued] has never been sent or failed pre-send, so it may be flushed
/// automatically once a verified session and network connectivity return.
/// [needsVerification] represents `DataCommandOutcomeUnknown` where the server
/// may already have applied the change; it must never be auto-resent, and is
/// only cleared by a read-only reconciliation or an explicit user retry/cancel.
enum BlacklistPendingStatus { queued, needsVerification }

@immutable
final class BlacklistPendingMutation {
  const BlacklistPendingMutation({
    required this.userId,
    required this.username,
    required this.action,
    required this.status,
    required this.updatedAt,
  });

  final String userId;
  final String username;
  final BlacklistPendingAction action;
  final BlacklistPendingStatus status;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return other is BlacklistPendingMutation &&
        other.userId == userId &&
        other.username == username &&
        other.action == action &&
        other.status == status &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(userId, username, action, status, updatedAt);
}

@immutable
final class BlacklistPendingSnapshot {
  BlacklistPendingSnapshot({
    Map<String, List<BlacklistPendingMutation>> accounts =
        const <String, List<BlacklistPendingMutation>>{},
  }) : accounts = Map<String, List<BlacklistPendingMutation>>.unmodifiable({
         for (final entry in accounts.entries)
           entry.key: List<BlacklistPendingMutation>.unmodifiable(entry.value),
       });

  static final BlacklistPendingSnapshot empty = BlacklistPendingSnapshot();

  final Map<String, List<BlacklistPendingMutation>> accounts;

  List<BlacklistPendingMutation> mutationsFor(String ownerUid) =>
      accounts[ownerUid] ?? const <BlacklistPendingMutation>[];

  BlacklistPendingSnapshot withMutation(
    String ownerUid,
    BlacklistPendingMutation mutation, {
    int maxAccounts = 8,
  }) {
    final nextAccounts = <String, List<BlacklistPendingMutation>>{
      for (final entry in accounts.entries)
        if (entry.key != ownerUid) entry.key: entry.value,
    };
    final existing = mutationsFor(ownerUid);
    final updatedList = <BlacklistPendingMutation>[
      for (final item in existing)
        if (item.userId != mutation.userId) item,
      mutation,
    ];
    nextAccounts[ownerUid] = updatedList;
    while (nextAccounts.length > maxAccounts) {
      nextAccounts.remove(nextAccounts.keys.first);
    }
    return BlacklistPendingSnapshot(accounts: nextAccounts);
  }

  BlacklistPendingSnapshot withoutUser(String ownerUid, String userId) {
    return withoutUsers(ownerUid, <String>{userId});
  }

  BlacklistPendingSnapshot withoutUsers(String ownerUid, Set<String> userIds) {
    final existing = accounts[ownerUid];
    if (existing == null || existing.isEmpty || userIds.isEmpty) {
      return this;
    }
    final remaining = existing
        .where((item) => !userIds.contains(item.userId))
        .toList(growable: false);
    if (remaining.length == existing.length) {
      return this;
    }
    final nextAccounts = <String, List<BlacklistPendingMutation>>{
      for (final entry in accounts.entries)
        if (entry.key != ownerUid) entry.key: entry.value,
    };
    if (remaining.isNotEmpty) {
      nextAccounts[ownerUid] = remaining;
    }
    return BlacklistPendingSnapshot(accounts: nextAccounts);
  }
}
