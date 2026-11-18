part of 'novel_reader_hybrid_pagination_planner_test.dart';

void _fallbackAndLimitsCases() {
  test(
    'falls back only the safe atom when text style resolution throws',
    () async {
      final chapter = await _prepare('<p>正文</p>');
      final planner = DefaultNovelReaderHybridPaginationPlanner(
        measureAdapter: _RecordingMeasureAdapter(),
        preferences: _preferences,
        theme: _theme,
        baseStyle: _baseStyle,
        textRunExtractor: const NovelReaderPaginationTextRunExtractor(
          styleResolver: _ThrowingTextStyleResolver(),
        ),
      );

      final plan = await planner.paginate(chapter, _key(chapter, height: 120));

      expect(plan.pageCount, 1);
      expect(plan.safeTextFallbackCount, 1);
      expect(
        plan.safeTextFallbackReasonCounts,
        <NovelReaderSafeTextFallbackReason, int>{
          NovelReaderSafeTextFallbackReason.textRunExtractionFailure: 1,
        },
      );
      expect(plan.complexBlockCount, 1);
      expect(plan.pages.single.html, chapter.html);
    },
  );

  test(
    'a safe-path failure cannot swallow the atomic candidate limit',
    () async {
      final chapter = await _prepare('<p>${List.filled(9000, '甲').join()}</p>');
      final adapter = _RecordingMeasureAdapter();
      final planner = DefaultNovelReaderHybridPaginationPlanner(
        measureAdapter: adapter,
        preferences: _preferences,
        theme: _theme,
        baseStyle: _baseStyle,
        textRunExtractor: const NovelReaderPaginationTextRunExtractor(
          styleResolver: _ThrowingTextStyleResolver(),
        ),
      );
      await expectLater(
        planner.paginate(chapter, _key(chapter, height: 120)),
        throwsA(
          isA<NovelReaderPaginationException>().having(
            (error) => error.code,
            'code',
            'complexFitSearchCandidateLimitExceeded',
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('composes safe, flowable complex and safe text on one page', () async {
    final chapter = await _prepare(
      '<p>前文。</p>'
      '<p><font style="letter-spacing: 1px">复杂标题。</font></p>'
      '<p>后文。</p>',
    );
    final adapter = _RecordingMeasureAdapter(
      heightFor: (request, _) {
        if (request.atomId?.endsWith(':validation') == true) {
          return 30;
        }
        return _visibleText(request.html).runes.length * 10.0;
      },
    );

    final plan = await _planner(adapter)
        .paginate(chapter, _key(chapter, height: 200));

    expect(plan.routeCounts[NovelReaderPaginationRoute.flowableComplexText], 1);
    expect(plan.pageCount, 1);
    expect(plan.pages.single.html, contains('前文'));
    expect(plan.pages.single.html, contains('复杂标题'));
    expect(plan.pages.single.html, contains('后文'));
    expect(plan.flowableComplexFragmentCount, 1);
    expect(plan.complexBoundaryIndexBuildCount, 1);
    expect(plan.complexBoundaryIndexCacheHitCount, 0);
    expect(plan.complexSearchProbeCount, 1);
    expect(plan.complexSearchCacheHitCount, 1);
    expect(plan.atomicWidgetPageCount, 0);
    expect(plan.flowabilityFailureReasonCounts, isEmpty);
  });

  test('shares the boundary index across isolated production plans', () async {
    final chapter = await _prepare(
      '<p><font style="letter-spacing: 1px">复杂缓存正文。</font></p>',
    );
    final planner = _planner(
      _RecordingMeasureAdapter(
        heightFor: (request, _) =>
            (request.endOffset! - request.startOffset!) * 10.0,
      ),
    );
    final key = _key(chapter, height: 200);

    final first = await planner.paginate(chapter, key);
    final second = await planner.paginate(chapter, key);

    expect(first.complexBoundaryIndexBuildCount, 1);
    expect(first.complexBoundaryIndexCacheHitCount, 0);
    expect(second.complexBoundaryIndexBuildCount, 0);
    expect(second.complexBoundaryIndexCacheHitCount, 1);
  });

  test('paginates a long flowable complex atom across three pages', () async {
    final chapter = await _prepare(
      '<p><font style="letter-spacing: 1px">${List.filled(24, '甲').join()}</font></p>',
    );
    final adapter = _RecordingMeasureAdapter(
      heightFor: (request, _) =>
          (request.endOffset! - request.startOffset!) * 10.0,
    );

    final plan = await _planner(adapter)
        .paginate(chapter, _key(chapter, height: 80));

    expect(plan.pageCount, 3);
    expect(plan.flowableComplexFragmentCount, 3);
    expect(plan.complexBoundaryCount, greaterThanOrEqualTo(24));
    expect(plan.complexBoundaryIndexBuildCount, 1);
    expect(plan.complexSearchProbeCount, greaterThan(3));
    expect(plan.atomicWidgetPageCount, 0);
    expect(
      plan.pages.map((page) => _visibleText(page.html)).join(),
      List.filled(24, '甲').join(),
    );
    for (var index = 1; index < plan.pages.length; index += 1) {
      expect(
        plan.pages[index - 1].endAnchor.textOffset,
        plan.pages[index].startAnchor.textOffset,
      );
    }
  });

  for (final failSecondPage in <bool>[false, true]) {
    test(
      failSecondPage
          ? 'a later complex failure preserves the published prefix and falls back only the tail'
          : 'publishes a stable complex first page before measuring the second',
      () async {
        final text = List<String>.filled(96, '甲').join();
        final chapter = await _prepare(
          '<p><font style="letter-spacing: 1px">$text</font></p>',
        );
        final secondPageStarted = Completer<void>();
        final releaseSecondPage = Completer<void>();
        final candidateDomNodeCounts = <int>[];
        final adapter = _RecordingMeasureAdapter(
          heightFor: (request, _) =>
              (request.endOffset! - request.startOffset!) * 10.0,
          beforeMeasure: (request) async {
            final fragment = html_parser.parseFragment(request.html);
            final pending = <html_dom.Node>[...fragment.nodes];
            var nodeCount = 0;
            while (pending.isNotEmpty) {
              final node = pending.removeLast();
              nodeCount += 1;
              pending.addAll(node.nodes);
            }
            candidateDomNodeCounts.add(nodeCount);
            if (request.startOffset! > 0 && !secondPageStarted.isCompleted) {
              secondPageStarted.complete();
              await releaseSecondPage.future;
              if (failSecondPage) {
                throw StateError('synthetic later complex measurement failure');
              }
            }
          },
        );
        final events = <NovelReaderPaginationProgress>[];
        final completed = _planner(adapter)
            .planIncrementally(
              chapter: chapter,
              key: _key(chapter, height: 80),
              cancellationToken: NovelReaderPaginationCancellationToken(),
            )
            .map((progress) {
              events.add(progress);
              return progress;
            })
            .toList();

        try {
          await secondPageStarted.future;
          expect(
            adapter.requests.any(
              (request) => request.startOffset == 0 && request.endOffset == 8,
            ),
            isTrue,
          );
          expect(adapter.requests.last.startOffset, 8);
          expect(events, hasLength(1));
          expect(events.single.isComplete, isFalse);
          expect(events.single.plan.pageCount, 1);
          expect(
            _visibleText(events.single.plan.pages.single.html),
            text.substring(0, 8),
          );
          expect(events.single.plan.flowableComplexFragmentCount, 1);
          expect(events.single.plan.complexBoundaryIndexBuildCount, 1);
          expect(events.single.plan.complexSearchProbeCount, greaterThan(0));
        } finally {
          releaseSecondPage.complete();
        }

        final updates = await completed;
        final plan = updates.last.plan;
        expect(updates.first.plan.pageCount, 1);
        expect(plan.pages.first, same(updates.first.plan.pages.first));
        expect(candidateDomNodeCounts, hasLength(adapter.requests.length));
        expect(
          candidateDomNodeCounts.fold<int>(0, (total, count) => total + count),
          greaterThan(adapter.requests.length),
          reason: 'DOM node cost is recorded only for uncached adapter probes.',
        );
        expect(updates.last.isComplete, isTrue);
        expect(
          plan.routeCounts[NovelReaderPaginationRoute.flowableComplexText],
          1,
        );
        expect(plan.pages.map((page) => _visibleText(page.html)).join(), text);
        if (failSecondPage) {
          expect(plan.pageCount, 2);
          expect(plan.atomicWidgetPageCount, 1);
          expect(plan.flowableComplexFragmentCount, 1);
          expect(plan.pages.last.requiresInnerScroll, isTrue);
          expect(plan.pages.first.startAnchor.textOffset, 0);
          expect(plan.pages.first.endAnchor.textOffset, 8);
          expect(plan.pages.last.startAnchor.textOffset, 8);
          expect(plan.pages.last.endAnchor.textOffset, text.length);
          expect(adapter.requests.last.html, isNot(contains(text)));
          expect(plan.flowabilityFailureReasonCounts, {
            NovelReaderFlowableComplexFallbackReason.measurementFailure: 1,
          });
        } else {
          expect(plan.pageCount, 12);
          expect(plan.flowableComplexFragmentCount, 12);
          expect(plan.atomicWidgetPageCount, 0);
          expect(plan.flowabilityFailureReasonCounts, isEmpty);
        }
      },
    );
  }

  test(
    'an unmeasurable failed tail leaves the stable prefix available',
    () async {
      final text = '甲' * 9000;
      final chapter = await _prepare(
        '<p><font style="letter-spacing: 1px">$text</font></p>',
      );
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, _) =>
            (request.endOffset! - request.startOffset!) * 10.0,
        beforeMeasure: (request) async {
          if (request.startOffset! > 0) {
            throw StateError('failed uncommitted tail');
          }
        },
      );
      final updates = <NovelReaderPaginationProgress>[];
      await expectLater(
        _planner(adapter)
            .planIncrementally(
              chapter: chapter,
              key: _key(chapter, height: 80),
              cancellationToken: NovelReaderPaginationCancellationToken(),
            )
            .map((progress) {
              updates.add(progress);
              return progress;
            })
            .toList(),
        throwsA(
          isA<NovelReaderPaginationException>().having(
            (e) => e.code,
            'code',
            'complexFitSearchCandidateLimitExceeded',
          ),
        ),
      );
      expect(updates, hasLength(1));
      expect(updates.single.isComplete, isFalse);
      expect(updates.single.plan.pageCount, 1);
      expect(_visibleText(updates.single.plan.pages.single.html), '甲' * 8);
      expect(adapter.requests.every((r) => r.html.length <= 8192), isTrue);
    },
  );

  test(
    'falls back atomically when the minimum complex fragment overflows',
    () async {
      final chapter = await _prepare(
        '<p><font style="letter-spacing: 1px">复杂正文。</font></p>',
      );

      final plan = await _planner(
        _RecordingMeasureAdapter(heightFor: (_, _) => 200),
      ).paginate(chapter, _key(chapter, height: 100));

      expect(plan.pageCount, 1);
      expect(plan.pages.single.requiresInnerScroll, isTrue);
      expect(plan.pages.single.isDedicatedContentPage, isTrue);
      expect(plan.minimumComplexFragmentCount, 1);
      expect(plan.atomicWidgetPageCount, 1);
      expect(plan.flowableComplexFragmentCount, 0);
      expect(plan.flowabilityFailureReasonCounts, {
        NovelReaderFlowableComplexFallbackReason.minimumFragmentOverflow: 1,
      });
      expect(_visibleText(plan.pages.single.html), '复杂正文。');
    },
  );

  for (final limit in ['html', 'nodes']) {
    test(
      'a flowable failure cannot remeasure a whole atom beyond the $limit limit',
      () async {
        final content = limit == 'html'
            ? List.filled(9000, '甲').join()
            : List.filled(160, '<span>甲</span>').join();
        final chapter = await _prepare(
          '<p><font style="letter-spacing: 1px">$content</font></p>',
        );
        if (limit == 'html') {
          expect(chapter.html.length, greaterThan(8192));
        } else {
          expect(chapter.html.length, lessThanOrEqualTo(8192));
          expect(
            NovelReaderComplexHtmlSearchBudget.countDomNodes(chapter.html),
            greaterThan(256),
          );
        }
        final adapter = _RecordingMeasureAdapter(
          beforeMeasure: (_) async {
            throw StateError(
              'Controlled complex candidate measurement failure.',
            );
          },
        );
        await expectLater(
          _planner(adapter).paginate(chapter, _key(chapter, height: 100)),
          throwsA(
            isA<NovelReaderPaginationException>().having(
              (error) => error.code,
              'code',
              'complexFitSearchCandidateLimitExceeded',
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
        expect(
          adapter.requests.single.html.length,
          lessThan(chapter.html.length),
        );
        expect(adapter.requests.single.html.length, lessThanOrEqualTo(8192));
      },
    );
  }

  test('a measured oversized minimum becomes a dedicated page without a second probe', () async {
    final text = List.filled(9000, '甲').join();
    final chapter = await _prepare('<p><ruby>$text<rt>注</rt></ruby></p>');
    final adapter = _RecordingMeasureAdapter(heightFor: (_, _) => 200);
    final plan = await _planner(adapter)
        .paginate(chapter, _key(chapter, height: 100));

    expect(adapter.requests, hasLength(1));
    expect(plan.measurementCount, 1);
    expect(plan.minimumComplexFragmentCount, 1);
    expect(plan.atomicWidgetPageCount, 1);
    expect(plan.flowableComplexFragmentCount, 0);
    expect(plan.pages, hasLength(1));
    expect(plan.pages.single.requiresInnerScroll, isTrue);
    expect(plan.pages.single.isDedicatedContentPage, isTrue);
    expect(plan.pages.single.html, adapter.requests.single.html);
    expect(_visibleText(plan.pages.single.html), _visibleText(chapter.html));
    expect(plan.flowabilityFailureReasonCounts, {
      NovelReaderFlowableComplexFallbackReason.minimumFragmentOverflow: 1,
    });
  });

  test(
    'an indivisible minimum beyond the finite exception limit is not measured',
    () async {
      final text = List.filled(40000, '甲').join();
      final chapter = await _prepare('<p><ruby>$text<rt>注</rt></ruby></p>');
      final adapter = _RecordingMeasureAdapter();
      await expectLater(
        _planner(adapter).paginate(chapter, _key(chapter, height: 100)),
        throwsA(
          isA<NovelReaderPaginationException>().having(
            (error) => error.code,
            'code',
            'complexFitSearchCandidateLimitExceeded',
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  for (final code in [
    'complexFitSearchCandidateLimitExceeded',
    'complexFitSearchBudgetUnavailable',
  ]) {
    test(
      'a propagated $code cannot be swallowed into an atomic measurement',
      () async {
        final chapter = await _prepare(
          '<p><font style="letter-spacing: 1px">复杂正文</font></p>',
        );
        final adapter = _RecordingMeasureAdapter();
        await expectLater(
          _planner(
            adapter,
            flowableComplexEngine: _RejectingFlowableEngine(code),
          ).paginate(chapter, _key(chapter, height: 100)),
          throwsA(
            isA<NovelReaderPaginationException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  }
}
