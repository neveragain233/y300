import 'dart:convert';

import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

/// Versioned JSON snapshot for locally blocked keyword rules.
///
/// Decoding is deliberately tolerant: a damaged or unknown snapshot must never
/// prevent the forum from opening, and only valid rules are retained.
abstract final class BlockedKeywordSnapshotCodec {
  static const int schemaVersion = 1;

  /// Upper bound that keeps one preference value small and bounded.
  static const int maxEntries = 500;

  static String encode(List<BlockedKeyword> keywords) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'keywords': [
        for (final rule in keywords.take(maxEntries))
          <String, Object?>{
            'id': rule.id,
            'keyword': rule.keyword,
            'scope': rule.scope.name,
            'kind': rule.kind.name,
            'matchType': rule.matchType.name,
            'wholeWord': rule.wholeWord,
            'caseSensitive': rule.caseSensitive,
            'enabled': rule.enabled,
            'createdAt': rule.createdAt.millisecondsSinceEpoch,
            'updatedAt': rule.updatedAt.millisecondsSinceEpoch,
          },
      ],
    });
  }

  static List<BlockedKeyword> decode(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const <BlockedKeyword>[];
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return const <BlockedKeyword>[];
      }
      final values = decoded['keywords'];
      if (values is! List) {
        return const <BlockedKeyword>[];
      }
      final byIdentity =
          <
            (BlockedKeywordKind, BlockedKeywordMatchType, bool, bool, String),
            BlockedKeyword
          >{};
      for (final value in values) {
        final rule = _decodeRule(value);
        if (rule == null) {
          continue;
        }
        final identity = (
          rule.kind,
          rule.matchType,
          rule.wholeWord,
          rule.caseSensitive,
          rule.normalizedKeyword,
        );
        final existing = byIdentity[identity];
        if (existing == null || rule.updatedAt.isAfter(existing.updatedAt)) {
          byIdentity[identity] = rule;
        }
      }
      final rules = byIdentity.values.toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      return List<BlockedKeyword>.unmodifiable(rules.take(maxEntries));
    } on Object {
      return const <BlockedKeyword>[];
    }
  }

  static BlockedKeyword? _decodeRule(Object? value) {
    if (value is! Map) {
      return null;
    }
    final rawId = value['id'];
    final id = rawId is String ? rawId.trim() : '';
    if (id.isEmpty) {
      return null;
    }
    final rawKeyword = value['keyword'];
    if (rawKeyword is! String) {
      return null;
    }
    final keyword = stripInvisibleFilterChars(rawKeyword).trim();
    final kind = switch (value['kind']) {
      null => BlockedKeywordKind.block,
      'block' => BlockedKeywordKind.block,
      'allow' => BlockedKeywordKind.allow,
      _ => null,
    };
    if (kind == null) {
      return null;
    }
    final matchType = switch (value['matchType']) {
      null => BlockedKeywordMatchType.plain,
      'plain' => BlockedKeywordMatchType.plain,
      'regex' => BlockedKeywordMatchType.regex,
      _ => null,
    };
    if (matchType == null) {
      return null;
    }
    final rawWholeWord = value['wholeWord'];
    if (rawWholeWord != null && rawWholeWord is! bool) {
      return null;
    }
    final wholeWord = rawWholeWord as bool? ?? true;
    final rawCaseSensitive = value['caseSensitive'];
    if (rawCaseSensitive != null && rawCaseSensitive is! bool) {
      return null;
    }
    final caseSensitive =
        rawCaseSensitive as bool? ??
        (matchType == BlockedKeywordMatchType.regex);
    if (validateBlockedKeywordPattern(
          keyword,
          matchType,
          caseSensitive: caseSensitive,
        ) !=
        null) {
      return null;
    }
    final normalizedKeyword = normalizeBlockedKeywordPattern(
      keyword,
      matchType,
      caseSensitive: caseSensitive,
    );
    if (normalizedKeyword.isEmpty) {
      return null;
    }
    final scope = switch (value['scope']) {
      'includeBody' => BlockedKeywordScope.includeBody,
      'repliesOnly' => BlockedKeywordScope.repliesOnly,
      _ => null,
    };
    if (scope == null) {
      return null;
    }
    final rawEnabled = value['enabled'];
    if (rawEnabled != null && rawEnabled is! bool) {
      return null;
    }
    final enabled = rawEnabled as bool? ?? true;
    final createdEpoch = value['createdAt'];
    final updatedEpoch = value['updatedAt'];
    if (createdEpoch is! int ||
        createdEpoch <= 0 ||
        updatedEpoch is! int ||
        updatedEpoch <= 0) {
      return null;
    }
    return BlockedKeyword(
      id: id,
      keyword: keyword,
      normalizedKeyword: normalizedKeyword,
      scope: kind == BlockedKeywordKind.allow
          ? BlockedKeywordScope.includeBody
          : scope,
      kind: kind,
      matchType: matchType,
      wholeWord: matchType == BlockedKeywordMatchType.regex ? false : wholeWord,
      caseSensitive: caseSensitive,
      enabled: enabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedEpoch),
    );
  }
}
