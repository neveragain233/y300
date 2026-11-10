import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps optional clipboard work outside route entrance and exit transitions.
///
/// Hosts must also check whether their own route is current. Popup routes do
/// not drive a page's secondary animation, and a popped page becomes current
/// before the popup's overlay has finished its reverse transition.
final class ForumClipboardRouteObserver extends NavigatorObserver
    with ChangeNotifier {
  final Map<TransitionRoute<dynamic>, _EntranceTransition> _entrances =
      Map.identity();
  final Set<TransitionRoute<dynamic>> _exits = Set.identity();
  bool _isTransitioning = false;
  bool _disposed = false;
  bool _enabled = true;
  bool _blocked = false;
  VoidCallback? _onDisposed;
  final _routes = <Route<dynamic>>[];
  final _nested = <ForumClipboardRouteObserver>{};

  bool get isTransitioning => _isTransitioning;
  bool get isBlocked => _enabled && _blocked;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  ForumClipboardRouteObserver createNestedObserver() {
    final child = ForumClipboardRouteObserver();
    _nested.add(child);
    child.addListener(_publish);
    child._onDisposed = () {
      _nested.remove(child);
      if (!_disposed) _publish();
    };
    return child;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _watchEntrance(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _watchExit(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _watchExit(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
    _watchExit(oldRoute);
    _watchEntrance(newRoute);
    _publish();
  }

  void _watchEntrance(Route<dynamic>? route) {
    if (_disposed || route is! TransitionRoute<dynamic>) {
      return;
    }
    final animation = route.animation;
    if (animation == null || _entrances.containsKey(route)) {
      return;
    }
    void onStatus(AnimationStatus status) {
      final entrance = _entrances[route];
      if (entrance?.checked == true &&
          (status == AnimationStatus.completed ||
              status == AnimationStatus.dismissed)) {
        _stopEntrance(route);
        _publish();
      }
    }

    _entrances[route] = _EntranceTransition(animation, onStatus);
    animation.addStatusListener(onStatus);
    _watchCompletion(route);
    // HeroController can temporarily expose an always-complete animation while
    // measuring an offstage entering route. Check after all first-frame work.
    final entrance = _entrances[route]!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        if (_disposed || !identical(_entrances[route], entrance)) {
          return;
        }
        entrance.checked = true;
        Animation<double> actual = animation;
        while (actual is ProxyAnimation && actual.parent != null) {
          actual = actual.parent!;
        }
        // A non-animated replace may retain a forward status at an intermediate
        // value, while the underlying controller has no active ticker.
        if (!actual.isAnimating) {
          _stopEntrance(route);
          _publish();
        }
      });
    });
  }

  void _watchExit(Route<dynamic>? route) {
    if (_disposed || route is! TransitionRoute<dynamic>) {
      return;
    }
    _stopEntrance(route);
    if (_exits.add(route)) {
      _watchCompletion(route);
    }
  }

  void _watchCompletion(TransitionRoute<dynamic> route) {
    unawaited(
      route.completed.then<void>(
        (_) => _finish(route),
        onError: (Object error, StackTrace stackTrace) => _finish(route),
      ),
    );
  }

  void _finish(TransitionRoute<dynamic> route) {
    if (_disposed) {
      return;
    }
    _stopEntrance(route);
    _exits.remove(route);
    _publish();
  }

  void _stopEntrance(TransitionRoute<dynamic> route) {
    final entrance = _entrances.remove(route);
    entrance?.animation.removeStatusListener(entrance.onStatus);
  }

  void _publish() {
    if (_disposed) {
      return;
    }
    final transitioning = _entrances.isNotEmpty || _exits.isNotEmpty;
    final blocked =
        transitioning ||
        _routes.lastOrNull is PopupRoute<dynamic> ||
        _nested.any((child) => child.isBlocked);
    if (transitioning != _isTransitioning || blocked != _blocked) {
      _isTransitioning = transitioning;
      _blocked = blocked;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final entrance in _entrances.values) {
      entrance.animation.removeStatusListener(entrance.onStatus);
    }
    _entrances.clear();
    _exits.clear();
    _routes.clear();
    for (final child in _nested) {
      child.removeListener(_publish);
      child._onDisposed = null;
    }
    _nested.clear();
    _onDisposed?.call();
    _isTransitioning = false;
    super.dispose();
  }
}

final class _EntranceTransition {
  _EntranceTransition(this.animation, this.onStatus);

  final Animation<double> animation;
  final AnimationStatusListener onStatus;
  bool checked = false;
}
