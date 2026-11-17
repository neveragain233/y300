import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' as riverpod_misc;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/data_source/api_result_data_read_adapter.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/domain/services/native_page_cache_invalidation_service.dart';
import 'package:y300/features/history/data/providers/history_providers.dart';
import 'package:y300/features/history/domain/models/history_models.dart';
import 'package:y300/features/history/domain/services/history_diagnostic_recorder.dart';
import 'package:y300/features/history/domain/services/history_visit_recorder.dart';
import 'package:y300/features/thread/data/providers/thread_repository_providers.dart';
import 'package:y300/features/thread/presentation/thread_detail_page.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_app_bar.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_widgets.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import '../../../test_support/localized_test_app.dart';

/// 帖子详情顶栏滚动标题与动作的定向测试。
///
/// 页面外壳只装配本页真正读取的服务；假数据固定为单帖长正文，滚动位置由
/// 测点几何算出，不依赖真实等待。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('keeps the forum name while the first post title is readable', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(_mainTitle(tester), '公告区');
    expect(_forumTitle(tester), isNull);
    expect(
      find.byKey(const Key('thread-detail-first-post-summary')),
      findsOneWidget,
    );
    // 只有板块名时不占副行，标题在固定高度的顶栏内上下居中。
    final slotCenter = tester.getCenter(
      find.byKey(ThreadDetailAppBar.copyLinkAreaKey),
    );
    final titleCenter = tester.getCenter(
      find.byKey(ThreadDetailAppBar.titleMainKey),
    );
    expect(titleCenter.dx, lessThan(slotCenter.dx));
    expect(titleCenter.dy, closeTo(slotCenter.dy, .5));
    expect(
      titleCenter.dy,
      closeTo(tester.getCenter(find.byType(AppBar)).dy, .5),
    );
    // 顶栏表面沿用主题 appBarTheme，不另铺强调色。
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, isNull);
  });

  testWidgets('keeps the shared circular back button on a pushed route', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page));
    });
    await tester.pumpWidget(
      _buildApp(
        repository,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-thread-detail'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ThreadDetailPage(tid: '100', subject: '测试主题'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-thread-detail')));
    await tester.pumpAndSettle();

    expect(find.byType(AppToolbarBackButton), findsOneWidget);
    await tester.tap(find.byType(AppToolbarBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadDetailPage), findsNothing);
  });

  testWidgets('switches to the subject after the first post title leaves', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await _scrollTitleBottomTo(tester, -12);

    expect(_mainTitle(tester), '测试主题');
    expect(_forumTitle(tester), '公告区');
  });

  testWidgets('holds the switched state inside the hysteresis band', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    // 边界上方 2 逻辑像素：仍在滞回带内，保持板块名。
    await _scrollTitleBottomTo(tester, -2);
    expect(_mainTitle(tester), '公告区');

    // 越过滞回带后切换为帖子标题。
    await _scrollTitleBottomTo(tester, -8);
    expect(_mainTitle(tester), '测试主题');

    // 回到边界上方 2 像素不足以恢复，避免临界抖动。
    await _scrollTitleBottomTo(tester, -2);
    expect(_mainTitle(tester), '测试主题');

    // 标题重新露出超过滞回带才恢复板块名。
    await _scrollTitleBottomTo(tester, 8);
    expect(_mainTitle(tester), '公告区');
  });

  testWidgets('restores the forum name when the first post title returns', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await _scrollTitleBottomTo(tester, -60);
    expect(_mainTitle(tester), '测试主题');

    final scrollable = _scrollable(tester);
    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await tester.pumpAndSettle();

    expect(_mainTitle(tester), '公告区');
    expect(_forumTitle(tester), isNull);
  });

  testWidgets('shows the subject and forum name on a later page', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(
        _pageData(tid, page, currentPage: 2, includesFirstPost: false),
      );
    });
    await tester.pumpWidget(_buildApp(repository, initialPage: 2));
    await tester.pumpAndSettle();

    expect(_mainTitle(tester), '测试主题');
    expect(_forumTitle(tester), '公告区');
    expect(
      find.byKey(const Key('thread-detail-first-post-summary')),
      findsNothing,
    );
  });

  testWidgets(
    'switches to the subject when reverse order hides the first post',
    (tester) async {
      final repository = _FakeThreadRepository((tid, page, query) async {
        final reverse = query['ordertype'] == '1';
        final data = _pageData(tid, page, replyCount: 3, reversed: reverse);
        return ApiSuccess(data);
      });
      await tester.pumpWidget(_buildApp(repository));
      await tester.pumpAndSettle();
      expect(_mainTitle(tester), '公告区');

      final l10n = _l10n(tester);
      await tester.tap(find.byKey(const Key('thread-detail-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.threadDetailReverseOrder));
      await tester.pumpAndSettle();

      expect(repository.queryHistory.last['ordertype'], '1');
      expect(_mainTitle(tester), '测试主题');
      expect(_forumTitle(tester), '公告区');
    },
  );

  testWidgets('falls back to the localized title without a subject', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, subject: '', currentPage: 2));
    });
    await tester.pumpWidget(_buildApp(repository, initialPage: 2, subject: ''));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(_mainTitle(tester), l10n.threadDetailTitle);
    expect(_forumTitle(tester), '公告区');
  });

  testWidgets('shows the subject for a target-centered list and restores it', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 6, subject: '目标帖子'));
    });
    await tester.pumpWidget(
      _buildApp(repository, targetPid: 'p-5', subject: '目标帖子'),
    );
    await tester.pumpAndSettle();

    // 目标楼层居中时首楼标题不在可读范围，顶栏直接显示帖子标题。
    expect(_mainTitle(tester), '目标帖子');
    expect(_forumTitle(tester), '公告区');

    final scrollable = _scrollable(tester);
    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await tester.pumpAndSettle();

    expect(_mainTitle(tester), '公告区');
  });

  testWidgets('keeps the bar height steady and does not rebuild the body', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    final barHeight = tester.getSize(find.byType(AppBar)).height;
    expect(barHeight, ThreadDetailAppBar.minimumToolbarHeight);
    final content = tester.widget<ThreadDetailContent>(
      find.byType(ThreadDetailContent),
    );
    final bodyTop = tester
        .getTopLeft(find.byKey(const Key('thread-detail-list')))
        .dy;

    await _scrollTitleBottomTo(tester, -12);

    expect(_mainTitle(tester), '测试主题');
    expect(tester.getSize(find.byType(AppBar)).height, barHeight);
    expect(
      tester.getTopLeft(find.byKey(const Key('thread-detail-list'))).dy,
      bodyTop,
    );
    // 标题切换只重建标题区，正文宿主实例保持同一份。
    expect(
      identical(
        tester.widget<ThreadDetailContent>(find.byType(ThreadDetailContent)),
        content,
      ),
      isTrue,
    );
  });

  testWidgets('grows for large text without clipping either title line', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    final resolvedHeight = ThreadDetailAppBar.resolveToolbarHeight(
      tester.element(find.byType(ThreadDetailPage)),
    );
    final barHeight = tester.getSize(find.byType(AppBar)).height;
    expect(tester.takeException(), isNull);
    expect(barHeight, closeTo(resolvedHeight, .01));
    expect(barHeight, greaterThan(ThreadDetailAppBar.minimumToolbarHeight));
    expect(_mainTitle(tester), '公告区');

    await _scrollTitleBottomTo(tester, -12);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppBar)).height, barHeight);
    expect(_mainTitle(tester), '测试主题');
    expect(_forumTitle(tester), '公告区');
    final barRect = tester.getRect(find.byType(AppBar));
    final mainRect = tester.getRect(
      find.byKey(ThreadDetailAppBar.titleMainKey),
    );
    final forumRect = tester.getRect(
      find.byKey(ThreadDetailAppBar.titleForumKey),
    );
    for (final rect in [mainRect, forumRect]) {
      expect(rect.top, greaterThanOrEqualTo(barRect.top));
      expect(rect.bottom, lessThanOrEqualTo(barRect.bottom));
    }
    // 2.0 倍系统字号真实放大：行高按实际字号乘行高系数，未被 1.34/1.5 上限截断。
    final mainFontSize = tester
        .widget<Text>(find.byKey(ThreadDetailAppBar.titleMainKey))
        .style!
        .fontSize!;
    final forumFontSize = tester
        .widget<Text>(find.byKey(ThreadDetailAppBar.titleForumKey))
        .style!
        .fontSize!;
    expect(mainRect.height, closeTo(mainFontSize * 2 * 1.25, .5));
    expect(forumRect.height, closeTo(forumFontSize * 2 * 1.3, .5));
  });

  testWidgets('keeps a single title in semantics during the cross-fade', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = _FakeThreadRepository((tid, page, query) async {
        return ApiSuccess(_pageData(tid, page, replyCount: 3));
      });
      await tester.pumpWidget(_buildApp(repository));
      await tester.pumpAndSettle();

      final initialTitle = _titleSemantics(tester);
      expect(_occurrences(initialTitle.label, '公告区'), 1);
      expect(_occurrences(initialTitle.label, '测试主题'), 0);

      _jumpTitleBottomTo(tester, -12);
      await tester.pump();
      await tester.pump();

      // 淡入淡出窗口内两块标题都在树上，但离场块不再进入语义树。
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.text('公告区'), findsNWidgets(2));
      final midTitle = _titleSemantics(tester);
      expect(_occurrences(midTitle.label, '公告区'), 1);
      expect(_occurrences(midTitle.label, '测试主题'), 1);

      await tester.pumpAndSettle();

      expect(find.text('公告区'), findsOneWidget);
      final settledTitle = _titleSemantics(tester);
      expect(_occurrences(settledTitle.label, '公告区'), 1);
      expect(_occurrences(settledTitle.label, '测试主题'), 1);
      expect(_mainTitle(tester), '测试主题');
      expect(_forumTitle(tester), '公告区');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('switches without a transition when animations are disabled', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _buildApp(repository),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTitleBottomTo(tester, -12);

    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(_mainTitle(tester), '测试主题');
    expect(_forumTitle(tester), '公告区');
  });

  testWidgets('copies the thread link from both title modes', (tester) async {
    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          copiedTexts.add(data['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final repository = _FakeThreadRepository((tid, page, query) async {
      return ApiSuccess(_pageData(tid, page, replyCount: 3));
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const Key('thread-detail-appbar-copy-link-area')),
    );
    await tester.pumpAndSettle();
    expect(copiedTexts, hasLength(1));

    await _scrollTitleBottomTo(tester, -12);
    expect(_mainTitle(tester), '测试主题');
    await tester.longPress(
      find.byKey(const Key('thread-detail-appbar-copy-link-area')),
    );
    await tester.pumpAndSettle();
    expect(copiedTexts, hasLength(2));
    expect(copiedTexts.last, contains('tid=100'));
  });

  testWidgets('keeps the first post action key, tooltip and disabled state', (
    tester,
  ) async {
    final pending = Completer<ApiResult<ThreadDetailData>>();
    final repository = _FakeThreadRepository((tid, page, query) async {
      return pending.future;
    });
    await tester.pumpWidget(_buildApp(repository));
    await tester.pump();

    final action = find.byKey(const Key('thread-detail-first-post-button'));
    expect(action, findsOneWidget);
    final l10n = _l10n(tester);
    expect(
      tester.widget<IconButton>(action).tooltip,
      l10n.threadControlsFirstPost,
    );
    expect(tester.widget<IconButton>(action).onPressed, isNull);

    pending.complete(ApiSuccess(_pageData('100', 1)));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(action).onPressed, isNotNull);
  });
}

Widget _buildApp(
  ThreadRepository repository, {
  int? initialPage,
  String? targetPid,
  String subject = '测试主题',
  Widget? home,
}) {
  return ProviderScope(
    overrides: <riverpod_misc.Override>[
      historyVisitRecorderProvider.overrideWithValue(
        const _NoopHistoryVisitRecorder(),
      ),
      historyDiagnosticRecorderProvider.overrideWithValue(
        const _NoopHistoryDiagnosticRecorder(),
      ),
      threadRepositoryProvider.overrideWithValue(repository),
      imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
      nativePageCacheInvalidationServiceProvider.overrideWithValue(
        _NoopPageCacheInvalidation(),
      ),
    ],
    child: LocalizedTestApp(
      theme: AppTheme.light(),
      home:
          home ??
          ThreadDetailPage(
            tid: '100',
            subject: subject,
            initialPage: initialPage,
            targetPid: targetPid,
          ),
    ),
  );
}

ThreadDetailData _pageData(
  String tid,
  int page, {
  int replyCount = 1,
  int currentPage = 1,
  bool includesFirstPost = true,
  bool reversed = false,
  String subject = '测试主题',
}) {
  const longBody = '<p>正文段落</p>';
  final firstPost = ThreadPost(
    pid: 'p-1',
    author: 'alice',
    authorId: '1',
    message: List<String>.filled(80, longBody).join(),
    number: 1,
    isFirst: true,
    dateline: '今天',
  );
  final replies = <ThreadPost>[
    for (var index = 2; index <= replyCount + 1; index++)
      ThreadPost(
        pid: 'p-$index',
        author: 'bob',
        authorId: '2',
        message: List<String>.filled(6, longBody).join(),
        number: index,
        isFirst: false,
        dateline: '今天',
      ),
  ];
  return ThreadDetailData(
    tid: tid,
    fid: '33',
    forumName: '公告区',
    subject: subject,
    author: 'alice',
    replies: replyCount,
    views: 12,
    currentPage: currentPage,
    lastPage: currentPage,
    perPage: 20,
    desktopUrl: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=$tid',
    // 倒序时首楼排到页尾，用于验证结构回退。
    posts: <ThreadPost>[
      if (!reversed && includesFirstPost) firstPost,
      ...(reversed ? replies.reversed : replies),
      if (reversed && includesFirstPost) firstPost,
    ],
  );
}

String? _mainTitle(WidgetTester tester) {
  final finder = find.byKey(ThreadDetailAppBar.titleMainKey);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

String? _forumTitle(WidgetTester tester) {
  final finder = find.byKey(ThreadDetailAppBar.titleForumKey);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

/// 顶栏标题的合并语义节点：AppBar 把标题包成一节 header，标题两行合并朗读。
SemanticsNode _titleSemantics(WidgetTester tester) =>
    tester.getSemantics(find.byKey(ThreadDetailAppBar.copyLinkAreaKey));

int _occurrences(String label, String text) => text.allMatches(label).length;

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ThreadDetailPage)));

ScrollableState _scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('thread-detail-list')),
        matching: find.byType(Scrollable),
      ),
    );

double _readableTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ThreadDetailContent)).dy;

/// 把首楼标题底边滚到可读区顶边下方 [inlineDelta] 像素处（负值表示已滚出）。
/// 把首楼标题底边滚到可读区顶边下方 [inlineDelta] 像素处（负值表示已滚出），
/// 只推进滚动位置，不等待标题切换动画。
void _jumpTitleBottomTo(WidgetTester tester, double inlineDelta) {
  final summary = find.byKey(const Key('thread-detail-first-post-summary'));
  final titleBottom = tester.getBottomLeft(summary).dy;
  final currentDelta = titleBottom - _readableTop(tester);
  final scrollable = _scrollable(tester);
  scrollable.position.jumpTo(
    scrollable.position.pixels + currentDelta - inlineDelta,
  );
}

Future<void> _scrollTitleBottomTo(
  WidgetTester tester,
  double inlineDelta,
) async {
  _jumpTitleBottomTo(tester, inlineDelta);
  await tester.pumpAndSettle();
}

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository(this._loader);

  final Future<ApiResult<ThreadDetailData>> Function(
    String tid,
    int page,
    Map<String, String> query,
  )
  _loader;
  final List<Map<String, String>> queryHistory = <Map<String, String>>[];

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
    final parameters = Map<String, String>.from(query.toRequestParameters());
    queryHistory.add(parameters);
    return dataReadResultFromApiResult(
      await _loader(tid, page, parameters),
      capabilities: capabilities.toReadCapabilities(),
    );
  }
}

class _NoopHistoryVisitRecorder implements HistoryVisitRecorder {
  const _NoopHistoryVisitRecorder();

  @override
  Future<void> record(HistoryVisitDraft draft) async {}
}

class _NoopHistoryDiagnosticRecorder implements HistoryDiagnosticRecorder {
  const _NoopHistoryDiagnosticRecorder();

  @override
  void recordQuery({
    required HistoryDiagnosticOutcome outcome,
    required int elapsedMs,
    required bool searching,
    int? itemCount,
    bool? hasMore,
    String? errorType,
  }) {}

  @override
  void recordSkip({
    required HistoryVisitSurface surface,
    required String reason,
  }) {}

  @override
  void recordWrite({
    required HistoryTargetType targetType,
    required HistoryVisitSurface surface,
    required HistoryDiagnosticOutcome outcome,
    required int elapsedMs,
    String? errorType,
  }) {}
}

class _NoopImageCacheService extends Fake implements ImageCacheService {}

class _NoopPageCacheInvalidation extends Fake
    implements NativePageCacheInvalidationService {}
