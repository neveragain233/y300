import 'dart:convert';

import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';

/// Versioned JSON snapshot for per-account web-blacklist lists.
abstract final class BlacklistSnapshotCodec {
  static const int schemaVersion = 1;
  static const int maxAccounts = 10;
  static const int maxMembers = 500;

  static String encode(BlacklistSnapshot snapshot) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'accounts': <String, Object?>{
        for (final entry in snapshot.accounts.entries)
          entry.key: <String, Object?>{
            'lastSuccessAt': entry.value.lastSuccessAt.millisecondsSinceEpoch,
            'members': [
              for (final member in entry.value.members.take(maxMembers))
                <String, Object?>{
                  'userId': member.userId,
                  'username': member.username,
                  if (member.avatarUrl != null) 'avatarUrl': member.avatarUrl,
                },
            ],
          },
      },
    });
  }

  static BlacklistSnapshot decode(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return BlacklistSnapshot.empty;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return BlacklistSnapshot.empty;
      }
      final accounts = decoded['accounts'];
      if (accounts is! Map) {
        return BlacklistSnapshot.empty;
      }
      final parsed = <String, BlacklistAccountSnapshot>{};
      for (final entry in accounts.entries) {
        final ownerUid = entry.key;
        if (ownerUid is! String ||
            !RegExp(r'^[1-9]\d{0,19}$').hasMatch(ownerUid)) {
          continue;
        }
        final account = _decodeAccount(ownerUid, entry.value);
        if (account != null) {
          parsed[ownerUid] = account;
        }
      }
      final ordered = parsed.entries.toList()
        ..sort(
          (left, right) =>
              right.value.lastSuccessAt.compareTo(left.value.lastSuccessAt),
        );
      return BlacklistSnapshot(
        accounts: Map<String, BlacklistAccountSnapshot>.unmodifiable(
          <String, BlacklistAccountSnapshot>{
            for (final entry in ordered.take(maxAccounts))
              entry.key: entry.value,
          },
        ),
      );
    } on Object {
      return BlacklistSnapshot.empty;
    }
  }

  static BlacklistAccountSnapshot? _decodeAccount(
    String ownerUid,
    Object? value,
  ) {
    if (value is! Map) {
      return null;
    }
    final epoch = value['lastSuccessAt'];
    if (epoch is! int || epoch <= 0) {
      return null;
    }
    final rawMembers = value['members'];
    if (rawMembers is! List || rawMembers.length > maxMembers) {
      return null;
    }
    final members = <BlacklistMember>[];
    final seen = <String>{};
    for (final rawMember in rawMembers) {
      final member = _decodeMember(rawMember);
      if (member == null || !seen.add(member.userId)) {
        continue;
      }
      members.add(member);
    }
    return BlacklistAccountSnapshot(
      ownerUid: ownerUid,
      members: List<BlacklistMember>.unmodifiable(members),
      lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(epoch),
    );
  }

  static BlacklistMember? _decodeMember(Object? value) {
    if (value is! Map) {
      return null;
    }
    final rawUid = value['userId'];
    final rawName = value['username'];
    if (rawUid is! String || rawName is! String) {
      return null;
    }
    final userId = rawUid.trim();
    final username = rawName.trim();
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(userId) ||
        username.isEmpty ||
        username.length > 256 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(username)) {
      return null;
    }
    final rawAvatar = value['avatarUrl'];
    final avatar = rawAvatar is String ? rawAvatar.trim() : '';
    return BlacklistMember(
      userId: userId,
      username: username,
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }
}
