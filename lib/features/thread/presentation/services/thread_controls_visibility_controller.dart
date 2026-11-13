import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

final class ThreadControlsVisibilityController extends ValueNotifier<bool> {
  ThreadControlsVisibilityController() : super(true);
  bool _userScroll = false;
  double _distance = 0;
  double _sign = 0;

  void show() {
    _distance = 0;
    value = true;
  }

  void reset() {
    _userScroll = false;
    _sign = 0;
    show();
  }

  void handle(ScrollNotification notification, {required bool enabled}) {
    if (!enabled) {
      show();
      return;
    }
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _userScroll = true;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScroll = true;
    }
    if (notification is ScrollEndNotification) _userScroll = false;
    if (notification is! ScrollUpdateNotification || !_userScroll) return;
    final delta = notification.scrollDelta ?? 0;
    if (notification.metrics.extentBefore <= 1 ||
        notification.metrics.extentAfter <= 1) {
      show();
      return;
    }
    if (delta.sign != _sign) _distance = 0;
    _sign = delta.sign;
    _distance += delta.abs();
    if (_distance >= (delta > 0 ? 32 : 12)) value = delta < 0;
  }
}
