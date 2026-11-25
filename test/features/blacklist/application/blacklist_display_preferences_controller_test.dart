import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';

void main() {
  test('hiding blacklisted threads is off by default', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final preferences = await container.read(
      blacklistDisplayPreferencesControllerProvider.future,
    );
    expect(preferences.hideThreadsStartedByBlacklistedUsers, isFalse);
    expect(container.read(hideBlacklistedThreadsProvider), isFalse);
  });

  test('a saved preference survives a new controller', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'blacklist.hide_initiated_threads.v1': true,
    });
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    expect(
      (await container.read(
        blacklistDisplayPreferencesControllerProvider.future,
      )).hideThreadsStartedByBlacklistedUsers,
      isTrue,
    );
    expect(container.read(hideBlacklistedThreadsProvider), isTrue);
  });

  test('toggling persists and publishes immediately', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer.test();
    addTearDown(container.dispose);
    await container.read(blacklistDisplayPreferencesControllerProvider.future);
    final controller = container.read(
      blacklistDisplayPreferencesControllerProvider.notifier,
    );

    expect(
      await controller.setHideThreadsStartedByBlacklistedUsers(true),
      isTrue,
    );
    expect(container.read(hideBlacklistedThreadsProvider), isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('blacklist.hide_initiated_threads.v1'), isTrue);
  });

  test('a failed save restores the last successful value', () async {
    final store = _FailingSaveStore();
    final container = ProviderContainer.test(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(blacklistDisplayPreferencesControllerProvider.future);
    final controller = container.read(
      blacklistDisplayPreferencesControllerProvider.notifier,
    );

    expect(
      await controller.setHideThreadsStartedByBlacklistedUsers(true),
      isFalse,
    );
    expect(container.read(hideBlacklistedThreadsProvider), isFalse);
    expect(store.writes, isNotEmpty);
  });
}

final class _FailingSaveStore implements PreferencesStore {
  final writes = <Object>[];

  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async => null;

  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async => false;

  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    writes.add(value);
    throw StateError('fixture');
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {}
}
