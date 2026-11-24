import 'package:y300/features/blacklist/domain/models/blacklist_pending_mutation.dart';

abstract interface class BlacklistPendingRepository {
  Future<BlacklistPendingSnapshot> load();

  Future<void> save(BlacklistPendingSnapshot snapshot);
}
