part of 'forum_webview_page_test.dart';

void _profileAppBarCases() {
  for (final purpose in [
    ForumWebViewHostPurpose.browse,
    ForumWebViewHostPurpose.selfProfile,
  ]) {
    testWidgets(
      'profile WebView AppBar opts into native action with $purpose',
      (tester) async {
        final driver = _FakeForumWebViewDriver();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedSessionOwnerProvider.overrideWithValue((
                uid: '654321',
                revision: 0,
              )),
              forumWebViewInitialUriProvider.overrideWithValue(
                Uri.parse(
                  'https://bbs.yamibo.com/home.php?mod=space&uid=654321&do=profile&mobile=2',
                ),
              ),
              forumWebViewHostPurposeProvider.overrideWithValue(purpose),
            ],
            child: _buildTestApp(driver: driver),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byKey(
              const Key('forum-webview-native-profile-button'),
            ),
          ),
          purpose == ForumWebViewHostPurpose.selfProfile
              ? findsOneWidget
              : findsNothing,
        );
      },
    );
  }
}

void _refreshActionCases() {
  testWidgets(
    'ForumWebViewPage refresh action reloads current page from more menu',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('forum-webview-refresh-action')));
      await tester.pumpAndSettle();

      expect(driver.reloadCallCount, 1);
    },
  );
}

void _toolbarMenuCases() {
  testWidgets('ForumWebViewPage home more menu shows unfavorite action', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();

    await tester.pumpWidget(_buildTestApp(driver: driver));
    await tester.pump();

    await tester.tap(find.byKey(const Key('forum-webview-more-button')));
    await tester.pumpAndSettle();

    expect(find.text('刷新页面'), findsOneWidget);
    expect(
      find.byKey(const Key('forum-webview-refresh-action')),
      findsOneWidget,
    );
    expect(find.text('取消收藏'), findsOneWidget);
    expect(
      find.byKey(const Key('forum-webview-home-unfavorite-action')),
      findsOneWidget,
    );
  });

  testWidgets('ForumWebViewPage home picker displays favorite forum list', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final favoriteRepository = _FakeForumFavoriteRepository(
      favoriteForums: <FavoriteForumEntry>[
        _favoriteForum(fid: '55', favid: 'fav-55', title: '综合区'),
        _favoriteForum(fid: '66', favid: 'fav-66', title: '讨论区'),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('forum-webview-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('forum-favorite-forum-picker')),
      findsOneWidget,
    );
    expect(find.text('综合区'), findsOneWidget);
    expect(find.text('讨论区'), findsOneWidget);
    expect(favoriteRepository.loadCallCount, 1);
  });

  testWidgets('ForumWebViewPage home picker retries after load failure', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver();
    final favoriteRepository = _FakeForumFavoriteRepository(
      loadResults: <_FavoriteForumReadResult>[
        const DataReadFailure(
          kind: DataReadFailureKind.network,
          diagnosticMessage: '加载失败',
        ),
        DataReadSuccess(
          data: FavoriteForumDirectoryData(
            items: <FavoriteForumEntry>[
              _favoriteForum(fid: '55', favid: 'fav-55', title: '综合区'),
            ],
          ),
          capabilities: _favoriteForumReadCapabilities,
          metadata: const DataReadMetadata.network(),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('forum-webview-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消收藏'));
    await tester.pumpAndSettle();

    expect(find.text('加载收藏版块失败：加载失败'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('forum-favorite-forum-picker-retry')),
    );
    await tester.pumpAndSettle();

    expect(find.text('综合区'), findsOneWidget);
    expect(favoriteRepository.loadCallCount, 2);
  });

  testWidgets(
    'ForumWebViewPage home unfavorite closes picker and reloads home',
    (tester) async {
      final driver = _FakeForumWebViewDriver();
      final favoriteRepository = _FakeForumFavoriteRepository(
        favoriteForums: <FavoriteForumEntry>[
          _favoriteForum(fid: '55', favid: 'fav-55', title: '综合区'),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消收藏'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('综合区'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('forum-favorite-forum-picker')),
        findsNothing,
      );
      expect(find.text('已取消收藏本版'), findsOneWidget);
      expect(favoriteRepository.unfavoriteCalls, <String>['fav-55']);
      expect(driver.loadedUris.length, 2);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
      expect(
        driver.loadRequests.last.headers['Referer'],
        'https://bbs.yamibo.com/index.php?mobile=2',
      );
    },
  );

  testWidgets(
    'ForumWebViewPage shows forum display app bar and loads curForum search',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';
      final favoriteRepository = _FakeForumFavoriteRepository();

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-back-button')),
        findsOneWidget,
      );
      expect(find.text('综合区'), findsOneWidget);

      await tester.tap(find.byKey(const Key('forum-webview-search-button')));
      await tester.pumpAndSettle();

      expect(driver.loadedUris.length, 2);
      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/search.php?mod=curforum&srhfid=55&mobile=2',
      );
      expect(
        driver.loadRequests.last.headers['Referer'],
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
    },
  );

  testWidgets(
    'ForumWebViewPage forum display shows favorite action when forum is not favorited',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';
      final favoriteRepository = _FakeForumFavoriteRepository();

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('收藏本版'), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage forum display shows unfavorite action when forum is favorited',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';
      final favoriteRepository = _FakeForumFavoriteRepository(
        favoriteForums: <FavoriteForumEntry>[
          _favoriteForum(fid: '55', favid: 'fav-55', title: '综合区'),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('取消收藏'), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage hides unfavorite action without identity capability',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';
      final favoriteRepository = _FakeForumFavoriteRepository(
        favoriteForums: <FavoriteForumEntry>[
          _favoriteForum(fid: '55', favid: 'fav-55', title: '综合区'),
        ],
        sourceCapabilities: _unsupportedRemoteIdentityCapabilities,
      );

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('取消收藏'), findsNothing);
      expect(find.text('收藏本版'), findsNothing);
    },
  );

  testWidgets(
    'ForumWebViewPage forum display favorite action reloads current page',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';
      final favoriteRepository = _FakeForumFavoriteRepository();
      const forumDisplayUrl =
          'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2';

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      await driver.dispatchPageStarted(forumDisplayUrl);
      await driver.dispatchPageFinished(forumDisplayUrl);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('收藏本版'));
      await tester.pumpAndSettle();

      expect(favoriteRepository.favoriteCalls, <String>['55']);
      expect(find.text('已收藏本版'), findsOneWidget);
      expect(driver.loadedUris.last.toString(), forumDisplayUrl);
      expect(driver.loadRequests.last.headers['Referer'], forumDisplayUrl);
    },
  );

  testWidgets(
    'ForumWebViewPage forum display unfavorite action reloads current page',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '页面标题';
      final favoriteRepository = _FakeForumFavoriteRepository(
        favoriteForums: <FavoriteForumEntry>[
          _favoriteForum(fid: '55', favid: 'fav-55', title: '综合区'),
        ],
      );
      const forumDisplayUrl =
          'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2';

      await tester.pumpWidget(
        _buildTestApp(driver: driver, favoriteRepository: favoriteRepository),
      );
      await tester.pump();

      await driver.dispatchPageStarted(forumDisplayUrl);
      await driver.dispatchPageFinished(forumDisplayUrl);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消收藏'));
      await tester.pumpAndSettle();

      expect(favoriteRepository.unfavoriteCalls, <String>['fav-55']);
      expect(find.text('已取消收藏本版'), findsOneWidget);
      expect(driver.loadedUris.last.toString(), forumDisplayUrl);
      expect(driver.loadRequests.last.headers['Referer'], forumDisplayUrl);
    },
  );

  testWidgets(
    'ForumWebViewPage thread detail hides search button when fid is unknown',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-back-button')),
        findsOneWidget,
      );
      expect(find.text('主题标题'), findsOneWidget);
      expect(
        find.byKey(const Key('forum-webview-thread-reply-button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('forum-webview-search-button')),
        findsNothing,
      );
      expect(driver.loadedUris.length, 1);
    },
  );

  testWidgets(
    'ForumWebViewPage hides thread reply button outside thread detail',
    (tester) async {
      final driver = _FakeForumWebViewDriver();

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-thread-reply-button')),
        findsNothing,
      );

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=55&mobile=2',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-thread-reply-button')),
        findsNothing,
      );

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/search.php?mod=forum&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/search.php?mod=forum&searchid=777&mobile=2',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-thread-reply-button')),
        findsNothing,
      );
    },
  );
}

void _threadToolbarCases() {
  testWidgets(
    'ForumWebViewPage thread detail more menu shows author order and home actions',
    (tester) async {
      final driver = _FakeForumWebViewDriver()
        ..title = '主题标题'
        ..javaScriptResult = jsonEncode(
          jsonEncode(<String, String?>{
            'authorOnlyHref':
                'forum.php?mod=viewthread&tid=123&authorid=9&mobile=2',
            'normalThreadHref': null,
            'reverseOrderHref':
                'forum.php?mod=viewthread&tid=123&ordertype=1&mobile=2',
            'normalOrderHref': null,
          }),
        );

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('刷新页面'), findsOneWidget);
      expect(find.text('只看楼主'), findsOneWidget);
      expect(find.text('倒序浏览'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(
        driver.returningScripts.single,
        contains('#nav-more-menu .nav-more-item'),
      );
    },
  );

  testWidgets(
    'ForumWebViewPage thread detail author filter action loads author-only url',
    (tester) async {
      final driver = _FakeForumWebViewDriver()
        ..title = '主题标题'
        ..javaScriptResult = jsonEncode(
          jsonEncode(<String, String?>{
            'authorOnlyHref':
                'forum.php?mod=viewthread&tid=123&authorid=9&mobile=2',
          }),
        );

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('只看楼主'));
      await tester.pumpAndSettle();

      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&authorid=9&mobile=2',
      );
    },
  );

  testWidgets(
    'ForumWebViewPage thread detail already author-only shows normal thread action',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&authorid=9&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&authorid=9&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('看全部'), findsOneWidget);

      await tester.tap(find.text('看全部'));
      await tester.pumpAndSettle();

      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
    },
  );

  testWidgets(
    'ForumWebViewPage thread detail order action toggles between reverse and normal order',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('倒序浏览'));
      await tester.pumpAndSettle();

      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2&ordertype=1',
      );

      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&ordertype=1&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&ordertype=1&mobile=2',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('正序浏览'), findsOneWidget);

      await tester.tap(find.text('正序浏览'));
      await tester.pumpAndSettle();

      expect(
        driver.loadedUris.last.toString(),
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
      );
    },
  );

  testWidgets('ForumWebViewPage thread detail more menu can load home', (
    tester,
  ) async {
    final driver = _FakeForumWebViewDriver()..title = '主题标题';

    await tester.pumpWidget(_buildTestApp(driver: driver));
    await tester.pump();

    await driver.dispatchPageStarted(
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
    );
    await driver.dispatchPageFinished(
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('forum-webview-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回首页'));
    await tester.pumpAndSettle();

    expect(
      driver.loadedUris.last.toString(),
      'https://bbs.yamibo.com/index.php?mobile=2',
    );
    expect(
      driver.loadRequests.last.headers['Referer'],
      'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&mobile=2',
    );
  });

  testWidgets(
    'ForumWebViewPage thread detail hides search button when fid is known',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '主题标题';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&fid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=123&fid=55&mobile=2',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-back-button')),
        findsOneWidget,
      );
      expect(find.text('综合区'), findsOneWidget);
      expect(
        find.byKey(const Key('forum-webview-search-button')),
        findsNothing,
      );
      expect(driver.loadedUris.length, 1);
    },
  );

  testWidgets(
    'ForumWebViewPage search app bar uses forum search title and hides search button',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '帖子搜索';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/search.php?mod=forum&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/search.php?mod=forum&searchid=777&mobile=2',
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('forum-webview-back-button')),
        findsOneWidget,
      );
      expect(find.text('论坛搜索'), findsOneWidget);
      expect(
        find.byKey(const Key('forum-webview-search-button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('forum-webview-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('刷新页面'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
    },
  );

  testWidgets(
    'ForumWebViewPage search app bar uses board name search title for curforum scope',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '帖子搜索';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      driver.canGoBackValue = true;
      await driver.dispatchPageStarted(
        'https://bbs.yamibo.com/search.php?mod=curforum&srhfid=55&mobile=2',
      );
      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/search.php?mod=curforum&srhfid=55&mobile=2',
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('综合区搜索'), findsOneWidget);
      expect(
        find.byKey(const Key('forum-webview-search-button')),
        findsNothing,
      );
    },
  );

  testWidgets('ForumWebViewPage search more action loads home', (tester) async {
    final driver = _FakeForumWebViewDriver()..title = '帖子搜索';

    await tester.pumpWidget(_buildTestApp(driver: driver));
    await tester.pump();

    await driver.dispatchPageStarted(
      'https://bbs.yamibo.com/search.php?mod=forum&mobile=2',
    );
    await driver.dispatchPageFinished(
      'https://bbs.yamibo.com/search.php?mod=forum&searchid=777&mobile=2',
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('forum-webview-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回首页'));
    await tester.pumpAndSettle();

    expect(
      driver.loadedUris.last.toString(),
      'https://bbs.yamibo.com/index.php?mobile=2',
    );
    expect(
      driver.loadRequests.last.headers['Referer'],
      'https://bbs.yamibo.com/search.php?mod=forum&searchid=777&mobile=2',
    );
  });

  testWidgets(
    'ForumWebViewPage search page still cleans chrome when loading finishes',
    (tester) async {
      final driver = _FakeForumWebViewDriver()..title = '帖子搜索';

      await tester.pumpWidget(_buildTestApp(driver: driver));
      await tester.pump();

      await driver.dispatchPageFinished(
        'https://bbs.yamibo.com/search.php?mod=forum&searchid=777&mobile=2',
      );
      await tester.pump();

      expect(driver.scripts.length, 1);
    },
  );
}
