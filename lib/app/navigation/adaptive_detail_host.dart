import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
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
  late final _sourceObserver = _PaneObserver(_scheduleSync);
  late final _detailObserver = _PaneObserver(_scheduleSync);
  final _sourceHero = HeroController();
  final _detailHero = HeroController();
  late final AdaptiveDetailController _controller;
  late final ForumClipboardRouteObserver _sourceClipboard;
  late final ForumClipboardRouteObserver _detailClipboard;
  AppWindowLayout? _window;
  bool _expanded = false;
  bool _syncPending = false;
  int _revision = 0;

  bool get _hasDetail => _detailObserver.routes.length > 1;
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

  Future<void> _back() async {
    if (!_isActive) return;
    if (_canSplit && _expanded) {
      _toggleExpanded();
    } else if (_hasDetail) {
      await _detailKey.currentState?.maybePop();
    } else {
      await _sourceKey.currentState?.maybePop();
    }
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
        return PopScope<Object?>(
          canPop:
              !widget.isActive ||
              (!_hasDetail && _sourceObserver.routes.length <= 1),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _pane(
                rect: sourceRect,
                inDetail: false,
                visible: _showSource,
                media: media,
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
              _pane(
                rect: detailRect,
                inDetail: true,
                visible: _hasDetail,
                media: media,
                child: HeroControllerScope(
                  controller: _detailHero,
                  child: Navigator(
                    key: _detailKey,
                    observers: [_detailObserver, _detailClipboard],
                    onGenerateRoute: (settings) => MaterialPageRoute<void>(
                      settings: settings,
                      builder: (_) => const SizedBox.expand(),
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
    final interactive = visible && (inDetail || !_sourceBlocked);
    return Positioned.fromRect(
      key: ValueKey(inDetail ? 'detail-pane' : 'source-pane'),
      rect: rect,
      child: Offstage(
        offstage: !visible,
        // Riverpod 会随 TickerMode 暂停订阅；页签停用由外层主壳负责。
        child: TickerMode(
          enabled: visible,
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
  if (scope == null) return null;
  if (!scope.inDetail) {
    if (Navigator.of(context).canPop()) return null;
    final parent = Navigator.of(scope.host.context);
    return ModalRoute.of(scope.host.context)?.canPop == true
        ? BackButton(onPressed: () => parent.maybePop())
        : null;
  }
  return BackButton(
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
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) routes[index] = newRoute;
    onChanged();
  }
}
