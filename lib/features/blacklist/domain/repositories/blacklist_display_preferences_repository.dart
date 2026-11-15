import '../models/blacklist_display_preferences.dart';

abstract interface class BlacklistDisplayPreferencesRepository {
  Future<BlacklistDisplayPreferences> load();

  Future<void> save(BlacklistDisplayPreferences preferences);
}
