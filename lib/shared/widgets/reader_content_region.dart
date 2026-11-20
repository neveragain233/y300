import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/app/theme/app_system_ui.dart';
import 'package:y300/core/motion/app_motion.dart';

/// 整页阅读任务的连续区域。内部会话保持挂载，几何与安全区统一投影到实际页框。
class ReaderContentRegion extends StatelessWidget {
  const ReaderContentRegion({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.maxWidth = double.infinity,
  });

  final Widget child;
  final Color backgroundColor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.onSurfaces(
        top: backgroundColor,
        bottom: backgroundColor,
      ),
      child: ColoredBox(
        color: backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final window = AppWindowLayout(
              size: constraints.biggest,
              displayFeatures: media.displayFeatures,
            );
            final region = window.readingRegion;
            final rect = Rect.fromCenter(
              center: region.center,
              width: math.min(maxWidth, region.width),
              height: region.height,
            );
            final projected = media
                .copyWith(size: constraints.biggest)
                .removeDisplayFeatures(rect)
                .copyWith(
                  size: rect.size,
                  // 墨水屏模式只在阅读器内恢复翻页动画；根层把其余动画关掉。
                  disableAnimations:
                      media.disableAnimations &&
                      !AppMotion.reduceMotion(context),
                  systemGestureInsets: EdgeInsets.only(
                    left: math.max(
                      0,
                      media.systemGestureInsets.left - rect.left,
                    ),
                    top: math.max(0, media.systemGestureInsets.top - rect.top),
                    right: math.max(
                      0,
                      media.systemGestureInsets.right -
                          (constraints.maxWidth - rect.right),
                    ),
                    bottom: math.max(
                      0,
                      media.systemGestureInsets.bottom -
                          (constraints.maxHeight - rect.bottom),
                    ),
                  ),
                  displayFeatures: [
                    for (final feature in media.displayFeatures)
                      if (rect.overlaps(feature.bounds))
                        DisplayFeature(
                          bounds: feature.bounds.shift(-rect.topLeft),
                          type: feature.type,
                          state: feature.state,
                        ),
                  ],
                );
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  key: const Key('reader-continuous-region'),
                  rect: rect,
                  child: MediaQuery(data: projected, child: child),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
