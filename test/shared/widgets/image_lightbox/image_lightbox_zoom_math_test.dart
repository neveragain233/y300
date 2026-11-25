import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/image_lightbox/image_lightbox_zoom_math.dart';

void main() {
  const viewport = Size(400, 800);

  test('standard photo double-tap zooms to 2.5x and resets on second tap', () {
    final fitted = computeFittedImageRect(
      viewportSize: viewport,
      imageSize: const Size(800, 1200),
    );
    expect(fitted, const Rect.fromLTWH(0, 100, 400, 600));

    final bounds = computeLightboxScaleBounds(
      viewportSize: viewport,
      fittedRect: fitted,
    );
    expect(bounds.isLongImage, isFalse);
    expect(bounds.isWideImage, isFalse);
    expect(bounds.doubleTapScale, 2.5);
    expect(bounds.maxScale, 5.0);

    final zoomed = computeDoubleTapTransform(
      viewportSize: viewport,
      fittedRect: fitted,
      focalPoint: const Offset(200, 400),
      currentScale: 1.0,
    );
    expect(zoomed.scale, 2.5);

    final reset = computeDoubleTapTransform(
      viewportSize: viewport,
      fittedRect: fitted,
      focalPoint: const Offset(200, 400),
      currentScale: zoomed.scale,
    );
    expect(reset.scale, 1.0);
    expect(reset.translation, Offset.zero);
  });

  test('long screenshot double-tap fills viewport width and locks X axis', () {
    final fitted = computeFittedImageRect(
      viewportSize: viewport,
      imageSize: const Size(400, 3200),
    );
    expect(fitted, const Rect.fromLTWH(150, 0, 100, 800));

    final bounds = computeLightboxScaleBounds(
      viewportSize: viewport,
      fittedRect: fitted,
    );
    expect(bounds.isLongImage, isTrue);
    expect(bounds.doubleTapScale, closeTo(4.0, 0.001));
    expect(bounds.maxScale, closeTo(6.0, 0.001));

    final zoomed = computeDoubleTapTransform(
      viewportSize: viewport,
      fittedRect: fitted,
      focalPoint: const Offset(210, 600),
      currentScale: 1.0,
    );
    expect(zoomed.scale, closeTo(4.0, 0.001));
    // 水平方向满宽 400px，X 轴必须锁定在 -fitted.left * scale = -600，不出现黑边偏移
    expect(zoomed.translation.dx, closeTo(-600, 0.001));
    expect(zoomed.translation.dy, inInclusiveRange(-2400.0, 0.0));
  });

  test('wide image double-tap fills viewport height and locks Y axis', () {
    final fitted = computeFittedImageRect(
      viewportSize: viewport,
      imageSize: const Size(3200, 400),
    );
    expect(fitted, const Rect.fromLTWH(0, 375, 400, 50));

    final bounds = computeLightboxScaleBounds(
      viewportSize: viewport,
      fittedRect: fitted,
    );
    expect(bounds.isLongImage, isFalse);
    expect(bounds.isWideImage, isTrue);
    expect(bounds.doubleTapScale, closeTo(16.0, 0.001));
    expect(bounds.maxScale, 16.0);

    final zoomed = computeDoubleTapTransform(
      viewportSize: viewport,
      fittedRect: fitted,
      focalPoint: const Offset(100, 400),
      currentScale: 1.0,
    );
    expect(zoomed.scale, closeTo(16.0, 0.001));
    expect(zoomed.translation.dy, closeTo(-375 * 16.0, 0.001));
  });

  test('clampLightboxTranslation centers axis when scaled image is narrower than viewport', () {
    final fitted = computeFittedImageRect(
      viewportSize: viewport,
      imageSize: const Size(1200, 900),
    );
    // 1.5x 时图片高 450 < 800，Y 轴必须居中锁死
    final clamped = clampLightboxTranslation(
      viewportSize: viewport,
      fittedRect: fitted,
      scale: 1.5,
      translation: const Offset(999, 999),
    );
    expect(clamped.dx, closeTo(0.0, 0.001));
    expect(clamped.dy, closeTo((800 - 450) / 2 - 250 * 1.5, 0.001));
  });

  test('fit toggle anchors long image at top for reading', () {
    final fitted = computeFittedImageRect(
      viewportSize: viewport,
      imageSize: const Size(400, 3200),
    );
    final zoomed = computeFitToggleTransform(
      viewportSize: viewport,
      fittedRect: fitted,
      currentScale: 1.0,
    );
    expect(zoomed.scale, closeTo(4.0, 0.001));
    expect(zoomed.translation.dy, closeTo(0.0, 0.001));
  });

  test(
    'edge state detects horizontal boundaries when zoomed past viewport width',
    () {
      final fitted = computeFittedImageRect(
        viewportSize: viewport,
        imageSize: const Size(1200, 900),
      );
      final leftEdge = computeLightboxEdgeState(
        viewportSize: viewport,
        fittedRect: fitted,
        scale: 2.0,
        translation: Offset.zero,
      );
      expect(leftEdge.hasHorizontalOverflow, isTrue);
      expect(leftEdge.atLeftEdge, isTrue);
      expect(leftEdge.atRightEdge, isFalse);

      final rightEdge = computeLightboxEdgeState(
        viewportSize: viewport,
        fittedRect: fitted,
        scale: 2.0,
        translation: const Offset(-400, -250),
      );
      expect(rightEdge.atLeftEdge, isFalse);
      expect(rightEdge.atRightEdge, isTrue);
    },
  );
}
