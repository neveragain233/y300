import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';

/// Result of one explicit or automatic web-blacklist synchronization.
enum BlacklistSyncOutcome { success, noOwner, cancelled, stale, failure }

/// Result of adding one user to the account's web blacklist.
enum BlacklistAddOutcome {
  applied,
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

/// Per-account web-blacklist snapshots.
///
/// Reads only run for a verified session owner. Results are discarded when the
/// owner or its session revision changes, and failures leave the last
/// successful list untouched. An explicitly empty validated list publishes an
/// empty account snapshot instead of being treated as a failure.
final class BlacklistSyncController extends AsyncNotifier<BlacklistSnapshot> {
  static const Duration staleAfter = Duration(hours: 6);

  Future<BlacklistSyncOutcome>? _inFlight;
  final _addInFlight = <String, Future<BlacklistAddOutcome>>{};
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
  /// Repeated requests for the same target share one command. A confirmed
  /// member is merged into the account snapshot before the full reconciliation
  /// read, so list filtering and thread gates react immediately.
  Future<BlacklistAddOutcome> addUser({
    required String userId,
    required String username,
  }) {
    final key = userId.trim();
    final existing = _addInFlight[key];
    if (existing != null) return existing;
    late final Future<BlacklistAddOutcome> run;
    run = _addUser(userId: key, username: username).whenComplete(() {
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
  }) async {
    final owner = ref.read(verifiedSessionOwnerProvider);
    if (owner == null) return BlacklistAddOutcome.notLoggedIn;
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(userId) ||
        username.isEmpty ||
        username.trim() != username) {
      return BlacklistAddOutcome.invalidTarget;
    }
    if (owner.uid == userId) return BlacklistAddOutcome.self;
    final current = await _currentSnapshot();
    final account = current.accountFor(owner.uid);
    if (account?.members.any((member) => member.userId == userId) ?? false) {
      return BlacklistAddOutcome.alreadyListed;
    }
    if (!ref.read(blacklistAddSupportedProvider)) {
      return BlacklistAddOutcome.unsupported;
    }
    try {
      final result = await ref.read(blacklistAddCommandProvider)(
        ForumBlacklistAddSubmission(userId: userId, username: username),
      );
      if (!ref.mounted || ref.read(verifiedSessionOwnerProvider) != owner) {
        return BlacklistAddOutcome.stale;
      }
      switch (result) {
        case DataCommandApplied(:final receipt):
          final applied = receipt;
          _writeRevision++;
          final latest = await _currentSnapshot();
          if (!ref.mounted || ref.read(verifiedSessionOwnerProvider) != owner) {
            return BlacklistAddOutcome.stale;
          }
          final latestAccount = latest.accountFor(owner.uid);
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
              ownerUid: owner.uid,
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
          if (!ref.mounted || ref.read(verifiedSessionOwnerProvider) != owner) {
            return BlacklistAddOutcome.stale;
          }
          state = AsyncData(next);
          unawaited(_reconcileAfterWrite());
          return BlacklistAddOutcome.applied;
        case DataCommandRejected(:final failure):
          return failure.kind == DataCommandFailureKind.unauthenticated
              ? BlacklistAddOutcome.notLoggedIn
              : BlacklistAddOutcome.rejected;
        case DataCommandNotSent(:final failure):
          return switch (failure.kind) {
            DataCommandFailureKind.unauthenticated =>
              BlacklistAddOutcome.notLoggedIn,
            DataCommandFailureKind.validation =>
              BlacklistAddOutcome.invalidTarget,
            DataCommandFailureKind.cancelled => BlacklistAddOutcome.cancelled,
            _ => BlacklistAddOutcome.rejected,
          };
        case DataCommandUnsupported():
          return BlacklistAddOutcome.unsupported;
        case DataCommandOutcomeUnknown():
          return BlacklistAddOutcome.outcomeUnknown;
      }
    } on Object {
      return BlacklistAddOutcome.outcomeUnknown;
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

/// Blacklisted author ids for the current verified owner.
final blacklistedUserIdsProvider = Provider<Set<String>>((ref) {
  final account = ref.watch(currentBlacklistAccountProvider);
  if (account == null || account.members.isEmpty) {
    return const <String>{};
  }
  return Set<String>.unmodifiable(
    account.members.map((member) => member.userId),
  );
});
