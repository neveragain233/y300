import 'package:flutter/foundation.dart';

final RegExp _positiveUidPattern = RegExp(r'^[1-9]\d*$');

/// 校验并规范化可信用户 UID（仅接受正整数字符串）。
String? normalizeWhitelistedUid(String raw) {
  final trimmed = raw.trim();
  if (!_positiveUidPattern.hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

/// 免受本地关键词屏蔽的可信用户白名单条目。
@immutable
final class WhitelistedUser {
  const WhitelistedUser({
    required this.uid,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String username;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayLabel =>
      username.trim().isNotEmpty ? '${username.trim()} (UID $uid)' : 'UID $uid';

  @override
  bool operator ==(Object other) =>
      other is WhitelistedUser &&
      other.uid == uid &&
      other.username == username &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.updatedAt.isAtSameMomentAs(updatedAt);

  @override
  int get hashCode => Object.hash(uid, username, createdAt, updatedAt);
}
