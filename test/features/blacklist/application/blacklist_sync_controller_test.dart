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
