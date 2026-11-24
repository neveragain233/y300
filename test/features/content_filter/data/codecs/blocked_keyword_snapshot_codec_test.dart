import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_keyword_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

void main() {
  group('BlockedKeywordSnapshotCodec', () {
    test('round-trips valid rules and deduplicates normalized keywords', () {
      final t1 = DateTime(2026, 11, 24, 10, 0);
      final t2 = DateTime(2026, 11, 24, 11, 0);
      final rules = [
        BlockedKeyword(
          id: 'k1',
          keyword: 'Spoiler',
          normalizedKeyword: 'spoiler',
          scope: BlockedKeywordScope.repliesOnly,
          createdAt: t1,
          updatedAt: t1,
        ),
        BlockedKeyword(
          id: 'k2',
          keyword: '剧透',
          normalizedKeyword: '剧透',
          scope: BlockedKeywordScope.includeBody,
          createdAt: t2,
          updatedAt: t2,
        ),
      ];

      final encoded = BlockedKeywordSnapshotCodec.encode(rules);
      final decoded = BlockedKeywordSnapshotCodec.decode(encoded);

      expect(decoded.length, 2);
      expect(decoded.first.id, 'k2');
      expect(decoded.first.scope, BlockedKeywordScope.includeBody);
      expect(decoded.last.id, 'k1');
      expect(decoded.last.scope, BlockedKeywordScope.repliesOnly);
    });

    test('tolerates malformed JSON, wrong schemaVersion and invalid items', () {
      expect(BlockedKeywordSnapshotCodec.decode(null), isEmpty);
      expect(BlockedKeywordSnapshotCodec.decode('not json'), isEmpty);
      expect(
        BlockedKeywordSnapshotCodec.decode(
          '{"schemaVersion":99,"keywords":[]}',
        ),
        isEmpty,
      );

      final decoded = BlockedKeywordSnapshotCodec.decode('''
        {
          "schemaVersion": 1,
          "keywords": [
            {"id": "", "keyword": "a", "scope": "repliesOnly", "createdAt": 100, "updatedAt": 100},
            {"id": "k1", "keyword": "   ", "scope": "repliesOnly", "createdAt": 100, "updatedAt": 100},
            {"id": "k2", "keyword": "ok", "scope": "unknown", "createdAt": 100, "updatedAt": 100},
            {"id": "k3", "keyword": "Valid", "scope": "includeBody", "createdAt": 1000, "updatedAt": 2000}
          ]
        }
      ''');

      expect(decoded.length, 1);
      expect(decoded.single.id, 'k3');
      expect(decoded.single.normalizedKeyword, 'valid');
    });
  });
}
