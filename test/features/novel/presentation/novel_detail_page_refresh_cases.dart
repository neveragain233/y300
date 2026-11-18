part of 'novel_detail_page_test.dart';

void _refreshCases() {
  testWidgets('only a header long press requests a full chapter update', (
    tester,
  ) async {
    final updateService = _RecordingNovelChapterUpdateService();
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      chapterUpdateService: updateService,
    );

    final headerUpdate = find.byKey(const Key('unified-detail-header-update'));
    await tester.tap(headerUpdate);
    await tester.pumpAndSettle();

    await tester.longPress(headerUpdate);
    await tester.pumpAndSettle();

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();

    expect(updateService.novelIds, <String>[
      'novel:1',
      'novel:1',
      'novel:1',
      'novel:1',
    ]);
    expect(updateService.intents, <NovelChapterUpdateIntent>[
      NovelChapterUpdateIntent.normal,
      NovelChapterUpdateIntent.full,
      NovelChapterUpdateIntent.normal,
      NovelChapterUpdateIntent.normal,
    ]);
  });

  testWidgets('refresh gestures share one in-flight detail update', (
    tester,
  ) async {
    final updateService = _BlockingNovelChapterUpdateService();
    await _pumpNovelDetail(
      tester,
      preferences: _MemoryNovelInteractionPreferencesRepository(),
      routeResolver: _FakeNovelChapterSourceRouteResolver.success(),
      chapterUpdateService: updateService,
    );

    await tester.longPress(
      find.byKey(const Key('unified-detail-header-update')),
    );
    await tester.pump();
    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final duplicate = refreshIndicator.onRefresh();

    expect(updateService.intents, <NovelChapterUpdateIntent>[
      NovelChapterUpdateIntent.full,
    ]);

    updateService.complete();
    await duplicate;
    await tester.pumpAndSettle();
    expect(updateService.intents, hasLength(1));
  });
}
