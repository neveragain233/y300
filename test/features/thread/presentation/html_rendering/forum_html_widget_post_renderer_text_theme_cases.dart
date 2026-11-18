part of 'forum_html_widget_post_renderer_test.dart';

void _textThemeCases() {
  testWidgets('renders simple HTML text and inline formatting', (tester) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            html: '<p>普通 <strong>加粗</strong></p>',
            sourceId: 'unit',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-html-renderer-unit')), findsOneWidget);
    expect(find.textContaining('普通', findRichText: true), findsOneWidget);
    expect(find.textContaining('加粗', findRichText: true), findsOneWidget);
  });

  testWidgets('forwards link taps to callbacks', (tester) async {
    final tappedUrls = <String>[];
    var interactions = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            html: '<a href="forum.php?mod=viewthread&tid=1">链接</a>',
            sourceId: 'link',
            callbacks: ForumHtmlRenderCallbacks(
              onInteraction: () => interactions += 1,
              onTapUrl: (url) async {
                tappedUrls.add(url);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('链接', findRichText: true));
    await tester.pumpAndSettle();

    expect(tappedUrls, <String>[
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=1',
    ]);
    expect(interactions, 1);
  });

  testWidgets('passes reader preferences to HtmlWidget', (tester) async {
    final preferences = ForumHtmlReaderPreferences.defaults().copyWith(
      typography: const RichTextTypography(
        fontScale: 1.4,
        lineHeightScale: 1.9,
        paragraphSpacing: 22,
      ),
    );

    await tester.pumpWidget(
      LocalizedTestApp(
        theme: ThemeData(
          textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 10)),
        ),
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            html: '<p>段落</p>',
            sourceId: 'prefs',
            preferences: preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final htmlWidget = tester.widget<HtmlWidget>(
      find.byKey(const Key('forum-html-renderer-prefs')),
    );
    expect(htmlWidget.textStyle?.fontSize, 14);
    expect(htmlWidget.textStyle?.height, 1.9);
    expect(htmlWidget.customStylesBuilder?.call(_elementFrom('<p>段落</p>')), {
      'margin': '0 0 22.0px',
    });
  });

  testWidgets(
    'forwards resolved text layout without applying fontScale again',
    (tester) async {
      const style = TextStyle(
        fontSize: 20,
        height: 1.4,
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
      );
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              html: '<p>显式排版</p>',
              sourceId: 'resolved-layout',
              preferences: ForumHtmlReaderPreferences.defaults().copyWith(
                typography: const RichTextTypography(
                  fontScale: 2.5,
                  lineHeightScale: 2,
                  paragraphSpacing: 12,
                ),
              ),
              textStyle: style,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final htmlWidget = tester.widget<HtmlWidget>(
        find.byKey(const Key('forum-html-renderer-resolved-layout')),
      );
      expect(htmlWidget.textStyle, style);
      final paragraph = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('显式排版'),
        ),
      );
      expect(paragraph.textAlign, TextAlign.center);
      final renderedStyle = _findTextSpanContaining(tester, '显式排版')!.style;
      expect(renderedStyle?.fontSize, 20);
      expect(renderedStyle?.fontFamily, 'serif');
      expect(renderedStyle?.fontWeight, FontWeight.w700);
    },
  );

  testWidgets('uses explicit render theme quote colors', (tester) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'quote-surface',
            html:
                '<div class="quote"><blockquote>'
                '<a href="space.php?uid=1">作者 发表于 2026-1-5</a><br>'
                '引用正文'
                '</blockquote></div>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final htmlWidget = tester.widget<HtmlWidget>(
      find.byKey(const Key('forum-html-renderer-quote-surface')),
    );
    final quoteStyles = htmlWidget.customStylesBuilder?.call(
      _elementFrom('<div class="quote">引用正文</div>'),
    );
    expect(
      quoteStyles,
      containsPair(
        'background-color',
        _cssHex(forumHtmlTestTheme.quoteSurface),
      ),
    );
    expect(
      quoteStyles,
      containsPair(
        'border-left',
        '3px solid ${_cssHex(forumHtmlTestTheme.link)}',
      ),
    );
    expect(find.textContaining('引用正文', findRichText: true), findsOneWidget);
  });

  testWidgets('renders adapted html when author font sizes are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            html:
                '<p style="font-size: 30px; color: red; '
                'background-color: yellow">正文</p>',
            sourceId: 'sanitized',
            preferences: ForumHtmlReaderPreferences.defaults().copyWith(
              preserveAuthorFontSize: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('正文', findRichText: true), findsOneWidget);
  });

  testWidgets('normalizes Discuz font size 3 to the base body size', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: ThemeData(
          textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 20)),
        ),
        home: const Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'font-size-three',
            html: '默认<font size="3">三号</font>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final defaultSpan = _findTextSpanContaining(tester, '默认');
    final sizeThreeSpan = _findTextSpanContaining(tester, '三号');

    expect(defaultSpan?.style?.fontSize, 23);
    expect(sizeThreeSpan?.style?.fontSize, 23);
  });

  testWidgets('preserves Discuz font size ordering around the base size', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: ThemeData(
          textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 20)),
        ),
        home: const Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'font-size-ordering',
            html:
                '默认'
                '<font size="2">二号</font>'
                '<font size="4">四号</font>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final defaultSize = _findTextSpanContaining(tester, '默认')?.style?.fontSize;
    final sizeTwo = _findTextSpanContaining(tester, '二号')?.style?.fontSize;
    final sizeFour = _findTextSpanContaining(tester, '四号')?.style?.fontSize;

    expect(defaultSize, 23);
    expect(sizeTwo, lessThan(defaultSize!));
    expect(sizeFour, greaterThan(defaultSize));
  });

  testWidgets('renders Discuz edit status smaller and quieter', (tester) async {
    const bodyColor = Color(0xFF203040);
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 20, color: bodyColor),
          ),
        ),
        home: const Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'pstatus',
            html:
                '<i class="pstatus"> 本帖最后由 INCSKY16 于 2026-7-3 13:56 编辑 </i>'
                '<br><i>普通斜体</i><p>正文</p>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editStatus = tester.widget<Text>(
      find.byKey(const Key('forum-html-discuz-edit-status')),
    );
    final ordinaryItalic = _findTextSpanContaining(tester, '普通斜体');

    expect(editStatus.data, '本帖最后由 INCSKY16 于 2026-7-3 13:56 编辑');
    expect(editStatus.style?.fontStyle, FontStyle.italic);
    expect(editStatus.style?.fontSize, lessThan(23));
    expect(editStatus.style?.color?.a, lessThan(bodyColor.a));
    expect(ordinaryItalic?.style?.fontStyle, FontStyle.italic);
    expect(ordinaryItalic?.style?.fontSize, 23);
    expect(ordinaryItalic?.style?.color?.a, bodyColor.a);
  });

  testWidgets('uses compact deterministic spacing after Discuz edit status', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'pstatus-spacing',
            html:
                '<i class="pstatus">本帖最后由作者编辑</i><br><br>'
                '<span>正文紧随编辑提示</span>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final htmlWidget = tester.widget<HtmlWidget>(
      find.byKey(const Key('forum-html-renderer-pstatus-spacing')),
    );
    final prepared = html_parser.parseFragment(htmlWidget.html);
    expect(prepared.querySelectorAll('br'), isEmpty);

    final statusRect = tester.getRect(
      find.byKey(const Key('forum-html-discuz-edit-status')),
    );
    final bodyFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains('正文紧随编辑提示'),
    );
    final bodyRect = tester.getRect(bodyFinder);
    expect(bodyRect.top - statusRect.bottom, inInclusiveRange(7, 10));
  });

  testWidgets('renders forum collapse blocks and expands nested content', (
    tester,
  ) async {
    final tappedUrls = <String>[];
    var interactions = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'collapse',
            html:
                '<div id="toc" class="showcollapse_box">'
                '<div class="showcollapse_title">目录</div>'
                '<div class="showcollapse_content">'
                '<a href="thread.html">内容链接</a>'
                '<div id="inner" class="showcollapse_box">'
                '<div class="showcollapse_title">内层目录</div>'
                '<div class="showcollapse_content">内层内容</div>'
                '</div>'
                '<div class="showcollapse_gather">收起</div>'
                '</div>'
                '</div>',
            callbacks: ForumHtmlRenderCallbacks(
              onInteraction: () => interactions += 1,
              onTapUrl: (url) async {
                tappedUrls.add(url);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ForumCollapseBlock), findsOneWidget);
    expect(
      find.byKey(const Key('forum-html-collapse-collapse-toc')),
      findsOneWidget,
    );
    expect(find.textContaining('目录', findRichText: true), findsOneWidget);
    expect(find.textContaining('内容链接', findRichText: true), findsNothing);
    expect(find.text('收起', findRichText: true), findsNothing);

    await tester.tap(
      find.byKey(const Key('forum-html-collapse-toggle-collapse-toc')),
    );
    await tester.pumpAndSettle();

    expect(interactions, 1);
    expect(find.textContaining('内容链接', findRichText: true), findsOneWidget);
    expect(find.byType(ForumCollapseBlock), findsNWidgets(2));
    expect(
      find.byKey(const Key('forum-html-collapse-collapse-toc-content-inner')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const Key('forum-html-collapse-toggle-collapse-toc-content-inner'),
      ),
    );
    await tester.pumpAndSettle();
    expect(interactions, 2);

    await tester.tap(find.text('内容链接', findRichText: true));
    await tester.pumpAndSettle();

    expect(tappedUrls, <String>['https://bbs.yamibo.com/thread.html']);
    expect(interactions, 3);
  });

  testWidgets('starts active forum collapse blocks expanded', (tester) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'active',
            html:
                '<div id="toc" class="showcollapse_box showcollapse_active">'
                '<div class="showcollapse_title">目录</div>'
                '<div class="showcollapse_content">已展开内容</div>'
                '</div>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已展开内容', findRichText: true), findsOneWidget);
    expect(
      find.byKey(const Key('forum-html-collapse-content-active-toc')),
      findsOneWidget,
    );
  });

  testWidgets('keeps ruby rendering delegated to the html library', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'ruby',
            html: '<p>冒险者<ruby>特莉丝<rt>トリス</rt></ruby></p>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('特莉丝', findRichText: true), findsOneWidget);
    expect(find.textContaining('トリス', findRichText: true), findsOneWidget);
    expect(find.textContaining('<rt>', findRichText: true), findsNothing);
  });
}
