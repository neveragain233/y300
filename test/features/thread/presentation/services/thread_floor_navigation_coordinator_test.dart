import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/presentation/services/thread_floor_navigation_coordinator.dart';

void main() {
  testWidgets(
    'single navigation reaches the actual bottom after the last header',
    (tester) async {
      final viewport = _Viewport()..visiblePostId = 'p3';
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => const ThreadFloorPage(
          owner: 'thread',
          page: 1,
          pids: ['p1', 'p2', 'p3'],
          hasPrevious: false,
          hasNext: false,
        ),
        loadAdjacent: (_, _) async => false,
      )..bind(viewport);
      addTearDown(nav.dispose);
      expect(nav.atEnd, isFalse);
      await nav.advance(animate: false);
      expect(viewport.pageEnds, 1);
      expect(nav.atEnd, isTrue);
    },
  );
  testWidgets('single navigation at the leading edge resets to forward', (
    tester,
  ) async {
    final viewport = _Viewport();
    final nav = ThreadFloorNavigationCoordinator(
      readPage: _page,
      loadAdjacent: (_, _) async => false,
    )..bind(viewport);
    addTearDown(nav.dispose);
    nav.reverseDirection();
    expect(nav.atEnd, isFalse);
    await nav.advance(animate: false);
    expect(nav.forward, isTrue);
    expect(viewport.targets, isEmpty);
    await nav.advance(animate: false);
    expect(viewport.targets, ['p2']);
  });
  testWidgets(
    'manual scrolling keeps the single direction and a query resets it',
    (tester) async {
      var page = _page();
      final viewport = _Viewport()..visiblePostId = 'p2';
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => page,
        loadAdjacent: (_, _) async => false,
      )..bind(viewport);
      addTearDown(nav.dispose);
      nav.reverseDirection();
      nav.userScrolled();
      expect(nav.forward, isFalse);
      page = _page(owner: 'reverse-order');
      nav.refresh();
      expect(nav.forward, isTrue);
      nav.reverseDirection();
      await nav.firstPost(animate: false);
      expect(nav.forward, isTrue);
    },
  );
  testWidgets(
    'single endpoint requests merge and a drag retires confirmation',
    (tester) async {
      final gate = Completer<void>();
      final viewport = _Viewport()
        ..visiblePostId = 'last'
        ..endGate = gate;
      var confirmations = 0;
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => const ThreadFloorPage(
          owner: 'thread',
          page: 1,
          pids: ['last'],
          hasPrevious: false,
          hasNext: false,
        ),
        loadAdjacent: (_, _) async => false,
        onConfirmed: () => confirmations++,
      )..bind(viewport);
      addTearDown(nav.dispose);
      final first = nav.advance(animate: false);
      expect(identical(first, nav.advance(animate: false)), isTrue);
      expect(viewport.pageEnds, 1);
      nav.userScrolled();
      gate.complete();
      await first;
      expect(confirmations, 0);
      expect(nav.atEnd, isFalse);
    },
  );
  testWidgets(
    'last post body reaches the page end before a separate tap loads the page',
    (tester) async {
      var page = _page();
      var loads = 0;
      var confirmed = 0;
      final viewport = _Viewport();
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => page,
        loadAdjacent: (forward, current) async {
          loads++;
          page = _page(number: 2, pids: ['p4', 'p5']);
          return true;
        },
        onConfirmed: () => confirmed++,
      );
      addTearDown(nav.dispose);
      nav.bind(viewport);
      await nav.move(true, animate: false);
      expect(viewport.targets, ['p2']);
      await nav.move(true, animate: false);
      expect(viewport.targets, ['p2', 'p3']);
      expect(loads, 0);

      // 末楼楼头可见不等于页尾：本次操作只把正文读到底。
      await nav.move(true, animate: false);
      expect(viewport.targets, ['p2', 'p3']);
      expect(viewport.pageEnds, 1);
      expect(loads, 0);
      expect(confirmed, 3);

      final pending = nav.move(true, animate: false);
      await _settle(tester, pending);
      expect(loads, 1);
      expect(viewport.targets.last, 'p4');
      expect(confirmed, 4);
    },
  );
  testWidgets('reverse and missing floor numbers follow display order', (
    tester,
  ) async {
    final viewport = _Viewport();
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => _page(pids: ['p1', 'p90', 'p7']),
      loadAdjacent: (_, _) async => false,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    await nav.move(true, animate: false);
    await nav.move(true, animate: false);
    expect(viewport.targets, ['p90', 'p7']);
    await nav.move(false, animate: false);
    expect(viewport.targets.last, 'p90');
    nav.reverseDirection();
    expect(nav.forward, isFalse);
    await nav.firstPost(animate: false);
    expect(viewport.targets.last, 'p1');
  });
  testWidgets(
    'duplicate cross-page taps share one operation and drag retires it',
    (tester) async {
      final gate = Completer<bool>();
      var loads = 0;
      final viewport = _Viewport()
        ..visiblePostId = 'p3'
        ..atBottom = true;
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => _page(),
        loadAdjacent: (_, _) {
          loads++;
          return gate.future;
        },
      );
      addTearDown(nav.dispose);
      nav.bind(viewport);
      final first = nav.move(true, animate: false);
      final second = nav.move(true, animate: false);
      expect(identical(first, second), isTrue);
      expect(loads, 1);
      nav.userScrolled();
      gate.complete(true);
      await first;
      expect(viewport.targets, isEmpty);
      expect(nav.isNavigating, isFalse);
    },
  );
  testWidgets('opposite navigation retires a pending forward arrival', (
    tester,
  ) async {
    final gate = Completer<bool>();
    final viewport = _Viewport()..visiblePostId = 'p3';
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => _page(),
      loadAdjacent: (_, _) => gate.future,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    final first = nav.move(true, animate: false);
    await nav.move(false, animate: false);
    gate.complete(true);
    await first;
    expect(viewport.targets, ['p2']);
  });
  testWidgets('query and viewport changes reject the previous arrival', (
    tester,
  ) async {
    var page = _page();
    final gate = Completer<bool>();
    final viewport = _Viewport()..visiblePostId = 'p3';
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => page,
      loadAdjacent: (_, _) => gate.future,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    final first = nav.move(true, animate: false);
    page = _page(owner: 'author-only');
    nav.refresh();
    nav.bind(_Viewport());
    gate.complete(true);
    await first;
    expect(viewport.targets, isEmpty);
    expect(nav.isNavigating, isFalse);
  });
  testWidgets('boundary feedback is deduplicated per page and direction', (
    tester,
  ) async {
    var boundaries = 0;
    final viewport = _Viewport()
      ..visiblePostId = 'p3'
      ..registerPageEnd = false;
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => const ThreadFloorPage(
        owner: 'thread',
        page: 1,
        pids: ['p1', 'p2', 'p3'],
        hasPrevious: false,
        hasNext: false,
      ),
      loadAdjacent: (_, _) async => false,
      onBoundaryReached: () => boundaries++,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    await nav.advance(animate: false);
    await nav.advance(animate: false);
    expect(viewport.pageEnds, 2);
    expect(boundaries, 1);
  });

  testWidgets('current floor follows the actual viewport after arrival', (
    tester,
  ) async {
    final viewport = _Viewport();
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => const ThreadFloorPage(
        owner: 'thread',
        page: 1,
        pids: ['p1', 'p2', 'p3', 'p4'],
        hasPrevious: false,
        hasNext: false,
      ),
      loadAdjacent: (_, _) async => false,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    await nav.move(true, animate: false);
    expect(viewport.targets, ['p2']);
    // 已确认目标不再覆盖用户之后实际停留的位置。
    viewport.visiblePostId = 'p1';
    await nav.move(true, animate: false);
    expect(viewport.targets, ['p2', 'p2']);
  });

  testWidgets('image stops run before the next floor in body order', (
    tester,
  ) async {
    final viewport = _Viewport()
      ..visiblePostId = 'p1'
      ..imageStopsByPid['p1'] = const [
        ThreadFloorImageStop(
          postId: 'p1',
          index: 0,
          cacheKey: 'a',
          url: 'a',
          offset: 120,
        ),
        ThreadFloorImageStop(
          postId: 'p1',
          index: 1,
          cacheKey: 'b',
          url: 'b',
          offset: 400,
        ),
      ];
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => _page(),
      loadAdjacent: (_, _) async => false,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    await nav.move(true, animate: false);
    expect(viewport.revealedImages.map((stop) => stop.index), [0]);
    await nav.move(true, animate: false);
    expect(viewport.revealedImages.map((stop) => stop.index), [0, 1]);
    await nav.move(true, animate: false);
    expect(viewport.revealedImages.map((stop) => stop.index), [0, 1]);
    expect(viewport.targets, ['p2']);
  });

  testWidgets('reversing into an image floor lands on its last stop', (
    tester,
  ) async {
    final viewport = _Viewport()
      ..visiblePostId = 'p2'
      ..scrollOffset = 10000
      ..imageStopsByPid['p1'] = const [
        ThreadFloorImageStop(
          postId: 'p1',
          index: 0,
          cacheKey: 'a',
          url: 'a',
          offset: 120,
        ),
        ThreadFloorImageStop(
          postId: 'p1',
          index: 1,
          cacheKey: 'b',
          url: 'b',
          offset: 400,
        ),
      ];
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => _page(),
      loadAdjacent: (_, _) async => false,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    await nav.move(false, animate: false);
    expect(viewport.revealedImages.single.index, 1);
    expect(viewport.targets, isEmpty);
    await nav.move(false, animate: false);
    expect(viewport.revealedImages.map((stop) => stop.index), [1, 0]);
    await nav.move(false, animate: false);
    expect(viewport.targets, ['p1']);
    expect(viewport.revealedImages.map((stop) => stop.index), [1, 0]);
  });

  testWidgets('image stops are looked up from the measured position', (
    tester,
  ) async {
    final viewport = _Viewport()
      ..visiblePostId = 'p1'
      ..scrollOffset = 200
      ..imageStopsByPid['p1'] = const [
        ThreadFloorImageStop(
          postId: 'p1',
          index: 0,
          cacheKey: 'a',
          url: 'a',
          offset: 120,
        ),
        ThreadFloorImageStop(
          postId: 'p1',
          index: 1,
          cacheKey: 'b',
          url: 'b',
          offset: 600,
        ),
        ThreadFloorImageStop(
          postId: 'p1',
          index: 2,
          cacheKey: 'c',
          url: 'c',
          offset: 650,
        ),
      ];
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => _page(),
      loadAdjacent: (_, _) async => false,
    );
    addTearDown(nav.dispose);
    nav.bind(viewport);
    await nav.move(true, animate: false);
    expect(viewport.revealedImages.single.offset, 600);
    await nav.move(true, animate: false);
    expect(viewport.revealedImages.map((stop) => stop.index), [1, 2]);
    // 当前楼图片走完后才换楼。
    await nav.move(true, animate: false);
    expect(viewport.targets, ['p2']);
    await nav.move(false, animate: false);
    expect(viewport.revealedImages.map((stop) => stop.index), [1, 2, 2]);
    expect(viewport.targets, ['p2']);
  });

  testWidgets(
    'failed adjacent page can be retried from the current last post',
    (tester) async {
      var page = _page();
      var loads = 0;
      final viewport = _Viewport()
        ..visiblePostId = 'p3'
        ..atBottom = true;
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => page,
        loadAdjacent: (_, _) async {
          loads++;
          if (loads == 1) return false;
          page = _page(number: 2, pids: ['p4']);
          return true;
        },
      );
      addTearDown(nav.dispose);
      nav.bind(viewport);
      await nav.move(true, animate: false);
      expect(viewport.targets, isEmpty);
      final retry = nav.move(true, animate: false);
      await _settle(tester, retry);
      expect(loads, 2);
      expect(viewport.targets, ['p4']);
    },
  );
}

ThreadFloorPage _page({
  int number = 1,
  List<String> pids = const ['p1', 'p2', 'p3'],
  Object owner = 'thread',
}) => ThreadFloorPage(
  owner: owner,
  page: number,
  pids: pids,
  hasPrevious: number > 1,
  hasNext: number == 1,
);

class _Viewport implements ThreadFloorViewport {
  @override
  bool atBottom = false;
  double scrollOffset = 0;
  bool postHeaderAbove = false;
  final imageStopsByPid = <String, List<ThreadFloorImageStop>>{};
  final revealedImages = <ThreadFloorImageStop>[];

  @override
  bool isPostHeaderAbove(String pid) => postHeaderAbove;

  @override
  double? get scrollPixels => scrollOffset;

  @override
  List<ThreadFloorImageStop> imageStops(String pid) =>
      imageStopsByPid[pid] ?? const [];

  @override
  Future<bool> revealImageStop(
    ThreadFloorImageStop stop, {
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return false;
    revealedImages.add(stop);
    scrollOffset = stop.offset;
    visiblePostId = stop.postId;
    postHeaderAbove = true;
    return true;
  }

  bool registerPageEnd = true;
  var pageEnds = 0;
  Completer<void>? endGate;
  @override
  Future<bool> revealPageEnd({
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    pageEnds++;
    await endGate?.future;
    if (!isCurrent()) return false;
    if (registerPageEnd) atBottom = true;
    return true;
  }

  @override
  String? visiblePostId = 'p1';
  final targets = <String>[];
  @override
  Future<bool> revealPost(
    String pid, {
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return false;
    targets.add(pid);
    visiblePostId = pid;
    atBottom = false;
    scrollOffset = 10000;
    postHeaderAbove = false;
    return true;
  }
}

Future<void> _settle(WidgetTester tester, Future<void> operation) async {
  var completed = false;
  operation.then((_) => completed = true);
  for (var frame = 0; frame < 10 && !completed; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(completed, isTrue);
  await operation;
}
