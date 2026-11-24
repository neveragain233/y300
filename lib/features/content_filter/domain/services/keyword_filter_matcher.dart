import 'dart:collection';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

/// Pure visible-text keyword matching and quote-block masking for forum content.
///
/// Uses case-insensitive, whitespace-collapsed substring matching instead of
/// regular expressions to avoid backtracking or syntax errors on user input.
abstract final class KeywordFilterMatcher {
  static const int _maxCacheEntries = 256;
  static final LinkedHashMap<Object, String?> _matchCache =
      LinkedHashMap<Object, String?>();
  static final LinkedHashMap<Object, String> _maskCache =
      LinkedHashMap<Object, String>();

  /// Matches [text] (and optional [convertedText]) against [rules].
  static BlockedKeyword? matchPlainText(
    String text,
    Iterable<BlockedKeyword> rules, {
    String? convertedText,
  }) {
    final ruleList = rules is List<BlockedKeyword>
        ? rules
        : rules.toList(growable: false);
    if (ruleList.isEmpty) {
      return null;
    }
    final normalizedPrimary = normalizeBlockedKeyword(text);
    final normalizedConverted = convertedText == null || convertedText == text
        ? ''
        : normalizeBlockedKeyword(convertedText);
    if (normalizedPrimary.isEmpty && normalizedConverted.isEmpty) {
      return null;
    }
    for (final rule in ruleList) {
      if (normalizedPrimary.contains(rule.normalizedKeyword)) {
        return rule;
      }
      if (normalizedConverted.isNotEmpty &&
          normalizedConverted.contains(rule.normalizedKeyword)) {
        return rule;
      }
    }
    return null;
  }

  /// Extracts visible text from [html] and matches against [rules].
  ///
  /// Tag names, attributes, URLs, `<script>` and `<style>` are excluded. When
  /// [excludeQuotes] is true, `.quote` and `<blockquote>` subtrees are skipped.
  static BlockedKeyword? matchHtmlBody(
    String html,
    Iterable<BlockedKeyword> rules, {
    required bool excludeQuotes,
    String? convertedHtml,
  }) {
    final ruleList = rules is List<BlockedKeyword>
        ? rules
        : rules.toList(growable: false);
    if (ruleList.isEmpty || html.trim().isEmpty) {
      return null;
    }
    final signature = _rulesSignature(ruleList);
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
      for (final rule in ruleList) {
        if (rule.id == cachedId) {
          return rule;
        }
      }
    }

    final primaryText = _extractVisibleText(html, excludeQuotes: excludeQuotes);
    var matched = matchPlainText(primaryText, ruleList);
    if (matched == null && convertedHtml != null && convertedHtml != html) {
      final convertedText = _extractVisibleText(
        convertedHtml,
        excludeQuotes: excludeQuotes,
      );
      matched = matchPlainText(convertedText, ruleList);
    }

    _putMatchCache(cacheKey, matched?.id);
    return matched;
  }

  /// Replaces top-level quote blocks in [html] whose visible text matches any
  /// rule in [rules] with a placeholder quote block containing [placeholderText].
  static String maskBlockedQuotesInHtml(
    String html, {
    required Iterable<BlockedKeyword> rules,
    required String placeholderText,
    String? convertedHtml,
  }) {
    final ruleList = rules is List<BlockedKeyword>
        ? rules
        : rules.toList(growable: false);
    if (ruleList.isEmpty || html.trim().isEmpty) {
      return html;
    }
    final lower = html.toLowerCase();
    if (!lower.contains('quote') && !lower.contains('blockquote')) {
      return html;
    }
    final signature = _rulesSignature(ruleList);
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
      final matched = matchPlainText(
        primaryQuoteText,
        ruleList,
        convertedText: convertedQuoteText,
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
        Object.hash(rule.id, rule.normalizedKeyword, rule.scope),
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
