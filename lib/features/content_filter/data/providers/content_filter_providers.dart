import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test seam for rule timestamps; production uses the wall clock.
final blockedThreadClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Test seam for keyword rule timestamps; production uses the wall clock.
final blockedKeywordClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
