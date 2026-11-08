import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_thread_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_thread_repository.dart';

final class SharedPreferencesBlockedThreadRepository
    implements BlockedThreadRepository {
  const SharedPreferencesBlockedThreadRepository(this._store);

  final PreferencesStore _store;

  @override
  Future<List<BlockedThread>> load() async {
    return BlockedThreadSnapshotCodec.decode(
      await _store.read(PreferenceKeys.contentFilterBlockedThreadsV1),
    );
  }

  @override
  Future<void> save(List<BlockedThread> threads) {
    return _store.write(
      PreferenceKeys.contentFilterBlockedThreadsV1,
      BlockedThreadSnapshotCodec.encode(threads),
    );
  }
}
