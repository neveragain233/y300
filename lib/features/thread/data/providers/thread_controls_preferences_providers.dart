import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

import '../../domain/repositories/thread_controls_preferences_repository.dart';
import '../repositories/shared_preferences_thread_controls_repository.dart';

final threadControlsPreferencesRepositoryProvider =
    Provider<ThreadControlsPreferencesRepository>((ref) {
      return SharedPreferencesThreadControlsRepository(
        ref.watch(preferencesStoreProvider),
      );
    });
