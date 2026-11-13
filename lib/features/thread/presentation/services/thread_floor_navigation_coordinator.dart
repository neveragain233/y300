import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

final class ThreadFloorPage {
  const ThreadFloorPage({
    required this.owner,
    required this.page,
    required this.pids,
    required this.hasPrevious,
    required this.hasNext,
    this.loading = false,
  });
  final Object owner;
  final int page;
  final List<String> pids;
  final bool hasPrevious;
  final bool hasNext;
  final bool loading;
}

abstract interface class ThreadFloorViewport {
  String? get visiblePostId;
  bool get atBottom;
  Future<bool> revealPageEnd({
    required bool animate,
    required bool Function() isCurrent,
  });
  Future<bool> revealPost(
    String pid, {
    required bool animate,
    required bool Function() isCurrent,
  });
}

/// 翻楼意图独立于正文几何；页末需要下一次显式操作才发起跨页。
final class ThreadFloorNavigationCoordinator extends ChangeNotifier {
  ThreadFloorNavigationCoordinator({
    required this.readPage,
    required this.loadAdjacent,
    this.onStarted,
    this.onConfirmed,
  });
  final ThreadFloorPage? Function() readPage;
  final Future<bool> Function(bool forward, bool Function() isCurrent)
  loadAdjacent;
  final VoidCallback? onStarted;
  final VoidCallback? onConfirmed;
  ThreadFloorViewport? _viewport;
  Object? _owner;
  int? _page;
  String? _confirmedPid;
  Future<void>? _pending;
  bool? _pendingForward;
  String? _pendingPid;
  bool _pendingSingle = false;
  bool _loadingAdjacent = false;
  bool _disposed = false;
  int _generation = 0;
  bool _notifyScheduled = false;
  bool forward = true;

  bool get isNavigating => _pending != null;
  bool get isLoadingAdjacent => _loadingAdjacent;
  bool get atEnd {
    final page = readPage();
    return page != null &&
        page.pids.isNotEmpty &&
        !page.loading &&
        !isNavigating &&
        !page.hasNext &&
        _viewport?.atBottom == true;
  }

  bool get canAdvance {
    final page = readPage();
    return _viewport != null &&
        page != null &&
        page.pids.isNotEmpty &&
        (!page.loading || isNavigating);
  }

  String? get currentPostId {
    final page = readPage();
    if (page == null || page.pids.isEmpty) return null;
    final current = _confirmedPid ?? _viewport?.visiblePostId;
    return page.pids.contains(current) ? current : page.pids.first;
  }

  bool canMove(bool forward) {
    final page = readPage();
    if (page == null || page.pids.isEmpty || page.loading && !isNavigating) {
      return false;
    }
    final index = page.pids.indexOf(currentPostId ?? '');
    return forward
        ? index < page.pids.length - 1 || page.hasNext
        : index > 0 || page.hasPrevious;
  }

  void bind(ThreadFloorViewport viewport) {
    if (_viewport != null && !identical(_viewport, viewport)) cancel();
    _viewport = viewport;
    refresh();
  }

  void unbind(ThreadFloorViewport viewport) {
    if (!identical(_viewport, viewport)) return;
    _viewport = null;
    cancel();
  }

  void refresh() {
    final page = readPage();
    if (page?.owner != _owner) forward = true;
    if (page?.owner != _owner || page?.page != _page && !_loadingAdjacent) {
      cancel();
    }
    _owner = page?.owner;
    _page = page?.page;
    _notify();
  }

  void userScrolled() {
    cancel();
    _notify();
  }

  void cancel({bool clearPosition = true}) {
    _generation++;
    _pending = null;
    _pendingForward = null;
    _pendingPid = null;
    _pendingSingle = false;
    _loadingAdjacent = false;
    if (clearPosition) _confirmedPid = null;
    _notify();
  }

  void reverseDirection() {
    cancel(clearPosition: false);
    forward = !forward;
    onStarted?.call();
    _notify();
  }

  void resetDirection() {
    forward = true;
    _notify();
  }

  Future<void> firstPost({required bool animate}) {
    resetDirection();
    final page = readPage();
    if (page == null || page.pids.isEmpty) return Future.value();
    return _navigate(null, page.pids.first, animate);
  }

  Future<void> move(bool forward, {required bool animate}) =>
      _navigate(forward, null, animate);

  Future<void> advance({required bool animate}) =>
      _navigate(forward, null, animate, single: true);

  Future<void> _navigate(
    bool? forward,
    String? pid,
    bool animate, {
    bool single = false,
  }) {
    if (_disposed) return Future.value();
    if (_pendingForward == forward &&
        _pendingPid == pid &&
        _pendingSingle == single &&
        _pending != null) {
      return _pending!;
    }
    final wasNavigating = isNavigating;
    cancel(clearPosition: false);
    final generation = _generation;
    final page = readPage();
    final viewport = _viewport;
    if (page == null ||
        viewport == null ||
        page.pids.isEmpty ||
        page.loading && !wasNavigating) {
      return Future.value();
    }
    final owner = page.owner;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        readPage()?.owner == owner &&
        identical(viewport, _viewport);
    _pendingForward = forward;
    _pendingPid = pid;
    _pendingSingle = single;
    onStarted?.call();
    final operation = pid == null
        ? _move(page, viewport, forward!, animate, current, single: single)
        : _reveal(viewport, pid, animate, current);
    final pending = operation.whenComplete(() {
      if (!current()) return;
      _pending = null;
      _pendingForward = null;
      _pendingPid = null;
      _pendingSingle = false;
      _loadingAdjacent = false;
      _notify();
    });
    _pending = pending;
    _notify();
    return pending;
  }

  Future<void> _move(
    ThreadFloorPage page,
    ThreadFloorViewport viewport,
    bool forward,
    bool animate,
    bool Function() current, {
    required bool single,
  }) async {
    final index = page.pids.indexOf(currentPostId ?? '');
    final targetIndex = index + (forward ? 1 : -1);
    String target;
    if (targetIndex >= 0 && targetIndex < page.pids.length) {
      target = page.pids[targetIndex];
    } else {
      if (!(forward ? page.hasNext : page.hasPrevious)) {
        if (single && forward) {
          // 末楼楼头不等于整帖底部；先展示剩余正文，再呈现回顶动作。
          final reached = await viewport.revealPageEnd(
            animate: animate,
            isCurrent: current,
          );
          if (current() && reached) {
            _confirmedPid = page.pids.last;
            onConfirmed?.call();
          }
        } else if (single && current()) {
          this.forward = true;
        }
        return;
      }
      _loadingAdjacent = true;
      final loaded = await loadAdjacent(forward, current);
      if (!current() || !loaded) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return;
      final next = readPage();
      if (next == null || next.page == page.page || next.pids.isEmpty) return;
      target = forward ? next.pids.first : next.pids.last;
    }
    if (!current()) return;
    await _reveal(viewport, target, animate, current);
  }

  Future<void> _reveal(
    ThreadFloorViewport viewport,
    String target,
    bool animate,
    bool Function() current,
  ) async {
    final reached = await viewport.revealPost(
      target,
      animate: animate,
      isCurrent: current,
    );
    if (!current() || !reached) return;
    _confirmedPid = target;
    onConfirmed?.call();
  }

  void _notify() {
    if (_disposed) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _viewport = null;
    super.dispose();
  }
}
