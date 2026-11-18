part of 'forum_home_page_test.dart';

void _sectionsCases() {
  testWidgets('today badge appears when refreshed data adds today count', (
    tester,
  ) async {
    var requestCount = 0;
    final refreshCompleter = Completer<ForumHomeReadResult>();
    final repository = _FakeForumHomeRepository(() {
      requestCount += 1;
      if (requestCount == 1) {
        return Future<ForumHomeReadResult>.value(
          forumHomeReadSuccess(_loggedOutPayloadNoToday()),
        );
      }
      return refreshCompleter.future;
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsNothing);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refreshIndicator.onRefresh();
    await tester.pump();

    refreshCompleter.complete(forumHomeReadSuccess(_loggedOutPayload()));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
    'hides directory fields when their capabilities are unsupported',
    (tester) async {
      final capabilities = ForumDirectoryReadCapabilities(
        values: DataCapabilitySet<ForumDirectoryCapability>.from(
          supported: const <ForumDirectoryCapability>[
            ForumDirectoryCapability.stableSectionIdentity,
            ForumDirectoryCapability.orderedSections,
            ForumDirectoryCapability.stableForumIdentity,
            ForumDirectoryCapability.orderedForums,
          ],
          unsupported: const <ForumDirectoryCapability>[
            ForumDirectoryCapability.forumDescription,
            ForumDirectoryCapability.todayPostCount,
          ],
        ),
      );
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(
          _loggedOutPayload(todayPosts: 9, description: '不应显示'),
          capabilities: capabilities,
        ),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('不应显示'), findsNothing);
      expect(find.text('今日'), findsNothing);
    },
  );

  testWidgets(
    'today badge disappears when refreshed data removes today count',
    (tester) async {
      var requestCount = 0;
      final refreshCompleter = Completer<ForumHomeReadResult>();
      final repository = _FakeForumHomeRepository(() {
        requestCount += 1;
        if (requestCount == 1) {
          return Future<ForumHomeReadResult>.value(
            forumHomeReadSuccess(_loggedOutPayload()),
          );
        }
        return refreshCompleter.future;
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('今日'), findsOneWidget);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final refreshFuture = refreshIndicator.onRefresh();
      await tester.pump();

      refreshCompleter.complete(
        forumHomeReadSuccess(_loggedOutPayloadNoToday()),
      );
      await refreshFuture;
      await tester.pumpAndSettle();

      expect(find.text('今日'), findsNothing);
    },
  );

  testWidgets('today badge keeps stable subtree when count changes', (
    tester,
  ) async {
    var requestCount = 0;
    final refreshCompleter = Completer<ForumHomeReadResult>();
    final repository = _FakeForumHomeRepository(() {
      requestCount += 1;
      if (requestCount == 1) {
        return Future<ForumHomeReadResult>.value(
          forumHomeReadSuccess(_loggedOutPayload()),
        );
      }
      return refreshCompleter.future;
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final beforeElement = tester.element(
      find.byKey(const ValueKey('forum-home-today-badge-filled')),
    );
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refreshIndicator.onRefresh();
    await tester.pump();

    refreshCompleter.complete(
      forumHomeReadSuccess(_loggedOutPayloadWithTodayCount(8)),
    );
    await refreshFuture;
    await tester.pump();

    final afterElement = tester.element(
      find.byKey(const ValueKey('forum-home-today-badge-filled')),
    );
    expect(identical(beforeElement, afterElement), isTrue);
    expect(find.text('今日'), findsOneWidget);
  });

  testWidgets(
    'manual content mode projects server text without reloading home',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(_loggedOutPayload()),
      );

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
              _ProjectionPrefixBatchConversionService(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T:综合区'), findsOneWidget);
      expect(find.text('T:公告区'), findsOneWidget);
      expect(find.text('T:站点公告与维护信息'), findsOneWidget);
      expect(
        find.byKey(const Key('forum-section-toggle-regular:1')),
        findsOneWidget,
      );
      expect(repository.cachePolicies, <CacheLoadPolicy>[
        CacheLoadPolicy.cacheFirst,
      ]);
    },
  );

  testWidgets(
    'silent refresh triggers when page becomes active after threshold',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(_loggedOutPayload()),
      );
      final fakeNow = _MutableNow(DateTime(2026, 6, 29, 12, 0, 0));

      await tester.pumpWidget(
        _buildTestApp(repository, isActive: false, nowProvider: fakeNow.call),
      );
      await tester.pumpAndSettle();

      fakeNow.value = fakeNow.value.add(const Duration(seconds: 61));

      await tester.pumpWidget(
        _buildTestApp(repository, isActive: true, nowProvider: fakeNow.call),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.cachePolicies, <CacheLoadPolicy>[
        CacheLoadPolicy.cacheFirst,
        CacheLoadPolicy.networkFirst,
      ]);
      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    },
  );

  testWidgets(
    'renders favorite forum section when logged in payload has favorites',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('我收藏的版块'), findsOneWidget);
      expect(find.byKey(const Key('forum-favorite-card-2')), findsOneWidget);
      expect(find.byKey(const Key('forum-favorite-card-55')), findsOneWidget);
      expect(find.text('综合区'), findsOneWidget);
    },
  );

  testWidgets(
    'favorite forums use forum index description when favorite description is empty',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(
          _loggedInPayloadWithEmptyFavoriteDescription(),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-favorite-card-2')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('forum-favorite-card-2')),
          matching: find.text('站点公告与维护信息'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('forum-favorite-card-2')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'favorite forums use home html descriptions before forum index fallback',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(
          _loggedInPayloadWithChromeFavoriteDescriptions(),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('风声水起。'), findsOneWidget);
      expect(find.text('爱的推广会。'), findsOneWidget);
      expect(find.text('外文作品翻译的分享与赏析。'), findsOneWidget);
    },
  );

  testWidgets(
    'section header toggles forum rows with expand and collapse icons',
    (tester) async {
      final repository = _FakeForumHomeRepository(
        () async => forumHomeReadSuccess(_loggedInPayloadWithFavorites()),
      );

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-favorite-card-2')), findsOneWidget);
      var indicator = tester.widget<Icon>(
        find.byKey(const Key('forum-section-indicator-favorite:2,55')),
      );
      expect(indicator.icon, Icons.expand_more);
      final palette = ForumHomeNativePalette.resolve(
        Theme.of(tester.element(find.byType(ForumHomePage))),
      );
      final header = tester.widget<Material>(
        find.byKey(const Key('forum-section-title-favorite:2,55')),
      );
      expect(header.color, palette.sectionHeaderBackground);
      expect(indicator.color, palette.sectionHeaderForeground);
      final body = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('forum-home-section-expanded-favorite:2,55')),
      );
      expect(
        (body.decoration as BoxDecoration).color,
        palette.sectionBodyBackground,
      );

      await tester.tap(
        find.byKey(const Key('forum-section-toggle-favorite:2,55')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      expect(find.byKey(const Key('forum-favorite-card-2')), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-favorite-card-2')), findsNothing);
      indicator = tester.widget<Icon>(
        find.byKey(const Key('forum-section-indicator-favorite:2,55')),
      );
      expect(indicator.icon, Icons.chevron_right);

      await tester.tap(
        find.byKey(const Key('forum-section-toggle-favorite:2,55')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-favorite-card-2')), findsOneWidget);
      indicator = tester.widget<Icon>(
        find.byKey(const Key('forum-section-indicator-favorite:2,55')),
      );
      expect(indicator.icon, Icons.expand_more);
    },
  );
}
