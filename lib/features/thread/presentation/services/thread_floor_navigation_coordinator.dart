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
    this.topicPid,
    this.tailPending = false,
  });
  final Object owner;
  final int page;
  final List<String> pids;
  final bool hasPrevious;
  final bool hasNext;
  final bool loading;

  /// 当前页包含主题首楼时的稳定帖子编号，用于返回正文时核对身份。
  final String? topicPid;

  /// 末页被屏蔽回复的尾部集合仍在归集；覆盖完成前全帖末端未确认。
  final bool tailPending;
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

  /// 真实内容末端：滚动边界、末条目实际布局和页尾避让空间都已确认；
  /// 末楼楼头可见不算到达。只返回最近一次实测结果。
  bool get atBottom;

  /// 在构建和布局之外重新测量内容末端。
  void refreshEndGeometry();

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
/// 已确认目标不会覆盖用户之后实际停留的位置。向下的末端动作先核对
/// 真实内容末端，再决定跨页或返回第一页主题正文。
final class ThreadFloorNavigationCoordinator extends ChangeNotifier {
  ThreadFloorNavigationCoordinator({
    required this.readPage,
    required this.loadAdjacent,
    this.loadTopicBody,
    this.onStarted,
    this.onConfirmed,
    this.onBoundaryReached,
    this.onTailPending,
  });
  final ThreadFloorPage? Function() readPage;
  final Future<bool> Function(bool forward, bool Function() isCurrent)
  loadAdjacent;

  /// 回第一页主题正文需要跨页时加载第一页；加载失败保留原页。
  final Future<bool> Function(bool Function() isCurrent)? loadTopicBody;
  final VoidCallback? onStarted;
  final VoidCallback? onConfirmed;

  /// 到达页尾或首末边界时回调一次；加载、失败和取消不触发。
  final VoidCallback? onBoundaryReached;

  /// 末页尾部集合尚未归集完成时请求补取，不发布末端确认。
  final VoidCallback? onTailPending;
  ThreadFloorViewport? _viewport;
  Object? _owner;
  int? _page;
  String? _lastVisiblePid;
  String? _boundaryKey;
  Future<void>? _pending;
  bool? _pendingForward;
  String? _pendingPid;
  bool _pendingSingle = false;
  bool _pendingTopicBody = false;
  bool _loadingAdjacent = false;
  bool _disposed = false;
  int _generation = 0;
  bool _notifyScheduled = false;
  bool _boundaryRefreshScheduled = false;
  bool _allowOwnerChange = false;
  bool forward = true;

  bool get isNavigating => _pending != null;
  bool get isLoadingAdjacent => _loadingAdjacent;

  /// 全帖完整末端已确认（末页尾部归集完成且滚动到底）。
  bool get atEnd {
    final page = readPage();
    return page != null &&
        page.pids.isNotEmpty &&
        !page.loading &&
        !isNavigating &&
        !page.hasNext &&
        !page.tailPending &&
        _viewport?.atBottom == true;
  }

  bool get canAdvance {
    final page = readPage();
    return _viewport != null && page != null && (!page.loading || isNavigating);
  }

  String? get currentPostId => _resolveCurrentPid();

  bool canMove(bool forward) {
    final page = readPage();
    final viewport = _viewport;
    if (page == null || viewport == null || page.loading && !isNavigating) {
      return false;
    }
    if (forward) {
      // 向下始终可操作：页尾之后有后继页时跨页，完整末端时返回主题正文，
      // 尾部集合未完成时只请求补取，不因等待状态禁用按钮。
      return true;
    }
    final index = page.pids.indexOf(currentPostId ?? '');
    return index > 0 || page.hasPrevious;
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
    final ownerChanged = page?.owner != _owner;
    // 返回主题正文时会主动清除作者过滤，查询身份随之变化；这段加载窗口
    // 由导航自身持有，不能因此取消。
    if (ownerChanged && !_allowOwnerChange) forward = true;
    if (ownerChanged || page?.page != _page) {
      _lastVisiblePid = null;
      _boundaryKey = null;
    }
    if (ownerChanged && !_allowOwnerChange ||
        page?.page != _page && !_loadingAdjacent) {
      cancel();
    }
    _owner = page?.owner;
    _page = page?.page;
    // 末端几何只能在布局完成后测量；构建期刷新只安排一次延迟核对。
    scheduleBoundaryRefresh();
    _notify();
  }

  /// 延后测量内容末端，避免在构建或布局阶段读取尺寸。
  void scheduleBoundaryRefresh() {
    if (_disposed || _boundaryRefreshScheduled) return;
    final viewport = _viewport;
    if (viewport == null) return;
    _boundaryRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boundaryRefreshScheduled = false;
      if (_disposed) return;
      final active = _viewport;
      if (active == null) return;
      active.refreshEndGeometry();
      _notify();
    });
    WidgetsBinding.instance.scheduleFrame();
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
    _pendingTopicBody = false;
    _loadingAdjacent = false;
    _allowOwnerChange = false;
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

  /// 返回第一页主题正文；跨页时先确认第一页加载成功再按首楼身份定位。
  Future<void> firstPost({required bool animate}) {
    resetDirection();
    return _navigate(null, null, animate, topicBody: true);
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
    bool topicBody = false,
  }) {
    if (_disposed) return Future.value();
    if (_pendingForward == forward &&
        _pendingPid == pid &&
        _pendingSingle == single &&
        _pendingTopicBody == topicBody &&
        _pending != null) {
      return _pending!;
    }
    final wasNavigating = isNavigating;
    cancel();
    final generation = _generation;
    final page = readPage();
    final viewport = _viewport;
    if (page == null || viewport == null || page.loading && !wasNavigating) {
      return Future.value();
    }
    final owner = page.owner;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        identical(viewport, _viewport) &&
        (_allowOwnerChange || readPage()?.owner == owner);
    _pendingForward = forward;
    _pendingPid = pid;
    _pendingSingle = single;
    _pendingTopicBody = topicBody;
    onStarted?.call();
    final operation = topicBody
        ? _returnToTopicBody(viewport, animate, current)
        : pid == null
        ? _move(page, viewport, forward!, animate, current, single: single)
        : _reveal(viewport, pid, animate, current);
    final pending = operation.whenComplete(() {
      if (!current()) return;
      _pending = null;
      _pendingForward = null;
      _pendingPid = null;
      _pendingSingle = false;
      _pendingTopicBody = false;
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
    final index = currentPid == null ? -1 : page.pids.indexOf(currentPid);
    if (forward) {
      // 先核对真实内容末端：已经读到底时不能再按最上方可见楼层挑“下一楼”，
      // 否则多层短回复同屏会反复定位旧楼而不跨页。
      viewport.refreshEndGeometry();
      if (viewport.atBottom) {
        if (page.hasNext) {
          await _loadAdjacentPage(
            page,
            viewport,
            forward: true,
            animate: animate,
            current: current,
          );
          return;
        }
        if (page.tailPending) {
          // 尾部集合未完成：不确认全帖末端，也不触发回正文。
          onTailPending?.call();
          return;
        }
        await _returnToTopicBody(viewport, animate, current);
        return;
      }
      // 楼内先走完按正文顺序排列的图片停靠点，再换楼。
      final imageStop = _nextImageStop(viewport, currentPid, true);
      if (imageStop != null) {
        await _revealImage(viewport, imageStop, animate, current);
        return;
      }
      final targetIndex = index + 1;
      if (index >= 0 && targetIndex < page.pids.length) {
        await _reveal(viewport, page.pids[targetIndex], animate, current);
        return;
      }
      if (index < 0 && page.pids.isNotEmpty) {
        await _reveal(viewport, page.pids.first, animate, current);
        return;
      }
      await _revealPageEnd(
        viewport,
        page,
        animate: animate,
        current: current,
        boundary: page.hasNext
            ? 'page-end'
            : page.tailPending
            ? null
            : 'thread-end',
      );
      return;
    }

    final currentStops = viewport.imageStops(currentPid ?? '');
    final imageStop = _nextImageStop(viewport, currentPid, false);
    if (imageStop != null) {
      await _revealImage(viewport, imageStop, animate, current);
      return;
    }
    // 有图片停靠点的楼层向上退完图片后，再回到本楼楼头。
    if (currentStops.isNotEmpty &&
        currentPid != null &&
        viewport.isPostHeaderAbove(currentPid)) {
      await _reveal(viewport, currentPid, animate, current);
      return;
    }
    final targetIndex = index - 1;
    if (index >= 0 && targetIndex >= 0) {
      final targetPid = page.pids[targetIndex];
      // 向上退入图片楼时先落在最后一个有效图片点。
      final stops = viewport.imageStops(targetPid);
      if (stops.isNotEmpty) {
        await _revealImage(viewport, stops.last, animate, current);
        return;
      }
      await _reveal(viewport, targetPid, animate, current);
      return;
    }
    if (page.hasPrevious) {
      await _loadAdjacentPage(
        page,
        viewport,
        forward: false,
        animate: animate,
        current: current,
      );
      return;
    }
    if (index < 0 && page.pids.isNotEmpty) {
      await _reveal(viewport, page.pids.last, animate, current);
      return;
    }
    // 首页首楼已是真实首端；单键在此把方向复位为向下。
    if (single && current()) {
      this.forward = true;
      _notify();
    }
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
    required String? boundary,
  }) async {
    final reached = await viewport.revealPageEnd(
      animate: animate,
      isCurrent: current,
    );
    if (!current() || !reached) return;
    if (boundary != null) _signalBoundary(page, boundary);
    onConfirmed?.call();
  }

  Future<void> _loadAdjacentPage(
    ThreadFloorPage initialPage,
    ThreadFloorViewport viewport, {
    required bool forward,
    required bool animate,
    required bool Function() current,
  }) async {
    _loadingAdjacent = true;
    var page = initialPage;
    // 相邻页可能整页都是被移走的回复：沿服务端后继页有界前进到可读页。
    for (var attempt = 0; attempt < 3; attempt++) {
      final loaded = await loadAdjacent(forward, current);
      if (!current() || !loaded) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return;
      final next = readPage();
      if (next == null || next.page == page.page) return;
      page = next;
      if (next.pids.isNotEmpty) {
        final target = forward ? next.pids.first : next.pids.last;
        await _reveal(viewport, target, animate, current);
        return;
      }
      if (forward ? !next.hasNext : !next.hasPrevious) return;
    }
  }

  Future<void> _returnToTopicBody(
    ThreadFloorViewport viewport,
    bool animate,
    bool Function() current,
  ) async {
    var page = readPage();
    if (page == null) return;
    // 第一页加载可能主动清除作者过滤，查询身份随之变化；这段窗口由本次
    // 导航持有，不能被自己触发的刷新取消。
    _allowOwnerChange = true;
    try {
      var topicPid = page.topicPid;
      if (page.page != 1 || topicPid == null || !page.pids.contains(topicPid)) {
        final load = loadTopicBody;
        if (load == null) return;
        _loadingAdjacent = true;
        final loaded = await load(current);
        if (!current() || !loaded) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!current()) return;
        page = readPage();
        topicPid = page?.topicPid;
        if (page == null || topicPid == null || !page.pids.contains(topicPid)) {
          return;
        }
      }
      await _reveal(viewport, topicPid, animate, current);
      if (!current()) return;
      // 返回正文后单键与双键向下都从主题正文继续。
      forward = true;
      _notify();
    } finally {
      _allowOwnerChange = false;
    }
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
    // 到达末楼楼头不等于正文末端；末端反馈只由实测页尾发布。
    if (page != null &&
        page.pids.isNotEmpty &&
        !page.hasPrevious &&
        page.page == 1 &&
        target == page.pids.first) {
      _signalBoundary(page, 'thread-start');
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
