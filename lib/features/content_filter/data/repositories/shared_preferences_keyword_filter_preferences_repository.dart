import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/repositories/keyword_filter_preferences_repository.dart';

final class SharedPreferencesKeywordFilterPreferencesRepository
    implements KeywordFilterPreferencesRepository {
  const SharedPreferencesKeywordFilterPreferencesRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<KeywordFilterPreferences> load() async {
    final hide =
        await _store.read(
          PreferenceKeys.contentFilterHideKeywordThreadsInListsV1,
        ) ??
        true;
    return KeywordFilterPreferences(hideMatchingThreadsInLists: hide);
  }

  @override
  Future<void> save(KeywordFilterPreferences preferences) {
    return _store.write(
      PreferenceKeys.contentFilterHideKeywordThreadsInListsV1,
      preferences.hideMatchingThreadsInLists,
    );
  }
}
