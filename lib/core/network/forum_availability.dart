import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

enum ForumAccessMode { normal, suspected, offline, maintenance, manual }

final forumAvailabilityProvider = ChangeNotifierProvider<ForumAvailability>((
  ref,
) {
  final model = ForumAvailability();
  final connectivity = Connectivity();
  Completer<void>? pending;
  Timer? deadline;

  void finish() {
    deadline?.cancel();
    deadline = null;
    pending?.complete();
    pending = null;
  }

  void update(List<ConnectivityResult> interfaces) {
    if (interfaces.isNotEmpty) {
      model.setConnected(
        interfaces.any((item) => item != ConnectivityResult.none),
      );
    }
    finish();
  }

  final subscription = connectivity.onConnectivityChanged.listen(
    update,
    onError: (Object _) {},
  );
  Future<void> refreshInterfaces() {
    final existing = pending;
    if (existing != null) return existing.future;
    final request = pending = Completer<void>();
    deadline = Timer(const Duration(seconds: 2), finish);
    connectivity.checkConnectivity().then<void>(
      (interfaces) {
        if (identical(pending, request)) update(interfaces);
      },
      onError: (Object _) {
        if (identical(pending, request)) finish();
      },
    );
    return request.future;
  }

  model.refreshInterfaces = refreshInterfaces;
  model.ready = model.checkInterfaces();
  ref.onDispose(() {
    finish();
    subscription.cancel();
  });
  return model;
});

/// 接口可用性与站点状态独立；重新联网不能抹掉已确认的维护状态。
class ForumAvailability extends ChangeNotifier {
  ForumAvailability({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  Future<void> ready = Future.value();
  Future<void> Function()? refreshInterfaces;
  Future<void>? _refresh;
  Future<void> checkInterfaces() =>
      _refresh ??= Future.sync(() => refreshInterfaces?.call())
          .then<void>((_) {})
          .whenComplete(() {
            _refresh = null;
          });
  bool _connected = true;
  bool _maintenance = false;
  bool _manual = false;
  DateTime? _firstFailure;
  int _failures = 0;
  int _generation = 0;
  Future<bool>? _probe;

  int get generation => _generation;
  bool get connected => _connected;
  bool get forced => _manual;
  bool get blocked => !_connected || _maintenance || _manual;
  ForumAccessMode get mode => !_connected
      ? ForumAccessMode.offline
      : _manual
      ? ForumAccessMode.manual
      : _maintenance
      ? ForumAccessMode.maintenance
      : _failures > 0
      ? ForumAccessMode.suspected
      : ForumAccessMode.normal;

  void setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    _resetWindow();
    _generation++;
    notifyListeners();
  }

  void setManual(bool enabled) {
    if (_manual == enabled && (enabled || !_maintenance)) return;
    _manual = enabled;
    if (!enabled) _maintenance = false;
    _resetWindow();
    _generation++;
    notifyListeners();
  }

  static bool maintenancePage(Object? body) {
    if (body is! String || body.length > 32768) return false;
    return RegExp(
      r'<title[^>]*>\s*(?:502 Bad Gateway|503 Service (?:Temporarily )?Unavailable|504 Gateway Time-out|站点维护中|網站維護中|网站维护中)\s*</title>',
      caseSensitive: false,
    ).hasMatch(body);
  }

  void observe({
    required int generation,
    required int? status,
    required bool securityResponse,
    Object? body,
  }) {
    if (blocked || generation != _generation || status == null) return;
    final before = mode;
    final explicit =
        !securityResponse && status == 200 && maintenancePage(body);
    if (!securityResponse && ({502, 503, 504}.contains(status) || explicit)) {
      final now = _clock();
      if (_firstFailure == null ||
          now.difference(_firstFailure!) > const Duration(minutes: 1)) {
        _firstFailure = now;
        _failures = 0;
      }
      if (++_failures >= 3 || explicit) {
        _maintenance = true;
        _generation++;
      }
    } else {
      _resetWindow();
    }
    if (before != mode) notifyListeners();
  }

  Future<bool> retry(Future<bool> Function() probe) {
    return _probe ??=
        Future.sync(() async {
          if (!_connected) await checkInterfaces();
          if (!_connected) return false;
          final generation = _generation;
          final ok = await probe();
          if (generation != _generation || !ok) return false;
          setManual(false);
          return true;
        }).catchError((Object _) => false).whenComplete(() {
          _probe = null;
        });
  }

  void _resetWindow() {
    _firstFailure = null;
    _failures = 0;
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
