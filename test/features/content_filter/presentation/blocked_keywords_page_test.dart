import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_keyword_repository.dart';
import 'package:y300/features/content_filter/domain/repositories/keyword_filter_preferences_repository.dart';
import 'package:y300/features/content_filter/presentation/blocked_keywords_page.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../../test_support/localized_test_app.dart';

class _MemoryKeywordRepo implements BlockedKeywordRepository {
  _MemoryKeywordRepo([List<BlockedKeyword>? initial])
    : _items = List<BlockedKeyword>.from(initial ?? const []);

  List<BlockedKeyword> _items;

  @override
  Future<List<BlockedKeyword>> load() async => List.unmodifiable(_items);

  @override
  Future<void> save(List<BlockedKeyword> keywords) async {
    _items = List<BlockedKeyword>.from(keywords);
  }
}

class _MemoryPrefsRepo implements KeywordFilterPreferencesRepository {
  KeywordFilterPreferences _prefs = KeywordFilterPreferences.defaults;

  @override
  Future<KeywordFilterPreferences> load() async => _prefs;

  @override
  Future<void> save(KeywordFilterPreferences preferences) async {
    _prefs = preferences;
  }
}

void main() {
  testWidgets('adds, edits scope, toggles list hiding, and deletes with undo', (
    tester,
  ) async {
    final repo = _MemoryKeywordRepo();
    final prefsRepo = _MemoryPrefsRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockedKeywordRepositoryProvider.overrideWithValue(repo),
          keywordFilterPreferencesRepositoryProvider.overrideWithValue(
            prefsRepo,
          ),
        ],
        child: const LocalizedTestApp(home: BlockedKeywordsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('content-filter-blocked-keyword-empty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('content-filter-add-keyword-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('content-filter-keyword-input')),
      '剧透',
    );
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-scope-include-body')),
    );
    await tester.tap(
      find.byKey(const Key('content-filter-scope-include-body')),
    );
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-keyword-save')),
    );
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-keyword-save')),
    );
    await tester.tap(find.byKey(const Key('content-filter-keyword-save')));
    await tester.pumpAndSettle();

    expect(find.text('剧透'), findsOneWidget);
    final savedRules = await repo.load();
    expect(savedRules.length, 1);
    expect(savedRules.single.scope, BlockedKeywordScope.includeBody);

    final rowKey = Key('content-filter-keyword-${savedRules.single.id}');
    await tester.tap(find.byKey(rowKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-scope-replies-only')),
    );
    await tester.tap(
      find.byKey(const Key('content-filter-scope-replies-only')),
    );
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-keyword-save')),
    );
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-keyword-save')),
    );
    await tester.tap(find.byKey(const Key('content-filter-keyword-save')));
    await tester.pumpAndSettle();

    final updatedRules = await repo.load();
    expect(updatedRules.single.scope, BlockedKeywordScope.repliesOnly);

    final switchFinder = find.byKey(
      const Key('content-filter-hide-keyword-threads-switch'),
    );
    expect(tester.widget<AppSwitchRow>(switchFinder).value, isFalse);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<AppSwitchRow>(switchFinder).value, isTrue);

    await tester.tap(
      find.byKey(
        Key('content-filter-toggle-keyword-${updatedRules.single.id}'),
      ),
    );
    await tester.pumpAndSettle();
    expect((await repo.load()).single.enabled, isFalse);

    await tester.tap(
      find.byKey(
        Key('content-filter-delete-keyword-${updatedRules.single.id}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('content-filter-blocked-keyword-empty')),
      findsOneWidget,
    );

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(find.text('剧透'), findsOneWidget);

    await tester.tap(find.byKey(const Key('content-filter-tab-allow')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('content-filter-add-keyword-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('content-filter-keyword-input')),
      '官方剧透预警',
    );
    await tester.ensureVisible(
      find.byKey(const Key('content-filter-keyword-save')),
    );
    await tester.tap(find.byKey(const Key('content-filter-keyword-save')));
    await tester.pumpAndSettle();
    expect(find.text('官方剧透预警'), findsOneWidget);
    final rulesWithAllow = await repo.load();
    expect(
      rulesWithAllow.any(
        (rule) =>
            rule.keyword == '官方剧透预警' && rule.kind == BlockedKeywordKind.allow,
      ),
      isTrue,
    );
  });
}
