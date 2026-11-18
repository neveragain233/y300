part of 'more_page_test.dart';

void _navigationCases() {
  for (final locale in [const Locale('zh'), const Locale('zh', 'TW')]) {
    testWidgets(
      'More keeps one settings entry without duplicate settings rows in '
      '${locale.toLanguageTag()}',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: false)),
              appAppearanceControllerProvider.overrideWith(
                () => _FakeAppAppearanceController(),
              ),
            ],
            child: LocalizedTestApp(home: const MorePage(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();
        final settingsEntry = find.byKey(const Key('more-settings-entry'));
        await _scrollUntilVisibleIfNeeded(tester, settingsEntry);
        final l10n = AppLocalizations.of(tester.element(settingsEntry));
        expect(
          (tester.widget<ListTile>(settingsEntry).title! as Text).data,
          l10n.moreSectionSettings,
        );
        for (final key in [
          'more-appearance-entry',
          'more-navigation-management-entry',
          'more-content-filter-entry',
          'more-thread-controls-entry',
          'more-data-storage-entry',
          'more-about-entry',
          'more-composer-quill-prototype-entry',
          'more-html-renderer-prototype-entry',
        ]) {
          expect(find.byKey(Key(key)), findsNothing, reason: key);
        }
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.byIcon(Icons.content_paste_go_outlined), findsNothing);
        expect(
          find.byKey(const Key('more-clipboard-link-detection-switch')),
          findsNothing,
        );

        await tester.tap(settingsEntry);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('settings-page')), findsOneWidget);
        expect(
          find.byKey(const Key('more-navigation-management-entry')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('more-appearance-entry')), findsOneWidget);
        expect(
          find.byKey(const Key('more-clipboard-link-detection-switch')),
          findsNothing,
        );
        expect(find.byType(SwitchListTile), findsNothing);
      },
    );
  }

  for (final type in UserThreadDirectoryType.values) {
    testWidgets('account ${type.name} statistic opens its native directory', (
      tester,
    ) async {
      final directory = _ThreadDirectoryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: true)),
            userThreadDirectoryRepositoryProvider.overrideWithValue(directory),

            appAppearanceControllerProvider.overrideWith(
              () => _FakeAppAppearanceController(),
            ),
          ],
          child: const LocalizedTestApp(home: MorePage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('more-account-${type.name}')));
      await tester.pumpAndSettle();
      expect(find.byType(MyThreadPage), findsOneWidget);
      expect(
        tester.widget<MyThreadPage>(find.byType(MyThreadPage)).initialType,
        type,
      );
      expect(directory.queries.single.type, type);
      expect(directory.queries.single.userId, '100');
    });
  }

  testWidgets(
    'account navigation ignores competing callbacks in the same frame',
    (tester) async {
      final observer = _RouteNameObserver();
      final webLaunches = <ForumWebViewLaunchConfig>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._moreAuthOverrides(_FakeAuthRepository(isLoggedIn: true)),
            userThreadDirectoryRepositoryProvider.overrideWithValue(
              _ThreadDirectoryRepository(),
            ),
            forumWebViewRouteFactoryProvider.overrideWithValue(
              _profileWebRoutes(webLaunches),
            ),

            appAppearanceControllerProvider.overrideWith(
              () => _FakeAppAppearanceController(),
            ),
          ],
          child: LocalizedTestApp(
            home: const MorePage(),
            navigatorObservers: [observer],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MorePage)),
      );
      await container
          .read(mainNavigationSettingsControllerProvider.notifier)
          .setVisibility(MainShellDestination.forum, false);
      await tester.pumpAndSettle();
      VoidCallback statisticTap(String type) => tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(Key('more-account-$type')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!;
      final threadTap = statisticTap('threads');
      final replyTap = statisticTap('replies');
      final creditTap = statisticTap('credits');
      final profileTap = tester
          .widget<InkWell>(find.byKey(const Key('more-account-avatar')))
          .onTap!;
      final logoutTap = tester
          .widget<IconButton>(find.byKey(const Key('more-logout-entry')))
          .onPressed!;
      final menuTaps = <VoidCallback>[];
      for (final name in ['messages', 'blogs', 'friends']) {
        final entry = find.byKey(Key('more-my-$name-entry'));
        await _scrollUntilVisibleIfNeeded(tester, entry);
        menuTaps.add(tester.widget<ListTile>(entry).onTap!);
      }
      threadTap();
      for (final tap in menuTaps) {
        tap();
      }
      creditTap();
      replyTap();
      profileTap();
      logoutTap();
      await tester.pumpAndSettle();
      expect(find.byType(MyThreadPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(observer.pushedNames.length, 2);
      expect(webLaunches, isEmpty);
    },
  );

  for (final action in [
    ForumUserProfileActionKind.messages,
    ForumUserProfileActionKind.blogs,
    ForumUserProfileActionKind.friends,
  ]) {
    testWidgets(
      'my ${action.name} menu opens the native current-account page',
      (tester) async {
        final directory = _ThreadDirectoryRepository();
        final messages = MessageTestRepository();
        final blogs = BlogDirectoryFixture();
        final friends = _emptyFriends();
        final webLaunches = <ForumWebViewLaunchConfig>[];
        final summary = _AccountSummaryRepository(
          () => const CurrentUserProfileData(
            identity: ProfileUserIdentity(userId: '100', displayName: 'tester'),
            creditTotal: 42,
          ),
        );
        await _pumpMyContentPage(
          tester,
          isLoggedIn: true,
          directory: directory,
          messages: messages,
          blogs: blogs,
          friends: friends,
          launches: webLaunches,
          summary: summary,
        );
        final entry = find.byKey(Key('more-my-${action.name}-entry'));
        await _scrollUntilVisibleIfNeeded(tester, entry);
        await tester.tap(entry);
        if (action == ForumUserProfileActionKind.messages) {
          await tester.pump();
          _completeMessageReads(messages, owner: '100');
        }
        await tester.pumpAndSettle();

        final Finder destination;
        switch (action) {
          case ForumUserProfileActionKind.messages:
            destination = find.byType(MessageCenterPage);
            expect(destination, findsOneWidget);
            expect(
              tester.widget<MessageCenterPage>(destination).initialTab,
              MessageCenterTab.messages,
            );
            expect(
              ProviderScope.containerOf(tester.element(destination))
                  .read(messageAccountIdProvider),
              '100',
            );
            expect(messages.reads.single.query.target, isNull);
            expect(messages.reads.single.query.page, 1);
            expect(messages.notificationReads, isEmpty);
            expect(directory.queries, isEmpty);
            expect(blogs.queries, isEmpty);
            expect(friends.requests, isEmpty);
          case ForumUserProfileActionKind.blogs:
            destination = find.byType(ProfileBlogPage);
            expect(destination, findsOneWidget);
            expect(
              tester.widget<ProfileBlogPage>(destination).initialScope,
              UserBlogFeedScope.self,
            );
            expect(
              tester.widget<ProfileBlogPage>(destination).ownerUserId,
              isNull,
            );
            expect(blogs.queries.single.scope, UserBlogFeedScope.self);
            expect(blogs.queries.single.ownerUserId, '100');
            expect(directory.queries, isEmpty);
            expect(friends.requests, isEmpty);
          case ForumUserProfileActionKind.friends:
            destination = find.byType(MyFriendsPage);
            expect(destination, findsOneWidget);
            expect(friends.requests.single.query.accountUserId, '100');
            expect(
              friends.requests.single.query.scope,
              ForumFriendFeedScope.friends,
            );
            expect(directory.queries, isEmpty);
            expect(blogs.queries, isEmpty);
          default:
            fail('Unexpected content action');
        }
        expect(webLaunches, isEmpty);
        expect(summary.reads, 1);
        Navigator.of(tester.element(destination)).pop();
        await tester.pumpAndSettle();
        expect(find.byType(MorePage), findsOneWidget);
        expect(summary.reads, 2);
        expect(tester.widget<ListTile>(entry).onTap, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final completesLogin in [true, false]) {
    testWidgets(
      'guest friends menu ${completesLogin ? 'continues after verified login' : 'stays on More after cancelled login'}',
      (tester) async {
        final friends = _emptyFriends();
        final webLaunches = <ForumWebViewLaunchConfig>[];
        final observer = _RouteNameObserver();
        await _pumpMyContentPage(
          tester,
          isLoggedIn: false,
          friends: friends,
          launches: webLaunches,
          observer: observer,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MorePage)),
        );
        final entry = find.byKey(const Key('more-my-friends-entry'));
        await _scrollUntilVisibleIfNeeded(tester, entry);
        final tap = tester.widget<ListTile>(entry).onTap!;
        tap();
        tap();
        expect(observer.pushedNames.last, LoginWebViewPage.routeName);
        expect(
          observer.pushedNames.where(
            (name) => name == LoginWebViewPage.routeName,
          ),
          hasLength(1),
        );
        expect(friends.requests, isEmpty);

        // Simulate the verified login handoff without building a platform view.
        if (completesLogin) {
          container
              .read(authSessionControllerProvider.notifier)
              .acceptSession(
                const ForumSessionIdentity(
                  userId: '200',
                  username: 'next-account',
                ),
              );
        }
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pop(completesLogin);
        await tester.pumpAndSettle();

        expect(webLaunches, isEmpty);
        if (completesLogin) {
          expect(find.byType(MyFriendsPage), findsOneWidget);
          expect(friends.requests.single.query.accountUserId, '200');
          expect(
            friends.requests.single.query.scope,
            ForumFriendFeedScope.friends,
          );
          expect(observer.pushedNames, hasLength(3));
        } else {
          expect(find.byType(MorePage), findsOneWidget);
          expect(find.byType(MyFriendsPage), findsNothing);
          expect(friends.requests, isEmpty);
          expect(observer.pushedNames, hasLength(2));
          expect(tester.widget<ListTile>(entry).onTap, isNotNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'credit statistics open one account-bound route and refresh totals on return',
    (tester) async {
      var credits = 12;
      final summary = _AccountSummaryRepository(
        () => CurrentUserProfileData(
          identity: const ProfileUserIdentity(
            userId: '100',
            displayName: 'tester',
          ),
          creditTotal: credits,
        ),
      );
      final webLaunches = <ForumWebViewLaunchConfig>[];
      final observer = _RouteNameObserver();
      await _pumpCreditPage(
        tester,
        summary: summary,
        launches: webLaunches,
        observer: observer,
      );
      expect(summary.reads, 1);
      final creditsTap = _accountStatisticButton(tester, 'credits').onTap!;
      final threadsTap = _accountStatisticButton(tester, 'threads').onTap!;
      final repliesTap = _accountStatisticButton(tester, 'replies').onTap!;
      final profileTap = tester
          .widget<InkWell>(find.byKey(const Key('more-account-avatar')))
          .onTap!;
      final logoutTap = tester
          .widget<IconButton>(find.byKey(const Key('more-logout-entry')))
          .onPressed!;

      creditsTap();
      creditsTap();
      threadsTap();
      repliesTap();
      profileTap();
      logoutTap();
      await tester.pumpAndSettle();

      expect(webLaunches, hasLength(1));
      expect(
        webLaunches.single.initialUri,
        Uri.parse('https://bbs.yamibo.com/plugin.php?id=zqlj_sign&mobile=2'),
      );
      expect(webLaunches.single.popOnRootBack, isTrue);
      expect(webLaunches.single.expectedAccountId, '100');
      expect(find.byKey(const Key('test-profile-webview')), findsOneWidget);
      expect(find.byType(MyThreadPage, skipOffstage: false), findsNothing);
      expect(find.byType(MyProfilePage, skipOffstage: false), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(observer.pushedNames, hasLength(2));
      expect(summary.reads, 1);
      for (final name in ['threads', 'replies', 'credits']) {
        expect(
          _accountStatisticButton(tester, name, skipOffstage: false).onTap,
          isNull,
        );
      }
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('more-account-avatar'), skipOffstage: false),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('more-logout-entry'), skipOffstage: false),
            )
            .onPressed,
        isNull,
      );

      credits = 19;
      Navigator.of(
        tester.element(find.byKey(const Key('test-profile-webview'))),
      ).pop();
      await tester.pumpAndSettle();

      expect(find.byType(MorePage), findsOneWidget);
      expect(summary.reads, 2);
      final counter = find.descendant(
        of: find.byKey(const Key('more-account-credits')),
        matching: find.byType(AnimatedFlipCounter),
      );
      expect(tester.widget<AnimatedFlipCounter>(counter).value, 19);
      expect(_accountStatisticButton(tester, 'credits').onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'returning from old credit details does not refresh a new owner',
    (tester) async {
      var uid = '100';
      final summary = _AccountSummaryRepository(
        () => CurrentUserProfileData(
          identity: ProfileUserIdentity(
            userId: uid,
            displayName: 'Account $uid',
          ),
          creditTotal: uid == '100' ? 12 : 27,
        ),
      );
      final webLaunches = <ForumWebViewLaunchConfig>[];
      await _pumpCreditPage(tester, summary: summary, launches: webLaunches);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MorePage)),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(MorePage)));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('more-account-credits')),
          matching: find.text(l10n.moreAccountCreditLabel),
        ),
      );
      await tester.pumpAndSettle();
      expect(webLaunches.single.expectedAccountId, '100');
      expect(summary.reads, 1);

      uid = '200';
      container
          .read(authSessionControllerProvider.notifier)
          .acceptSession(
            const ForumSessionIdentity(userId: '200', username: 'next-account'),
          );
      await tester.pumpAndSettle();
      expect(container.read(verifiedSessionOwnerProvider)?.uid, '200');
      // Offstage consumers may pause; observe the new summary before returning.
      expect(
        container.read(currentAccountSummaryControllerProvider).owner?.uid,
        '200',
      );
      await tester.pumpAndSettle();
      expect(summary.reads, 2);

      Navigator.of(
        tester.element(find.byKey(const Key('test-profile-webview'))),
      ).pop();
      await tester.pumpAndSettle();

      expect(summary.reads, 2);
      expect(webLaunches, hasLength(1));
      expect(find.text('Account 200'), findsOneWidget);
      final counter = find.descendant(
        of: find.byKey(const Key('more-account-credits')),
        matching: find.byType(AnimatedFlipCounter),
      );
      expect(tester.widget<AnimatedFlipCounter>(counter).value, 27);
      expect(_accountStatisticButton(tester, 'credits').onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
