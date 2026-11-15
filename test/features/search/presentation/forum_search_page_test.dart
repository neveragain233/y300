import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' as riverpod_misc;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:y300/app/theme/app_theme.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/comic/data/providers/comic_refresh_workflow_providers.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_models.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/search/data/services/forum_search_coordinator.dart';
import 'package:y300/features/search/presentation/forum_search_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  testWidgets('ForumSearchPage builds search chrome', (tester) async {
    final coordinator = _FakeForumSearchCoordinator();
    await tester.pumpWidget(_buildApp(coordinator));
    addTearDown(coordinator.dispose);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const Key('forum-search-input')), findsOneWidget);
    expect(find.byKey(const Key('forum-search-submit-button')), findsOneWidget);
  });

  testWidgets('search builds a source-neutral query and renders topics', (
    tester,
  ) async {
    final coordinator = _FakeForumSearchCoordinator(
      topics: const <ForumSearchTopicSummary>[
        ForumSearchTopicSummary(
          tid: '100',
          title: '测试漫画 第1话',
          forumId: '30',
          forumName: '漫画版',
          authorName: '作者',
          publishedAtText: '今天',
        ),
      ],
    );
    await tester.pumpWidget(
      _buildApp(
        coordinator,
        page: const ForumSearchPage(
          scope: ForumSearchScope.currentForum,
          forumId: '30',
        ),
      ),
    );
    addTearDown(coordinator.dispose);

    await tester.enterText(
      find.byKey(const Key('forum-search-input')),
      '  测试漫画  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(coordinator.queries.single.normalizedKeyword, '测试漫画');
    expect(coordinator.queries.single.scope, ForumSearchScope.currentForum);
    expect(coordinator.queries.single.normalizedForumId, '30');
    expect(find.text('测试漫画 第1话'), findsOneWidget);
  });

  testWidgets('web blacklist hides results when hiding is enabled', (
    tester,
  ) async {
    _seedBlacklistMembers(const <String>['42']);
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final coordinator = _FakeForumSearchCoordinator(
      topics: const <ForumSearchTopicSummary>[
        ForumSearchTopicSummary(tid: '100', title: '屏蔽作者结果', authorId: '42'),
        ForumSearchTopicSummary(tid: '200', title: '正常作者结果', authorId: '43'),
      ],
    );
    await tester.pumpWidget(
      _buildApp(
        coordinator,
        extraOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          hideBlacklistedThreadsProvider.overrideWithValue(true),
        ],
      ),
    );
    addTearDown(coordinator.dispose);

    await tester.enterText(find.byKey(const Key('forum-search-input')), '关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('屏蔽作者结果'), findsNothing);
    expect(find.text('正常作者结果'), findsOneWidget);
  });

  testWidgets('blacklisted search results stay visible by default', (
    tester,
  ) async {
    _seedBlacklistMembers(const <String>['42']);
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final coordinator = _FakeForumSearchCoordinator(
      topics: const <ForumSearchTopicSummary>[
        ForumSearchTopicSummary(tid: '100', title: '屏蔽作者结果', authorId: '42'),
        ForumSearchTopicSummary(tid: '200', title: '正常作者结果', authorId: '43'),
      ],
    );
    await tester.pumpWidget(
      _buildApp(
        coordinator,
        extraOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
        ],
      ),
    );
    addTearDown(coordinator.dispose);

    await tester.enterText(find.byKey(const Key('forum-search-input')), '关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('屏蔽作者结果'), findsOneWidget);
    expect(find.text('正常作者结果'), findsOneWidget);
  });

  testWidgets('blocked search results are hidden without refetching', (
    tester,
  ) async {
    _seedBlockedThreads(const <String>['100']);
    final coordinator = _FakeForumSearchCoordinator(
      topics: const <ForumSearchTopicSummary>[
        ForumSearchTopicSummary(tid: '100', title: '已屏蔽结果'),
        ForumSearchTopicSummary(tid: '200', title: '正常结果'),
      ],
    );
    await tester.pumpWidget(_buildApp(coordinator));
    addTearDown(coordinator.dispose);

    await tester.enterText(find.byKey(const Key('forum-search-input')), '关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('已屏蔽结果'), findsNothing);
    expect(find.text('正常结果'), findsOneWidget);
    expect(coordinator.queries, hasLength(1));
  });

  testWidgets('refresh failure keeps the previous result visible', (
    tester,
  ) async {
    final coordinator = _FakeForumSearchCoordinator(
      topics: const <ForumSearchTopicSummary>[
        ForumSearchTopicSummary(tid: '100', title: '旧结果'),
      ],
    );
    await tester.pumpWidget(_buildApp(coordinator));
    addTearDown(coordinator.dispose);

    final input = find.byKey(const Key('forum-search-input'));
    await tester.enterText(input, '关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('旧结果'), findsOneWidget);

    coordinator.failNext = true;
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('旧结果'), findsOneWidget);
  });

  testWidgets(
    'empty input shows shared recent searches and submits in the page scope',
    (tester) async {
      _seedRecentKeywords(<String>['漫画', '小说']);
      final coordinator = _FakeForumSearchCoordinator(
        topics: const <ForumSearchTopicSummary>[
          ForumSearchTopicSummary(tid: '100', title: '漫画 第1话'),
        ],
      );
      await tester.pumpWidget(
        _buildApp(
          coordinator,
          page: const ForumSearchPage(
            scope: ForumSearchScope.currentForum,
            forumId: '30',
          ),
        ),
      );
      addTearDown(coordinator.dispose);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-search-scope-label')), findsOneWidget);
      expect(
        find.byKey(const Key('recent-search-chip-forum-漫画')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recent-search-chip-forum-小说')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('recent-search-chip-forum-漫画')));
      await tester.pumpAndSettle();

      expect(coordinator.queries.single.normalizedKeyword, '漫画');
      expect(coordinator.queries.single.scope, ForumSearchScope.currentForum);
      expect(find.text('漫画 第1话'), findsOneWidget);
      expect(find.byKey(const Key('recent-search-panel-forum')), findsNothing);

      await tester.tap(find.byKey(const Key('forum-search-clear-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('recent-search-panel-forum')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recent-search-chip-forum-漫画')),
        findsOneWidget,
      );
    },
  );
}

void _seedRecentKeywords(List<String> keywords) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'search.recent.snapshot.v1': jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'scopes': <String, Object?>{
        'forum': <Object?>[
          for (var index = 0; index < keywords.length; index += 1)
            <String, Object?>{
              'keyword': keywords[index],
              'usedAt': 2000 - index,
            },
        ],
      },
    }),
  });
}

Widget _buildApp(
  _FakeForumSearchCoordinator coordinator, {
  ForumSearchPage page = const ForumSearchPage(),
  List<riverpod_misc.Override> extraOverrides =
      const <riverpod_misc.Override>[],
}) {
  return LocalizedTestApp(
    theme: AppTheme.dark(),
    home: ProviderScope(
      overrides: [
        forumSearchCoordinatorProvider.overrideWithValue(coordinator),
        comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
          ValueNotifier<ComicSearchRefreshQueueSnapshot>(
            ComicSearchRefreshQueueSnapshot.empty,
          ),
        ),
        ...extraOverrides,
      ],
      child: page,
    ),
  );
}

final class _FakeForumSearchCoordinator
    implements ForumSearchCoordinator, ForumSearchReadQueueStateReader {
  _FakeForumSearchCoordinator({
    this.topics = const <ForumSearchTopicSummary>[],
  });

  final List<ForumSearchTopicSummary> topics;
  final List<ForumSearchQuery> queries = <ForumSearchQuery>[];
  final ValueNotifier<ForumSearchReadSchedulerSnapshot> _snapshot =
      ValueNotifier<ForumSearchReadSchedulerSnapshot>(
        ForumSearchReadSchedulerSnapshot.empty,
      );
  bool failNext = false;

  @override
  ValueListenable<ForumSearchReadSchedulerSnapshot> get snapshot => _snapshot;

  @override
  Future<ForumSearchExecution> search(
    ForumSearchQuery query, {
    bool enforceRateLimit = true,
    bool waitForRateLimit = false,
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    queries.add(query);
    if (failNext) {
      failNext = false;
      return const ForumSearchExecution.read(
        DataReadFailure<ForumSearchData, ForumSearchReadCapabilities>(
          kind: DataReadFailureKind.network,
          code: 'test_search_failure',
          diagnosticMessage: 'Search failed.',
        ),
      );
    }
    return ForumSearchExecution.read(_success(query));
  }

  @override
  Future<ForumSearchExecution> loadNextPage(
    ForumSearchQuery query,
    ForumSearchPageIdentity page,
  ) async {
    return ForumSearchExecution.read(_success(query, currentPage: page.page));
  }

  DataReadSuccess<ForumSearchData, ForumSearchReadCapabilities> _success(
    ForumSearchQuery query, {
    int currentPage = 1,
  }) {
    final data = ForumSearchData(
      query: query.normalized(),
      topics: topics,
      pagination: ForumSearchPagination(currentPage: currentPage),
    );
    return DataReadSuccess(
      data: data,
      capabilities: ForumSearchReadCapabilities(
        values: DataCapabilitySet<ForumSearchCapability>.supported(
          ForumSearchCapability.values,
        ),
        paginationPrecision: PaginationPrecision.unknown,
      ),
      metadata: const DataReadMetadata.network(),
    );
  }

  void dispose() => _snapshot.dispose();
}

void _seedBlockedThreads(List<String> tids) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'content_filter.blocked_threads.v1': jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'threads': [
        for (final tid in tids)
          <String, Object?>{'tid': tid, 'subject': tid, 'blockedAt': 1000},
      ],
    }),
  });
}

void _seedBlacklistMembers(List<String> uids) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'content_filter.web_blacklist.snapshot.v1': jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'accounts': <String, Object?>{
        '11': <String, Object?>{
          'lastSuccessAt': 1000,
          'members': <Object?>[
            for (final uid in uids)
              <String, Object?>{'userId': uid, 'username': 'Blocked'},
          ],
        },
      },
    }),
  });
}
