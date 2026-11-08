/// One user read from the authenticated web blacklist.
final class BlacklistMember {
  const BlacklistMember({
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  /// Stable positive forum user id.
  final String userId;

  /// Exact server username.
  final String username;

  /// Optional validated avatar URL.
  final String? avatarUrl;
}

/// The last successful web-blacklist snapshot for one account.
final class BlacklistAccountSnapshot {
  const BlacklistAccountSnapshot({
    required this.ownerUid,
    required this.members,
    required this.lastSuccessAt,
  });

  final String ownerUid;
  final List<BlacklistMember> members;
  final DateTime lastSuccessAt;
}

/// Device-local snapshots keyed by verified account id.
final class BlacklistSnapshot {
  const BlacklistSnapshot({
    this.accounts = const <String, BlacklistAccountSnapshot>{},
  });

  static const empty = BlacklistSnapshot();

  final Map<String, BlacklistAccountSnapshot> accounts;

  BlacklistAccountSnapshot? accountFor(String? uid) {
    final value = uid?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return accounts[value];
  }

  /// Stores one account snapshot and keeps only the most recently synced
  /// accounts. Account switching never merges lists between accounts.
  BlacklistSnapshot withAccount(
    BlacklistAccountSnapshot account, {
    required int maxAccounts,
  }) {
    final next = Map<String, BlacklistAccountSnapshot>.of(accounts)
      ..[account.ownerUid] = account;
    final ordered = next.entries.toList()
      ..sort(
        (left, right) =>
            right.value.lastSuccessAt.compareTo(left.value.lastSuccessAt),
      );
    return BlacklistSnapshot(
      accounts: Map<String, BlacklistAccountSnapshot>.unmodifiable(
        <String, BlacklistAccountSnapshot>{
          for (final entry in ordered.take(maxAccounts)) entry.key: entry.value,
        },
      ),
    );
  }
}
