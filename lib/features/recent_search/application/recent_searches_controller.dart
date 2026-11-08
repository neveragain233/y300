import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/recent_search/data/codecs/recent_search_snapshot_codec.dart';
import 'package:y300/features/recent_search/data/providers/recent_search_providers.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_entry.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_snapshot.dart';

/// Local recent keywords shared by the visible search surfaces.
///
/// Mutations are serialized and published only after the snapshot is written.
/// A separate revision guards reloads so a late read cannot bring back a
/// keyword that a later delete or clear already removed.
final class RecentSearchesController
    extends AsyncNotifier<RecentSearchSnapshot> {
  Future<void> _mutationTail = Future<void>.value();
  int _revision = 0;

  @override
  FutureOr<RecentSearchSnapshot> build() {
    return ref.watch(recentSearchRepositoryProvider).load();
  }

  /// Records one explicitly submitted keyword for [scope].
  Future<bool> record(RecentSearchScope scope, String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return Future<bool>.value(false);
    }
    return _serialize(() async {
      final RecentSearchSnapshot snapshot;
      try {
        snapshot = await _current();
      } catch (_) {
        return false;
      }
      final remaining = snapshot
          .entriesFor(scope)
          .where((entry) => entry.keyword != normalized)
          .toList(growable: false);
      final entry = RecentSearchEntry(
        keyword: normalized,
        usedAt: ref.read(recentSearchClockProvider)(),
      );
      final next = snapshot.replaceScope(
        scope,
        <RecentSearchEntry>[entry, ...remaining],
        maxEntriesPerScope: RecentSearchSnapshotCodec.maxEntriesPerScope,
        maxScopes: RecentSearchSnapshotCodec.maxScopes,
      );
      return _commit(next);
    });
  }

  /// Removes one keyword from [scope].
  Future<bool> remove(RecentSearchScope scope, String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return Future<bool>.value(false);
    }
    return _serialize(() async {
      final RecentSearchSnapshot snapshot;
      try {
        snapshot = await _current();
      } catch (_) {
        return false;
      }
      final nextEntries = snapshot
          .entriesFor(scope)
          .where((entry) => entry.keyword != normalized)
          .toList(growable: false);
      if (nextEntries.length == snapshot.entriesFor(scope).length) {
        return true;
      }
      final next = snapshot.replaceScope(
        scope,
        nextEntries,
        maxEntriesPerScope: RecentSearchSnapshotCodec.maxEntriesPerScope,
        maxScopes: RecentSearchSnapshotCodec.maxScopes,
      );
      return _commit(next);
    });
  }

  /// Clears every keyword in [scope].
  Future<bool> clear(RecentSearchScope scope) {
    return _serialize(() async {
      final RecentSearchSnapshot snapshot;
      try {
        snapshot = await _current();
      } catch (_) {
        return false;
      }
      if (snapshot.entriesFor(scope).isEmpty) {
        return true;
      }
      final next = snapshot.replaceScope(
        scope,
        const <RecentSearchEntry>[],
        maxEntriesPerScope: RecentSearchSnapshotCodec.maxEntriesPerScope,
        maxScopes: RecentSearchSnapshotCodec.maxScopes,
      );
      return _commit(next);
    });
  }

  /// Retries loading while discarding a late read from an older mutation set.
  Future<void> reload() async {
    final revision = _revision;
    state = const AsyncLoading();
    final loaded = await AsyncValue.guard(
      () => ref.read(recentSearchRepositoryProvider).load(),
    );
    if (!ref.mounted || revision != _revision) {
      return;
    }
    state = loaded;
  }

  Future<RecentSearchSnapshot> _current() async {
    final value = state.value;
    if (value != null) {
      return value;
    }
    try {
      final loaded = await future;
      if (!ref.mounted) {
        throw StateError('recent_searches_disposed');
      }
      return loaded;
    } catch (_) {
      throw StateError('recent_searches_unavailable');
    }
  }

  Future<bool> _commit(RecentSearchSnapshot next) async {
    _revision++;
    try {
      await ref.read(recentSearchRepositoryProvider).save(next);
    } catch (_) {
      return false;
    }
    if (!ref.mounted) {
      return false;
    }
    state = AsyncData(next);
    return true;
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final recentSearchesControllerProvider =
    AsyncNotifierProvider<RecentSearchesController, RecentSearchSnapshot>(
      RecentSearchesController.new,
    );

/// Keywords for one range, newest first; empty while the store loads.
final recentSearchesProvider =
    Provider.family<List<RecentSearchEntry>, RecentSearchScope>((ref, scope) {
      final snapshot = ref.watch(recentSearchesControllerProvider).value;
      return snapshot?.entriesFor(scope) ?? const <RecentSearchEntry>[];
    });
