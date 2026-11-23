import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/reader_shared/application/active_reader_session.dart';

void main() {
  test('late disposal preserves the newly active reader and consumes its last chapter once', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesStore();
    final sessions = ActiveReaderSessions(store);
    final old = Object();
    final current = Object();
    const novel = (
      module: ActiveReaderModule.novel,
      workId: 'n',
      episodeId: 'n1',
    );
    const comic = (
      module: ActiveReaderModule.comic,
      workId: 'c',
      episodeId: 'c2',
    );
    await Future.wait([
      sessions.activate(old, novel),
      sessions.activate(current, comic),
      sessions.release(old),
    ]);
    final saved =
        jsonDecode((await store.read(PreferenceKeys.activeReader))!) as Map;
    expect(
      saved.keys,
      unorderedEquals(['module', 'workId', 'episodeId', 'updatedAt']),
    );
    final nextProcess = ActiveReaderSessions(store);
    expect(await nextProcess.consume(), comic);
    expect(await nextProcess.consume(), isNull);
    await sessions.activate(current, comic, refresh: true);
    await sessions.release(current);
    expect(await ActiveReaderSessions(store).consume(), isNull);
  });
}
