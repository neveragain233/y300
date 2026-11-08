import 'dart:convert';

import 'package:y300/features/recent_search/domain/models/recent_search_entry.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';

/// Versioned JSON snapshot for local recent-search keywords.
abstract final class RecentSearchSnapshotCodec {
  static const int schemaVersion = 1;
  static const int maxEntriesPerScope = 20;
  static const int maxScopes = 40;

  static String encode(RecentSearchSnapshot snapshot) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'scopes': <String, Object?>{
        for (final entry in snapshot.entriesByScope.entries)
          entry.key: [
            for (final value in entry.value)
              <String, Object?>{
                'keyword': value.keyword,
                'usedAt': value.usedAt.millisecondsSinceEpoch,
              },
          ],
      },
    });
  }

  static RecentSearchSnapshot decode(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return RecentSearchSnapshot.empty;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return RecentSearchSnapshot.empty;
      }
      final scopes = decoded['scopes'];
      if (scopes is! Map) {
        return RecentSearchSnapshot.empty;
      }
      final entriesByScope = <String, List<RecentSearchEntry>>{};
      for (final entry in scopes.entries) {
        final key = entry.key;
        if (key is! String || !_isKnownScopeKey(key)) {
          continue;
        }
        final values = entry.value;
        if (values is! List) {
          continue;
        }
        final entries = <RecentSearchEntry>[];
        for (final value in values) {
          final decodedEntry = _decodeEntry(value);
          if (decodedEntry != null) {
            entries.add(decodedEntry);
          }
        }
        if (entries.isEmpty) {
          continue;
        }
        entries.sort((left, right) => right.usedAt.compareTo(left.usedAt));
        entriesByScope[key] = List<RecentSearchEntry>.unmodifiable(
          entries.take(maxEntriesPerScope),
        );
      }
      return RecentSearchSnapshot(
        entriesByScope: Map<String, List<RecentSearchEntry>>.unmodifiable(
          entriesByScope,
        ),
      );
    } on Object {
      return RecentSearchSnapshot.empty;
    }
  }

  static RecentSearchEntry? _decodeEntry(Object? value) {
    if (value is! Map) {
      return null;
    }
    final rawKeyword = value['keyword'];
    if (rawKeyword is! String) {
      return null;
    }
    final keyword = rawKeyword.trim();
    if (keyword.isEmpty) {
      return null;
    }
    final epoch = value['usedAt'];
    if (epoch is! int || epoch <= 0) {
      return null;
    }
    return RecentSearchEntry(
      keyword: keyword,
      usedAt: DateTime.fromMillisecondsSinceEpoch(epoch),
    );
  }

  /// Unknown future ranges are ignored instead of being re-assigned.
  static bool _isKnownScopeKey(String key) {
    return const <String>{
          'forum',
          'shelf:comic',
          'shelf:novel',
          'shelf:favorite',
          'history',
        }.contains(key) ||
        _hasPrefix(key, 'account:') ||
        _hasPrefix(key, 'work:');
  }

  static bool _hasPrefix(String value, String prefix) {
    return value.startsWith(prefix) && value.length > prefix.length;
  }

  /// Snapshot keys are only produced by [RecentSearchScope].
  static String keyFor(RecentSearchScope scope) => scope.key;
}
