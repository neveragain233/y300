part of 'thread_detail_page_test.dart';

void _blacklistCases() {
  testWidgets(
    'blacklisted topic author prompts once and other blacklisted floors collapse',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.web_blacklist.snapshot.v1': jsonEncode(
          <String, Object?>{
            'schemaVersion': 1,
            'accounts': <String, Object?>{
              '11': <String, Object?>{
                'lastSuccessAt': 1000,
                'members': <Object?>[
                  <String, Object?>{'userId': '42', 'username': 'Blocked'},
                  <String, Object?>{'userId': '44', 'username': 'Muted'},
                ],
              },
            },
          },
        ),
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
      final repository = _FakeThreadRepository(
        (String tid, int page) async => ApiSuccess(
          _threadDetailData(
            tid: tid,
            posts: [
              _postWithAuthor(
                pid: 'blacklist-p1',
                author: 'Blocked',
                authorId: '42',
                number: 1,
                isFirst: true,
              ),
              _postWithAuthor(
                pid: 'blacklist-p2',
                author: 'Muted',
                authorId: '44',
                number: 2,
              ),
              _postWithAuthor(
                pid: 'blacklist-p3',
                author: 'Normal',
                authorId: '43',
                number: 3,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          repository,
          additionalOverrides: [
            yamiboSessionStoreProvider.overrideWithValue(sessionStore),
            hideBlacklistedThreadsProvider.overrideWithValue(true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blacklist-author-gate')), findsOneWidget);
      expect(
        find.byKey(const Key('thread-post-card-blacklist-p1')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('blacklist-author-view-once-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blacklist-author-gate')), findsNothing);
      expect(
        find.byKey(const Key('thread-post-card-blacklist-p1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread-blacklisted-post-blacklist-p2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('thread-post-card-blacklist-p2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('thread-post-card-blacklist-p3')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-blacklisted-post-blacklist-p2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('thread-blacklisted-expand-blacklist-p2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('thread-blacklisted-post-blacklist-p2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('thread-post-card-blacklist-p2')),
        findsOneWidget,
      );
    },
  );

  testWidgets('blacklisted threads render with collapsed floors by default', (
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
              <String, Object?>{'userId': '44', 'username': 'Muted'},
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
    final repository = _FakeThreadRepository(
      (String tid, int page) async => ApiSuccess(
        _threadDetailData(
          tid: tid,
          posts: [
            _postWithAuthor(
              pid: 'blacklist-default-p1',
              author: 'Blocked',
              authorId: '42',
              number: 1,
              isFirst: true,
            ),
            _postWithAuthor(
              pid: 'blacklist-default-p2',
              author: 'Muted',
              authorId: '44',
              number: 2,
            ),
            _postWithAuthor(
              pid: 'blacklist-default-p3',
              author: 'Normal',
              authorId: '43',
              number: 3,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository,
        additionalOverrides: [
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('blacklist-author-gate')), findsNothing);
    expect(
      find.byKey(const Key('thread-blacklisted-post-blacklist-default-p1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('thread-post-card-blacklist-default-p1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('thread-filtered-tail-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('thread-blacklisted-post-blacklist-default-p2')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('thread-post-card-blacklist-default-p3')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('thread-blacklisted-expand-blacklist-default-p1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('thread-post-card-blacklist-default-p1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('thread-blacklisted-post-blacklist-default-p2')),
      findsOneWidget,
    );
  });

  testWidgets(
    'blocked replies from earlier pages collect at the end of the last page',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_filter.web_blacklist.snapshot.v1': jsonEncode(
          <String, Object?>{
            'schemaVersion': 1,
            'accounts': <String, Object?>{
              '11': <String, Object?>{
                'lastSuccessAt': 1000,
                'members': <Object?>[
                  <String, Object?>{'userId': '44', 'username': 'Muted'},
                ],
              },
            },
          },
        ),
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
      final requests = <int>[];
      final repository = _FakeThreadRepository((tid, page, query) async {
        requests.add(page);
        return ApiSuccess(
          page == 2
              ? _threadDetailData(
                  tid: tid,
                  currentPage: 2,
                  lastPage: 2,
                  posts: [
                    _post(
                      pid: 'tail-page-p3',
                      author: 'Normal',
                      authorId: '43',
                      number: 3,
                      message: '<p>最后一页的普通回复</p>',
                    ),
                    _post(
                      pid: 'tail-page-b2',
                      author: 'Muted',
                      authorId: '44',
                      number: 4,
                      message: '<p>最后一页的被屏蔽回复</p>',
                    ),
                  ],
                )
              : _threadDetailData(
                  tid: tid,
                  currentPage: 1,
                  lastPage: 2,
                  posts: [
                    _post(
                      pid: 'tail-page-p1',
                      author: 'Owner',
                      authorId: '41',
                      number: 1,
                      isFirst: true,
                      message: '<p>主题正文</p>',
                    ),
                    _post(
                      pid: 'tail-page-b1',
                      author: 'Muted',
                      authorId: '44',
                      number: 2,
                      message: '<p>前页的被屏蔽回复</p>',
                    ),
                  ],
                ),
        );
      });

      await tester.pumpWidget(
        _buildTestApp(
          repository,
          home: const ThreadDetailPage(
            tid: '100',
            subject: '测试主题',
            initialPage: 2,
          ),
          additionalOverrides: [
            yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(requests, equals(<int>[2]));
      expect(
        find.byKey(const Key('thread-filtered-tail-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread-blacklisted-post-tail-page-b1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('thread-blacklisted-post-tail-page-b2')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('thread-filtered-tail-toggle')));
      await tester.pumpAndSettle();

      expect(requests, containsAll(<int>[1, 2]));

      expect(
        find.byKey(const Key('thread-blacklisted-post-tail-page-b1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread-blacklisted-post-tail-page-b2')),
        findsOneWidget,
      );
      final normalTop = tester
          .getTopLeft(find.byKey(const Key('thread-post-card-tail-page-p3')))
          .dy;
      final bannerTop = tester
          .getTopLeft(find.byKey(const Key('thread-filtered-tail-banner')))
          .dy;
      final firstTailTop = tester
          .getTopLeft(
            find.byKey(const Key('thread-blacklisted-post-tail-page-b1')),
          )
          .dy;
      final secondTailTop = tester
          .getTopLeft(
            find.byKey(const Key('thread-blacklisted-post-tail-page-b2')),
          )
          .dy;
      expect(bannerTop, greaterThan(normalTop));
      expect(firstTailTop, greaterThan(bannerTop));
      expect(secondTailTop, greaterThan(firstTailTop));
    },
  );
}
