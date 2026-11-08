import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/content_filter/data/repositories/shared_preferences_blocked_thread_repository.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_thread_repository.dart';

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
