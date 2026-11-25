import 'dart:convert';

import 'package:y300/features/content_filter/domain/models/whitelisted_user.dart';

/// 本地可信用户白名单的 JSON 快照编解码器。
abstract final class WhitelistedUserSnapshotCodec {
  static const int schemaVersion = 1;
  static const int maxEntries = 500;

  static String encode(List<WhitelistedUser> users) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'users': [
        for (final user in users.take(maxEntries))
          <String, Object?>{
            'uid': user.uid,
            'username': user.username,
            'createdAt': user.createdAt.millisecondsSinceEpoch,
            'updatedAt': user.updatedAt.millisecondsSinceEpoch,
          },
      ],
    });
  }

  static List<WhitelistedUser> decode(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const <WhitelistedUser>[];
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return const <WhitelistedUser>[];
      }
      final values = decoded['users'];
      if (values is! List) {
        return const <WhitelistedUser>[];
      }
      final byUid = <String, WhitelistedUser>{};
      for (final value in values) {
        final user = _decodeUser(value);
        if (user == null) continue;
        final existing = byUid[user.uid];
        if (existing == null || user.updatedAt.isAfter(existing.updatedAt)) {
          byUid[user.uid] = user;
        }
      }
      final result = byUid.values.toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      return List<WhitelistedUser>.unmodifiable(result.take(maxEntries));
    } on Object {
      return const <WhitelistedUser>[];
    }
  }

  static WhitelistedUser? _decodeUser(Object? value) {
    if (value is! Map) return null;
    final rawUid = value['uid'];
    if (rawUid is! String) return null;
    final uid = normalizeWhitelistedUid(rawUid);
    if (uid == null) return null;
    final rawUsername = value['username'];
    if (rawUsername != null && rawUsername is! String) return null;
    final username = (rawUsername as String? ?? '').trim();
    final createdEpoch = value['createdAt'];
    final updatedEpoch = value['updatedAt'];
    if (createdEpoch is! int ||
        createdEpoch <= 0 ||
        updatedEpoch is! int ||
        updatedEpoch <= 0) {
      return null;
    }
    return WhitelistedUser(
      uid: uid,
      username: username,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedEpoch),
    );
  }
}
