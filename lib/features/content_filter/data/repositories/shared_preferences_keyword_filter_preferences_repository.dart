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
    final hideCompletely =
        await _store.read(
          PreferenceKeys.contentFilterHideBlockedKeywordThreadsCompletelyV1,
        ) ??
        false;
    return KeywordFilterPreferences(
      hideBlockedContentCompletely: hideCompletely,
    );
  }

  @override
  Future<void> save(KeywordFilterPreferences preferences) {
    return _store.write(
      PreferenceKeys.contentFilterHideBlockedKeywordThreadsCompletelyV1,
      preferences.hideBlockedContentCompletely,
    );
  }
}
