import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_client_provider.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/blacklist/data/repositories/shared_preferences_blacklist_repository.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_repository.dart';

final blacklistRepositoryProvider = Provider<BlacklistRepository>((ref) {
  return SharedPreferencesBlacklistRepository(
    ref.watch(preferencesStoreProvider),
  );
});

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
  var _revision = 0;

  @override
  BlacklistSessionIdentity? build() {
    final store = ref.watch(yamiboSessionStoreProvider);
    final subscription = store.identityChanges.listen((_) {
      _update(store);
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    final uid = _read(store);
    return uid == null ? null : (uid: uid, revision: _revision);
  }

  void _update(YamiboSessionStore store) {
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
    return RegExp(r'^[1-9]\d{0,19}$').hasMatch(uid) ? uid : null;
  }
}
