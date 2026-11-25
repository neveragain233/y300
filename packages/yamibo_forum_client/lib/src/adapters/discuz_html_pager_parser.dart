// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:html/dom.dart' as html_dom;

/// Parsed Discuz `.pg` pagination metadata.
final class DiscuzHtmlPager {
  const DiscuzHtmlPager({
    required this.currentPage,
    required this.lastPage,
    required this.previousPageUrl,
    required this.nextPageUrl,
    required this.hasPager,
  });

  final int currentPage;
  final int? lastPage;
  final String? previousPageUrl;
  final String? nextPageUrl;
  final bool hasPager;

  bool get hasMore =>
      nextPageUrl != null || (lastPage != null && lastPage! > currentPage);
}

final RegExp _firstIntPattern = RegExp(r'\d+');
final RegExp _slashTotalPattern = RegExp(r'/\s*(\d+)');
final RegExp _numberedAnchorTextPattern = RegExp(r'^(?:\.\.\.\s*)?(\d+)$');

/// Parses Discuz desktop and mobile `.pg` containers into normalized page bounds.
///
/// Distinguishes pages with an explicit total (via `a.last`, `label span`,
/// `<select>` options, numbered page links, or the confirmed final page where
/// `a.nxt` is absent) from directional-only mobile pagers that only emit
/// `a.prev` / `a.nxt`.
DiscuzHtmlPager parseDiscuzHtmlPager(
  html_dom.Document document, {
  required int fallbackPage,
  required String? Function(String? raw) resolveUrl,
  required int Function(String? resolvedUrl) extractPageFromUrl,
}) {
  final normalizedFallback = fallbackPage > 0 ? fallbackPage : 1;
  final pager = document.querySelector('.pg');
  if (pager == null) {
    return DiscuzHtmlPager(
      currentPage: normalizedFallback,
      lastPage: null,
      previousPageUrl: null,
      nextPageUrl: null,
      hasPager: false,
    );
  }

  final previousPageUrl = resolveUrl(
    pager.querySelector('a.prev')?.attributes['href'],
  );
  final nextPageUrl = resolveUrl(
    pager.querySelector('a.nxt')?.attributes['href'],
  );

  final currentPage = _parseCurrentPage(
    pager,
    fallbackPage: normalizedFallback,
  );
  final lastPage = _parseLastPage(
    pager,
    currentPage: currentPage,
    nextPageUrl: nextPageUrl,
    resolveUrl: resolveUrl,
    extractPageFromUrl: extractPageFromUrl,
  );

  return DiscuzHtmlPager(
    currentPage: currentPage,
    lastPage: lastPage,
    previousPageUrl: previousPageUrl,
    nextPageUrl: nextPageUrl,
    hasPager: true,
  );
}

int _parseCurrentPage(html_dom.Element pager, {required int fallbackPage}) {
  final strongInt = _positiveInt(pager.querySelector('strong')?.text);
  if (strongInt != null) {
    return strongInt;
  }

  for (final option in pager.querySelectorAll('select option')) {
    if (!option.attributes.containsKey('selected')) {
      continue;
    }
    final fromValue = _positiveInt(option.attributes['value']);
    if (fromValue != null) {
      return fromValue;
    }
    final fromText = _positiveInt(option.text);
    if (fromText != null) {
      return fromText;
    }
  }

  final customPage = _positiveInt(
    pager.querySelector('input[name="custompage"]')?.attributes['value'],
  );
  if (customPage != null) {
    return customPage;
  }

  return fallbackPage;
}

int? _parseLastPage(
  html_dom.Element pager, {
  required int currentPage,
  required String? nextPageUrl,
  required String? Function(String? raw) resolveUrl,
  required int Function(String? resolvedUrl) extractPageFromUrl,
}) {
  int? exactTotal;

  // 1. Explicit `a.last` link.
  final lastAnchor = pager.querySelector('a.last');
  if (lastAnchor != null) {
    final fromText = _positiveInt(lastAnchor.text);
    final fromHref = extractPageFromUrl(
      resolveUrl(lastAnchor.attributes['href']),
    );
    final candidate = fromText ?? (fromHref > 0 ? fromHref : null);
    if (candidate != null) {
      exactTotal = candidate;
    }
  }

  // 2. `.pg label span` (`/ N 页` or `title="共 N 页"`).
  if (exactTotal == null) {
    final labelSpan = pager.querySelector('label span');
    if (labelSpan != null) {
      final visibleMatch = _slashTotalPattern.firstMatch(labelSpan.text);
      final visibleTotal = _positiveInt(visibleMatch?.group(1));
      final titleMatch = _firstIntPattern.firstMatch(
        labelSpan.attributes['title'] ?? '',
      );
      final titleTotal = _positiveInt(titleMatch?.group(0));
      exactTotal = visibleTotal ?? titleTotal;
    }
  }

  // 3. Mobile `<select>` pager options.
  if (exactTotal == null) {
    final options = pager.querySelectorAll('select option');
    if (options.isNotEmpty) {
      var selectMax = 0;
      var hasSlashTotal = false;
      for (final option in options) {
        final slashMatch = _slashTotalPattern.firstMatch(option.text);
        final slashVal = _positiveInt(slashMatch?.group(1));
        if (slashVal != null) {
          hasSlashTotal = true;
          if (slashVal > selectMax) {
            selectMax = slashVal;
          }
        }
        final valInt = _positiveInt(option.attributes['value']);
        if (valInt != null && valInt > selectMax) {
          selectMax = valInt;
        }
      }
      if (selectMax > 0 && (options.length > 1 || hasSlashTotal)) {
        exactTotal = selectMax;
      }
    }
  }

  // 4. Numbered page anchors (excluding directional `prev`, `nxt`, `pgb`).
  var maxNumberedPage = 0;
  for (final anchor in pager.querySelectorAll('a[href]')) {
    if (anchor.classes.contains('prev') ||
        anchor.classes.contains('nxt') ||
        anchor.classes.contains('pgb')) {
      continue;
    }
    final cleaned = anchor.text.replaceAll('\u00A0', ' ').trim();
    final textMatch = _numberedAnchorTextPattern.firstMatch(cleaned);
    if (textMatch == null && !anchor.classes.contains('last')) {
      continue;
    }
    final fromHref = extractPageFromUrl(resolveUrl(anchor.attributes['href']));
    final fromText = _positiveInt(textMatch?.group(1)) ?? 0;
    final page = fromHref > 0 ? fromHref : fromText;
    if (page > maxNumberedPage) {
      maxNumberedPage = page;
    }
  }

  if (exactTotal == null) {
    if (nextPageUrl == null) {
      exactTotal = math.max(currentPage, maxNumberedPage);
    } else if (maxNumberedPage > 0) {
      exactTotal = math.max(currentPage, maxNumberedPage);
    }
  }

  if (exactTotal == null) {
    return null;
  }
  return math.max(exactTotal, currentPage);
}

int? _positiveInt(String? source) {
  if (source == null) {
    return null;
  }
  final match = _firstIntPattern.firstMatch(source);
  final value = int.tryParse(match?.group(0) ?? '');
  return value != null && value > 0 ? value : null;
}
