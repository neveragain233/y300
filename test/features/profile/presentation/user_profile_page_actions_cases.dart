part of 'user_profile_page_test.dart';

void _actionsCases() {
  testWidgets(
    'WebView profile action opens native once and returns to the web host',
    (tester) async {
      final repository = _FakeProfileRepository(data: _myProfile);
      final store = YamiboSessionStore()..saveExtracted(_sessionFor('654321'));
      await _pumpMyProfile(
        tester,
        repository: repository,
        store: store,
        home: Scaffold(
          key: const Key('profile-web-host'),
          appBar: AppBar(
            actions: [
              MyProfileWebViewAction(
                currentUri: Uri.parse(
                  'https://bbs.yamibo.com/home.php?mod=space&uid=654321&do=profile&mobile=2',
                ),
              ),
            ],
          ),
        ),
      );
      final button = find.byKey(
        const Key('forum-webview-native-profile-button'),
      );
      final l10n = AppLocalizations.of(tester.element(button));
      expect(tester.widget<IconButton>(button).tooltip, l10n.profileOpenNative);
      expect(repository.queries, isEmpty);
      final open = tester.widget<IconButton>(button).onPressed!;
      open();
      open();
      await tester.pumpAndSettle();
      expect(find.byType(MyProfilePage), findsOneWidget);
      expect(repository.queries, hasLength(1));
      expect(repository.queries.single.userId, '654321');
      expect(repository.queries.single.view, ForumUserProfileView.self);

      Navigator.of(tester.element(find.byType(MyProfilePage))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-web-host')), findsOneWidget);
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      store.clear();
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      open();
      await tester.pumpAndSettle();
      expect(find.byType(MyProfilePage), findsNothing);
      expect(repository.queries, hasLength(1));
    },
  );

  for (final uri in [
    'https://bbs.yamibo.com/home.php?mod=space&uid=777777&do=profile',
    'https://example.test/home.php?mod=space&uid=654321&do=profile',
    'https://bbs.yamibo.com/member.php?mod=logging&action=login',
    'https://bbs.yamibo.com/home.php?mod=space&uid=654321&uid=777777&do=profile',
    'about:blank',
  ]) {
    testWidgets('native self-profile action stays hidden for $uri', (
      tester,
    ) async {
      final repository = _FakeProfileRepository(data: _myProfile);
      await _pumpMyProfile(
        tester,
        repository: repository,
        home: Scaffold(
          appBar: AppBar(
            actions: [MyProfileWebViewAction(currentUri: Uri.parse(uri))],
          ),
        ),
      );
      expect(
        find.byKey(const Key('forum-webview-native-profile-button')),
        findsNothing,
      );
      expect(repository.queries, isEmpty);
    });
  }

  for (final self in [false, true]) {
    testWidgets(
      '${self ? 'self' : 'public'} initial placeholder preserves the scrollable and identity anchor',
      (tester) async {
        final initialRead = Completer<_ProfileReadResult>();
        final repository = _ScriptedProfileRepository(
          (_, _) => initialRead.future,
        );
        final directory = _ProfileThreadDirectoryRepository();
        final profile = self ? _myProfile : _profile;
        if (self) {
          await _pumpMyProfile(
            tester,
            repository: repository,
            threadDirectory: directory,
            settle: false,
          );
        } else {
          await _pumpPublicProfile(
            tester,
            repository: repository,
            settle: false,
          );
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(repository.queries, hasLength(1));
        expect(
          find.byKey(const Key('user-profile-identity-skeleton')),
          findsOneWidget,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(self ? MyProfilePage : UserProfilePage)),
        );
        final loadingSemantics = tester.widget<Semantics>(
          find.byKey(const Key('user-profile-identity-skeleton')),
        );
        expect(loadingSemantics.properties.label, l10n.profileLoading);
        expect(loadingSemantics.properties.liveRegion, isTrue);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('user-profile-name')), findsNothing);
        expect(find.byKey(const Key('user-profile-copy-uid')), findsNothing);
        for (final kind in [
          'settings',
          'sendMessage',
          'addFriend',
          'removeFriend',
        ]) {
          expect(find.byKey(Key('user-profile-action-$kind')), findsNothing);
        }

        final scrollable = _profileScrollable(tester);
        final identityTop = tester
            .getTopLeft(find.byKey(const Key('user-profile-identity')))
            .dy;
        final avatar = tester.getRect(
          find.byKey(const Key('user-profile-avatar-skeleton')),
        );
        if (self) {
          final shortcuts = find.byKey(
            const Key('my-profile-native-shortcuts'),
          );
          expect(shortcuts, findsOneWidget);
          for (final kind in ['threads', 'replies', 'blogs', 'messages']) {
            final action = find.byKey(Key('user-profile-action-$kind'));
            expect(
              find.descendant(of: shortcuts, matching: action),
              findsOneWidget,
            );
            expect(tester.widget<InkWell>(action).onTap, isNotNull);
          }
          tester
              .widget<InkWell>(
                find.byKey(const Key('user-profile-action-threads')),
              )
              .onTap!();
          await tester.pumpAndSettle();
          expect(find.byType(MyThreadPage), findsOneWidget);
          expect(directory.queries.single.userId, '654321');
          Navigator.of(tester.element(find.byType(MyThreadPage))).pop();
          await tester.pump();
          expect(
            find.byKey(const Key('user-profile-identity-skeleton')),
            findsOneWidget,
          );
        } else {
          expect(
            find.byKey(const Key('my-profile-native-shortcuts')),
            findsNothing,
          );
          expect(find.byKey(const Key('user-profile-actions')), findsNothing);
        }

        initialRead.complete(_profileSuccess(profile));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('user-profile-identity-skeleton')),
          findsNothing,
        );
        expect(_profileScrollable(tester), same(scrollable));
        expect(
          tester.getTopLeft(find.byKey(const Key('user-profile-identity'))).dy,
          closeTo(identityTop, 0.01),
        );
        expect(
          tester.getRect(find.byKey(const Key('user-profile-avatar'))),
          avatar,
        );
        expect(find.text(profile.identity.displayName!), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${self ? 'self' : 'public'} refresh keeps identity geometry and scroll position through success and network failure',
      (tester) async {
        final profile = _scrollableProfile(self: self);
        final pendingReads = <Completer<_ProfileReadResult>>[];
        final repository = _ScriptedProfileRepository((_, call) {
          if (call == 0) return Future.value(_profileSuccess(profile));
          final read = Completer<_ProfileReadResult>();
          pendingReads.add(read);
          return read.future;
        });
        if (self) {
          await _pumpMyProfile(tester, repository: repository);
        } else {
          await _pumpPublicProfile(tester, repository: repository);
        }
        final page = find.byType(self ? MyProfilePage : UserProfilePage);
        final container = ProviderScope.containerOf(tester.element(page));
        final l10n = AppLocalizations.of(tester.element(page));
        final scrollable = _profileScrollable(tester);
        expect(scrollable.position.maxScrollExtent, greaterThan(96));
        scrollable.position.jumpTo(96);
        await tester.pump();
        final pixels = scrollable.position.pixels;
        final identity = tester.getRect(
          find.byKey(const Key('user-profile-identity')),
        );
        void expectUnchangedLayout() {
          expect(_profileScrollable(tester), same(scrollable));
          expect(scrollable.position.pixels, closeTo(pixels, 0.01));
          expect(
            tester.getRect(find.byKey(const Key('user-profile-identity'))),
            identity,
          );
          expect(find.text(profile.identity.displayName!), findsOneWidget);
          expect(
            find.byKey(const Key('user-profile-identity-skeleton')),
            findsNothing,
          );
        }

        for (final fails in [false, true]) {
          final refresh = self
              ? container.read(myUserProfileProvider.notifier).refresh()
              : container
                    .read(userProfileProvider('123456').notifier)
                    .refresh();
          await tester.pump();
          expect(
            find.byKey(const Key('user-profile-refresh-progress')),
            findsOneWidget,
          );
          expectUnchangedLayout();
          pendingReads.last.complete(
            fails
                ? const DataReadFailure(
                    kind: DataReadFailureKind.network,
                    diagnosticMessage: 'private diagnostic must not be shown',
                  )
                : _profileSuccess(profile),
          );
          await refresh;
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('user-profile-refresh-progress')),
            findsNothing,
          );
          expectUnchangedLayout();
          if (fails) {
            final error = find.text(
              l10n.profileLoadFailed(l10n.commonNetworkError),
            );
            expect(error, findsOneWidget);
            expect(
              find.text('private diagnostic must not be shown'),
              findsNothing,
            );
            expect(find.byType(SnackBar), findsOneWidget);
            expect(error.hitTestable(), findsOneWidget);
            expectUnchangedLayout();

            await tester.pump(const Duration(seconds: 5));
            await tester.pump(const Duration(milliseconds: 300));
            tester.element(page).markNeedsBuild();
            await tester.pump();
            expect(find.byType(SnackBar), findsNothing);
            expect(error, findsNothing);
            expect(repository.queries, hasLength(3));
            expectUnchangedLayout();
          }
        }
        expect(repository.queries, hasLength(3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
