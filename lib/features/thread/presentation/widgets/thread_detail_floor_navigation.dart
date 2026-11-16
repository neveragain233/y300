part of 'thread_detail_widgets.dart';

mixin _ThreadDetailFloorNavigation on ConsumerState<ThreadDetailContent>
    implements ThreadFloorViewport {
  ThreadPostViewportAnchorCoordinator get _projectionAnchorCoordinator;
  GlobalKey get _viewportKey;
  GlobalKey get _listEndKey;
  Object? get _renderLayoutIdentity;
  double get _repliesHeaderHeight;
  bool get _repliesHeaderPinned;
  bool _targetBelowRepliesHeader(String pid);
  set _targetCenterKey(GlobalKey value);
  GlobalKey get _targetCenterKey;
  set _endpointTarget(ThreadDetailQuickScrollTarget? value);
  ThreadDetailQuickScrollTarget? get _endpointTarget;
  int get _endpointViewRevision;
  set _endpointViewRevision(int value);
  set _pendingChunkAnchor(ThreadPostViewportAnchorSnapshot? value);
  Iterable<String> _sourcePidsFor(ThreadDetailContent target);
  Future<ThreadDetailEndpointNavigationResult> _navigateToEndpoint({
    required ThreadDetailQuickScrollTarget target,
    required bool animate,
    required Duration duration,
    required bool Function() isCurrent,
  });

  String? _floorTargetPid;
  final _floorHeaderKeys = <String, GlobalKey>{};
  GlobalKey _floorHeaderKey(String pid) => _floorHeaderKeys.putIfAbsent(
    pid,
    () => GlobalKey(debugLabel: 'thread-floor-header-$pid'),
  );
  BuildContext? _floorTopContext(String pid) {
    final header = _floorHeaderKeys[pid]?.currentContext;
    if (header != null) return header;
    if (_activeLanding == ThreadPostLanding.bodyEnd &&
        _activeTargetPid == pid) {
      return null;
    }
    return _projectionAnchorCoordinator.keyForPid(pid).currentContext;
  }

  int _floorGeneration = 0;
  ({
    bool Function() current,
    String? pid,
    GlobalKey center,
    int revision,
    ThreadDetailQuickScrollTarget? endpoint,
  })?
  _pendingFloorBuild;

  void _prepareFloorBuild() {
    final pending = _pendingFloorBuild;
    _pendingFloorBuild = null;
    if (pending == null || pending.current()) return;
    _floorTargetPid = pending.pid;
    _targetCenterKey = pending.center;
    _endpointViewRevision = pending.revision;
    _endpointTarget = pending.endpoint;
  }

  String? get _activeTargetPid => _floorTargetPid ?? widget.targetPid?.trim();
  ThreadPostLanding get _activeLanding =>
      _floorTargetPid == null ? widget.landing : ThreadPostLanding.top;

  void _bindFloorNavigation() => widget.floorNavigation?.bind(this);

  void _updateFloorNavigation(ThreadDetailContent previous) {
    final pids = _sourcePidsFor(widget).toSet();
    _floorHeaderKeys.removeWhere((pid, _) => !pids.contains(pid));
    if (!identical(previous.floorNavigation, widget.floorNavigation)) {
      previous.floorNavigation?.unbind(this);
      _bindFloorNavigation();
    }
    if (!identical(previous.state.posts, widget.state.posts) ||
        previous.showReplyTail != widget.showReplyTail ||
        previous.replyTailRevision != widget.replyTailRevision ||
        previous.projection?.displayIdentity !=
            widget.projection?.displayIdentity) {
      _floorGeneration++;
    }
    if (previous.state.tid != widget.state.tid ||
        previous.state.currentPage != widget.state.currentPage ||
        previous.targetPid != widget.targetPid ||
        previous.landing != widget.landing ||
        previous.bodyReadingCoordinator != widget.bodyReadingCoordinator ||
        previous.state.queryParameters['authorid'] !=
            widget.state.queryParameters['authorid'] ||
        previous.state.queryParameters['ordertype'] !=
            widget.state.queryParameters['ordertype'] ||
        !identical(previous.scrollController, widget.scrollController)) {
      _floorGeneration++;
      _floorTargetPid = null;
      _pendingFloorBuild = null;
    }
  }

  void _disposeFloorNavigation() {
    _floorGeneration++;
    widget.floorNavigation?.unbind(this);
  }

  @override
  String? get visiblePostId {
    final controller = widget.scrollController;
    // 居中列表换绑的一帧内，新旧滚动位置可能同时附着。
    if (controller == null || controller.positions.length != 1) return null;
    return _projectionAnchorCoordinator
        .capture(
          _sourcePidsFor(widget),
          // 吸顶栏遮住的上一楼尾部不属于当前阅读位置。
          topInset: _repliesHeaderPinned ? _repliesHeaderHeight : 0,
        )
        ?.pid;
  }

  @override
  double? get scrollPixels {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) return null;
    final position = controller.position;
    return position.hasContentDimensions ? position.pixels : null;
  }

  @override
  List<ThreadFloorImageStop> imageStops(String pid) {
    if (!mounted) return const [];
    final controller = widget.imageReaderReturnCoordinator?.anchorsFor(pid);
    final scrollController = widget.scrollController;
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (controller == null ||
        scrollController == null ||
        scrollController.positions.length != 1 ||
        viewportBox is! RenderBox ||
        !viewportBox.hasSize) {
      return const [];
    }
    final topInset = _imageTopInset(pid);
    final stops = <ThreadFloorImageStop>[];
    for (final stop in controller.layoutStops(
      scrollController.position,
      topInset: topInset,
    )) {
      // 相邻重复落点按逻辑像素容差合并，保留正文顺序。
      if (stops.isNotEmpty &&
          (stops.last.offset - stop.offset).abs() <= _imageStopTolerance) {
        continue;
      }
      stops.add(
        ThreadFloorImageStop(
          postId: pid,
          index: stop.index,
          cacheKey: stop.cacheKey,
          url: stop.url,
          offset: stop.offset,
        ),
      );
    }
    return List<ThreadFloorImageStop>.unmodifiable(stops);
  }

  @override
  bool isPostHeaderAbove(String pid) {
    if (!mounted) return false;
    final header = _floorTopContext(pid);
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (header == null || viewport is! RenderBox || !viewport.hasSize) {
      return false;
    }
    final box = header.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top < _imageTopInset(pid);
  }

  static const double _imageStopTolerance = 1;

  double _imageTopInset(String pid) =>
      _targetBelowRepliesHeader(pid) ? _repliesHeaderHeight : 0;

  @override
  Future<bool> revealImageStop(
    ThreadFloorImageStop stop, {
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    if (!mounted) return false;
    final controller = widget.imageReaderReturnCoordinator?.anchorsFor(
      stop.postId,
    );
    final scrollController = widget.scrollController;
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (controller == null ||
        scrollController == null ||
        !scrollController.hasClients ||
        scrollController.positions.length != 1 ||
        viewportBox is! RenderBox ||
        !viewportBox.hasSize) {
      return false;
    }
    final generation = ++_floorGeneration;
    final layoutIdentity = _renderLayoutIdentity;
    bool current() =>
        mounted &&
        generation == _floorGeneration &&
        layoutIdentity == _renderLayoutIdentity &&
        isCurrent() &&
        identical(scrollController, widget.scrollController) &&
        identical(
          controller,
          widget.imageReaderReturnCoordinator?.anchorsFor(stop.postId),
        );
    _projectionAnchorCoordinator.beginExplicitNavigation();
    _pendingChunkAnchor = null;
    if (animate) {
      final position = scrollController.position;
      await scrollController.animateTo(
        stop.offset.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
      if (!current()) return false;
    }
    final reached = await controller.revealImage(
      index: stop.index,
      cacheKey: stop.cacheKey,
      url: stop.url,
      scrollController: scrollController,
      isCurrent: current,
      topInset: _imageTopInset(stop.postId),
    );
    return current() && reached;
  }

  bool _atBottom = false;

  @override
  bool get atBottom => _atBottom;

  @override
  void refreshEndGeometry() {
    if (!mounted) return;
    _atBottom = _measureEndGeometry();
  }

  bool _measureEndGeometry() {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) return false;
    final position = controller.position;
    if (!position.hasContentDimensions) return false;
    if (position.pixels < position.maxScrollExtent - _endTolerance) {
      return false;
    }
    // 滚动边界之外还要核对末条目已经参与布局并落在视口内：惰性列表按陈旧
    // 的最大滚动范围也会先报到底，末楼楼头可见更不能代替正文末端。
    final bottom = _endEntryBottom();
    if (bottom == null) return false;
    final viewportBox = _viewportKey.currentContext?.findRenderObject();
    if (viewportBox is! RenderBox ||
        !viewportBox.attached ||
        !viewportBox.hasSize) {
      return false;
    }
    return bottom >= -_endTolerance &&
        bottom <= viewportBox.size.height + _endTolerance;
  }

  /// 末条目底边相对正文视口的位置；惰性列表重建窗口内全局键可能指向
  /// 已退出 sliver 子列表的保留子项，此时无法换算坐标，按未确认处理。
  double? _endEntryBottom() {
    final end = _listEndKey.currentContext?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (end is! RenderBox ||
        viewport is! RenderBox ||
        !end.attached ||
        !end.hasSize ||
        !viewport.attached ||
        !viewport.hasSize) {
      return null;
    }
    try {
      final top = end.localToGlobal(Offset.zero, ancestor: viewport).dy;
      return top + end.size.height;
    } on Object {
      return null;
    }
  }

  static const double _endTolerance = 1;

  @override
  Future<bool> revealPageEnd({
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    final controller = widget.scrollController;
    if (!mounted || controller == null || controller.positions.length != 1) {
      return false;
    }
    final generation = ++_floorGeneration;
    final layoutIdentity = _renderLayoutIdentity;
    bool current() =>
        mounted &&
        generation == _floorGeneration &&
        layoutIdentity == _renderLayoutIdentity &&
        isCurrent() &&
        identical(controller, widget.scrollController) &&
        controller.positions.length == 1;
    const duration = Duration(milliseconds: 180);
    final endpoint = await _navigateToEndpoint(
      target: ThreadDetailQuickScrollTarget.bottom,
      animate: animate,
      duration: duration,
      isCurrent: current,
    );
    if (!current()) return false;
    refreshEndGeometry();
    if (endpoint == ThreadDetailEndpointNavigationResult.reached && atBottom) {
      return true;
    }
    // 完整正文保留原渲染实例，并在惰性列表布局后核对最新页尾。迟到图片和
    // 分块测量会继续改变范围，因此按实测几何收敛而不是固定三帧。
    _projectionAnchorCoordinator.beginExplicitNavigation();
    _pendingChunkAnchor = null;
    if (animate) {
      await controller.animateTo(
        controller.position.maxScrollExtent,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } else {
      controller.jumpTo(controller.position.maxScrollExtent);
    }
    for (var attempt = 0; attempt < 12; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return false;
      refreshEndGeometry();
      if (atBottom) return true;
      if (!controller.hasClients) return false;
      controller.jumpTo(controller.position.maxScrollExtent);
    }
    return false;
  }

  @override
  Future<bool> revealPost(
    String pid, {
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    if (!mounted ||
        !_sourcePidsFor(widget).any((candidate) => candidate == pid)) {
      return false;
    }
    final generation = ++_floorGeneration;
    var layoutIdentity = _renderLayoutIdentity;
    final controller = widget.scrollController;
    bool currentOwner() =>
        mounted &&
        generation == _floorGeneration &&
        isCurrent() &&
        identical(controller, widget.scrollController);
    bool current() => currentOwner() && layoutIdentity == _renderLayoutIdentity;
    _projectionAnchorCoordinator.beginExplicitNavigation();
    _pendingChunkAnchor = null;
    final target = _floorTopContext(pid);
    if (target == null) {
      _pendingFloorBuild = (
        current: current,
        pid: _floorTargetPid,
        center: _targetCenterKey,
        revision: _endpointViewRevision,
        endpoint: _endpointTarget,
      );
      // 沿用已支持楼层定位的居中列表，按真实条目落点，避免估算长正文高度。
      setState(() {
        _floorTargetPid = pid;
        _endpointTarget = null;
        _endpointViewRevision++;
        _targetCenterKey = GlobalKey(debugLabel: 'thread-floor-center-$pid');
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!currentOwner()) {
        return false;
      }
      // 居中重排本身就是预期的布局变化，按新布局继续定位。
      layoutIdentity = _renderLayoutIdentity;
    }
    final targetContext = _floorTopContext(pid);
    if (!current() ||
        !mounted ||
        targetContext == null ||
        controller == null ||
        !controller.hasClients) {
      return false;
    }
    if (!targetContext.mounted) return false;
    // 目标在回复栏之下时，楼头对齐到吸顶栏下沿而不是视口顶边。
    final occlusion = _targetBelowRepliesHeader(pid)
        ? _repliesHeaderHeight
        : 0.0;
    final marker = targetContext.findRenderObject();
    final scrollPosition = controller.position;
    if (marker is! RenderBox ||
        !marker.attached ||
        !marker.hasSize ||
        !scrollPosition.hasContentDimensions) {
      return false;
    }
    final scrollViewport = RenderAbstractViewport.maybeOf(marker);
    if (scrollViewport == null) {
      return false;
    }
    final reveal = scrollViewport.getOffsetToReveal(marker, 0);
    final destination = (reveal.offset - occlusion).clamp(
      scrollPosition.minScrollExtent,
      scrollPosition.maxScrollExtent,
    );
    if ((scrollPosition.pixels - destination).abs() > .5) {
      if (animate) {
        await controller.animateTo(
          destination,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        controller.jumpTo(destination);
      }
    }
    // 居中布局、锚点偏移和迟到尺寸都可能让第一次落点偏离，按实测几何收敛。
    for (var attempt = 0; attempt < 3; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return false;
      final landed = _floorTopContext(pid)?.findRenderObject();
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (landed is! RenderBox ||
          viewport is! RenderBox ||
          !landed.attached ||
          !landed.hasSize ||
          !viewport.attached ||
          !viewport.hasSize) {
        return false;
      }
      final top = landed.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final delta = top - occlusion;
      if (delta.abs() <= 1) return true;
      final position = controller.position;
      final next = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((next - position.pixels).abs() < .5) {
        // 已到滚动边界：目标仍应可见，只是无法再让出置顶遮挡。
        return top < viewport.size.height &&
            top >= -1 &&
            top + landed.size.height > 0;
      }
      controller.jumpTo(next);
    }
    return false;
  }
}
