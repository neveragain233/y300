part of 'novel_reader_html_paged_surface_performance_test.dart';

void _conversionRestoreCases() {
  for (final flowMode in [
    NovelReaderFlowMode.pagedLtr,
    NovelReaderFlowMode.pagedRtl,
  ]) {
    testWidgets(
      'converted middle position in ${flowMode.name} renders its covered target before completion and never jumps to the percentage',
      (tester) async {
        const raw = '<p>臺第一頁。</p><p>臺目標頁。</p><p>臺尾頁。</p>';
        final preparation = _GatedPreparationService();
        final coordinator = _BudgetPaginationCoordinator()
          ..useFlowAnchors = true;
        final host = _BudgetSurfaceHost(
          coordinator,
          preparationService: preparation,
          enforceBudgets: false,
        );
        host.rawHtml = raw;
        final old = await _conversionChapter(host, raw);
        final next = await _conversionChapter(host, raw.replaceAll('臺', '台'));
        host.preferences = host.preferences.copyWith(
          flowMode: flowMode,
          conversionMode: NovelReaderConversionMode.toSimplified,
        );
        host.conversionPosition = NovelReaderConversionPosition(
          rawHtml: raw,
          conversionIdentity: 'none',
          chapter: old,
          anchor: old.flowUnits[1].startAnchor,
        );
        host.snapshot = host.snapshot.copyWith(
          progressPercent: 0.9,
          isProgressPercentValid: true,
          pageCount: 10,
          pageIndex: 9,
          paginationKey: 'old-layout',
          anchorNodeId: 'future-position',
          anchorTextIdentity: 'future-text',
          anchorTextOffset: 777,
          anchorFormatVersion: 37,
        );
        final persisted = host.snapshot;
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        preparation.requests.single.complete(next);
        await tester.pump();
        await tester.pump();
        coordinator.emit(0, pageCount: 1);
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const Key('novel-reader-paged-restoring-position')),
          findsOneWidget,
        );
        expect(host.positions, isEmpty);
        coordinator.emit(0, pageCount: 2);
        await tester.pump();
        await tester.pump();
        final pageView = find.byKey(const Key('novel-reader-paged-page-view'));
        expect(pageView, findsOneWidget);
        expect(host.positions.single.pageIndex, 1);
        expect(host.positions.single.isReadOnlyCompatibilityRestore, isTrue);
        final body = tester.element(pageView);
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pump();
        await tester.pump();
        expect(tester.element(pageView), same(body));
        expect(host.positions.last.pageIndex, 1);
        expect(
          host.positions.every((p) => p.isReadOnlyCompatibilityRestore),
          isTrue,
        );
        expect(host.snapshot, same(persisted));
        expect(host.conversionPositions.last.chapter, same(next));
        expect(
          host.conversionPositions.last.anchor.textIdentity,
          next.flowUnits[1].startAnchor.textIdentity,
        );
        expect(host.navigation.turnNext(), isTrue);
        await tester.pumpAndSettle();
        expect(host.positions.last.pageIndex, 2);
        expect(host.positions.last.isReadOnlyCompatibilityRestore, isFalse);
      },
    );
  }

  testWidgets(
    'a late conversion preparation cannot replace the latest conversion target',
    (tester) async {
      const raw = '<p>臺第一頁。</p><p>臺目標頁。</p><p>臺尾頁。</p>';
      final preparation = _GatedPreparationService();
      final coordinator = _BudgetPaginationCoordinator()..useFlowAnchors = true;
      final host = _BudgetSurfaceHost(
        coordinator,
        preparationService: preparation,
        enforceBudgets: false,
      )..rawHtml = raw;
      final original = await _conversionChapter(host, raw);
      final simplified = await _conversionChapter(
        host,
        raw.replaceAll('臺', '台'),
      );
      final traditional = await _conversionChapter(
        host,
        raw.replaceAll('臺', '檯'),
      );
      host.conversionPosition = NovelReaderConversionPosition(
        rawHtml: raw,
        conversionIdentity: 'none',
        chapter: original,
        anchor: original.flowUnits[1].startAnchor,
      );
      host.snapshot = host.snapshot.copyWith(
        progressPercent: 0.9,
        isProgressPercentValid: true,
      );
      host.preferences = host.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toSimplified,
      );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      host.preferences = host.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toTraditional,
      );
      await tester.pumpWidget(host.build());
      preparation.requests[1].complete(traditional);
      await tester.pump();
      await tester.pump();
      coordinator.emit(0, pageCount: 2);
      await tester.pump();
      await tester.pump();
      expect(host.positions.last.pageIndex, 1);
      preparation.requests[0].complete(simplified);
      await tester.pump();
      await tester.pump();
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(coordinator.attempts, hasLength(1));
      expect(host.positions.last.pageIndex, 1);
      expect(host.conversionPositions.last.chapter, same(traditional));
    },
  );

  testWidgets(
    'navigation retired during preparation prevents a late conversion hint from rearming',
    (tester) async {
      const raw = '<p>臺第一頁。</p><p>臺目標頁。</p><p>臺尾頁。</p>';
      final preparation = _GatedPreparationService();
      final coordinator = _BudgetPaginationCoordinator()..useFlowAnchors = true;
      final host = _BudgetSurfaceHost(
        coordinator,
        preparationService: preparation,
        enforceBudgets: false,
      )..rawHtml = raw;
      final original = await _conversionChapter(host, raw);
      final converted = await _conversionChapter(
        host,
        raw.replaceAll('臺', '台'),
      );
      host.conversionPosition = NovelReaderConversionPosition(
        rawHtml: raw,
        conversionIdentity: 'none',
        chapter: original,
        anchor: original.flowUnits[2].startAnchor,
      );
      host.preferences = host.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toSimplified,
      );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      host.navigationRequest = NovelReaderAnchorNavigationRequest(
        requestId: 1,
        anchor: converted.flowUnits.first.startAnchor,
      );
      await tester.pumpWidget(host.build());
      host.navigationRequest = null;
      host.snapshot = host.snapshot.copyWith(
        progressPercent: 0,
        isProgressPercentValid: true,
      );
      await tester.pumpWidget(host.build());
      preparation.requests.single.complete(converted);
      await tester.pump();
      await tester.pump();
      coordinator.emit(0, pageCount: 1);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-paged-page-view')),
        findsOneWidget,
      );
      expect(host.positions.single.pageIndex, 0);
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(host.positions.last.pageIndex, 0);
    },
  );

  for (final format in [1, 37]) {
    testWidgets(
      'verified beginning with an invalidated conversion anchor format $format renders before the whole chapter',
      (tester) async {
        final coordinator = _BudgetPaginationCoordinator();
        final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
        host.snapshot = host.snapshot.copyWith(
          anchorNodeId: 'before-conversion-node',
          anchorTextIdentity: 'before-conversion-text',
          anchorFormatVersion: format,
          anchorTextOffset: 777,
          paginationKey: 'before-conversion-layout',
          isProgressPercentValid: true,
        );
        _disposeBudgetHost(tester, coordinator);
        await _pumpBudgetHost(tester, host);
        coordinator.emit(0, pageCount: 1);
        await tester.pump();
        await tester.pump();
        final pageView = find.byKey(const Key('novel-reader-paged-page-view'));
        expect(pageView, findsOneWidget);
        expect(
          find.byKey(const Key('novel-reader-paged-restoring-position')),
          findsNothing,
        );
        expect(host.positions.single.pageIndex, 0);
        expect(host.positions.single.isReadOnlyCompatibilityRestore, isTrue);
        final firstBody = tester.element(pageView);
        coordinator.emit(0, pageCount: 3, isComplete: true);
        await tester.pump();
        await tester.pump();
        expect(tester.element(pageView), same(firstBody));
        expect(host.positions.last.pageIndex, 0);
        expect(
          host.positions.every(
            (position) => position.isReadOnlyCompatibilityRestore,
          ),
          isTrue,
        );
        expect(host.snapshot.anchorTextOffset, 777);
        expect(host.snapshot.anchorFormatVersion, format);
        expect(host.snapshot.anchorTextIdentity, 'before-conversion-text');
      },
    );
  }

  testWidgets(
    'a nonzero position with an invalidated conversion anchor still restores by the final percentage',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final host = _BudgetSurfaceHost(coordinator, enforceBudgets: false);
      host.snapshot = host.snapshot.copyWith(
        anchorNodeId: 'before-conversion-node',
        anchorTextIdentity: 'before-conversion-text',
        anchorFormatVersion: 1,
        anchorTextOffset: 777,
        paginationKey: 'before-conversion-layout',
        progressPercent: 0.4,
        pageCount: 10,
        pageIndex: 4,
        isProgressPercentValid: true,
      );
      _disposeBudgetHost(tester, coordinator);
      await _pumpBudgetHost(tester, host);
      coordinator.emit(0, pageCount: 1);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-paged-restoring-position')),
        findsOneWidget,
      );
      expect(host.positions, isEmpty);
      coordinator.emit(0, pageCount: 3, isComplete: true);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('novel-reader-paged-page-view')),
        findsOneWidget,
      );
      expect(host.positions.single.pageIndex, 1);
      expect(host.positions.single.isReadOnlyCompatibilityRestore, isTrue);
      expect(host.snapshot.pageIndex, 4);
      expect(host.snapshot.anchorTextOffset, 777);
    },
  );
}

void _conversionProvenanceCases() {
  testWidgets(
    'same HTML hash rechecks changed semantic conversion provenance',
    (tester) async {
      final coordinator = _BudgetPaginationCoordinator();
      final preparation = _GatedPreparationService();
      final host = _BudgetSurfaceHost(
        coordinator,
        preparationService: preparation,
        enforceBudgets: false,
      );
      _disposeBudgetHost(tester, coordinator);
      NovelReaderDocument document(String identity) => NovelReaderDocument(
        episodeId: _episode.episodeId,
        rawHtmlHash: 'same-raw-hash',
        body: RichDocument.empty,
        plainText: '',
        wordCount: 0,
        textConversionIdentity: identity,
      );
      host.semanticDocument = document('original');
      await _pumpBudgetHost(tester, host);
      host.semanticDocument = document('simplified');
      await tester.pumpWidget(host.build());
      await tester.pump();
      expect(preparation.requests, hasLength(2));
      expect(
        preparation.semanticDocuments.map((doc) => doc?.textConversionIdentity),
        ['original', 'simplified'],
      );
      final chapter = await const DefaultNovelReaderHtmlPreparationService()
          .prepare(
            rawHtml: _budgetRawHtml,
            episode: _episode,
            preferences: const NovelHtmlReaderPreferencesAdapter().map(
              host.preferences,
            ),
            theme: host.htmlTheme,
            sourceId: _episode.episodeId,
            threadId: _episode.sourceTid,
            imageCacheOwnerId: _episode.sourceTid,
          );
      preparation.requests.first.complete(chapter);
      await tester.pump();
      expect(coordinator.attempts, isEmpty);
      preparation.requests.last.complete(chapter);
      await tester.pump();
      await tester.pump();
      expect(coordinator.attempts, hasLength(1));
    },
  );
}
