import 'package:flutter/foundation.dart';

/// Scope of a local keyword blocking rule.
enum BlockedKeywordScope { repliesOnly, includeBody }

final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');

/// Normalizes [raw] for case-insensitive and whitespace-collapsed matching.
String normalizeBlockedKeyword(String raw) {
  final collapsed = raw.trim().replaceAll(_whitespaceCollapsePattern, ' ');
  return collapsed.toLowerCase();
}

/// A device-local keyword rule that filters replies or whole threads.
@immutable
final class BlockedKeyword {
  const BlockedKeyword({
    required this.id,
    required this.keyword,
    required this.normalizedKeyword,
    required this.scope,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String keyword;
  final String normalizedKeyword;
  final BlockedKeywordScope scope;
  final DateTime createdAt;
  final DateTime updatedAt;

  BlockedKeyword copyWith({
    String? id,
    String? keyword,
    String? normalizedKeyword,
    BlockedKeywordScope? scope,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlockedKeyword(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      normalizedKeyword: normalizedKeyword ?? this.normalizedKeyword,
      scope: scope ?? this.scope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isSameRule(BlockedKeyword other) =>
      id == other.id &&
      keyword == other.keyword &&
      normalizedKeyword == other.normalizedKeyword &&
      scope == other.scope &&
      createdAt.isAtSameMomentAs(other.createdAt) &&
      updatedAt.isAtSameMomentAs(other.updatedAt);

  @override
  bool operator ==(Object other) =>
      other is BlockedKeyword && isSameRule(other);

  @override
  int get hashCode =>
      Object.hash(id, keyword, normalizedKeyword, scope, createdAt, updatedAt);
}

/// Device-local display preferences for keyword filtering.
@immutable
final class KeywordFilterPreferences {
  const KeywordFilterPreferences({this.hideMatchingThreadsInLists = true});

  static const KeywordFilterPreferences defaults = KeywordFilterPreferences();

  final bool hideMatchingThreadsInLists;

  KeywordFilterPreferences copyWith({bool? hideMatchingThreadsInLists}) {
    return KeywordFilterPreferences(
      hideMatchingThreadsInLists:
          hideMatchingThreadsInLists ?? this.hideMatchingThreadsInLists,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KeywordFilterPreferences &&
      other.hideMatchingThreadsInLists == hideMatchingThreadsInLists;

  @override
  int get hashCode => hideMatchingThreadsInLists.hashCode;
}

/// Immutable snapshot of active keyword rules and list display preference.
@immutable
final class KeywordFilterRuleSet {
  const KeywordFilterRuleSet({
    this.rules = const <BlockedKeyword>[],
    this.hideMatchingThreadsInLists = true,
    this.revision = 0,
  });

  static const KeywordFilterRuleSet empty = KeywordFilterRuleSet();

  final List<BlockedKeyword> rules;
  final bool hideMatchingThreadsInLists;
  final int revision;

  bool get isEmpty => rules.isEmpty;
  bool get hasReplyRules => rules.isNotEmpty;
  bool get hasBodyRules =>
      rules.any((rule) => rule.scope == BlockedKeywordScope.includeBody);

  List<BlockedKeyword> get replyRules => rules;

  List<BlockedKeyword> get bodyRules => List<BlockedKeyword>.unmodifiable(
    rules.where((rule) => rule.scope == BlockedKeywordScope.includeBody),
  );
}
