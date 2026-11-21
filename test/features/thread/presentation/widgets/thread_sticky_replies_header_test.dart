import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/media/device_memory_profile.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/thread/domain/thread_content_classifier.dart';
import 'package:y300/features/thread/presentation/thread_detail_state.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_widgets.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'sticky replies header stays visible when switching to reverse order while scrolled in eInk mode',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      final previousMemory = DeviceMemoryProfileStore.current;
      DeviceMemoryProfileStore.current = const DeviceMemoryProfile(
        isLowRamDevice: true,
      );
      final scrollController = ScrollController();
      addTearDown(() {
        scrollController.dispose();
        DeviceMemoryProfileStore.current = previousMemory;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firstPost = _post(
        pid: 'p1',
        number: 1,
        isFirst: true,
        paragraphs: 120,
      );
      final replies = [
        for (var i = 2; i <= 25; i++)
          _post(pid: 'p$i', number: i, paragraphs: 4),
      ];

      late void Function(ThreadDetailPageState next) updateState;
      var currentState = _state(
        posts: [firstPost, ...replies],
        queryParameters: const <String, String>{},
      );

      await tester.pumpWidget(
        _harness(
          scrollController: scrollController,
          builder: (setState) {
            updateState = (next) => setState(() => currentState = next);
            return currentState;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      final targetOffset = scrollController.position.maxScrollExtent * 0.7;
      scrollController.jumpTo(targetOffset);
      await tester.pump();
      await tester.pump();

      final sticky = find.byKey(
        const Key('thread-detail-sticky-replies-header'),
      );
      expect(sticky, findsOneWidget);
      final stickyBox = tester.renderObject<RenderBox>(sticky);
      expect(stickyBox.paintBounds.isEmpty, isFalse);
      final visibility = tester.widget<Visibility>(
        find.ancestor(of: sticky, matching: find.byType(Visibility)).first,
      );
      expect(visibility.visible, isTrue);

      // 切换倒序后首楼之外的回帖倒序排列，原地停在回复区时吸顶栏仍须保持可见。
      updateState(
        _state(
          posts: [firstPost, ...replies.reversed],
          queryParameters: const <String, String>{'ordertype': '1'},
        ),
      );
      await tester.pump();
      await tester.pump();

      final stickyAfter = find.byKey(
        const Key('thread-detail-sticky-replies-header'),
      );
      expect(stickyAfter, findsOneWidget);
      final visibilityAfter = tester.widget<Visibility>(
        find.ancestor(of: stickyAfter, matching: find.byType(Visibility)).first,
      );
      expect(visibilityAfter.visible, isTrue);
      final listTop = tester
          .getTopLeft(find.byKey(const Key('thread-detail-list')))
          .dy;
      expect(tester.getTopLeft(stickyAfter).dy, closeTo(listTop, 1.0));
    },
  );

  testWidgets(
    'sticky replies header stays pinned on reply-only reverse page and after direct eInk jumpTo',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      final previousMemory = DeviceMemoryProfileStore.current;
      DeviceMemoryProfileStore.current = const DeviceMemoryProfile(
        isLowRamDevice: true,
      );
      final scrollController = ScrollController();
      addTearDown(() {
        scrollController.dispose();
        DeviceMemoryProfileStore.current = previousMemory;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firstPost = _post(
        pid: 'p1',
        number: 1,
        isFirst: true,
        paragraphs: 140,
      );
      final replies = [
        for (var i = 2; i <= 20; i++)
          _post(pid: 'p$i', number: i, paragraphs: 5),
      ];

      late void Function(ThreadDetailPageState next) updateState;
      var currentState = _state(
        posts: [firstPost, ...replies],
        queryParameters: const <String, String>{},
      );

      await tester.pumpWidget(
        _harness(
          scrollController: scrollController,
          builder: (setState) {
            updateState = (next) => setState(() => currentState = next);
            return currentState;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      // 未测量过内联回复栏时直接按墨水屏 85% 单次 jumpTo 跨过超长首楼，仍须立即吸顶。
      final maxExtent = scrollController.position.maxScrollExtent;
      scrollController.jumpTo(maxExtent * 0.8);
      await tester.pump();
      await tester.pump();

      final sticky = find.byKey(
        const Key('thread-detail-sticky-replies-header'),
      );
      expect(
        tester
            .widget<Visibility>(
              find
                  .ancestor(of: sticky, matching: find.byType(Visibility))
                  .first,
            )
            .visible,
        isTrue,
      );

      // 切换到多页倒序（无首楼、repliesHeader 在 index 0）并保持在回复区，同样保留吸顶。
      updateState(
        _state(
          posts: replies.reversed.toList(growable: false),
          currentPage: 2,
          queryParameters: const <String, String>{'ordertype': '1'},
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<Visibility>(
              find
                  .ancestor(of: sticky, matching: find.byType(Visibility))
                  .first,
            )
            .visible,
        isTrue,
      );

      // 回到顶部后恢复内联显示、取消吸顶。
      scrollController.jumpTo(0);
      await tester.pump();
      await tester.pump();

      final stickySurface = find.byKey(
        const Key('thread-detail-sticky-replies-header-surface'),
      );
      expect(sticky, findsNothing);
      expect(
        tester
            .widget<Visibility>(
              find
                  .ancestor(
                    of: stickySurface,
                    matching: find.byType(Visibility),
                  )
                  .first,
            )
            .visible,
        isFalse,
      );
      final inline = find.byKey(const Key('thread-detail-replies-header'));
      expect(
        tester
            .widget<Visibility>(
              find
                  .ancestor(of: inline, matching: find.byType(Visibility))
                  .first,
            )
            .visible,
        isTrue,
      );
    },
  );
}

Widget _harness({
  required ScrollController scrollController,
  required ThreadDetailPageState Function(StateSetter setState) builder,
}) {
  return ProviderScope(
    overrides: [blacklistedUserIdsProvider.overrideWithValue(const <String>{})],
    child: LocalizedTestApp(
      home: EInkModeScope(
        enabled: true,
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ThreadDetailContent(
              state: builder(setState),
              scrollController: scrollController,
              enableBodyChunking: false,
              imageReferer: 'https://bbs.yamibo.com/',
              onLoadPreviousPage: () {},
              onLoadNextPage: () {},
              onLoadPageNumber: (_) {},
              onOpenAuthorProfile: (_) {},
              onOpenCommentAuthorProfile: (_) {},
              onCopyActionUrl: (_, _) {},
              onOpenPostLink: (_) {},
              onOpenPostActions: (_) {},
              onTogglePollOption: (_, _) {},
              onSubmitPollVote: (_) {},
              onToggleAuthorFilter: () {},
              onOrderChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

ThreadPost _post({
  required String pid,
  required int number,
  bool isFirst = false,
  int paragraphs = 1,
}) {
  return ThreadPost(
    pid: pid,
    author: 'author$number',
    authorId: '$number',
    message: List.generate(paragraphs, (i) => '<p>楼层$number 第$i段正文</p>').join(),
    number: number,
    isFirst: isFirst,
    dateline: '2026-11-21 08:00',
  );
}

ThreadDetailPageState _state({
  required List<ThreadPost> posts,
  required Map<String, String> queryParameters,
  int currentPage = 1,
}) {
  return ThreadDetailPageState(
    tid: '100',
    fid: '2',
    typeid: '',
    typeName: null,
    forumName: '动漫区',
    forumUrl: null,
    sourceTagName: null,
    contentKind: ThreadContentKind.forum,
    subject: '测试帖子主题',
    views: 100,
    replies: 24,
    currentPage: currentPage,
    lastPage: 2,
    previousPageUrl: null,
    nextPageUrl: null,
    reverseOrderUrl: null,
    onlyAuthorUrl: null,
    favoriteUrl: null,
    shareUrl: null,
    homeUrl: null,
    desktopUrl: null,
    hasMore: false,
    queryParameters: queryParameters,
    isLoadingInitial: false,
    isLoadingMore: false,
    posts: posts,
    isThreadFavorited: false,
    isThreadFavoriteActionLoading: false,
    threadFavoriteHint: null,
    selectedPollOptionIds: const <String>{},
    isPollVoteSubmitting: false,
    pollVoteHint: null,
    capabilities: ThreadDetailReadCapabilities(
      paginationPrecision: PaginationPrecision.exact,
      values: DataCapabilitySet<ThreadDetailCapability>.supported(
        ThreadDetailCapability.values,
      ),
    ),
    replyText: '',
    isReplySubmitting: false,
    replyHint: null,
  );
}
