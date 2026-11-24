import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_pending_mutation.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';

/// Result of one explicit or automatic web-blacklist synchronization.
enum BlacklistSyncOutcome { success, noOwner, cancelled, stale, failure }

/// Result of adding one user to the account's web blacklist.
enum BlacklistAddOutcome {
  applied,
  queued,
  alreadyListed,
  notLoggedIn,
  invalidTarget,
  self,
  unsupported,
  rejected,
  outcomeUnknown,
  stale,
  cancelled,
}

/// Result of removing one user from the account's web blacklist.
enum BlacklistRemoveOutcome {
  applied,
  queued,
  notListed,
  notLoggedIn,
  invalidTarget,
  unsupported,
  rejected,
  outcomeUnknown,
  stale,
  cancelled,
}

/// Persisted local pending web-blacklist mutations, separate from the
/// server-confirmed [BlacklistSnapshot].
final class BlacklistPendingController
    extends AsyncNotifier<BlacklistPendingSnapshot> {
  Future<void> _writes = Future<void>.value();

  @override
  FutureOr<BlacklistPendingSnapshot> build() {
    return ref.watch(blacklistPendingRepositoryProvider).load();
  }

  Future<void> recordMutation(
    String ownerUid,
    BlacklistPendingMutation mutation,
  ) => _mutate((current) => current.withMutation(ownerUid, mutation));

  Future<void> removeUser(String ownerUid, String userId) =>
      _mutate((current) => current.withoutUser(ownerUid, userId));

  Future<void> reconcile(String ownerUid, Set<String> serverUserIds) {
    return _mutate((current) {
      final list = current.mutationsFor(ownerUid);
      if (list.isEmpty) {
        return current;
      }
      final satisfiedIds = <String>{};
      for (final item in list) {
        final isOnServer = serverUserIds.contains(item.userId);
        if ((item.action == BlacklistPendingAction.add && isOnServer) ||
            (item.action == BlacklistPendingAction.remove && !isOnServer)) {
          satisfiedIds.add(item.userId);
        }
      }
      return satisfiedIds.isEmpty
          ? current
          : current.withoutUsers(ownerUid, satisfiedIds);
    });
  }

  Future<void> _mutate(
    BlacklistPendingSnapshot Function(BlacklistPendingSnapshot current)
    transform,
  ) {
    final op = _writes.then((_) async {
      if (!ref.mounted) {
        return;
      }
      final current = await _currentSnapshot();
      if (!ref.mounted) {
        return;
      }
      final next = transform(current);
      if (identical(next, current)) {
        return;
      }
      state = AsyncData(next);
      try {
        await ref.read(blacklistPendingRepositoryProvider).save(next);
      } catch (_) {
        // Keep in-memory pending intent; next save or read will retry.
      }
    });
    _writes = op.catchError((_) {});
    return op;
  }

  Future<BlacklistPendingSnapshot> _currentSnapshot() async {
    if (!ref.mounted) {
      return BlacklistPendingSnapshot.empty;
    }
    final value = state.value;
    if (value != null) {
      return value;
    }
    try {
      final loaded = await future;
      return ref.mounted ? loaded : BlacklistPendingSnapshot.empty;
    } catch (_) {
      return BlacklistPendingSnapshot.empty;
    }
  }
}

final blacklistPendingControllerProvider =
    AsyncNotifierProvider<BlacklistPendingController, BlacklistPendingSnapshot>(
      BlacklistPendingController.new,
    );

/// Per-account web-blacklist snapshots.
///
/// Reads only run for a verified session owner. Results are discarded when the
/// owner or its session revision changes, and failures leave the last
/// successful list untouched. An explicitly empty validated list publishes an
/// empty account snapshot instead of being treated as a failure.
final class BlacklistSyncController extends AsyncNotifier<BlacklistSnapshot> {
  static const Duration staleAfter = Duration(hours: 6);

  Future<BlacklistSyncOutcome>? _inFlight;
  Future<void>? _flushInFlight;
  final _addInFlight = <String, Future<BlacklistAddOutcome>>{};
  final _removeInFlight = <String, Future<BlacklistRemoveOutcome>>{};
  int _writeRevision = 0;

  @override
  FutureOr<BlacklistSnapshot> build() {
    return ref.watch(blacklistRepositoryProvider).load();
  }

  /// Loads the complete web blacklist for the current verified owner.
  Future<BlacklistSyncOutcome> refresh({bool force = false}) {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<BlacklistSyncOutcome> run;
    run = _refresh(force: force).whenComplete(() {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    });
    _inFlight = run;
    return run;
  }

  Future<BlacklistSyncOutcome> _refresh({required bool force}) async {
    final owner = ref.read(verifiedSessionOwnerProvider);
    if (owner == null) {
      return BlacklistSyncOutcome.noOwner;
    }
    final current = await _currentSnapshot();
    if (!ref.mounted) {
      return BlacklistSyncOutcome.stale;
    }
    if (!force) {
      final account = current.accountFor(owner.uid);
      if (account != null &&
          ref.read(blacklistClockProvider)().difference(account.lastSuccessAt) <
              staleAfter) {
        return BlacklistSyncOutcome.success;
      }
    }
    final writeRevision = _writeRevision;
    final cancellation = ForumRequestCancellation();
    final result = await ref
        .read(blacklistRemoteLoaderProvider)
        .call(ForumBlacklistQuery(cancellation: cancellation));
    if (cancellation.isCancelled ||
        ref.read(verifiedSessionOwnerProvider) != owner) {
      return cancellation.isCancelled
          ? BlacklistSyncOutcome.cancelled
          : BlacklistSyncOutcome.stale;
    }
    if (writeRevision != _writeRevision) {
      // A confirmed member write landed after this read started; publishing the
      // older list would hide it again.
      return BlacklistSyncOutcome.stale;
    }
    if (result case DataReadSuccess<
      ForumBlacklistData,
      ForumBlacklistReadCapabilities
    >(
      :final data,
    )) {
      final account = BlacklistAccountSnapshot(
        ownerUid: owner.uid,
        members: <BlacklistMember>[
          for (final entry in data.entries)
            BlacklistMember(
              userId: entry.userId,
              username: entry.username,
              avatarUrl: entry.avatarUrl,
            ),
        ],
        lastSuccessAt: ref.read(blacklistClockProvider)(),
      );
      final next = current.withAccount(
        account,
        maxAccounts: BlacklistSnapshotCodec.maxAccounts,
      );
      try {
        await ref.read(blacklistRepositoryProvider).save(next);
      } catch (_) {
        return BlacklistSyncOutcome.failure;
      }
      if (!ref.mounted || ref.read(verifiedSessionOwnerProvider) != owner) {
        return BlacklistSyncOutcome.stale;
      }
      state = AsyncData(next);
      await ref.read(blacklistPendingControllerProvider.notifier).reconcile(
        owner.uid,
        <String>{for (final entry in data.entries) entry.userId},
      );
      return BlacklistSyncOutcome.success;
    }
    return BlacklistSyncOutcome.failure;
  }

  /// Refreshes only when the current owner has no list or a stale one.
  ///
  /// Surfaces that list blacklisted content call this when they open; ordinary
  /// page builds never start an implicit network read.
  Future<BlacklistSyncOutcome> syncIfStale() async {
    if (!ref.read(blacklistAutoSyncProvider)) {
      return BlacklistSyncOutcome.success;
    }
    final owner = ref.read(verifiedSessionOwnerProvider);
    if (owner == null) {
      return BlacklistSyncOutcome.noOwner;
    }
    final snapshot = await _currentSnapshot();
    final account = snapshot.accountFor(owner.uid);
    final stale =
        account == null ||
        ref.read(blacklistClockProvider)().difference(account.lastSuccessAt) >=
            staleAfter;
    return stale ? refresh() : BlacklistSyncOutcome.success;
  }

  /// Adds one user to the current owner's web blacklist.
  ///
  /// Repeated requests for the same target share one command. When the network
  /// or verified session is temporarily unavailable, the intent is persisted
  /// locally as [BlacklistPendingStatus.queued] so filtering reacts at once and
  /// syncs on next launch.
  Future<BlacklistAddOutcome> addUser({
    required String userId,
    required String username,
    bool allowRetryPending = false,
  }) {
    final key = userId.trim();
    final existing = _addInFlight[key];
    if (existing != null) return existing;
    late final Future<BlacklistAddOutcome> run;
    run =
        _addUser(
          userId: key,
          username: username,
          allowRetryPending: allowRetryPending,
        ).whenComplete(() {
          if (identical(_addInFlight[key], run)) {
            _addInFlight.remove(key);
          }
        });
    _addInFlight[key] = run;
    return run;
  }

  Future<BlacklistAddOutcome> _addUser({
    required String userId,
    required String username,
    required bool allowRetryPending,
  }) async {
    final verifiedOwner = ref.read(verifiedSessionOwnerProvider);
    final activeUid =
        verifiedOwner?.uid ?? ref.read(blacklistSessionUidProvider)?.uid;
    if (activeUid == null) return BlacklistAddOutcome.notLoggedIn;
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(userId) ||
        username.isEmpty ||
        username.trim() != username) {
      return BlacklistAddOutcome.invalidTarget;
    }
    if (activeUid == userId) return BlacklistAddOutcome.self;
    final current = await _currentSnapshot();
    final account = current.accountFor(activeUid);
    final inServerList =
        account?.members.any((member) => member.userId == userId) ?? false;
    final pendingList = (await _currentPendingSnapshot()).mutationsFor(
      activeUid,
    );
    BlacklistPendingMutation? existingPending;
    for (final item in pendingList) {
      if (item.userId == userId) {
        existingPending = item;
        break;
      }
    }
    if (inServerList &&
        existingPending?.action == BlacklistPendingAction.remove) {
      // Restoring a user who only had a local pending removal needs no network call.
      await ref
          .read(blacklistPendingControllerProvider.notifier)
          .removeUser(activeUid, userId);
      return BlacklistAddOutcome.applied;
    }
    if (inServerList) {
      return BlacklistAddOutcome.alreadyListed;
    }
    if (existingPending?.action == BlacklistPendingAction.add &&
        !allowRetryPending) {
      return BlacklistAddOutcome.alreadyListed;
    }
    if (!ref.read(blacklistAddSupportedProvider)) {
      return BlacklistAddOutcome.unsupported;
    }
    if (verifiedOwner == null) {
      await _recordPending(
        activeUid,
        userId: userId,
        username: username,
        action: BlacklistPendingAction.add,
        status: BlacklistPendingStatus.queued,
      );
      return BlacklistAddOutcome.queued;
    }
    try {
      final result = await ref.read(blacklistAddCommandProvider)(
        ForumBlacklistAddSubmission(userId: userId, username: username),
      );
      if (!ref.mounted ||
          ref.read(verifiedSessionOwnerProvider) != verifiedOwner) {
        return BlacklistAddOutcome.stale;
      }
      switch (result) {
        case DataCommandApplied(:final receipt):
          final applied = receipt;
          await ref
              .read(blacklistPendingControllerProvider.notifier)
              .removeUser(verifiedOwner.uid, applied.userId);
          _writeRevision++;
          final latest = await _currentSnapshot();
          if (!ref.mounted ||
              ref.read(verifiedSessionOwnerProvider) != verifiedOwner) {
            return BlacklistAddOutcome.stale;
          }
          final latestAccount = latest.accountFor(verifiedOwner.uid);
          final merged = <BlacklistMember>[
            ...?latestAccount?.members,
            if (!(latestAccount?.members.any(
                  (member) => member.userId == applied.userId,
                ) ??
                false))
              BlacklistMember(
                userId: applied.userId,
                username: applied.username,
              ),
          ];
          final next = latest.withAccount(
            BlacklistAccountSnapshot(
              ownerUid: verifiedOwner.uid,
              members: List<BlacklistMember>.unmodifiable(merged),
              lastSuccessAt:
                  latestAccount?.lastSuccessAt ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
            maxAccounts: BlacklistSnapshotCodec.maxAccounts,
          );
          try {
            await ref.read(blacklistRepositoryProvider).save(next);
          } catch (_) {
            // The server effect is confirmed; keep the in-memory list and let
            // the reconciliation read repair persistence.
          }
          if (!ref.mounted ||
              ref.read(verifiedSessionOwnerProvider) != verifiedOwner) {
            return BlacklistAddOutcome.stale;
          }
          state = AsyncData(next);
          unawaited(_reconcileAfterWrite());
          return BlacklistAddOutcome.applied;
        case DataCommandRejected(:final failure):
          if (failure.kind == DataCommandFailureKind.unauthenticated) {
            return BlacklistAddOutcome.notLoggedIn;
          }
          return BlacklistAddOutcome.rejected;
        case DataCommandNotSent(:final failure):
          switch (failure.kind) {
            case DataCommandFailureKind.unauthenticated:
              return BlacklistAddOutcome.notLoggedIn;
            case DataCommandFailureKind.validation:
              return BlacklistAddOutcome.invalidTarget;
            case DataCommandFailureKind.cancelled:
              return BlacklistAddOutcome.cancelled;
            case DataCommandFailureKind.permissionDenied:
              return BlacklistAddOutcome.rejected;
            case DataCommandFailureKind.unsupported:
              return BlacklistAddOutcome.unsupported;
            case DataCommandFailureKind.network:
            case DataCommandFailureKind.timeout:
            case DataCommandFailureKind.server:
            case DataCommandFailureKind.parse:
            case DataCommandFailureKind.securityChallenge:
            case DataCommandFailureKind.staleFormhash:
            case DataCommandFailureKind.unknown:
              await _recordPending(
                verifiedOwner.uid,
                userId: userId,
                username: username,
                action: BlacklistPendingAction.add,
                status: BlacklistPendingStatus.queued,
              );
              return BlacklistAddOutcome.queued;
          }
        case DataCommandUnsupported():
          return BlacklistAddOutcome.unsupported;
        case DataCommandOutcomeUnknown():
          await _recordPending(
            verifiedOwner.uid,
            userId: userId,
            username: username,
            action: BlacklistPendingAction.add,
            status: BlacklistPendingStatus.needsVerification,
          );
          return BlacklistAddOutcome.outcomeUnknown;
      }
    } on Object {
      await _recordPending(
        verifiedOwner.uid,
        userId: userId,
        username: username,
        action: BlacklistPendingAction.add,
        status: BlacklistPendingStatus.needsVerification,
      );
      return BlacklistAddOutcome.outcomeUnknown;
    }
  }

  /// Removes one user from the current owner's web blacklist.
  Future<BlacklistRemoveOutcome> removeUser({
    required String userId,
    required String username,
    bool allowRetryPending = false,
  }) {
    final key = userId.trim();
    final existing = _removeInFlight[key];
    if (existing != null) return existing;
    late final Future<BlacklistRemoveOutcome> run;
    run =
        _removeUser(
          userId: key,
          username: username,
          allowRetryPending: allowRetryPending,
        ).whenComplete(() {
          if (identical(_removeInFlight[key], run)) {
            _removeInFlight.remove(key);
          }
        });
    _removeInFlight[key] = run;
    return run;
  }

  Future<BlacklistRemoveOutcome> _removeUser({
    required String userId,
    required String username,
    required bool allowRetryPending,
  }) async {
    final verifiedOwner = ref.read(verifiedSessionOwnerProvider);
    final activeUid =
        verifiedOwner?.uid ?? ref.read(blacklistSessionUidProvider)?.uid;
    if (activeUid == null) return BlacklistRemoveOutcome.notLoggedIn;
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(userId)) {
      return BlacklistRemoveOutcome.invalidTarget;
    }
    final current = await _currentSnapshot();
    final account = current.accountFor(activeUid);
    final inServerList =
        account?.members.any((member) => member.userId == userId) ?? false;
    final pendingList = (await _currentPendingSnapshot()).mutationsFor(
      activeUid,
    );
    BlacklistPendingMutation? existingPending;
    for (final item in pendingList) {
      if (item.userId == userId) {
        existingPending = item;
        break;
      }
    }
    if (!inServerList &&
        existingPending?.action == BlacklistPendingAction.add) {
      await ref
          .read(blacklistPendingControllerProvider.notifier)
          .removeUser(activeUid, userId);
      return BlacklistRemoveOutcome.applied;
    }
    if (!inServerList) {
      return BlacklistRemoveOutcome.notListed;
    }
    if (existingPending?.action == BlacklistPendingAction.remove &&
        !allowRetryPending) {
      return existingPending!.status == BlacklistPendingStatus.needsVerification
          ? BlacklistRemoveOutcome.outcomeUnknown
          : BlacklistRemoveOutcome.queued;
    }
    if (!ref.read(blacklistRemoveSupportedProvider)) {
      return BlacklistRemoveOutcome.unsupported;
    }
    if (verifiedOwner == null) {
      await _recordPending(
        activeUid,
        userId: userId,
        username: username,
        action: BlacklistPendingAction.remove,
        status: BlacklistPendingStatus.queued,
      );
      return BlacklistRemoveOutcome.queued;
    }
    try {
      final result = await ref.read(blacklistRemoveCommandProvider)(
        ForumBlacklistRemoveSubmission(userId: userId),
      );
      if (!ref.mounted ||
          ref.read(verifiedSessionOwnerProvider) != verifiedOwner) {
        return BlacklistRemoveOutcome.stale;
      }
      switch (result) {
        case DataCommandApplied(:final receipt):
          await ref
              .read(blacklistPendingControllerProvider.notifier)
              .removeUser(verifiedOwner.uid, receipt.userId);
          _writeRevision++;
          final latest = await _currentSnapshot();
          if (!ref.mounted ||
              ref.read(verifiedSessionOwnerProvider) != verifiedOwner) {
            return BlacklistRemoveOutcome.stale;
          }
          final latestAccount = latest.accountFor(verifiedOwner.uid);
          if (latestAccount != null) {
            final filtered = latestAccount.members
                .where((member) => member.userId != receipt.userId)
                .toList(growable: false);
            final next = latest.withAccount(
              BlacklistAccountSnapshot(
                ownerUid: verifiedOwner.uid,
                members: List<BlacklistMember>.unmodifiable(filtered),
                lastSuccessAt: latestAccount.lastSuccessAt,
              ),
              maxAccounts: BlacklistSnapshotCodec.maxAccounts,
            );
            try {
              await ref.read(blacklistRepositoryProvider).save(next);
            } catch (_) {
              // Confirmed server effect; reconciliation read repairs disk state.
            }
            if (!ref.mounted ||
                ref.read(verifiedSessionOwnerProvider) != verifiedOwner) {
              return BlacklistRemoveOutcome.stale;
            }
            state = AsyncData(next);
          }
          unawaited(_reconcileAfterWrite());
          return BlacklistRemoveOutcome.applied;
        case DataCommandRejected(:final failure):
          if (failure.kind == DataCommandFailureKind.unauthenticated) {
            return BlacklistRemoveOutcome.notLoggedIn;
          }
          if (failure.code == 'blacklist_remove_not_listed') {
            await ref
                .read(blacklistPendingControllerProvider.notifier)
                .removeUser(verifiedOwner.uid, userId);
            unawaited(_reconcileAfterWrite());
            return BlacklistRemoveOutcome.notListed;
          }
          return BlacklistRemoveOutcome.rejected;
        case DataCommandNotSent(:final failure):
          switch (failure.kind) {
            case DataCommandFailureKind.unauthenticated:
              return BlacklistRemoveOutcome.notLoggedIn;
            case DataCommandFailureKind.validation:
              return BlacklistRemoveOutcome.invalidTarget;
            case DataCommandFailureKind.cancelled:
              return BlacklistRemoveOutcome.cancelled;
            case DataCommandFailureKind.permissionDenied:
              return BlacklistRemoveOutcome.rejected;
            case DataCommandFailureKind.unsupported:
              return BlacklistRemoveOutcome.unsupported;
            case DataCommandFailureKind.network:
            case DataCommandFailureKind.timeout:
            case DataCommandFailureKind.server:
            case DataCommandFailureKind.parse:
            case DataCommandFailureKind.securityChallenge:
            case DataCommandFailureKind.staleFormhash:
            case DataCommandFailureKind.unknown:
              await _recordPending(
                verifiedOwner.uid,
                userId: userId,
                username: username,
                action: BlacklistPendingAction.remove,
                status: BlacklistPendingStatus.queued,
              );
              return BlacklistRemoveOutcome.queued;
          }
        case DataCommandUnsupported():
          return BlacklistRemoveOutcome.unsupported;
        case DataCommandOutcomeUnknown():
          await _recordPending(
            verifiedOwner.uid,
            userId: userId,
            username: username,
            action: BlacklistPendingAction.remove,
            status: BlacklistPendingStatus.needsVerification,
          );
          return BlacklistRemoveOutcome.outcomeUnknown;
      }
    } on Object {
      await _recordPending(
        verifiedOwner.uid,
        userId: userId,
        username: username,
        action: BlacklistPendingAction.remove,
        status: BlacklistPendingStatus.needsVerification,
      );
      return BlacklistRemoveOutcome.outcomeUnknown;
    }
  }

  /// Cancels a local pending add/remove intent without touching the server.
  Future<void> cancelPendingMutation(String userId) async {
    final activeUid =
        ref.read(verifiedSessionOwnerProvider)?.uid ??
        ref.read(blacklistSessionUidProvider)?.uid;
    if (activeUid == null) {
      return;
    }
    await ref
        .read(blacklistPendingControllerProvider.notifier)
        .removeUser(activeUid, userId.trim());
  }

  /// Explicitly retries one pending mutation triggered by the user.
  Future<void> retryPendingMutation(BlacklistPendingMutation mutation) async {
    switch (mutation.action) {
      case BlacklistPendingAction.add:
        await addUser(
          userId: mutation.userId,
          username: mutation.username,
          allowRetryPending: true,
        );
      case BlacklistPendingAction.remove:
        await removeUser(
          userId: mutation.userId,
          username: mutation.username,
          allowRetryPending: true,
        );
    }
  }

  /// Reconciles pending mutations with a read-only refresh and then flushes
  /// only [BlacklistPendingStatus.queued] mutations (never auto-resending
  /// [BlacklistPendingStatus.needsVerification]).
  Future<void> flushQueuedMutations() {
    final existing = _flushInFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<void> run;
    run = _flushQueuedMutations().whenComplete(() {
      if (identical(_flushInFlight, run)) {
        _flushInFlight = null;
      }
    });
    _flushInFlight = run;
    return run;
  }

  Future<void> _flushQueuedMutations() async {
    final owner = ref.read(verifiedSessionOwnerProvider);
    if (owner == null) {
      return;
    }
    final initialPending = (await _currentPendingSnapshot()).mutationsFor(
      owner.uid,
    );
    if (initialPending.isEmpty) {
      return;
    }
    final refreshOutcome = await refresh(force: true);
    if (!ref.mounted ||
        ref.read(verifiedSessionOwnerProvider) != owner ||
        refreshOutcome != BlacklistSyncOutcome.success) {
      return;
    }
    final remaining = (await _currentPendingSnapshot())
        .mutationsFor(owner.uid)
        .where((item) => item.status == BlacklistPendingStatus.queued)
        .toList(growable: false);
    for (final mutation in remaining) {
      if (!ref.mounted || ref.read(verifiedSessionOwnerProvider) != owner) {
        return;
      }
      if (mutation.action == BlacklistPendingAction.add) {
        final outcome = await addUser(
          userId: mutation.userId,
          username: mutation.username,
          allowRetryPending: true,
        );
        if (outcome == BlacklistAddOutcome.notLoggedIn ||
            outcome == BlacklistAddOutcome.queued ||
            outcome == BlacklistAddOutcome.stale) {
          return;
        }
      } else {
        final outcome = await removeUser(
          userId: mutation.userId,
          username: mutation.username,
          allowRetryPending: true,
        );
        if (outcome == BlacklistRemoveOutcome.notLoggedIn ||
            outcome == BlacklistRemoveOutcome.queued ||
            outcome == BlacklistRemoveOutcome.stale) {
          return;
        }
      }
    }
  }

  Future<void> _recordPending(
    String ownerUid, {
    required String userId,
    required String username,
    required BlacklistPendingAction action,
    required BlacklistPendingStatus status,
  }) {
    return ref
        .read(blacklistPendingControllerProvider.notifier)
        .recordMutation(
          ownerUid,
          BlacklistPendingMutation(
            userId: userId,
            username: username,
            action: action,
            status: status,
            updatedAt: ref.read(blacklistClockProvider)(),
          ),
        );
  }

  Future<BlacklistPendingSnapshot> _currentPendingSnapshot() async {
    final pendingState = ref.read(blacklistPendingControllerProvider);
    final value = pendingState.value;
    if (value != null) {
      return value;
    }
    try {
      return await ref.read(blacklistPendingControllerProvider.future);
    } catch (_) {
      return BlacklistPendingSnapshot.empty;
    }
  }

  Future<void> _reconcileAfterWrite() async {
    final existing = _inFlight;
    if (existing != null) {
      try {
        await existing;
      } catch (_) {
        // A failed older read must not block the reconciliation read.
      }
    }
    if (!ref.mounted) return;
    await refresh(force: true);
  }

  Future<BlacklistSnapshot> _currentSnapshot() async {
    final value = state.value;
    if (value != null) {
      return value;
    }
    try {
      final loaded = await future;
      if (!ref.mounted) {
        return BlacklistSnapshot.empty;
      }
      return loaded;
    } catch (_) {
      return BlacklistSnapshot.empty;
    }
  }
}

final blacklistSyncControllerProvider =
    AsyncNotifierProvider<BlacklistSyncController, BlacklistSnapshot>(
      BlacklistSyncController.new,
    );

/// The current verified owner's last successful list, if any.
final currentBlacklistAccountProvider = Provider<BlacklistAccountSnapshot?>((
  ref,
) {
  final identity = ref.watch(blacklistSessionUidProvider);
  if (identity == null) {
    return null;
  }
  return ref
      .watch(blacklistSyncControllerProvider)
      .value
      ?.accountFor(identity.uid);
});

/// Pending local web-blacklist mutations for the current account.
final currentBlacklistPendingMutationsProvider =
    Provider<List<BlacklistPendingMutation>>((ref) {
      final identity = ref.watch(blacklistSessionUidProvider);
      if (identity == null) {
        return const <BlacklistPendingMutation>[];
      }
      return ref
              .watch(blacklistPendingControllerProvider)
              .value
              ?.mutationsFor(identity.uid) ??
          const <BlacklistPendingMutation>[];
    });

/// Blacklisted author ids for the current verified owner, including local
/// pending additions and excluding local pending removals.
final blacklistedUserIdsProvider = Provider<Set<String>>((ref) {
  final account = ref.watch(currentBlacklistAccountProvider);
  final pending = ref.watch(currentBlacklistPendingMutationsProvider);
  if ((account == null || account.members.isEmpty) && pending.isEmpty) {
    return const <String>{};
  }
  final effective = <String>{
    if (account != null)
      for (final member in account.members) member.userId,
  };
  for (final mutation in pending) {
    if (mutation.action == BlacklistPendingAction.add) {
      effective.add(mutation.userId);
    } else {
      effective.remove(mutation.userId);
    }
  }
  return Set<String>.unmodifiable(effective);
});
