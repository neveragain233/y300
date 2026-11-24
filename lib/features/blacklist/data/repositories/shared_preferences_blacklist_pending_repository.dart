import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_pending_mutation_codec.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_pending_mutation.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_pending_repository.dart';

final class SharedPreferencesBlacklistPendingRepository
    implements BlacklistPendingRepository {
  const SharedPreferencesBlacklistPendingRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<BlacklistPendingSnapshot> load() async {
    return BlacklistPendingMutationCodec.decode(
      await _store.read(PreferenceKeys.contentFilterWebBlacklistPendingV1),
    );
  }

  @override
  Future<void> save(BlacklistPendingSnapshot snapshot) {
    return _store.write(
      PreferenceKeys.contentFilterWebBlacklistPendingV1,
      BlacklistPendingMutationCodec.encode(snapshot),
    );
  }
}
