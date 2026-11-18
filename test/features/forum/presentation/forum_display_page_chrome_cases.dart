part of 'forum_display_page_test.dart';

void _chromeCases() {
  testWidgets('renders HTML-first forum chrome and pinned entries', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 52718,
          headImageUrl:
              'https://bbs.yamibo.com/data/attachment/album/202603/02/head.png',
          threads: [
            ForumThreadSummary(
              tid: '572604',
              subject: '[个人汉化]测试标题',
              author: 'nkdndixnx',
              replies: 0,
              views: 119,
              dateline: '2026-6-18 14:42',
              excerpt: '请勿随意转载，也请别在外网提及，谢谢',
              sourceTagName: '長篇連載',
              badgeLabel: '投票',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('forum-display-head-image')), findsOneWidget);
    final headImage = tester.widget<CachedLibraryImage>(
      find.descendant(
        of: find.byKey(const Key('forum-display-head-image')),
        matching: find.byType(CachedLibraryImage),
      ),
    );
    expect(headImage.request?.role, ImageCacheRole.forumHeadImage);
    expect(headImage.request?.ownerId, 'forum:2');
    expect(
      headImage.remoteDisplayPolicy,
      CachedImageRemoteDisplayPolicy.afterCacheWrite,
    );
    expect(headImage.fadeInDuration, ForumCachedAvatar.fadeInDuration);
    expect(
      headImage.request?.effectiveRetentionClass,
      ImageRetentionClass.sticky,
    );
    expect(
      tester.getSize(find.byKey(const Key('forum-display-head-image'))).height,
      72,
    );
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(
      find.byKey(const Key('forum-display-type-filter-menu')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forum-display-compose-button')), findsNothing);
    expect(find.byKey(const Key('forum-display-appbar-stats')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
    expect(find.text('今日 3'), findsOneWidget);
    expect(find.text('主题 52718'), findsOneWidget);
    expect(find.text('排名 1'), findsOneWidget);
    final stats = find.byKey(const Key('forum-display-appbar-stats'));
    final intrinsicStatsWidth =
        tester.getSize(find.text('今日 3')).width +
        tester.getSize(find.text('主题 52718')).width +
        tester.getSize(find.text('排名 1')).width +
        20;
    expect(tester.getSize(stats).width, closeTo(intrinsicStatsWidth, 0.01));
    expect(find.text('发帖'), findsNothing);
    expect(find.byKey(const Key('forum-display-top-entries')), findsOneWidget);
    expect(find.text('公告 / 置顶'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('欢迎光临。'), findsNothing);

    await tester.drag(
      find.byKey(const Key('forum-display-list')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('forum-display-top-entries-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('公告'), findsWidgets);
    expect(find.text('欢迎光临。'), findsOneWidget);
    expect(find.text('[个人汉化]测试标题'), findsOneWidget);
    expect(find.text('nkdndixnx'), findsOneWidget);
    expect(find.text('2026-6-18 14:42'), findsOneWidget);
    expect(find.textContaining('请勿随意转载'), findsOneWidget);
    expect(find.text('119'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('長篇連載'), findsOneWidget);
    expect(find.text('投票'), findsOneWidget);

    final threadBadgeDecoration = _decorationAroundText(tester, '投票');
    expect(threadBadgeDecoration.boxShadow, isNotNull);
    expect(threadBadgeDecoration.boxShadow, isNotEmpty);
  });

  testWidgets('restores the last known head image aspect ratio by forum', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          headImageUrl: 'https://bbs.yamibo.com/new-head.png',
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        extraOverrides: [
          forumImageDimensionIndexProvider.overrideWithValue(
            const _FixedForumImageDimensionIndex(
              ForumImageDimensions(
                width: 1200,
                height: 300,
                source: ForumImageDimensionSource.cacheMetadata,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final size = tester.getSize(
      find.byKey(const Key('forum-display-head-image')),
    );
    expect(size.height, closeTo(size.width / 4, 0.01));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });

  testWidgets('app bar gives the thread count all remaining width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 72611,
          todayPosts: 137,
          rank: 2,
          threads: const <ForumThreadSummary>[],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final stats = find.byKey(const Key('forum-display-appbar-stats'));
    final flexibleStats = find.descendant(
      of: stats,
      matching: find.byType(Flexible),
    );
    expect(flexibleStats, findsOneWidget);
    expect(
      find.descendant(of: flexibleStats, matching: find.text('主题 72611')),
      findsOneWidget,
    );
    final usedStatsWidth =
        tester.getSize(find.text('今日 137')).width +
        tester.getSize(find.text('主题 72611')).width +
        tester.getSize(find.text('排名 2')).width +
        20;
    expect(usedStatsWidth, closeTo(tester.getSize(stats).width, 0.01));
    expect(
      tester.getRect(stats).right,
      closeTo(
        tester
            .getRect(find.byKey(const Key('forum-display-search-button')))
            .left,
        0.01,
      ),
    );
  });

  testWidgets('aligns thread tags to the same right edge', (tester) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 2,
          threads: [
            ForumThreadSummary(
              tid: 'tag-short',
              subject: '短 tag 帖子',
              author: 'alice',
              replies: 7,
              views: 86,
              dateline: 'today',
              excerpt: '短 tag 摘要',
              sourceTagName: '#短',
            ),
            ForumThreadSummary(
              tid: 'tag-long',
              subject: '长 tag 帖子',
              author: 'bob',
              replies: 162,
              views: 1675,
              dateline: 'today',
              excerpt: '长 tag 摘要',
              sourceTagName: '八卦杂谈',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('短'), findsOneWidget);
    expect(find.text('#短'), findsNothing);

    final shortTagRight = tester.getBottomRight(
      find.byKey(const Key('forum-thread-tag-tag-short')),
    );
    final longTagRight = tester.getBottomRight(
      find.byKey(const Key('forum-thread-tag-tag-long')),
    );

    expect((shortTagRight.dx - longTagRight.dx).abs(), lessThan(0.1));
  });

  testWidgets('dark theme uses theme-driven forum display surfaces', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(page: 1, total: 1, threads: const <ForumThreadSummary>[]),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumDisplayRepositoryProvider.overrideWithValue(repository),
        ],
        child: LocalizedTestApp(
          theme: AppTheme.dark(),
          home: const ForumDisplayPage(fid: '2', title: '公告区'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark().scaffoldBackgroundColor);
    expect(find.byKey(const Key('forum-display-list')), findsOneWidget);
    expect(find.byKey(const Key('forum-display-top-entries')), findsOneWidget);
  });
}
