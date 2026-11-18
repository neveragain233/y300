import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 硬件翻页键方向。音量减/翻页下对应 [next]，音量加/翻页上对应 [previous]。
enum HardwarePageKeyDirection { previous, next }

/// 墨水屏阅读器硬件翻页键的宿主能力。
///
/// 原生侧拦截音量键与翻页键后经 `com.adws.y300/eink_keys` 回传方向；
/// 是否拦截由 [setEnabled] 控制，阅读器只在自身可见时启用，避免全局吃掉
/// 系统音量键。非 Android 平台与没有该通道的宿主静默降级。
abstract class EInkHardwarePageKeysService {
  /// 硬件键方向事件；没有监听者或未启用时宿主不会回传。
  Stream<HardwarePageKeyDirection> get directions;

  Future<void> setEnabled(bool enabled);

  Future<void> dispose();
}

class MethodChannelEInkHardwarePageKeysService
    implements EInkHardwarePageKeysService {
  MethodChannelEInkHardwarePageKeysService({
    MethodChannel channel = _defaultChannel,
  }) : _channel = channel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.adws.y300/eink_keys',
  );

  final MethodChannel _channel;
  final StreamController<HardwarePageKeyDirection> _directions =
      StreamController<HardwarePageKeyDirection>.broadcast();
  bool _handlerInstalled = false;

  @override
  Stream<HardwarePageKeyDirection> get directions {
    _installHandler();
    return _directions.stream;
  }

  void _installHandler() {
    if (_handlerInstalled || kIsWeb) {
      return;
    }
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onHardwarePageKey' || _directions.isClosed) {
        return;
      }
      final argument = call.arguments;
      if (argument == 'up') {
        _directions.add(HardwarePageKeyDirection.previous);
      } else if (argument == 'down') {
        _directions.add(HardwarePageKeyDirection.next);
      }
    });
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _installHandler();
    try {
      await _channel.invokeMethod<void>('setVolumePagingEnabled', enabled);
    } on MissingPluginException {
      // 桌面宿主与未注册通道的测试环境没有原生键桥。
    } on PlatformException {
      // 宿主引擎重建期间可能失败；阅读器翻页不受影响。
    }
  }

  @override
  Future<void> dispose() async {
    if (_handlerInstalled) {
      _handlerInstalled = false;
      _channel.setMethodCallHandler(null);
    }
    await _directions.close();
  }
}

final einkHardwarePageKeysServiceProvider =
    Provider<EInkHardwarePageKeysService>((ref) {
      final service = MethodChannelEInkHardwarePageKeysService();
      ref.onDispose(service.dispose);
      return service;
    });
