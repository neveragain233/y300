import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/services/keyword_filter_matcher.dart';

BlockedKeyword _rule(
  String keyword, {
  String id = 'id-1',
  BlockedKeywordScope scope = BlockedKeywordScope.repliesOnly,
  BlockedKeywordKind kind = BlockedKeywordKind.block,
  BlockedKeywordMatchType matchType = BlockedKeywordMatchType.plain,
  bool wholeWord = true,
  bool caseSensitive = false,
  bool enabled = true,
}) {
  final now = DateTime(2026, 11, 24);
  return BlockedKeyword(
    id: id,
    keyword: keyword,
    normalizedKeyword: normalizeBlockedKeywordPattern(
      keyword,
      matchType,
      caseSensitive: caseSensitive,
    ),
    scope: scope,
    kind: kind,
    matchType: matchType,
    wholeWord: wholeWord,
    caseSensitive: caseSensitive,
    enabled: enabled,
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

    test('whitelist overrides block rules and disabled rules are ignored', () {
      final block = _rule(
        '剧透',
        id: 'b1',
        scope: BlockedKeywordScope.includeBody,
      );
      final allow = _rule('剧透预警已折叠', id: 'a1', kind: BlockedKeywordKind.allow);
      final disabled = _rule(
        '正常',
        id: 'b2',
        scope: BlockedKeywordScope.includeBody,
        enabled: false,
      );
      final ruleSet = KeywordFilterRuleSet(rules: [block, allow, disabled]);

      expect(
        KeywordFilterMatcher.matchThreadListItem(
          subject: '正常讨论',
          excerpt: '这里有剧透预警已折叠，可放心看',
          ruleSet: ruleSet,
        ),
        isNull,
      );
      expect(
        KeywordFilterMatcher.matchThreadListItem(
          subject: '正常讨论',
          excerpt: '直接剧透结局',
          ruleSet: ruleSet,
        )?.id,
        'b1',
      );
    });

    test(
      'supports case-insensitive regex rules and tolerates invalid regex',
      () {
        final regexBlock = _rule(
          r'\bep\s*\d+\b',
          id: 'r1',
          scope: BlockedKeywordScope.includeBody,
          matchType: BlockedKeywordMatchType.regex,
        );
        final badRegex = _rule(
          '[unclosed',
          id: 'r2',
          scope: BlockedKeywordScope.includeBody,
          matchType: BlockedKeywordMatchType.regex,
        );
        final ruleSet = KeywordFilterRuleSet(rules: [badRegex, regexBlock]);

        expect(
          KeywordFilterMatcher.matchThreadListItem(
            subject: 'Episode EP 12 discussion',
            ruleSet: ruleSet,
          )?.id,
          'r1',
        );
        expect(
          KeywordFilterMatcher.matchThreadListItem(
            subject: 'Deep learning notes',
            ruleSet: ruleSet,
          ),
          isNull,
        );
      },
    );

    test(
      'wholeWord spares Latin substrings while catching boundary and CJK edges',
      () {
        final aiRule = _rule('AI', id: 'r1', wholeWord: true);
        for (final safeText in const <String>[
          'all in',
          'daily',
          'again',
          'detail',
          'kawaii',
          'maid',
          'waifu',
        ]) {
          expect(
            KeywordFilterMatcher.matchPlainText(safeText, <BlockedKeyword>[
              aiRule,
            ]),
            isNull,
            reason: 'Expected "$safeText" not to match whole-word "AI"',
          );
        }
        for (final blockedText in const <String>[
          'AI画图',
          '用AI写的',
          'AI2026',
          'This is AI!',
        ]) {
          expect(
            KeywordFilterMatcher.matchPlainText(blockedText, <BlockedKeyword>[
              aiRule,
            ])?.id,
            'r1',
            reason: 'Expected "$blockedText" to match whole-word "AI"',
          );
        }
        final substringRule = _rule('AI', id: 'r2', wholeWord: false);
        expect(
          KeywordFilterMatcher.matchPlainText('daily', <BlockedKeyword>[
            substringRule,
          ])?.id,
          'r2',
        );
      },
    );

    test('supports caseSensitive, invisible-char stripping, HTML boundaries, and author whitelist', () {
      final upperOnly = _rule('AI', id: 'cs', caseSensitive: true);
      expect(
        KeywordFilterMatcher.matchPlainText('ai tools', <BlockedKeyword>[
          upperOnly,
        ]),
        isNull,
      );
      expect(
        KeywordFilterMatcher.matchPlainText('AI tools', <BlockedKeyword>[
          upperOnly,
        ])?.id,
        'cs',
      );

      final regexCs = _rule(
        r'\bAI\b',
        id: 'rcs',
        matchType: BlockedKeywordMatchType.regex,
        caseSensitive: true,
      );
      expect(
        KeywordFilterMatcher.matchPlainText('ai', <BlockedKeyword>[regexCs]),
        isNull,
      );
      expect(
        KeywordFilterMatcher.matchPlainText('AI', <BlockedKeyword>[
          regexCs,
        ])?.id,
        'rcs',
      );

      final spoiler = _rule('剧透', id: 'sp');
      expect(
        KeywordFilterMatcher.matchPlainText('剧\u200B透预警', <BlockedKeyword>[
          spoiler,
        ])?.id,
        'sp',
      );

      final inRule = _rule('ain', id: 'in', wholeWord: true);
      expect(
        KeywordFilterMatcher.matchHtmlBody(
          '<p>a<img src="x.png">in <a href="https://example.com/ain">https://example.com/ain</a></p>',
          <BlockedKeyword>[inRule],
          excludeQuotes: true,
        ),
        isNull,
      );

      final detail = KeywordFilterMatcher.matchReplyHtmlDetail(
        '<p>这里是包含剧透的正文内容</p>',
        <BlockedKeyword>[spoiler],
        excludeQuotes: true,
        authorId: '1001',
        whitelistedUserIds: const <String>{'1001'},
      );
      expect(detail, isNull);

      final matchedDetail = KeywordFilterMatcher.matchReplyHtmlDetail(
        '<p>这里是包含剧透的正文内容</p>',
        <BlockedKeyword>[spoiler],
        excludeQuotes: true,
        authorId: '1002',
        whitelistedUserIds: const <String>{'1001'},
      );
      expect(matchedDetail?.rule.id, 'sp');
      expect(matchedDetail?.snippet, contains('剧透'));

      final eval = KeywordFilterMatcher.evaluatePlainText(
        '官方AI画图',
        <BlockedKeyword>[
          _rule('官方', id: 'allow', kind: BlockedKeywordKind.allow),
          _rule('AI', id: 'blk'),
        ],
      );
      expect(eval.isBlocked, isFalse);
      expect(eval.matchedAllow?.rule.id, 'allow');
      expect(eval.matchedBlock?.rule.id, 'blk');
    });
  });
}
