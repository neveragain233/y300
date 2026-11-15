import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_display_preferences.dart';

final blacklistDisplayPreferencesControllerProvider =
    AsyncNotifierProvider<
      BlacklistDisplayPreferencesController,
      BlacklistDisplayPreferences
    >(BlacklistDisplayPreferencesController.new);

/// Device-local blacklist display policy with serialized persistence.
final class BlacklistDisplayPreferencesController
    extends AsyncNotifier<BlacklistDisplayPreferences> {
  Future<void> _writes = Future<void>.value();
  BlacklistDisplayPreferences _saved = BlacklistDisplayPreferences.defaults;
  int _revision = 0;

  @override
  Future<BlacklistDisplayPreferences> build() async {
    try {
      return _saved = await ref
          .watch(blacklistDisplayPreferencesRepositoryProvider)
          .load();
    } on Object {
      return _saved = BlacklistDisplayPreferences.defaults;
    }
  }

  Future<bool> setHideThreadsStartedByBlacklistedUsers(bool value) {
    final current = state.value;
    if (current == null) return Future.value(false);
    return _save(current.copyWith(hideThreadsStartedByBlacklistedUsers: value));
  }

  Future<bool> _save(BlacklistDisplayPreferences preferences) {
    final repository = ref.read(blacklistDisplayPreferencesRepositoryProvider);
    final revision = ++_revision;
    state = AsyncData(preferences);
    final result = _writes.then((_) async {
      try {
        await repository.save(preferences);
        _saved = preferences;
        return true;
      } on Object {
        try {
          await repository.save(_saved);
        } on Object {
          // Keep the last successful value; the next explicit change still
          // goes through the serialized queue.
        }
        if (ref.mounted && revision == _revision) {
          state = AsyncData(_saved);
          return false;
        }
        return true;
      }
    });
    _writes = result.then<void>((_) {});
    return result;
  }
}

/// Whether threads initiated by blacklisted authors are hidden on lists.
///
/// Missing or not-yet-loaded preferences keep the website-compatible default
/// (visible threads with collapsed floors).
final hideBlacklistedThreadsProvider = Provider<bool>((ref) {
  final preferences = ref.watch(blacklistDisplayPreferencesControllerProvider);
  return preferences.value?.hideThreadsStartedByBlacklistedUsers ?? false;
});
