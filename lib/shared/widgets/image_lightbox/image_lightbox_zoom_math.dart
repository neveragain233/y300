import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/rendering.dart' show Matrix4;

/// 缩放上下界、双击目标倍数以及长图/超宽图分类。
class ImageLightboxScaleBounds {
  const ImageLightboxScaleBounds({
    required this.minScale,
    required this.maxScale,
    required this.doubleTapScale,
    required this.isLongImage,
    required this.isWideImage,
  });

  final double minScale;
  final double maxScale;
  final double doubleTapScale;
  final bool isLongImage;
  final bool isWideImage;
}

/// 灯箱变换状态（缩放倍数与左上角基准位移）。
class ImageLightboxTransform {
  const ImageLightboxTransform({
    required this.scale,
    required this.translation,
  });

  static const ImageLightboxTransform identity = ImageLightboxTransform(
    scale: 1.0,
    translation: Offset.zero,
  );

  final double scale;
  final Offset translation;

  Matrix4 toMatrix4() {
    return Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }
}

/// 当前缩放状态下水平边界是否已贴边，用于决定何时向 `PageView` 交接切页。
class ImageLightboxEdgeState {
  const ImageLightboxEdgeState({
    required this.atLeftEdge,
    required this.atRightEdge,
    required this.hasHorizontalOverflow,
  });

  final bool atLeftEdge;
  final bool atRightEdge;
  final bool hasHorizontalOverflow;
}

/// 计算 `BoxFit.contain` 下图片在视口内的实际绘制矩形。
///
/// 未获得有效尺寸或宽高比时回退为铺满视口。
Rect computeFittedImageRect({
  required Size viewportSize,
  Size? imageSize,
  double? aspectRatio,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) {
    return Rect.zero;
  }
  double? ratio;
  if (imageSize != null &&
      imageSize.width.isFinite &&
      imageSize.height.isFinite &&
      imageSize.width > 0 &&
      imageSize.height > 0) {
    ratio = imageSize.width / imageSize.height;
  } else if (aspectRatio != null && aspectRatio.isFinite && aspectRatio > 0) {
    ratio = aspectRatio;
  }
  if (ratio == null) {
    return Offset.zero & viewportSize;
  }
  final viewportRatio = viewportSize.width / viewportSize.height;
  final double width;
  final double height;
  if (ratio > viewportRatio) {
    width = viewportSize.width;
    height = width / ratio;
  } else {
    height = viewportSize.height;
    width = height * ratio;
  }
  return Rect.fromLTWH(
    (viewportSize.width - width) / 2,
    (viewportSize.height - height) / 2,
    width,
    height,
  );
}

/// 根据视口与图片实际绘制区域计算缩放边界与双击目标倍数。
ImageLightboxScaleBounds computeLightboxScaleBounds({
  required Size viewportSize,
  required Rect fittedRect,
}) {
  final fitWidthScale = fittedRect.width > 0 && viewportSize.width > 0
      ? viewportSize.width / fittedRect.width
      : 1.0;
  final fitHeightScale = fittedRect.height > 0 && viewportSize.height > 0
      ? viewportSize.height / fittedRect.height
      : 1.0;
  final isLongImage = fitWidthScale >= 1.8;
  final isWideImage = !isLongImage && fitHeightScale >= 1.8;
  final preferredBase = isLongImage
      ? fitWidthScale
      : (isWideImage ? fitHeightScale : 2.5);
  final maxScale = math
      .max(5.0, preferredBase * 1.5)
      .clamp(5.0, 16.0)
      .toDouble();
  final doubleTapScale = isLongImage
      ? fitWidthScale.clamp(2.0, maxScale).toDouble()
      : (isWideImage
            ? fitHeightScale.clamp(2.0, maxScale).toDouble()
            : 2.5.clamp(1.0, maxScale).toDouble());
  return ImageLightboxScaleBounds(
    minScale: 1.0,
    maxScale: maxScale,
    doubleTapScale: doubleTapScale,
    isLongImage: isLongImage,
    isWideImage: isWideImage,
  );
}

/// 按缩放后的图片真实边界裁剪平移量；单轴未溢出视口时居中锁死。
Offset clampLightboxTranslation({
  required Size viewportSize,
  required Rect fittedRect,
  required double scale,
  required Offset translation,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0 || scale <= 1.001) {
    return Offset.zero;
  }
  final scaledWidth = fittedRect.width * scale;
  final scaledHeight = fittedRect.height * scale;

  final double dx;
  if (scaledWidth <= viewportSize.width + 0.5) {
    dx = (viewportSize.width - scaledWidth) / 2 - fittedRect.left * scale;
  } else {
    final minX = viewportSize.width - fittedRect.right * scale;
    final maxX = -fittedRect.left * scale;
    dx = translation.dx.clamp(minX, maxX).toDouble();
  }

  final double dy;
  if (scaledHeight <= viewportSize.height + 0.5) {
    dy = (viewportSize.height - scaledHeight) / 2 - fittedRect.top * scale;
  } else {
    final minY = viewportSize.height - fittedRect.bottom * scale;
    final maxY = -fittedRect.top * scale;
    dy = translation.dy.clamp(minY, maxY).toDouble();
  }

  return Offset(dx, dy);
}

/// 计算双击目标变换：已放大时复位；未放大时以点击点为锚点放大至目标倍数。
ImageLightboxTransform computeDoubleTapTransform({
  required Size viewportSize,
  required Rect fittedRect,
  required Offset focalPoint,
  required double currentScale,
}) {
  if (currentScale > 1.02) {
    return ImageLightboxTransform.identity;
  }
  final bounds = computeLightboxScaleBounds(
    viewportSize: viewportSize,
    fittedRect: fittedRect,
  );
  final targetScale = bounds.doubleTapScale;
  final rawTranslation = Offset(
    focalPoint.dx * (1 - targetScale),
    focalPoint.dy * (1 - targetScale),
  );
  return ImageLightboxTransform(
    scale: targetScale,
    translation: clampLightboxTranslation(
      viewportSize: viewportSize,
      fittedRect: fittedRect,
      scale: targetScale,
      translation: rawTranslation,
    ),
  );
}

/// 计算底部“适宽 / 还原”快捷按钮的目标变换，从长图顶部或宽图左缘开始阅读。
ImageLightboxTransform computeFitToggleTransform({
  required Size viewportSize,
  required Rect fittedRect,
  required double currentScale,
}) {
  if (currentScale > 1.02) {
    return ImageLightboxTransform.identity;
  }
  final bounds = computeLightboxScaleBounds(
    viewportSize: viewportSize,
    fittedRect: fittedRect,
  );
  final anchor = bounds.isLongImage
      ? Offset(viewportSize.width / 2, fittedRect.top)
      : (bounds.isWideImage
            ? Offset(fittedRect.left, viewportSize.height / 2)
            : Offset(viewportSize.width / 2, viewportSize.height / 2));
  return computeDoubleTapTransform(
    viewportSize: viewportSize,
    fittedRect: fittedRect,
    focalPoint: anchor,
    currentScale: currentScale,
  );
}

/// 判断当前缩放与平移是否已触及图片左右边界。
ImageLightboxEdgeState computeLightboxEdgeState({
  required Size viewportSize,
  required Rect fittedRect,
  required double scale,
  required Offset translation,
  double tolerance = 1.5,
}) {
  if (viewportSize.width <= 0 || scale <= 1.001) {
    return const ImageLightboxEdgeState(
      atLeftEdge: true,
      atRightEdge: true,
      hasHorizontalOverflow: false,
    );
  }
  final scaledWidth = fittedRect.width * scale;
  if (scaledWidth <= viewportSize.width + 0.5) {
    return const ImageLightboxEdgeState(
      atLeftEdge: true,
      atRightEdge: true,
      hasHorizontalOverflow: false,
    );
  }
  final minX = viewportSize.width - fittedRect.right * scale;
  final maxX = -fittedRect.left * scale;
  return ImageLightboxEdgeState(
    atLeftEdge: translation.dx >= maxX - tolerance,
    atRightEdge: translation.dx <= minX + tolerance,
    hasHorizontalOverflow: true,
  );
}
