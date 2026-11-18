part of 'forum_display_page_test.dart';

void _filterCases() {
  testWidgets('local block rules hide matching thread cards', (tester) async {
    _seedBlockedThreads(const <String, String>{'000101': '已屏蔽的帖子'});
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 2,
          threads: [
            _blockedTestThread(tid: '101', subject: '已屏蔽的帖子'),
            _blockedTestThread(tid: '102', subject: '正常帖子'),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-101')), findsNothing);
    expect(find.byKey(const Key('forum-thread-102')), findsOneWidget);
  });

  testWidgets('blocking a card hides it immediately and undo restores it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 1,
          threads: [_blockedTestThread(tid: '201', subject: '要屏蔽的帖子')],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: const SizedBox(
              width: 280,
              child: ForumDisplayPage(fid: '2', title: '公告区'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('forum-thread-201'));
    final menu = find.byKey(const Key('thread-block-menu-201'));
    final avatar = find.byKey(const Key('forum-thread-summary-avatar-201'));
    expect(card, findsOneWidget);
    expect(
      tester.getBottomRight(menu).dy,
      lessThan(tester.getTopLeft(find.text('要屏蔽的帖子')).dy),
    );
    expect(tester.getRect(menu).overlaps(tester.getRect(avatar)), isFalse);
    expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    final l10n = AppLocalizations.of(tester.element(card));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thread-block-action-201')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-201')), findsNothing);
    expect(find.text(l10n.contentFilterUndo), findsOneWidget);

    await tester.tap(find.text(l10n.contentFilterUndo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-201')), findsOneWidget);
  });

  testWidgets('web blacklist hides threads when hiding is enabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'content_filter.web_blacklist.snapshot.v1': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'accounts': <String, Object?>{
          '11': <String, Object?>{
            'lastSuccessAt': 1000,
            'members': <Object?>[
              <String, Object?>{'userId': '42', 'username': 'Blocked'},
            ],
          },
        },
      }),
    });
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 2,
          threads: [
            _blockedTestThread(tid: '301', subject: '黑名单作者', uid: '42'),
            _blockedTestThread(tid: '302', subject: '正常作者', uid: '43'),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        extraOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          hideBlacklistedThreadsProvider.overrideWithValue(true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-301')), findsNothing);
    expect(find.byKey(const Key('forum-thread-302')), findsOneWidget);
  });

  testWidgets('turning hiding off reveals blacklisted threads in place', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'blacklist.hide_initiated_threads.v1': true,
      'content_filter.web_blacklist.snapshot.v1': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'accounts': <String, Object?>{
          '11': <String, Object?>{
            'lastSuccessAt': 1000,
            'members': <Object?>[
              <String, Object?>{'userId': '42', 'username': 'Blocked'},
            ],
          },
        },
      }),
    });
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 2,
          threads: [
            _blockedTestThread(tid: '301', subject: '黑名单作者', uid: '42'),
            _blockedTestThread(tid: '302', subject: '正常作者', uid: '43'),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        extraOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forum-thread-301')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ForumDisplayPage)),
    );
    expect(
      await container
          .read(blacklistDisplayPreferencesControllerProvider.notifier)
          .setHideThreadsStartedByBlacklistedUsers(false),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-301')), findsOneWidget);
    expect(find.byKey(const Key('forum-thread-302')), findsOneWidget);
  });

  testWidgets('blacklisted threads stay visible by default', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'content_filter.web_blacklist.snapshot.v1': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'accounts': <String, Object?>{
          '11': <String, Object?>{
            'lastSuccessAt': 1000,
            'members': <Object?>[
              <String, Object?>{'userId': '42', 'username': 'Blocked'},
            ],
          },
        },
      }),
    });
    final sessionStore = YamiboSessionStore()
      ..saveExtracted(
        YamiboSessionSnapshot(
          isLoggedIn: true,
          uid: '11',
          username: 'Reader',
          formhash: '',
          updatedAt: DateTime(2026, 1, 1),
          source: 'test',
        ),
      );
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 2,
          threads: [
            _blockedTestThread(tid: '301', subject: '黑名单作者', uid: '42'),
            _blockedTestThread(tid: '302', subject: '正常作者', uid: '43'),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        extraOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-301')), findsOneWidget);
    expect(find.byKey(const Key('forum-thread-302')), findsOneWidget);
  });

  testWidgets('a fully filtered page explains the rules and keeps paging', (
    tester,
  ) async {
    _seedBlockedThreads(const <String, String>{'101': '第一条', '102': '第二条'});
    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          page: 1,
          total: 4,
          lastPage: 2,
          threads: [
            _blockedTestThread(tid: '101', subject: '第一条'),
            _blockedTestThread(tid: '102', subject: '第二条'),
          ],
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ForumDisplayPage)),
    );
    expect(find.text(l10n.contentFilterHiddenOnPage), findsOneWidget);
    expect(find.text(l10n.contentFilterHiddenOnPageHint), findsOneWidget);
    expect(
      find.byKey(const Key('forum-display-load-more-button')),
      findsOneWidget,
    );
  });
}
