import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_client_provider.dart';
import 'package:y300/features/thread/data/providers/thread_interaction_providers.dart';
import 'package:y300/features/thread/data/providers/thread_repository_providers.dart';
import 'package:y300/features/thread/presentation/thread_detail_controller.dart';

void main() {
  test('keeps known reply counts when the next page omits them', () async {
    final repository = _PagedThreadRepository({
      1: _detail(page: 1, replies: 52, views: 120, countsKnown: true),
      2: _detail(page: 2, replies: 0, views: 0, countsKnown: false),
    });
    final container = _container(repository);
    final provider = threadDetailControllerProvider(
      const ThreadDetailArgs(tid: '100', subject: 'Fixture thread'),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(provider.future);
    expect(container.read(provider).value!.replies, 52);

    await container.read(provider.notifier).loadNextPage();

    final state = container.read(provider).value!;
    expect(state.currentPage, 2);
    expect(state.replies, 52);
    expect(state.views, 120);
    expect(repository.requestedPages, <int>[1, 2]);
  });

  test('adopts server counts when the loaded page provides them', () async {
    final repository = _PagedThreadRepository({
      1: _detail(page: 1, replies: 52, views: 120, countsKnown: true),
      2: _detail(page: 2, replies: 60, views: 141, countsKnown: true),
    });
    final container = _container(repository);
    final provider = threadDetailControllerProvider(
      const ThreadDetailArgs(tid: '100', subject: 'Fixture thread'),
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(provider.future);
    await container.read(provider.notifier).loadNextPage();

    final state = container.read(provider).value!;
    expect(state.replies, 60);
    expect(state.views, 141);
  });

  test(
    'failed loadNextPage preserves current page and does not wipe posts',
    () async {
      final repository = _PagedThreadRepository(
        {1: _detail(page: 1, replies: 52, views: 120, countsKnown: true)},
        failPages: const <int>{2},
      );
      final container = _container(repository);
      final provider = threadDetailControllerProvider(
        const ThreadDetailArgs(tid: '100', subject: 'Fixture thread'),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.future);
      await container.read(provider.notifier).loadNextPage();

      final state = container.read(provider).value!;
      expect(state.currentPage, 1);
      expect(state.posts, hasLength(1));
      expect(state.posts.first.pid, '1');
      expect(state.loadFailure, isNotNull);
    },
  );

  test(
    'switching to author-only view does not inherit unfiltered counts',
    () async {
      final repository = _PagedThreadRepository(
        {1: _detail(page: 1, replies: 52, views: 120, countsKnown: true)},
        authorPages: {
          1: _detail(page: 1, replies: 0, views: 0, countsKnown: false),
        },
      );
      final container = _container(repository);
      final provider = threadDetailControllerProvider(
        const ThreadDetailArgs(tid: '100', subject: 'Fixture thread'),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.future);
      await container.read(provider.notifier).openOnlyAuthor(authorId: '10');

      final state = container.read(provider).value!;
      expect(state.isOnlyAuthorView, isTrue);
      expect(state.replies, 0);
      expect(state.views, 0);
    },
  );
}

ProviderContainer _container(_PagedThreadRepository repository) {
  final container = ProviderContainer(
    overrides: [
      threadRepositoryProvider.overrideWithValue(repository),
      yamiboSessionStoreProvider.overrideWithValue(YamiboSessionStore()),
      threadPollVoteCommandProvider.overrideWithValue(_NoPollVoteCommand()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ThreadDetailData _detail({
  required int page,
  required int replies,
  required int views,
  required bool countsKnown,
}) {
  return ThreadDetailData(
    tid: '100',
    fid: '',
    subject: page == 1 ? 'Fixture thread' : '',
    author: 'Author',
    replies: replies,
    views: views,
    currentPage: page,
    perPage: 20,
    lastPage: 2,
    nextPageUrl: page == 1
        ? 'https://bbs.example.test/thread-100-2-1.html'
        : null,
    hasServerCounts: countsKnown,
    posts: page == 1
        ? [
            ThreadPost(
              pid: '1',
              author: 'Author',
              authorId: '10',
              message: '<p>Opening.</p>',
              number: 1,
              isFirst: true,
              dateline: '2026-01-01',
            ),
          ]
        : [
            ThreadPost(
              pid: '21',
              author: 'Reply author',
              authorId: '11',
              message: '<p>Second page reply.</p>',
              number: 21,
              isFirst: false,
              dateline: '2026-01-02',
            ),
          ],
  );
}

final class _PagedThreadRepository implements ThreadRepository {
  _PagedThreadRepository(
    this._pages, {
    this.failPages = const <int>{},
    this.authorPages = const <int, ThreadDetailData>{},
  });

  final Map<int, ThreadDetailData> _pages;
  final Set<int> failPages;
  final Map<int, ThreadDetailData> authorPages;
  final List<int> requestedPages = <int>[];

  @override
  ThreadDetailSourceCapabilities get capabilities =>
      ThreadDetailSourceCapabilities.full;

  @override
  Future<DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities>>
  getThreadDetail({
    required String tid,
    int page = 1,
    ThreadDetailQuery query = const ThreadDetailQuery(),
  }) async {
    requestedPages.add(page);
    if (failPages.contains(page)) {
      return const DataReadFailure(
        kind: DataReadFailureKind.network,
        code: 'network_error',
        diagnosticMessage: 'network_error',
      );
    }
    final source = (query.authorId?.isNotEmpty ?? false)
        ? authorPages[page]!
        : _pages[page]!;
    return DataReadSuccess<ThreadDetailData, ThreadDetailReadCapabilities>(
      data: source,
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

final class _NoPollVoteCommand implements ThreadPollVoteCommand {
  @override
  ThreadPollVoteCapabilities get capabilities => ThreadPollVoteCapabilities(
    values: DataCapabilitySet<ThreadPollVoteCapability>(const {}),
  );

  @override
  Future<DataCommandResult<ThreadPollVoteReceipt>> execute(
    ThreadPollVoteSubmission submission,
  ) {
    throw UnimplementedError();
  }
}
