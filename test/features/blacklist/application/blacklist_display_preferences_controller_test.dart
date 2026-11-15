import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_display_preferences.dart';
import 'package:y300/features/blacklist/domain/repositories/blacklist_display_preferences_repository.dart';

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
    final repository = _FailingSaveRepository();
    final container = ProviderContainer.test(
      overrides: [
        blacklistDisplayPreferencesRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
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
    expect(repository.saves, isNotEmpty);
  });
}

final class _FailingSaveRepository
    implements BlacklistDisplayPreferencesRepository {
  final saves = <BlacklistDisplayPreferences>[];

  @override
  Future<BlacklistDisplayPreferences> load() async =>
      BlacklistDisplayPreferences.defaults;

  @override
  Future<void> save(BlacklistDisplayPreferences preferences) async {
    saves.add(preferences);
    throw StateError('fixture');
  }
}
