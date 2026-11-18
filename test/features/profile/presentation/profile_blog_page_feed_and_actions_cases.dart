part of 'profile_blog_page_test.dart';

void _feedAndActionCases() {
  for (final source in ['list', 'detail', 'comment']) {
    for (final avatar in [false, true]) {
      testWidgets(
        '$source ${avatar ? 'avatar' : 'name'} opens the source author and preserves the article on return',
        (tester) async {
          final profiles = ProfileRepositoryFixture();
          final directory = _FakeBlogDirectoryRepository();
          final details = _FakeBlogDetailRepository(commentAuthorId: '909');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                blogAccountIdProvider.overrideWithValue('101'),
                verifiedSessionOwnerProvider.overrideWithValue((
                  uid: '101',
                  revision: 0,
                )),
                forumUserProfileRepositoryProvider.overrideWithValue(profiles),
                userBlogDirectoryRepositoryProvider.overrideWithValue(
                  directory,
                ),
                userBlogDetailRepositoryProvider.overrideWithValue(details),
                forumImageRefererProvider.overrideWithValue(
                  'https://example.test/',
                ),
              ],
              child: const LocalizedTestApp(home: ProfileBlogPage()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppPageAppBar), findsOneWidget);
          if (source != 'list') {
            await tester.tap(find.byKey(const Key('profile-blog-item-117558')));
            await tester.pumpAndSettle();
          }
          final author = source == 'comment' ? '909' : '257582';
          final target = avatar
              ? find
                    .descendant(
                      of: find.byWidgetPredicate(
                        (widget) =>
                            widget is ProfileUserLink &&
                            widget.userId == author,
                      ),
                      matching: find.byType(ForumCachedAvatar),
                    )
                    .first
              : find.byKey(
                  Key(switch (source) {
                    'list' => 'blog-list-author-117558',
                    'detail' => 'blog-detail-author',
                    _ => 'blog-comment-author-646846',
                  }),
                );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(profiles.queries, isEmpty);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(find.byType(UserProfilePage), findsOneWidget);
          expect(profiles.queries.single.userId, author);
          await tapBack(tester, within: find.byType(UserProfilePage));
          expect(directory.queries, hasLength(1));
          expect(details.queries, hasLength(source == 'list' ? 0 : 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'publishing opens the verified article and defers the feed refresh',
    (tester) async {
      final directory = _FakeBlogDirectoryRepository();
      final details = _FakeBlogDetailRepository(title: 'Newly published');
      final operations = BlogOperationFixture(autoPrepare: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            blogAccountIdProvider.overrideWithValue('101'),
            blogDraftRepositoryProvider.overrideWithValue(
              MemoryBlogDraftRepository(),
            ),
            userBlogDirectoryRepositoryProvider.overrideWithValue(directory),
            userBlogDetailRepositoryProvider.overrideWithValue(details),
            userBlogOperationsProvider.overrideWithValue(operations),
            forumImageRefererProvider.overrideWithValue(
              'https://example.test/',
            ),
          ],
          child: const LocalizedTestApp(home: ProfileBlogPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blog-write')));
      await tester.pumpAndSettle();
      expect(find.byType(BlogEditorPage), findsOneWidget);
      expect(
        operations.editorPreparations.single.target.action,
        UserBlogAction.create,
      );
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'Newly published',
      );
      tester
          .widget<QuillEditor>(find.byType(QuillEditor))
          .controller
          .replaceText(
            0,
            0,
            'New body',
            const TextSelection.collapsed(offset: 8),
          );
      await tester.pump();
      await tester.tap(find.byKey(const Key('blog-editor-submit')));
      await tester.pump();
      operations.saved();
      await tester.pumpAndSettle();
      final page = tester.widget<ProfileBlogDetailPage>(
        find.byType(ProfileBlogDetailPage),
      );
      expect(page.blogId, '12');
      expect(page.ownerUserId, '101');
      expect(page.initialTitle, 'Newly published');
      expect(details.queries.single.blogId, '12');
      expect(directory.queries, hasLength(1));
      await tapBack(tester, within: find.byType(ProfileBlogDetailPage));
      expect(directory.queries, hasLength(2));
      expect(directory.policies.last, CacheLoadPolicy.networkFirst);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fromDetail in [false, true]) {
    testWidgets(
      'editing from ${fromDetail ? 'detail' : 'list'} refreshes existing views after saving',
      (tester) async {
        final directory = _FakeBlogDirectoryRepository(
          blogActions: {UserBlogAction.edit},
        );
        final details = _FakeBlogDetailRepository(
          blogActions: {UserBlogAction.edit},
        );
        final operations = BlogOperationFixture(autoPrepare: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              blogAccountIdProvider.overrideWithValue('257582'),
              userBlogDirectoryRepositoryProvider.overrideWithValue(directory),
              userBlogDetailRepositoryProvider.overrideWithValue(details),
              userBlogOperationsProvider.overrideWithValue(operations),
              forumImageRefererProvider.overrideWithValue(
                'https://example.test/',
              ),
            ],
            child: const LocalizedTestApp(home: ProfileBlogPage()),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ProfileBlogPage)),
        );
        if (fromDetail) {
          await tester.tap(find.byKey(const Key('profile-blog-item-117558')));
          await tester.pumpAndSettle();
        }
        if (fromDetail) {
          await tester.longPress(find.byKey(const Key('blog-detail-card')));
        } else {
          await tester.tap(find.byKey(const Key('blog-list-actions-117558')));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileBlogEdit));
        await tester.pumpAndSettle();
        expect(find.byType(BlogEditorPage), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('blog-editor-subject')),
          'Changed title',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('blog-editor-submit')));
        await tester.pump();
        details.title = 'Changed title';
        operations.saved();
        await tester.pumpAndSettle();
        if (fromDetail) {
          expect(find.byType(ProfileBlogDetailPage), findsOneWidget);
          expect(details.queries, hasLength(2));
          expect(find.text('Changed title'), findsWidgets);
          await tapBack(tester, within: find.byType(ProfileBlogDetailPage));
        }
        expect(find.byType(ProfileBlogPage), findsOneWidget);
        expect(directory.queries, hasLength(2));
        expect(
          operations.editorSubmissions.single.input.subject,
          'Changed title',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fromDetail in [false, true]) {
    for (final action in blogManagementActions) {
      for (final applied in [false, true]) {
        testWidgets(
          '$action from ${fromDetail ? 'detail' : 'list'} updates only when applied=$applied',
          (tester) async {
            final directory = _FakeBlogDirectoryRepository(
              blogActions: {action},
            );
            final details = _FakeBlogDetailRepository(blogActions: {action});
            final operations = BlogOperationFixture(autoPrepare: true);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  blogAccountIdProvider.overrideWithValue('257582'),
                  userBlogDirectoryRepositoryProvider.overrideWithValue(
                    directory,
                  ),
                  userBlogDetailRepositoryProvider.overrideWithValue(details),
                  userBlogOperationsProvider.overrideWithValue(operations),
                  forumImageRefererProvider.overrideWithValue(
                    'https://example.test/',
                  ),
                ],
                child: const LocalizedTestApp(home: ProfileBlogPage()),
              ),
            );
            await tester.pumpAndSettle();
            final l10n = AppLocalizations.of(
              tester.element(find.byType(ProfileBlogPage)),
            );
            if (fromDetail) {
              await tester.tap(
                find.byKey(const Key('profile-blog-item-117558')),
              );
              await tester.pumpAndSettle();
            }
            if (fromDetail) {
              await tester.longPress(find.byKey(const Key('blog-detail-card')));
            } else {
              await tester.tap(
                find.byKey(const Key('blog-list-actions-117558')),
              );
            }
            await tester.pumpAndSettle();
            for (final other in blogManagementActions.where(
              (other) => other != action,
            )) {
              expect(find.text(blogActionLabel(l10n, other)), findsNothing);
            }
            await tester.tap(find.text(blogActionLabel(l10n, action)));
            await tester.pumpAndSettle();
            expect(find.byType(BlogActionPage), findsOneWidget);
            expect(operations.preparations.single.target.blogId, '117558');
            expect(operations.preparations.single.target.ownerUserId, '257582');
            expect(operations.submissions, isEmpty);
            await tester.tap(find.byKey(const Key('blog-action-submit')));
            await tester.pump();
            expect(directory.queries, hasLength(1));
            expect(details.queries, hasLength(fromDetail ? 1 : 0));
            if (applied) {
              directory.removed = action == UserBlogAction.delete;
              operations.applied();
            } else {
              operations.submissions.last.result.complete(
                const DataCommandOutcomeUnknown(blogActionWriteFailure),
              );
            }
            await tester.pumpAndSettle();
            if (!applied) {
              expect(find.byType(BlogActionPage), findsOneWidget);
              expect(find.byKey(const Key('blog-action-retry')), findsNothing);
              await tapBack(tester, within: find.byType(BlogActionPage));
            }
            if (fromDetail && !(applied && action == UserBlogAction.delete)) {
              expect(find.byType(ProfileBlogDetailPage), findsOneWidget);
              expect(details.queries, hasLength(applied ? 2 : 1));
              await tapBack(tester, within: find.byType(ProfileBlogDetailPage));
            }
            expect(find.byType(ProfileBlogPage), findsOneWidget);
            expect(directory.queries, hasLength(applied ? 2 : 1));
            if (applied) {
              expect(directory.policies.last, CacheLoadPolicy.networkFirst);
            }
            if (applied && action == UserBlogAction.delete) {
              expect(
                find.byKey(const Key('profile-blog-item-117558')),
                findsNothing,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final action in UserBlogCommentAction.values) {
    for (final applied in [true, false]) {
      testWidgets('$action refreshes comment data only when applied=$applied', (
        tester,
      ) async {
        final details = _FakeBlogDetailRepository(commentActions: {action});
        final comments = BlogCommentFixture(autoPrepare: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              blogAccountIdProvider.overrideWithValue('101'),
              userBlogDetailRepositoryProvider.overrideWithValue(details),
              userBlogCommentServiceProvider.overrideWithValue(comments),
              forumImageRefererProvider.overrideWithValue(
                'https://bbs.yamibo.com/',
              ),
            ],
            child: const LocalizedTestApp(
              home: ProfileBlogDetailPage(ownerUserId: '202', blogId: '11'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ProfileBlogDetailPage)),
        );
        if (action == UserBlogCommentAction.add) {
          await tester.tap(find.byKey(const Key('blog-detail-reply')));
        } else {
          final menu = find.byKey(const Key('profile-blog-comment-646846'));
          await tester.scrollUntilVisible(
            menu,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.longPress(menu);
          await tester.pumpAndSettle();
          for (final other in UserBlogCommentAction.values) {
            if (other != action && other != UserBlogCommentAction.add) {
              expect(
                find.text(blogCommentActionLabel(l10n, other)),
                findsNothing,
              );
            }
          }
          await tester.tap(find.text(blogCommentActionLabel(l10n, action)));
        }
        await tester.pumpAndSettle();
        expect(find.byType(BlogCommentPage), findsOneWidget);
        expect(
          comments.preparations.single.target,
          UserBlogCommentTarget(
            actorUserId: '101',
            ownerUserId: '202',
            blogId: '11',
            action: action,
            commentId: action == UserBlogCommentAction.add ? null : '646846',
          ),
        );
        if (action != UserBlogCommentAction.delete) {
          final editor = tester.widget<QuillEditor>(
            find.byKey(const Key('blog-comment-input')),
          );
          editor.controller.replaceText(
            0,
            editor.controller.document.length - 1,
            '实际输入内容',
            const TextSelection.collapsed(offset: 6),
          );
        }
        await tester.pump();
        await tester.tap(find.byKey(const Key('blog-comment-submit')));
        await tester.pump();
        expect(details.queries, hasLength(1));
        if (applied) {
          comments.applied();
          await tester.pumpAndSettle();
          expect(details.queries, hasLength(2));
          expect(details.policies.last, CacheLoadPolicy.networkFirst);
          expect(
            details.queries.last.lastCommentPage,
            action == UserBlogCommentAction.add ||
                action == UserBlogCommentAction.reply,
          );
        } else {
          comments.submissions.single.result.complete(
            const DataCommandOutcomeUnknown(blogCommentWriteFailure),
          );
          await tester.pumpAndSettle();
          await tapBack(tester, within: find.byType(BlogCommentPage));
          await tester.tap(find.byKey(const Key('blog-comment-leave')));
          await tester.pumpAndSettle();
          expect(details.queries, hasLength(1));
          // An inconclusive write leaves the article untouched, but the
          // user must still be able to check it by pulling a short page.
          await tester.drag(
            find.byKey(const Key('profile-blog-detail')),
            const Offset(0, 400),
          );
          await tester.pumpAndSettle();
          expect(details.queries, hasLength(2));
          expect(details.policies.last, CacheLoadPolicy.networkFirst);
        }
        expect(find.byType(BlogCommentPage), findsNothing);
        expect(find.byType(ProfileBlogDetailPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('tabs remain usable while the first request is pending', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FakeBlogDirectoryRepository(gate: gate);
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
      settle: false,
    );
    await tester.pump();
    expect(find.byKey(const Key('profile-blog-view-tabs')), findsOneWidget);
    await tester.tap(find.text('我的日志'));
    await tester.pump();
    expect(repository.queries.map((q) => q.scope), [
      UserBlogFeedScope.public,
      UserBlogFeedScope.self,
    ]);
    expect(repository.cancellations.first!.isCancelled, isTrue);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('一种体验'), findsNothing);
    expect(find.text('还没有相关的日志'), findsOneWidget);
  });

  testWidgets('swiping selects lazy feeds and retains the public sort', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository();
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileBlogPage)),
    );
    expect(repository.queries.map((query) => query.scope), [
      UserBlogFeedScope.public,
    ]);

    await tester.tap(find.text(l10n.profileBlogRecommendedShort));
    await tester.pumpAndSettle();
    final publicRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).hitTestable())
        .onRefresh;
    await _swipeToScope(tester, UserBlogFeedScope.self);
    expect(_blogTabs(tester).controller!.index, UserBlogFeedScope.self.index);
    expect(repository.queries.last.scope, UserBlogFeedScope.self);
    expect(repository.queries.last.order, isNull);
    expect(
      find.text(l10n.profileBlogRecommendedShort).hitTestable(),
      findsNothing,
    );
    expect(find.text(l10n.profileBlogEmpty).hitTestable(), findsOneWidget);
    await publicRefresh();
    await tester.pumpAndSettle();
    expect(repository.queries, hasLength(3));

    await _swipeToScope(tester, UserBlogFeedScope.friends);
    expect(
      _blogTabs(tester).controller!.index,
      UserBlogFeedScope.friends.index,
    );
    expect(repository.queries.map((query) => query.scope), [
      UserBlogFeedScope.public,
      UserBlogFeedScope.public,
      UserBlogFeedScope.self,
      UserBlogFeedScope.friends,
    ]);

    await _swipeToScope(tester, UserBlogFeedScope.public);
    expect(_blogTabs(tester).controller!.index, UserBlogFeedScope.public.index);
    expect(repository.queries, hasLength(4));
    expect(find.text('我们小区的公共交通极其不便利').hitTestable(), findsOneWidget);
    await tester.tap(find.text(l10n.profileBlogLatestShort));
    await tester.pumpAndSettle();
    expect(repository.queries.last.order, UserBlogOrder.latest);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping cancels a pending feed and ignores its late result', (
    tester,
  ) async {
    final publicGate = Completer<void>();
    final repository = _FakeBlogDirectoryRepository(
      scopeGates: {UserBlogFeedScope.public: publicGate},
    );
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
      settle: false,
    );
    await tester.pump();
    expect(repository.queries.map((query) => query.scope), [
      UserBlogFeedScope.public,
    ]);

    await _swipeToScope(tester, UserBlogFeedScope.self);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileBlogPage)),
    );
    expect(repository.queries.map((query) => query.scope), [
      UserBlogFeedScope.public,
      UserBlogFeedScope.self,
    ]);
    expect(repository.cancellations.first!.isCancelled, isTrue);
    expect(find.text(l10n.profileBlogEmpty).hitTestable(), findsOneWidget);

    publicGate.complete();
    await tester.pumpAndSettle();
    expect(_blogTabs(tester).controller!.index, UserBlogFeedScope.self.index);
    expect(find.text('一种体验').hitTestable(), findsNothing);
    expect(find.text(l10n.profileBlogEmpty).hitTestable(), findsOneWidget);
    expect(repository.queries, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an author feed keeps its fixed scope when dragged sideways', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository();
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
      page: const ProfileBlogPage(ownerUserId: '909'),
    );
    expect(find.byKey(const Key('profile-blog-view-tabs')), findsNothing);
    expect(find.byType(TabBarView), findsNothing);
    expect(repository.queries.single.scope, UserBlogFeedScope.self);
    expect(repository.queries.single.ownerUserId, '909');

    await tester.drag(find.byType(ProfileBlogPage), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(repository.queries, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from a pending article cancels its read', (
    tester,
  ) async {
    final gate = Completer<void>();
    final details = _FakeBlogDetailRepository(gate: gate);
    await _pumpBlogPage(
      tester,
      directoryRepository: _FakeBlogDirectoryRepository(),
      detailRepository: details,
    );
    await tester.tap(find.text('一种体验'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(ProfileBlogDetailPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ProfileBlogDetailPage),
        matching: find.text('一种体验'),
      ),
      findsOneWidget,
    );
    await tapBack(tester, within: find.byType(ProfileBlogDetailPage));
    expect(details.cancellations.single!.isCancelled, isTrue);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileBlogDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping restores an independent scroll offset for each feed', (
    tester,
  ) async {
    final repository = _FakeBlogDirectoryRepository(
      longList: true,
      longListScopes: {UserBlogFeedScope.public, UserBlogFeedScope.self},
    );
    await _pumpBlogPage(
      tester,
      directoryRepository: repository,
      detailRepository: _FakeBlogDetailRepository(),
    );
    final list = find.byKey(const Key('profile-blog-list')).hitTestable();
    await tester.drag(list, const Offset(0, -650));
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(
          find
              .descendant(of: list, matching: find.byType(Scrollable))
              .hitTestable(),
        )
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(400));
    await _swipeToScope(tester, UserBlogFeedScope.self);
    expect(offset(), 0);
    await tester.drag(list, const Offset(0, -950));
    await tester.pumpAndSettle();
    final selfOffset = offset();
    expect(selfOffset, greaterThan(before + 100));

    await _swipeToScope(tester, UserBlogFeedScope.public);
    expect(offset(), closeTo(before, 1));
    await _swipeToScope(tester, UserBlogFeedScope.self);
    expect(offset(), closeTo(selfOffset, 1));
    expect(repository.queries, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'two routes with the same feed use separate controller instances',
    (tester) async {
      final repository = _FakeBlogDirectoryRepository();
      await _pumpBlogPage(
        tester,
        directoryRepository: repository,
        detailRepository: _FakeBlogDetailRepository(),
      );
      final context = tester.element(find.text('随便看看'));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileBlogPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.queries, hasLength(2));
      await tapBack(tester, within: find.byType(ProfileBlogPage).last);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(repository.queries, hasLength(3));
      expect(find.text('一种体验'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
