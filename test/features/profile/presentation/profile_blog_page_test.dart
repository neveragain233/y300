import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/profile/data/providers/profile_read_providers.dart';
import 'package:y300/features/profile/data/providers/blog_draft_providers.dart';
import 'package:y300/features/profile/presentation/profile_blog_page.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/profile/presentation/blog/blog_comment_page.dart';
import 'package:y300/features/profile/presentation/blog/blog_action_page.dart';
import 'package:y300/features/profile/presentation/blog/blog_editor_page.dart';
import 'package:y300/features/profile/presentation/profile_user_link.dart';
import 'package:y300/features/profile/presentation/user_profile_page.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/forum_cached_avatar.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../test_support/localized_test_app.dart';
import '../../../test_support/page_flow_test_support.dart';
import '../test_support/blog_comment_fixture.dart';
import '../test_support/blog_draft_fixture.dart';
import '../test_support/blog_operation_fixture.dart';
import '../test_support/profile_repository_fixture.dart';

part 'profile_blog_page_feed_and_actions_cases.dart';
part 'profile_blog_page_detail_and_pagination_cases.dart';
part 'profile_blog_page_feedback_and_layout_cases.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  _feedAndActionCases();
  _detailAndPaginationCases();
  _feedbackAndLayoutCases();
}

Future<void> _pumpBlogPage(
  WidgetTester tester, {
  required UserBlogDirectoryRepository directoryRepository,
  required UserBlogDetailRepository detailRepository,
  Locale locale = const Locale('zh'),
  bool settle = true,
  ProfileBlogPage page = const ProfileBlogPage(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        blogAccountIdProvider.overrideWithValue('101'),
        userBlogDirectoryRepositoryProvider.overrideWithValue(
          directoryRepository,
        ),
        userBlogDetailRepositoryProvider.overrideWithValue(detailRepository),
        forumImageRefererProvider.overrideWithValue('https://bbs.yamibo.com/'),
      ],
      child: LocalizedTestApp(locale: locale, home: page),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

TabBar _blogTabs(WidgetTester tester) => tester.widget<TabBar>(
  find.descendant(
    of: find.byKey(const Key('profile-blog-view-tabs')),
    matching: find.byType(TabBar),
  ),
);

Future<void> _swipeToScope(WidgetTester tester, UserBlogFeedScope scope) async {
  while (_blogTabs(tester).controller!.index != scope.index) {
    final previousIndex = _blogTabs(tester).controller!.index;
    final direction = scope.index > previousIndex ? -1 : 1;
    final pager = find.byType(TabBarView);
    await tester.drag(
      pager,
      Offset(tester.getSize(pager).width * 0.8 * direction, 0),
    );
    await tester.pumpAndSettle();
    expect(_blogTabs(tester).controller!.index, isNot(previousIndex));
  }
}

TextButton _paginationButton(WidgetTester tester, String action) =>
    tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(Key('profile-blog-$action-button')),
        matching: find.byType(TextButton),
      ),
    );

UserBlogDirectoryReadCapabilities _directoryCapabilities({
  Iterable<UserBlogDirectoryCapability> supported =
      UserBlogDirectoryCapability.values,
}) {
  return UserBlogDirectoryReadCapabilities(
    values: DataCapabilitySet<UserBlogDirectoryCapability>.from(
      supported: supported,
      unsupported: UserBlogDirectoryCapability.values.where(
        (value) => !supported.contains(value),
      ),
    ),
    paginationPrecision:
        supported.contains(UserBlogDirectoryCapability.totalPageCount)
        ? PaginationPrecision.exact
        : PaginationPrecision.unknown,
  );
}

UserBlogDetailReadCapabilities _detailCapabilities({
  Iterable<UserBlogDetailCapability> supported =
      UserBlogDetailCapability.values,
}) {
  return UserBlogDetailReadCapabilities(
    values: DataCapabilitySet<UserBlogDetailCapability>.from(
      supported: supported,
      unsupported: UserBlogDetailCapability.values.where(
        (value) => !supported.contains(value),
      ),
    ),
  );
}

class _FakeBlogDirectoryRepository implements UserBlogDirectoryRepository {
  _FakeBlogDirectoryRepository({
    UserBlogDirectoryReadCapabilities? capabilities,
    this.failAfterSuccess = false,
    this.failFirst = false,
    this.gate,
    this.nextPageGate,
    this.unknownTotalPages = false,
    this.longList = false,
    this.longListPages = const {1},
    this.longListScopes = const {UserBlogFeedScope.public},
    this.scopeGates = const {},
    this.blogActions = const {},
  }) : readCapabilities =
           capabilities ??
           _directoryCapabilities(
             supported: UserBlogDirectoryCapability.values.where(
               (capability) =>
                   !unknownTotalPages ||
                   capability != UserBlogDirectoryCapability.totalPageCount,
             ),
           );

  final UserBlogDirectoryReadCapabilities readCapabilities;
  final bool failAfterSuccess;
  final bool failFirst;
  final Completer<void>? gate;
  final Completer<void>? nextPageGate;
  final bool unknownTotalPages;
  final failedPages = <int>{};
  final bool longList;
  final Set<int> longListPages;
  final Set<UserBlogFeedScope> longListScopes;
  final Map<UserBlogFeedScope, Completer<void>> scopeGates;
  final Set<UserBlogAction> blogActions;
  bool removed = false;
  final cancellations = <ForumRequestCancellation?>[];
  final List<UserBlogDirectoryQuery> queries = <UserBlogDirectoryQuery>[];
  final List<CacheLoadPolicy> policies = <CacheLoadPolicy>[];

  @override
  UserBlogDirectorySourceCapabilities get capabilities =>
      UserBlogDirectorySourceCapabilities(
        values: readCapabilities.values,
        paginationPrecision: readCapabilities.paginationPrecision,
      );

  @override
  Future<
    DataReadResult<UserBlogDirectoryData, UserBlogDirectoryReadCapabilities>
  >
  load(
    UserBlogDirectoryQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    policies.add(cachePolicy);
    cancellations.add(cancellation);
    await gate?.future;
    await scopeGates[query.scope]?.future;
    if (query.page > 1) await nextPageGate?.future;
    if ((failFirst && queries.length == 1) ||
        (failAfterSuccess && queries.length > 1) ||
        failedPages.contains(query.page)) {
      return const DataReadFailure(
        kind: DataReadFailureKind.network,
        diagnosticMessage: 'network failure',
      );
    }
    return DataReadSuccess(
      data: _directoryData(query),
      capabilities: readCapabilities,
      metadata: const DataReadMetadata.network(),
    );
  }

  UserBlogDirectoryData _directoryData(UserBlogDirectoryQuery query) {
    if (longList &&
        longListScopes.contains(query.scope) &&
        longListPages.contains(query.page)) {
      return UserBlogDirectoryData(
        scope: query.scope,
        order: query.order,
        items: [
          for (var i = 0; i < 30; i++)
            UserBlogSummary(
              blogId:
                  '${i + (query.scope == UserBlogFeedScope.self ? 1001 : 1) + (query.page - 1) * 10000}',
              ownerUserId: '101',
              title: query.page > 1
                  ? 'Page ${query.page} entry $i'
                  : query.scope == UserBlogFeedScope.self
                  ? 'Self entry $i'
                  : 'Entry $i',
              excerpt: 'A longer journal excerpt for checking retained scroll position.',
            ),
        ],
        pagination: UserBlogPagination(
          currentPage: query.page,
          totalPages: 2,
          hasPrevious: query.page > 1,
          hasNext: query.page < 2,
        ),
      );
    }
    if (query.scope != UserBlogFeedScope.public) {
      return UserBlogDirectoryData(
        scope: query.scope,
        order: null,
        items: const <UserBlogSummary>[],
        pagination: UserBlogPagination(currentPage: query.page),
      );
    }
    if (query.page == 2) {
      return UserBlogDirectoryData(
        scope: UserBlogFeedScope.public,
        order: UserBlogOrder.latest,
        items: const <UserBlogSummary>[
          UserBlogSummary(
            blogId: '117600',
            ownerUserId: '257582',
            title: '第二页日志',
          ),
        ],
        pagination: UserBlogPagination(
          currentPage: 2,
          totalPages: unknownTotalPages ? null : 2,
          hasPrevious: true,
          hasNext: false,
        ),
      );
    }
    final recommended = query.order == UserBlogOrder.recommended;
    return UserBlogDirectoryData(
      scope: UserBlogFeedScope.public,
      order: query.order ?? UserBlogOrder.latest,
      items: <UserBlogSummary>[
        if (!removed)
          UserBlogSummary(
            blogId: recommended ? '117548' : '117558',
            ownerUserId: '257582',
            title: recommended ? '我们小区的公共交通极其不便利' : '一种体验',
            authorName: recommended ? 'hsyhlj' : '抉择',
            excerpt: '作为女生，见血是常有的事',
            publishedAtText: '2026-6-21 13:06',
            actions: blogActions,
          ),
      ],
      pagination: UserBlogPagination(
        currentPage: 1,
        totalPages: unknownTotalPages ? null : 2,
        hasPrevious: false,
        hasNext: true,
      ),
    );
  }
}

class _FakeBlogDetailRepository implements UserBlogDetailRepository {
  _FakeBlogDetailRepository({
    UserBlogDetailReadCapabilities? capabilities,
    this.gate,
    this.commentActions = const {},
    this.blogActions = const {},
    this.title = '我们小区的公共交通极其不便利',
    this.commentAuthorId,
    this.emptyComments = false,
    this.viewCount = 39,
    this.commentCount = 1,
    this.pagedComments = false,
  }) : readCapabilities = capabilities ?? _detailCapabilities();

  final UserBlogDetailReadCapabilities readCapabilities;
  final Set<UserBlogCommentAction> commentActions;
  final Set<UserBlogAction> blogActions;
  String title;
  final String? commentAuthorId;
  final bool emptyComments;
  final int? viewCount;
  final int? commentCount;
  final bool pagedComments;
  final failedCommentPages = <int>{};
  final policies = <CacheLoadPolicy>[];
  final Completer<void>? gate;
  final cancellations = <ForumRequestCancellation?>[];
  final List<UserBlogDetailQuery> queries = <UserBlogDetailQuery>[];

  @override
  UserBlogDetailSourceCapabilities get capabilities =>
      UserBlogDetailSourceCapabilities(values: readCapabilities.values);

  @override
  Future<DataReadResult<UserBlogDetailData, UserBlogDetailReadCapabilities>>
  load(
    UserBlogDetailQuery query, {
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    ForumRequestCancellation? cancellation,
  }) async {
    queries.add(query);
    policies.add(cachePolicy);
    cancellations.add(cancellation);
    await gate?.future;
    if (failedCommentPages.contains(query.page)) {
      return const DataReadFailure(
        kind: DataReadFailureKind.network,
        diagnosticMessage: 'network failure',
      );
    }
    return DataReadSuccess(
      data: UserBlogDetailData(
        blogId: query.blogId,
        ownerUserId: query.ownerUserId,
        title: title,
        bodyHtml: '<p>一直对着电脑屏幕</p>',
        authorName: 'hsyhlj',
        publishedAtText: '2026-6-18 00:25',
        viewCount: viewCount,
        commentCount: commentCount,
        commentsOpen: true,
        commentPagination: UserBlogPagination(
          currentPage: query.page,
          hasNext: pagedComments && query.page == 1,
        ),
        actions: blogActions,
        comments: <UserBlogComment>[
          if (!emptyComments)
            UserBlogComment(
              commentId: pagedComments && query.page == 2 ? '646847' : '646846',
              authorName: 'thessky',
              authorUserId: commentAuthorId,
              bodyHtml: '<p>探险的感觉</p>',
              publishedAtText: '2026-6-18 01:00',
              actions: commentActions,
            ),
        ],
      ),
      capabilities: readCapabilities,
      metadata: const DataReadMetadata.network(),
    );
  }
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is RichText && widget.text.toPlainText().contains(text);
  });
}
