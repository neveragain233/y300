part of 'novel_detail_page_test.dart';

void _renderingMetadataCases() {
  testWidgets(
    'NovelDetailPage renders unified detail header and chapter list',
    (tester) async {
      final historyRecorder = _RecordingHistoryVisitRecorder();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyVisitRecorderProvider.overrideWithValue(historyRecorder),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            novelSourceStateRepositoryProvider.overrideWithValue(
              const _EmptyNovelSourceStateRepository(),
            ),
            novelInteractionPreferencesRepositoryProvider.overrideWithValue(
              _MemoryNovelInteractionPreferencesRepository(),
            ),
            imageCacheServiceProvider.overrideWithValue(
              _NoopImageCacheService(),
            ),
          ],
          child: const LocalizedTestApp(
            home: NovelDetailPage(novelId: 'novel:1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Novel'), findsAtLeastNWidgets(1));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('unified-detail-chapter-novel:1:e1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-detail-chapter-novel:1:e1')),
        findsOneWidget,
      );
      expect(find.textContaining('Pid:'), findsNothing);
      expect(find.textContaining('Tid:'), findsNothing);
      expect(find.text('2026-01-01'), findsOneWidget);
      expect(
        find.byKey(const Key('unified-detail-appbar-download')),
        findsNothing,
      );
      expect(find.byTooltip('下载该章节'), findsNothing);
      await tester.tap(find.byKey(const Key('unified-detail-appbar-filter')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('unified-detail-filter-downloaded')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('unified-detail-filter-unread')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-detail-filter-bookmarked')),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(
          find.byKey(const Key('unified-detail-chapter-filter-sheet')),
        ),
      ).pop();
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey<String>('unified-detail-chapter-novel:1:e1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('取消全部已读'), findsNothing);
      expect(find.text('添加书签'), findsOneWidget);
      Navigator.of(tester.element(find.text('添加书签'))).pop();
      await tester.pumpAndSettle();
      expect(historyRecorder.drafts, hasLength(1));
      expect(
        historyRecorder.drafts.single.target,
        const HistoryTargetKey(type: HistoryTargetType.novel, id: 'novel:1'),
      );
      expect(historyRecorder.drafts.single.title, 'Test Novel');
      expect(historyRecorder.drafts.single.sourceTid, '100');
    },
  );

  for (final sample
      in <({String name, double fraction, bool? valid, int? label})>[
        (name: 'valid percentage', fraction: 0.42, valid: true, label: 42),
        (name: 'explicit valid zero', fraction: 0, valid: true, label: 0),
        (name: 'unknown legacy zero', fraction: 0, valid: null, label: null),
        (
          name: 'invalid partial position',
          fraction: 0.42,
          valid: false,
          label: null,
        ),
      ]) {
    testWidgets(
      'NovelDetailPage displays ${sample.name} without technical IDs',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final libraryState = _FakeLibraryStateRepository();
          await _pumpNovelDetail(
            tester,
            preferences: _MemoryNovelInteractionPreferencesRepository(),
            routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
            libraryStateRepository: libraryState,
            repository: _FakeNovelRepository(
              progress: NovelReadingProgress(
                novelId: 'novel:1',
                episodeId: 'novel:1:e1',
                scrollOffset: 120,
                updatedAt: DateTime(2026, 10, 7),
                progressPercent: sample.fraction,
                isProgressPercentValid: sample.valid,
              ),
            ),
          );
          await _scrollNovelChapterIntoTapArea(tester);

          final inlineProgress = find.byKey(
            const ValueKey<String>(
              'unified-detail-chapter-inline-progress-novel:1:e1',
            ),
          );
          final l10n = AppLocalizations.of(tester.element(inlineProgress));
          final label = sample.label == null
              ? l10n.libraryChapterLastRead
              : l10n.libraryChapterLastReadPercent(sample.label!);
          final text = tester.widget<RichText>(
            find.descendant(
              of: inlineProgress,
              matching: find.byType(RichText),
            ),
          );

          expect(text.text.toPlainText(), '2026-01-01  ·  $label');
          expect(
            tester.widget<Semantics>(inlineProgress).properties.label,
            l10n.libraryChapterProgressSemantics('2026-01-01', label),
          );
          expect(tester.getSemantics(inlineProgress).label, contains(label));
          expect(text.text.toPlainText(), isNot(contains('Pid:')));
          expect(text.text.toPlainText(), isNot(contains('Tid:')));
          expect(
            find.byKey(
              const ValueKey<String>(
                'unified-detail-chapter-read-swipe-novel:1:e1',
              ),
            ),
            findsOneWidget,
          );
          expect(libraryState.readMutationCount, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('NovelDetailPage only renders publisher metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyVisitRecorderProvider.overrideWithValue(
            const _NoopHistoryVisitRecorder(),
          ),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          novelSourceStateRepositoryProvider.overrideWithValue(
            const _EmptyNovelSourceStateRepository(),
          ),
          novelInteractionPreferencesRepositoryProvider.overrideWithValue(
            _MemoryNovelInteractionPreferencesRepository(),
          ),
          imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        ],
        child: const LocalizedTestApp(
          home: NovelDetailPage(novelId: 'novel:1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-plain-header')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unified-detail-author-row')), findsNothing);
    expect(find.byKey(const Key('unified-detail-group-row')), findsNothing);
    expect(
      find.byKey(const Key('unified-detail-publisher-row')),
      findsOneWidget,
    );
    expect(find.text('Author A'), findsOneWidget);
    expect(find.textContaining('UID:'), findsNothing);
    expect(
      find.byKey(const Key('unified-detail-header-gradient')),
      findsNothing,
    );
  });

  testWidgets('NovelDetailPage exposes novel metadata and cover actions', (
    tester,
  ) async {
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-edit-metadata')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unified-detail-set-cover')), findsOneWidget);

    await tester.tap(find.byKey(const Key('unified-detail-edit-metadata')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-detail-custom-author-input')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-custom-group-input')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('unified-detail-custom-search-title-input')),
      findsNothing,
    );
  });

  testWidgets('metadata remains visible while first chapters hydrate', (
    tester,
  ) async {
    final sourceRepository = _HydrationNovelSourceStateRepository();
    final syncService = _ControlledNovelChapterSyncService();
    final historyRecorder = _RecordingHistoryVisitRecorder();
    addTearDown(syncService.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyVisitRecorderProvider.overrideWithValue(historyRecorder),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          novelSourceStateRepositoryProvider.overrideWithValue(
            sourceRepository,
          ),
          novelChapterSyncServiceProvider.overrideWithValue(syncService),
          novelInteractionPreferencesRepositoryProvider.overrideWithValue(
            _MemoryNovelInteractionPreferencesRepository(),
          ),
          imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        ],
        child: const LocalizedTestApp(
          home: NovelDetailPage(novelId: 'novel:1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Test Novel'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const Key('novel-chapter-hydration-panel')),
      findsOneWidget,
    );
    expect(find.textContaining('正在加载第 1/2 页'), findsOneWidget);
    expect(syncService.request?.publisherId, '406769');
    expect(syncService.request?.mode, NovelChapterSyncMode.initialFull);
    expect(historyRecorder.drafts, hasLength(1));

    syncService.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('novel-chapter-hydration-panel')),
      findsNothing,
    );
    expect(historyRecorder.drafts, hasLength(1));
  });
}
