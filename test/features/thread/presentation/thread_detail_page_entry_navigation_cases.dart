part of 'thread_detail_page_test.dart';

void _entryNavigationCases() {
  testWidgets('late reading close cannot pop a rebound thread owner', (
    tester,
  ) async {
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: 'bound',
          author: 'Author',
          replies: 0,
          views: 1,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: '200',
              author: 'Author',
              authorId: '10',
              message: '<p>body</p>',
              number: 1,
              isFirst: true,
              dateline: '',
            ),
          ],
        ),
      ),
    );
    final oldObserver = _ReadingLifecycleObserver();
    final nextObserver = _ReadingLifecycleObserver();
    var observer = oldObserver;
    var tid = '100';
    StateSetter? changeRoute;
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('reading-test-home'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StatefulBuilder(
                    builder: (context, setState) {
                      changeRoute = setState;
                      return ThreadDetailPage(
                        key: const Key('reading-owner'),
                        tid: tid,
                        targetPid: '200',
                        bodyReadingObserver: observer,
                      );
                    },
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('reading-test-home')));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    oldObserver.flushGate = gate;
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(oldObserver.flushCalls, greaterThan(0));
    changeRoute!(() {
      observer = nextObserver;
      tid = '101';
    });
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ThreadDetailPage>(find.byType(ThreadDetailPage)).tid,
      '101',
    );
    expect(nextObserver.retired, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bound system back flushes before retiring the reading route', (
    tester,
  ) async {
    final repository = _FakeThreadRepository(
      (String tid, int page) async =>
          ApiSuccess(_navigationData(page, pid: '200')),
    );
    final observer = _ReadingLifecycleObserver();
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('reading-test-home'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ThreadDetailPage(
                    tid: '100',
                    targetPid: '200',
                    bodyReadingObserver: observer,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('reading-test-home')));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    observer.flushGate = gate;
    final back = tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ThreadDetailPage), findsOneWidget);
    expect(observer.retired, isFalse);
    gate.complete();
    await back;
    await tester.pumpAndSettle();
    expect(find.byType(ThreadDetailPage), findsNothing);
    expect(observer.retired, isTrue);
  });

  testWidgets('loads one comment page, deduplicates IDs, and retries failure', (
    tester,
  ) async {
    final pending =
        Completer<
          DataReadResult<
            ThreadPostCommentsPage,
            ThreadPostCommentsReadCapabilities
          >
        >();
    var thirdAttempts = 0;
    final comments = _FakePagedCommentsRepository((query) async {
      if (query.page == 2) return pending.future;
      thirdAttempts++;
      if (thirdAttempts == 1) {
        return const DataReadFailure(
          kind: DataReadFailureKind.network,
          code: 'offline',
          diagnosticMessage: 'offline',
        );
      }
      if (thirdAttempts == 2) {
        return const DataReadFailure(
          kind: DataReadFailureKind.unauthorized,
          code: 'thread_post_comments_login_required',
          diagnosticMessage: 'thread_post_comments_login_required',
        );
      }
      if (thirdAttempts == 3) {
        return const DataReadFailure(
          kind: DataReadFailureKind.business,
          code: 'thread_post_comments_permission_denied',
          diagnosticMessage: 'thread_post_comments_permission_denied',
        );
      }
      return DataReadSuccess(
        data: const ThreadPostCommentsPage(
          tid: '100',
          pid: '200',
          page: 3,
          comments: [
            ThreadPostCommentEntry(
              author: 'Carol',
              message: 'Third page',
              dateline: 'today',
              commentId: '903',
            ),
          ],
          nextPage: null,
        ),
        capabilities: commentsCapabilities,
        metadata: const DataReadMetadata.network(),
      );
    });
    final client = _clientWithPagedComments(comments);
    final converter = _ThreadProjectionTestConverter(
      TextConversionMode.toTraditional,
    );
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '10',
          username: 'Alice',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: 'Comments',
          author: 'Alice',
          replies: 1,
          views: 1,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: '200',
              author: 'Alice',
              authorId: '10',
              message: '<p>Body</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              commentNextPage: 2,
              comments: const [
                ThreadPostCommentEntry(
                  author: 'Alice',
                  message: 'First page',
                  dateline: 'today',
                  commentId: '901',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        additionalOverrides: [
          yamiboForumClientProvider.overrideWithValue(client),
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          appServerContentConversionModeProvider.overrideWithValue(
            TextConversionMode.toTraditional,
          ),
          textConverterProvider.overrideWith((ref, mode) => converter),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    expect(find.text(l10n.threadCommentLoadMore), findsOneWidget);
    await tester.tap(find.byKey(const Key('thread-comment-load-more')));
    await tester.pump();
    expect(comments.queries, hasLength(1));
    expect(find.text(l10n.threadCommentLoadingMore), findsOneWidget);
    pending.complete(
      DataReadSuccess(
        data: const ThreadPostCommentsPage(
          tid: '100',
          pid: '200',
          page: 2,
          comments: [
            ThreadPostCommentEntry(
              author: 'Alice',
              message: 'Duplicate',
              dateline: 'today',
              commentId: '901',
            ),
            ThreadPostCommentEntry(
              author: 'Bob',
              message: '软件内容',
              dateline: 'today',
              commentId: '902',
            ),
            ThreadPostCommentEntry(
              author: 'Bob',
              message: 'Duplicate again',
              dateline: 'today',
              commentId: '902',
            ),
          ],
          nextPage: 3,
        ),
        capabilities: commentsCapabilities,
        metadata: const DataReadMetadata.network(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('軟體內容'), findsOneWidget);
    expect(find.text('Duplicate'), findsNothing);
    await tester.tap(find.byKey(const Key('thread-comment-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('軟體內容'), findsOneWidget);
    expect(find.text(l10n.threadCommentRetry), findsOneWidget);
    expect(find.text(l10n.threadCommentLoadFailed), findsOneWidget);
    await tester.tap(find.byKey(const Key('thread-comment-load-more')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.threadCommentLoginRequired), findsOneWidget);
    await tester.tap(find.byKey(const Key('thread-comment-load-more')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.threadCommentPermissionDenied), findsOneWidget);
    await tester.tap(find.byKey(const Key('thread-comment-load-more')));
    await tester.pumpAndSettle();
    expect(comments.queries.map((query) => query.page), [2, 3, 3, 3, 3]);
    expect(find.text('Third page'), findsOneWidget);
    expect(find.byKey(const Key('thread-comment-load-more')), findsNothing);
    sessionStore.saveExtracted(
      YamiboSessionSnapshot(
        isLoggedIn: true,
        uid: '11',
        username: 'Bob',
        formhash: '',
        updatedAt: DateTime(2026, 1, 2),
        source: 'test',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('軟體內容'), findsNothing);
    expect(find.text('Third page'), findsNothing);
    expect(find.text('First page'), findsOneWidget);
  });
  testWidgets('late comment page cannot attach to a replacement thread page', (
    tester,
  ) async {
    final pending =
        Completer<
          DataReadResult<
            ThreadPostCommentsPage,
            ThreadPostCommentsReadCapabilities
          >
        >();
    final comments = _FakePagedCommentsRepository((_) => pending.future);
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: 'Comments',
          author: 'Alice',
          replies: 1,
          views: 1,
          currentPage: page,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: page == 1 ? '200' : '201',
              author: 'Alice',
              authorId: '10',
              message: '<p>Body</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              commentNextPage: 2,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        additionalOverrides: [
          yamiboForumClientProvider.overrideWithValue(
            _clientWithPagedComments(comments),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThreadDetailPage)),
    );
    const args = ThreadDetailArgs(tid: '100', subject: '测试主题');
    final controller = container.read(
      threadDetailControllerProvider(args).notifier,
    );
    final post = container
        .read(threadDetailControllerProvider(args))
        .value!
        .posts
        .single;
    final loading = controller.loadMoreComments(post);
    await tester.pump();
    await controller.loadPage(2);
    pending.complete(
      DataReadSuccess(
        data: const ThreadPostCommentsPage(
          tid: '100',
          pid: '200',
          page: 2,
          comments: [
            ThreadPostCommentEntry(
              author: 'Old',
              message: 'Late',
              dateline: 'today',
              commentId: '902',
            ),
          ],
          nextPage: null,
        ),
        capabilities: commentsCapabilities,
        metadata: const DataReadMetadata.network(),
      ),
    );
    await loading;
    await tester.pumpAndSettle();
    final current = container.read(threadDetailControllerProvider(args)).value!;
    expect(current.posts.single.pid, '201');
    expect(current.commentsByPostId, isEmpty);
    expect(find.text('Late'), findsNothing);
  });

  testWidgets('empty interaction hint belongs only to body-end target', (
    tester,
  ) async {
    final state = ThreadDetailPageState.initial(tid: '100', subject: 'Title')
        .copyWith(
          posts: [
            ThreadPost(
              pid: '200',
              author: 'Alice',
              authorId: '10',
              message: '<p>Body</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        );
    Widget content(ThreadPostLanding landing) => ProviderScope(
      overrides: [
        imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
      ],
      child: LocalizedTestApp(
        home: Scaffold(
          body: ThreadDetailContent(
            state: state,
            targetPid: '200',
            landing: landing,
            imageReferer:
                'https://bbs.example.test/forum.php?mod=viewthread&tid=100',
            onLoadPreviousPage: () {},
            onLoadNextPage: () {},
            onOpenAuthorProfile: (_) {},
            onOpenCommentAuthorProfile: (_) {},
            onCopyActionUrl: (_, _) {},
            onOpenPostLink: (_) {},
            onOpenPostActions: (_) {},
            onTogglePollOption: (_, _) {},
            onSubmitPollVote: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(content(ThreadPostLanding.bodyEnd));
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailContent)),
    );
    expect(find.text(l10n.threadInteractionsEmpty), findsOneWidget);
    await tester.pumpWidget(content(ThreadPostLanding.top));
    await tester.pump();
    expect(find.text(l10n.threadInteractionsEmpty), findsNothing);
  });
  testWidgets(
    'target recovery invalidates a same-page snapshot and commits only verified history',
    (tester) async {
      final cache = _FakeNativePageCacheInvalidationService();
      final history = _RecordingHistoryVisitRecorder();
      final locator = _FakeThreadPostLocator(
        const ThreadPostLocation(tid: '100', pid: '200', page: 2, url: ''),
      );
      final repository = _FakeThreadRepository((tid, page, query) async {
        expect(query, isEmpty);
        return ApiSuccess(
          _navigationData(
            page,
            pid: cache.invalidatedThreadIds.isEmpty || page == 3
                ? '199'
                : '200',
          ),
        );
      });
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          threadPostLocator: locator,
          pageCacheInvalidationService: cache,
          historyVisitRecorder: history,
          home: const ThreadDetailPage(
            tid: '100',
            initialPage: 2,
            targetPid: '200',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.queryHistory, hasLength(2));
      expect(cache.invalidatedThreadIds, ['100']);
      expect(locator.calls, 1);
      expect(find.byKey(const Key('thread-post-card-200')), findsOneWidget);
      expect(history.drafts, hasLength(1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ThreadDetailPage)),
      );
      await container
          .read(
            threadDetailControllerProvider(
              const ThreadDetailArgs(
                tid: '100',
                initialPage: 2,
                targetPid: '200',
              ),
            ).notifier,
          )
          .loadPage(3);
      await tester.pumpAndSettle();
      expect(locator.calls, 1);
      expect(repository.queryHistory, hasLength(3));
      expect(find.byKey(const Key('thread-post-card-199')), findsOneWidget);
    },
  );

  testWidgets('body-end target consumes the initial detail handoff once', (
    tester,
  ) async {
    final handoff = _PageHandoff();
    final history = _RecordingHistoryVisitRecorder();
    final repository = _HandoffThreadRepository(handoff);
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        historyVisitRecorder: history,
        home: ThreadDetailPage(
          tid: '100',
          initialPage: 3,
          targetPid: '200',
          landing: ThreadPostLanding.bodyEnd,
          initialHandoff: handoff,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.handoffReads, 1);
    expect(repository.ordinaryReads, 0);
    expect(find.byKey(const Key('thread-post-body-entry-200')), findsOneWidget);
    expect(history.drafts, hasLength(1));
  });

  testWidgets(
    'unconfirmed target stops, retry is bounded and home requires user action',
    (tester) async {
      final history = _RecordingHistoryVisitRecorder();
      final locator = _FakeThreadPostLocator(
        const ThreadPostLocation(tid: '100', pid: '200', page: 3, url: ''),
      );
      final repository = _FakeThreadRepository(
        (tid, page) async => ApiSuccess(_navigationData(page, pid: '199')),
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          threadPostLocator: locator,
          historyVisitRecorder: history,
          home: const ThreadDetailPage(
            tid: '100',
            initialPage: 9,
            targetPid: '200',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThreadDetailPage)),
      );
      expect(find.text(l10n.threadPostTargetUnconfirmed), findsOneWidget);
      expect(repository.queryHistory, hasLength(2));
      expect(history.drafts, isEmpty);
      await tester.tap(find.byKey(const Key('thread-detail-retry-button')));
      await tester.pumpAndSettle();
      expect(repository.queryHistory, hasLength(4));
      expect(locator.calls, 2);
      expect(history.drafts, isEmpty);
      await tester.tap(find.text(l10n.threadPostOpenHome));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ThreadDetailPage>(find.byType(ThreadDetailPage))
            .targetPid,
        isNull,
      );
      expect(history.drafts, hasLength(1));
      expect(locator.calls, 2);
    },
  );

  testWidgets('target network failure never relocates or exposes raw payload', (
    tester,
  ) async {
    final locator = _FakeThreadPostLocator(null);
    final history = _RecordingHistoryVisitRecorder();
    final repository = _FakeThreadRepository(
      (tid, page) async => const ApiFailure<ThreadDetailData>(
        ApiError(type: ApiErrorType.network, message: 'private server payload'),
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        threadPostLocator: locator,
        historyVisitRecorder: history,
        home: const ThreadDetailPage(
          tid: '100',
          initialPage: 9,
          targetPid: '200',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    expect(find.text(l10n.threadPostLocationNetworkFailed), findsOneWidget);
    expect(find.textContaining('private server payload'), findsNothing);
    expect(repository.queryHistory, hasLength(1));
    expect(locator.calls, 0);
    expect(history.drafts, isEmpty);
  });

  testWidgets('cold entry keeps the title anchored until content is ready', (
    tester,
  ) async {
    final result = Completer<ApiResult<ThreadDetailData>>();
    final repository = _FakeThreadRepository((tid, page) => result.future);
    final history = _RecordingHistoryVisitRecorder();
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        historyVisitRecorder: history,
        home: const ThreadDetailPage(
          tid: '100',
          subject: '测试主题',
          initialForumName: 'fixture-forum',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppLoadingState), findsOneWidget);
    expect(find.text('fixture-forum'), findsOneWidget);
    expect(find.text('测试主题'), findsOneWidget);
    expect(find.byType(ThreadPostHtmlFirstBody), findsNothing);
    expect(find.byType(ForumCachedAvatar), findsNothing);
    expect(history.drafts, isEmpty);
    final titleRect = tester.getRect(find.text('测试主题'));
    final titleStyle = tester.widget<Text>(find.text('测试主题')).style;
    final statusFinder = find.byKey(AppLoadingState.labelKey);
    final statusRect = tester.getRect(statusFinder);
    expect(
      find.descendant(
        of: find.byType(AppLoadingState),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 299));
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(AppLoadingState.indicatorKey), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppLoadingState)),
    );
    final status = tester.widget<Text>(find.byKey(AppLoadingState.labelKey));
    expect(status.data, l10n.threadDetailLoading);
    expect(status.style!.color!.a, greaterThan(0));
    expect(tester.getRect(find.text('测试主题')), titleRect);
    expect(tester.getRect(statusFinder), statusRect);

    result.complete(
      ApiSuccess(
        _threadDetailData(
          tid: '100',
          posts: [
            _post(
              pid: 'entry-p1',
              author: 'fixture-user',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>fixture-body</p>',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLoadingState), findsNothing);
    expect(find.byKey(const Key('thread-post-card-entry-p1')), findsOneWidget);
    expect(tester.getRect(find.text('测试主题')), titleRect);
    expect(tester.widget<Text>(find.text('测试主题')).style, titleStyle);
    expect(repository.queryHistory, hasLength(1));
    expect(history.drafts, hasLength(1));
  });

  for (final dark in [false, true]) {
    testWidgets(
      'multiline entry title keeps its layout in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final subject = List.filled(3, '這是一個很長的測試標題').join();
        final result = Completer<ApiResult<ThreadDetailData>>();
        final repository = _FakeThreadRepository((tid, page) => result.future);
        await tester.pumpWidget(
          _buildTestApp(
            repository,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: ThreadDetailPage(tid: '100', subject: subject),
              ),
            ),
          ),
        );
        await tester.pump();
        final titleFinder = find.text(subject);
        final titleRect = tester.getRect(titleFinder);
        final titleStyle = tester.widget<Text>(titleFinder).style;
        List<Rect> lineBoxes() => tester
            .renderObject<RenderParagraph>(titleFinder)
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: subject.length),
            )
            .map((box) => box.toRect())
            .toList();
        final linesBefore = lineBoxes();
        expect(linesBefore.length, greaterThan(1));
        result.complete(
          ApiSuccess(
            _threadDetailData(
              tid: '100',
              subject: subject,
              posts: [
                _post(
                  pid: 'multiline-p1',
                  author: 'fixture-user',
                  authorId: '1',
                  number: 1,
                  isFirst: true,
                  message: '<p>fixture-body</p>',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppLoadingState), findsNothing);
        expect(tester.getRect(titleFinder), titleRect);
        expect(tester.widget<Text>(titleFinder).style, titleStyle);
        expect(lineBoxes(), linesBefore);
        expect(repository.queryHistory, hasLength(1));
      },
    );
  }

  for (final initialSubject in ['', 'fixture-old-title']) {
    testWidgets(
      'loaded title replaces ${initialSubject.isEmpty ? 'missing' : 'outdated'} route title',
      (tester) async {
        final result = Completer<ApiResult<ThreadDetailData>>();
        final repository = _FakeThreadRepository((tid, page) => result.future);
        await tester.pumpWidget(
          _buildTestApp(
            repository,
            home: ThreadDetailPage(tid: '100', subject: initialSubject),
          ),
        );
        if (initialSubject.isEmpty) {
          expect(
            find.byKey(const Key('thread-detail-first-post-summary')),
            findsNothing,
          );
        } else {
          expect(find.text(initialSubject), findsOneWidget);
        }
        result.complete(
          ApiSuccess(
            _threadDetailData(
              tid: '100',
              subject: 'fixture-current-title',
              posts: [
                _post(
                  pid: 'updated-title-p1',
                  author: 'fixture-user',
                  authorId: '1',
                  number: 1,
                  isFirst: true,
                  message: '<p>fixture-body</p>',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('fixture-current-title'), findsOneWidget);
        expect(find.byType(AppLoadingState), findsNothing);
        if (initialSubject.isNotEmpty) {
          expect(find.text(initialSubject), findsNothing);
        }
        expect(repository.queryHistory, hasLength(1));
      },
    );
  }

  testWidgets('fast entry does not wait for the loading indicator', (
    tester,
  ) async {
    final result = Completer<ApiResult<ThreadDetailData>>();
    final repository = _FakeThreadRepository((tid, page) => result.future);
    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump(const Duration(milliseconds: 40));
    result.complete(
      ApiSuccess(
        _threadDetailData(
          tid: '100',
          posts: [
            _post(
              pid: 'fast-p1',
              author: 'fixture-user',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>fixture-body</p>',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(AppLoadingState), findsNothing);
    expect(find.byKey(const Key('thread-post-card-fast-p1')), findsOneWidget);
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back navigation stays available while a cold read is pending', (
    tester,
  ) async {
    final result = Completer<ApiResult<ThreadDetailData>>();
    final repository = _FakeThreadRepository((tid, page) => result.future);
    final history = _RecordingHistoryVisitRecorder();
    await tester.pumpWidget(
      _buildTestApp(
        repository,
        historyVisitRecorder: history,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('fixture-open-thread'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ThreadDetailPage(tid: '100', subject: '测试主题'),
                ),
              ),
              child: const Text('fixture-list-entry'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('fixture-open-thread')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppLoadingState), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ThreadDetailPage), findsNothing);
    expect(find.byKey(const Key('fixture-open-thread')), findsOneWidget);
    result.complete(
      ApiSuccess(
        _threadDetailData(
          tid: '100',
          posts: [
            _post(
              pid: 'late-entry',
              author: 'fixture-user',
              authorId: '1',
              number: 1,
              isFirst: true,
              message: '<p>fixture-body</p>',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingState), findsNothing);
    expect(history.drafts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failure and retry preserve the title and restart the status delay',
    (tester) async {
      final first = Completer<ApiResult<ThreadDetailData>>();
      final retry = Completer<ApiResult<ThreadDetailData>>();
      var requests = 0;
      final repository = _FakeThreadRepository((tid, page) {
        return ++requests == 1 ? first.future : retry.future;
      });
      await tester.pumpWidget(_buildTestApp(repository));
      final titleRect = tester.getRect(find.text('测试主题'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(AppLoadingState.indicatorKey), findsOneWidget);
      first.complete(
        const ApiFailure(
          ApiError(type: ApiErrorType.network, message: 'fixture-failure'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppLoadingState), findsNothing);
      expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
      expect(tester.getRect(find.text('测试主题')), titleRect);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('thread-detail-retry-button')))
            .dy,
        greaterThan(titleRect.bottom),
      );
      await tester.tap(find.byKey(const Key('thread-detail-retry-button')));
      await tester.pump();
      expect(find.byType(AppLoadingState), findsOneWidget);
      expect(tester.getRect(find.text('测试主题')), titleRect);
      expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(AppLoadingState.indicatorKey), findsOneWidget);
      retry.complete(
        ApiSuccess(
          _threadDetailData(
            tid: '100',
            posts: [
              _post(
                pid: 'retry-p1',
                author: 'fixture-user',
                authorId: '1',
                number: 1,
                isFirst: true,
                message: '<p>fixture-body</p>',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppLoadingState), findsNothing);
      expect(
        find.byKey(const Key('thread-post-card-retry-p1')),
        findsOneWidget,
      );
      expect(requests, 2);
      expect(tester.getRect(find.text('测试主题')), titleRect);
    },
  );

  testWidgets('unexpected read errors offer retry instead of an empty page', (
    tester,
  ) async {
    Future<ApiResult<ThreadDetailData>> load(String tid, int page) async {
      throw StateError('private-fixture-error');
    }

    final repository = _FakeThreadRepository(load);
    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingState), findsNothing);
    expect(find.byKey(const Key('thread-detail-retry-button')), findsOneWidget);
    expect(find.textContaining('private-fixture-error'), findsNothing);
    expect(find.text('测试主题'), findsOneWidget);
  });

  test('light chip background follows forum list thread tag chip', () {
    final theme = AppTheme.light();
    final detailPalette = ThreadDetailNativePalette.resolve(theme);
    final displayPalette = ForumDisplayThemePalette.resolve(theme);

    expect(
      detailPalette.chipBackground,
      displayPalette.surfaceContainerHigh.withValues(alpha: 0.42),
    );
  });

  test('dark content accent uses a readable color-scheme role', () {
    final theme = AppTheme.dark();
    final palette = ThreadDetailNativePalette.resolve(theme);

    expect(palette.accent, theme.colorScheme.primary);
    expect(palette.onAccent, theme.colorScheme.onPrimary);
    expect(palette.accent, isNot(theme.appBarTheme.backgroundColor));
    expect(
      _contrastRatio(palette.accent, palette.panelBackground),
      greaterThanOrEqualTo(4.5),
    );
  });
}
