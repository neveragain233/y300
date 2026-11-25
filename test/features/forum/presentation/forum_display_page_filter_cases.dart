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

  testWidgets(
    'pinned topEntries and sticky threads are never hidden by local filters',
    (tester) async {
      _seedBlockedThreads(const <String, String>{'901': '置顶公告', '902': '置顶帖'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'content_filter.blocked_keywords.v1',
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': <Object?>[
            <String, Object?>{
              'id': 'kw1',
              'keyword': '剧透',
              'scope': 'includeBody',
              'kind': 'block',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      );
      await prefs.setBool(
        'content_filter.hide_blocked_keyword_threads_completely.v1',
        true,
      );

      final repository = _FakeForumDisplayRepository((fid, page, query) async {
        return ApiSuccess(
          _displayData(
            page: 1,
            total: 2,
            topEntries: const <ForumDisplayTopEntry>[
              ForumDisplayTopEntry(
                title: '剧透公告条目',
                url: 'https://bbs.example.test/thread-901-1-1.html',
                tid: '901',
                badgeLabel: '置顶',
              ),
            ],
            threads: [
              ForumThreadSummary(
                tid: '902',
                subject: '包含剧透的置顶帖',
                author: 'mod',
                uid: '50',
                replies: 0,
                views: 10,
                dateline: 'today',
                badges: const <ForumThreadBadge>[
                  ForumThreadBadge(
                    kind: ForumThreadBadgeKind.sticky,
                    sourceLabel: '置顶',
                  ),
                ],
              ),
              _blockedTestThread(tid: '903', subject: '普通剧透帖'),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-thread-902')), findsOneWidget);
      expect(find.byKey(const Key('forum-thread-903')), findsNothing);

      await tester.tap(
        find.byKey(const Key('forum-display-top-entries-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('剧透公告条目'), findsOneWidget);
    },
  );

  testWidgets('subforum exempts all threads inside from local filters', (
    tester,
  ) async {
    _seedBlockedThreads(const <String, String>{'801': '子版块屏蔽帖'});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'content_filter.blocked_keywords.v1',
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'keywords': <Object?>[
          <String, Object?>{
            'id': 'kw1',
            'keyword': '剧透',
            'scope': 'includeBody',
            'kind': 'block',
            'matchType': 'plain',
            'enabled': true,
            'createdAt': 1000,
            'updatedAt': 1000,
          },
        ],
      }),
    );

    final repository = _FakeForumDisplayRepository((fid, page, query) async {
      return ApiSuccess(
        _displayData(
          fid: '99',
          page: 1,
          total: 2,
          threads: [
            _blockedTestThread(tid: '801', subject: '子版块屏蔽帖'),
            _blockedTestThread(tid: '802', subject: '子版块剧透帖'),
          ],
        ),
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        home: const ForumDisplayPage(fid: '99', title: '子版块', isSubForum: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-thread-801')), findsOneWidget);
    expect(find.byKey(const Key('forum-thread-802')), findsOneWidget);
  });

  testWidgets(
    'eink mode shows corner paging buttons on ForumDisplayPage and hides when disabled',
    (tester) async {
      final repository = _FakeForumDisplayRepository((fid, page, query) async {
        return ApiSuccess(
          _displayData(
            page: 1,
            total: 30,
            threads: [
              for (var i = 1; i <= 25; i++)
                _blockedTestThread(tid: '$i', subject: '帖子 $i'),
            ],
          ),
        );
      });

      await tester.pumpWidget(
        EInkModeScope(enabled: true, child: _buildTestApp(repository)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('eink-corner-page-down')), findsOneWidget);
      expect(find.byKey(const Key('eink-corner-page-up')), findsOneWidget);

      await tester.pumpWidget(
        EInkModeScope(enabled: false, child: _buildTestApp(repository)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('eink-corner-page-down')), findsNothing);
      expect(find.byKey(const Key('eink-corner-page-up')), findsNothing);
    },
  );

  testWidgets(
    'revealed keyword-filtered thread card supports quick Add to Whitelist',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'content_filter.blocked_keywords.v1',
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keywords': <Object?>[
            <String, Object?>{
              'id': 'kw1',
              'keyword': '剧透',
              'scope': 'includeBody',
              'kind': 'block',
              'matchType': 'plain',
              'enabled': true,
              'createdAt': 1000,
              'updatedAt': 1000,
            },
          ],
        }),
      );

      final repository = _FakeForumDisplayRepository((fid, page, query) async {
        return ApiSuccess(
          _displayData(
            page: 1,
            total: 1,
            threads: [
              _blockedTestThread(tid: '701', subject: '剧透预警贴', uid: '505'),
            ],
          ),
        );
      });

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('keyword-filtered-thread-reveal-701')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('keyword-filtered-thread-whitelist-701')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('keyword-filtered-thread-whitelist-701')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('keyword-filtered-thread-whitelist-701')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('keyword-filtered-thread-hide-701')),
        findsNothing,
      );
      expect(find.byKey(const Key('forum-thread-701')), findsOneWidget);
    },
  );
}
