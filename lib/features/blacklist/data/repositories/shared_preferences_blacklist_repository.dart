import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_repository.dart';

final class SharedPreferencesBlacklistRepository
    implements BlacklistRepository {
  const SharedPreferencesBlacklistRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<BlacklistSnapshot> load() async {
    return BlacklistSnapshotCodec.decode(
      await _store.read(PreferenceKeys.contentFilterWebBlacklistSnapshotV1),
    );
  }

  @override
  Future<void> save(BlacklistSnapshot snapshot) {
    return _store.write(
      PreferenceKeys.contentFilterWebBlacklistSnapshotV1,
      BlacklistSnapshotCodec.encode(snapshot),
    );
  }
}
