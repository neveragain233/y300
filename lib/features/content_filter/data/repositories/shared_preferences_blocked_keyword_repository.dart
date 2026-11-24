import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_keyword_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_keyword_repository.dart';

final class SharedPreferencesBlockedKeywordRepository
    implements BlockedKeywordRepository {
  const SharedPreferencesBlockedKeywordRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<List<BlockedKeyword>> load() async {
    return BlockedKeywordSnapshotCodec.decode(
      await _store.read(PreferenceKeys.contentFilterBlockedKeywordsV1),
    );
  }

  @override
  Future<void> save(List<BlockedKeyword> keywords) {
    return _store.write(
      PreferenceKeys.contentFilterBlockedKeywordsV1,
      BlockedKeywordSnapshotCodec.encode(keywords),
    );
  }
}
