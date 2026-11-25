import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_client_provider.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/profile/presentation/account_display_controller.dart';

/// Test seam for sync timestamps; production uses the wall clock.
final blacklistClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

typedef BlacklistRemoteLoader =
    Future<DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>>
    Function(ForumBlacklistQuery query);

/// Test seam for the authenticated web-blacklist read.
final blacklistRemoteLoaderProvider = Provider<BlacklistRemoteLoader>((ref) {
  return (query) => ref.read(yamiboForumClientProvider).loadBlacklist(query);
});

typedef BlacklistAddRemoteCommand =
    Future<DataCommandResult<ForumBlacklistAddReceipt>> Function(
      ForumBlacklistAddSubmission submission,
    );

/// Test seam for the authenticated web-blacklist add command.
final blacklistAddCommandProvider = Provider<BlacklistAddRemoteCommand>((ref) {
  return (submission) =>
      ref.read(yamiboForumClientProvider).addToBlacklist(submission);
});

/// Whether the configured forum client can add blacklist members.
final blacklistAddSupportedProvider = Provider<bool>((ref) {
  return ref.watch(yamiboForumClientProvider).friendBlacklistCommand != null;
});

typedef BlacklistRemoveRemoteCommand =
    Future<DataCommandResult<ForumBlacklistRemoveReceipt>> Function(
      ForumBlacklistRemoveSubmission submission,
    );

/// Test seam for the authenticated web-blacklist remove command.
final blacklistRemoveCommandProvider = Provider<BlacklistRemoveRemoteCommand>((
  ref,
) {
  return (submission) =>
      ref.read(yamiboForumClientProvider).removeFromBlacklist(submission);
});

/// Whether the configured forum client can remove blacklist members.
final blacklistRemoveSupportedProvider = Provider<bool>((ref) {
  return ref.watch(yamiboForumClientProvider).friendBlacklistRemoveCommand !=
      null;
});

/// Whether a stale snapshot may be refreshed without an explicit request.
final blacklistAutoSyncProvider = Provider<bool>((ref) => true);

/// Current account and local login generation from the cookie session.
typedef BlacklistSessionIdentity = ({String uid, int revision});

/// Display filtering uses this synchronous identity so ordinary forum pages do
/// not start an authentication request just to read the blacklist. Every sync
/// is still gated by the verified session owner.
final blacklistSessionUidProvider =
    NotifierProvider<_BlacklistSessionUidNotifier, BlacklistSessionIdentity?>(
      _BlacklistSessionUidNotifier.new,
    );

final class _BlacklistSessionUidNotifier
    extends Notifier<BlacklistSessionIdentity?> {
  static final RegExp _positiveUserId = RegExp(r'^[1-9]\d{0,19}$');
  var _revision = 0;
  var _generation = 0;

  @override
  BlacklistSessionIdentity? build() {
    final store = ref.watch(yamiboSessionStoreProvider);
    final prefs = ref.watch(preferencesStoreProvider);
    final subscription = store.identityChanges.listen((_) {
      _update(store);
    });
    ref.onDispose(() {
      _generation++;
      unawaited(subscription.cancel());
    });
    final uid = _read(store);
    if (uid != null) {
      return (uid: uid, revision: _revision);
    }
    // Cold start or slow/DDoS network: fall back to the locally persisted
    // account pointer without triggering an auth network request.
    if (store.readCurrent() == null) {
      final generation = _generation;
      unawaited(
        Future<void>.microtask(() async {
          try {
            final persisted = await prefs.read(
              AccountDisplayController.storageKey,
            );
            if (!ref.mounted || generation != _generation) {
              return;
            }
            if (store.readCurrent() != null) {
              return;
            }
            final normalized = persisted?.trim() ?? '';
            if (_positiveUserId.hasMatch(normalized) &&
                state?.uid != normalized) {
              _revision++;
              state = (uid: normalized, revision: _revision);
            }
          } catch (_) {
            // Missing or unavailable preferences leave state unauthenticated.
          }
        }),
      );
    }
    return null;
  }

  void _update(YamiboSessionStore store) {
    _generation++;
    final uid = _read(store);
    if (uid == null) {
      state = null;
      return;
    }
    _revision++;
    state = (uid: uid, revision: _revision);
  }

  String? _read(YamiboSessionStore store) {
    final snapshot = store.readCurrent();
    if (snapshot == null || !snapshot.isLoggedIn) {
      return null;
    }
    final uid = snapshot.uid.trim();
    return _positiveUserId.hasMatch(uid) ? uid : null;
  }
}
