part of 'thread_detail_page_test.dart';

void _postLoadReconcileCases() {
  for (final change in ['completed', 'identity']) {
    for (final succeeds in [true, false]) {
      testWidgets(
        'append reconciles post loads after $change success=$succeeds',
        (tester) async {
          final append = Completer<ApiResult<ThreadDetailData>>();
          Future<ApiResult<ThreadDetailData>> readPage(
            String tid,
            int page,
          ) async {
            if (page == 2) return append.future;
            return ApiSuccess(_postLoadingTestData(tid, page));
          }

          final repository = _FakeThreadRepository(readPage);
          final ratings = _ControlledThreadPostRatingsRepository();
          final comments = _FakePagedCommentsRepository(
            (query) async => DataReadSuccess(
              data: ThreadPostCommentsPage(
                tid: query.tid,
                pid: query.pid,
                page: query.page,
                comments: const [
                  ThreadPostCommentEntry(
                    author: 'test',
                    message: 'private continuation',
                    dateline: '',
                    commentId: '901',
                  ),
                ],
                nextPage: null,
              ),
              capabilities: commentsCapabilities,
              metadata: const DataReadMetadata.network(),
            ),
          );
          final sessions = YamiboSessionStore();
          await tester.pumpWidget(
            _buildTestApp(
              repository,
              postRatingsRepository: ratings,
              additionalOverrides: [
                yamiboForumClientProvider.overrideWithValue(
                  _clientWithPagedComments(comments),
                ),
                yamiboSessionStoreProvider.overrideWithValue(sessions),
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
              .requireValue
              .posts
              .first;
          Future<void> loadChildren() async {
            final ratingLoad = controller.loadAllRatings(post);
            ratings.completeSuccess();
            await ratingLoad;
            await controller.loadMoreComments(post);
          }

          if (change == 'identity') await loadChildren();
          final loadingMore = controller.loadMore();
          if (change == 'completed') {
            await loadChildren();
          } else {
            sessions.saveExtracted(
              YamiboSessionSnapshot(
                isLoggedIn: true,
                uid: 'new-owner',
                username: 'test',
                formhash: '',
                updatedAt: DateTime(2026, 1, 1),
                source: 'test',
              ),
            );
          }
          final latest = container
              .read(threadDetailControllerProvider(args))
              .requireValue;
          if (change == 'identity') expect(latest.commentsByPostId, isEmpty);
          append.complete(
            succeeds
                ? ApiSuccess(_postLoadingTestData('100', 2))
                : const ApiFailure(
                    ApiError(
                      type: ApiErrorType.network,
                      message: 'append failure',
                    ),
                  ),
          );
          await loadingMore;
          await tester.pumpAndSettle();
          final result = container
              .read(threadDetailControllerProvider(args))
              .requireValue;
          expect(result.ratingsByPostId, same(latest.ratingsByPostId));
          expect(result.commentsByPostId, same(latest.commentsByPostId));
          expect(
            result.ratingsByPostId['200']!.status,
            ThreadPostRatingsLoadStatus.loaded,
          );
          expect(result.commentsByPostId.isEmpty, change == 'identity');
        },
      );
    }
  }

  testWidgets(
    'provider rebuild retires both old loaders and creates fresh owners',
    (tester) async {
      final ratings = _ControlledThreadPostRatingsRepository();
      final pendingComments =
          Completer<
            DataReadResult<
              ThreadPostCommentsPage,
              ThreadPostCommentsReadCapabilities
            >
          >();
      final comments = _FakePagedCommentsRepository(
        (query) => pendingComments.future,
      );
      final repository = _FakeThreadRepository(
        (String tid, int page) async =>
            ApiSuccess(_postLoadingTestData(tid, page)),
      );
      await tester.pumpWidget(
        _buildTestApp(
          repository,
          postRatingsRepository: ratings,
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
          .requireValue
          .posts
          .first;
      final oldRating = controller.loadAllRatings(post);
      final oldComments = controller.loadMoreComments(post);
      container.invalidate(threadDetailControllerProvider(args));
      await tester.pumpAndSettle();
      ratings.completeSuccess();
      pendingComments.complete(
        DataReadSuccess(
          data: const ThreadPostCommentsPage(
            tid: '100',
            pid: '200',
            page: 2,
            comments: [],
            nextPage: null,
          ),
          capabilities: commentsCapabilities,
          metadata: const DataReadMetadata.network(),
        ),
      );
      await Future.wait([oldRating, oldComments]);
      final replaced = container
          .read(threadDetailControllerProvider(args))
          .requireValue;
      expect(replaced.ratingsByPostId, isEmpty);
      expect(replaced.commentsByPostId, isEmpty);
      final current = container.read(
        threadDetailControllerProvider(args).notifier,
      );
      await current.loadAllRatings(replaced.posts.first);
      await current.loadMoreComments(replaced.posts.first);
      expect(ratings.loadCount, 2);
      expect(comments.queries, hasLength(2));
      expect(
        container
            .read(threadDetailControllerProvider(args))
            .requireValue
            .ratingsByPostId['200']!
            .status,
        ThreadPostRatingsLoadStatus.loaded,
      );
    },
  );
}
