import 'package:html/dom.dart' as html_dom;
import 'package:y300/features/novel/domain/models/novel_reader_preferences.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';

/// Display-only first-line indentation for novel body paragraphs.
///
/// The prepared chapter, its semantic anchors and every source offset stay
/// untouched: this projection runs on the HTML handed to the renderer and to
/// pagination measurement, where both sides see identical text. Changing the
/// mode therefore cannot re-interpret a persisted reading anchor.
final class NovelReaderParagraphIndentProjection {
  const NovelReaderParagraphIndentProjection({
    this.fragmentCodec = const HtmlPackageForumHtmlFragmentCodec(),
  });

  final ForumHtmlFragmentCodec fragmentCodec;

  /// One ordinary full-width character per indent position.
  static const String indentText = '\u3000\u3000';

  static final RegExp _leadingIndentWhitespace = RegExp(
    r'^[\t \u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]+',
  );
  static final RegExp _centeredOrRightAlign = RegExp(
    r'text-align\s*:\s*(?:center|right|end)',
    caseSensitive: false,
  );

  static const Set<String> _blockTags = <String>{
    'address',
    'article',
    'aside',
    'blockquote',
    'center',
    'dd',
    'details',
    'dialog',
    'div',
    'dl',
    'dt',
    'fieldset',
    'figcaption',
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
    'hgroup',
    'hr',
    'li',
    'main',
    'nav',
    'ol',
    'p',
    'pre',
    'section',
    'table',
    'ul',
  };

  /// Blocks whose structure carries its own layout intent. They keep the
  /// author's original spacing and never receive synthetic indentation.
  static const Set<String> _protectedTags = <String>{
    'blockquote',
    'center',
    'code',
    'dd',
    'dl',
    'dt',
    'figcaption',
    'figure',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'hr',
    'li',
    'ol',
    'pre',
    'table',
    'textarea',
    'ul',
  };

  static const Set<String> _protectedClasses = <String>{
    'quote',
    'blockcode',
    'showcollapse',
    'showcollapse_box',
    'showcollapse_gather',
    'pstatus',
  };

  /// Paged mode measures and renders complex units as their own HTML, where
  /// display-only indentation cannot be projected without moving source
  /// coordinates. Such paragraphs keep the same unindented form in both modes.
  static const String _complexInlineSelector =
      'img, ruby, table, pre, code, blockquote, ul, ol, hr, video, audio, '
      'iframe, .showcollapse, .showcollapse_box, .showcollapse_gather, '
      '.blockcode, .quote';

  String project(
    String html, {
    required NovelReaderParagraphIndentMode mode,
    required bool startsParagraph,
  }) {
    if (mode == NovelReaderParagraphIndentMode.keep || html.isEmpty) {
      return html;
    }
    final fragment = fragmentCodec.parse(html);
    final projector = _ParagraphIndentProjector(mode);
    if (!projector.project(fragment, startsParagraph: startsParagraph)) {
      return html;
    }
    return fragmentCodec.serialize(fragment);
  }
}

enum _TextProjection { untouched, consumedParagraphStart, removed }

final class _ParagraphIndentProjector {
  _ParagraphIndentProjector(this.mode);

  final NovelReaderParagraphIndentMode mode;
  var _changed = false;

  /// Returns true when the document was rewritten.
  bool project(
    html_dom.DocumentFragment fragment, {
    required bool startsParagraph,
  }) {
    _projectContainer(
      fragment,
      atParagraphStart: startsParagraph,
      protectedScope: false,
      fragmentRoot: true,
    );
    return _changed;
  }

  void _projectContainer(
    html_dom.Node parent, {
    required bool atParagraphStart,
    required bool protectedScope,
    bool fragmentRoot = false,
  }) {
    var atStart = atParagraphStart;
    var seenRenderable = false;
    var index = 0;
    while (index < parent.nodes.length) {
      final node = parent.nodes[index];
      if (node is html_dom.Text) {
        if (protectedScope) {
          index += 1;
          continue;
        }
        final result = _projectText(parent, index, node, atStart);
        switch (result) {
          case _TextProjection.removed:
            continue;
          case _TextProjection.consumedParagraphStart:
            atStart = false;
            seenRenderable = seenRenderable || node.data.trim().isNotEmpty;
            index += 1;
            break;
          case _TextProjection.untouched:
            if (node.data.trim().isNotEmpty) {
              atStart = false;
              seenRenderable = true;
            }
            index += 1;
            break;
        }
        continue;
      }
      if (node is html_dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        if (tag == 'br') {
          if (!protectedScope) {
            atStart = true;
          }
          index += 1;
          continue;
        }
        final isBlock = NovelReaderParagraphIndentProjection._blockTags
            .contains(tag);
        final tagProtected =
            protectedScope ||
            NovelReaderParagraphIndentProjection._protectedTags.contains(tag) ||
            node.classes.any(
              NovelReaderParagraphIndentProjection._protectedClasses.contains,
            ) ||
            NovelReaderParagraphIndentProjection._centeredOrRightAlign.hasMatch(
              node.attributes['style'] ?? '',
            ) ||
            (isBlock && !_hasNestedBlock(node) && _hasComplexInline(node));
        if (tagProtected) {
          _projectContainer(
            node,
            atParagraphStart: false,
            protectedScope: true,
          );
          seenRenderable = seenRenderable || _hasRenderableContent(node);
          atStart = isBlock;
          index += 1;
          continue;
        }
        if (!isBlock && atStart) {
          // Inline content owns the paragraph start. Increase normalizes the
          // first line to exactly two indent widths: existing author
          // indentation is replaced, not stacked. The indent lives in this
          // container so its glyph metrics match the TextPainter layout.
          final inserted =
              mode == NovelReaderParagraphIndentMode.increase &&
              _firstTextNode(node) != null;
          if (inserted) {
            _stripLeadingIndentWhitespace(node);
            parent.nodes.insert(
              index,
              html_dom.Text(NovelReaderParagraphIndentProjection.indentText),
            );
            _changed = true;
          }
          _projectContainer(
            node,
            // Remove must strip author indentation whether or not it was
            // already recognized as an author-provided indent.
            atParagraphStart: mode == NovelReaderParagraphIndentMode.remove,
            protectedScope: false,
          );
          seenRenderable = seenRenderable || _hasRenderableContent(node);
          atStart = false;
          index += inserted ? 2 : 1;
          continue;
        }
        // Only the first top-level block inherits the caller's paragraph
        // state; every later block starts a new paragraph of its own.
        final blockStart = fragmentRoot && !seenRenderable
            ? atStart
            : isBlock
            ? true
            : atStart;
        _projectContainer(
          node,
          atParagraphStart: blockStart,
          protectedScope: false,
        );
        seenRenderable = seenRenderable || _hasRenderableContent(node);
        atStart = isBlock;
        index += 1;
        continue;
      }
      index += 1;
    }
  }

  _TextProjection _projectText(
    html_dom.Node parent,
    int index,
    html_dom.Text node,
    bool atParagraphStart,
  ) {
    if (!atParagraphStart) {
      return _TextProjection.untouched;
    }
    final data = node.data;
    if (data.isEmpty) {
      return _TextProjection.untouched;
    }
    switch (mode) {
      case NovelReaderParagraphIndentMode.keep:
        return _TextProjection.untouched;
      case NovelReaderParagraphIndentMode.increase:
        if (data.trim().isEmpty) {
          parent.nodes.removeAt(index);
          _changed = true;
          return _TextProjection.removed;
        }
        final stripped = data.replaceFirst(
          NovelReaderParagraphIndentProjection._leadingIndentWhitespace,
          '',
        );
        if (stripped.isEmpty) {
          parent.nodes.removeAt(index);
          _changed = true;
          return _TextProjection.removed;
        }
        parent.nodes.insert(
          index,
          html_dom.Text(NovelReaderParagraphIndentProjection.indentText),
        );
        if (stripped != data) {
          node.data = stripped;
        }
        _changed = true;
        return _TextProjection.consumedParagraphStart;
      case NovelReaderParagraphIndentMode.remove:
        final stripped = data.replaceFirst(
          NovelReaderParagraphIndentProjection._leadingIndentWhitespace,
          '',
        );
        if (stripped == data) {
          return _TextProjection.untouched;
        }
        _changed = true;
        if (stripped.isEmpty) {
          parent.nodes.removeAt(index);
          return _TextProjection.removed;
        }
        node.data = stripped;
        return _TextProjection.consumedParagraphStart;
    }
  }

  /// Replaces existing author indentation at the paragraph start with the
  /// normalized two-character indent. Walks inline formatting wrappers and
  /// stops at the first non-whitespace text.
  void _stripLeadingIndentWhitespace(html_dom.Node node) {
    if (node is html_dom.Text) {
      final stripped = node.data.replaceFirst(
        NovelReaderParagraphIndentProjection._leadingIndentWhitespace,
        '',
      );
      if (stripped.isEmpty) {
        if (node.data.isNotEmpty) {
          node.remove();
          _changed = true;
        }
        return;
      }
      if (stripped != node.data) {
        node.data = stripped;
        _changed = true;
      }
      return;
    }
    if (node is! html_dom.Element) {
      return;
    }
    final tag = node.localName?.toLowerCase();
    // Line breaks and media own the visual start; do not strip across them.
    if (tag == 'br' ||
        tag == 'img' ||
        tag == 'hr' ||
        tag == 'video' ||
        tag == 'audio' ||
        tag == 'iframe') {
      return;
    }
    for (final child in node.nodes.toList(growable: false)) {
      _stripLeadingIndentWhitespace(child);
      if (_hasNonWhitespaceText(child)) {
        return;
      }
    }
  }

  bool _hasNonWhitespaceText(html_dom.Node node) {
    if (node is html_dom.Text) {
      return node.data.trim().isNotEmpty;
    }
    if (node is html_dom.Element) {
      return node.nodes.any(_hasNonWhitespaceText);
    }
    return false;
  }

  html_dom.Text? _firstTextNode(html_dom.Node node) {
    if (node is html_dom.Text) {
      return node.data.isEmpty ? null : node;
    }
    if (node is html_dom.Element) {
      for (final child in node.nodes) {
        final text = _firstTextNode(child);
        if (text != null) {
          return text;
        }
      }
    }
    return null;
  }

  bool _hasNestedBlock(html_dom.Element element) {
    for (final child in element.querySelectorAll(
      NovelReaderParagraphIndentProjection._blockTags.join(','),
    )) {
      if (child != element) {
        return true;
      }
    }
    return false;
  }

  bool _hasComplexInline(html_dom.Element element) {
    return element.querySelector(
          NovelReaderParagraphIndentProjection._complexInlineSelector,
        ) !=
        null;
  }

  bool _hasRenderableContent(html_dom.Element element) {
    return element.text.trim().isNotEmpty ||
        element.querySelector('img, hr, video, audio, iframe') != null;
  }
}
