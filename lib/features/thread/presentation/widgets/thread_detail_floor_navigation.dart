part of 'thread_detail_widgets.dart';

mixin _ThreadDetailFloorNavigation on ConsumerState<ThreadDetailContent>
    implements ThreadFloorViewport {
  ThreadPostViewportAnchorCoordinator get _projectionAnchorCoordinator;
  GlobalKey get _viewportKey;
  Object? get _renderLayoutIdentity;
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
    final pids = widget.state.posts.map((post) => post.pid).toSet();
    _floorHeaderKeys.removeWhere((pid, _) => !pids.contains(pid));
    if (!identical(previous.floorNavigation, widget.floorNavigation)) {
      previous.floorNavigation?.unbind(this);
      _bindFloorNavigation();
    }
    if (!identical(previous.state.posts, widget.state.posts) ||
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
    return _projectionAnchorCoordinator.capture(_sourcePidsFor(widget))?.pid;
  }

  @override
  bool get atBottom {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) return false;
    final position = controller.position;
    return position.hasContentDimensions &&
        position.pixels >= position.maxScrollExtent - 1;
  }

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
    if (endpoint != ThreadDetailEndpointNavigationResult.unavailable) {
      return endpoint == ThreadDetailEndpointNavigationResult.reached;
    }
    // 完整正文保留原渲染实例，并在惰性列表布局后核对最新页尾。
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
    for (var attempt = 0; attempt < 3; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return false;
      if (atBottom) return true;
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
    if (!mounted || !widget.state.posts.any((post) => post.pid == pid)) {
      return false;
    }
    final generation = ++_floorGeneration;
    final layoutIdentity = _renderLayoutIdentity;
    final controller = widget.scrollController;
    bool current() =>
        mounted &&
        generation == _floorGeneration &&
        layoutIdentity == _renderLayoutIdentity &&
        isCurrent() &&
        identical(controller, widget.scrollController);
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
      if (!current()) return false;
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
    await Scrollable.ensureVisible(
      targetContext,
      duration: animate ? const Duration(milliseconds: 180) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!current()) return false;
    final marker = _floorTopContext(pid)?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (marker is! RenderBox ||
        viewport is! RenderBox ||
        !marker.attached ||
        !marker.hasSize) {
      return false;
    }
    final top = marker.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top < viewport.size.height && top + marker.size.height > -1;
  }
}
