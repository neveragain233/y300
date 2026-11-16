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

  static const currentRevision = 3;

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

  /// 只承载文字格式的行内元素。Discuz 旧内容常把它们错误地包在块级元素外，
  /// 形成 `<font><div>段落</div></font>`，使分页把它们当作复杂块处理。
  static const _inlineFormattingTags = <String>{
    'b',
    'del',
    'em',
    'font',
    'i',
    'ins',
    'mark',
    's',
    'small',
    'span',
    'strike',
    'strong',
    'u',
  };

  static final _blockBreakCandidatePattern = RegExp(
    r'<br\b[^>]*>',
    caseSensitive: false,
  );

  @override
  NovelReaderLegacyMarkupNormalizationResult normalize(String html) {
    final hasFontFace = _fontFaceCandidatePattern.hasMatch(html);
    final hasBlockTag = _blockTagCandidatePattern.hasMatch(html);
    final hasBlockBreak =
        _blockBreakCandidatePattern.hasMatch(html) && hasBlockTag;
    // A formatting element plus a block tag can still mean valid nesting such
    // as `<font>` inside `<div>`; only the parsed tree decides whether a
    // transformation is needed.
    final mayNestBlockInInline =
        hasBlockTag && _inlineFormattingCandidatePattern.hasMatch(html);
    if (!hasFontFace && !hasBlockBreak && !mayNestBlockInInline) {
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
      _removeBlockAdjacentBreaks(fragment, reasonCounts);
    }
    if (mayNestBlockInInline) {
      _hoistBlocksOutOfInlineFormatting(fragment, reasonCounts);
      _pruneEmptyInlineFormatting(fragment);
      _unwrapStructuralWrappers(fragment, reasonCounts);
      // 拆分后可能把原本嵌在行内元素里的 `<br>` 移到块级元素旁边。
      _removeBlockAdjacentBreaks(fragment, reasonCounts);
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

  void _removeBlockAdjacentBreaks(
    html_dom.DocumentFragment fragment,
    Map<NovelReaderLegacyMarkupNormalizationReason, int> reasonCounts,
  ) {
    for (final br in fragment.querySelectorAll('br').toList(growable: false)) {
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

  /// 后序遍历：先把更深层的行内格式拆开，再处理当前元素，这样连续多层的
  /// `<font><font><div>段落</div></font></font>` 会逐层收敛为
  /// `<div><font><font>段落</font></font></div>`。
  void _hoistBlocksOutOfInlineFormatting(
    html_dom.Node parent,
    Map<NovelReaderLegacyMarkupNormalizationReason, int> reasonCounts,
  ) {
    for (final child in parent.nodes.toList(growable: false)) {
      if (child is html_dom.Element) {
        _hoistBlocksOutOfInlineFormatting(child, reasonCounts);
      }
    }
    for (final child in parent.nodes.toList(growable: false)) {
      if (child is! html_dom.Element) {
        continue;
      }
      final tag = child.localName?.toLowerCase();
      if (!_inlineFormattingTags.contains(tag) || !_hasBlockChild(child)) {
        continue;
      }
      _splitInlineElement(child);
      reasonCounts.update(
        NovelReaderLegacyMarkupNormalizationReason.inlineFormattingBlockSplit,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  /// 拆分后会留下只承载空白的 `<font>` 等行内格式壳。它们既无文字也无换行，
  /// 却会阻止上层布局 div 被识别为纯结构容器。
  void _pruneEmptyInlineFormatting(html_dom.DocumentFragment fragment) {
    final candidates = fragment
        .querySelectorAll(_inlineFormattingTags.join(','))
        .toList(growable: false)
        .reversed;
    for (final element in candidates) {
      if (element.parent != null && _isEmptyFormattingElement(element)) {
        element.remove();
      }
    }
  }

  bool _isEmptyFormattingElement(html_dom.Element element) {
    final tag = element.localName?.toLowerCase();
    if (!_inlineFormattingTags.contains(tag)) {
      return false;
    }
    for (final child in element.nodes) {
      if (child is html_dom.Text) {
        if (child.data.trim().isNotEmpty) {
          return false;
        }
        continue;
      }
      if (child is html_dom.Element) {
        if (!_isEmptyFormattingElement(child)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _hasBlockChild(html_dom.Element element) {
    for (final child in element.nodes) {
      if (child is html_dom.Element &&
          _blockTags.contains(child.localName?.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// 把行内格式元素的块级子元素提到父级，并让块级元素继承该格式：
  /// `<font><div>p</div></font>` → `<div><font>p</font></div>`。
  void _splitInlineElement(html_dom.Element inline) {
    final parent = inline.parent;
    if (parent == null) {
      return;
    }
    final replacement = <html_dom.Node>[];
    var buffer = <html_dom.Node>[];

    void flushInlineBuffer() {
      if (buffer.isEmpty) {
        return;
      }
      final wrapper = inline.clone(false);
      for (final node in buffer) {
        wrapper.append(node);
      }
      replacement.add(wrapper);
      buffer = <html_dom.Node>[];
    }

    for (final child in inline.nodes.toList(growable: false)) {
      if (child is html_dom.Element &&
          _blockTags.contains(child.localName?.toLowerCase())) {
        flushInlineBuffer();
        final wrapper = inline.clone(false);
        for (final node in child.nodes.toList(growable: false)) {
          wrapper.append(node);
        }
        if (wrapper.nodes.isNotEmpty) {
          child.append(wrapper);
        }
        replacement.add(child);
      } else {
        buffer.add(child);
      }
    }
    flushInlineBuffer();

    final index = parent.nodes.indexOf(inline);
    inline.remove();
    if (index < 0) {
      parent.nodes.addAll(replacement);
      return;
    }
    parent.nodes.insertAll(index, replacement);
  }

  /// 后序遍历展开只承载块级子元素的布局 div，让段落成为顶层节点；带样式、
  /// 类名或非左对齐的容器保留，避免丢失作者布局。
  void _unwrapStructuralWrappers(
    html_dom.Node parent,
    Map<NovelReaderLegacyMarkupNormalizationReason, int> reasonCounts,
  ) {
    for (final child in parent.nodes.toList(growable: false)) {
      if (child is html_dom.Element) {
        _unwrapStructuralWrappers(child, reasonCounts);
      }
    }
    for (final child in parent.nodes.toList(growable: false)) {
      if (child is! html_dom.Element || !_isStructuralWrapper(child)) {
        continue;
      }
      final index = parent.nodes.indexOf(child);
      child.remove();
      if (index < 0) {
        continue;
      }
      parent.nodes.insertAll(index, child.nodes.toList(growable: false));
      child.nodes.clear();
      reasonCounts.update(
        NovelReaderLegacyMarkupNormalizationReason.structuralWrapperUnwrapped,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  bool _isStructuralWrapper(html_dom.Element element) {
    if (element.localName?.toLowerCase() != 'div') {
      return false;
    }
    if (element.classes.isNotEmpty) {
      return false;
    }
    for (final name in element.attributes.keys) {
      final normalized = name.toString().toLowerCase();
      if (normalized != 'align') {
        return false;
      }
    }
    final align = element.attributes['align']?.trim().toLowerCase();
    if (align != null && align != 'left') {
      return false;
    }
    var hasBlockChild = false;
    for (final child in element.nodes) {
      if (child is html_dom.Text) {
        if (child.data.trim().isNotEmpty) {
          return false;
        }
        continue;
      }
      if (child is html_dom.Comment) {
        continue;
      }
      if (child is html_dom.Element &&
          _blockTags.contains(child.localName?.toLowerCase())) {
        hasBlockChild = true;
        continue;
      }
      return false;
    }
    return hasBlockChild;
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
  static final _inlineFormattingCandidatePattern = RegExp(
    r'<(?:b|del|em|font|i|ins|mark|small|span|s|strike|strong|u)\b',
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
