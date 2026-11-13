import '../models/thread_controls_preferences.dart';

abstract interface class ThreadControlsPreferencesRepository {
  Future<ThreadControlsPreferences> load();
  Future<void> save(ThreadControlsPreferences preferences);
}
