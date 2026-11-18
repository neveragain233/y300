import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 掌阅 SmartOS 墨水屏翻页水波纹的速度档位。
enum EInkRippleSpeed { slow, standard, fast }

/// 翻页水波纹的宿主能力。
///
/// 掌阅机型由宿主反射调用 `android.eink.EPDCDevice`，把下一次屏幕提交按水波
/// 纹动画绘制；其他平台返回 false。调用方只关心"是否接受"，不需要判断机型。
abstract class EInkPageRippleService {
  Future<bool> triggerPageRipple({
    required bool forward,
    required EInkRippleSpeed speed,
  });
}

/// 不需要动画的宿主实现：普通 Android、桌面与测试环境。
final class NoopEInkPageRippleService implements EInkPageRippleService {
  const NoopEInkPageRippleService();

  @override
  Future<bool> triggerPageRipple({
    required bool forward,
    required EInkRippleSpeed speed,
  }) async {
    return false;
  }
}

class MethodChannelEInkPageRippleService implements EInkPageRippleService {
  const MethodChannelEInkPageRippleService({
    MethodChannel channel = _defaultChannel,
  }) : _channel = channel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.adws.y300/epdc',
  );

  final MethodChannel _channel;

  @override
  Future<bool> triggerPageRipple({
    required bool forward,
    required EInkRippleSpeed speed,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final accepted = await _channel.invokeMethod<bool>(
        'triggerPageRipple',
        <String, Object?>{'forward': forward, 'speed': speed.name},
      );
      return accepted ?? false;
    } on MissingPluginException {
      // 桌面宿主及未注册通道的测试环境没有 EPDC 桥。
      return false;
    } on PlatformException {
      // 宿主引擎重建期间可能失败；翻页本身必须照常进行。
      return false;
    }
  }
}

final einkPageRippleServiceProvider = Provider<EInkPageRippleService>((ref) {
  return const MethodChannelEInkPageRippleService();
});
