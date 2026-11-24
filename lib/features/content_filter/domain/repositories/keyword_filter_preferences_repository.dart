import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

abstract interface class KeywordFilterPreferencesRepository {
  Future<KeywordFilterPreferences> load();

  Future<void> save(KeywordFilterPreferences preferences);
}
