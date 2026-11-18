part of 'profile_blog_page_test.dart';

void _feedbackAndLayoutCases() {
  testWidgets('failed page navigation preserves a scrolled blog list', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository(longList: true)
      ..failedPages.add(2);
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
    );
    final scrollable = find.descendant(
      of: find.byKey(const Key('profile-blog-list')),
      matching: find.byType(Scrollable),
    );
    final next = find.byKey(const Key('profile-blog-next-page-button'));
    await tester.scrollUntilVisible(next, 500, scrollable: scrollable);
    await tester.pumpAndSettle();
    final oldOffset = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(oldOffset, 0.5),
    );
    expect(repository.queries.last.page, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capabilities hide optional list and detail fields', (
    tester,
  ) async {
    final directoryCapabilities = _directoryCapabilities(
      supported: const <UserBlogDirectoryCapability>[
        UserBlogDirectoryCapability.stableFeedIdentity,
        UserBlogDirectoryCapability.orderedEntries,
        UserBlogDirectoryCapability.stableBlogIdentity,
        UserBlogDirectoryCapability.stableOwnerIdentity,
        UserBlogDirectoryCapability.title,
      ],
    );
    final detailCapabilities = _detailCapabilities(
      supported: const <UserBlogDetailCapability>[
        UserBlogDetailCapability.stableBlogIdentity,
        UserBlogDetailCapability.stableOwnerIdentity,
        UserBlogDetailCapability.title,
        UserBlogDetailCapability.bodyMarkup,
      ],
    );
    await _pumpBlogPage(
      tester,
      directoryRepository: _FakeBlogDirectoryRepository(
        capabilities: directoryCapabilities,
      ),
      detailRepository: _FakeBlogDetailRepository(
        capabilities: detailCapabilities,
      ),
    );

    expect(find.text('一种体验'), findsOneWidget);
    expect(find.text('抉择'), findsNothing);
    expect(find.text('2026-6-21 13:06'), findsNothing);
    expect(find.textContaining('作为女生'), findsNothing);

    await tester.tap(find.text('一种体验'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileBlogDetailPage)),
    );
    expect(find.byKey(const Key('blog-detail-views')), findsNothing);
    expect(find.byKey(const Key('blog-detail-comment-count')), findsNothing);
    expect(find.text(l10n.profileBlogComments), findsNothing);
    expect(find.byKey(const Key('blog-detail-reply')), findsNothing);
    expect(find.byKey(const Key('profile-blog-comment-button')), findsNothing);
  });

  testWidgets('refresh failure retains existing directory content', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository(failAfterSuccess: true);
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(find.text('一种体验'), findsOneWidget);
    expect(find.textContaining('网络连接失败'), findsOneWidget);
    expect(repository.policies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });

  testWidgets('initial failure shows retry and then loads content', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository(failFirst: true);
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
      settle: false,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('网络连接失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('一种体验'), findsOneWidget);
  });

  testWidgets('ProfileBlogPage localizes chrome and preserves server titles', (
    tester,
  ) async {
    await _pumpBlogPage(
      tester,
      directoryRepository: _FakeBlogDirectoryRepository(),
      detailRepository: _FakeBlogDetailRepository(),
      locale: const Locale('zh', 'TW'),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileBlogPage)),
    );

    expect(find.text('隨便看看'), findsOneWidget);
    expect(find.text(l10n.profileBlogLatestShort), findsOneWidget);
    expect(find.text('一种体验'), findsOneWidget);
  });

  testWidgets('blog layout remains usable at 300dp with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blogAccountIdProvider.overrideWithValue('101'),
          userBlogDirectoryRepositoryProvider.overrideWithValue(
            _FakeBlogDirectoryRepository(),
          ),
          userBlogDetailRepositoryProvider.overrideWithValue(
            _FakeBlogDetailRepository(),
          ),
          forumImageRefererProvider.overrideWithValue(
            'https://bbs.yamibo.com/',
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: LocalizedTestApp(home: ProfileBlogPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('profile-blog-list')), findsOneWidget);
  });
}
