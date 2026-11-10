import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

/// 所有坐标均属于宿主的可用窗口；[globalOrigin] 把系统分隔投影到该窗口。
class AppWindowLayout {
  AppWindowLayout({
    required this.size,
    List<DisplayFeature> displayFeatures = const [],
    Offset globalOrigin = Offset.zero,
  }) : regions = _regions(size, displayFeatures, globalOrigin);

  static const double minimumListWidth = 320;
  static const double minimumDetailWidth = 480;
  final Size size;
  final List<Rect> regions;

  bool get hasSeparator => regions.length > 1;
  bool get useNavigationRail =>
      !hasSeparator && size.width >= 720 && size.height >= 360;

  Rect get readingRegion => regions.reduce(
    (a, b) => a.width * a.height >= b.width * b.height ? a : b,
  );

  ({Rect list, Rect detail})? get split {
    if (size.height < 360) return null;
    if (hasSeparator) {
      final first = regions.first;
      final last = regions.last;
      if (first.left < last.left &&
          first.width >= minimumListWidth &&
          last.width >= minimumDetailWidth) {
        return (list: first, detail: last);
      }
      if (first.top < last.top &&
          first.height >= 280 &&
          last.height >= 280 &&
          first.width >= minimumDetailWidth &&
          last.width >= minimumListWidth) {
        return (list: last, detail: first);
      }
      return null;
    }
    if (size.width < minimumListWidth + minimumDetailWidth + 1) return null;
    final listWidth = (size.width * 0.36).clamp(minimumListWidth, 420.0);
    return (
      list: Rect.fromLTWH(0, 0, listWidth, size.height),
      detail: Rect.fromLTWH(
        listWidth + 1,
        0,
        size.width - listWidth - 1,
        size.height,
      ),
    );
  }

  static List<Rect> _regions(
    Size size,
    List<DisplayFeature> features,
    Offset origin,
  ) {
    final whole = Offset.zero & size;
    for (final feature in features) {
      if (feature.type != DisplayFeatureType.hinge &&
          feature.state != DisplayFeatureState.postureHalfOpened) {
        continue;
      }
      final bounds = feature.bounds.shift(-origin);
      // 普通平整折痕不分割内容；遮挡铰链及明确半折状态才形成连续区域。
      if (bounds.height >= size.height * 0.6 &&
          bounds.center.dx > 0 &&
          bounds.center.dx < size.width) {
        final left = math.max(0.0, bounds.left);
        final right = math.min(size.width, bounds.right);
        if (left > 0 && right < size.width) {
          return List.unmodifiable([
            Rect.fromLTRB(0, 0, left, size.height),
            Rect.fromLTRB(right, 0, size.width, size.height),
          ]);
        }
      }
      if (bounds.width >= size.width * 0.6 &&
          bounds.center.dy > 0 &&
          bounds.center.dy < size.height) {
        final top = math.max(0.0, bounds.top);
        final bottom = math.min(size.height, bounds.bottom);
        if (top > 0 && bottom < size.height) {
          return List.unmodifiable([
            Rect.fromLTRB(0, 0, size.width, top),
            Rect.fromLTRB(0, bottom, size.width, size.height),
          ]);
        }
      }
    }
    return [whole];
  }
}
