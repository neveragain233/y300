import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_repository.dart';

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
      expect(container.read(blacklistedUserIdsProvider), isEmpty);
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
  DateTime Function()? clock,
  Future<DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>>
  Function(ForumBlacklistQuery query)?
  load,
  BlacklistAddRemoteCommand? command,
  bool supported = false,
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
  final container = ProviderContainer.test(
    overrides: [
      blacklistRepositoryProvider.overrideWithValue(
        repository ?? _MemoryRepository(),
      ),
      blacklistRemoteLoaderProvider.overrideWithValue(
        load ?? (_) async => _success(const <ForumBlacklistEntry>[]),
      ),
      blacklistAutoSyncProvider.overrideWithValue(false),
      blacklistAddSupportedProvider.overrideWithValue(supported),
      if (command != null)
        blacklistAddCommandProvider.overrideWithValue(command),
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

final class _MemoryRepository implements BlacklistRepository {
  _MemoryRepository([this.snapshot = BlacklistSnapshot.empty]);

  BlacklistSnapshot snapshot;
  final List<BlacklistSnapshot> saved = <BlacklistSnapshot>[];

  @override
  Future<BlacklistSnapshot> load() async => snapshot;

  @override
  Future<void> save(BlacklistSnapshot next) async {
    snapshot = next;
    saved.add(next);
  }
}
