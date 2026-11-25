import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/content_filter/application/whitelisted_users_controller.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/whitelisted_user.dart';

class _MemoryPreferencesStore implements PreferencesStore {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async {
    final value = _values[key.name];
    return value is T ? value : null;
  }

  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async =>
      _values.containsKey(key.name);

  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    _values[key.name] = value;
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {
    _values.remove(key.name);
  }
}

void main() {
  group('WhitelistedUsersController', () {
    test(
      'adds, validates, removes, undoes, and imports whitelisted users',
      () async {
        final store = _MemoryPreferencesStore();
        var tick = DateTime.utc(2026, 11, 25, 10, 0);
        final container = ProviderContainer(
          overrides: [
            preferencesStoreProvider.overrideWithValue(store),
            whitelistedUserClockProvider.overrideWithValue(() {
              tick = tick.add(const Duration(seconds: 1));
              return tick;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(whitelistedUsersControllerProvider.future);
        final controller = container.read(
          whitelistedUsersControllerProvider.notifier,
        );

        final invalid = await controller.add(uid: 'abc', username: 'bad');
        expect(invalid.status, WhitelistedUserMutationStatus.invalidUid);

        final created = await controller.add(uid: ' 12345 ', username: 'Alice');
        expect(created.status, WhitelistedUserMutationStatus.created);
        expect(created.entry?.uid, '12345');
        expect(container.read(whitelistedUserIdsProvider), <String>{'12345'});

        final duplicate = await controller.add(uid: '12345', username: 'Other');
        expect(duplicate.status, WhitelistedUserMutationStatus.alreadyExists);

        expect(await controller.remove('12345'), isTrue);
        expect(container.read(whitelistedUserIdsProvider), isEmpty);

        expect(await controller.undoRemove(created.entry!), isTrue);
        expect(container.read(whitelistedUserIdsProvider), <String>{'12345'});

        final incoming = <WhitelistedUser>[
          WhitelistedUser(
            uid: '12345',
            username: 'Dup',
            createdAt: DateTime.utc(2026, 11, 25),
            updatedAt: DateTime.utc(2026, 11, 25),
          ),
          WhitelistedUser(
            uid: '67890',
            username: 'Bob',
            createdAt: DateTime.utc(2026, 11, 25, 11),
            updatedAt: DateTime.utc(2026, 11, 25, 11),
          ),
        ];

        final (importedMerge, skippedMerge) = await controller.importEntries(
          incoming,
          replace: false,
        );
        expect(importedMerge, 1);
        expect(skippedMerge, 1);
        expect(container.read(whitelistedUserIdsProvider), <String>{
          '12345',
          '67890',
        });

        final (importedReplace, skippedReplace) = await controller
            .importEntries(<WhitelistedUser>[incoming.last], replace: true);
        expect(importedReplace, 1);
        expect(skippedReplace, 0);
        expect(container.read(whitelistedUserIdsProvider), <String>{'67890'});
      },
    );

    test('whitelistedUserIdsProvider excludes users present in blacklistedUserIdsProvider (deny-overrides)', () async {
      final store = _MemoryPreferencesStore();
      final container = ProviderContainer(
        overrides: [
          preferencesStoreProvider.overrideWithValue(store),
          blacklistedUserIdsProvider.overrideWithValue(const <String>{'12345'}),
        ],
      );
      addTearDown(container.dispose);

      await container.read(whitelistedUsersControllerProvider.future);
      final controller = container.read(
        whitelistedUsersControllerProvider.notifier,
      );
      await controller.add(uid: '12345', username: 'Conflicted');
      await controller.add(uid: '67890', username: 'Allowed');

      expect(container.read(whitelistedUserIdsProvider), <String>{'67890'});
    });
  });
}
