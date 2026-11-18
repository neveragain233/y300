part of 'user_profile_page_test.dart';

void _profileRenderingCases() {
  testWidgets('UserProfilePage renders source-neutral profile data', (
    tester,
  ) async {
    await _pumpPublicProfile(tester, repository: _FakeProfileRepository());

    expect(find.text('alice的资料'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byKey(const Key('user-profile-action-settings')), findsNothing);
    expect(find.byKey(const Key('user-profile-metrics')), findsOneWidget);
    expect(find.text('2048'), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(UserProfilePage)),
    );
    expect(find.byKey(const Key('user-profile-actions')), findsOneWidget);
    expect(find.text(l10n.profileMyThreadsTab), findsOneWidget);
    expect(find.text(l10n.profileSendMessage), findsOneWidget);
    expect(find.byKey(const Key('user-profile-signature')), findsOneWidget);
    expect(_richTextContaining('Make a deal'), findsOneWidget);
    expect(find.byKey(const Key('user-profile-details')), findsOneWidget);
    expect(find.text('用户组'), findsOneWidget);
    expect(find.text('普通会员'), findsOneWidget);
  });

  testWidgets('public profile opens owner blogs and a direct conversation', (
    tester,
  ) async {
    ForumConversationTarget? opened;
    String? openedTitle;
    final blogRepository = _FakeBlogDirectoryRepository();
    await _pumpPublicProfile(
      tester,
      repository: _FakeProfileRepository(),
      blogRepository: blogRepository,
      conversationRoute: (target, {title = ''}) {
        opened = target;
        openedTitle = title;
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('conversation fixture')),
        );
      },
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(UserProfilePage)),
    );
    expect(find.text(l10n.profileSendMessage), findsOneWidget);
    final blogs = find.byKey(const Key('user-profile-action-blogs'));
    await _reveal(tester, blogs);
    await tester.tap(blogs);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileBlogPage), findsOneWidget);
    expect(blogRepository.queries.single.ownerUserId, '123456');
    expect(blogRepository.queries.single.scope, UserBlogFeedScope.self);
    Navigator.of(tester.element(find.byType(ProfileBlogPage))).pop();
    await tester.pumpAndSettle();

    final send = find.byKey(const Key('user-profile-action-sendMessage'));
    await _reveal(tester, send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(opened, const ForumConversationTarget.direct('123456'));
    expect(openedTitle, 'alice');
    expect(find.text('conversation fixture'), findsOneWidget);
  });

  testWidgets('opening the verified viewer UID uses the self profile', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(data: _allActionsProfile);
    await _pumpMyProfile(
      tester,
      repository: repository,
      home: const UserProfilePage(uid: '654321'),
    );
    expect(find.byType(MyProfilePage), findsOneWidget);
    expect(repository.queries.last.view, ForumUserProfileView.self);
    expect(repository.queries.last.viewerUserId, '654321');
    expect(
      find.byKey(const Key('user-profile-action-threads')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('user-profile-action-messages')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('user-profile-action-sendMessage')),
      findsNothing,
    );
  });

  testWidgets('guest profile exposes content and a localized login entry', (
    tester,
  ) async {
    await _pumpPublicProfile(
      tester,
      owner: null,
      repository: _FakeProfileRepository(
        data: const ForumUserProfileData(
          identity: ProfileUserIdentity(userId: '123456', displayName: 'alice'),
          metrics: [],
          details: [],
          actions: [
            ForumUserProfileActionKind.threads,
            ForumUserProfileActionKind.blogs,
            ForumUserProfileActionKind.sendMessage,
          ],
        ),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(UserProfilePage)),
    );
    expect(
      find.byKey(const Key('user-profile-action-threads')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('user-profile-action-blogs')), findsOneWidget);
    expect(
      find.byKey(const Key('user-profile-action-sendMessage')),
      findsNothing,
    );
    expect(find.text(l10n.profileLoginToInteract), findsOneWidget);
  });

  for (final owner in <VerifiedSessionOwner?>[
    null,
    (uid: '654321', revision: 0),
  ]) {
    testWidgets(
      'public profile omits settings even when advertised for $owner',
      (tester) async {
        await _pumpPublicProfile(
          tester,
          owner: owner,
          repository: _FakeProfileRepository(
            data: ForumUserProfileData(
              identity: const ProfileUserIdentity(userId: '123456'),
              viewerUserId: owner?.uid,
              actions: const [ForumUserProfileActionKind.settings],
              actionLinks: _allActionsProfile.actionLinks
                  .where(
                    (link) => link.kind == ForumUserProfileActionKind.settings,
                  )
                  .toList(),
              metrics: const [],
              details: const [],
            ),
          ),
        );

        expect(
          find.byKey(const Key('user-profile-action-settings')),
          findsNothing,
        );
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
        expect(find.byIcon(Icons.home_outlined), findsNothing);
        expect(find.byKey(const Key('user-profile-open-web')), findsOneWidget);
      },
    );
  }

  testWidgets('UserProfilePage gates optional sections by capability', (
    tester,
  ) async {
    await _pumpPublicProfile(
      tester,
      repository: _FakeProfileRepository(
        capabilities: _profileCapabilities(
          supported: const <ForumUserProfileCapability>[
            ForumUserProfileCapability.stableUserIdentity,
            ForumUserProfileCapability.userName,
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('user-profile-metrics')), findsNothing);
    expect(find.byKey(const Key('user-profile-signature')), findsNothing);
    expect(find.byKey(const Key('user-profile-details')), findsNothing);
    expect(find.text('2048'), findsNothing);
    expect(find.text('普通会员'), findsNothing);
  });

  testWidgets('UserProfilePage avatar uses profile cache ownership', (
    tester,
  ) async {
    await _pumpPublicProfile(
      tester,
      repository: _FakeProfileRepository(
        data: _profileWith(
          avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/12/34/56_avatar_middle.jpg',
        ),
      ),
      imageCacheService: _NoopImageCacheService(),
    );

    final avatarImage = tester
        .widgetList<CachedLibraryImage>(
          find.descendant(
            of: find.byKey(const Key('user-profile-avatar')),
            matching: find.byType(CachedLibraryImage),
          ),
        )
        .singleWhere((image) => image.request != null);
    expect(avatarImage.request?.role, ImageCacheRole.avatar);
    expect(avatarImage.request?.ownerType, ImageCacheOwnerType.profile);
    expect(avatarImage.request?.ownerId, '123456');
  });

  testWidgets(
    'UserProfilePage localizes app chrome and preserves server text',
    (tester) async {
      await _pumpPublicProfile(
        tester,
        repository: _FakeProfileRepository(),
        locale: const Locale('zh', 'TW'),
      );

      expect(find.text('alice 的資料'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(UserProfilePage)),
      );
      expect(find.byKey(const Key('user-profile-actions')), findsOneWidget);
      expect(find.text(l10n.profileMyThreadsTab), findsOneWidget);
      expect(find.text(l10n.profileSendMessage), findsOneWidget);
      expect(find.text('普通会员'), findsOneWidget);
    },
  );

  testWidgets('refresh failure keeps existing profile content', (tester) async {
    final repository = _FakeProfileRepository(failAfterSuccess: true);
    await _pumpPublicProfile(tester, repository: repository);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UserProfilePage)),
    );

    await container.read(userProfileProvider('123456').notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
    expect(find.textContaining('网络连接失败'), findsOneWidget);
    expect(repository.policies, <CacheLoadPolicy>[
      CacheLoadPolicy.cacheFirst,
      CacheLoadPolicy.networkFirst,
    ]);
  });
}
