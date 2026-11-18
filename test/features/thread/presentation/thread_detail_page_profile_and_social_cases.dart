part of 'thread_detail_page_test.dart';

void _profileAndSocialCases() {
  testWidgets('opens user profile from post author name', (tester) async {
    final webViewDriver = _FakeForumWebViewDriver();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '509957',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        forumWebViewDriverFactory: () => webViewDriver,
        additionalOverrides: [
          verifiedSessionOwnerProvider.overrideWithValue(null),
          forumUserProfileRepositoryProvider.overrideWithValue(
            ProfileRepositoryFixture(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('alice').first);
    await tester.pumpAndSettle();

    expect(find.byType(UserProfilePage), findsOneWidget);
    expect(
      tester.widget<UserProfilePage>(find.byType(UserProfilePage)).uid,
      '509957',
    );
    expect(webViewDriver.bootstrapConfig, isNull);
    expect(webViewDriver.loadedUris, isEmpty);
  });

  testWidgets('opens user profile from post author avatar', (tester) async {
    final webViewDriver = _FakeForumWebViewDriver();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '509957',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        forumWebViewDriverFactory: () => webViewDriver,
        additionalOverrides: [
          verifiedSessionOwnerProvider.overrideWithValue(null),
          forumUserProfileRepositoryProvider.overrideWithValue(
            ProfileRepositoryFixture(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-author-avatar-p1')));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfilePage), findsOneWidget);
    expect(
      tester.widget<UserProfilePage>(find.byType(UserProfilePage)).uid,
      '509957',
    );
    expect(webViewDriver.bootstrapConfig, isNull);
  });

  testWidgets('opens user profile from comment author name', (tester) async {
    final webViewDriver = _FakeForumWebViewDriver();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'commenter',
                  authorId: '777',
                  authorUrl: 'https://bbs.yamibo.com/home.php?mod=space&uid=777&mobile=2',
                  avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/00/07/77_avatar_small.jpg',
                  message: '点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        forumWebViewDriverFactory: () => webViewDriver,
        additionalOverrides: [
          verifiedSessionOwnerProvider.overrideWithValue(null),
          forumUserProfileRepositoryProvider.overrideWithValue(
            ProfileRepositoryFixture(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-comment-author-name-777')));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfilePage), findsOneWidget);
    expect(
      tester.widget<UserProfilePage>(find.byType(UserProfilePage)).uid,
      '777',
    );
    expect(webViewDriver.bootstrapConfig, isNull);
    expect(webViewDriver.loadedUris, isEmpty);
  });

  testWidgets('opens user profile from comment author avatar', (tester) async {
    final webViewDriver = _FakeForumWebViewDriver();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'commenter',
                  authorId: '778',
                  avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/00/07/78_avatar_small.jpg',
                  message: '点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        forumWebViewDriverFactory: () => webViewDriver,
        additionalOverrides: [
          verifiedSessionOwnerProvider.overrideWithValue(null),
          forumUserProfileRepositoryProvider.overrideWithValue(
            ProfileRepositoryFixture(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-comment-author-avatar-778')));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfilePage), findsOneWidget);
    expect(
      tester.widget<UserProfilePage>(find.byType(UserProfilePage)).uid,
      '778',
    );
    expect(webViewDriver.bootstrapConfig, isNull);
  });

  testWidgets('opens comment profile from author url uid when id is empty', (
    tester,
  ) async {
    final webViewDriver = _FakeForumWebViewDriver();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'url-user',
                  authorId: '',
                  authorUrl: 'home.php?mod=space&uid=888&mobile=2',
                  message: '点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        forumWebViewDriverFactory: () => webViewDriver,
        additionalOverrides: [
          verifiedSessionOwnerProvider.overrideWithValue(null),
          forumUserProfileRepositoryProvider.overrideWithValue(
            ProfileRepositoryFixture(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('url-user'));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfilePage), findsOneWidget);
    expect(
      tester.widget<UserProfilePage>(find.byType(UserProfilePage)).uid,
      '888',
    );
    expect(webViewDriver.bootstrapConfig, isNull);
  });

  testWidgets('shows snackbar when comment author uid is missing', (
    tester,
  ) async {
    final webViewDriver = _FakeForumWebViewDriver();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'missing-user',
                  message: '点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, forumWebViewDriverFactory: () => webViewDriver),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('missing-user'));
    await tester.pump();

    expect(find.text('用户 UID 缺失'), findsOneWidget);
    expect(find.byType(ForumWebViewPage), findsNothing);
    expect(webViewDriver.loadedUris, isEmpty);
  });

  testWidgets('default comment avatar uses the local default asset', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'commenter',
                  authorId: '779',
                  avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/noavatar.svg',
                  message: '点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final avatar = find.byKey(const Key('thread-comment-author-avatar-779'));
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
  });

  testWidgets('comment avatar uses avatar cache request baseline', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
              comments: const <ThreadPostCommentEntry>[
                ThreadPostCommentEntry(
                  author: 'commenter',
                  authorId: '780',
                  avatarUrl: 'https://bbs.yamibo.com/uc_server/data/avatar/000/00/07/80_avatar_small.jpg',
                  message: '点评内容',
                  dateline: 'today',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(repository, imageCacheService: cacheService),
    );
    await tester.pump();
    await tester.pump();

    final cachedAvatar = tester.widget<CachedLibraryImage>(
      find.descendant(
        of: find.byKey(const Key('thread-comment-author-avatar-780')),
        matching: find.byType(CachedLibraryImage),
      ),
    );

    expect(cachedAvatar.request?.role, ImageCacheRole.avatar);
    expect(cachedAvatar.request?.ownerType, ImageCacheOwnerType.thread);
    expect(cachedAvatar.request?.ownerId, '780');
    expect(
      cachedAvatar.request?.sourceUrl,
      'https://bbs.yamibo.com/uc_server/data/avatar/000/00/07/80_avatar_small.jpg',
    );
    expect(
      cacheService.requests.where(
        (request) => request.role == ImageCacheRole.avatar,
      ),
      isNotEmpty,
    );
  });

  testWidgets('favorites thread from app bar action', (tester) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });
    final favoriteActionService = _FakeThreadFavoriteActionService();

    await tester.pumpWidget(
      _buildTestApp(repository, favoriteActionService: favoriteActionService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-detail-favorite-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(favoriteActionService.called, isTrue);
    expect(favoriteActionService.lastTid, '100');
    expect(find.byIcon(Icons.star), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadDetailPage)),
    );
    expect(find.text(l10n.threadFavoriteParseQueued), findsOneWidget);
  });

  testWidgets('opens reply composer and submits reply via shared composer', (
    tester,
  ) async {
    final repository = _FakeThreadRepository((tid, page) async {
      return ApiSuccess(
        ThreadDetailData(
          tid: tid,
          fid: '33',
          subject: '测试主题',
          author: 'alice',
          replies: 0,
          views: 1,
          currentPage: 1,
          perPage: 20,
          posts: [
            ThreadPost(
              pid: 'p1',
              author: 'alice',
              authorId: '1',
              message: '<p>正文</p>',
              number: 1,
              isFirst: true,
              dateline: 'today',
            ),
          ],
        ),
      );
    });
    final replyRepo = _FakeThreadReplyCommand();
    final invalidationService = _FakeNativePageCacheInvalidationService();

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        replyRepository: replyRepo,
        pageCacheInvalidationService: invalidationService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('thread-reply-submit-button')), findsNothing);
    expect(find.byKey(const Key('thread-reply-input')), findsNothing);

    await tester.tap(
      find.byKey(const Key('thread-detail-appbar-reply-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reply-composer-quill-editor')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reply-composer-source-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reply-composer-message-input')),
      '这是测试回复',
    );
    await tester.pump();
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('reply-composer-send-button')),
    );
    expect(sendButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    expect(replyRepo.called, isTrue);
    expect(replyRepo.lastSubmission?.message, '这是测试回复');
    expect(invalidationService.invalidatedThreadIds, <String>['100']);
    expect(find.text('回复成功'), findsOneWidget);
  });
}
