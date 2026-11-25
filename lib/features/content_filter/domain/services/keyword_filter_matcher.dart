import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

/// 命中的单条关键词规则及其上下文片段。
@immutable
final class KeywordMatchDetail {
  const KeywordMatchDetail({
    required this.rule,
    required this.matchedText,
    required this.snippet,
  });

  final BlockedKeyword rule;
  final String matchedText;
  final String snippet;
}

/// 规则测试与诊断的完整评估结果（同时保留白名单与屏蔽命中信息）。
@immutable
final class KeywordEvaluationResult {
  const KeywordEvaluationResult({
    this.matchedBlock,
    this.matchedAllow,
    this.whitelistedAuthor = false,
  });

  final KeywordMatchDetail? matchedBlock;
  final KeywordMatchDetail? matchedAllow;
  final bool whitelistedAuthor;

  bool get isBlocked =>
      !whitelistedAuthor && matchedAllow == null && matchedBlock != null;

  BlockedKeyword? get blockingRule => isBlocked ? matchedBlock!.rule : null;
}

/// Pure visible-text keyword matching and quote-block masking for forum content.
///
/// Supports enabled/disabled state, whitelist-first exemption, Latin
/// whole-word boundary matching, per-rule case sensitivity, invisible-character
/// stripping, and bounded-length regular expressions.
abstract final class KeywordFilterMatcher {
  static const int _maxCacheEntries = 256;
  static final LinkedHashMap<Object, KeywordMatchDetail?> _matchCache =
      LinkedHashMap<Object, KeywordMatchDetail?>();
  static final LinkedHashMap<Object, String> _maskCache =
      LinkedHashMap<Object, String>();
  static final LinkedHashMap<(String, bool), RegExp?> _regexCache =
      LinkedHashMap<(String, bool), RegExp?>();

  static final RegExp _whitespaceCollapsePattern = RegExp(r'\s+');
  static final RegExp _asciiLetterPattern = RegExp(r'[A-Za-z]');
  static final RegExp _pureUrlPattern = RegExp(
    r'^(?:https?:\/\/|www\.)\S+$',
    caseSensitive: false,
  );

  static const Set<String> _spaceBoundaryTags = <String>{
    'br',
    'hr',
    'wbr',
    'img',
    'video',
    'audio',
    'source',
    'track',
    'embed',
    'object',
    'iframe',
    'svg',
    'canvas',
    'input',
  };

  static const Set<String> _blockTags = <String>{
    'p',
    'div',
    'section',
    'article',
    'blockquote',
    'li',
    'tr',
    'td',
    'th',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  /// 完整评估 [texts] 对启用白名单与屏蔽规则的命中情况（供规则测试器与诊断使用）。
  static KeywordEvaluationResult evaluateTexts(
    Iterable<String?> texts, {
    required Iterable<BlockedKeyword> blockRules,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
    bool whitelistedAuthor = false,
  }) {
    final activeBlocks = _activeBlockRules(blockRules);
    final activeAllows = _activeAllowRules(allowRules);
    final segments = _prepareSegments(texts);
    if (segments.isEmpty) {
      return KeywordEvaluationResult(whitelistedAuthor: whitelistedAuthor);
    }
    final matchedAllow = activeAllows.isEmpty
        ? null
        : _matchSegmentsDetail(segments, activeAllows);
    final matchedBlock = activeBlocks.isEmpty
        ? null
        : _matchSegmentsDetail(segments, activeBlocks);
    return KeywordEvaluationResult(
      matchedBlock: matchedBlock,
      matchedAllow: matchedAllow,
      whitelistedAuthor: whitelistedAuthor,
    );
  }

  /// 完整评估纯文本 [text]（及可选简繁转换文本 [convertedText]）。
  static KeywordEvaluationResult evaluatePlainText(
    String text,
    Iterable<BlockedKeyword> rules, {
    String? convertedText,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
    bool whitelistedAuthor = false,
  }) {
    final (activeBlocks, combinedAllows) = _splitActiveRules(rules, allowRules);
    return evaluateTexts(
      <String?>[text, convertedText],
      blockRules: activeBlocks,
      allowRules: combinedAllows,
      whitelistedAuthor: whitelistedAuthor,
    );
  }

  /// Evaluates [texts] against enabled [allowRules] and [blockRules].
  ///
  /// Whitelist rules take precedence across all non-empty segments in [texts]:
  /// if any segment matches any enabled whitelist rule, returns `null`.
  static BlockedKeyword? matchTexts(
    Iterable<String?> texts, {
    required Iterable<BlockedKeyword> blockRules,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
    return matchTextsDetail(
      texts,
      blockRules: blockRules,
      allowRules: allowRules,
    )?.rule;
  }

  /// Evaluates [texts] and returns the matched blocking rule with snippet.
  static KeywordMatchDetail? matchTextsDetail(
    Iterable<String?> texts, {
    required Iterable<BlockedKeyword> blockRules,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
    final activeBlocks = _activeBlockRules(blockRules);
    if (activeBlocks.isEmpty) {
      return null;
    }
    final activeAllows = _activeAllowRules(allowRules);
    final segments = _prepareSegments(texts);
    if (segments.isEmpty) {
      return null;
    }
    if (activeAllows.isNotEmpty &&
        _matchSegmentsDetail(segments, activeAllows) != null) {
      return null;
    }
    return _matchSegmentsDetail(segments, activeBlocks);
  }

  /// Matches [text] (and optional [convertedText]) against [rules] and
  /// optional [allowRules].
  static BlockedKeyword? matchPlainText(
    String text,
    Iterable<BlockedKeyword> rules, {
    String? convertedText,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
    final (activeBlocks, combinedAllows) = _splitActiveRules(rules, allowRules);
    return matchTexts(
      <String?>[text, convertedText],
      blockRules: activeBlocks,
      allowRules: combinedAllows,
    );
  }

  /// Matches a list entry's subject and optional excerpt (raw and converted)
  /// against [ruleSet], respecting [authorId] user whitelist.
  static BlockedKeyword? matchThreadListItem({
    required String subject,
    String? convertedSubject,
    String? excerpt,
    String? convertedExcerpt,
    required KeywordFilterRuleSet ruleSet,
    String? authorId,
  }) {
    if (!ruleSet.hasBodyRules || ruleSet.isWhitelistedAuthor(authorId)) {
      return null;
    }
    return matchTexts(
      <String?>[subject, convertedSubject, excerpt, convertedExcerpt],
      blockRules: ruleSet.activeBodyBlockRules,
      allowRules: ruleSet.activeAllowRules,
    );
  }

  /// Matches a thread's topic title and first-post HTML body (raw and converted)
  /// against [ruleSet], respecting [authorId] user whitelist.
  static BlockedKeyword? matchThreadTopic({
    required String subject,
    String? convertedSubject,
    String? bodyHtml,
    String? convertedBodyHtml,
    required KeywordFilterRuleSet ruleSet,
    String? authorId,
  }) {
    if (!ruleSet.hasBodyRules || ruleSet.isWhitelistedAuthor(authorId)) {
      return null;
    }
    final primaryBody = bodyHtml == null || bodyHtml.trim().isEmpty
        ? null
        : _extractVisibleText(bodyHtml, excludeQuotes: false);
    final convertedBody =
        convertedBodyHtml == null ||
            convertedBodyHtml == bodyHtml ||
            convertedBodyHtml.trim().isEmpty
        ? null
        : _extractVisibleText(convertedBodyHtml, excludeQuotes: false);
    return matchTexts(
      <String?>[subject, convertedSubject, primaryBody, convertedBody],
      blockRules: ruleSet.activeBodyBlockRules,
      allowRules: ruleSet.activeAllowRules,
    );
  }

  /// Extracts visible text from [html] and matches against [rules] and
  /// optional [allowRules].
  static BlockedKeyword? matchHtmlBody(
    String html,
    Iterable<BlockedKeyword> rules, {
    required bool excludeQuotes,
    String? convertedHtml,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
    String? authorId,
    Set<String> whitelistedUserIds = const <String>{},
  }) {
    return matchReplyHtmlDetail(
      html,
      rules,
      excludeQuotes: excludeQuotes,
      convertedHtml: convertedHtml,
      allowRules: allowRules,
      authorId: authorId,
      whitelistedUserIds: whitelistedUserIds,
    )?.rule;
  }

  /// 提取回复正文可见文本并匹配关键词，同时返回命中片段供展开后诊断展示。
  static KeywordMatchDetail? matchReplyHtmlDetail(
    String html,
    Iterable<BlockedKeyword> rules, {
    required bool excludeQuotes,
    String? convertedHtml,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
    String? authorId,
    Set<String> whitelistedUserIds = const <String>{},
  }) {
    if (html.trim().isEmpty) {
      return null;
    }
    final trimmedAuthorId = authorId?.trim();
    if (trimmedAuthorId != null &&
        trimmedAuthorId.isNotEmpty &&
        whitelistedUserIds.contains(trimmedAuthorId)) {
      return null;
    }
    final (activeBlocks, combinedAllows) = _splitActiveRules(rules, allowRules);
    if (activeBlocks.isEmpty) {
      return null;
    }

    final signature = Object.hash(
      _rulesSignature(activeBlocks),
      _rulesSignature(combinedAllows),
    );
    final cacheKey = (
      signature,
      excludeQuotes,
      html,
      convertedHtml == html ? null : convertedHtml,
    );
    if (_matchCache.containsKey(cacheKey)) {
      final cached = _matchCache.remove(cacheKey);
      _matchCache[cacheKey] = cached;
      if (cached == null) {
        return null;
      }
      for (final rule in activeBlocks) {
        if (rule.id == cached.rule.id) {
          return KeywordMatchDetail(
            rule: rule,
            matchedText: cached.matchedText,
            snippet: cached.snippet,
          );
        }
      }
    }

    final primaryText = _extractVisibleText(html, excludeQuotes: excludeQuotes);
    final convertedText = convertedHtml != null && convertedHtml != html
        ? _extractVisibleText(convertedHtml, excludeQuotes: excludeQuotes)
        : null;
    final matched = matchTextsDetail(
      <String?>[primaryText, convertedText],
      blockRules: activeBlocks,
      allowRules: combinedAllows,
    );

    _putMatchCache(cacheKey, matched);
    return matched;
  }

  /// Replaces top-level quote blocks in [html] whose visible text matches any
  /// rule in [rules] (and is not exempted by [allowRules]) with a placeholder
  /// quote block containing [placeholderText].
  static String maskBlockedQuotesInHtml(
    String html, {
    required Iterable<BlockedKeyword> rules,
    required String placeholderText,
    String? convertedHtml,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
    if (html.trim().isEmpty) {
      return html;
    }
    final (activeBlocks, combinedAllows) = _splitActiveRules(rules, allowRules);
    if (activeBlocks.isEmpty) {
      return html;
    }
    final lower = html.toLowerCase();
    if (!lower.contains('quote') && !lower.contains('blockquote')) {
      return html;
    }
    final signature = Object.hash(
      _rulesSignature(activeBlocks),
      _rulesSignature(combinedAllows),
    );
    final normalizedConverted = convertedHtml == html ? null : convertedHtml;
    final cacheKey = (signature, placeholderText, html, normalizedConverted);
    if (_maskCache.containsKey(cacheKey)) {
      final cached = _maskCache.remove(cacheKey)!;
      _maskCache[cacheKey] = cached;
      return cached;
    }

    final fragment = html_parser.parseFragment(html);
    final quotes = _collectTopLevelQuotes(fragment);
    if (quotes.isEmpty) {
      _putMaskCache(cacheKey, html);
      return html;
    }

    List<html_dom.Element>? convertedQuotes;
    if (normalizedConverted != null && normalizedConverted.trim().isNotEmpty) {
      final convertedFragment = html_parser.parseFragment(normalizedConverted);
      final candidate = _collectTopLevelQuotes(convertedFragment);
      if (candidate.length == quotes.length) {
        convertedQuotes = candidate;
      }
    }

    var changed = false;
    final escapedPlaceholder = _escapeHtml(placeholderText);
    for (var index = 0; index < quotes.length; index++) {
      final quoteElement = quotes[index];
      final primaryQuoteText = _extractVisibleTextFromNode(
        quoteElement,
        excludeQuotes: false,
      );
      final convertedQuoteText = convertedQuotes == null
          ? null
          : _extractVisibleTextFromNode(
              convertedQuotes[index],
              excludeQuotes: false,
            );
      final matched = matchTexts(
        <String?>[primaryQuoteText, convertedQuoteText],
        blockRules: activeBlocks,
        allowRules: combinedAllows,
      );
      if (matched == null) {
        continue;
      }
      changed = true;
      final replacement = html_parser.parseFragment(
        '<div class="quote"><blockquote><em>$escapedPlaceholder</em></blockquote></div>',
      );
      if (quoteElement.parentNode != null && replacement.nodes.isNotEmpty) {
        quoteElement.replaceWith(replacement.nodes.first);
      }
    }

    final output = changed ? fragment.outerHtml : html;
    _putMaskCache(cacheKey, output);
    return output;
  }

  static (List<BlockedKeyword>, List<BlockedKeyword>) _splitActiveRules(
    Iterable<BlockedKeyword> rules,
    Iterable<BlockedKeyword> allowRules,
  ) {
    final activeBlocks = <BlockedKeyword>[];
    final combinedAllows = <BlockedKeyword>[..._activeAllowRules(allowRules)];
    for (final rule in rules) {
      if (!rule.enabled) {
        continue;
      }
      if (rule.kind == BlockedKeywordKind.allow) {
        combinedAllows.add(rule);
      } else {
        activeBlocks.add(rule);
      }
    }
    return (activeBlocks, combinedAllows);
  }

  static List<BlockedKeyword> _activeBlockRules(
    Iterable<BlockedKeyword> rules,
  ) {
    return <BlockedKeyword>[
      for (final rule in rules)
        if (rule.enabled && rule.kind == BlockedKeywordKind.block) rule,
    ];
  }

  static List<BlockedKeyword> _activeAllowRules(
    Iterable<BlockedKeyword> rules,
  ) {
    return <BlockedKeyword>[
      for (final rule in rules)
        if (rule.enabled && rule.kind == BlockedKeywordKind.allow) rule,
    ];
  }

  static List<_PreparedSegment> _prepareSegments(Iterable<String?> texts) {
    final segments = <_PreparedSegment>[];
    final seenCollapsed = <String>{};
    for (final raw in texts) {
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      final cleaned = stripInvisibleFilterChars(raw);
      final collapsed = cleaned.trim().replaceAll(
        _whitespaceCollapsePattern,
        ' ',
      );
      if (collapsed.isEmpty || !seenCollapsed.add(collapsed)) {
        continue;
      }
      segments.add(
        _PreparedSegment(
          collapsed: collapsed,
          lowerCollapsed: collapsed.toLowerCase(),
        ),
      );
    }
    return segments;
  }

  static KeywordMatchDetail? _matchSegmentsDetail(
    List<_PreparedSegment> segments,
    List<BlockedKeyword> rules,
  ) {
    for (final rule in rules) {
      if (rule.normalizedKeyword.isEmpty) {
        continue;
      }
      if (rule.matchType == BlockedKeywordMatchType.regex) {
        final regex = _compileRegex(
          rule.normalizedKeyword,
          caseSensitive: rule.caseSensitive,
        );
        if (regex == null) {
          continue;
        }
        for (final segment in segments) {
          final match = regex.firstMatch(segment.collapsed);
          if (match != null) {
            return _buildDetail(
              rule,
              segment.collapsed,
              match.start,
              match.end,
            );
          }
        }
        continue;
      }

      if (rule.effectiveWholeWord) {
        final regex = _compileWholeWordPlainRegex(
          rule.normalizedKeyword,
          caseSensitive: rule.caseSensitive,
        );
        if (regex == null) {
          continue;
        }
        for (final segment in segments) {
          final match = regex.firstMatch(segment.collapsed);
          if (match != null) {
            return _buildDetail(
              rule,
              segment.collapsed,
              match.start,
              match.end,
            );
          }
        }
        continue;
      }

      final needle = rule.normalizedKeyword;
      for (final segment in segments) {
        final haystack = rule.caseSensitive
            ? segment.collapsed
            : segment.lowerCollapsed;
        final index = haystack.indexOf(needle);
        if (index >= 0) {
          return _buildDetail(
            rule,
            segment.collapsed,
            index,
            index + needle.length,
          );
        }
      }
    }
    return null;
  }

  static KeywordMatchDetail _buildDetail(
    BlockedKeyword rule,
    String text,
    int start,
    int end,
  ) {
    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(safeStart, text.length);
    final matchedText = text.substring(safeStart, safeEnd);
    const contextRadius = 12;
    final windowStart = (safeStart - contextRadius).clamp(0, text.length);
    final windowEnd = (safeEnd + contextRadius).clamp(0, text.length);
    final prefix = windowStart > 0 ? '…' : '';
    final suffix = windowEnd < text.length ? '…' : '';
    final snippet = '$prefix${text.substring(windowStart, windowEnd)}$suffix';
    return KeywordMatchDetail(
      rule: rule,
      matchedText: matchedText.isEmpty ? rule.keyword : matchedText,
      snippet: snippet,
    );
  }

  static RegExp? _compileRegex(String pattern, {required bool caseSensitive}) {
    if (pattern.isEmpty || pattern.length > kMaxBlockedKeywordRegexLength) {
      return null;
    }
    final key = (pattern, caseSensitive);
    if (_regexCache.containsKey(key)) {
      final cached = _regexCache.remove(key);
      _regexCache[key] = cached;
      return cached;
    }
    RegExp? compiled;
    try {
      compiled = RegExp(pattern, caseSensitive: caseSensitive, unicode: true);
    } on FormatException {
      compiled = null;
    }
    if (_regexCache.length >= _maxCacheEntries) {
      _regexCache.remove(_regexCache.keys.first);
    }
    _regexCache[key] = compiled;
    return compiled;
  }

  static RegExp? _compileWholeWordPlainRegex(
    String normalizedKeyword, {
    required bool caseSensitive,
  }) {
    if (normalizedKeyword.isEmpty) {
      return null;
    }
    final escaped = RegExp.escape(normalizedKeyword);
    final leftBoundary = _asciiLetterPattern.hasMatch(normalizedKeyword[0])
        ? r'(?<![A-Za-z])'
        : '';
    final rightBoundary =
        _asciiLetterPattern.hasMatch(
          normalizedKeyword[normalizedKeyword.length - 1],
        )
        ? r'(?![A-Za-z])'
        : '';
    final pattern = '$leftBoundary$escaped$rightBoundary';
    final key = (pattern, caseSensitive);
    if (_regexCache.containsKey(key)) {
      final cached = _regexCache.remove(key);
      _regexCache[key] = cached;
      return cached;
    }
    RegExp? compiled;
    try {
      compiled = RegExp(pattern, caseSensitive: caseSensitive, unicode: true);
    } on FormatException {
      compiled = null;
    }
    if (_regexCache.length >= _maxCacheEntries) {
      _regexCache.remove(_regexCache.keys.first);
    }
    _regexCache[key] = compiled;
    return compiled;
  }

  static List<html_dom.Element> _collectTopLevelQuotes(
    html_dom.DocumentFragment fragment,
  ) {
    final quotes = <html_dom.Element>[];
    void visit(html_dom.Node node) {
      if (node is html_dom.Element) {
        if (_isQuoteElement(node)) {
          quotes.add(node);
          return;
        }
      }
      for (final child in node.nodes) {
        visit(child);
      }
    }

    for (final child in fragment.nodes) {
      visit(child);
    }
    return quotes;
  }

  static bool _isQuoteElement(html_dom.Element element) {
    final tag = element.localName?.toLowerCase();
    return element.classes.contains('quote') || tag == 'blockquote';
  }

  static String _extractVisibleText(
    String html, {
    required bool excludeQuotes,
  }) {
    final fragment = html_parser.parseFragment(html);
    return _extractVisibleTextFromNode(fragment, excludeQuotes: excludeQuotes);
  }

  static String _extractVisibleTextFromNode(
    html_dom.Node root, {
    required bool excludeQuotes,
  }) {
    final buffer = StringBuffer();
    void visit(html_dom.Node node) {
      if (node is html_dom.Text) {
        buffer.write(node.text);
        return;
      }
      if (node is html_dom.Element) {
        final tag = node.localName?.toLowerCase();
        if (tag == 'script' ||
            tag == 'style' ||
            tag == 'noscript' ||
            tag == 'template') {
          return;
        }
        if (excludeQuotes && _isQuoteElement(node)) {
          return;
        }
        if (tag != null && _spaceBoundaryTags.contains(tag)) {
          if (buffer.isNotEmpty) {
            buffer.write(' ');
          }
          return;
        }
        if (tag == 'a') {
          final anchorText = node.text.trim();
          if (anchorText.isNotEmpty && _pureUrlPattern.hasMatch(anchorText)) {
            if (buffer.isNotEmpty) {
              buffer.write(' ');
            }
            return;
          }
        }
        final isBlock = tag != null && _blockTags.contains(tag);
        if (isBlock && buffer.isNotEmpty) {
          buffer.write(' ');
        }
        for (final child in node.nodes) {
          visit(child);
        }
        if (isBlock) {
          buffer.write(' ');
        }
        return;
      }
      for (final child in node.nodes) {
        visit(child);
      }
    }

    visit(root);
    return buffer.toString();
  }

  static int _rulesSignature(List<BlockedKeyword> rules) {
    return Object.hashAll(<int>[
      for (final rule in rules)
        Object.hash(
          rule.id,
          rule.normalizedKeyword,
          rule.scope,
          rule.kind,
          rule.matchType,
          rule.wholeWord,
          rule.caseSensitive,
          rule.enabled,
        ),
    ]);
  }

  static void _putMatchCache(Object key, KeywordMatchDetail? value) {
    if (_matchCache.length >= _maxCacheEntries) {
      _matchCache.remove(_matchCache.keys.first);
    }
    _matchCache[key] = value;
  }

  static void _putMaskCache(Object key, String value) {
    if (_maskCache.length >= _maxCacheEntries) {
      _maskCache.remove(_maskCache.keys.first);
    }
    _maskCache[key] = value;
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

final class _PreparedSegment {
  const _PreparedSegment({
    required this.collapsed,
    required this.lowerCollapsed,
  });

  final String collapsed;
  final String lowerCollapsed;
}
