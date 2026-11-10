import 'package:html/dom.dart' as html_dom;
import 'package:y300/features/novel/presentation/models/novel_reader_legacy_markup_normalization.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';

abstract interface class NovelReaderLegacyMarkupNormalizer {
  int get revision;

  NovelReaderLegacyMarkupNormalizationResult normalize(String html);
}

final class DefaultNovelReaderLegacyMarkupNormalizer
    implements NovelReaderLegacyMarkupNormalizer {
  const DefaultNovelReaderLegacyMarkupNormalizer({
    ForumHtmlFragmentCodec fragmentCodec =
        const HtmlPackageForumHtmlFragmentCodec(),
  }) : _fragmentCodec = fragmentCodec;

  static const currentRevision = 2;

  final ForumHtmlFragmentCodec _fragmentCodec;

  @override
  int get revision => currentRevision;

  static const _blockTags = <String>{
    'address',
    'article',
    'aside',
    'blockquote',
    'center',
    'details',
    'div',
    'dl',
    'figure',
    'footer',
    'form',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'header',
    'hr',
    'li',
    'main',
    'nav',
    'ol',
    'p',
    'pre',
    'section',
    'summary',
    'table',
    'tbody',
    'td',
    'tfoot',
    'th',
    'thead',
    'tr',
    'ul',
  };

  static const _preformattedTags = <String>{'pre', 'code', 'textarea'};

  static final _blockBreakCandidatePattern = RegExp(
    r'<br\b[^>]*>',
    caseSensitive: false,
  );

  @override
  NovelReaderLegacyMarkupNormalizationResult normalize(String html) {
    final hasFontFace = _fontFaceCandidatePattern.hasMatch(html);
    final hasBlockBreak =
        _blockBreakCandidatePattern.hasMatch(html) &&
        _blockTagCandidatePattern.hasMatch(html);
    if (!hasFontFace && !hasBlockBreak) {
      return NovelReaderLegacyMarkupNormalizationResult(
        html: html,
        summary: const NovelReaderLegacyMarkupNormalizationSummary(
          revision: currentRevision,
          normalizedAttributeCount: 0,
        ),
      );
    }
    final fragment = _fragmentCodec.parse(html);
    final reasonCounts = <NovelReaderLegacyMarkupNormalizationReason, int>{};

    for (final font in fragment.querySelectorAll('font[face]')) {
      final reason = _invalidFaceReason(font.attributes['face'] ?? '');
      if (reason == null) {
        continue;
      }
      font.attributes.remove('face');
      reasonCounts.update(reason, (count) => count + 1, ifAbsent: () => 1);
    }

    if (hasBlockBreak) {
      for (final br in fragment.querySelectorAll('br')) {
        if (_hasPreformattedAncestor(br) || !_isBlockAdjacentBreak(br)) {
          continue;
        }
        br.remove();
        reasonCounts.update(
          NovelReaderLegacyMarkupNormalizationReason.blockAdjacentLineBreak,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final count = reasonCounts.values.fold<int>(
      0,
      (total, value) => total + value,
    );
    return NovelReaderLegacyMarkupNormalizationResult(
      html: count == 0 ? html : _fragmentCodec.serialize(fragment),
      summary: NovelReaderLegacyMarkupNormalizationSummary(
        revision: revision,
        normalizedAttributeCount: count,
        reasonCounts:
            Map<NovelReaderLegacyMarkupNormalizationReason, int>.unmodifiable(
              reasonCounts,
            ),
      ),
    );
  }

  bool _hasPreformattedAncestor(html_dom.Element element) {
    for (var node = element.parent; node != null; node = node.parent) {
      if (_preformattedTags.contains(node.localName?.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// `<div>…</div><br>` 在 HTML renderer 里不会多出一行：块级元素已经换行，
  /// 紧随其后的 br 被折叠。前后相邻元素任一是块级元素时都按折叠处理；顶层
  /// 节点的 parent 可能为空，因此只用元素兄弟而不是父节点索引。
  bool _isBlockAdjacentBreak(html_dom.Element br) {
    final previous = br.previousElementSibling;
    if (previous != null &&
        _blockTags.contains(previous.localName?.toLowerCase())) {
      return true;
    }
    final next = br.nextElementSibling;
    return next != null && _blockTags.contains(next.localName?.toLowerCase());
  }

  NovelReaderLegacyMarkupNormalizationReason? _invalidFaceReason(String face) {
    final trimmed = face.trim();
    if (trimmed.isEmpty) {
      return NovelReaderLegacyMarkupNormalizationReason.emptyFontFace;
    }

    final decoded = _decodeQuoteEntities(trimmed);
    var hasUsableToken = false;
    for (final rune in decoded.runes) {
      if (_isFamilyDelimiter(rune)) {
        continue;
      }
      hasUsableToken = true;
      break;
    }
    if (hasUsableToken) {
      return null;
    }
    return decoded.contains(',')
        ? NovelReaderLegacyMarkupNormalizationReason
              .invalidNoUsableFontFamilyToken
        : NovelReaderLegacyMarkupNormalizationReason.invalidQuoteOnlyFontFace;
  }

  String _decodeQuoteEntities(String value) {
    var decoded = value;
    for (var pass = 0; pass < 3; pass++) {
      final next = decoded.replaceAllMapped(_quoteEntityPattern, (match) {
        final entity = match.group(0)!.toLowerCase();
        return entity.contains('apos') ||
                entity.contains('39') ||
                entity.contains('27')
            ? "'"
            : '"';
      });
      if (next == decoded) {
        break;
      }
      decoded = next;
    }
    return decoded;
  }

  bool _isFamilyDelimiter(int rune) {
    if (rune == 0x22 || rune == 0x27 || rune == 0x2C || rune == 0x3000) {
      return true;
    }
    return String.fromCharCode(rune).trim().isEmpty;
  }

  static final _quoteEntityPattern = RegExp(
    r'&(?:quot|apos|#0*34|#x0*22|#0*39|#x0*27);?',
    caseSensitive: false,
  );
  static final _fontFaceCandidatePattern = RegExp(
    r'<font\b[^>]*\bface\b',
    caseSensitive: false,
  );
  static final _blockTagCandidatePattern = RegExp(
    r'<(?:div|p|table|tbody|thead|tr|td|th|ul|ol|li|blockquote|h[1-6]|hr|center|pre)\b',
    caseSensitive: false,
  );
}

final class NoopNovelReaderLegacyMarkupNormalizer
    implements NovelReaderLegacyMarkupNormalizer {
  const NoopNovelReaderLegacyMarkupNormalizer();

  @override
  int get revision => 0;

  @override
  NovelReaderLegacyMarkupNormalizationResult normalize(String html) {
    return NovelReaderLegacyMarkupNormalizationResult(
      html: html,
      summary: NovelReaderLegacyMarkupNormalizationSummary.none,
    );
  }
}
