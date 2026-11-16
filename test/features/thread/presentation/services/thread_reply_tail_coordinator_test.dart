import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/thread/presentation/services/thread_reply_tail_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('blocked replies from visited pages move to the tail in page order', () {
    final reads = <int>[];
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (page) async {
        reads.add(page);
        return null;
      },
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [_post('p21', 21, authorId: 'blocked'), _post('p22', 22)],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    expect(coordinator.tailPending, isTrue);
    expect(reads, isEmpty);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 1,
      posts: [
        _post('p1', 1, authorId: 'blocked', isFirst: true),
        _post('p2', 2, authorId: 'blocked'),
        _post('p3', 3),
      ],
      isLastPage: false,
      blacklistedUserIds: const {'blocked'},
    );

    expect(coordinator.tailPosts.map((post) => post.pid), ['p2', 'p21']);
    expect(coordinator.movedPids, {'p2', 'p21'});
    expect(coordinator.showTail, isFalse);
  });

  test('the last page fills every unvisited page before completing', () async {
    final reads = <int>[];
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (page) async {
        reads.add(page);
        return ThreadReplyTailPage(
          page: page,
          posts: [
            if (page == 1) _post('p1', 1, isFirst: true),
            _post(
              'p${page}1',
              page * 10 + 1,
              authorId: page == 2 ? 'blocked' : 'normal',
            ),
            _post('p${page}2', page * 10 + 2),
          ],
          hasMore: page < 3,
        );
      },
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 3,
      posts: [_post('p31', 31, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 3,
      posts: [_post('p31', 31, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );

    await coordinator.ensureComplete(isCurrent: () => true);

    expect(reads, [1, 2]);
    expect(coordinator.complete, isTrue);
    expect(coordinator.tailPending, isFalse);
    expect(coordinator.tailPosts.map((post) => post.pid), ['p21', 'p31']);
  });

  test('a blocked topic body keeps its floor', () {
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (_) async => null,
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 1,
      posts: [
        _post('p1', 1, authorId: 'blocked', isFirst: true),
        _post('p2', 2, authorId: 'blocked'),
      ],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );

    expect(coordinator.tailPosts.map((post) => post.pid), ['p2']);
  });

  test('membership changes retire coverage and rescan the last page', () async {
    final reads = <int>[];
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (page) async {
        reads.add(page);
        return ThreadReplyTailPage(
          page: page,
          posts: [
            _post('p${page}1', page * 10 + 1, authorId: 'blocked'),
          ],
          hasMore: true,
        );
      },
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [_post('p21', 21)],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    await coordinator.ensureComplete(isCurrent: () => true);
    expect(coordinator.complete, isTrue);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [_post('p21', 21, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked', 'other'},
    );
    expect(coordinator.complete, isFalse);
    expect(coordinator.tailPosts.map((post) => post.pid), ['p21']);

    await coordinator.ensureComplete(isCurrent: () => true);
    expect(reads, [1, 1]);
    expect(coordinator.complete, isTrue);
  });

  test('a failed page read keeps the collected set and allows retry', () async {
    var failures = 1;
    final reads = <int>[];
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (page) async {
        reads.add(page);
        if (failures > 0) {
          failures -= 1;
          return null;
        }
        return ThreadReplyTailPage(
          page: page,
          posts: [_post('p${page}1', page * 10 + 1, authorId: 'blocked')],
          hasMore: true,
        );
      },
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 3,
      posts: [_post('p31', 31, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    await coordinator.ensureComplete(isCurrent: () => true);
    expect(coordinator.hasFailure, isTrue);
    expect(coordinator.complete, isFalse);
    expect(coordinator.tailPosts.map((post) => post.pid), ['p31']);

    await coordinator.ensureComplete(isCurrent: () => true, force: true);
    expect(coordinator.hasFailure, isFalse);
    expect(coordinator.complete, isTrue);
    expect(reads, [1, 1, 2]);
  });

  test('the per-pass budget leaves an explicit continuation', () async {
    final reads = <int>[];
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (page) async {
        reads.add(page);
        return ThreadReplyTailPage(
          page: page,
          posts: [_post('p${page}1', page * 10 + 1, authorId: 'blocked')],
          hasMore: true,
        );
      },
      maxPagesPerPass: 2,
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 4,
      posts: [_post('p41', 41, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    await coordinator.ensureComplete(isCurrent: () => true);
    expect(coordinator.hasBudgetLimitation, isTrue);
    expect(coordinator.complete, isFalse);
    expect(reads, [1, 2]);

    // The automatic path does not spin; the next explicit action continues.
    await coordinator.ensureComplete(isCurrent: () => true);
    expect(reads, [1, 2]);

    await coordinator.ensureComplete(isCurrent: () => true, force: true);
    expect(reads, [1, 2, 3]);
    expect(coordinator.complete, isTrue);
  });

  test('thread and query changes discard the collected set', () {
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (_) async => null,
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [_post('p21', 21, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    expect(coordinator.tailPosts, hasLength(1));

    coordinator.observe(
      threadId: '100',
      queryIdentity: 'ordertype=1',
      page: 1,
      posts: [_post('p11', 11, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    expect(coordinator.tailPosts.map((post) => post.pid), ['p11']);
  });

  test('a pinned target stays on its floor and out of the moved set', () {
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (_) async => null,
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [
        _post('p21', 21, authorId: 'blocked'),
        _post('p22', 22, authorId: 'blocked'),
      ],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
      pinnedPid: 'p21',
    );

    expect(coordinator.movedPids, {'p22'});
    expect(coordinator.tailPosts.map((post) => post.pid), ['p21', 'p22']);
  });

  test('duplicate posts across pages are collected once', () {
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (_) async => null,
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [_post('dup', 5, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 1,
      posts: [
        _post('p1', 1, isFirst: true),
        _post('dup', 5, authorId: 'blocked'),
      ],
      isLastPage: false,
      blacklistedUserIds: const {'blocked'},
    );

    expect(coordinator.tailPosts.map((post) => post.pid), ['dup']);
  });

  test('a late page read cannot enter a new generation', () async {
    final gate = Completer<ThreadReplyTailPage?>();
    final coordinator = ThreadReplyTailCoordinator(
      readPage: (_) => gate.future,
    );
    addTearDown(coordinator.dispose);

    coordinator.observe(
      threadId: '100',
      queryIdentity: '',
      page: 2,
      posts: [_post('p21', 21, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    final operation = coordinator.ensureComplete(isCurrent: () => true);
    coordinator.observe(
      threadId: '200',
      queryIdentity: '',
      page: 2,
      posts: [_post('late', 22, authorId: 'blocked')],
      isLastPage: true,
      blacklistedUserIds: const {'blocked'},
    );
    gate.complete(
      ThreadReplyTailPage(
        page: 1,
        posts: [_post('stale', 1, authorId: 'blocked')],
        hasMore: true,
      ),
    );
    await operation;

    expect(coordinator.tailPosts.map((post) => post.pid), ['late']);
  });
}

ThreadPost _post(
  String pid,
  int number, {
  String authorId = 'normal',
  bool isFirst = false,
}) {
  return ThreadPost(
    pid: pid,
    author: 'author',
    authorId: authorId,
    message: '<p>body</p>',
    number: number,
    isFirst: isFirst,
    dateline: 'today',
  );
}
