part of 'forum_display_page_test.dart';

void _loadingCases() {
  testWidgets('fast entry shows cards without a spinner or a second fade', (
    tester,
  ) async {
    final response = Completer<ApiResult<ForumDisplayData>>();
    final repository = _FakeForumDisplayRepository(
      (_, _, _) => response.future,
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ForumDisplayPage(fid: '2', title: '公告区'),
                ),
              ),
              child: const Text('Open fixture forum'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture forum'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.cachePolicies, [CacheLoadPolicy.cacheFirst]);
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);

    response.complete(
      ApiSuccess(
        _displayData(
          page: 1,
          total: 1,
          threads: _manyThreads(suffix: 'entry', count: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    _expectCardFullyVisible(tester, 'entry-0');
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
  });

  testWidgets('slow initial loading still shows progress after the delay', (
    tester,
  ) async {
    final response = Completer<ApiResult<ForumDisplayData>>();
    final repository = _FakeForumDisplayRepository(
      (_, _, _) => response.future,
    );
    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(AppLoadingState.indicatorKey), findsOneWidget);

    response.complete(
      ApiSuccess(_displayData(page: 1, total: 0, threads: const [])),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    expect(find.byKey(const Key('forum-display-list')), findsOneWidget);
  });

  testWidgets('leaving initial loading cancels the pending indicator', (
    tester,
  ) async {
    final response = Completer<ApiResult<ForumDisplayData>>();
    await tester.pumpWidget(
      _buildTestApp(_FakeForumDisplayRepository((_, _, _) => response.future)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
