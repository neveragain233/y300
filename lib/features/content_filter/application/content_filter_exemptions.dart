import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

/// 判断帖子在版块列表中是否带有置顶标识。
bool isStickyForumThread(ForumThreadSummary thread) {
  return thread.effectiveBadges.any(
    (badge) => badge.kind == ForumThreadBadgeKind.sticky,
  );
}

/// 已知子版块 ID 注册表：只要作为子版块出现或打开过，即纳入永久屏蔽豁免。
final class KnownSubForumIdsController extends Notifier<Set<String>> {
  static const int _schemaVersion = 1;
  static const int _maxEntries = 500;

  bool _hydrated = false;
  Future<void> _writeTail = Future<void>.value();

  @override
  Set<String> build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate());
    }
    return const <String>{};
  }

  /// 记录单个子版块 ID。
  void record(String fid) => recordAll(<String>[fid]);

  /// 批量记录子版块 ID，并在有新增时异步持久化。
  void recordAll(Iterable<String> fids) {
    final next = <String>{...state};
    var changed = false;
    for (final raw in fids) {
      final fid = raw.trim();
      if (fid.isEmpty || next.contains(fid)) {
        continue;
      }
      if (next.length >= _maxEntries) {
        break;
      }
      next.add(fid);
      changed = true;
    }
    if (!changed) {
      return;
    }
    final immutable = Set<String>.unmodifiable(next);
    state = immutable;
    _schedulePersist(immutable);
  }

  Future<void> _hydrate() async {
    try {
      final raw = await ref
          .read(preferencesStoreProvider)
          .read(PreferenceKeys.contentFilterKnownSubForumIdsV1);
      if (!ref.mounted) {
        return;
      }
      final decoded = _decode(raw);
      if (decoded.isEmpty) {
        return;
      }
      final merged = <String>{...decoded, ...state};
      if (merged.length == state.length && state.containsAll(merged)) {
        return;
      }
      state = Set<String>.unmodifiable(merged.take(_maxEntries));
    } on Object {
      // 读取失败不阻塞版块展示，保留当前内存状态。
    }
  }

  void _schedulePersist(Set<String> fids) {
    _writeTail = _writeTail.then((_) async {
      if (!ref.mounted) {
        return;
      }
      try {
        await ref
            .read(preferencesStoreProvider)
            .write(
              PreferenceKeys.contentFilterKnownSubForumIdsV1,
              _encode(fids),
            );
      } on Object {
        // 忽略后台持久化异常，内存豁免仍立即生效。
      }
    });
  }

  static String _encode(Set<String> fids) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': _schemaVersion,
      'fids': fids.take(_maxEntries).toList(growable: false),
    });
  }

  static Set<String> _decode(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const <String>{};
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map || decoded['schemaVersion'] != _schemaVersion) {
        return const <String>{};
      }
      final values = decoded['fids'];
      if (values is! List) {
        return const <String>{};
      }
      final fids = <String>{};
      for (final value in values) {
        if (value is! String) {
          continue;
        }
        final fid = value.trim();
        if (fid.isNotEmpty) {
          fids.add(fid);
          if (fids.length >= _maxEntries) {
            break;
          }
        }
      }
      return fids;
    } on Object {
      return const <String>{};
    }
  }
}

/// 永久豁免本地屏蔽拦截的子版块 ID 集合。
final exemptSubForumIdsProvider =
    NotifierProvider<KnownSubForumIdsController, Set<String>>(
      KnownSubForumIdsController.new,
    );
