import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/recent_search/application/recent_searches_controller.dart';
import 'package:y300/features/recent_search/data/codecs/recent_search_snapshot_codec.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';

void main() {
  group('RecentSearchesController', () {
    test('newest keyword first and duplicates move to the top', () async {
      final repository = _MemoryRepository();
      var clock = 1000;
      final container = _container(
        repository,
        clock: () => DateTime.fromMillisecondsSinceEpoch(clock++),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        recentSearchesControllerProvider.notifier,
      );

      await controller.record(RecentSearchScope.forum, '漫画');
      await controller.record(RecentSearchScope.forum, '小说');
      await controller.record(RecentSearchScope.forum, '漫画');

      final entries = container.read(
        recentSearchesProvider(RecentSearchScope.forum),
      );
      expect(entries.map((entry) => entry.keyword), <String>['漫画', '小说']);
    });

    test('keeps ranges separate and clears one range', () async {
      final repository = _MemoryRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        recentSearchesControllerProvider.notifier,
      );

      await controller.record(RecentSearchScope.comicShelf, '漫画词');
      await controller.record(RecentSearchScope.novelShelf, '小说词');
      await controller.clear(RecentSearchScope.comicShelf);

      expect(
        container.read(recentSearchesProvider(RecentSearchScope.comicShelf)),
        isEmpty,
      );
      expect(
        container
            .read(recentSearchesProvider(RecentSearchScope.novelShelf))
            .single
            .keyword,
        '小说词',
      );
    });

    test('bounds each range to twenty keywords', () async {
      final repository = _MemoryRepository();
      var clock = 1000;
      final container = _container(
        repository,
        clock: () => DateTime.fromMillisecondsSinceEpoch(clock++),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        recentSearchesControllerProvider.notifier,
      );

      for (var index = 0; index < 25; index += 1) {
        await controller.record(RecentSearchScope.forum, '关键词$index');
      }

      final entries = container.read(
        recentSearchesProvider(RecentSearchScope.forum),
      );
      expect(entries, hasLength(20));
      expect(entries.first.keyword, '关键词24');
      expect(entries.last.keyword, '关键词5');
    });

    test('drops the least recently used ranges beyond forty', () async {
      final repository = _MemoryRepository();
      var clock = 1000;
      final container = _container(
        repository,
        clock: () => DateTime.fromMillisecondsSinceEpoch(clock++),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        recentSearchesControllerProvider.notifier,
      );

      for (var index = 0; index < 41; index += 1) {
        final scope = RecentSearchScope.workChapters('work-$index');
        await controller.record(scope!, '第$index章');
      }

      final snapshot = container.read(recentSearchesControllerProvider).value!;
      expect(snapshot.entriesByScope, hasLength(40));
      expect(
        snapshot.entriesFor(RecentSearchScope.workChapters('work-0')!),
        isEmpty,
      );
    });
  });
}

ProviderContainer _container(
  _MemoryRepository repository, {
  DateTime Function()? clock,
}) {
  return ProviderContainer.test(
    overrides: [
      preferencesStoreProvider.overrideWithValue(repository),
      if (clock != null) recentSearchClockProvider.overrideWithValue(clock),
    ],
  );
}

final class _MemoryRepository implements PreferencesStore {
  RecentSearchSnapshot snapshot = RecentSearchSnapshot.empty;

  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async {
    if (key.name == PreferenceKeys.recentSearchSnapshotV1.name) {
      return RecentSearchSnapshotCodec.encode(snapshot) as T;
    }
    return null;
  }

  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async =>
      key.name == PreferenceKeys.recentSearchSnapshotV1.name;

  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    if (key.name == PreferenceKeys.recentSearchSnapshotV1.name && value is String) {
      snapshot = RecentSearchSnapshotCodec.decode(value);
    }
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {
    if (key.name == PreferenceKeys.recentSearchSnapshotV1.name) {
      snapshot = RecentSearchSnapshot.empty;
    }
  }
}
