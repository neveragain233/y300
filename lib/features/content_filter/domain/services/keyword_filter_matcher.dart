import 'dart:collection';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

/// Pure visible-text keyword matching and quote-block masking for forum content.
///
/// Supports enabled/disabled state, whitelist-first exemption, plain-text
/// normalized substring matching, and bounded-length regular expressions.
abstract final class KeywordFilterMatcher {
  static const int _maxCacheEntries = 256;
  static final LinkedHashMap<Object, String?> _matchCache =
      LinkedHashMap<Object, String?>();
  static final LinkedHashMap<Object, String> _maskCache =
      LinkedHashMap<Object, String>();
  static final LinkedHashMap<String, RegExp?> _regexCache =
      LinkedHashMap<String, RegExp?>();

  /// Evaluates [texts] against enabled [allowRules] and [blockRules].
  ///
  /// Whitelist rules take precedence across all non-empty segments in [texts]:
  /// if any segment matches any enabled whitelist rule, returns `null`.
  static BlockedKeyword? matchTexts(
    Iterable<String?> texts, {
    required Iterable<BlockedKeyword> blockRules,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
    final activeBlocks = _activeBlockRules(blockRules);
    if (activeBlocks.isEmpty) {
      return null;
    }
    final activeAllows = _activeAllowRules(allowRules);
    final rawSegments = <String>[];
    final normalizedSegments = <String>[];
    for (final segment in texts) {
      if (segment == null || segment.trim().isEmpty) {
        continue;
      }
      if (!rawSegments.contains(segment)) {
        rawSegments.add(segment);
        final normalized = normalizeBlockedKeyword(segment);
        if (normalized.isNotEmpty) {
          normalizedSegments.add(normalized);
        }
      }
    }
    if (rawSegments.isEmpty) {
      return null;
    }
    if (activeAllows.isNotEmpty &&
        _matchesAnyRule(rawSegments, normalizedSegments, activeAllows) !=
            null) {
      return null;
    }
    return _matchesAnyRule(rawSegments, normalizedSegments, activeBlocks);
  }

  /// Matches [text] (and optional [convertedText]) against [rules] and
  /// optional [allowRules].
  ///
  /// Whitelist entries inside [rules] are automatically combined with
  /// [allowRules] and take precedence over block entries.
  static BlockedKeyword? matchPlainText(
    String text,
    Iterable<BlockedKeyword> rules, {
    String? convertedText,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
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
    return matchTexts(
      [text, convertedText],
      blockRules: activeBlocks,
      allowRules: combinedAllows,
    );
  }

  /// Matches a list entry's subject and optional excerpt (raw and converted)
  /// against [ruleSet].
  static BlockedKeyword? matchThreadListItem({
    required String subject,
    String? convertedSubject,
    String? excerpt,
    String? convertedExcerpt,
    required KeywordFilterRuleSet ruleSet,
  }) {
    if (!ruleSet.hasBodyRules) {
      return null;
    }
    return matchTexts(
      [subject, convertedSubject, excerpt, convertedExcerpt],
      blockRules: ruleSet.activeBodyBlockRules,
      allowRules: ruleSet.activeAllowRules,
    );
  }

  /// Matches a thread's topic title and first-post HTML body (raw and converted)
  /// against [ruleSet].
  static BlockedKeyword? matchThreadTopic({
    required String subject,
    String? convertedSubject,
    String? bodyHtml,
    String? convertedBodyHtml,
    required KeywordFilterRuleSet ruleSet,
  }) {
    if (!ruleSet.hasBodyRules) {
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
      [subject, convertedSubject, primaryBody, convertedBody],
      blockRules: ruleSet.activeBodyBlockRules,
      allowRules: ruleSet.activeAllowRules,
    );
  }

  /// Extracts visible text from [html] and matches against [rules] and
  /// optional [allowRules].
  ///
  /// Tag names, attributes, URLs, `<script>` and `<style>` are excluded. When
  /// [excludeQuotes] is true, `.quote` and `<blockquote>` subtrees are skipped.
  static BlockedKeyword? matchHtmlBody(
    String html,
    Iterable<BlockedKeyword> rules, {
    required bool excludeQuotes,
    String? convertedHtml,
    Iterable<BlockedKeyword> allowRules = const <BlockedKeyword>[],
  }) {
    if (html.trim().isEmpty) {
      return null;
    }
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
      final cachedId = _matchCache.remove(cacheKey);
      _matchCache[cacheKey] = cachedId;
      if (cachedId == null) {
        return null;
      }
      for (final rule in activeBlocks) {
        if (rule.id == cachedId) {
          return rule;
        }
      }
    }

    final primaryText = _extractVisibleText(html, excludeQuotes: excludeQuotes);
    final convertedText = convertedHtml != null && convertedHtml != html
        ? _extractVisibleText(convertedHtml, excludeQuotes: excludeQuotes)
        : null;
    final matched = matchTexts(
      [primaryText, convertedText],
      blockRules: activeBlocks,
      allowRules: combinedAllows,
    );

    _putMatchCache(cacheKey, matched?.id);
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
        [primaryQuoteText, convertedQuoteText],
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

  static List<BlockedKeyword> _activeBlockRules(
    Iterable<BlockedKeyword> rules,
  ) {
    return [
      for (final rule in rules)
        if (rule.enabled && rule.kind == BlockedKeywordKind.block) rule,
    ];
  }

  static List<BlockedKeyword> _activeAllowRules(
    Iterable<BlockedKeyword> rules,
  ) {
    return [
      for (final rule in rules)
        if (rule.enabled && rule.kind == BlockedKeywordKind.allow) rule,
    ];
  }

  static BlockedKeyword? _matchesAnyRule(
    List<String> rawSegments,
    List<String> normalizedSegments,
    List<BlockedKeyword> rules,
  ) {
    for (final rule in rules) {
      if (rule.matchType == BlockedKeywordMatchType.regex) {
        final regex = _compileRegex(rule.normalizedKeyword);
        if (regex == null) {
          continue;
        }
        for (final segment in rawSegments) {
          if (regex.hasMatch(segment)) {
            return rule;
          }
        }
      } else {
        if (rule.normalizedKeyword.isEmpty) {
          continue;
        }
        for (final segment in normalizedSegments) {
          if (segment.contains(rule.normalizedKeyword)) {
            return rule;
          }
        }
      }
    }
    return null;
  }

  static RegExp? _compileRegex(String pattern) {
    if (pattern.isEmpty || pattern.length > kMaxBlockedKeywordRegexLength) {
      return null;
    }
    if (_regexCache.containsKey(pattern)) {
      final cached = _regexCache.remove(pattern);
      _regexCache[pattern] = cached;
      return cached;
    }
    RegExp? compiled;
    try {
      compiled = RegExp(pattern, caseSensitive: false, unicode: true);
    } on FormatException {
      compiled = null;
    }
    if (_regexCache.length >= _maxCacheEntries) {
      _regexCache.remove(_regexCache.keys.first);
    }
    _regexCache[pattern] = compiled;
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
        if (tag == 'script' || tag == 'style') {
          return;
        }
        if (excludeQuotes && _isQuoteElement(node)) {
          return;
        }
        if (tag == 'br') {
          buffer.write(' ');
          return;
        }
        final isBlock = const <String>{
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
        }.contains(tag);
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
    return Object.hashAll([
      for (final rule in rules)
        Object.hash(
          rule.id,
          rule.normalizedKeyword,
          rule.scope,
          rule.kind,
          rule.matchType,
          rule.enabled,
        ),
    ]);
  }

  static void _putMatchCache(Object key, String? value) {
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
