import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/storage/app_data_backup_providers.dart';
import 'package:y300/features/content_filter/data/backup/content_filter_backup_sections.dart';
import 'package:y300/features/storage/data/app_data_backup_service.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_thread_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/presentation/blocked_threads_page.dart';
import 'package:y300/features/content_filter/presentation/content_filter_page.dart';
import 'package:y300/features/content_filter/presentation/web_blacklist_page.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../../test_support/localized_test_app.dart';
import '../../../test_support/page_flow_test_support.dart';

void main() {
  testWidgets('content filter entry lists two submenus without content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWithValue(_MemoryPreferencesStore()),
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue(null),
        ],
        child: const LocalizedTestApp(home: ContentFilterPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-threads-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('content-filter-blocked-keywords-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('content-filter-web-blacklist-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('content-filter-blocked-thread-12')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('content-filter-blacklist-refresh')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('content-filter-blocked-threads-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blocked-threads-page')), findsOneWidget);
  });
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
    final store = _MemoryPreferencesStore(
      blacklist: BlacklistSnapshot(
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
          preferencesStoreProvider.overrideWithValue(store),
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '11',
            revision: 1,
          )),
          yamiboSessionStoreProvider.overrideWithValue(sessionStore),
        ],
        child: const LocalizedTestApp(home: WebBlacklistPage()),
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
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue(null),
        ],
        child: const LocalizedTestApp(home: WebBlacklistPage()),
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
    final store = _MemoryPreferencesStore(
      blockedThreads: [
        BlockedThread(
          tid: '12',
          subject: '被屏蔽的帖子',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWithValue(store),
          blacklistAutoSyncProvider.overrideWithValue(false),
          verifiedSessionOwnerProvider.overrideWithValue(null),
        ],
        child: const LocalizedTestApp(home: BlockedThreadsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-12')),
      findsOneWidget,
    );
    expect(find.text('被屏蔽的帖子'), findsOneWidget);

    final unblock = find.byKey(const Key('content-filter-unblock-12'));
    final unblockSize = tester.getSize(unblock);
    expect(unblockSize.width, greaterThanOrEqualTo(72));
    expect(unblockSize.height, greaterThanOrEqualTo(48));
    // 行尾危险操作在屏幕右缘也必须有完整命中区：点按钮最右侧2像素仍生效。
    final rect = tester.getRect(unblock);
    await tester.tapAt(rect.centerRight - const Offset(2, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-thread-12')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('content-filter-blocked-thread-empty')),
      findsOneWidget,
    );
    expect(store.blockedThreads, isEmpty);
  });

  testWidgets(
    'web blacklist page confirms native removal and shows queued undo',
    (tester) async {
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
      final store = _MemoryPreferencesStore(
        blacklist: BlacklistSnapshot(
          accounts: <String, BlacklistAccountSnapshot>{
            '11': BlacklistAccountSnapshot(
              ownerUid: '11',
              members: const <BlacklistMember>[
                BlacklistMember(userId: '42', username: 'BlockedUser'),
                BlacklistMember(userId: '43', username: 'QueuedTarget'),
              ],
              lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(1000),
            ),
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWithValue(store),
            blacklistAutoSyncProvider.overrideWithValue(false),
            blacklistRemoveSupportedProvider.overrideWithValue(true),
            blacklistRemoveCommandProvider.overrideWithValue((
              submission,
            ) async {
              if (submission.userId == '42') {
                return const DataCommandApplied(
                  ForumBlacklistRemoveReceipt(userId: '42'),
                );
              }
              return const DataCommandNotSent(
                DataCommandFailure(
                  kind: DataCommandFailureKind.network,
                  retryPolicy: DataCommandRetryPolicy.explicitOnly,
                  code: 'offline',
                  diagnosticMessage: 'offline',
                ),
              );
            }),
            blacklistRemoteLoaderProvider.overrideWithValue(
              (_) async =>
                  DataReadSuccess<
                    ForumBlacklistData,
                    ForumBlacklistReadCapabilities
                  >(
                    data: const ForumBlacklistData(
                      entries: <ForumBlacklistEntry>[
                        ForumBlacklistEntry(
                          userId: '43',
                          username: 'QueuedTarget',
                        ),
                      ],
                      pagesRead: 1,
                    ),
                    capabilities: ForumBlacklistReadCapabilities(
                      values: DataCapabilitySet.supported(
                        ForumBlacklistCapability.values,
                      ),
                    ),
                    metadata: const DataReadMetadata.network(),
                  ),
            ),
            verifiedSessionOwnerProvider.overrideWithValue((
              uid: '11',
              revision: 1,
            )),
            yamiboSessionStoreProvider.overrideWithValue(sessionStore),
          ],
          child: const LocalizedTestApp(home: WebBlacklistPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('content-filter-blacklist-remove-42')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('content-filter-blacklist-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('content-filter-blacklist-member-42')),
        findsNothing,
      );

      // Offline remove queues locally and allows undo.
      await tester.tap(
        find.byKey(const Key('content-filter-blacklist-remove-43')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('content-filter-blacklist-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('content-filter-blacklist-pending-43')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('content-filter-blacklist-cancel-pending-43')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('content-filter-blacklist-pending-43')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('content-filter-blacklist-member-43')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'content filter entry navigates to whitelisted users and runs backup export/import',
    (tester) async {
      final store = _MemoryPreferencesStore();
      String? exportedJson;
      final incomingBackup = AppDataBackupEnvelopeCodec.encode(
        exportedAt: DateTime.utc(2026, 11, 25),
        sections: <String, DecodedBackupSectionEntry>{
          'content_filter.blocked_keywords': const DecodedBackupSectionEntry(
            version: 1,
            data: <String, Object?>{
              'schemaVersion': 1,
              'keywords': <Object?>[
                <String, Object?>{
                  'id': 'imp-1',
                  'keyword': 'AI',
                  'scope': 'includeBody',
                  'kind': 'block',
                  'matchType': 'plain',
                  'wholeWord': true,
                  'caseSensitive': false,
                  'enabled': true,
                  'createdAt': 1000,
                  'updatedAt': 1000,
                },
              ],
            },
          ),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWithValue(store),
            blacklistAutoSyncProvider.overrideWithValue(false),
            verifiedSessionOwnerProvider.overrideWithValue(null),
            appDataBackupServiceProvider.overrideWith((ref) {
              return AppDataBackupService(
                sections: <AppDataBackupSection>[
                  BlockedKeywordsBackupSection(ref),
                  BlockedThreadsBackupSection(ref),
                  WhitelistedUsersBackupSection(ref),
                ],
                saveJsonFile:
                    ({required fileName, required bytes, dialogTitle}) async {
                      exportedJson = utf8.decode(bytes);
                      return Uri.parse('file:///tmp/$fileName');
                    },
                pickJsonFile: () async => incomingBackup,
              );
            }),
          ],
          child: const LocalizedTestApp(home: ContentFilterPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('content-filter-whitelisted-users-entry')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('whitelisted-users-page')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('content-filter-add-whitelist-user-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('content-filter-whitelist-uid-input')),
        '5566',
      );
      await tester.tap(find.byKey(const Key('content-filter-whitelist-save')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('content-filter-whitelist-user-5566')),
        findsOneWidget,
      );

      await tapBack(
        tester,
        within: find.byKey(const Key('whitelisted-users-page')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('content-filter-backup-export-entry')),
      );
      await tester.pumpAndSettle();
      expect(exportedJson, isNotNull);
      expect(exportedJson, contains('5566'));

      await tester.tap(
        find.byKey(const Key('content-filter-backup-import-entry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('content-filter-backup-preview-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('content-filter-backup-import-merge')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('content-filter-backup-preview-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('content-filter-builtin-exemption-entry')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('content-filter-builtin-exemption-entry')),
          matching: find.byType(Switch),
        ),
        findsNothing,
      );
    },
  );
}

final class _MemoryPreferencesStore implements PreferencesStore {
  _MemoryPreferencesStore({
    List<BlockedThread> blockedThreads = const <BlockedThread>[],
    BlacklistSnapshot blacklist = BlacklistSnapshot.empty,
  }) : _values = <String, Object>{
         PreferenceKeys.contentFilterBlockedThreadsV1.name:
             BlockedThreadSnapshotCodec.encode(blockedThreads),
         PreferenceKeys.contentFilterWebBlacklistSnapshotV1.name:
             BlacklistSnapshotCodec.encode(blacklist),
       };

  final Map<String, Object> _values;

  List<BlockedThread> get blockedThreads => BlockedThreadSnapshotCodec.decode(
    _values[PreferenceKeys.contentFilterBlockedThreadsV1.name] as String?,
  );

  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async {
    final value = _values[key.name];
    return value is T ? value : null;
  }

  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async =>
      _values.containsKey(key.name);

  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    _values[key.name] = value;
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {
    _values.remove(key.name);
  }
}
