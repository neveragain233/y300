import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_repository.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_thread_repository.dart';
import 'package:y300/features/content_filter/presentation/content_filter_page.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('shows the synced web blacklist for the current account', (
    tester,
  ) async {
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
    final blacklistRepository = _SeededBlacklistRepository(
      BlacklistSnapshot(
        accounts: <String, BlacklistAccountSnapshot>{
          '11': BlacklistAccountSnapshot(
            ownerUid: '11',
            members: const <BlacklistMember>[
              BlacklistMember(userId: '42', username: 'BlockedUser'),
            ],
            lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockedThreadRepositoryProvider.overrideWithValue(
            _MemoryRepository(const <BlockedThread>[]),
          ),
          blacklistRepositoryProvider.overrideWithValue(blacklistRepository),
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '11',
            revision: 1,
          )),
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
        ],
        child: const LocalizedTestApp(home: ContentFilterPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BlockedUser'), findsOneWidget);
    expect(
      find.byKey(const Key('content-filter-blacklist-member-42')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('content-filter-blacklist-refresh')),
      findsOneWidget,
    );
  });

  testWidgets('hiding blacklisted threads defaults off and persists toggle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockedThreadRepositoryProvider.overrideWithValue(
            _MemoryRepository(const <BlockedThread>[]),
          ),
          blacklistRepositoryProvider.overrideWithValue(
            _EmptyBlacklistRepository(),
          ),
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue(null),
        ],
        child: const LocalizedTestApp(home: ContentFilterPage()),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(
      const Key('content-filter-hide-blacklisted-threads'),
    );
    expect(tile, findsOneWidget);
    expect(tester.widget<AppSwitchRow>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<AppSwitchRow>(tile).value, isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('blacklist.hide_initiated_threads.v1'), isTrue);
  });

  testWidgets('lists blocked threads and restores one', (tester) async {
    final repository = _MemoryRepository([
      BlockedThread(
        tid: '12',
        subject: '被屏蔽的帖子',
        blockedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockedThreadRepositoryProvider.overrideWithValue(repository),
          blacklistRepositoryProvider.overrideWithValue(
            _EmptyBlacklistRepository(),
          ),
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue(null),
        ],
        child: const LocalizedTestApp(home: ContentFilterPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-12')),
      findsOneWidget,
    );
    expect(find.text('被屏蔽的帖子'), findsOneWidget);

    await tester.tap(find.byKey(const Key('content-filter-unblock-12')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-12')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('content-filter-blocked-thread-empty')),
      findsOneWidget,
    );
    expect(repository.rules, isEmpty);
  });
}

final class _MemoryRepository implements BlockedThreadRepository {
  _MemoryRepository(this.rules);

  List<BlockedThread> rules;

  @override
  Future<List<BlockedThread>> load() async => rules;

  @override
  Future<void> save(List<BlockedThread> threads) async {
    rules = threads;
  }
}

final class _SeededBlacklistRepository implements BlacklistRepository {
  _SeededBlacklistRepository(this.snapshot);

  BlacklistSnapshot snapshot;

  @override
  Future<BlacklistSnapshot> load() async => snapshot;

  @override
  Future<void> save(BlacklistSnapshot next) async {
    snapshot = next;
  }
}

final class _EmptyBlacklistRepository implements BlacklistRepository {
  @override
  Future<BlacklistSnapshot> load() async => BlacklistSnapshot.empty;

  @override
  Future<void> save(BlacklistSnapshot snapshot) async {}
}
