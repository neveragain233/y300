import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';

/// Device persistence boundary for per-account web-blacklist snapshots.
abstract interface class BlacklistRepository {
  Future<BlacklistSnapshot> load();

  Future<void> save(BlacklistSnapshot snapshot);
}
