part of 'novel_reader_hybrid_pagination_planner_test.dart';

void _cancellationAndStabilityCases() {
  test('honors cancellation before publishing a plan', () async {
    final chapter = await _prepare('<p>正文</p>');
    final token = NovelReaderPaginationCancellationToken()..cancel();

    await expectLater(
      _planner(_RecordingMeasureAdapter()).plan(
        chapter: chapter,
        key: _key(chapter, height: 120),
        cancellationToken: token,
      ),
      throwsA(
        isA<NovelReaderPaginationException>().having(
          (error) => error.code,
          'code',
          'paginationCancelled',
        ),
      ),
    );
  });

  test(
    'cancelling a pending measurement disposes once and cannot fall back',
    () async {
      final chapter = await _prepare(
        '<font style="letter-spacing: 1px">复杂正文。</font>',
      );
      final adapter = _GatedSessionFactory(disposeCompletesError: true);
      final token = NovelReaderPaginationCancellationToken();
      final operation = _planner(adapter).plan(
        chapter: chapter,
        key: _key(chapter, height: 120),
        cancellationToken: token,
      );
      final cancelled = expectLater(
        operation,
        throwsA(
          isA<NovelReaderPaginationException>().having(
            (error) => error.code,
            'code',
            'paginationCancelled',
          ),
        ),
      );
      await adapter.session.started.future;

      token.cancel();
      await cancelled;
      expect(adapter.session.disposeCalls, 1);
      expect(
        adapter.session.measureCalls,
        1,
        reason: 'Cancellation must not trigger an atomic measurement fallback.',
      );
    },
  );

  test(
    'cancel releases a planner even when its adapter ignores disposal',
    () async {
      for (final fail in <bool>[false, true]) {
        final chapter = await _prepare('<table><tr><td>等待正文</td></tr></table>');
        final adapter = _GatedSessionFactory();
        final token = NovelReaderPaginationCancellationToken();
        final operation = _planner(adapter).plan(
          chapter: chapter,
          key: _key(chapter, height: 120),
          cancellationToken: token,
        );
        final cancelled = expectLater(
          operation,
          throwsA(
            isA<NovelReaderPaginationException>().having(
              (error) => error.code,
              'code',
              'paginationCancelled',
            ),
          ),
        );
        await adapter.session.started.future;

        token.cancel();
        await cancelled; // No renderer completion is required to leave the run.
        expect(adapter.session.disposeCalls, 1);
        if (fail) {
          adapter.session.result.completeError(
            StateError('late renderer error'),
          );
        } else {
          adapter.session.result.complete(
            const NovelReaderPaginationMeasureResult(height: 20),
          );
        }
        await Future<void>.delayed(Duration.zero);
        expect(adapter.session.measureCalls, 1);
        expect(adapter.session.disposeCalls, 1);
      }
    },
  );

  test('publishes only stable pages before the complete plan', () async {
    final chapter = await _prepare(
      '<p>${List<String>.filled(80, '增量分页正文 mixed 123。').join()}</p>',
    );
    final token = NovelReaderPaginationCancellationToken();

    final events = await _planner(_RecordingMeasureAdapter())
        .planIncrementally(
          chapter: chapter,
          key: _key(chapter, height: 120),
          cancellationToken: token,
        )
        .toList();

    expect(events.length, greaterThan(1));
    expect(events.first.isComplete, isFalse);
    expect(events.first.plan.pages, hasLength(1));
    expect(events.last.isComplete, isTrue);
    expect(events.last.processedAtomCount, events.last.totalAtomCount);
    for (var index = 1; index < events.length; index += 1) {
      final previous = events[index - 1].plan.pages;
      final current = events[index].plan.pages;
      expect(current.length, greaterThanOrEqualTo(previous.length));
      expect(current.take(previous.length).toList(), previous);
    }
  });

  test(
    'nearby pages pause probes and promotion resumes the same session',
    () async {
      final chapter = await _prepare(
        '<p><font style="letter-spacing: 1px">${'甲' * 96}</font></p>',
      );
      final key = _key(chapter, height: 80);
      double heightFor(NovelReaderPaginationMeasureRequest request, int _) =>
          (request.endOffset! - request.startOffset!) * 10.0;
      final eager = await _planner(
        _RecordingMeasureAdapter(heightFor: heightFor),
      ).paginate(chapter, key);
      final idle = Completer<void>();
      final deferred = Completer<void>();
      final demand = NovelReaderPaginationDemand(
        lookAhead: 0,
        idleScheduler: () => idle.future,
      )..update(targetPending: false, pageIndex: 0);
      demand.addListener(() {
        if (demand.isDeferring && !deferred.isCompleted) {
          deferred.complete();
        }
      });
      final adapter = _RecordingMeasureAdapter(heightFor: heightFor);
      final sessions = _DemandMeasureSessionFactory(adapter);
      final events = <NovelReaderPaginationProgress>[];
      final completed = _planner(sessions, workDemand: demand)
          .planIncrementally(
            chapter: chapter,
            key: key,
            cancellationToken: NovelReaderPaginationCancellationToken(),
          )
          .map((progress) {
            events.add(progress);
            return progress;
          })
          .toList();

      await deferred.future.timeout(const Duration(seconds: 2));
      try {
        final probeCount = adapter.requests.length;
        expect(events.last.plan.pageCount, 1);
        expect(events.every((event) => !event.isComplete), isTrue);
        expect(sessions.sessions, hasLength(1));
        expect(sessions.sessions.single.disposeCalls, 0);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(adapter.requests, hasLength(probeCount));
        expect(events.last.plan.pageCount, 1);
      } finally {
        demand.update(
          targetPending: false,
          pageIndex: 0,
          requireComplete: true,
        );
      }
      final updates = await completed;
      final plan = updates.last.plan;
      expect(updates.last.isComplete, isTrue);
      expect(
        plan.pages.map((page) => page.html),
        eager.pages.map((page) => page.html),
      );
      for (var index = 0; index < plan.pageCount; index += 1) {
        final actual = plan.pages[index];
        final expected = eager.pages[index];
        expect(
          _anchorValues(actual.startAnchor),
          _anchorValues(expected.startAnchor),
        );
        expect(
          _anchorValues(actual.endAnchor),
          _anchorValues(expected.endAnchor),
        );
        expect(
          actual.anchorRanges.map(
            (range) => [_anchorValues(range.start), _anchorValues(range.end)],
          ),
          expected.anchorRanges.map(
            (range) => [_anchorValues(range.start), _anchorValues(range.end)],
          ),
        );
      }
      expect(sessions.sessions, hasLength(1));
      expect(sessions.sessions.single.disposeCalls, 1);
      expect(plan.pages.take(1).toList(), events.first.plan.pages);
      idle.complete();
      await Future<void>.delayed(Duration.zero);
      demand.dispose();
    },
  );

  test(
    'cancelling deferred work releases its session without late cache writes',
    () async {
      final chapter = await _prepare(
        '<p><font style="letter-spacing: 1px">${'甲' * 96}</font></p>',
      );
      final idle = Completer<void>();
      final deferred = Completer<void>();
      final demand = NovelReaderPaginationDemand(
        lookAhead: 0,
        idleScheduler: () => idle.future,
      )..update(targetPending: false, pageIndex: 0);
      demand.addListener(() {
        if (demand.isDeferring && !deferred.isCompleted) {
          deferred.complete();
        }
      });
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, _) =>
            (request.endOffset! - request.startOffset!) * 10.0,
      );
      final sessions = _DemandMeasureSessionFactory(adapter);
      final coordinator = DefaultNovelReaderPaginationCoordinator(
        pageBreaker: _planner(sessions, workDemand: demand),
      );
      final events = <NovelReaderPaginationProgress>[];
      final errors = <Object>[];
      final done = Completer<void>();
      final subscription = coordinator
          .paginateIncrementally(
            chapter: chapter,
            key: _key(chapter, height: 80),
          )
          .listen(events.add, onError: errors.add, onDone: done.complete);
      await deferred.future.timeout(const Duration(seconds: 2));
      final probeCount = adapter.requests.length;
      final eventCount = events.length;
      coordinator.cancelPending();
      await done.future.timeout(const Duration(seconds: 2));
      idle.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(demand.isDeferring, isFalse);
      expect(sessions.sessions, hasLength(1));
      expect(sessions.sessions.single.disposeCalls, 1);
      expect(adapter.requests, hasLength(probeCount));
      expect(events, hasLength(eventCount));
      expect(events.every((event) => !event.isComplete), isTrue);
      expect(errors, hasLength(1));
      expect(
        errors.single,
        isA<NovelReaderPaginationException>().having(
          (error) => error.code,
          'code',
          'paginationCancelled',
        ),
      );
      expect(coordinator.cache.length, 0);
      await subscription.cancel();
      demand.dispose();
    },
  );

  test(
    'complete-plan callers remain eager when a demand object is supplied',
    () async {
      final chapter = await _prepare(
        '<p><font style="letter-spacing: 1px">${'甲' * 48}</font></p>',
      );
      final demand = NovelReaderPaginationDemand(
        lookAhead: 0,
        idleScheduler: () =>
            throw StateError('Complete plans must not be gated.'),
      )..update(targetPending: false, pageIndex: 0);
      final adapter = _RecordingMeasureAdapter(
        heightFor: (request, _) =>
            (request.endOffset! - request.startOffset!) * 10.0,
      );
      final plan = await _planner(
        adapter,
        workDemand: demand,
      ).paginate(chapter, _key(chapter, height: 80));

      expect(plan.pageCount, 6);
      expect(
        plan.pages.map((page) => _visibleText(page.html)).join(),
        '甲' * 48,
      );
      expect(demand.isDeferring, isFalse);
      demand.dispose();
    },
  );

  test('incremental pagination stops publishing after cancellation', () async {
    final chapter = await _prepare(
      '<p>${List<String>.filled(80, '可取消的增量分页正文。').join()}</p>',
    );
    final token = NovelReaderPaginationCancellationToken();
    final events = <NovelReaderPaginationProgress>[];
    final done = Completer<void>();

    _planner(_RecordingMeasureAdapter())
        .planIncrementally(
          chapter: chapter,
          key: _key(chapter, height: 120),
          cancellationToken: token,
        )
        .listen(
          (progress) {
            events.add(progress);
            if (!progress.isComplete && !token.isCancelled) {
              token.cancel();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            expect(
              error,
              isA<NovelReaderPaginationException>().having(
                (value) => value.code,
                'code',
                'paginationCancelled',
              ),
            );
            done.complete();
          },
          onDone: () {
            if (!done.isCompleted) {
              done.complete();
            }
          },
        );

    await done.future;
    expect(events, isNotEmpty);
    expect(events.every((event) => !event.isComplete), isTrue);
  });

  test('publishes the first page before later renderer validation', () async {
    final chapter = await _prepare(
      '<p><span style="background-color:#ffeeaa">'
      '${List<String>.filled(100, '风险样式增量分页正文。').join()}'
      '</span></p>',
    );
    final adapter = _GatedValidationMeasureAdapter();
    final firstPage = Completer<NovelReaderPaginationProgress>();
    final complete = Completer<NovelReaderPaginationProgress>();

    _planner(adapter)
        .planIncrementally(
          chapter: chapter,
          key: _key(chapter, height: 120),
          cancellationToken: NovelReaderPaginationCancellationToken(),
        )
        .listen(
          (progress) {
            if (!progress.isComplete && !firstPage.isCompleted) {
              firstPage.complete(progress);
            }
            if (progress.isComplete && !complete.isCompleted) {
              complete.complete(progress);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!firstPage.isCompleted) {
              firstPage.completeError(error, stackTrace);
            }
            if (!complete.isCompleted) {
              complete.completeError(error, stackTrace);
            }
          },
        );

    final first = await firstPage.future;
    expect(first.plan.pages, hasLength(1));
    expect(complete.isCompleted, isFalse);
    for (
      var attempt = 0;
      attempt < 10 && !adapter.laterValidationStarted;
      attempt += 1
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(adapter.laterValidationStarted, isTrue);

    adapter.releaseLaterValidation();
    expect((await complete.future).isComplete, isTrue);
  });

  test('late validation mismatch preserves already published pages', () async {
    final chapter = await _prepare(
      '<p><span style="background-color:#ffeeaa">'
      '${List<String>.filled(100, '迟到校验不应重写已发布页。').join()}'
      '</span></p>',
    );
    final adapter = _GatedValidationMeasureAdapter(laterHeight: 260);
    final events = <NovelReaderPaginationProgress>[];
    final complete = Completer<NovelReaderPaginationProgress>();

    _planner(adapter)
        .planIncrementally(
          chapter: chapter,
          key: _key(chapter, height: 120),
          cancellationToken: NovelReaderPaginationCancellationToken(),
        )
        .listen((progress) {
          events.add(progress);
          if (progress.isComplete && !complete.isCompleted) {
            complete.complete(progress);
          }
        }, onError: complete.completeError);

    for (
      var attempt = 0;
      attempt < 20 && !adapter.laterValidationStarted;
      attempt += 1
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(events, isNotEmpty);
    final publishedFirstPage = events.first.plan.pages.single;

    adapter.releaseLaterValidation();
    final finalPlan = (await complete.future).plan;

    expect(finalPlan.pages.first, publishedFirstPage);
    expect(finalPlan.safeTextFallbackCount, 1);
    expect(
      finalPlan.safeTextFallbackReasonCounts,
      <NovelReaderSafeTextFallbackReason, int>{
        NovelReaderSafeTextFallbackReason.rendererMismatch: 1,
      },
    );
    expect(finalPlan.complexBlockCount, 1);
  });
}
