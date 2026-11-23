import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';

enum ActiveReaderModule { comic, novel }

typedef ActiveReaderTarget = ({
  ActiveReaderModule module,
  String workId,
  String episodeId,
});

final activeReaderSessionsProvider = Provider<ActiveReaderSessions>(
  (ref) => ActiveReaderSessions(ref.watch(preferencesStoreProvider)),
);
final restoreReaderPreferenceProvider =
    AsyncNotifierProvider<RestoreReaderPreference, bool>(
      RestoreReaderPreference.new,
    );

class RestoreReaderPreference extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref
          .watch(preferencesStoreProvider)
          .read(PreferenceKeys.restoreReader) ??
      false;

  Future<void> set(bool enabled) async {
    await ref
        .read(preferencesStoreProvider)
        .write(PreferenceKeys.restoreReader, enabled);
    if (!enabled) await ref.read(activeReaderSessionsProvider).reset();
    state = AsyncData(enabled);
  }
}

/// 标记写入与消费共用一个队列；旧页面释放时不能清掉新页面的章节。
class ActiveReaderSessions {
  ActiveReaderSessions(this._store);
  final PreferencesStore _store;
  Future<void> _tail = Future.value();
  Object? _owner;
  ActiveReaderTarget? _target;
  bool _consumed = false;

  Future<T> _queue<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> activate(
    Object owner,
    ActiveReaderTarget target, {
    bool refresh = false,
  }) {
    if (!refresh && identical(owner, _owner) && target == _target) return _tail;
    _owner = owner;
    _target = target;
    return _queue(() async {
      try {
        await _store.write(
          PreferenceKeys.activeReader,
          jsonEncode({
            'module': target.module.name,
            'workId': target.workId,
            'episodeId': target.episodeId,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          }),
        );
      } catch (_) {
        if (identical(owner, _owner) && target == _target) _target = null;
        rethrow;
      }
    });
  }

  Future<void> release(Object owner) =>
      identical(owner, _owner) ? reset() : Future.value();

  Future<void> reset() {
    _owner = null;
    _target = null;
    return _queue(() => _store.remove(PreferenceKeys.activeReader));
  }

  Future<ActiveReaderTarget?> consume() => _queue(() async {
    if (_consumed || _owner != null) return null;
    _consumed = true;
    final raw = await _store.read(PreferenceKeys.activeReader);
    if (raw == null) return null;
    await _store.remove(PreferenceKeys.activeReader);
    try {
      if (jsonDecode(raw) case {
        'module': final String name,
        'workId': final String work,
        'episodeId': final String episode,
      }) {
        final module = ActiveReaderModule.values
            .where((m) => m.name == name)
            .firstOrNull;
        if (module != null &&
            work.trim().isNotEmpty &&
            episode.trim().isNotEmpty) {
          return (module: module, workId: work, episodeId: episode);
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  });
}
