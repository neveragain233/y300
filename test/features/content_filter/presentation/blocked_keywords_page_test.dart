import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_keyword_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/presentation/blocked_keywords_page.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../../test_support/localized_test_app.dart';

class _MemoryPreferencesStore implements PreferencesStore {
  final Map<String, Object> _values = <String, Object>{};

  List<BlockedKeyword> loadRules() => BlockedKeywordSnapshotCodec.decode(
    _values[PreferenceKeys.contentFilterBlockedKeywordsV1.name] as String?,
  );

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
  testWidgets('adds, edits scope, toggles list hiding, and deletes with undo', (
    tester,
  ) async {
    final store = _MemoryPreferencesStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
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
    final savedRules = store.loadRules();
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

    final updatedRules = store.loadRules();
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
    expect(store.loadRules().single.enabled, isFalse);

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
    final rulesWithAllow = store.loadRules();
    expect(
      rulesWithAllow.any(
        (rule) =>
            rule.keyword == '官方剧透预警' && rule.kind == BlockedKeywordKind.allow,
      ),
      isTrue,
    );
  });
}
