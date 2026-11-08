import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';

/// Device persistence boundary for locally blocked thread rules.
abstract interface class BlockedThreadRepository {
  /// Loads all rules, newest first.
  Future<List<BlockedThread>> load();

  /// Replaces the persisted rule snapshot.
  Future<void> save(List<BlockedThread> threads);
}
