import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Speed presets for iReader (掌阅) SmartOS EPDC water-ripple page-turn animations.
enum EInkRippleSpeed { slow, standard, fast }

/// Native bridge to iReader SmartOS `android.eink.EPDCDevice` water-ripple effect.
abstract final class EInkEpdcChannel {
  static const MethodChannel _channel = MethodChannel('com.adws.y300/epdc');

  static Future<void> Function(bool forward, String speed)? _testOverride;

  /// Whether EPDC page-turn water-ripple animation is active (enabled in E-Ink mode).
  static bool enabled = false;

  @visibleForTesting
  static void setTestOverride(
    Future<void> Function(bool forward, String speed)? override,
  ) {
    _testOverride = override;
  }

  /// Arms the next display post with an EPDC water-ripple page-turn effect.
  /// Safe no-op on non-Android platforms, non-iReader devices, and widget tests.
  static Future<void> triggerPageRipple({
    required bool forward,
    EInkRippleSpeed speed = EInkRippleSpeed.standard,
  }) async {
    if (!enabled) return;
    final override = _testOverride;
    if (override != null) {
      await override(forward, speed.name);
      return;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('triggerPageRipple', <String, Object?>{
        'forward': forward,
        'speed': speed.name,
      });
    } on MissingPluginException {
      // Ignored in pure widget tests or hosts without EPDC bridge.
    } catch (_) {
      // Keep page turns resilient if host engine is tearing down.
    }
  }
}

/// Disables stretch/glow overscroll indicators and bouncy physics for E-Ink.
class EInkScrollBehavior extends MaterialScrollBehavior {
  const EInkScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
