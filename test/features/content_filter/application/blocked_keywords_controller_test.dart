import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

class _MemoryPreferencesStore implements PreferencesStore {
  final Map<String, Object> _values = <String, Object>{};
  bool failNextKeywordSave = false;
  bool failNextPrefsSave = false;

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
    if (key.name == PreferenceKeys.contentFilterBlockedKeywordsV1.name &&
        failNextKeywordSave) {
      failNextKeywordSave = false;
      throw StateError('save failed');
    }
    if (key.name ==
            PreferenceKeys
                .contentFilterHideBlockedKeywordThreadsCompletelyV1
                .name &&
        failNextPrefsSave) {
      failNextPrefsSave = false;
      throw StateError('prefs save failed');
    }
    _values[key.name] = value;
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {
    _values.remove(key.name);
  }
}

void main() {
  group('BlockedKeywordsController', () {
    test('adds, deduplicates, updates scope, removes and undoes', () async {
      final store = _MemoryPreferencesStore();
      var tick = 1000;
      final container = ProviderContainer(
        overrides: [
          preferencesStoreProvider.overrideWithValue(store),
          blockedKeywordClockProvider.overrideWithValue(
            () => DateTime.fromMillisecondsSinceEpoch(tick += 1000),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(blockedKeywordsControllerProvider.future);
      final controller = container.read(
        blockedKeywordsControllerProvider.notifier,
      );

      final added = await controller.add(
        keyword: '  Spoiler  ',
        scope: BlockedKeywordScope.repliesOnly,
      );
      expect(added.status, BlockedKeywordMutationStatus.created);
      expect(added.entry!.normalizedKeyword, 'spoiler');

      final duplicate = await controller.add(
        keyword: 'SPOILER',
        scope: BlockedKeywordScope.includeBody,
      );
      expect(duplicate.status, BlockedKeywordMutationStatus.alreadyExists);

      final updated = await controller.updateRule(
        id: added.entry!.id,
        keyword: '剧透',
        scope: BlockedKeywordScope.includeBody,
      );
      expect(updated.status, BlockedKeywordMutationStatus.updated);
      expect(updated.entry!.scope, BlockedKeywordScope.includeBody);
      expect(container.read(keywordFilterRulesProvider).hasBodyRules, isTrue);

      final toggled = await controller.setEnabled(updated.entry!.id, false);
      expect(toggled, isTrue);
      expect(container.read(keywordFilterRulesProvider).hasBodyRules, isFalse);
      await controller.setEnabled(updated.entry!.id, true);

      final invalidRegex = await controller.add(
        keyword: '[unclosed',
        scope: BlockedKeywordScope.repliesOnly,
        matchType: BlockedKeywordMatchType.regex,
      );
      expect(invalidRegex.status, BlockedKeywordMutationStatus.invalidRegex);

      final allowRule = await controller.add(
        keyword: '剧透预警',
        scope: BlockedKeywordScope.repliesOnly,
        kind: BlockedKeywordKind.allow,
      );
      expect(allowRule.status, BlockedKeywordMutationStatus.created);
      expect(allowRule.entry!.scope, BlockedKeywordScope.includeBody);
      expect(
        container.read(keywordFilterRulesProvider).activeAllowRules.length,
        1,
      );

      final removed = await controller.remove(added.entry!.id);
      expect(removed, isTrue);
      expect(
        container.read(blockedKeywordsControllerProvider).value?.length,
        1,
      );

      final undone = await controller.undoRemove(updated.entry!);
      expect(undone, isTrue);
      expect(
        container.read(blockedKeywordsControllerProvider).value?.length,
        2,
      );
    });

    test('leaves existing state untouched when save fails', () async {
      final store = _MemoryPreferencesStore();
      final container = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(blockedKeywordsControllerProvider.future);
      store.failNextKeywordSave = true;

      final result = await container
          .read(blockedKeywordsControllerProvider.notifier)
          .add(keyword: 'test', scope: BlockedKeywordScope.repliesOnly);
      expect(result.status, BlockedKeywordMutationStatus.failed);
      expect(container.read(blockedKeywordsControllerProvider).value, isEmpty);

      await container.read(keywordFilterPreferencesControllerProvider.future);
      store.failNextPrefsSave = true;
      final saved = await container
          .read(keywordFilterPreferencesControllerProvider.notifier)
          .setHideBlockedContentCompletely(true);
      expect(saved, isFalse);
      expect(
        container.read(hideBlockedKeywordThreadsCompletelyProvider),
        isFalse,
      );
    });
  });
}
