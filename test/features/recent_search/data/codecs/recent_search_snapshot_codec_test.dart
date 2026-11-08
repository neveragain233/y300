import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/recent_search/data/codecs/recent_search_snapshot_codec.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_entry.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';

void main() {
  group('RecentSearchSnapshotCodec', () {
    test('round-trips known ranges', () {
      final snapshot = RecentSearchSnapshot(
        entriesByScope: <String, List<RecentSearchEntry>>{
          'forum': <RecentSearchEntry>[
            RecentSearchEntry(
              keyword: '漫画',
              usedAt: DateTime.fromMillisecondsSinceEpoch(3000),
            ),
          ],
          'shelf:comic': <RecentSearchEntry>[
            RecentSearchEntry(
              keyword: '测试',
              usedAt: DateTime.fromMillisecondsSinceEpoch(2000),
            ),
          ],
        },
      );

      final decoded = RecentSearchSnapshotCodec.decode(
        RecentSearchSnapshotCodec.encode(snapshot),
      );

      expect(
        decoded.entriesByScope.keys,
        containsAll(<String>['forum', 'shelf:comic']),
      );
      expect(decoded.entriesByScope['forum']!.single.keyword, '漫画');
    });

    test('ignores unknown ranges and damaged entries', () {
      final raw = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'scopes': <String, Object?>{
          'forum': <Object?>[
            <String, Object?>{'keyword': '  有效  ', 'usedAt': 1000},
            <String, Object?>{'keyword': '', 'usedAt': 1000},
            <String, Object?>{'keyword': '无时间'},
            'not-a-map',
          ],
          'future:range': <Object?>[
            <String, Object?>{'keyword': '未来', 'usedAt': 1000},
          ],
        },
      });

      final decoded = RecentSearchSnapshotCodec.decode(raw);

      expect(decoded.entriesByScope.keys, <String>['forum']);
      expect(decoded.entriesByScope['forum']!.single.keyword, '有效');
    });

    test('tolerates malformed snapshots', () {
      expect(
        RecentSearchSnapshotCodec.decode('bad json').entriesByScope,
        isEmpty,
      );
      expect(
        RecentSearchSnapshotCodec.decode(
          jsonEncode(<String, Object?>{'schemaVersion': 9, 'scopes': {}}),
        ).entriesByScope,
        isEmpty,
      );
    });
  });
}
