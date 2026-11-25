import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/application/content_filter_exemptions.dart';

final class _MemoryPreferencesStore implements PreferencesStore {
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
  group('isStickyForumThread', () {
    test('detects sticky badges and ignores non-sticky threads', () {
      final stickyByBadges = ForumThreadSummary(
        tid: '1',
        subject: 'Sticky',
        author: 'Mod',
        replies: 0,
        views: 1,
        dateline: 'today',
        badges: const <ForumThreadBadge>[
          ForumThreadBadge(
            kind: ForumThreadBadgeKind.sticky,
            sourceLabel: '置顶',
          ),
        ],
      );
      final stickyByLegacyLabel = ForumThreadSummary(
        tid: '2',
        subject: 'Sticky legacy',
        author: 'Mod',
        replies: 0,
        views: 1,
        dateline: 'today',
        badgeLabel: '置顶',
      );
      final normal = ForumThreadSummary(
        tid: '3',
        subject: 'Normal',
        author: 'User',
        replies: 0,
        views: 1,
        dateline: 'today',
      );

      expect(isStickyForumThread(stickyByBadges), isTrue);
      expect(isStickyForumThread(stickyByLegacyLabel), isTrue);
      expect(isStickyForumThread(normal), isFalse);
    });
  });

  group('KnownSubForumIdsController', () {
    test(
      'records, deduplicates, persists, and hydrates subforum fids',
      () async {
        final store = _MemoryPreferencesStore();
        final container = ProviderContainer(
          overrides: [preferencesStoreProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);

        expect(container.read(exemptSubForumIdsProvider), isEmpty);

        container.read(exemptSubForumIdsProvider.notifier).recordAll(<String>[
          ' 12 ',
          '',
          '18',
          '12',
        ]);
        container.read(exemptSubForumIdsProvider.notifier).record('25');

        expect(container.read(exemptSubForumIdsProvider), <String>{
          '12',
          '18',
          '25',
        });

        // Allow async persistence to flush.
        await Future<void>.delayed(Duration.zero);

        final rehydrated = ProviderContainer(
          overrides: [preferencesStoreProvider.overrideWithValue(store)],
        );
        addTearDown(rehydrated.dispose);

        expect(rehydrated.read(exemptSubForumIdsProvider), isEmpty);
        await Future<void>.delayed(Duration.zero);
        expect(rehydrated.read(exemptSubForumIdsProvider), <String>{
          '12',
          '18',
          '25',
        });
      },
    );
  });
}
