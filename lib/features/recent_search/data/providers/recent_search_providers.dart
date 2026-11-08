import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/recent_search/data/repositories/shared_preferences_recent_search_repository.dart';
import 'package:y300/features/recent_search/domain/repositories/recent_search_repository.dart';

final recentSearchRepositoryProvider = Provider<RecentSearchRepository>((ref) {
  return SharedPreferencesRecentSearchRepository(
    ref.watch(preferencesStoreProvider),
  );
});

/// Test seam for keyword timestamps; production uses the wall clock.
final recentSearchClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
