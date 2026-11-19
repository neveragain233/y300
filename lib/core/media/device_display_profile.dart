import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// 屏幕物理尺寸画像：像素与每英寸点数。
///
/// 逻辑 dp 由厂商 ROM 的 density 决定，同一块 1264 像素宽的屏可能报 421dp
/// 或 674dp；墨水屏的大屏判定必须回到物理英寸，否则换设备或改 density 就失效。
class DeviceDisplayProfile {
  const DeviceDisplayProfile({
    required this.widthPixels,
    required this.heightPixels,
    required this.xdpi,
    required this.ydpi,
    required this.densityDpi,
  });

  final int widthPixels;
  final int heightPixels;
  final double xdpi;
  final double ydpi;
  final int densityDpi;

  /// 屏幕短边的物理英寸数；像素或 dpi 异常时返回 null。
  ///
  /// 短边不随旋转变化，手机通常在 3 英寸以下，7 寸 4:3 墨水屏约 4.2 英寸。
  double? get shortestSideInches {
    final shortestPixels = math.min(widthPixels, heightPixels).toDouble();
    final shortestDpi = math.min(xdpi, ydpi);
    if (shortestPixels <= 0 || !shortestDpi.isFinite) {
      return null;
    }
    // 厂商虚报的 xdpi/ydpi 经常落在常见范围之外，直接放弃物理判定。
    if (shortestDpi < 120 || shortestDpi > 1200) {
      return null;
    }
    return shortestPixels / shortestDpi;
  }
}

abstract final class DeviceDisplayProfileStore {
  static DeviceDisplayProfile? current;
}

class DeviceDisplayProfileResolver {
  const DeviceDisplayProfileResolver({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.adws.y300/display_metrics',
  );

  final MethodChannel _channel;

  Future<DeviceDisplayProfile?> resolve() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getProfile',
      );
      if (result == null) {
        return null;
      }
      final profile = DeviceDisplayProfile(
        widthPixels: (result['widthPixels'] as num?)?.toInt() ?? 0,
        heightPixels: (result['heightPixels'] as num?)?.toInt() ?? 0,
        xdpi: (result['xdpi'] as num?)?.toDouble() ?? 0,
        ydpi: (result['ydpi'] as num?)?.toDouble() ?? 0,
        densityDpi: (result['densityDpi'] as num?)?.toInt() ?? 0,
      );
      return profile.shortestSideInches == null ? null : profile;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
