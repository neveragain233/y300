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

/// 楼内图片停靠点：图片顶边对齐到阅读区顶部所需的内容滚动位置。
final class ThreadFloorImageStop {
  const ThreadFloorImageStop({
    required this.postId,
    required this.index,
    required this.cacheKey,
    required this.url,
    required this.offset,
  });

  final String postId;
  final int index;
  final String cacheKey;
  final String url;
  final double offset;
}

abstract interface class ThreadFloorViewport {
  String? get visiblePostId;

  /// 当前滚动位置；居中列表换绑等无法确认时为 null。
  double? get scrollPixels;

  /// 真实滚动位置到达当前页底部；末楼楼头可见不算到达。
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

  /// 该楼当前已参与正文布局的图片落点，按正文顺序、扣除置顶遮挡并合并重复点。
  List<ThreadFloorImageStop> imageStops(String pid);

  /// 楼头是否已经完全滚出阅读区上方，可作为一个向上停靠点。
  bool isPostHeaderAbove(String pid);

  Future<bool> revealImageStop(
    ThreadFloorImageStop stop, {
    required bool animate,
    required bool Function() isCurrent,
  });
}

/// 翻楼意图独立于正文几何；页末需要下一次显式操作才发起跨页。
///
/// 状态分别由实际可见楼层、在途目标、当前页末楼和真实滚动底部决定，
/// 已确认目标不会覆盖用户之后实际停留的位置。
final class ThreadFloorNavigationCoordinator extends ChangeNotifier {
  ThreadFloorNavigationCoordinator({
    required this.readPage,
    required this.loadAdjacent,
    this.onStarted,
    this.onConfirmed,
    this.onBoundaryReached,
  });
  final ThreadFloorPage? Function() readPage;
  final Future<bool> Function(bool forward, bool Function() isCurrent)
  loadAdjacent;
  final VoidCallback? onStarted;
  final VoidCallback? onConfirmed;

  /// 到达页尾或首末边界时回调一次；加载、失败和取消不触发。
  final VoidCallback? onBoundaryReached;
  ThreadFloorViewport? _viewport;
  Object? _owner;
  int? _page;
  String? _lastVisiblePid;
  String? _boundaryKey;
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

  String? get currentPostId => _resolveCurrentPid();

  bool canMove(bool forward) {
    final page = readPage();
    if (page == null || page.pids.isEmpty || page.loading && !isNavigating) {
      return false;
    }
    final index = page.pids.indexOf(currentPostId ?? '');
    return forward
        ? index < page.pids.length - 1 ||
              page.hasNext ||
              !(_viewport?.atBottom ?? false)
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
    if (page?.owner != _owner || page?.page != _page) {
      _lastVisiblePid = null;
      _boundaryKey = null;
    }
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

  void cancel() {
    _generation++;
    _pending = null;
    _pendingForward = null;
    _pendingPid = null;
    _pendingSingle = false;
    _loadingAdjacent = false;
    _notify();
  }

  void reverseDirection() {
    cancel();
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

  String? _resolveCurrentPid() {
    final page = readPage();
    if (page == null || page.pids.isEmpty) return null;
    final visible = _viewport?.visiblePostId;
    if (visible != null && page.pids.contains(visible)) {
      _lastVisiblePid = visible;
    }
    final current = _pendingPid ?? _lastVisiblePid;
    return page.pids.contains(current) ? current : page.pids.first;
  }

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
    cancel();
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
    final currentPid = _resolveCurrentPid();
    final index = page.pids.indexOf(currentPid ?? '');
    // 楼内先走完按正文顺序排列的图片停靠点，再换楼。
    final currentStops = viewport.imageStops(currentPid ?? '');
    final imageStop = _nextImageStop(viewport, currentPid, forward);
    if (imageStop != null) {
      await _revealImage(viewport, imageStop, animate, current);
      return;
    }
    // 有图片停靠点的楼层向上退完图片后，再回到本楼楼头。
    if (!forward &&
        currentStops.isNotEmpty &&
        currentPid != null &&
        viewport.isPostHeaderAbove(currentPid)) {
      await _reveal(viewport, currentPid, animate, current);
      return;
    }
    final targetIndex = index + (forward ? 1 : -1);
    if (targetIndex >= 0 && targetIndex < page.pids.length) {
      final targetPid = page.pids[targetIndex];
      if (!forward) {
        // 向上退入图片楼时先落在最后一个有效图片点。
        final stops = viewport.imageStops(targetPid);
        if (stops.isNotEmpty) {
          await _revealImage(viewport, stops.last, animate, current);
          return;
        }
      }
      await _reveal(viewport, targetPid, animate, current);
      return;
    }
    if (forward) {
      if (page.hasNext) {
        if (!viewport.atBottom) {
          await _revealPageEnd(
            viewport,
            page,
            animate: animate,
            current: current,
            boundary: 'page-end',
          );
          return;
        }
        await _loadAdjacentPage(
          page,
          viewport,
          forward: true,
          animate: animate,
          current: current,
        );
        return;
      }
      // 最后一页：先让末楼正文读到底，无下一页时单键随后切为回首楼。
      if (!viewport.atBottom) {
        await _revealPageEnd(
          viewport,
          page,
          animate: animate,
          current: current,
          boundary: 'thread-end',
        );
        return;
      }
      if (single && current()) {
        this.forward = true;
        _notify();
      }
      return;
    }
    if (!page.hasPrevious) {
      // 首页首楼已是真实首端；单键在此把方向复位为向下。
      if (single && current()) {
        this.forward = true;
        _notify();
      }
      return;
    }
    await _loadAdjacentPage(
      page,
      viewport,
      forward: false,
      animate: animate,
      current: current,
    );
  }

  ThreadFloorImageStop? _nextImageStop(
    ThreadFloorViewport viewport,
    String? pid,
    bool forward,
  ) {
    if (pid == null) return null;
    final stops = viewport.imageStops(pid);
    if (stops.isEmpty) return null;
    final pixels = viewport.scrollPixels;
    if (pixels == null) return null;
    const tolerance = 1.0;
    ThreadFloorImageStop? best;
    for (final stop in stops) {
      if (forward) {
        if (stop.offset <= pixels + tolerance) continue;
        if (best == null || stop.offset < best.offset) best = stop;
      } else {
        if (stop.offset >= pixels - tolerance) continue;
        if (best == null || stop.offset > best.offset) best = stop;
      }
    }
    return best;
  }

  Future<void> _revealImage(
    ThreadFloorViewport viewport,
    ThreadFloorImageStop stop,
    bool animate,
    bool Function() current,
  ) async {
    final reached = await viewport.revealImageStop(
      stop,
      animate: animate,
      isCurrent: current,
    );
    if (!current() || !reached) return;
    _lastVisiblePid = stop.postId;
    onConfirmed?.call();
  }

  Future<void> _revealPageEnd(
    ThreadFloorViewport viewport,
    ThreadFloorPage page, {
    required bool animate,
    required bool Function() current,
    required String boundary,
  }) async {
    final reached = await viewport.revealPageEnd(
      animate: animate,
      isCurrent: current,
    );
    if (!current() || !reached) return;
    _signalBoundary(page, boundary);
    onConfirmed?.call();
  }

  Future<void> _loadAdjacentPage(
    ThreadFloorPage page,
    ThreadFloorViewport viewport, {
    required bool forward,
    required bool animate,
    required bool Function() current,
  }) async {
    _loadingAdjacent = true;
    final loaded = await loadAdjacent(forward, current);
    if (!current() || !loaded) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!current()) return;
    final next = readPage();
    if (next == null || next.page == page.page || next.pids.isEmpty) return;
    final target = forward ? next.pids.first : next.pids.last;
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
    _lastVisiblePid = target;
    final page = readPage();
    if (page != null && page.pids.isNotEmpty) {
      if (!page.hasPrevious && page.page == 1 && target == page.pids.first) {
        _signalBoundary(page, 'thread-start');
      } else if (!page.hasNext && target == page.pids.last) {
        _signalBoundary(page, 'thread-end');
      }
    }
    onConfirmed?.call();
  }

  /// 同一页的同类边界只反馈一次；换页、换查询或进入新的到达代次时重新计。
  void _signalBoundary(ThreadFloorPage page, String boundary) {
    final key = '${page.owner}|${page.page}|$boundary';
    if (_boundaryKey == key) return;
    _boundaryKey = key;
    onBoundaryReached?.call();
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
