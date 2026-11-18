part of 'thread_detail_page_test.dart';

void _historyCases() {
  for (final source in <String>['network', 'snapshot', 'document cache']) {
    testWidgets('records one visible visit from $source content', (
      tester,
    ) async {
      final historyRecorder = _RecordingHistoryVisitRecorder();
      final sourceId = source.replaceAll(' ', '-');
      final repository = _FakeThreadRepository((tid, page) async {
        return ApiSuccess(
          ThreadDetailData(
            tid: tid,
            fid: '2',
            forumName: '测试版块',
            subject: '$source 主题',
            author: 'alice',
            replies: 0,
            views: 1,
            currentPage: page,
            lastPage: 1,
            desktopUrl:
                'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=$tid&page=$page',
            perPage: 20,
            posts: <ThreadPost>[
              ThreadPost(
                pid: '$sourceId-p1',
                author: 'alice',
                authorId: '1',
                message: '<p>可见正文</p>',
                number: 1,
                isFirst: true,
                dateline: 'today',
              ),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(repository, historyVisitRecorder: historyRecorder),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(Key('thread-post-card-$sourceId-p1')), findsOneWidget);
      expect(historyRecorder.drafts, hasLength(1));
      expect(historyRecorder.drafts.single.title, '$source 主题');
    });
  }

  testWidgets('failed initial load records only after retry succeeds', (
    tester,
  ) async {
    final historyRecorder = _RecordingHistoryVisitRecorder();
    var callCount = 0;
    final repository = _FakeThreadRepository((tid, page) async {
      callCount++;
      if (callCount == 1) {
        return const ApiFailure<ThreadDetailData>(
          ApiError(type: ApiErrorType.network, message: '加载失败'),
        );
      }
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            ThreadPost(
              pid: 'retry-p1',
              author: 'alice',
              authorId: '1',
              message: '<p>重试后的正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, historyVisitRecorder: historyRecorder),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-detail-retry-button')), findsOneWidget);
    expect(historyRecorder.drafts, isEmpty);

    await tester.tap(find.byKey(const Key('thread-detail-retry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('thread-post-card-retry-p1')), findsOneWidget);
    expect(historyRecorder.drafts, hasLength(1));
  });

  testWidgets('history failures never replace visible thread content', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            ThreadPost(
              pid: 'history-failure-p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文仍然可见</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        historyVisitRecorder: const _ThrowingHistoryVisitRecorder(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const Key('thread-post-card-history-failure-p1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('thread-detail-retry-button')), findsNothing);
  });

  testWidgets('late content after route disposal does not record', (
    tester,
  ) async {
    final result = Completer<ApiResult<ThreadDetailData>>();
    final historyRecorder = _RecordingHistoryVisitRecorder();
    final repository = _FakeThreadRepository((tid, page) => result.future);

    await tester.pumpWidget(
      _buildTestApp(repository, historyVisitRecorder: historyRecorder),
    );
    await tester.pump();
    expect(historyRecorder.drafts, isEmpty);

    await tester.pumpWidget(const LocalizedTestApp(home: SizedBox.shrink()));
    result.complete(
      ApiSuccess(
        _threadDetailData(
          tid: '100',
          posts: <ThreadPost>[
            ThreadPost(
              pid: 'late-p1',
              author: 'alice',
              authorId: '1',
              message: '<p>迟到正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(historyRecorder.drafts, isEmpty);
  });

  testWidgets('a new route records another visit to the same TID', (
    tester,
  ) async {
    final historyRecorder = _RecordingHistoryVisitRecorder();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: <ThreadPost>[
            ThreadPost(
              pid: 'route-p1',
              author: 'alice',
              authorId: '1',
              message: '<p>路由正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        historyVisitRecorder: historyRecorder,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-native-thread-route'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ThreadDetailPage(tid: '100', subject: '测试主题'),
                    ),
                  );
                },
                child: const Text('打开帖子'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-native-thread-route')));
    await tester.pumpAndSettle();
    expect(historyRecorder.drafts, hasLength(1));

    Navigator.of(tester.element(find.byType(ThreadDetailPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-native-thread-route')));
    await tester.pumpAndSettle();

    expect(historyRecorder.drafts, hasLength(2));
    expect(
      historyRecorder.drafts.map((draft) => draft.target.id),
      everyElement('100'),
    );
  });
}
