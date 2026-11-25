import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';

/// Reason why a reply floor was filtered into the thread tail.
@immutable
final class ThreadReplyFilterReason {
  const ThreadReplyFilterReason({
    this.isBlacklistedAuthor = false,
    this.matchedKeyword,
  });

  static const ThreadReplyFilterReason none = ThreadReplyFilterReason();

  final bool isBlacklistedAuthor;
  final String? matchedKeyword;

  bool get isFiltered => isBlacklistedAuthor || matchedKeyword != null;

  @override
  bool operator ==(Object other) =>
      other is ThreadReplyFilterReason &&
      other.isBlacklistedAuthor == isBlacklistedAuthor &&
      other.matchedKeyword == matchedKeyword;

  @override
  int get hashCode => Object.hash(isBlacklistedAuthor, matchedKeyword);
}

/// One source page read while collecting replies whose authors are blacklisted.
final class ThreadReplyTailPage {
  const ThreadReplyTailPage({
    required this.page,
    required this.posts,
    required this.hasMore,
  });

  final int page;
  final List<ThreadPost> posts;
  final bool hasMore;
}

/// Detail-session aggregation of replies whose authors are on the blacklist.
///
/// The site requirement places those replies after the normal replies of the
/// last page. This coordinator records the blocked replies of every visited
/// page, detects the last page, and serially fills the pages that were never
/// visited. It owns no transport: reads go through the detail controller and
/// the shared forum client. Persisted bodies, source floor numbers and server
/// pagination are never rewritten; only the display projection changes.
///
/// Identity contains thread, query (author filter and order), account revision
/// and blacklist membership. Any change retires the collected set and every
/// late read of the previous generation.
final class ThreadReplyTailCoordinator extends ChangeNotifier {
  ThreadReplyTailCoordinator({
    required this.readPage,
    this.maxPagesPerPass = 40,
    this.maxBlockedPosts = 600,
  });

  /// Reads one thread page without publishing it into the visible detail state.
  final Future<ThreadReplyTailPage?> Function(
    int page,
    Map<String, String> queryParameters,
  )
  readPage;

  /// Budget for one collection pass; the next explicit action may continue.
  final int maxPagesPerPass;

  /// Memory budget for retained blocked replies.
  final int maxBlockedPosts;

  final Map<int, List<ThreadPost>> _blockedByPage = <int, List<ThreadPost>>{};
  final Map<int, List<String>> _blockedPidsByPage = <int, List<String>>{};
  final Map<String, ThreadReplyFilterReason> _reasonsByPid =
      <String, ThreadReplyFilterReason>{};
  final Set<int> _observedPages = <int>{};
  String? _threadId;
  String? _queryIdentity;
  Map<String, String> _queryParameters = const <String, String>{};
  String? _pinnedPid;
  int _lastPage = 0;
  int _currentPage = 0;
  bool _onLastPage = false;
  Set<String> _membership = const <String>{};
  Object? _filterIdentity;
  bool _hasActiveFilters = false;
  ThreadReplyFilterReason Function(ThreadPost post)? _evaluatePost;
  List<ThreadPost>? _tailCache;
  int _revision = 0;
  int _generation = 0;
  int _retainedPosts = 0;
  bool _collecting = false;
  bool _budgetExhausted = false;
  bool _failed = false;
  bool _disposed = false;
  bool _notifyScheduled = false;
  Future<void>? _inFlight;

  /// Display generation; the render list and navigation snapshot share it.
  int get revision => _revision;

  bool get isCollecting => _collecting;
  bool get hasBudgetLimitation => _budgetExhausted;
  bool get hasFailure => _failed;

  /// Blocked replies in reading order across all observed pages.
  List<ThreadPost> get tailPosts {
    final cached = _tailCache;
    if (cached != null) return cached;
    final seen = <String>{};
    final posts = <ThreadPost>[];
    for (final page in _observedPages.toList()..sort()) {
      for (final post in _blockedByPage[page] ?? const <ThreadPost>[]) {
        if (!seen.add(post.pid)) continue;
        posts.add(post);
      }
    }
    return _tailCache = List<ThreadPost>.unmodifiable(posts);
  }

  /// Blocked replies removed from their source floor, by stable post id.
  Set<String> get movedPids {
    final pids = <String>{
      for (final post in tailPosts)
        if (post.pid != _pinnedPid) post.pid,
    };
    return Set<String>.unmodifiable(pids);
  }

  /// Reasons for filtered replies keyed by post id.
  Map<String, ThreadReplyFilterReason> get reasonsByPid =>
      Map<String, ThreadReplyFilterReason>.unmodifiable(_reasonsByPid);

  ThreadReplyFilterReason? reasonFor(String pid) => _reasonsByPid[pid];

  /// The tail is only visible on the page that ended the thread.
  bool get showTail => _onLastPage;

  /// Every page from one to the last page has been scanned.
  bool get complete {
    if (!_hasActiveFilters) return true;
    if (_lastPage <= 0) return false;
    if ((_threadId ?? '').isEmpty) return false;
    for (var page = 1; page <= _lastPage; page++) {
      if (!_observedPages.contains(page)) return false;
    }
    return true;
  }

  /// The last page is displayed while its complete tail is still unknown.
  bool get tailPending => _hasActiveFilters && _onLastPage && !complete;

  /// Records one visible page and its current filter configuration.
  ///
  /// Called from build: state changes are published after the frame instead of
  /// notifying listeners during layout.
  void observe({
    required String threadId,
    required String queryIdentity,
    Map<String, String> queryParameters = const <String, String>{},
    required int page,
    required List<ThreadPost> posts,
    required bool isLastPage,
    required Set<String> blacklistedUserIds,
    String? pinnedPid,
    ThreadReplyFilterReason Function(ThreadPost post)? evaluatePost,
    Object? filterIdentity,
    bool? hasActiveFilters,
  }) {
    if (_disposed) return;
    final normalizedTid = threadId.trim();
    final threadChanged =
        normalizedTid.isNotEmpty && normalizedTid != _threadId;
    final queryChanged =
        _queryIdentity != null && queryIdentity != _queryIdentity;
    if (threadChanged || queryChanged) {
      _resetInternal(
        threadId: normalizedTid.isEmpty ? _threadId : normalizedTid,
        queryIdentity: queryIdentity,
      );
    }
    if (normalizedTid.isNotEmpty) _threadId = normalizedTid;
    _queryIdentity = queryIdentity;
    _queryParameters = Map<String, String>.unmodifiable(queryParameters);
    _evaluatePost = evaluatePost;
    final effectiveHasActiveFilters =
        hasActiveFilters ?? blacklistedUserIds.isNotEmpty;
    if (!_setEquals(_membership, blacklistedUserIds) ||
        filterIdentity != _filterIdentity ||
        _hasActiveFilters != effectiveHasActiveFilters) {
      _membership = Set<String>.unmodifiable(blacklistedUserIds);
      _filterIdentity = filterIdentity;
      _hasActiveFilters = effectiveHasActiveFilters;
      // Filter rules decide tail ownership; collected coverage is retired so
      // every page is re-scanned with the new configuration.
      _generation++;
      _clearCollected();
      _invalidate();
    }
    final normalizedPinned = pinnedPid?.trim();
    if (normalizedPinned != _pinnedPid) {
      _pinnedPid = normalizedPinned;
      _invalidate();
    }
    if (page <= 0) return;
    _currentPage = page;
    _onLastPage = isLastPage;
    if (_onLastPage) _lastPage = page;
    _observePage(page, posts);
  }

  void _observePage(int page, List<ThreadPost> posts) {
    final blocked = <ThreadPost>[];
    final nextReasons = <String, ThreadReplyFilterReason>{};
    for (final post in posts) {
      if (post.isFirst || post.number == 1) continue;
      final reason = _evaluatePost != null
          ? _evaluatePost!(post)
          : ThreadReplyFilterReason(isBlacklistedAuthor: _isBlocked(post));
      if (!reason.isFiltered) continue;
      blocked.add(post);
      nextReasons[post.pid] = reason;
    }
    final blockedPids = <String>[for (final post in blocked) post.pid];
    final previousPids = _blockedPidsByPage[page];
    _observedPages.add(page);
    var reasonsChanged = false;
    for (final entry in nextReasons.entries) {
      if (_reasonsByPid[entry.key] != entry.value) {
        reasonsChanged = true;
        break;
      }
    }
    if (previousPids != null &&
        listEquals(previousPids, blockedPids) &&
        !reasonsChanged) {
      return;
    }
    final previous = _blockedByPage[page];
    if (previous != null) {
      _retainedPosts -= previous.length;
      for (final oldPost in previous) {
        if (!nextReasons.containsKey(oldPost.pid)) {
          _reasonsByPid.remove(oldPost.pid);
        }
      }
    }
    _reasonsByPid.addAll(nextReasons);
    _blockedPidsByPage[page] = List<String>.unmodifiable(blockedPids);
    if (blocked.isEmpty) {
      _blockedByPage.remove(page);
    } else {
      _blockedByPage[page] = List<ThreadPost>.unmodifiable(blocked);
      _retainedPosts += blocked.length;
    }
    _trimBudget();
    _invalidate();
  }

  bool _isBlocked(ThreadPost post) {
    final authorId = post.authorId.trim();
    if (authorId.isEmpty || !_membership.contains(authorId)) return false;
    // The topic body keeps the existing author fold / whole-thread gate.
    return !(post.isFirst || post.number == 1);
  }

  void _trimBudget() {
    if (_retainedPosts <= maxBlockedPosts) return;
    for (final page in _observedPages.toList()..sort()) {
      if (_retainedPosts <= maxBlockedPosts) break;
      if (page == _currentPage) continue;
      final removed = _blockedByPage.remove(page);
      _retainedPosts -= removed?.length ?? 0;
      if (removed != null) {
        for (final post in removed) {
          _reasonsByPid.remove(post.pid);
        }
      }
      _blockedPidsByPage.remove(page);
      // A dropped page is re-readable; the session no longer claims coverage.
      _observedPages.remove(page);
      _budgetExhausted = true;
    }
  }

  /// Fills pages that were never visited once the last page is displayed.
  Future<void> ensureComplete({
    required bool Function() isCurrent,
    bool force = false,
  }) {
    if (_disposed ||
        !_onLastPage ||
        complete ||
        !_hasActiveFilters ||
        _lastPage < 2) {
      return Future<void>.value();
    }
    final running = _inFlight;
    if (running != null) return running;
    if (_budgetExhausted && !force) return Future<void>.value();
    if (force) _budgetExhausted = false;
    _failed = false;
    late final Future<void> run;
    run = _collect(isCurrent).whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
      if (_disposed) return;
      _collecting = false;
      _invalidate();
    });
    _inFlight = run;
    _collecting = true;
    return run;
  }

  Future<void> _collect(bool Function() isCurrent) async {
    final generation = _generation;
    final queryParameters = _queryParameters;
    var fetched = 0;
    for (var page = 1; page <= _lastPage; page++) {
      if (_observedPages.contains(page)) continue;
      if (fetched >= maxPagesPerPass) {
        _budgetExhausted = true;
        return;
      }
      if (_disposed || generation != _generation || !isCurrent()) return;
      final result = await readPage(page, queryParameters);
      if (_disposed || generation != _generation || !isCurrent()) return;
      if (result == null) {
        _failed = true;
        return;
      }
      fetched++;
      _observePage(result.page > 0 ? result.page : page, result.posts);
    }
  }

  void _clearCollected() {
    _blockedByPage.clear();
    _blockedPidsByPage.clear();
    _reasonsByPid.clear();
    _observedPages.clear();
    _retainedPosts = 0;
    _budgetExhausted = false;
    _failed = false;
    _tailCache = null;
  }

  void _resetInternal({
    required String? threadId,
    required String queryIdentity,
  }) {
    _generation++;
    _threadId = threadId;
    _queryIdentity = queryIdentity;
    _lastPage = 0;
    _currentPage = 0;
    _onLastPage = false;
    _inFlight = null;
    _collecting = false;
    _clearCollected();
    _invalidate();
  }

  /// Resets every collected page, e.g. when the route owner changes.
  void reset() {
    if (_disposed) return;
    _generation++;
    _threadId = null;
    _queryIdentity = null;
    _queryParameters = const <String, String>{};
    _pinnedPid = null;
    _filterIdentity = null;
    _hasActiveFilters = false;
    _evaluatePost = null;
    _lastPage = 0;
    _currentPage = 0;
    _onLastPage = false;
    _inFlight = null;
    _collecting = false;
    _clearCollected();
    _invalidate();
  }

  void _invalidate() {
    _revision++;
    _tailCache = null;
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
    // Collection finishes outside a frame; the owner rebuilds only after this
    // notification, so a frame must be scheduled explicitly.
    WidgetsBinding.instance.scheduleFrame();
  }

  bool _setEquals(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    for (final value in left) {
      if (!right.contains(value)) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _inFlight = null;
    super.dispose();
  }
}
