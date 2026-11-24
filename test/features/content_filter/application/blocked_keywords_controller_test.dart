import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_keyword_repository.dart';
import 'package:y300/features/content_filter/domain/repositories/keyword_filter_preferences_repository.dart';

class _MemoryKeywordRepo implements BlockedKeywordRepository {
  _MemoryKeywordRepo([List<BlockedKeyword>? initial])
    : _items = List<BlockedKeyword>.from(initial ?? const []);

  List<BlockedKeyword> _items;
  bool failNextSave = false;

  @override
  Future<List<BlockedKeyword>> load() async => List.unmodifiable(_items);

  @override
  Future<void> save(List<BlockedKeyword> keywords) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    _items = List<BlockedKeyword>.from(keywords);
  }
}

class _MemoryPrefsRepo implements KeywordFilterPreferencesRepository {
  KeywordFilterPreferences _prefs = KeywordFilterPreferences.defaults;
  bool failNextSave = false;

  @override
  Future<KeywordFilterPreferences> load() async => _prefs;

  @override
  Future<void> save(KeywordFilterPreferences preferences) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('prefs save failed');
    }
    _prefs = preferences;
  }
}

void main() {
  group('BlockedKeywordsController', () {
    test('adds, deduplicates, updates scope, removes and undoes', () async {
      final repo = _MemoryKeywordRepo();
      final prefsRepo = _MemoryPrefsRepo();
      var tick = 1000;
      final container = ProviderContainer(
        overrides: [
          blockedKeywordRepositoryProvider.overrideWithValue(repo),
          keywordFilterPreferencesRepositoryProvider.overrideWithValue(
            prefsRepo,
          ),
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

      final removed = await controller.remove(added.entry!.id);
      expect(removed, isTrue);
      expect(container.read(blockedKeywordsControllerProvider).value, isEmpty);

      final undone = await controller.undoRemove(updated.entry!);
      expect(undone, isTrue);
      expect(
        container.read(blockedKeywordsControllerProvider).value?.length,
        1,
      );
    });

    test('leaves existing state untouched when save fails', () async {
      final repo = _MemoryKeywordRepo();
      final prefsRepo = _MemoryPrefsRepo();
      final container = ProviderContainer(
        overrides: [
          blockedKeywordRepositoryProvider.overrideWithValue(repo),
          keywordFilterPreferencesRepositoryProvider.overrideWithValue(
            prefsRepo,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(blockedKeywordsControllerProvider.future);
      repo.failNextSave = true;

      final result = await container
          .read(blockedKeywordsControllerProvider.notifier)
          .add(keyword: 'test', scope: BlockedKeywordScope.repliesOnly);
      expect(result.status, BlockedKeywordMutationStatus.failed);
      expect(container.read(blockedKeywordsControllerProvider).value, isEmpty);

      await container.read(keywordFilterPreferencesControllerProvider.future);
      prefsRepo.failNextSave = true;
      final saved = await container
          .read(keywordFilterPreferencesControllerProvider.notifier)
          .setHideMatchingThreadsInLists(false);
      expect(saved, isFalse);
      expect(container.read(hideKeywordThreadsInListsProvider), isTrue);
    });
  });
}
