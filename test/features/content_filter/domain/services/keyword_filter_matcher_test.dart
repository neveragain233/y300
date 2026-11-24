import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/services/keyword_filter_matcher.dart';

BlockedKeyword _rule(
  String keyword, {
  String id = 'id-1',
  BlockedKeywordScope scope = BlockedKeywordScope.repliesOnly,
}) {
  final now = DateTime(2026, 11, 24);
  return BlockedKeyword(
    id: id,
    keyword: keyword,
    normalizedKeyword: normalizeBlockedKeyword(keyword),
    scope: scope,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('KeywordFilterMatcher', () {
    test('normalizes case and whitespace in plain text and regex chars', () {
      final rules = [_rule('SPOILER   alert+1')];

      expect(
        KeywordFilterMatcher.matchPlainText(
          'This has a spoiler alert+1 inside',
          rules,
        )?.keyword,
        'SPOILER   alert+1',
      );
      expect(
        KeywordFilterMatcher.matchPlainText('No match here', rules),
        isNull,
      );
    });

    test('matches against converted text when primary differs', () {
      final rules = [_rule('剧透')];

      final matched = KeywordFilterMatcher.matchPlainText(
        '含劇透內容',
        rules,
        convertedText: '含剧透内容',
      );
      expect(matched?.keyword, '剧透');
    });

    test('ignores HTML tag names, attributes, URLs, scripts and styles', () {
      final rules = [_rule('spoiler')];
      const html = '''
        <style>.spoiler { color: red; }</style>
        <script>const spoiler = 1;</script>
        <p data-spoiler="true"><a href="https://example.com/spoiler">正常链接文本</a></p>
      ''';

      expect(
        KeywordFilterMatcher.matchHtmlBody(html, rules, excludeQuotes: false),
        isNull,
      );
    });

    test('excludes quote blocks when matching reply bodies', () {
      final rules = [_rule('剧透')];
      const html = '''
        <div class="quote"><blockquote><b>甲</b>: 这里有剧透</blockquote></div>
        <p>同意楼上，不要理会。</p>
      ''';

      expect(
        KeywordFilterMatcher.matchHtmlBody(html, rules, excludeQuotes: true),
        isNull,
      );
      expect(
        KeywordFilterMatcher.matchHtmlBody(
          html,
          rules,
          excludeQuotes: false,
        )?.keyword,
        '剧透',
      );
    });

    test('masks matched quote blocks while preserving quote wrapper and non-matching quotes', () {
      final rules = [_rule('剧透')];
      const html = '''
        <div class="quote"><blockquote><b>甲</b>: 包含剧透和<img src="x.jpg"></blockquote></div>
        <div class="quote"><blockquote><b>乙</b>: 正常讨论</blockquote></div>
        <p>正文不受影响</p>
      ''';

      final masked = KeywordFilterMatcher.maskBlockedQuotesInHtml(
        html,
        rules: rules,
        placeholderText: '引用发言因为关键词屏蔽被隐藏',
      );

      expect(masked, contains('引用发言因为关键词屏蔽被隐藏'));
      expect(masked, isNot(contains('包含剧透')));
      expect(masked, isNot(contains('x.jpg')));
      expect(masked, contains('正常讨论'));
      expect(masked, contains('正文不受影响'));
      expect(masked, contains('class="quote"'));
    });
  });
}
