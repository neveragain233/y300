import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/storage/app_data_backup_providers.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/application/whitelisted_users_controller.dart';
import 'package:y300/features/content_filter/data/backup/content_filter_backup_sections.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';

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
  group('Content filter backup sections', () {
    test(
      'round-trips keywords, blocked threads, and whitelisted users',
      () async {
        final sourceStore = _MemoryPreferencesStore();
        final sourceContainer = ProviderContainer(
          overrides: [preferencesStoreProvider.overrideWithValue(sourceStore)],
        );
        addTearDown(sourceContainer.dispose);

        await sourceContainer
            .read(blockedKeywordsControllerProvider.notifier)
            .add(
              keyword: 'AI',
              scope: BlockedKeywordScope.includeBody,
              wholeWord: true,
            );
        await sourceContainer
            .read(blockedThreadsControllerProvider.notifier)
            .block(tid: '1001', subject: 'Thread 1001');
        await sourceContainer
            .read(whitelistedUsersControllerProvider.notifier)
            .add(uid: '9988', username: 'Trusted');

        final rawJson = await sourceContainer
            .read(appDataBackupServiceProvider)
            .exportJson(sectionIds: ContentFilterBackupSectionIds.all);

        final targetStore = _MemoryPreferencesStore();
        final targetContainer = ProviderContainer(
          overrides: [preferencesStoreProvider.overrideWithValue(targetStore)],
        );
        addTearDown(targetContainer.dispose);

        await targetContainer
            .read(blockedKeywordsControllerProvider.notifier)
            .add(keyword: 'existing', scope: BlockedKeywordScope.repliesOnly);

        final targetService = targetContainer.read(
          appDataBackupServiceProvider,
        );
        final preview = targetService.inspectJson(
          rawJson,
          allowedSectionIds: ContentFilterBackupSectionIds.all,
        );
        expect(preview.totalItems, 3);

        final mergeReport = await targetService.importJson(
          rawJson,
          mode: AppDataBackupImportMode.merge,
          allowedSectionIds: ContentFilterBackupSectionIds.all,
        );
        expect(mergeReport.totalImported, 3);
        expect(
          (await targetContainer.read(blockedKeywordsControllerProvider.future))
              .length,
          2,
        );
        expect(
          targetContainer.read(blockedThreadIdsProvider),
          contains('1001'),
        );
        expect(
          targetContainer.read(whitelistedUserIdsProvider),
          contains('9988'),
        );

        final replaceReport = await targetService.importJson(
          rawJson,
          mode: AppDataBackupImportMode.replace,
          allowedSectionIds: ContentFilterBackupSectionIds.all,
        );
        expect(replaceReport.totalImported, 3);
        final replacedKeywords = await targetContainer.read(
          blockedKeywordsControllerProvider.future,
        );
        expect(replacedKeywords.map((e) => e.keyword), <String>['AI']);
      },
    );
  });
}
