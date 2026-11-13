import 'dart:convert';

import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';

import '../../domain/models/thread_controls_preferences.dart';
import '../../domain/repositories/thread_controls_preferences_repository.dart';

final class SharedPreferencesThreadControlsRepository
    implements ThreadControlsPreferencesRepository {
  const SharedPreferencesThreadControlsRepository(this._store);
  final PreferencesStore _store;

  @override
  Future<ThreadControlsPreferences> load() async {
    final raw = await _store.read(PreferenceKeys.threadControlsV1);
    if (raw == null) {
      final side = await _store.read(PreferenceKeys.threadQuickScrollDockSide);
      return ThreadControlsPreferences(
        side: side == 'left'
            ? ThreadControlsSide.left
            : ThreadControlsSide.right,
      );
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['schemaVersion'] != 1) {
        return const ThreadControlsPreferences();
      }
      bool flag(String key, bool fallback) =>
          data[key] is bool ? data[key] as bool : fallback;
      return ThreadControlsPreferences(
        compact: flag('compact', false),
        side: data['side'] == 'left'
            ? ThreadControlsSide.left
            : ThreadControlsSide.right,
        showFavorite: flag('showFavorite', true),
        navigationEnabled: flag('navigationEnabled', true),
        singleNavigationButton: flag('singleNavigationButton', false),
        holdToFirstPost: flag('holdToFirstPost', false),
        hideOnScroll: flag('hideOnScroll', false),
      );
    } on FormatException {
      return const ThreadControlsPreferences();
    }
  }

  @override
  Future<void> save(ThreadControlsPreferences preferences) => _store.write(
    PreferenceKeys.threadControlsV1,
    jsonEncode({
      'schemaVersion': 1,
      'compact': preferences.compact,
      'side': preferences.side.name,
      'showFavorite': preferences.showFavorite,
      'navigationEnabled': preferences.navigationEnabled,
      'singleNavigationButton': preferences.singleNavigationButton,
      'holdToFirstPost': preferences.holdToFirstPost,
      'hideOnScroll': preferences.hideOnScroll,
    }),
  );
}
