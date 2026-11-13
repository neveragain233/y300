import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/thread_controls_preferences_providers.dart';
import '../domain/models/thread_controls_preferences.dart';

final threadControlsPreferencesControllerProvider =
    AsyncNotifierProvider<
      ThreadControlsPreferencesController,
      ThreadControlsPreferences
    >(ThreadControlsPreferencesController.new);

final class ThreadControlsPreferencesController
    extends AsyncNotifier<ThreadControlsPreferences> {
  Future<void> _writes = Future<void>.value();
  ThreadControlsPreferences _saved = const ThreadControlsPreferences();
  int _revision = 0;

  @override
  Future<ThreadControlsPreferences> build() async {
    try {
      return _saved = await ref
          .watch(threadControlsPreferencesRepositoryProvider)
          .load();
    } on Object {
      return _saved = const ThreadControlsPreferences();
    }
  }

  Future<bool> savePreferences(ThreadControlsPreferences preferences) {
    if (state.value == null) return Future.value(false);
    final repository = ref.read(threadControlsPreferencesRepositoryProvider);
    final revision = ++_revision;
    state = AsyncData(preferences);
    final result = _writes.then((_) async {
      try {
        await repository.save(preferences);
        _saved = preferences;
        return true;
      } on Object {
        try {
          await repository.save(_saved);
        } on Object {
          // 保留最近成功值，下一次明确设置仍沿串行队列提交。
        }
        if (ref.mounted && revision == _revision) {
          state = AsyncData(_saved);
          return false;
        }
        return true;
      }
    });
    _writes = result.then<void>((_) {});
    return result;
  }
}
