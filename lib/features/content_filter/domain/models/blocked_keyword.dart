import 'package:flutter/foundation.dart';

/// Scope of a local keyword blocking rule.
enum BlockedKeywordScope { repliesOnly, includeBody }

/// Whether a keyword rule blocks content or exempts it from keyword blocks.
enum BlockedKeywordKind { block, allow }

/// Matching mode for a keyword rule.
enum BlockedKeywordMatchType { plain, regex }

/// Validation errors for user-entered keyword or regular-expression rules.
enum BlockedKeywordPatternError { empty, regexTooLong, invalidRegex }

/// Maximum allowed character length for user-entered regular expressions.
const int kMaxBlockedKeywordRegexLength = 160;

final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');

/// Normalizes [raw] for case-insensitive and whitespace-collapsed matching.
String normalizeBlockedKeyword(String raw) {
  final collapsed = raw.trim().replaceAll(_whitespaceCollapsePattern, ' ');
  return collapsed.toLowerCase();
}

/// Normalizes [raw] according to [matchType] for storage and deduplication.
String normalizeBlockedKeywordPattern(
  String raw,
  BlockedKeywordMatchType matchType,
) {
  return switch (matchType) {
    BlockedKeywordMatchType.plain => normalizeBlockedKeyword(raw),
    BlockedKeywordMatchType.regex => raw.trim(),
  };
}

/// Validates [raw] for [matchType], returning `null` when valid.
BlockedKeywordPatternError? validateBlockedKeywordPattern(
  String raw,
  BlockedKeywordMatchType matchType,
) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return BlockedKeywordPatternError.empty;
  }
  switch (matchType) {
    case BlockedKeywordMatchType.plain:
      return null;
    case BlockedKeywordMatchType.regex:
      if (trimmed.length > kMaxBlockedKeywordRegexLength) {
        return BlockedKeywordPatternError.regexTooLong;
      }
      try {
        RegExp(trimmed, caseSensitive: false, unicode: true);
        return null;
      } on FormatException {
        return BlockedKeywordPatternError.invalidRegex;
      }
  }
}

/// A device-local keyword rule that filters or exempts replies and threads.
@immutable
final class BlockedKeyword {
  const BlockedKeyword({
    required this.id,
    required this.keyword,
    required this.normalizedKeyword,
    required this.scope,
    required this.createdAt,
    required this.updatedAt,
    this.kind = BlockedKeywordKind.block,
    this.matchType = BlockedKeywordMatchType.plain,
    this.enabled = true,
  });

  final String id;
  final String keyword;
  final String normalizedKeyword;
  final BlockedKeywordScope scope;
  final BlockedKeywordKind kind;
  final BlockedKeywordMatchType matchType;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isWhitelist => kind == BlockedKeywordKind.allow;
  bool get isRegex => matchType == BlockedKeywordMatchType.regex;

  BlockedKeyword copyWith({
    String? id,
    String? keyword,
    String? normalizedKeyword,
    BlockedKeywordScope? scope,
    BlockedKeywordKind? kind,
    BlockedKeywordMatchType? matchType,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlockedKeyword(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      normalizedKeyword: normalizedKeyword ?? this.normalizedKeyword,
      scope: scope ?? this.scope,
      kind: kind ?? this.kind,
      matchType: matchType ?? this.matchType,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isSameRule(BlockedKeyword other) =>
      id == other.id &&
      keyword == other.keyword &&
      normalizedKeyword == other.normalizedKeyword &&
      scope == other.scope &&
      kind == other.kind &&
      matchType == other.matchType &&
      enabled == other.enabled &&
      createdAt.isAtSameMomentAs(other.createdAt) &&
      updatedAt.isAtSameMomentAs(other.updatedAt);

  @override
  bool operator ==(Object other) =>
      other is BlockedKeyword && isSameRule(other);

  @override
  int get hashCode => Object.hash(
    id,
    keyword,
    normalizedKeyword,
    scope,
    kind,
    matchType,
    enabled,
    createdAt,
    updatedAt,
  );
}

/// Device-local display preferences for keyword filtering.
@immutable
final class KeywordFilterPreferences {
  const KeywordFilterPreferences({this.hideBlockedContentCompletely = false});

  static const KeywordFilterPreferences defaults = KeywordFilterPreferences();

  /// Whether keyword-blocked threads are removed completely from lists instead
  /// of showing an in-place placeholder.
  final bool hideBlockedContentCompletely;

  KeywordFilterPreferences copyWith({bool? hideBlockedContentCompletely}) {
    return KeywordFilterPreferences(
      hideBlockedContentCompletely:
          hideBlockedContentCompletely ?? this.hideBlockedContentCompletely,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KeywordFilterPreferences &&
      other.hideBlockedContentCompletely == hideBlockedContentCompletely;

  @override
  int get hashCode => hideBlockedContentCompletely.hashCode;
}

/// Immutable snapshot of active keyword rules and list display preference.
@immutable
final class KeywordFilterRuleSet {
  const KeywordFilterRuleSet({
    this.rules = const <BlockedKeyword>[],
    this.hideBlockedContentCompletely = false,
    this.revision = 0,
  });

  static const KeywordFilterRuleSet empty = KeywordFilterRuleSet();

  final List<BlockedKeyword> rules;
  final bool hideBlockedContentCompletely;
  final int revision;

  List<BlockedKeyword> get activeAllowRules =>
      List<BlockedKeyword>.unmodifiable(
        rules.where(
          (rule) => rule.enabled && rule.kind == BlockedKeywordKind.allow,
        ),
      );

  List<BlockedKeyword> get activeBlockRules =>
      List<BlockedKeyword>.unmodifiable(
        rules.where(
          (rule) => rule.enabled && rule.kind == BlockedKeywordKind.block,
        ),
      );

  List<BlockedKeyword> get activeReplyBlockRules => activeBlockRules;

  List<BlockedKeyword> get activeBodyBlockRules =>
      List<BlockedKeyword>.unmodifiable(
        rules.where(
          (rule) =>
              rule.enabled &&
              rule.kind == BlockedKeywordKind.block &&
              rule.scope == BlockedKeywordScope.includeBody,
        ),
      );

  bool get isEmpty => activeBlockRules.isEmpty;
  bool get hasReplyRules => activeReplyBlockRules.isNotEmpty;
  bool get hasBodyRules => activeBodyBlockRules.isNotEmpty;

  List<BlockedKeyword> get replyRules => activeReplyBlockRules;

  List<BlockedKeyword> get bodyRules => activeBodyBlockRules;
}
