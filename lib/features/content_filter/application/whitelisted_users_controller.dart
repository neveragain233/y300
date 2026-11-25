import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/content_filter/data/codecs/whitelisted_user_snapshot_codec.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/whitelisted_user.dart';

enum WhitelistedUserMutationStatus {
  created,
  alreadyExists,
  invalidUid,
  failed,
}

final class WhitelistedUserMutationResult {
  const WhitelistedUserMutationResult(this.status, [this.entry]);

  const WhitelistedUserMutationResult.invalidUid()
    : status = WhitelistedUserMutationStatus.invalidUid,
      entry = null;

  const WhitelistedUserMutationResult.failed()
    : status = WhitelistedUserMutationStatus.failed,
      entry = null;

  final WhitelistedUserMutationStatus status;
  final WhitelistedUser? entry;

  bool get isSuccess => status == WhitelistedUserMutationStatus.created;
}

/// 本地可信用户白名单控制器，按 UID 豁免关键词屏蔽。
final class WhitelistedUsersController
    extends AsyncNotifier<List<WhitelistedUser>> {
  Future<void> _mutationTail = Future<void>.value();

  @override
  FutureOr<List<WhitelistedUser>> build() async {
    final raw = await ref
        .watch(preferencesStoreProvider)
        .read(PreferenceKeys.contentFilterWhitelistedUsersV1);
    return WhitelistedUserSnapshotCodec.decode(raw);
  }

  Future<WhitelistedUserMutationResult> add({
    required String uid,
    String username = '',
  }) {
    return _serialize(() async {
      final normalizedUid = normalizeWhitelistedUid(uid);
      if (normalizedUid == null) {
        return const WhitelistedUserMutationResult.invalidUid();
      }
      final List<WhitelistedUser> current;
      try {
        current = await _currentUsers();
      } catch (_) {
        return const WhitelistedUserMutationResult.failed();
      }
      for (final existing in current) {
        if (existing.uid == normalizedUid) {
          return WhitelistedUserMutationResult(
            WhitelistedUserMutationStatus.alreadyExists,
            existing,
          );
        }
      }
      final now = ref.read(whitelistedUserClockProvider)();
      final entry = WhitelistedUser(
        uid: normalizedUid,
        username: username.trim(),
        createdAt: now,
        updatedAt: now,
      );
      final next = List<WhitelistedUser>.unmodifiable([entry, ...current]);
      if (!await _commit(next)) {
        return const WhitelistedUserMutationResult.failed();
      }
      return WhitelistedUserMutationResult(
        WhitelistedUserMutationStatus.created,
        entry,
      );
    });
  }

  Future<bool> remove(String uid) {
    return _serialize(() async {
      final normalizedUid = normalizeWhitelistedUid(uid);
      if (normalizedUid == null) return false;
      final List<WhitelistedUser> current;
      try {
        current = await _currentUsers();
      } catch (_) {
        return false;
      }
      if (!current.any((entry) => entry.uid == normalizedUid)) {
        return true;
      }
      final next = List<WhitelistedUser>.unmodifiable(
        current.where((entry) => entry.uid != normalizedUid),
      );
      return _commit(next);
    });
  }

  Future<bool> undoRemove(WhitelistedUser expected) {
    return _serialize(() async {
      final List<WhitelistedUser> current;
      try {
        current = await _currentUsers();
      } catch (_) {
        return false;
      }
      if (current.any((entry) => entry.uid == expected.uid)) {
        return true;
      }
      final next = List<WhitelistedUser>.unmodifiable(
        [expected, ...current]
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt)),
      );
      return _commit(next);
    });
  }

  Future<(int imported, int skipped)> importEntries(
    List<WhitelistedUser> incoming, {
    required bool replace,
  }) {
    return _serialize(() async {
      final List<WhitelistedUser> current;
      try {
        current = replace ? const <WhitelistedUser>[] : await _currentUsers();
      } catch (_) {
        return (0, incoming.length);
      }
      final byUid = <String, WhitelistedUser>{
        for (final existing in current) existing.uid: existing,
      };
      var imported = 0;
      var skipped = 0;
      for (final item in incoming) {
        if (byUid.containsKey(item.uid)) {
          skipped++;
          continue;
        }
        byUid[item.uid] = item;
        imported++;
      }
      final next = byUid.values.toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      final bounded = List<WhitelistedUser>.unmodifiable(
        next.take(WhitelistedUserSnapshotCodec.maxEntries),
      );
      final saved = await _commit(bounded);
      if (!saved) return (0, incoming.length);
      return (imported, skipped);
    });
  }

  Future<List<WhitelistedUser>> _currentUsers() async {
    final current = state.asData?.value;
    if (current != null) return current;
    final raw = await ref
        .read(preferencesStoreProvider)
        .read(PreferenceKeys.contentFilterWhitelistedUsersV1);
    return WhitelistedUserSnapshotCodec.decode(raw);
  }

  Future<bool> _commit(List<WhitelistedUser> next) async {
    final bounded = next.length > WhitelistedUserSnapshotCodec.maxEntries
        ? List<WhitelistedUser>.unmodifiable(
            next.take(WhitelistedUserSnapshotCodec.maxEntries),
          )
        : next;
    try {
      await ref
          .read(preferencesStoreProvider)
          .write(
            PreferenceKeys.contentFilterWhitelistedUsersV1,
            WhitelistedUserSnapshotCodec.encode(bounded),
          );
    } catch (_) {
      return false;
    }
    if (!ref.mounted) return false;
    state = AsyncData(bounded);
    return true;
  }

  Future<R> _serialize<R>(Future<R> Function() action) {
    final completer = Completer<R>();
    final next = _mutationTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _mutationTail = next.catchError((_) {});
    return completer.future;
  }
}

final whitelistedUsersControllerProvider =
    AsyncNotifierProvider<WhitelistedUsersController, List<WhitelistedUser>>(
      WhitelistedUsersController.new,
    );

final whitelistedUserIdsProvider = Provider<Set<String>>((ref) {
  final users =
      ref.watch(whitelistedUsersControllerProvider).asData?.value ??
      const <WhitelistedUser>[];
  if (users.isEmpty) {
    return const <String>{};
  }
  final blacklisted = ref.watch(blacklistedUserIdsProvider);
  return Set<String>.unmodifiable({
    for (final user in users)
      if (!blacklisted.contains(user.uid)) user.uid,
  });
});
