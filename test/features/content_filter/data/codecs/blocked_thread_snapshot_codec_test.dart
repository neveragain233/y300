import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_thread_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';

void main() {
  group('BlockedThreadSnapshotCodec', () {
    test('round-trips canonical rules newest first', () {
      final rules = [
        BlockedThread(
          tid: '2',
          subject: '第二条',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        BlockedThread(
          tid: '1',
          subject: '第一条',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      ];
      final decoded = BlockedThreadSnapshotCodec.decode(
        BlockedThreadSnapshotCodec.encode(rules),
      );
      expect(decoded, hasLength(2));
      expect(decoded[0].tid, '2');
      expect(decoded[0].subject, '第二条');
      expect(decoded[1].tid, '1');
    });

    test('tolerates damaged and unknown snapshots', () {
      expect(BlockedThreadSnapshotCodec.decode(null), isEmpty);
      expect(BlockedThreadSnapshotCodec.decode('not json'), isEmpty);
      expect(
        BlockedThreadSnapshotCodec.decode(
          jsonEncode({'schemaVersion': 99, 'threads': <Object>[]}),
        ),
        isEmpty,
      );
    });

    test('skips incomplete entries and keeps the newest revision', () {
      final raw = jsonEncode({
        'schemaVersion': 1,
        'threads': [
          {'tid': '0007', 'subject': '旧标题', 'blockedAt': 1000},
          {'tid': '7', 'subject': '新标题', 'blockedAt': 3000},
          {'tid': '', 'subject': '无效', 'blockedAt': 2000},
          {'tid': '8', 'subject': 42, 'blockedAt': 2000},
          {'tid': '9', 'subject': '无时间'},
          'not-a-map',
        ],
      });
      final decoded = BlockedThreadSnapshotCodec.decode(raw);
      expect(decoded, hasLength(2));
      expect(decoded.map((rule) => rule.tid), containsAll(<String>['7', '8']));
      final seven = decoded.firstWhere((rule) => rule.tid == '7');
      expect(seven.subject, '新标题');
      expect(seven.blockedAt.millisecondsSinceEpoch, 3000);
      expect(
        decoded.firstWhere((rule) => rule.tid == '8').subject,
        '8',
        reason: 'A non-string title falls back to the thread id.',
      );
    });
  });
}
