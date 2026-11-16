import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:y300/features/novel/domain/models/novel_reader_preferences.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_paragraph_indent_projection.dart';

void main() {
  const projection = NovelReaderParagraphIndentProjection();
  const indent = NovelReaderParagraphIndentProjection.indentText;

  String project(
    String html, {
    NovelReaderParagraphIndentMode mode =
        NovelReaderParagraphIndentMode.increase,
    bool startsParagraph = true,
  }) => projection.project(html, mode: mode, startsParagraph: startsParagraph);

  String textOf(String html) =>
      (html_parser.parseFragment(html).text ?? '').replaceAll('\n', '');

  test('increase adds one indent per ordinary paragraph start', () {
    final result = project('<p>正文甲</p><p>正文乙<br>乙二</p>');

    expect(RegExp(indent).allMatches(result).length, 3);
    expect(textOf(result), '$indent正文甲$indent正文乙$indent乙二');
  });

  test('increase normalizes existing author indentation to two widths', () {
    final fullWidth = project('<p>\u3000\u3000已有缩进</p>');
    final twoSpaces = project('<p>  已有缩进</p>');
    final sixNbsp = project('<p>\u00a0 \u00a0 \u00a0 \u00a0正文</p>');

    expect(fullWidth, '<p>$indent已有缩进</p>');
    expect(twoSpaces, '<p>$indent已有缩进</p>');
    expect(sixNbsp, '<p>$indent正文</p>');
    expect(RegExp(indent).allMatches(fullWidth).length, 1);
  });

  test('remove strips author indentation inside inline formatting', () {
    final nested = project(
      '<div align="left"><font>\u00a0 \u00a0 \u00a0 \u00a0正文</font></div>',
      mode: NovelReaderParagraphIndentMode.remove,
    );
    final twoLevels = project(
      '<div><span><font>\u3000\u3000正文</font></span></div>',
      mode: NovelReaderParagraphIndentMode.remove,
    );

    expect(nested, contains('正文'));
    expect(nested, isNot(contains('\u00a0')));
    expect(twoLevels, contains('正文'));
    expect(twoLevels, isNot(contains('\u3000')));
  });

  test('increase replaces inline author indentation without stacking', () {
    final result = project(
      '<div align="left"><font>\u00a0 \u00a0 \u00a0 \u00a0正文</font></div>',
    );

    expect(RegExp(indent).allMatches(result).length, 1);
    expect(result, isNot(contains('\u00a0')));
    expect(result, contains(indent));
  });

  test('increase keeps inline markup and inserts before its first text', () {
    final result = project('<p><span style="color:#123456">红色</span>正文</p>');

    expect(result, contains('<span style="color:#123456">红色</span>'));
    expect(result.indexOf(indent), lessThan(result.indexOf('红色')));
  });

  test('mid-paragraph chunks only indent after a hard break', () {
    final result = project('<p>续段<br>新段</p>', startsParagraph: false);

    expect(RegExp(indent).allMatches(result).length, 1);
    expect(result, contains('续段<br>$indent新段'));
  });

  test('remove strips half, full and no-break spaces at paragraph starts', () {
    final result = project(
      '<p>\u3000\u3000去除<br> 半角<br>\u00A0不换行</p>',
      mode: NovelReaderParagraphIndentMode.remove,
    );

    expect(textOf(result), '去除半角不换行');
  });

  test('remove keeps interior whitespace and special layout blocks', () {
    const source =
        '<p>前 中 后</p><h2>标题</h2><blockquote><p>引用</p></blockquote>'
        '<pre>\u3000代码</pre><ul><li>列表</li></ul>'
        '<div style="text-align:center">居中</div>';
    final result = project(source, mode: NovelReaderParagraphIndentMode.remove);

    expect(result, contains('前 中 后'));
    expect(result, contains('<h2>标题</h2>'));
    expect(result, contains('<blockquote><p>引用</p></blockquote>'));
    expect(result, contains('\u3000代码'));
    expect(result, contains('<li>列表</li>'));
    expect(result, contains('居中'));
  });

  test(
    'paragraphs with complex inline content stay unindented in both modes',
    () {
      const source =
          '<p>图片段<img src="https://example.invalid/a.png"></p>'
          '<p><ruby>字<rt>じ</rt></ruby>注音段</p>'
          '<div><p>嵌套段落甲</p><p>嵌套段落乙</p></div>';
      final result = project(source);

      expect(RegExp(indent).allMatches(result).length, 2);
      expect(result, contains('<p>图片段<img'));
      expect(result, contains('<p><ruby>字<rt>じ</rt></ruby>注音段</p>'));
      expect(result, contains('$indent嵌套段落甲'));
      expect(result, contains('$indent嵌套段落乙'));
    },
  );

  test('keep mode returns the original string', () {
    const source = '<p>\u3000\u3000原文<br>第二段</p>';

    expect(
      project(source, mode: NovelReaderParagraphIndentMode.keep),
      same(source),
    );
  });
}
