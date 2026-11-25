import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_pending_mutation_codec.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_pending_mutation.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/features/profile/presentation/account_display_controller.dart';

void main() {
  test('does not read without a verified owner', () async {
    var reads = 0;
    final container = _container(
      owner: null,
      load: (_) {
        reads++;
        return Future.value(_success(const <ForumBlacklistEntry>[]));
      },
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(blacklistSyncControllerProvider.notifier)
        .refresh();

    expect(outcome, BlacklistSyncOutcome.noOwner);
    expect(reads, 0);
  });

  test('publishes the complete list for the current owner', () async {
    final repository = _MemoryRepository();
    var clock = DateTime.fromMillisecondsSinceEpoch(5000);
    final container = _container(
      owner: (uid: '11', revision: 3),
      repository: repository,
      clock: () => clock,
      load: (_) async => _success(<ForumBlacklistEntry>[
        const ForumBlacklistEntry(userId: '21', username: 'Alice'),
        const ForumBlacklistEntry(userId: '22', username: 'Bob'),
      ]),
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(blacklistSyncControllerProvider.notifier)
        .refresh(force: true);

    expect(outcome, BlacklistSyncOutcome.success);
    expect(container.read(blacklistedUserIdsProvider), <String>{'21', '22'});
    expect(repository.saved.single.accountFor('11')!.lastSuccessAt, clock);
  });

  test('an explicit empty list clears the account snapshot', () async {
    final repository = _MemoryRepository(
      BlacklistSnapshot(
        accounts: <String, BlacklistAccountSnapshot>{
          '11': BlacklistAccountSnapshot(
            ownerUid: '11',
            members: const <BlacklistMember>[
              BlacklistMember(userId: '21', username: 'Alice'),
            ],
            lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        },
      ),
    );
    final container = _container(
      owner: (uid: '11', revision: 3),
      repository: repository,
      load: (_) async => _success(const <ForumBlacklistEntry>[]),
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(blacklistSyncControllerProvider.notifier)
        .refresh(force: true);

    expect(outcome, BlacklistSyncOutcome.success);
    expect(container.read(blacklistedUserIdsProvider), isEmpty);
    expect(repository.saved.single.accountFor('11')!.members, isEmpty);
  });

  test('a failed read keeps the last successful list', () async {
    final repository = _MemoryRepository(
      BlacklistSnapshot(
        accounts: <String, BlacklistAccountSnapshot>{
          '11': BlacklistAccountSnapshot(
            ownerUid: '11',
            members: const <BlacklistMember>[
              BlacklistMember(userId: '21', username: 'Alice'),
            ],
            lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        },
      ),
    );
    final container = _container(
      owner: (uid: '11', revision: 3),
      repository: repository,
      load: (_) async =>
          const DataReadFailure<
            ForumBlacklistData,
            ForumBlacklistReadCapabilities
          >(
            kind: DataReadFailureKind.network,
            code: 'fixture',
            diagnosticMessage: 'fixture',
          ),
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(blacklistSyncControllerProvider.notifier)
        .refresh(force: true);

    expect(outcome, BlacklistSyncOutcome.failure);
    expect(container.read(blacklistedUserIdsProvider), <String>{'21'});
    expect(repository.saved, isEmpty);
  });

  test('a confirmed add merges immediately and reconciles the list', () async {
    final repository = _MemoryRepository();
    final commands = <ForumBlacklistAddSubmission>[];
    final container = _container(
      owner: (uid: '11', revision: 3),
      repository: repository,
      load: (_) async => _success(<ForumBlacklistEntry>[
        const ForumBlacklistEntry(userId: '21', username: 'Alice'),
        const ForumBlacklistEntry(userId: '22', username: 'Bob'),
      ]),
      command: (submission) async {
        commands.add(submission);
        return DataCommandApplied(
          ForumBlacklistAddReceipt(
            userId: submission.userId,
            username: submission.username,
          ),
        );
      },
      supported: true,
    );
    addTearDown(container.dispose);
    final controller = container.read(blacklistSyncControllerProvider.notifier);

    final outcome = await controller.addUser(userId: '22', username: 'Bob');
    expect(outcome, BlacklistAddOutcome.applied);
    expect(commands.single.userId, '22');
    expect(commands.single.username, 'Bob');
    expect(container.read(blacklistedUserIdsProvider), contains('22'));
    expect(repository.saved.last.accountFor('11')!.members.single.userId, '22');

    await Future<void>.delayed(Duration.zero);
    expect(container.read(blacklistedUserIdsProvider), <String>{'21', '22'});
  });

  test(
    'repeated requests share one command and already listed users skip it',
    () async {
      final gate = Completer<DataCommandResult<ForumBlacklistAddReceipt>>();
      final commands = <ForumBlacklistAddSubmission>[];
      final repository = _MemoryRepository(
        BlacklistSnapshot(
          accounts: <String, BlacklistAccountSnapshot>{
            '11': BlacklistAccountSnapshot(
              ownerUid: '11',
              members: const <BlacklistMember>[
                BlacklistMember(userId: '22', username: 'Bob'),
              ],
              lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(1000),
            ),
          },
        ),
      );
      final container = _container(
        owner: (uid: '11', revision: 3),
        repository: repository,
        command: (submission) {
          commands.add(submission);
          return gate.future;
        },
        supported: true,
      );
      addTearDown(container.dispose);
      final controller = container.read(
        blacklistSyncControllerProvider.notifier,
      );

      expect(
        await controller.addUser(userId: '22', username: 'Bob'),
        BlacklistAddOutcome.alreadyListed,
      );
      final first = controller.addUser(userId: '23', username: 'Carol');
      final second = controller.addUser(userId: '23', username: 'Carol');
      await Future<void>.delayed(Duration.zero);
      expect(commands, hasLength(1));
      gate.complete(
        const DataCommandApplied(
          ForumBlacklistAddReceipt(userId: '23', username: 'Carol'),
        ),
      );
      expect(await first, BlacklistAddOutcome.applied);
      expect(await second, BlacklistAddOutcome.applied);
      expect(commands, hasLength(1));
    },
  );

  test('inconclusive or rejected commands keep the published list', () async {
    final cases =
        <
          (
            Future<DataCommandResult<ForumBlacklistAddReceipt>> Function(),
            BlacklistAddOutcome,
          )
        >[
          (
            () async => const DataCommandOutcomeUnknown(
              DataCommandFailure(
                kind: DataCommandFailureKind.unknown,
                retryPolicy: DataCommandRetryPolicy.never,
                diagnosticMessage: 'fixture',
              ),
            ),
            BlacklistAddOutcome.outcomeUnknown,
          ),
          (
            () async => const DataCommandRejected(
              DataCommandFailure(
                kind: DataCommandFailureKind.validation,
                retryPolicy: DataCommandRetryPolicy.never,
                diagnosticMessage: 'fixture',
              ),
            ),
            BlacklistAddOutcome.rejected,
          ),
          (
            () async => const DataCommandNotSent(
              DataCommandFailure(
                kind: DataCommandFailureKind.unauthenticated,
                retryPolicy: DataCommandRetryPolicy.never,
                diagnosticMessage: 'fixture',
              ),
            ),
            BlacklistAddOutcome.notLoggedIn,
          ),
          (
            () async => const DataCommandUnsupported(),
            BlacklistAddOutcome.unsupported,
          ),
        ];
    for (final (command, expected) in cases) {
      final repository = _MemoryRepository();
      final container = _container(
        owner: (uid: '11', revision: 3),
        repository: repository,
        command: (_) => command(),
        supported: true,
        load: (_) async => _success(const <ForumBlacklistEntry>[]),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        blacklistSyncControllerProvider.notifier,
      );
      expect(await controller.addUser(userId: '22', username: 'Bob'), expected);
      expect(container.read(currentBlacklistAccountProvider), isNull);
      expect(
        container.read(blacklistedUserIdsProvider),
        expected == BlacklistAddOutcome.outcomeUnknown
            ? <String>{'22'}
            : isEmpty,
      );
      expect(repository.saved, isEmpty);
    }
  });

  test('invalid targets, self and a missing owner never submit', () async {
    var commands = 0;
    final container = _container(
      owner: (uid: '11', revision: 3),
      command: (_) async {
        commands++;
        return const DataCommandUnsupported();
      },
      supported: true,
    );
    addTearDown(container.dispose);
    final controller = container.read(blacklistSyncControllerProvider.notifier);
    expect(
      await controller.addUser(userId: '11', username: 'Reader'),
      BlacklistAddOutcome.self,
    );
    expect(
      await controller.addUser(userId: '0', username: 'Bad'),
      BlacklistAddOutcome.invalidTarget,
    );
    expect(
      await controller.addUser(userId: '22', username: ''),
      BlacklistAddOutcome.invalidTarget,
    );
    expect(
      await controller.addUser(userId: '22', username: ' Bob'),
      BlacklistAddOutcome.invalidTarget,
    );
    expect(commands, 0);

    final anonymous = _container(
      owner: null,
      command: (_) async {
        commands++;
        return const DataCommandUnsupported();
      },
      supported: true,
    );
    addTearDown(anonymous.dispose);
    expect(
      await anonymous
          .read(blacklistSyncControllerProvider.notifier)
          .addUser(userId: '22', username: 'Bob'),
      BlacklistAddOutcome.notLoggedIn,
    );
    expect(commands, 0);
  });

  test(
    'an older read cannot hide a member confirmed after it started',
    () async {
      final readGate =
          Completer<
            DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>
          >();
      var reads = 0;
      final container = _container(
        owner: (uid: '11', revision: 3),
        load: (_) {
          reads++;
          return reads == 1
              ? readGate.future
              : Future.value(
                  _success(<ForumBlacklistEntry>[
                    const ForumBlacklistEntry(userId: '21', username: 'Alice'),
                    const ForumBlacklistEntry(userId: '22', username: 'Bob'),
                  ]),
                );
        },
        command: (submission) async => DataCommandApplied(
          ForumBlacklistAddReceipt(
            userId: submission.userId,
            username: submission.username,
          ),
        ),
        supported: true,
      );
      addTearDown(container.dispose);
      final controller = container.read(
        blacklistSyncControllerProvider.notifier,
      );

      final pendingRefresh = controller.refresh(force: true);
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);

      final added = await controller.addUser(userId: '22', username: 'Bob');
      expect(added, BlacklistAddOutcome.applied);
      expect(container.read(blacklistedUserIdsProvider), contains('22'));

      // The pre-write read completes without the member and must not publish.
      readGate.complete(
        _success(<ForumBlacklistEntry>[
          const ForumBlacklistEntry(userId: '21', username: 'Alice'),
        ]),
      );
      expect(await pendingRefresh, BlacklistSyncOutcome.stale);
      expect(container.read(blacklistedUserIdsProvider), contains('22'));

      for (var attempt = 0; attempt < 20 && reads < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(reads, 2);
      expect(container.read(blacklistedUserIdsProvider), <String>{'21', '22'});
    },
  );

  test('a confirmed add is stale when the owner changes mid-command', () async {
    final gate = Completer<DataCommandResult<ForumBlacklistAddReceipt>>();
    final container = _container(
      owner: (uid: '11', revision: 3),
      command: (_) => gate.future,
      supported: true,
    );
    addTearDown(container.dispose);
    final controller = container.read(blacklistSyncControllerProvider.notifier);
    final pending = controller.addUser(userId: '22', username: 'Bob');
    await Future<void>.delayed(Duration.zero);
    container.read(_ownerState.notifier).set((uid: '12', revision: 4));
    gate.complete(
      const DataCommandApplied(
        ForumBlacklistAddReceipt(userId: '22', username: 'Bob'),
      ),
    );
    expect(await pending, BlacklistAddOutcome.stale);
    expect(container.read(blacklistedUserIdsProvider), isEmpty);
  });

  test('does not publish a result after the owner revision changes', () async {
    final repository = _MemoryRepository();
    final response =
        Completer<
          DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>
        >();
    var reads = 0;
    final container = _container(
      owner: (uid: '11', revision: 3),
      repository: repository,
      load: (_) {
        reads++;
        return reads == 1
            ? response.future
            : Future.value(
                const DataReadFailure<
                  ForumBlacklistData,
                  ForumBlacklistReadCapabilities
                >(
                  kind: DataReadFailureKind.network,
                  code: 'fixture',
                  diagnosticMessage: 'fixture',
                ),
              );
      },
    );
    addTearDown(container.dispose);
    final controller = container.read(blacklistSyncControllerProvider.notifier);

    final pending = controller.refresh(force: true);
    container.read(_ownerState.notifier).set((uid: '12', revision: 4));
    response.complete(_success(const <ForumBlacklistEntry>[]));
    final outcome = await pending;

    expect(outcome, BlacklistSyncOutcome.stale);
    expect(repository.saved, isEmpty);
    expect(container.read(blacklistedUserIdsProvider), isEmpty);
  });

  test('removeUser removes confirmed member and reconciles', () async {
    final repository = _MemoryRepository(
      BlacklistSnapshot(
        accounts: <String, BlacklistAccountSnapshot>{
          '11': BlacklistAccountSnapshot(
            ownerUid: '11',
            members: const <BlacklistMember>[
              BlacklistMember(userId: '21', username: 'Alice'),
              BlacklistMember(userId: '22', username: 'Bob'),
            ],
            lastSuccessAt: DateTime(2026, 11, 24),
          ),
        },
      ),
    );
    var reads = 0;
    final container = _container(
      owner: (uid: '11', revision: 1),
      repository: repository,
      removeSupported: true,
      removeCommand: (submission) async {
        expect(submission.userId, '22');
        return const DataCommandApplied(
          ForumBlacklistRemoveReceipt(userId: '22'),
        );
      },
      load: (_) async {
        reads++;
        return _success(const <ForumBlacklistEntry>[
          ForumBlacklistEntry(userId: '21', username: 'Alice'),
        ]);
      },
    );
    addTearDown(container.dispose);

    final controller = container.read(blacklistSyncControllerProvider.notifier);
    final outcome = await controller.removeUser(userId: '22', username: 'Bob');

    expect(outcome, BlacklistRemoveOutcome.applied);
    expect(container.read(blacklistedUserIdsProvider), <String>{'21'});
    for (var i = 0; i < 10 && reads == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(reads, 1);
  });

  test('queues add/remove locally under weak network and flushes only queued items', () async {
    final repository = _MemoryRepository(
      BlacklistSnapshot(
        accounts: <String, BlacklistAccountSnapshot>{
          '11': BlacklistAccountSnapshot(
            ownerUid: '11',
            members: const <BlacklistMember>[
              BlacklistMember(userId: '21', username: 'Alice'),
            ],
            lastSuccessAt: DateTime(2026, 11, 24),
          ),
        },
      ),
    );
    final pendingRepo = _MemoryPendingRepository(
      BlacklistPendingSnapshot(
        accounts: <String, List<BlacklistPendingMutation>>{
          '11': <BlacklistPendingMutation>[
            BlacklistPendingMutation(
              userId: '30',
              username: 'AlreadySynced',
              action: BlacklistPendingAction.add,
              status: BlacklistPendingStatus.needsVerification,
              updatedAt: DateTime(2026, 11, 24),
            ),
            BlacklistPendingMutation(
              userId: '31',
              username: 'NeedsManualCheck',
              action: BlacklistPendingAction.remove,
              status: BlacklistPendingStatus.needsVerification,
              updatedAt: DateTime(2026, 11, 24),
            ),
          ],
        },
      ),
    );
    final prefs = _MemoryPreferencesStore(<String, Object>{
      AccountDisplayController.storageKey.name: '11',
    });
    final sentAdds = <String>[];
    final sentRemoves = <String>[];

    final container = _container(
      owner: null,
      repository: repository,
      pendingRepository: pendingRepo,
      preferencesStore: prefs,
      supported: true,
      removeSupported: true,
      command: (submission) async {
        sentAdds.add(submission.userId);
        return DataCommandApplied(
          ForumBlacklistAddReceipt(
            userId: submission.userId,
            username: submission.username,
          ),
        );
      },
      removeCommand: (submission) async {
        sentRemoves.add(submission.userId);
        return DataCommandApplied(
          ForumBlacklistRemoveReceipt(userId: submission.userId),
        );
      },
      load: (_) async => _success(<ForumBlacklistEntry>[
        const ForumBlacklistEntry(userId: '21', username: 'Alice'),
        // 30 is already on server -> read-only reconciliation clears it.
        const ForumBlacklistEntry(userId: '30', username: 'AlreadySynced'),
        // 31 is still on server -> needsVerification stays, never auto-resent.
        const ForumBlacklistEntry(userId: '31', username: 'NeedsManualCheck'),
      ]),
    );
    addTearDown(container.dispose);

    // Let fallback microtask read persisted UID without verified owner.
    final sub = container.listen(blacklistSessionUidProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(blacklistSessionUidProvider)?.uid, '11');

    final controller = container.read(blacklistSyncControllerProvider.notifier);
    final queuedAdd = await controller.addUser(userId: '22', username: 'Bob');
    final queuedRemove = await controller.removeUser(
      userId: '21',
      username: 'Alice',
    );
    expect(queuedAdd, BlacklistAddOutcome.queued);
    expect(queuedRemove, BlacklistRemoveOutcome.queued);
    expect(container.read(blacklistedUserIdsProvider), contains('22'));
    expect(container.read(blacklistedUserIdsProvider), isNot(contains('21')));

    // Verified session arrives -> flushQueuedMutations reconciles + flushes queued.
    container.read(_ownerState.notifier).set((uid: '11', revision: 2));
    await controller.flushQueuedMutations();

    expect(sentAdds, <String>['22']);
    expect(sentRemoves, <String>['21']);
    // 31 (needsVerification) was NOT auto-resent and remains pending for user.
    final remainingPending = container.read(
      currentBlacklistPendingMutationsProvider,
    );
    expect(remainingPending.map((m) => m.userId), <String>['31']);
  });
}

DataReadSuccess<ForumBlacklistData, ForumBlacklistReadCapabilities> _success(
  List<ForumBlacklistEntry> entries,
) {
  return DataReadSuccess<ForumBlacklistData, ForumBlacklistReadCapabilities>(
    data: ForumBlacklistData(
      entries: List<ForumBlacklistEntry>.unmodifiable(entries),
      pagesRead: 1,
    ),
    capabilities: ForumBlacklistReadCapabilities(
      values: DataCapabilitySet.supported(ForumBlacklistCapability.values),
    ),
    metadata: const DataReadMetadata.network(),
  );
}

ProviderContainer _container({
  required VerifiedSessionOwner? owner,
  _MemoryRepository? repository,
  _MemoryPendingRepository? pendingRepository,
  _MemoryPreferencesStore? preferencesStore,
  DateTime Function()? clock,
  Future<DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>>
  Function(ForumBlacklistQuery query)?
  load,
  BlacklistAddRemoteCommand? command,
  BlacklistRemoveRemoteCommand? removeCommand,
  bool supported = false,
  bool removeSupported = false,
}) {
  final sessionStore = YamiboSessionStore();
  if (owner != null) {
    sessionStore.saveExtracted(
      YamiboSessionSnapshot(
        isLoggedIn: true,
        uid: owner.uid,
        username: 'Reader',
        formhash: '',
        updatedAt: DateTime(2026, 1, 1),
        source: 'test',
      ),
    );
  }
  final store = _MemoryPreferencesStore(<String, Object>{
    if (preferencesStore != null) ...preferencesStore._values,
    if (repository != null)
      PreferenceKeys.contentFilterWebBlacklistSnapshotV1.name:
          BlacklistSnapshotCodec.encode(repository.snapshot),
    if (pendingRepository != null)
      PreferenceKeys.contentFilterWebBlacklistPendingV1.name:
          BlacklistPendingMutationCodec.encode(pendingRepository.snapshot),
  }, onSnapshotWrite: repository?.saved.add);
  final container = ProviderContainer.test(
    overrides: [
      preferencesStoreProvider.overrideWithValue(store),
      blacklistRemoteLoaderProvider.overrideWithValue(
        load ?? (_) async => _success(const <ForumBlacklistEntry>[]),
      ),
      blacklistAutoSyncProvider.overrideWithValue(false),
      blacklistAddSupportedProvider.overrideWithValue(supported),
      blacklistRemoveSupportedProvider.overrideWithValue(removeSupported),
      if (command != null)
        blacklistAddCommandProvider.overrideWithValue(command),
      if (removeCommand != null)
        blacklistRemoveCommandProvider.overrideWithValue(removeCommand),
      if (clock != null) blacklistClockProvider.overrideWithValue(clock),
      verifiedSessionOwnerProvider.overrideWith(
        (ref) => ref.watch(_ownerState),
      ),
      yamiboSessionStoreProvider.overrideWithValue(sessionStore),
    ],
  );
  container.read(_ownerState.notifier).set(owner);
  return container;
}

final _ownerState = NotifierProvider<_OwnerNotifier, VerifiedSessionOwner?>(
  _OwnerNotifier.new,
);

final class _OwnerNotifier extends Notifier<VerifiedSessionOwner?> {
  @override
  VerifiedSessionOwner? build() => null;

  void set(VerifiedSessionOwner? value) {
    state = value;
  }
}

final class _MemoryRepository {
  _MemoryRepository([this.snapshot = BlacklistSnapshot.empty]);

  BlacklistSnapshot snapshot;
  final List<BlacklistSnapshot> saved = <BlacklistSnapshot>[];
}

final class _MemoryPendingRepository {
  _MemoryPendingRepository([BlacklistPendingSnapshot? snapshot])
    : snapshot = snapshot ?? BlacklistPendingSnapshot.empty;

  BlacklistPendingSnapshot snapshot;
}

final class _MemoryPreferencesStore implements PreferencesStore {
  _MemoryPreferencesStore(this._values, {this.onSnapshotWrite});

  final Map<String, Object> _values;
  final void Function(BlacklistSnapshot snapshot)? onSnapshotWrite;

  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async =>
      _values.containsKey(key.name);

  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async {
    final value = _values[key.name];
    return value is T ? value : null;
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {
    _values.remove(key.name);
  }

  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    _values[key.name] = value;
    if (key.name == PreferenceKeys.contentFilterWebBlacklistSnapshotV1.name &&
        value is String) {
      onSnapshotWrite?.call(BlacklistSnapshotCodec.decode(value));
    }
  }
}
