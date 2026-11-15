import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_display_preferences.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_display_preferences_repository.dart';

final class SharedPreferencesBlacklistDisplayPreferencesRepository
    implements BlacklistDisplayPreferencesRepository {
  const SharedPreferencesBlacklistDisplayPreferencesRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<BlacklistDisplayPreferences> load() async {
    final hide =
        await _store.read(PreferenceKeys.blacklistHideInitiatedThreadsV1) ??
        false;
    return BlacklistDisplayPreferences(
      hideThreadsStartedByBlacklistedUsers: hide,
    );
  }

  @override
  Future<void> save(BlacklistDisplayPreferences preferences) {
    return _store.write(
      PreferenceKeys.blacklistHideInitiatedThreadsV1,
      preferences.hideThreadsStartedByBlacklistedUsers,
    );
  }
}
