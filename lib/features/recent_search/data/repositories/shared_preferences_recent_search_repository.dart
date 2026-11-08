import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/recent_search/data/codecs/recent_search_snapshot_codec.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';
import 'package:y300/features/recent_search/domain/repositories/recent_search_repository.dart';

final class SharedPreferencesRecentSearchRepository
    implements RecentSearchRepository {
  const SharedPreferencesRecentSearchRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<RecentSearchSnapshot> load() async {
    return RecentSearchSnapshotCodec.decode(
      await _store.read(PreferenceKeys.recentSearchSnapshotV1),
    );
  }

  @override
  Future<void> save(RecentSearchSnapshot snapshot) {
    return _store.write(
      PreferenceKeys.recentSearchSnapshotV1,
      RecentSearchSnapshotCodec.encode(snapshot),
    );
  }
}
