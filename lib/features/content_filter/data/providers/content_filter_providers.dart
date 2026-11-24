import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/content_filter/data/repositories/shared_preferences_blocked_keyword_repository.dart';
import 'package:y300/features/content_filter/data/repositories/shared_preferences_blocked_thread_repository.dart';
import 'package:y300/features/content_filter/data/repositories/shared_preferences_keyword_filter_preferences_repository.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_keyword_repository.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_thread_repository.dart';
import 'package:y300/features/content_filter/domain/repositories/keyword_filter_preferences_repository.dart';

final blockedThreadRepositoryProvider = Provider<BlockedThreadRepository>((
  ref,
) {
  return SharedPreferencesBlockedThreadRepository(
    ref.watch(preferencesStoreProvider),
  );
});

/// Test seam for rule timestamps; production uses the wall clock.
final blockedThreadClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final blockedKeywordRepositoryProvider = Provider<BlockedKeywordRepository>((
  ref,
) {
  return SharedPreferencesBlockedKeywordRepository(
    ref.watch(preferencesStoreProvider),
  );
});

final keywordFilterPreferencesRepositoryProvider =
    Provider<KeywordFilterPreferencesRepository>((ref) {
      return SharedPreferencesKeywordFilterPreferencesRepository(
        ref.watch(preferencesStoreProvider),
      );
    });

/// Test seam for keyword rule timestamps; production uses the wall clock.
final blockedKeywordClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
