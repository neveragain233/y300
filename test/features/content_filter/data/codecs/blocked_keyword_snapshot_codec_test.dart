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
      expect(decoded.single.kind, BlockedKeywordKind.block);
      expect(decoded.single.matchType, BlockedKeywordMatchType.plain);
      expect(decoded.single.enabled, isTrue);
    });

    test(
      'round-trips whitelist, regex, enabled state and drops invalid regex',
      () {
        final t1 = DateTime(2026, 11, 24, 12, 0);
        final allowRegex = BlockedKeyword(
          id: 'a1',
          keyword: r'^\[官方\]',
          normalizedKeyword: r'^\[官方\]',
          scope: BlockedKeywordScope.includeBody,
          kind: BlockedKeywordKind.allow,
          matchType: BlockedKeywordMatchType.regex,
          enabled: false,
          createdAt: t1,
          updatedAt: t1,
        );

        final decoded = BlockedKeywordSnapshotCodec.decode(
          BlockedKeywordSnapshotCodec.encode([allowRegex]),
        );
        expect(decoded.length, 1);
        expect(decoded.single.kind, BlockedKeywordKind.allow);
        expect(decoded.single.matchType, BlockedKeywordMatchType.regex);
        expect(decoded.single.enabled, isFalse);

        final withBadRegex = BlockedKeywordSnapshotCodec.decode('''
        {
          "schemaVersion": 1,
          "keywords": [
            {"id": "bad", "keyword": "[unclosed", "scope": "includeBody", "kind": "block", "matchType": "regex", "enabled": true, "createdAt": 1000, "updatedAt": 1000}
          ]
        }
      ''');
        expect(withBadRegex, isEmpty);
      },
    );

    test(
      'applies v1 legacy defaults and round-trips wholeWord and caseSensitive',
      () {
        final legacyDecoded = BlockedKeywordSnapshotCodec.decode('''
        {
          "schemaVersion": 1,
          "keywords": [
            {"id": "p1", "keyword": "AI", "scope": "includeBody", "kind": "block", "matchType": "plain", "enabled": true, "createdAt": 1000, "updatedAt": 2000},
            {"id": "r1", "keyword": "\\\\bAI\\\\b", "scope": "repliesOnly", "kind": "block", "matchType": "regex", "enabled": true, "createdAt": 1000, "updatedAt": 3000}
          ]
        }
      ''');
        expect(legacyDecoded.length, 2);
        final regexRule = legacyDecoded.firstWhere((e) => e.id == 'r1');
        final plainRule = legacyDecoded.firstWhere((e) => e.id == 'p1');
        expect(plainRule.wholeWord, isTrue);
        expect(plainRule.caseSensitive, isFalse);
        expect(regexRule.wholeWord, isFalse);
        expect(regexRule.caseSensitive, isTrue);

        final t1 = DateTime.fromMillisecondsSinceEpoch(4000);
        final customPlain = BlockedKeyword(
          id: 'p2',
          keyword: 'AI',
          normalizedKeyword: 'AI',
          scope: BlockedKeywordScope.includeBody,
          wholeWord: false,
          caseSensitive: true,
          createdAt: t1,
          updatedAt: t1,
        );
        final roundTripped = BlockedKeywordSnapshotCodec.decode(
          BlockedKeywordSnapshotCodec.encode(<BlockedKeyword>[
            plainRule,
            customPlain,
          ]),
        );
        expect(roundTripped.length, 2);
        expect(
          roundTripped.firstWhere((e) => e.id == 'p2').caseSensitive,
          isTrue,
        );
        expect(roundTripped.firstWhere((e) => e.id == 'p2').wholeWord, isFalse);
      },
    );
  });
}
