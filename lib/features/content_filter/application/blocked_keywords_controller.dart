import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

/// Result of adding or updating a keyword rule.
enum BlockedKeywordMutationStatus {
  created,
  updated,
  alreadyExists,
  invalid,
  invalidRegex,
  regexTooLong,
  failed,
}

final class BlockedKeywordMutationResult {
  const BlockedKeywordMutationResult(this.status, [this.entry]);

  const BlockedKeywordMutationResult.invalid()
    : status = BlockedKeywordMutationStatus.invalid,
      entry = null;

  const BlockedKeywordMutationResult.invalidRegex()
    : status = BlockedKeywordMutationStatus.invalidRegex,
      entry = null;

  const BlockedKeywordMutationResult.regexTooLong()
    : status = BlockedKeywordMutationStatus.regexTooLong,
      entry = null;

  const BlockedKeywordMutationResult.failed()
    : status = BlockedKeywordMutationStatus.failed,
      entry = null;

  final BlockedKeywordMutationStatus status;
  final BlockedKeyword? entry;

  bool get isSuccess =>
      status == BlockedKeywordMutationStatus.created ||
      status == BlockedKeywordMutationStatus.updated;
}

/// Device-wide blocked keyword rules with serialized persistence.
final class BlockedKeywordsController
    extends AsyncNotifier<List<BlockedKeyword>> {
  Future<void> _mutationTail = Future<void>.value();
  int _sequence = 0;

  @override
  FutureOr<List<BlockedKeyword>> build() {
    return ref.watch(blockedKeywordRepositoryProvider).load();
  }

  Future<BlockedKeywordMutationResult> add({
    required String keyword,
    required BlockedKeywordScope scope,
    BlockedKeywordKind kind = BlockedKeywordKind.block,
    BlockedKeywordMatchType matchType = BlockedKeywordMatchType.plain,
    bool enabled = true,
  }) {
    return _serialize(() async {
      final validationError = validateBlockedKeywordPattern(keyword, matchType);
      if (validationError != null) {
        return _mapPatternError(validationError);
      }
      final trimmed = keyword.trim();
      final normalized = normalizeBlockedKeywordPattern(trimmed, matchType);
      final effectiveScope = kind == BlockedKeywordKind.allow
          ? BlockedKeywordScope.includeBody
          : scope;
      final List<BlockedKeyword> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return const BlockedKeywordMutationResult.failed();
      }
      final existing = _findByIdentity(current, kind, matchType, normalized);
      if (existing != null) {
        return BlockedKeywordMutationResult(
          BlockedKeywordMutationStatus.alreadyExists,
          existing,
        );
      }
      final now = ref.read(blockedKeywordClockProvider)();
      final id = _nextId(now, current);
      final entry = BlockedKeyword(
        id: id,
        keyword: trimmed,
        normalizedKeyword: normalized,
        scope: effectiveScope,
        kind: kind,
        matchType: matchType,
        enabled: enabled,
        createdAt: now,
        updatedAt: now,
      );
      final next = List<BlockedKeyword>.unmodifiable([entry, ...current]);
      if (!await _commit(next)) {
        return const BlockedKeywordMutationResult.failed();
      }
      return BlockedKeywordMutationResult(
        BlockedKeywordMutationStatus.created,
        entry,
      );
    });
  }

  Future<BlockedKeywordMutationResult> updateRule({
    required String id,
    required String keyword,
    required BlockedKeywordScope scope,
    BlockedKeywordKind? kind,
    BlockedKeywordMatchType? matchType,
    bool? enabled,
  }) {
    return _serialize(() async {
      final List<BlockedKeyword> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return const BlockedKeywordMutationResult.failed();
      }
      final existing = _findById(current, id);
      if (existing == null) {
        return const BlockedKeywordMutationResult.failed();
      }
      final effectiveKind = kind ?? existing.kind;
      final effectiveMatchType = matchType ?? existing.matchType;
      final effectiveEnabled = enabled ?? existing.enabled;
      final effectiveScope = effectiveKind == BlockedKeywordKind.allow
          ? BlockedKeywordScope.includeBody
          : scope;
      final validationError = validateBlockedKeywordPattern(
        keyword,
        effectiveMatchType,
      );
      if (validationError != null) {
        return _mapPatternError(validationError);
      }
      final trimmed = keyword.trim();
      final normalized = normalizeBlockedKeywordPattern(
        trimmed,
        effectiveMatchType,
      );
      final conflict = _findByIdentity(
        current,
        effectiveKind,
        effectiveMatchType,
        normalized,
      );
      if (conflict != null && conflict.id != id) {
        return BlockedKeywordMutationResult(
          BlockedKeywordMutationStatus.alreadyExists,
          conflict,
        );
      }
      final now = ref.read(blockedKeywordClockProvider)();
      final updated = existing.copyWith(
        keyword: trimmed,
        normalizedKeyword: normalized,
        scope: effectiveScope,
        kind: effectiveKind,
        matchType: effectiveMatchType,
        enabled: effectiveEnabled,
        updatedAt: now,
      );
      final next = List<BlockedKeyword>.unmodifiable([
        updated,
        for (final rule in current)
          if (rule.id != id) rule,
      ]);
      if (!await _commit(next)) {
        return const BlockedKeywordMutationResult.failed();
      }
      return BlockedKeywordMutationResult(
        BlockedKeywordMutationStatus.updated,
        updated,
      );
    });
  }

  Future<bool> setEnabled(String id, bool enabled) {
    return _serialize(() async {
      final List<BlockedKeyword> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return false;
      }
      final existing = _findById(current, id);
      if (existing == null) {
        return false;
      }
      if (existing.enabled == enabled) {
        return true;
      }
      final now = ref.read(blockedKeywordClockProvider)();
      final updated = existing.copyWith(enabled: enabled, updatedAt: now);
      final next = List<BlockedKeyword>.unmodifiable([
        for (final rule in current)
          if (rule.id == id) updated else rule,
      ]);
      return _commit(next);
    });
  }

  Future<bool> remove(String id) {
    return _serialize(() async {
      final List<BlockedKeyword> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return false;
      }
      if (_findById(current, id) == null) {
        return true;
      }
      final next = List<BlockedKeyword>.unmodifiable(
        current.where((rule) => rule.id != id),
      );
      return _commit(next);
    });
  }

  Future<bool> undoRemove(BlockedKeyword entry) {
    return _serialize(() async {
      final List<BlockedKeyword> current;
      try {
        current = await _currentRules();
      } catch (_) {
        return false;
      }
      if (_findById(current, entry.id) != null ||
          _findByIdentity(
                current,
                entry.kind,
                entry.matchType,
                entry.normalizedKeyword,
              ) !=
              null) {
        return true;
      }
      final next = List<BlockedKeyword>.unmodifiable([entry, ...current]);
      return _commit(next);
    });
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(blockedKeywordRepositoryProvider).load(),
    );
  }

  BlockedKeywordMutationResult _mapPatternError(
    BlockedKeywordPatternError error,
  ) {
    return switch (error) {
      BlockedKeywordPatternError.empty =>
        const BlockedKeywordMutationResult.invalid(),
      BlockedKeywordPatternError.regexTooLong =>
        const BlockedKeywordMutationResult.regexTooLong(),
      BlockedKeywordPatternError.invalidRegex =>
        const BlockedKeywordMutationResult.invalidRegex(),
    };
  }

  Future<List<BlockedKeyword>> _currentRules() async {
    final value = state.value;
    if (value != null) {
      return value;
    }
    try {
      final loaded = await future;
      if (!ref.mounted) {
        throw StateError('blocked_keywords_disposed');
      }
      return loaded;
    } catch (_) {
      throw StateError('blocked_keywords_unavailable');
    }
  }

  Future<bool> _commit(List<BlockedKeyword> next) async {
    try {
      await ref.read(blockedKeywordRepositoryProvider).save(next);
    } catch (_) {
      return false;
    }
    if (!ref.mounted) {
      return false;
    }
    state = AsyncData(next);
    return true;
  }

  BlockedKeyword? _findById(List<BlockedKeyword> rules, String id) {
    for (final rule in rules) {
      if (rule.id == id) return rule;
    }
    return null;
  }

  BlockedKeyword? _findByIdentity(
    List<BlockedKeyword> rules,
    BlockedKeywordKind kind,
    BlockedKeywordMatchType matchType,
    String normalized,
  ) {
    for (final rule in rules) {
      if (rule.kind == kind &&
          rule.matchType == matchType &&
          rule.normalizedKeyword == normalized) {
        return rule;
      }
    }
    return null;
  }

  String _nextId(DateTime now, List<BlockedKeyword> current) {
    var candidate = 'kw-${now.microsecondsSinceEpoch}-${_sequence++}';
    while (_findById(current, candidate) != null) {
      candidate = 'kw-${now.microsecondsSinceEpoch}-${_sequence++}';
    }
    return candidate;
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

final blockedKeywordsControllerProvider =
    AsyncNotifierProvider<BlockedKeywordsController, List<BlockedKeyword>>(
      BlockedKeywordsController.new,
    );

/// Device-local keyword filter display preferences with serialized persistence.
final class KeywordFilterPreferencesController
    extends AsyncNotifier<KeywordFilterPreferences> {
  Future<void> _writes = Future<void>.value();
  KeywordFilterPreferences _saved = KeywordFilterPreferences.defaults;
  int _revision = 0;

  @override
  Future<KeywordFilterPreferences> build() async {
    try {
      return _saved = await ref
          .watch(keywordFilterPreferencesRepositoryProvider)
          .load();
    } on Object {
      return _saved = KeywordFilterPreferences.defaults;
    }
  }

  Future<bool> setHideBlockedContentCompletely(bool value) {
    final current = state.value ?? _saved;
    return _save(current.copyWith(hideBlockedContentCompletely: value));
  }

  Future<bool> _save(KeywordFilterPreferences preferences) {
    final repository = ref.read(keywordFilterPreferencesRepositoryProvider);
    final revision = ++_revision;
    state = AsyncData(preferences);
    final result = _writes.then((_) async {
      try {
        await repository.save(preferences);
        _saved = preferences;
        return true;
      } on Object {
        try {
          await repository.save(_saved);
        } on Object {
          // Keep the last successful value for future mutations.
        }
        if (ref.mounted && revision == _revision) {
          state = AsyncData(_saved);
          return false;
        }
        return true;
      }
    });
    _writes = result.then<void>((_) {});
    return result;
  }
}

final keywordFilterPreferencesControllerProvider =
    AsyncNotifierProvider<
      KeywordFilterPreferencesController,
      KeywordFilterPreferences
    >(KeywordFilterPreferencesController.new);

final hideBlockedKeywordThreadsCompletelyProvider = Provider<bool>((ref) {
  final preferences = ref.watch(keywordFilterPreferencesControllerProvider);
  return preferences.value?.hideBlockedContentCompletely ?? false;
});

final keywordFilterRulesProvider = Provider<KeywordFilterRuleSet>((ref) {
  final rules = ref.watch(blockedKeywordsControllerProvider).value;
  final hideCompletely = ref.watch(hideBlockedKeywordThreadsCompletelyProvider);
  if (rules == null || rules.isEmpty) {
    return KeywordFilterRuleSet(
      rules: const <BlockedKeyword>[],
      hideBlockedContentCompletely: hideCompletely,
      revision: hideCompletely ? 1 : 0,
    );
  }
  return KeywordFilterRuleSet(
    rules: rules,
    hideBlockedContentCompletely: hideCompletely,
    revision: Object.hash(hideCompletely, Object.hashAll(rules)),
  );
});
