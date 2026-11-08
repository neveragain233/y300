import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';

abstract interface class RecentSearchRepository {
  Future<RecentSearchSnapshot> load();

  Future<void> save(RecentSearchSnapshot snapshot);
}
