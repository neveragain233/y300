import 'dart:convert';

import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/services/thread_block_identity.dart';

/// Versioned JSON snapshot for the locally blocked thread rules.
///
/// Decoding is deliberately tolerant: a damaged or unknown snapshot must never
/// prevent the forum from opening, and only complete rules are retained.
abstract final class BlockedThreadSnapshotCodec {
  static const int schemaVersion = 1;

  /// Upper bound that keeps one preference value small and bounded.
  static const int maxEntries = 500;

  static String encode(List<BlockedThread> threads) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'threads': [
        for (final thread in threads.take(maxEntries))
          <String, Object?>{
            'tid': thread.tid,
            'subject': thread.subject,
            'blockedAt': thread.blockedAt.millisecondsSinceEpoch,
          },
      ],
    });
  }

  static List<BlockedThread> decode(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const <BlockedThread>[];
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return const <BlockedThread>[];
      }
      final values = decoded['threads'];
      if (values is! List) {
        return const <BlockedThread>[];
      }
      final byTid = <String, BlockedThread>{};
      for (final value in values) {
        final rule = _decodeRule(value);
        if (rule == null) {
          continue;
        }
        final existing = byTid[rule.tid];
        if (existing == null || rule.blockedAt.isAfter(existing.blockedAt)) {
          byTid[rule.tid] = rule;
        }
      }
      final rules = byTid.values.toList()
        ..sort((left, right) => right.blockedAt.compareTo(left.blockedAt));
      return List<BlockedThread>.unmodifiable(rules.take(maxEntries));
    } on Object {
      return const <BlockedThread>[];
    }
  }

  static BlockedThread? _decodeRule(Object? value) {
    if (value is! Map) {
      return null;
    }
    final rawTid = value['tid'];
    final tid = rawTid is String
        ? ThreadBlockIdentity.normalizeTid(rawTid)
        : null;
    if (tid == null) {
      return null;
    }
    final epoch = value['blockedAt'];
    if (epoch is! int || epoch <= 0) {
      return null;
    }
    final rawSubject = value['subject'];
    final subject = rawSubject is String ? rawSubject.trim() : '';
    return BlockedThread(
      tid: tid,
      subject: subject.isEmpty ? tid : subject,
      blockedAt: DateTime.fromMillisecondsSinceEpoch(epoch),
    );
  }
}
