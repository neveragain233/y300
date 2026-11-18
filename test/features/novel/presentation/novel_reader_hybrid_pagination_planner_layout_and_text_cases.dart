part of 'novel_reader_hybrid_pagination_planner_test.dart';

void _layoutAndTextCases() {
  test(
    'author font declarations inherit reader metrics without complex probes',
    () async {
      final chapter = await _prepare(
        '<p style="font-family: MissingAuthorFont">'
        '<font face="Tahoma">跟随阅读器字体。</font></p>',
      );
      final adapter = _RecordingMeasureAdapter();
      final plan = await _planner(adapter)
          .paginate(chapter, _key(chapter, height: 200));
      expect(plan.routeCounts[NovelReaderPaginationRoute.safeText], 1);
      expect(plan.complexSearchProbeCount, 0);
      expect(plan.pages.single.html, isNot(contains('font-family')));
      expect(plan.pages.single.html, isNot(contains('face=')));
      expect(_visibleText(plan.pages.single.html), '跟随阅读器字体。');
    },
  );

  test('isolated incremental planner keeps the paragraph indent mode', () {
    final planner = DefaultNovelReaderHybridPaginationPlanner(
      measureAdapter: _RecordingMeasureAdapter(),
      preferences: _preferences,
      theme: _theme,
      baseStyle: _baseStyle,
      paragraphIndent: NovelReaderParagraphIndentMode.increase,
    );

    final isolated = planner.createIsolated();

    expect(isolated, isA<DefaultNovelReaderHybridPaginationPlanner>());
    expect(
      (isolated as DefaultNovelReaderHybridPaginationPlanner).paragraphIndent,
      NovelReaderParagraphIndentMode.increase,
    );
  });

  test('block after an inline heading starts its own indented paragraph', () async {
    final chapter = await _prepare(
      '<strong>episode 348</strong>'
      '<div align="left"><font>&nbsp; &nbsp; &nbsp; &nbsp;第一段正文</font></div>'
      '<div align="left"><font>第二段正文</font></div>',
    );
    final plan = await DefaultNovelReaderHybridPaginationPlanner(
      measureAdapter: _RecordingMeasureAdapter(),
      preferences: _preferences,
      theme: _theme,
      baseStyle: _baseStyle,
      paragraphIndent: NovelReaderParagraphIndentMode.increase,
    ).paginate(chapter, _key(chapter, height: 200));
    final html = plan.pages.map((page) => page.html).join();

    expect(
      RegExp(NovelReaderParagraphIndentProjection.indentText)
          .allMatches(html)
          .length,
      3,
    );
    expect(
      html,
      contains(
        '<div align="left">${NovelReaderParagraphIndentProjection.indentText}<font>第一段正文</font></div>',
      ),
    );
    expect(
      html,
      contains(
        '<div align="left">${NovelReaderParagraphIndentProjection.indentText}<font>第二段正文</font></div>',
      ),
    );
    expect(html, isNot(contains('&nbsp;')));
  });

  test(
    'paragraph indent reaches page html while anchors keep source offsets',
    () async {
      final chapter = await _prepare('<p>第一段</p><p>第二段<br>续行</p>');
      final plan = await DefaultNovelReaderHybridPaginationPlanner(
        measureAdapter: _RecordingMeasureAdapter(),
        preferences: _preferences,
        theme: _theme,
        baseStyle: _baseStyle,
        paragraphIndent: NovelReaderParagraphIndentMode.increase,
      ).paginate(chapter, _key(chapter, height: 200));
      final html = plan.pages.map((page) => page.html).join();

      expect(
        RegExp(NovelReaderParagraphIndentProjection.indentText)
            .allMatches(html)
            .length,
        3,
      );
      expect(plan.pages.first.startAnchor.nodeId, isNotNull);
      expect(
        plan.pages.first.startAnchor.textOffset,
        chapter.flowUnits.first.startAnchor.textOffset,
      );
      final visible = _visibleText(html)
          .replaceAll(NovelReaderParagraphIndentProjection.indentText, '');
      expect(visible, contains('第一段'));
      expect(visible, contains('第二段'));
      expect(visible, contains('续行'));
    },
  );

  test(
    'collapse followed by style and line breaks has no blank final page',
    () async {
      const content =
          '<p>正文介绍。</p>'
          '<div class="showcollapse_box">'
          '<div class="showcollapse_title">合成目录</div>'
          '<div class="showcollapse_content">'
          '<div class="showcollapse_box">'
          '<div class="showcollapse_title">第一组</div>'
          '<div class="showcollapse_content">'
          '<a href="forum.php?mod=viewthread&amp;tid=10001">第一章</a>'
          '</div></div></div></div>';
      final chapter = await _prepare(
        '$content<br>\r\n<br>\r\n<br>\r\n'
        '<style>.showcollapse_content{display:none}</style>'
        '<br>\r\n<br>\r\n',
      );
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, _) => request.html.contains('<style>') ? 0 : 10,
      );
      final plan = await _planner(adapter)
          .paginate(chapter, _key(chapter, height: 120));

      expect(plan.pages, hasLength(2));
      expect(plan.pages.first.html, contains('正文介绍。'));
      expect(plan.pages.last.isDedicatedContentPage, isTrue);
      expect(plan.pages.last.html, contains('第一章'));
      expect(plan.dedicatedCollapsePageCount, 1);
      expect(plan.atomicWidgetPageCount, 0);
      expect(
        adapter.requests.where((request) => request.html.contains('<style>')),
        isEmpty,
      );
      final baseline = await _prepare(content);
      final baselinePlan = await _planner(_RecordingMeasureAdapter())
          .paginate(baseline, _key(baseline, height: 120));
      expect(
        plan.pages.map((page) => page.html),
        baselinePlan.pages.map((page) => page.html),
      );
    },
  );

  test('incremental pages never publish metadata-only content', () async {
    final chapter = await _prepare(
      '<p>前文</p>'
      '<table><tr><td>表格</td></tr></table>'
      '<br><style>.fixture{color:red}</style>'
      '<div><script>fixtureCallback();</script><!-- fixture --></div>'
      '<p>后文</p><br><br>',
    );
    final updates = await _planner(_RecordingMeasureAdapter())
        .planIncrementally(
          chapter: chapter,
          key: _key(chapter, height: 120),
          cancellationToken: NovelReaderPaginationCancellationToken(),
        )
        .toList();

    expect(updates.last.isComplete, isTrue);
    expect(updates.last.plan.pageCount, 3);
    for (final update in updates) {
      for (final page in update.plan.pages) {
        final fragment = html_parser.parseFragment(page.html);
        fragment
            .querySelectorAll('style,script')
            .forEach((node) => node.remove());
        expect((fragment.text ?? '').trim(), isNotEmpty);
        expect(page.html, isNot(contains('fixture')));
      }
    }
    expect(updates.last.plan.pages.last.html, '<p>后文</p>');
  });

  test(
    'keeps a long edit notice intact on the same page as the following prose',
    () async {
      final notice =
          '本帖最后由 ${List.filled(30, 'fixture-user').join()} 于 2026-1-1 12:34 编辑';
      final chapter = await _prepare(
        '<i class="pstatus">$notice</i><br><br><p>正文第一段。</p>',
      );
      final adapter = _RecordingMeasureAdapter();
      final plan = await _planner(adapter)
          .paginate(chapter, _key(chapter, height: 160));

      expect(plan.pageCount, 1);
      expect(plan.pages.single.html, contains(notice));
      expect(plan.pages.single.html, contains('正文第一段。'));
      expect(plan.pages.single.requiresInnerScroll, isFalse);
      expect(plan.pages.single.isDedicatedContentPage, isFalse);
      expect(plan.routeCounts[NovelReaderPaginationRoute.editStatus], 1);
      expect(plan.routeCounts[NovelReaderPaginationRoute.safeText], 1);
      expect(plan.textLayoutCount, 1);
      expect(
        adapter.requests.where(
          (r) => r.html.contains(notice) && !r.html.contains('正文第一段。'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'an edit notice joins preceding content without forcing a new page',
    () async {
      final chapter = await _prepare(
        '<p>前文</p><i class="pstatus">编辑提示</i><p>后文</p>',
      );
      final plan = await _planner(_RecordingMeasureAdapter())
          .paginate(chapter, _key(chapter, height: 160));
      expect(plan.pageCount, 1);
      expect(plan.pages.single.html, contains('前文'));
      expect(plan.pages.single.html, contains('编辑提示'));
      expect(plan.pages.single.html, contains('后文'));
    },
  );

  test('pure text uses TextPainter with bounded HTML validation', () async {
    final chapter = await _prepare(
      '<p>${List<String>.filled(60, '混合分页正文 mixed 123。').join()}</p>',
    );
    final adapter = _RecordingMeasureAdapter();

    final plan = await _planner(adapter)
        .paginate(chapter, _key(chapter, height: 120));

    expect(plan.pageCount, greaterThan(2));
    expect(plan.textFastPathCount, plan.pageCount);
    expect(plan.textLayoutCount, 1);
    expect(plan.safeTextRunCount, greaterThan(0));
    expect(plan.complexBlockCount, 0);
    expect(plan.safeTextFallbackCount, 0);
    expect(plan.rendererValidationCount, greaterThan(0));
    expect(plan.rendererValidationCount, lessThan(plan.pageCount));
    expect(plan.measurementCount, plan.rendererValidationCount);
    expect(plan.domSliceCount, plan.pageCount);
    expect(plan.routeCounts[NovelReaderPaginationRoute.safeText], 1);
    expect(
      plan.pages
          .map((page) => html_parser.parseFragment(page.html).text ?? '')
          .join(),
      html_parser.parseFragment(chapter.html).text,
    );
  });

  test(
    'routes text, ruby, tables and readable images through one planner',
    () async {
      final chapter = await _prepare(
        '<p>普通正文</p>'
        '<p>前<ruby>字<rt>じ</rt></ruby>后</p>'
        '<table><tr><td>表格正文</td></tr></table>'
        '<img src="data/attachment/forum/phase4.jpg">',
      );
      final plan = await _planner(_RecordingMeasureAdapter())
          .paginate(chapter, _key(chapter, height: 160));

      expect(plan.routeCounts[NovelReaderPaginationRoute.safeText], 1);
      expect(plan.routeCounts[NovelReaderPaginationRoute.rubyInline], 1);
      expect(plan.routeCounts[NovelReaderPaginationRoute.tableBlock], 1);
      expect(plan.routeCounts[NovelReaderPaginationRoute.isolatedImage], 1);
      expect(plan.complexBlockCount, 2);
      expect(plan.readableImageCount, 1);
      expect(
        plan.pages.where((page) => page.containsIsolatedImage),
        hasLength(1),
      );
      expect(
        plan.pages
            .singleWhere((page) => page.containsIsolatedImage)
            .requiresInnerScroll,
        isTrue,
        reason: 'Unknown image geometry must not be allowed to overflow after decode.',
      );
      expect(plan.pages.expand((page) => page.imageIndices), contains(0));
      expect(plan.pages.any((page) => page.html.contains('<ruby>')), isTrue);
      expect(plan.pages.any((page) => page.html.contains('<table>')), isTrue);
    },
  );

  test(
    'backs off to fewer complete lines after a validation mismatch',
    () async {
      final chapter = await _prepare(
        '<p>${List<String>.filled(20, '需要回退的安全正文。').join()}</p>',
      );
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, validationCall) {
          if (request.atomId?.endsWith(':validation') == true &&
              validationCall == 1) {
            return 240;
          }
          return 40;
        },
      );

      final plan = await _planner(adapter)
          .paginate(chapter, _key(chapter, height: 120));

      expect(plan.rendererValidationMismatchCount, 1);
      expect(plan.safeTextFallbackCount, 0);
      expect(plan.textFastPathCount, greaterThan(0));
      expect(plan.pages.every((page) => !page.requiresInnerScroll), isTrue);
    },
  );

  test(
    'falls back to a complex atom when bounded backoff still mismatches',
    () async {
      final chapter = await _prepare(
        '<p>${List<String>.filled(20, '持续不一致的正文。').join()}</p>',
      );
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, validationCall) {
          if (request.atomId?.endsWith(':validation') == true) {
            return 260;
          }
          return 80;
        },
      );

      final plan = await _planner(adapter)
          .paginate(chapter, _key(chapter, height: 120));

      expect(plan.rendererValidationMismatchCount, 2);
      expect(plan.safeTextFallbackCount, 1);
      expect(
        plan.safeTextFallbackReasonCounts,
        <NovelReaderSafeTextFallbackReason, int>{
          NovelReaderSafeTextFallbackReason.rendererMismatch: 1,
        },
      );
      expect(plan.complexBlockCount, 1);
      expect(plan.pageCount, 1);
      expect(plan.pages.single.html, chapter.html);
    },
  );

  test(
    'uses first-page remaining height to compose adjacent text atoms',
    () async {
      final chapter = await _prepare('<p>第一段短文。</p><p>第二段短文。</p>');
      final plan = await _planner(_RecordingMeasureAdapter())
          .paginate(chapter, _key(chapter, height: 120));

      expect(plan.pageCount, 1);
      expect(plan.pages.single.html, contains('第一段短文'));
      expect(plan.pages.single.html, contains('第二段短文'));
      expect(plan.pages.single.anchorRanges, hasLength(2));
    },
  );

  test('top-level br-separated lines share pages on the text path', () async {
    final source = List<String>.generate(
      24,
      (index) => '第${index + 1}句短文。<br>\r\n',
    ).join();
    final chapter = await _prepare(source);

    final plan = await _planner(_RecordingMeasureAdapter())
        .paginate(chapter, _key(chapter, height: 120));

    expect(plan.pageCount, greaterThan(1));
    expect(plan.pageCount, lessThan(24));
    expect(plan.complexBlockCount, 0);
    expect(plan.routeCounts.keys, <NovelReaderPaginationRoute>{
      NovelReaderPaginationRoute.safeText,
    });
    final combinedHtml = plan.pages.map((page) => page.html).join();
    expect(combinedHtml, contains('第1句短文。<br>'));
    expect(combinedHtml, contains('第24句短文。'));
    expect(combinedHtml, isNot(endsWith('<br>')));
  });

  test('does not publish separator-only pages before an image', () async {
    final chapter = await _prepare(
      '<p>图片前正文。</p>'
      '<div>&nbsp; &nbsp;</div>'
      '<br><br>'
      '<img src="data/attachment/forum/blank-page.jpg">',
    );

    final plan = await _planner(_RecordingMeasureAdapter())
        .paginate(chapter, _key(chapter, height: 42));

    expect(plan.pages, hasLength(2));
    expect(plan.pages.first.html, contains('图片前正文'));
    expect(plan.pages.first.containsIsolatedImage, isFalse);
    expect(plan.pages.last.containsIsolatedImage, isTrue);
    expect(plan.pages.last.html, contains('blank-page.jpg'));
    expect(
      plan.pages.where((page) {
        final fragment = html_parser.parseFragment(page.html);
        final text = (fragment.text ?? '').replaceAll('\u00A0', ' ').trim();
        return text.isEmpty && fragment.querySelector('img') == null;
      }),
      isEmpty,
    );
  });

  test(
    'drops a whitespace-only text chunk before an image at 18.5 and 1.6',
    () async {
      final chapter = await _prepare(
        '<div>图片前正文。<br>\r\n<br>\r\n<br>\r\n<br>\r\n</div>'
        '<img src="data/attachment/forum/blank-chunk.jpg">',
      );

      final plan = await _planner(_RecordingMeasureAdapter())
          .paginate(chapter, _key(chapter, height: 60));

      expect(
        plan.pages.where((page) => page.containsIsolatedImage),
        hasLength(1),
      );
      expect(
        plan.pages.where(
          (page) =>
              !page.containsIsolatedImage && _visibleText(page.html).isEmpty,
        ),
        isEmpty,
      );
      expect(
        plan.pages.where((page) => _visibleText(page.html).contains('图片前正文')),
        hasLength(1),
      );
    },
  );

  test('does not place a blank page before the fixture image', () async {
    final fixture = await File(
      'test/features/novel/fixtures/pagination/'
      'nested_title_attachment_v1.html',
    ).readAsString();
    final html = fixture.replaceFirst(
      '[attach]841380[/attach]',
      '<img src="data/attachment/forum/nested-title-cover.jpg">',
    );
    final chapter = await _prepare(html);

    final plan = await _planner(_RecordingMeasureAdapter())
        .paginate(chapter, _key(chapter, height: 600));

    final imagePageIndex = plan.pages.indexWhere(
      (page) => page.containsIsolatedImage,
    );
    expect(imagePageIndex, greaterThan(0));
    expect(
      _visibleText(plan.pages[imagePageIndex - 1].html),
      isNotEmpty,
      reason: 'A separator-only page must not be emitted before an image.',
    );
    expect(
      plan.pages.where(
        (page) =>
            !page.containsIsolatedImage && _visibleText(page.html).isEmpty,
      ),
      isEmpty,
    );
    final textBeforeImage = plan.pages
        .take(imagePageIndex)
        .map((page) => _visibleText(page.html))
        .join(' ');
    expect(textBeforeImage, contains('尊重发帖人的意愿'));
    expect(textBeforeImage, contains('默默下载就是了'));
    expect(plan.pages[imagePageIndex].html, contains('nested-title-cover.jpg'));
  });

  test(
    'ACT23 fixture packs Discuz lines around ruby without sparse pages',
    () async {
      final html = await File(
        'test/features/novel/fixtures/pagination/'
        'act23_ruby_collapse_v1.html',
      ).readAsString();
      final chapter = await _prepare(html);
      final plan = await _planner(
        _RecordingMeasureAdapter(
          heightFor: (request, _) {
            if (request.html.contains('showcollapse_box')) {
              return 60;
            }
            if (request.html.contains('<ruby>')) {
              return 120;
            }
            return 10;
          },
        ),
      ).paginate(chapter, _key(chapter, height: 600));

      expect(plan.routeCounts[NovelReaderPaginationRoute.safeText], 87);
      expect(plan.routeCounts[NovelReaderPaginationRoute.rubyInline], 1);
      expect(plan.routeCounts[NovelReaderPaginationRoute.collapseBlock], 1);
      expect(plan.pageCount, lessThanOrEqualTo(9));
      expect(plan.dedicatedCollapsePageCount, 1);
      expect(plan.averageTextPageFullness, greaterThan(0.85));
      final textPages = plan.pages
          .where((page) => !page.isDedicatedContentPage)
          .toList(growable: false);
      expect(
        textPages
            .take(textPages.length - 1)
            .every((page) => page.fullness > 0.85),
        isTrue,
      );
      expect(
        plan.pages.where((page) => _visibleText(page.html).isEmpty),
        isEmpty,
      );
      final combinedText = plan.pages
          .map((page) => _visibleText(page.html))
          .join();
      expect(combinedText, contains('ACT23'));
      expect(combinedText, contains('我也好想变成像蓝沙前辈那样出色的姐姐啊'));
      expect(combinedText, contains('碎碎念'));
    },
  );

  test(
    'flows Ruby and fixed-size smileys without splitting protected clusters',
    () async {
      final html = await File(
        'test/features/novel/fixtures/pagination/'
        'phase6_ruby_protected_inline_v1.html',
      ).readAsString();
      final chapter = await _prepare(html);
      final plan = await _planner(
        _RecordingMeasureAdapter(
          heightFor: (request, _) {
            final fragment = html_parser.parseFragment(request.html);
            final imageHeight = fragment.querySelectorAll('img').length * 24;
            return (_visibleText(request.html).runes.length * 8 + imageHeight)
                .toDouble();
          },
        ),
      ).paginate(chapter, _key(chapter, height: 180));

      expect(plan.routeCounts[NovelReaderPaginationRoute.rubyInline], 4);
      expect(
        plan.routeCounts[NovelReaderPaginationRoute.flowableComplexText],
        1,
      );
      expect(plan.pageCount, greaterThan(1));
      expect(plan.flowableComplexFragmentCount, greaterThan(5));
      expect(plan.atomicWidgetPageCount, 0);
      expect(plan.dedicatedImagePageCount, 0);
      expect(plan.pages.every((page) => !page.isDedicatedContentPage), isTrue);

      final publishedHtml = plan.pages.map((page) => page.html).join();
      final published = html_parser.parseFragment(publishedHtml);
      expect(published.querySelectorAll('ruby'), hasLength(5));
      expect(published.querySelectorAll('rt'), hasLength(5));
      expect(published.querySelectorAll('rp'), hasLength(10));
      for (final ruby in published.querySelectorAll('ruby')) {
        expect(ruby.querySelectorAll('rt'), hasLength(1));
        expect(ruby.querySelectorAll('rp'), hasLength(2));
      }
      final smileys = published.querySelectorAll('img');
      expect(smileys, hasLength(1));
      expect(smileys.single.attributes['width'], '24');
      expect(smileys.single.attributes['height'], '24');
      expect(
        _withoutFormattingWhitespace(publishedHtml),
        _withoutFormattingWhitespace(chapter.html),
        reason: 'Flowable slices must not lose or duplicate annotated text.',
      );
    },
  );

  test(
    'moves a heading forward when the following body line would orphan',
    () async {
      final chapter = await _prepare(
        '<p>${List<String>.filled(20, '前文').join()}</p>'
        '<h2>章节标题</h2>'
        '<p>标题后的第一行正文。</p>',
      );
      final plan = await _planner(_RecordingMeasureAdapter())
          .paginate(chapter, _key(chapter, height: 180));

      final headingPage = plan.pages.singleWhere(
        (page) => page.html.contains('<h2>'),
      );
      expect(headingPage.index, greaterThan(0));
      expect(plan.pages[headingPage.index - 1].html, isNot(contains('<h2>')));
      expect(headingPage.html, contains('标题后的第一行正文'));
    },
  );

  test('keeps a fitting table on a dedicated page', () async {
    final chapter = await _prepare(
      '<p>表格前的短文。</p>'
      '<table><tr><td>单元格</td></tr></table>',
    );
    final adapter = _RecordingMeasureAdapter(
      heightFor: (request, _) {
        if (request.atomId?.contains(':composition:validation') == true) {
          return 70;
        }
        return request.html.contains('<table>') ? 24 : 30;
      },
    );

    final plan = await _planner(adapter)
        .paginate(chapter, _key(chapter, height: 120));

    expect(plan.pageCount, 2);
    expect(plan.pages.first.html, contains('表格前的短文'));
    expect(plan.pages.first.html, isNot(contains('<table>')));
    expect(plan.pages.last.html, contains('<table>'));
    expect(plan.pages.last.isDedicatedContentPage, isTrue);
    expect(plan.pages.last.gapReason, NovelReaderPageGapReason.dedicatedTable);
    expect(plan.dedicatedTablePageCount, 1);
    expect(plan.rendererValidationCount, 1);
    expect(plan.rendererValidationMismatchCount, 0);
  });

  test('does not probe page composition for a dedicated table', () async {
    final chapter = await _prepare(
      '<p>表格前的短文。</p>'
      '<table><tr><td>单元格</td></tr></table>',
    );
    final adapter = _RecordingMeasureAdapter(
      heightFor: (request, _) {
        if (request.atomId?.contains(':composition:validation') == true) {
          return 180;
        }
        return request.html.contains('<table>') ? 24 : 30;
      },
    );

    final plan = await _planner(adapter)
        .paginate(chapter, _key(chapter, height: 120));

    expect(plan.pageCount, 2);
    expect(plan.pages.first.html, contains('表格前的短文'));
    expect(plan.pages.first.html, isNot(contains('<table>')));
    expect(plan.pages.last.html, contains('<table>'));
    expect(
      adapter.requests.where(
        (request) => request.atomId?.contains(':composition') == true,
      ),
      isEmpty,
    );
    expect(plan.rendererValidationMismatchCount, 0);
  });

  test(
    'keeps original pages when complex composition validation throws',
    () async {
      final chapter = await _prepare(
        '<p>表格前的短文。</p>'
        '<table><tr><td>单元格</td></tr></table>',
      );

      final plan = await DefaultNovelReaderHybridPaginationPlanner(
        measureAdapter: const _ThrowingCompositionMeasureAdapter(),
        preferences: _preferences,
        theme: _theme,
        baseStyle: _baseStyle,
      ).paginate(chapter, _key(chapter, height: 120));

      expect(plan.pageCount, 2);
      expect(plan.pages.first.html, contains('表格前的短文'));
      expect(plan.pages.last.html, contains('<table>'));
      expect(plan.pages.every((page) => page.html.trim().isNotEmpty), isTrue);
    },
  );

  test('validates each distinct risk style signature once', () async {
    final chapter = await _prepare(
      '<p><span style="background-color:#ffeeaa">第一种样式。</span></p>'
      '<p><span style="background-color:#ddeeff">第二种样式。</span></p>',
    );
    final plan = await DefaultNovelReaderHybridPaginationPlanner(
      measureAdapter: _RecordingMeasureAdapter(),
      preferences: _preferences,
      theme: _theme,
      baseStyle: _baseStyle,
      validationPolicy: const NovelReaderPaginationValidationPolicy(
        interval: 10000,
      ),
    ).paginate(chapter, _key(chapter, height: 200));

    expect(plan.rendererValidationCount, 2);
    expect(plan.rendererValidationMismatchCount, 0);
  });

  test(
    'marks oversized tables as inner-scroll pages without splitting rows',
    () async {
      const table = '<table><tr><td>第一行</td></tr><tr><td>第二行</td></tr></table>';
      final chapter = await _prepare(table);
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, _) => request.html.contains('<table>') ? 300 : 10,
      );
      final plan = await _planner(adapter)
          .paginate(chapter, _key(chapter, height: 100));

      expect(plan.pageCount, 1);
      expect(plan.pages.single.requiresInnerScroll, isTrue);
      expect(
        html_parser
            .parseFragment(plan.pages.single.html)
            .querySelectorAll('tr'),
        hasLength(2),
      );
    },
  );
}
