import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';

/// Result of one explicit or automatic web-blacklist synchronization.
enum BlacklistSyncOutcome { success, noOwner, cancelled, stale, failure }

/// Per-account web-blacklist snapshots.
///
/// Reads only run for a verified session owner. Results are discarded when the
/// owner or its session revision changes, and failures leave the last
/// successful list untouched. An explicitly empty validated list publishes an
/// empty account snapshot instead of being treated as a failure.
final class BlacklistSyncController extends AsyncNotifier<BlacklistSnapshot> {
  static const Duration staleAfter = Duration(hours: 6);

  Future<BlacklistSyncOutcome>? _inFlight;

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
