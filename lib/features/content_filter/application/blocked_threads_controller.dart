import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_thread_snapshot_codec.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/services/thread_block_identity.dart';

/// Result of one block request.
enum BlockedThreadBlockStatus { created, alreadyBlocked, failed }

final class BlockedThreadBlockResult {
  const BlockedThreadBlockResult(this.status, [this.entry]);

  const BlockedThreadBlockResult.failed()
    : status = BlockedThreadBlockStatus.failed,
      entry = null;

  final BlockedThreadBlockStatus status;
  final BlockedThread? entry;

  bool get isCreated => status == BlockedThreadBlockStatus.created;
}

/// Device-wide blocked thread rules.
///
/// Mutations are serialized end to end: each one re-reads the published rules,
/// writes the whole snapshot, and only then publishes the new list. A failed
/// write therefore leaves the previous rules untouched instead of rolling back
/// an optimistic list that a later mutation may already have replaced.
final class BlockedThreadsController
    extends AsyncNotifier<List<BlockedThread>> {
  Future<void> _mutationTail = Future<void>.value();

  @override
  FutureOr<List<BlockedThread>> build() async {
    final raw = await ref
        .watch(preferencesStoreProvider)
        .read(PreferenceKeys.contentFilterBlockedThreadsV1);
    return BlockedThreadSnapshotCodec.decode(raw);
  }

  /// Blocks [tid] and captures [subject] for recognition in the management
  /// page. Rules are keyed by canonical thread id only.
  Future<BlockedThreadBlockResult> block({
    required String tid,
    required String subject,
  }) {
    return _serialize(() async {
      final normalized = ThreadBlockIdentity.normalizeTid(tid);
      if (normalized == null) {
        return const BlockedThreadBlockResult.failed();
      }
      final List<BlockedThread> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return const BlockedThreadBlockResult.failed();
      }
      final existing = _find(current, normalized);
      if (existing != null) {
        return BlockedThreadBlockResult(
          BlockedThreadBlockStatus.alreadyBlocked,
          existing,
        );
      }
      final snapshot = subject.trim().isEmpty ? normalized : subject.trim();
      final entry = BlockedThread(
        tid: normalized,
        subject: snapshot,
        blockedAt: ref.read(blockedThreadClockProvider)(),
      );
      final next = List<BlockedThread>.unmodifiable([
        entry,
        ...current.where((rule) => rule.tid != normalized),
      ]);
      if (!await _commit(next)) {
        return const BlockedThreadBlockResult.failed();
      }
      return BlockedThreadBlockResult(BlockedThreadBlockStatus.created, entry);
    });
  }

  /// Removes the rule for [tid] regardless of its revision.
  Future<bool> unblock(String tid) {
    return _serialize(() async {
      final normalized = ThreadBlockIdentity.normalizeTid(tid);
      if (normalized == null) {
        return false;
      }
      final List<BlockedThread> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return false;
      }
      if (_find(current, normalized) == null) {
        return true;
      }
      final next = List<BlockedThread>.unmodifiable(
        current.where((rule) => rule.tid != normalized),
      );
      return _commit(next);
    });
  }

  /// Reverts exactly the block operation that produced [expected].
  ///
  /// A later block of the same thread has a different timestamp, so its rule
  /// is left intact; removing an already removed rule is a no-op success.
  Future<bool> undo(BlockedThread expected) {
    return _serialize(() async {
      final List<BlockedThread> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return false;
      }
      final existing = _find(current, expected.tid);
      if (existing == null) {
        return true;
      }
      if (!existing.isSameRule(expected)) {
        return true;
      }
      final next = List<BlockedThread>.unmodifiable(
        current.where((rule) => rule.tid != expected.tid),
      );
      return _commit(next);
    });
  }

  /// Retries loading after a failed read.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final raw = await ref
          .read(preferencesStoreProvider)
          .read(PreferenceKeys.contentFilterBlockedThreadsV1);
      return BlockedThreadSnapshotCodec.decode(raw);
    });
  }

  Future<List<BlockedThread>> _currentRules() async {
    final value = state.value;
    if (value != null) {
      return value;
    }
    try {
      final loaded = await future;
      if (!ref.mounted) {
        throw StateError('blocked_threads_disposed');
      }
      return loaded;
    } catch (_) {
      // A broken store must not become a silent success: the caller reports
      // the failure and the previous (empty) rules stay in effect.
      throw StateError('blocked_threads_unavailable');
    }
  }

  Future<bool> _commit(List<BlockedThread> next) async {
    try {
      await ref
          .read(preferencesStoreProvider)
          .write(
            PreferenceKeys.contentFilterBlockedThreadsV1,
            BlockedThreadSnapshotCodec.encode(next),
          );
    } catch (_) {
      return false;
    }
    if (!ref.mounted) {
      return false;
    }
    state = AsyncData(next);
    return true;
  }

  BlockedThread? _find(List<BlockedThread> rules, String tid) {
    for (final rule in rules) {
      if (rule.tid == tid) {
        return rule;
      }
    }
    return null;
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

final blockedThreadsControllerProvider =
    AsyncNotifierProvider<BlockedThreadsController, List<BlockedThread>>(
      BlockedThreadsController.new,
    );

/// Blocked thread ids for display filtering; empty while rules load or fail.
final blockedThreadIdsProvider = Provider<Set<String>>((ref) {
  final rules = ref.watch(blockedThreadsControllerProvider).value;
  if (rules == null || rules.isEmpty) {
    return const <String>{};
  }
  return Set<String>.unmodifiable(rules.map((rule) => rule.tid));
});

/// The rule for one thread, or null while unblocked.
final blockedThreadRuleProvider = Provider.family<BlockedThread?, String>((
  ref,
  tid,
) {
  final normalized = ThreadBlockIdentity.normalizeTid(tid);
  if (normalized == null) {
    return null;
  }
  final rules = ref.watch(blockedThreadsControllerProvider).value;
  if (rules == null) {
    return null;
  }
  for (final rule in rules) {
    if (rule.tid == normalized) {
      return rule;
    }
  }
  return null;
});
