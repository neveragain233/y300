part of 'forum_display_page_test.dart';

void _renderingCases() {
  test('light palette uses forum home native colors', () {
    final theme = AppTheme.light();
    final displayPalette = ForumDisplayThemePalette.resolve(theme);
    final homePalette = ForumHomeNativePalette.resolve(theme);

    expect(displayPalette.background, homePalette.background);
    expect(displayPalette.panel, homePalette.sectionBodyBackground);
    expect(displayPalette.card, homePalette.sectionBodyBackground);
    expect(displayPalette.accent, homePalette.sectionHeaderBackground);
    expect(displayPalette.surfaceContainer, homePalette.sectionBodyBackground);
    expect(displayPalette.selectedContainer, isNot(Colors.transparent));
    expect(displayPalette.outlineSoft.a, lessThan(1));
    expect(displayPalette.stateLayer.a, lessThan(1));
  });

  test('dark palette remains derived from ColorScheme', () {
    final theme = AppTheme.dark();
    final palette = ForumDisplayThemePalette.resolve(theme);

    expect(palette.background, theme.scaffoldBackgroundColor);
    expect(palette.panel, theme.colorScheme.surfaceContainer);
    expect(palette.card, theme.colorScheme.surfaceContainerLowest);
    expect(palette.accent, theme.colorScheme.primary);
    expect(palette.surfaceContainer, theme.colorScheme.surfaceContainer);
    expect(
      palette.surfaceContainerLow,
      theme.colorScheme.surfaceContainerLowest,
    );
    expect(
      palette.surfaceContainerHigh,
      theme.colorScheme.surfaceContainerHighest,
    );
    expect(palette.selectedContainer, theme.colorScheme.secondaryContainer);
  });

  testWidgets('stays buildable first then renders list', (tester) async {
    final completer = Completer<ApiResult<ForumDisplayData>>();
    final repository = _FakeForumDisplayRepository(
      (fid, page, query) => completer.future,
    );

    await tester.pumpWidget(
      _buildTestApp(repository, threadRepository: _FakeThreadRepository()),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const Key('forum-display-list')), findsNothing);

    completer.complete(
      ApiSuccess(
        _displayData(
          page: 1,
          total: 2,
          threads: [
            ForumThreadSummary(
              tid: '100',
              subject: '帖子A',
              author: 'alice',
              replies: 1,
              views: 5,
              dateline: 'today',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('forum-display-list')), findsOneWidget);
    expect(
      find.byKey(const Key('forum-display-filter-header')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forum-thread-list-group')), findsOneWidget);
    final selectedFilterIndicatorSize = tester.getSize(
      find
          .descendant(
            of: find.byKey(
              const Key(
                'forum-display-filter-'
                'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&'
                'mobile=2',
              ),
            ),
            matching: find.byType(AnimatedContainer),
          )
          .last,
    );
    expect(selectedFilterIndicatorSize.width, 18);
    expect(selectedFilterIndicatorSize.height, 3);
    final selectedFilterIndicatorBottom = tester
        .getBottomLeft(
          find
              .descendant(
                of: find.byKey(
                  const Key(
                    'forum-display-filter-'
                    'https://bbs.yamibo.com/forum.php?mod=forumdisplay&fid=2&'
                    'mobile=2',
                  ),
                ),
                matching: find.byType(AnimatedContainer),
              )
              .last,
        )
        .dy;
    final filterHeaderBottom = tester
        .getBottomLeft(find.byKey(const Key('forum-display-filter-header')))
        .dy;
    expect(
      (filterHeaderBottom - selectedFilterIndicatorBottom).abs(),
      lessThanOrEqualTo(1),
    );
    final filterHeaderCenterY = tester
        .getCenter(find.byKey(const Key('forum-display-filter-header')))
        .dy;
    final selectedFilterTextCenterY = tester.getCenter(find.text('全部')).dy;
    expect(
      (filterHeaderCenterY - selectedFilterTextCenterY).abs(),
      lessThanOrEqualTo(2),
    );
    expect(find.text('帖子A'), findsOneWidget);
    final palette = ForumDisplayThemePalette.resolve(
      Theme.of(tester.element(find.byType(ForumDisplayPage))),
    );
    final threadSurface = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('forum-thread-100')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(threadSurface.color, palette.surfaceContainerLow);
    expect(threadSurface.borderRadius, BorderRadius.circular(12));
    final cardDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.byKey(const Key('forum-thread-100')),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(
      cardDecoration.boxShadow,
      ForumNativeSurfaceShadows.card(palette.stateLayer),
    );
    expect(find.text('公告区'), findsWidgets);
    expect(find.text('第1页'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forum-thread-100')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar).last, matching: find.text('公告区')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.text('帖子详情'),
      ),
      findsNothing,
    );
    Navigator.of(tester.element(find.byType(ThreadDetailPage))).pop();
    await tester.pumpAndSettle();

    const pageButtonKeys = [
      Key('forum-display-prev-page-button'),
      Key('forum-display-current-page-button'),
      Key('forum-display-load-more-button'),
    ];
    for (final key in pageButtonKeys) {
      final buttonWithKey = find.byKey(key);
      final descendantButton = find.descendant(
        of: buttonWithKey,
        matching: find.byType(TextButton),
      );
      final pageButton = tester.widget<TextButton>(
        descendantButton.evaluate().isEmpty ? buttonWithKey : descendantButton,
      );
      expect(
        pageButton.style?.backgroundColor?.resolve({}),
        palette.surfaceContainerHigh.withValues(alpha: 0.42),
      );
      final pageButtonShape =
          pageButton.style?.shape?.resolve({}) as RoundedRectangleBorder;
      expect(pageButtonShape.side, BorderSide.none);
      expect(pageButtonShape.borderRadius, BorderRadius.circular(10));
    }
  });

  testWidgets('pull refresh uses network-first forum display load', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: page,
          total: 1,
          threads: [
            ForumThreadSummary(
              tid: '100',
              subject: '帖子A',
              author: 'alice',
              replies: 1,
              views: 5,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
    ]);

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(repository.cachePolicies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('default svg avatar uses the local default avatar asset', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 1,
          threads: [
            ForumThreadSummary(
              tid: '100',
              subject: '帖子A',
              author: 'alice',
              replies: 1,
              views: 5,
              dateline: 'today',
              avatarUrl:
                  'https://bbs.yamibo.com/uc_server/data/avatar/noavatar.svg',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final avatar = find.byKey(const Key('forum-thread-summary-avatar-100'));
    final image = tester.widget<CachedLibraryImage>(
      find.descendant(of: avatar, matching: find.byType(CachedLibraryImage)),
    );
    expect(image.request, isNull);
    expect(
      image.imageProviderOverride,
      isA<AssetImage>().having(
        (provider) => provider.assetName,
        'assetName',
        forumDefaultAvatarAsset,
      ),
    );
    expect(image.fadeInDuration, const Duration(milliseconds: 300));
  });

  testWidgets(
    'manual content mode projects server text without reloading display',
    (tester) async {
      final conversionService = _ProjectionPrefixBatchConversionService();
      final repository = _FakeForumDisplayRepository((_, page, query) async {
        return ApiSuccess(
          _displayData(
            page: page,
            total: 31,
            threads: [
              ForumThreadSummary(
                tid: 'projection',
                subject: '帖子标题',
                author: 'alice',
                replies: 0,
                views: 1,
                dateline: '今天',
                excerpt: '帖子摘要',
                sourceTagName: '漫画',
                sourceTagUrl: '/forum.php?mod=forumdisplay&fid=2&typeid=7',
                threadUrl: '/thread-projection-1-1.html',
              ),
              for (var index = 1; index <= 30; index += 1)
                ForumThreadSummary(
                  tid: 'projection-$index',
                  subject: '帖子$index',
                  author: 'user$index',
                  replies: index,
                  views: index + 1,
                  dateline: '今天',
                  excerpt: '摘要$index',
                  threadUrl: '/thread-projection-$index-1-1.html',
                ),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(
          repository,
          extraOverrides: <riverpod_misc.Override>[
            appServerContentConversionModeProvider.overrideWithValue(
              TextConversionMode.toTraditional,
            ),
            textConverterProvider.overrideWith(
              (ref, mode) => _ProjectionTestConverter(mode),
            ),
            plainTextBatchConversionServiceProvider.overrideWithValue(
              conversionService,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T:公告区'), findsWidgets);
      expect(find.text('T:帖子标题'), findsOneWidget);
      expect(find.text('T:帖子摘要'), findsOneWidget);
      expect(find.text('T:漫画'), findsOneWidget);
      expect(find.text('T:今天'), findsWidgets);
      expect(find.text('alice'), findsOneWidget);
      expect(conversionService.callCount, 1);
      expect(repository.cachePolicies, <CacheLoadPolicy>[
        CacheLoadPolicy.cacheFirst,
      ]);

      await tester.drag(
        find.byKey(const Key('forum-display-list')),
        const Offset(0, -500),
      );
      await tester.pump();

      expect(conversionService.callCount, 1);
      expect(repository.cachePolicies, <CacheLoadPolicy>[
        CacheLoadPolicy.cacheFirst,
      ]);
    },
  );

  testWidgets('thread summary avatar uses avatar cache request', (
    tester,
  ) async {
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 1,
          threads: [
            ForumThreadSummary(
              tid: '100',
              uid: '42',
              subject: '帖子A',
              author: 'alice',
              replies: 1,
              views: 5,
              dateline: 'today',
              avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/00/00/42_avatar_middle.jpg',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();
    await tester.pump();

    final avatarImage = tester.widget<CachedLibraryImage>(
      find.descendant(
        of: find.byKey(const Key('forum-thread-summary-avatar-100')),
        matching: find.byType(CachedLibraryImage),
      ),
    );
    expect(avatarImage.request?.role, ImageCacheRole.avatar);
    expect(avatarImage.request?.ownerType, ImageCacheOwnerType.forumDisplay);
    expect(avatarImage.request?.ownerId, '42');
    expect(avatarImage.fadeInDuration, ForumCachedAvatar.fadeInDuration);
  });

  testWidgets('builds cards and starts avatars only near the viewport', (
    tester,
  ) async {
    final cache = _RecordingImageCacheService();
    final threads = List.generate(
      100,
      (index) => ForumThreadSummary(
        tid: '${10000 + index}',
        uid: '${30000 + index}',
        subject: 'Fixture thread $index',
        author: 'fixture-user',
        replies: 1,
        views: 5,
        dateline: 'fixture-time',
        avatarUrl: 'https://bbs.yamibo.com/fixture-avatar-$index.jpg',
      ),
    );
    final repository = _FakeForumDisplayRepository((_, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: threads.length,
          lastPage: 1,
          topEntries: const [],
          threads: threads,
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, imageCacheService: cache),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-10000')), findsOneWidget);
    expect(find.byKey(const Key('forum-thread-10020')), findsNothing);
    expect(cache.requests, isNotEmpty);
    expect(cache.requests.length, lessThan(20));
    expect(
      cache.requests.any((request) => request.ownerId == '30020'),
      isFalse,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('forum-thread-10020')),
      450,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('forum-display-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-10020')), findsOneWidget);
    expect(cache.requests.any((request) => request.ownerId == '30020'), isTrue);
    expect(find.byKey(const Key('forum-thread-10000')), findsNothing);
    expect(find.byKey(const Key('forum-thread-10099')), findsNothing);
    expect(
      cache.requests.any((request) => request.ownerId == '30099'),
      isFalse,
    );

    // A recycled row must be readable on its first frame back in view.
    _scrollPosition(tester).jumpTo(0);
    await tester.pump();
    _expectCardFullyVisible(tester, '10000');
  });
}
