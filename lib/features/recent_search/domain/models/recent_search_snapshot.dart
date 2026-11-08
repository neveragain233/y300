import 'package:y300/features/recent_search/domain/models/recent_search_entry.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';

/// Immutable recent-search lists keyed by [RecentSearchScope.key].
final class RecentSearchSnapshot {
  const RecentSearchSnapshot({
    this.entriesByScope = const <String, List<RecentSearchEntry>>{},
  });

  static const empty = RecentSearchSnapshot();

  final Map<String, List<RecentSearchEntry>> entriesByScope;

  List<RecentSearchEntry> entriesFor(RecentSearchScope scope) {
    return entriesByScope[scope.key] ?? const <RecentSearchEntry>[];
  }

  /// Replaces one range, applies the per-range bound and drops the least
  /// recently used ranges beyond [maxScopes].
  RecentSearchSnapshot replaceScope(
    RecentSearchScope scope,
    List<RecentSearchEntry> entries, {
    required int maxEntriesPerScope,
    required int maxScopes,
  }) {
    final next = Map<String, List<RecentSearchEntry>>.of(entriesByScope);
    if (entries.isEmpty) {
      next.remove(scope.key);
    } else {
      final ordered = List<RecentSearchEntry>.of(entries)
        ..sort((left, right) => right.usedAt.compareTo(left.usedAt));
      next[scope.key] = List<RecentSearchEntry>.unmodifiable(
        ordered.take(maxEntriesPerScope),
      );
    }
    final keys = next.keys.toList()
      ..sort(
        (left, right) => _latest(next[right]!).compareTo(_latest(next[left]!)),
      );
    final retained = <String, List<RecentSearchEntry>>{
      for (final key in keys.take(maxScopes)) key: next[key]!,
    };
    return RecentSearchSnapshot(
      entriesByScope: Map<String, List<RecentSearchEntry>>.unmodifiable(
        retained,
      ),
    );
  }

  static DateTime _latest(List<RecentSearchEntry> entries) {
    var latest = entries.first.usedAt;
    for (final entry in entries) {
      if (entry.usedAt.isAfter(latest)) {
        latest = entry.usedAt;
      }
    }
    return latest;
  }
}
