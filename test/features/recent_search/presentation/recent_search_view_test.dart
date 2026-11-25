import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/recent_search/data/codecs/recent_search_snapshot_codec.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_entry.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';
import 'package:y300/features/recent_search/presentation/recent_search_view.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('shows keywords, selects one and clears the range', (
    tester,
  ) async {
    final repository = _MemoryRepository(
      RecentSearchSnapshot(
        entriesByScope: <String, List<RecentSearchEntry>>{
          'forum': <RecentSearchEntry>[
            RecentSearchEntry(
              keyword: '漫画',
              usedAt: DateTime.fromMillisecondsSinceEpoch(2000),
            ),
            RecentSearchEntry(
              keyword: '小说',
              usedAt: DateTime.fromMillisecondsSinceEpoch(1000),
            ),
          ],
        },
      ),
    );
    String? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesStoreProvider.overrideWithValue(repository)],
        child: LocalizedTestApp(
          home: Scaffold(
            body: RecentSearchView(
              scope: RecentSearchScope.forum,
              onSelected: (keyword) => selected = keyword,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recent-search-chip-forum-漫画')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recent-search-chip-forum-小说')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('recent-search-chip-forum-漫画')));
    expect(selected, '漫画');

    await tester.tap(find.byKey(const Key('recent-search-clear-forum')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recent-search-panel-forum')), findsNothing);
    expect(repository.snapshot.entriesByScope, isEmpty);
  });
}

final class _MemoryRepository implements PreferencesStore {
  _MemoryRepository(this.snapshot);

  RecentSearchSnapshot snapshot;

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
