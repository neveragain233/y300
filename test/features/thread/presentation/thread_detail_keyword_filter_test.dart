import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yamibo_forum_client/yamibo_forum_client.dart' as forum_client;
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo_forum_client_provider.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_widgets.dart';
import 'package:y300/features/forum/presentation/forum_display_content_projection.dart';
import 'package:y300/features/forum/presentation/forum_display_state.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/features/thread/presentation/thread_detail_page.dart';

import '../../../test_support/localized_test_app.dart';

class _UnusedNetwork implements forum_client.ForumClientNetwork {
  @override
  Future<forum_client.ForumTransportResult<forum_client.ForumResponse<Object?>>>
  send(forum_client.ForumRequest request) {
    throw StateError('Unexpected network call');
  }
}

class _UnusedPollVoteCommand implements ThreadPollVoteCommand {
  @override
  ThreadPollVoteCapabilities get capabilities => ThreadPollVoteCapabilities(
    values: DataCapabilitySet<ThreadPollVoteCapability>.supported(const []),
  );

  @override
  Future<DataCommandResult<ThreadPollVoteReceipt>> execute(
    ThreadPollVoteSubmission submission,
  ) {
    throw UnimplementedError();
  }
}

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository(this._loader);

  final Future<ThreadDetailData> Function(String tid, int page) _loader;

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
    final data = await _loader(tid, page);
    return DataReadSuccess(
      data: data,
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata(
        origin: DataReadOrigin.network,
        freshness: DataReadFreshness.current,
      ),
    );
  }
}

ThreadPost _post({
  required String pid,
  required int number,
  required String message,
  String? authorId,
  bool isFirst = false,
}) {
  return ThreadPost(
    pid: pid,
    author: 'User$number',
    authorId: authorId ?? 'u$number',
    message: message,
    number: number,
    isFirst: isFirst,
    dateline: '2026-11-24',
  );
}

ThreadDetailData _detail({
  required String tid,
  String fid = '33',
  required String subject,
  required List<ThreadPost> posts,
  int currentPage = 1,
  int lastPage = 1,
  bool isPinned = false,
}) {
  return ThreadDetailData(
    tid: tid,
    fid: fid,
    subject: subject,
    author: 'User1',
    replies: posts.length - 1,
    views: 100,
    currentPage: currentPage,
    perPage: 20,
    lastPage: lastPage,
    isPinned: isPinned,
    posts: posts,
  );
}

void main() {
  testWidgets(
    'repliesOnly keyword moves matching replies to tail banner and masks quotes in normal replies',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': [
            <String, Object?>{
              'id': 'k1',
              'keyword': '剧透',
              'scope': 'repliesOnly',
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      });
      final repo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          subject: '包含剧透的标题在仅回复模式下不拦截',
          posts: [
            _post(
              pid: 'p1',
              number: 1,
              isFirst: true,
              message: '<p>主楼讨论剧透也不拦截</p>',
            ),
            _post(pid: 'p2', number: 2, message: '<p>这里有剧透内容</p>'),
            _post(
              pid: 'p3',
              number: 3,
              message: '<div class="quote"><blockquote><b>User2</b>: 这里有剧透内容</blockquote></div><p>请勿讨论</p>',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: repo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(tid: '100', subject: '包含剧透的标题在仅回复模式下不拦截'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('keyword-thread-gate')), findsNothing);
      expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
      expect(find.byKey(const Key('thread-post-card-p3')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('引用发言因为关键词屏蔽被隐藏'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('请勿讨论'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('thread-blacklisted-post-p2')), findsNothing);

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-blacklisted-post-p2')),
        findsOneWidget,
      );
      expect(find.text('由于你的屏蔽设置，该楼层已被屏蔽'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('thread-blacklisted-post-p2')),
          matching: find.textContaining('剧透'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('thread-blacklisted-expand-p2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('thread-post-card-p2')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == '这里有剧透内容',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('临时展开：命中规则「剧透」'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('includeBody keyword triggers whole-thread gate with view once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'keywords': [
          <String, Object?>{
            'id': 'k2',
            'keyword': '剧透',
            'scope': 'includeBody',
            'createdAt': 1000,
            'updatedAt': 1000,
          },
        ],
      }),
    });
    final repo = _FakeThreadRepository(
      (tid, page) async => _detail(
        tid: tid,
        subject: '普通标题',
        posts: [
          _post(
            pid: 'p1',
            number: 1,
            isFirst: true,
            message: '<p>主楼包含剧透正文</p>',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yamiboForumClientProvider.overrideWithValue(
            forum_client.YamiboForumClient(
              config: forum_client.ForumClientConfig(
                siteOrigin: Uri.parse('https://bbs.example.test'),
                apiOrigin: Uri.parse(
                  'https://api.example.test/mobile/index.php',
                ),
                userAgent: 'test',
                desktopUserAgent: 'test',
              ),
              network: _UnusedNetwork(),
              sourcePlan: forum_client.ForumClientSourcePlan(
                threadDetail: repo,
                threadPollVoteCommand: _UnusedPollVoteCommand(),
              ),
            ),
          ),
        ],
        child: const LocalizedTestApp(
          home: ThreadDetailPage(tid: '101', subject: '普通标题'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('keyword-thread-gate')), findsOneWidget);
    expect(find.text('由于你的屏蔽设置，此主题已被屏蔽。'), findsOneWidget);
    expect(find.textContaining('剧透'), findsNothing);
    expect(find.byKey(const Key('thread-post-card-p1')), findsNothing);

    await tester.tap(find.byKey(const Key('keyword-thread-view-once-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('keyword-thread-gate')), findsNothing);
    expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
  });

  testWidgets(
    'list filtering shows placeholder by default, supports reveal/hide, and hides completely when enabled',
    (tester) async {
      final now = DateTime(2026, 11, 24);
      final includeBodyRule = BlockedKeyword(
        id: 'k1',
        keyword: '剧透',
        normalizedKeyword: '剧透',
        scope: BlockedKeywordScope.includeBody,
        createdAt: now,
        updatedAt: now,
      );
      final allowRule = BlockedKeyword(
        id: 'a1',
        keyword: '剧透预警',
        normalizedKeyword: '剧透预警',
        scope: BlockedKeywordScope.includeBody,
        kind: BlockedKeywordKind.allow,
        createdAt: now,
        updatedAt: now,
      );
      final threads = [
        ForumThreadSummary(
          tid: '1',
          subject: '含剧透的帖子',
          author: 'A',
          uid: '10',
          replies: 0,
          views: 10,
          dateline: '2026-11-24',
        ),
        ForumThreadSummary(
          tid: '2',
          subject: '正常帖子',
          excerpt: '这里有剧透预警，可以安全阅读',
          author: 'B',
          uid: '11',
          replies: 0,
          views: 10,
          dateline: '2026-11-24',
        ),
        ForumThreadSummary(
          tid: '3',
          subject: '标题正常的帖子',
          excerpt: '摘要里出现了剧透内容',
          author: 'C',
          uid: '12',
          replies: 0,
          views: 10,
          dateline: '2026-11-24',
        ),
      ];
      final projection = ForumDisplayContentProjection.raw(
        ForumDisplayPageState.initial(
          fid: '33',
          title: '百合会',
        ).copyWith(threads: threads, lastPage: 1),
        mode: TextConversionMode.none,
      );

      Widget buildWithHide(bool hideCompletely) => ProviderScope(
        child: LocalizedTestApp(
          home: Scaffold(
            body: ForumDisplayContent(
              projection: projection,
              scrollController: ScrollController(),
              filterAnchorKey: GlobalKey(),
              headImageKey: GlobalKey(),
              keywordFilterRules: KeywordFilterRuleSet(
                rules: [includeBodyRule, allowRule],
                hideBlockedContentCompletely: hideCompletely,
                revision: hideCompletely ? 1 : 2,
              ),
              onLoadMore: () {},
              onLoadPrevious: () {},
              onSelectPage: (_) {},
              onOpenFilter: (_) {},
              onOpenThreadTag: (_) {},
              onOpenThread: (_) {},
              onOpenTopEntry: (_) {},
              onOpenSubForum: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildWithHide(false));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('keyword-filtered-thread-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('keyword-filtered-thread-3')),
        findsOneWidget,
      );
      expect(find.text('含剧透的帖子'), findsNothing);
      expect(find.text('标题正常的帖子'), findsNothing);
      expect(find.text('正常帖子'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('keyword-filtered-thread-reveal-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('含剧透的帖子'), findsOneWidget);
      expect(
        find.byKey(const Key('keyword-filtered-thread-hide-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('keyword-filtered-thread-hide-1')));
      await tester.pumpAndSettle();
      expect(find.text('含剧透的帖子'), findsNothing);
      expect(
        find.byKey(const Key('keyword-filtered-thread-1')),
        findsOneWidget,
      );

      await tester.pumpWidget(buildWithHide(true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keyword-filtered-thread-1')), findsNothing);
      expect(find.byKey(const Key('keyword-filtered-thread-3')), findsNothing);
      expect(find.text('含剧透的帖子'), findsNothing);
      expect(find.text('标题正常的帖子'), findsNothing);
      expect(find.text('正常帖子'), findsOneWidget);
    },
  );

  testWidgets(
    'expanded blocked floor can be hidden again and tail collapse resets revealed floors',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': [
            <String, Object?>{
              'id': 'k1',
              'keyword': '剧透',
              'scope': 'repliesOnly',
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      });
      final repo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          subject: '测试主题',
          posts: [
            _post(
              pid: 'p1',
              number: 1,
              isFirst: true,
              message: '<p>主楼正常内容</p>',
            ),
            _post(
              pid: 'p2',
              number: 2,
              isFirst: false,
              message: '<p>包含剧透的回复</p>',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: repo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(tid: '100', subject: '测试主题'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-blacklisted-post-p2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('thread-blacklisted-expand-p2')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-blacklisted-hide-p2')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == '包含剧透的回复',
        ),
        findsOneWidget,
      );

      // Tapping per-floor hide returns it to placeholder immediately.
      await tester.tap(find.byKey(const Key('thread-blacklisted-hide-p2')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-blacklisted-post-p2')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('thread-blacklisted-hide-p2')), findsNothing);

      // Expand again, then collapse the tail banner and re-expand: must reset to hidden.
      await tester.tap(find.byKey(const Key('thread-blacklisted-expand-p2')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-blacklisted-hide-p2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thread-blacklisted-hide-p2')), findsNothing);

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-blacklisted-post-p2')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('thread-blacklisted-hide-p2')), findsNothing);
    },
  );

  testWidgets(
    'whitelisted author and allow keyword exempt reply from keyword blocking',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': <Object?>[
            <String, Object?>{
              'id': 'blk',
              'keyword': '剧透',
              'scope': 'repliesOnly',
              'kind': 'block',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
            <String, Object?>{
              'id': 'allow',
              'keyword': '官方',
              'scope': 'includeBody',
              'kind': 'allow',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
        'content_filter.whitelisted_users.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'users': <Object?>[
            <String, Object?>{
              'uid': '777',
              'username': 'Trusted',
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      });

      final repo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          subject: '普通主题',
          posts: [
            _post(
              pid: 'p1',
              number: 1,
              isFirst: true,
              authorId: '1',
              message: '<p>主楼正文</p>',
            ),
            _post(
              pid: 'p2',
              number: 2,
              authorId: '777',
              message: '<p>剧透内容但作者在白名单</p>',
            ),
            _post(
              pid: 'p3',
              number: 3,
              authorId: '888',
              message: '<p>官方剧透豁免</p>',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: repo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(tid: '100', subject: '普通主题'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsNothing,
      );
      expect(find.byKey(const Key('thread-post-card-p2')), findsOneWidget);
      expect(find.byKey(const Key('thread-post-card-p3')), findsOneWidget);
    },
  );

  testWidgets(
    'pinned thread and known subforum skip gates and reply/quote filtering',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.blocked_threads.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'threads': <Object?>[
            <String, Object?>{
              'tid': '100',
              'subject': '剧透置顶帖',
              'blockedAt': 1000,
            },
          ],
        }),
        'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': <Object?>[
            <String, Object?>{
              'id': 'blk',
              'keyword': '剧透',
              'scope': 'includeBody',
              'kind': 'block',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
        'content_filter.known_subforum_ids.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'fids': <String>['99'],
        }),
      });

      final pinnedRepo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          fid: '33',
          subject: '剧透置顶帖',
          isPinned: true,
          posts: [
            _post(
              pid: 'p1',
              number: 1,
              isFirst: true,
              message: '<p>主楼剧透正文</p>',
            ),
            _post(pid: 'p2', number: 2, message: '<p>回复也有剧透</p>'),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: pinnedRepo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(
              tid: '100',
              subject: '剧透置顶帖',
              gateBlockedEntry: true,
              exemptFromContentFilter: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blocked-thread-gate')), findsNothing);
      expect(find.byKey(const Key('keyword-thread-gate')), findsNothing);
      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsNothing,
      );
      expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
      expect(find.byKey(const Key('thread-post-card-p2')), findsOneWidget);

      final subForumRepo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          fid: '99',
          subject: '子版块剧透帖',
          posts: [
            _post(
              pid: 's1',
              number: 1,
              isFirst: true,
              message: '<p>子版块主楼剧透</p>',
            ),
            _post(pid: 's2', number: 2, message: '<p>子版块回复剧透</p>'),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: subForumRepo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(tid: '101', subject: '子版块剧透帖'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('keyword-thread-gate')), findsNothing);
      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsNothing,
      );
      expect(find.byKey(const Key('thread-post-card-s1')), findsOneWidget);
      expect(find.byKey(const Key('thread-post-card-s2')), findsOneWidget);
    },
  );

  testWidgets(
    'expanded keyword reply and thread gate offer one-tap Add to Whitelist with undo',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': <Object?>[
            <String, Object?>{
              'id': 'blk',
              'keyword': '剧透',
              'scope': 'repliesOnly',
              'kind': 'block',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      });

      final repo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          subject: '普通主题',
          posts: [
            _post(
              pid: 'p1',
              number: 1,
              isFirst: true,
              authorId: '101',
              message: '<p>主楼正文</p>',
            ),
            _post(
              pid: 'p2',
              number: 2,
              authorId: '202',
              message: '<p>这里有剧透内容</p>',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: repo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(tid: '100', subject: '普通主题'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thread-blacklisted-expand-p2')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-keyword-whitelist-p2')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('thread-keyword-whitelist-p2')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-keyword-whitelist-p2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsNothing,
      );
      expect(find.byKey(const Key('thread-post-card-p2')), findsOneWidget);

      await tester.tap(find.byType(SnackBarAction));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'BlockedKeywordThreadGateView whitelists topic author and unlocks thread',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.blocked_keywords.v1': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': <Object?>[
            <String, Object?>{
              'id': 'blk',
              'keyword': '剧透',
              'scope': 'includeBody',
              'kind': 'block',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      });

      final repo = _FakeThreadRepository(
        (tid, page) async => _detail(
          tid: tid,
          subject: '包含剧透的主题',
          posts: [
            _post(
              pid: 'p1',
              number: 1,
              isFirst: true,
              authorId: '101',
              message: '<p>主楼剧透正文</p>',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            yamiboForumClientProvider.overrideWithValue(
              forum_client.YamiboForumClient(
                config: forum_client.ForumClientConfig(
                  siteOrigin: Uri.parse('https://bbs.example.test'),
                  apiOrigin: Uri.parse(
                    'https://api.example.test/mobile/index.php',
                  ),
                  userAgent: 'test',
                  desktopUserAgent: 'test',
                ),
                network: _UnusedNetwork(),
                sourcePlan: forum_client.ForumClientSourcePlan(
                  threadDetail: repo,
                  threadPollVoteCommand: _UnusedPollVoteCommand(),
                ),
              ),
            ),
          ],
          child: const LocalizedTestApp(
            home: ThreadDetailPage(tid: '100', subject: '包含剧透的主题'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('keyword-thread-whitelist-author-button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('keyword-thread-whitelist-author-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('keyword-thread-gate')), findsNothing);
      expect(find.byKey(const Key('thread-post-card-p1')), findsOneWidget);
    },
  );
}
