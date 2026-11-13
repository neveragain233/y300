import 'dart:async';

import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/clipboard/forum_clipboard_runtime.dart';
import 'package:y300/app/clipboard/forum_clipboard_route_observer.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/l10n/app_localizations.dart';

class AdaptiveDetailController extends ChangeNotifier {
  _AdaptiveDetailHostState? _host;
  bool _hasDetail = false;
  bool _expanded = false;
  bool _canSplit = false;

  bool get hasDetail => _hasDetail;
  bool get expanded => _expanded;
  bool get canSplit => _canSplit;

  /// 回到该入口的根页：先清空详情栈，再清空来源栈。
  Future<void> resetToRoot() => _host?._resetToRoot() ?? Future<void>.value();

  void _update({
    required bool hasDetail,
    required bool expanded,
    required bool canSplit,
  }) {
    if (_hasDetail == hasDetail &&
        _expanded == expanded &&
        _canSplit == canSplit) {
      return;
    }
    _hasDetail = hasDetail;
    _expanded = expanded;
    _canSplit = canSplit;
    notifyListeners();
  }
}

/// 独立入口沿用整页路由；论坛宿主把同一个详情导航器保留到窗口收起之后。
/// 当前上下文是否已经处在一个详情宿主内。
///
/// 从论坛根页推入的记录页仍挂在论坛宿主的来源栈上；此时再创建一个宿主会
/// 把详情截留在内层，主壳就看不到详情已打开，底栏不会退出并可遮住悬浮控件。
bool hasAdaptiveDetailHost(BuildContext context) {
  return context.getInheritedWidgetOfExactType<_DetailScope>() != null;
}

Future<T?> openAdaptiveDetail<T>(BuildContext context, Route<T> route) {
  final scope = context.getInheritedWidgetOfExactType<_DetailScope>();
  if (scope != null) return scope.host._open(route, fromDetail: scope.inDetail);
  final dispatch = context
      .getInheritedWidgetOfExactType<AdaptiveDetailDispatchScope>();
  final host = dispatch?.enabled == true ? dispatch!.controller._host : null;
  return host == null
      ? Navigator.of(context).push(route)
      : host._open(route, fromDetail: false, external: true);
}

Future<void> popAdaptivePage(BuildContext context) async {
  final scope = context.getInheritedWidgetOfExactType<_DetailScope>();
  if (scope != null) {
    await scope.host._back();
  } else {
    await Navigator.of(context).maybePop();
  }
}

Future<void> returnToAdaptiveRoot(BuildContext context) async {
  final scope = context.getInheritedWidgetOfExactType<_DetailScope>();
  if (scope != null) {
    await scope.host._resetToRoot();
  } else {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

bool isAdaptiveSourceCurrent(BuildContext context) {
  final scope = context.getInheritedWidgetOfExactType<_DetailScope>();
  if (scope == null) {
    final dispatch = context
        .getInheritedWidgetOfExactType<AdaptiveDetailDispatchScope>();
    final host = dispatch?.enabled == true ? dispatch!.controller._host : null;
    return host == null || host._isActive && !host._sourceBlocked;
  }
  return scope.host._isActive &&
      (scope.inDetail
          ? scope.host._hasDetail
          : scope.host._showSource && !scope.host._sourceBlocked);
}

class AdaptiveDetailDispatchScope extends InheritedWidget {
  const AdaptiveDetailDispatchScope({
    super.key,
    required this.controller,
    required this.enabled,
    required super.child,
  });
  final AdaptiveDetailController controller;
  final bool enabled;
  @override
  bool updateShouldNotify(AdaptiveDetailDispatchScope oldWidget) =>
      oldWidget.controller != controller || oldWidget.enabled != enabled;
}

class AdaptiveDetailHost extends ConsumerStatefulWidget {
  const AdaptiveDetailHost({
    super.key,
    required this.child,
    this.controller,
    this.isActive = true,
    this.globalOrigin = Offset.zero,
  });

  final Widget child;
  final AdaptiveDetailController? controller;
  final bool isActive;
  final Offset globalOrigin;

  @override
  ConsumerState<AdaptiveDetailHost> createState() => _AdaptiveDetailHostState();
}

class _AdaptiveDetailHostState extends ConsumerState<AdaptiveDetailHost> {
  final _sourceKey = GlobalKey<NavigatorState>();
  final _detailKey = GlobalKey<NavigatorState>();
  final _browsingRoutes = <Route<dynamic>>{};
  late final _sourceObserver = _PaneObserver(_navigationChanged);
  late final _detailObserver = _PaneObserver(_navigationChanged);
  final _sourceHero = HeroController();
  final _detailHero = HeroController();
  late final AdaptiveDetailController _controller;
  late final ForumClipboardRouteObserver _sourceClipboard;
  late final ForumClipboardRouteObserver _detailClipboard;
  AppWindowLayout? _window;
  bool _expanded = false;
  bool _syncPending = false;
  int _revision = 0;

  bool get _hasDetail =>
      _detailObserver.routes.length > 1 || _detailObserver.retiring.isNotEmpty;
  bool get _canSplit => _window?.split != null;
  bool get _showSource => !_hasDetail || _canSplit && !_expanded;
  bool get _isActive =>
      widget.isActive && ModalRoute.of(context)?.isCurrent != false;
  bool get _sourceBlocked =>
      _hasDetail && !_browsingRoutes.contains(_detailObserver.routes.last);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AdaptiveDetailController();
    _controller._host = this;
    final rootRoutes = ref.read(forumClipboardRouteObserverProvider);
    _sourceClipboard = rootRoutes.createNestedObserver()
      ..enabled = widget.isActive;
    _detailClipboard = rootRoutes.createNestedObserver()
      ..enabled = widget.isActive;
  }

  @override
  void didUpdateWidget(AdaptiveDetailHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revision++;
    _sourceClipboard.enabled = widget.isActive;
    _detailClipboard.enabled = widget.isActive;
  }

  void _scheduleSync() {
    if (_syncPending) return;
    _syncPending = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPending = false;
      if (!mounted) return;
      if (!_hasDetail) _expanded = false;
      setState(() => _revision++);
      _controller._update(
        hasDetail: _hasDetail,
        expanded: _expanded,
        canSplit: _canSplit,
      );
    });
  }

  void _navigationChanged() {
    if (!mounted) return;
    _updatePopEligibility();
    _scheduleSync();
  }

  void _updatePopEligibility() {
    final canHandle = _isActive && !_transitioning && !(_canSplit && _expanded);
    _sourceObserver.handlesBack = canHandle && !_hasDetail;
    _detailObserver.handlesBack = canHandle && _hasDetail;
  }

  Future<T?> _open<T>(
    Route<T> route, {
    required bool fromDetail,
    bool external = false,
  }) async {
    if (!_isActive ||
        !fromDetail && (_sourceBlocked || !external && !_showSource)) {
      return null;
    }
    final navigator = _detailKey.currentState;
    if (navigator == null) return null;
    _browsingRoutes.add(route);
    try {
      // 来源列表选择另一项替换当前详情；详情内部导航保留自己的返回顺序。
      if (!fromDetail && _hasDetail) {
        return await navigator.pushAndRemoveUntil(
          route,
          (entry) => entry.isFirst,
        );
      }
      return await navigator.push(route);
    } finally {
      _browsingRoutes.remove(route);
    }
  }

  bool _backInFlight = false;
  bool get _transitioning =>
      _sourceObserver.retiring.isNotEmpty ||
      _detailObserver.retiring.isNotEmpty;

  Future<void> _back() async {
    if (!_isActive || _backInFlight || _transitioning) return;
    _backInFlight = true;
    try {
      if (_canSplit && _expanded) {
        _toggleExpanded();
      } else {
        final observer = _hasDetail ? _detailObserver : _sourceObserver;
        final route = observer.routes.lastOrNull;
        final navigator = _hasDetail ? _detailKey : _sourceKey;
        await navigator.currentState?.maybePop();
        // popped 在退出动画前完成；completed 才代表来源可以接管下一次返回。
        if (route is TransitionRoute && !route.isActive) await route.completed;
      }
    } finally {
      _backInFlight = false;
      if (mounted) _scheduleSync();
    }
  }

  Future<void> _resetToRoot() async {
    _detailKey.currentState?.popUntil((route) => route.isFirst);
    _sourceKey.currentState?.popUntil((route) => route.isFirst);
    if (_expanded) {
      _expanded = false;
      _revision++;
    }
    _scheduleSync();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      _revision++;
    });
    _scheduleSync();
  }

  @override
  void dispose() {
    if (identical(_controller._host, this)) _controller._host = null;
    _sourceClipboard.dispose();
    _detailClipboard.dispose();
    _sourceObserver.dispose();
    _detailObserver.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final previousSplit = _canSplit;
        _window = AppWindowLayout(
          size: constraints.biggest,
          displayFeatures: media.displayFeatures,
          globalOrigin: widget.globalOrigin,
        );
        if (_canSplit != previousSplit) _scheduleSync();
        final split = _window!.split;
        final sourceRect = _hasDetail && split != null && !_expanded
            ? split.list
            : _window!.readingRegion;
        final detailRect = split != null && !_expanded
            ? split.detail
            : _window!.readingRegion;
        final restorePanes = _canSplit && _expanded;
        _updatePopEligibility();
        final sourceHandlesBack = _isActive && !_hasDetail && !restorePanes;
        final detailHandlesBack = _isActive && _hasDetail && !restorePanes;
        return PopScope<Object?>(
          canPop:
              !widget.isActive ||
              (!_transitioning && !_backInFlight && !(_canSplit && _expanded)),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _isActive && restorePanes) _back();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _pane(
                rect: sourceRect,
                inDetail: false,
                visible:
                    _showSource ||
                    _detailObserver.entering.isNotEmpty ||
                    _detailObserver.retiring.isNotEmpty,
                media: media,
                child: NavigatorPopHandler<Object?>(
                  enabled: sourceHandlesBack,
                  onPopWithResult: (_) {
                    if (sourceHandlesBack) unawaited(_back());
                  },
                  child: HeroControllerScope(
                    controller: _sourceHero,
                    child: Navigator(
                      key: _sourceKey,
                      observers: [_sourceObserver, _sourceClipboard],
                      onGenerateRoute: (settings) => MaterialPageRoute<void>(
                        settings: settings,
                        builder: (_) => Builder(
                          builder: (context) {
                            context
                                .dependOnInheritedWidgetOfExactType<
                                  _DetailScope
                                >();
                            return widget.child;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _pane(
                rect: detailRect,
                inDetail: true,
                visible: _hasDetail,
                media: media,
                child: NavigatorPopHandler<Object?>(
                  enabled: detailHandlesBack,
                  onPopWithResult: (_) {
                    if (detailHandlesBack) {
                      unawaited(_back());
                    }
                  },
                  child: HeroControllerScope(
                    controller: _detailHero,
                    child: Navigator(
                      key: _detailKey,
                      observers: [_detailObserver, _detailClipboard],
                      onGenerateRoute: (settings) => PageRouteBuilder<void>(
                        settings: settings,
                        opaque: false,
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        pageBuilder: (_, _, _) => const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pane({
    required Rect rect,
    required bool inDetail,
    required bool visible,
    required MediaQueryData media,
    required Widget child,
  }) {
    final globalRect = rect
        .shift(widget.globalOrigin)
        .intersect(Offset.zero & media.size);
    final projected = media
        .removeDisplayFeatures(globalRect)
        .copyWith(
          size: rect.size,
          displayFeatures: [
            for (final feature in media.displayFeatures)
              if (globalRect.overlaps(feature.bounds))
                DisplayFeature(
                  bounds: feature.bounds.shift(-globalRect.topLeft),
                  type: feature.type,
                  state: feature.state,
                ),
          ],
        );
    final interactive = visible && (inDetail || _showSource && !_sourceBlocked);
    return Positioned.fromRect(
      key: ValueKey(inDetail ? 'detail-pane' : 'source-pane'),
      rect: rect,
      child: Offstage(
        offstage: !visible,
        // Riverpod 会随 TickerMode 暂停订阅；页签停用由外层主壳负责。
        child: TickerMode(
          enabled: visible && (inDetail || _showSource),
          child: IgnorePointer(
            ignoring: !interactive,
            child: ExcludeFocus(
              excluding: !interactive,
              child: MediaQuery(
                data: projected,
                child: _DetailScope(
                  host: this,
                  inDetail: inDetail,
                  revision: _revision,
                  canSplit: _canSplit,
                  expanded: _expanded,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶栏与系统返回共享宿主顺序：先恢复分栏，再退回详情导航。
Widget? adaptiveDetailBackButton(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<_DetailScope>();
  if (scope == null) {
    return Navigator.of(context).canPop() ? const AppToolbarBackButton() : null;
  }
  if (!scope.inDetail) {
    if (Navigator.of(context).canPop()) {
      return AppToolbarBackButton(onPressed: scope.host._back);
    }
    final parent = Navigator.of(scope.host.context);
    return ModalRoute.of(scope.host.context)?.canPop == true
        ? AppToolbarBackButton(onPressed: () => parent.maybePop())
        : null;
  }
  return AppToolbarBackButton(
    key: const Key('adaptive-detail-back'),
    onPressed: scope.host._back,
  );
}

class AdaptiveDetailExpandAction extends StatelessWidget {
  const AdaptiveDetailExpandAction({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DetailScope>();
    if (scope == null || !scope.inDetail || !scope.canSplit) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('adaptive-detail-expand'),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      tooltip: scope.expanded
          ? l10n.layoutRestorePanes
          : l10n.layoutExpandDetail,
      onPressed: scope.host._toggleExpanded,
      icon: Icon(scope.expanded ? Icons.close_fullscreen : Icons.open_in_full),
    );
  }
}

class _DetailScope extends InheritedWidget {
  const _DetailScope({
    required this.host,
    required this.inDetail,
    required this.revision,
    required this.canSplit,
    required this.expanded,
    required super.child,
  });
  final _AdaptiveDetailHostState host;
  final bool inDetail;
  final int revision;
  final bool canSplit;
  final bool expanded;
  @override
  bool updateShouldNotify(_DetailScope oldWidget) =>
      oldWidget.revision != revision ||
      oldWidget.canSplit != canSplit ||
      oldWidget.expanded != expanded;
}

class _PaneObserver extends NavigatorObserver {
  _PaneObserver(this.onChanged);
  final VoidCallback onChanged;
  final routes = <Route<dynamic>>[];
  final retiring = <TransitionRoute<dynamic>>{};
  final entering = <TransitionRoute<dynamic>>{};
  final _popEntry = _PanePopEntry();
  final _guardedRoutes = <ModalRoute<dynamic>>{};

  set handlesBack(bool value) => _popEntry.canPopNotifier.value = value;

  void _guard(Route<dynamic> route) {
    if (route is ModalRoute && _guardedRoutes.add(route)) {
      // 预测返回直接查询每个栈的当前路由，不经过外层返回回调。
      // 将资格写到路由自身，隐藏来源、停用页签和展开详情不能抢同一手势。
      route.registerPopEntry(_popEntry);
    }
  }

  void _unguard(Route<dynamic>? route) {
    if (route is ModalRoute && _guardedRoutes.remove(route)) {
      route.unregisterPopEntry(_popEntry);
    }
  }

  void dispose() {
    for (final route in _guardedRoutes.toList()) {
      _unguard(route);
    }
    _popEntry.canPopNotifier.dispose();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    if (previousRoute != null) _guard(route);
    if (route is TransitionRoute && previousRoute != null) {
      final animation = route.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        entering.add(route);
        void settled(AnimationStatus status) {
          if (status != AnimationStatus.completed &&
              status != AnimationStatus.dismissed) {
            return;
          }
          animation.removeStatusListener(settled);
          entering.remove(route);
          onChanged();
        }

        animation.addStatusListener(settled);
      }
    }
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    _unguard(route);
    if (route is TransitionRoute) {
      retiring.add(route);
      unawaited(
        route.completed.whenComplete(() {
          retiring.remove(route);
          onChanged();
        }),
      );
    }
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    _unguard(route);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    _unguard(oldRoute);
    if (index >= 0 && newRoute != null) {
      routes[index] = newRoute;
      if (index > 0) _guard(newRoute);
    }
    onChanged();
  }
}

class _PanePopEntry extends PopEntry<Object?> {
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
}
