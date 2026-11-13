import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// 颜色与轮廓分别输入，未来固定主题和动态色共用同一份标志覆盖率。
final class IconPalette {
  const IconPalette({required this.background, this.foreground});

  static const brand = IconPalette(background: 0xfff9e2);
  static const brandDark = IconPalette(
    background: 0x20201d,
    foreground: 0xffb4ab,
  );

  final int background;
  final int? foreground;
}

enum IconShape { square, circle, roundedSquare }

img.Image extractIconArtwork(img.Image source) {
  final logo = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  // 原素材为乳黄底红色标志；沿既有消光计算保留抗锯齿覆盖率。
  const background = [253.0, 252.0, 241.0];
  for (final pixel in source) {
    final coverage = ((background[1] - pixel.g) / (background[1] - 6)).clamp(
      0.0,
      1.0,
    );
    if (pixel.a == 0 || coverage < .02) continue;
    int unmatte(num channel, double matte) =>
        ((channel - matte * (1 - coverage)) / coverage).round().clamp(0, 255);
    logo.setPixelRgba(
      pixel.x,
      pixel.y,
      unmatte(pixel.r, background[0]),
      unmatte(pixel.g, background[1]),
      unmatte(pixel.b, background[2]),
      (pixel.a * coverage).round(),
    );
  }
  if (!logo.any((pixel) => pixel.a > 0)) {
    throw StateError('The source contains no icon artwork.');
  }
  // 原画布的留白、字母和百合位置共同组成构图，不按非透明包围盒重排。
  return logo;
}

img.Image renderIconMark(
  img.Image artwork, {
  required int size,
  required int viewportSize,
  int? tint,
}) {
  if (viewportSize < 1 || viewportSize > size) {
    throw ArgumentError.value(viewportSize, 'viewportSize');
  }
  final mark = img.copyResize(
    artwork,
    width: viewportSize,
    height: viewportSize,
    interpolation: img.Interpolation.average,
  );
  if (tint != null) {
    for (final pixel in mark) {
      pixel
        ..r = (tint >> 16) & 255
        ..g = (tint >> 8) & 255
        ..b = tint & 255;
    }
  }
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  final inset = (size - viewportSize) ~/ 2;
  for (final pixel in canvas) {
    // 右下红色斜面延伸至出血区；系统遮罩或轻微位移不会露出前景方框。
    final x = (pixel.x - inset).clamp(0, viewportSize - 1);
    final y = (pixel.y - inset).clamp(0, viewportSize - 1);
    canvas.setPixel(pixel.x, pixel.y, mark.getPixel(x, y));
  }
  return canvas;
}

img.Image renderIconTile(
  img.Image artwork, {
  required int size,
  required IconShape shape,
  IconPalette palette = IconPalette.brand,
}) {
  final tile = img.Image(width: size, height: size, numChannels: 4);
  img.fill(
    tile,
    color: img.ColorRgb8(
      (palette.background >> 16) & 255,
      (palette.background >> 8) & 255,
      palette.background & 255,
    ),
  );
  img.compositeImage(
    tile,
    renderIconMark(
      artwork,
      size: size,
      viewportSize: size,
      tint: palette.foreground,
    ),
  );
  final half = size / 2;
  final radius = shape == IconShape.circle ? half : size * .21;
  for (final pixel in tile) {
    final dx = (pixel.x + .5 - half).abs() - (half - radius);
    final dy = (pixel.y + .5 - half).abs() - (half - radius);
    final distance =
        math.sqrt(math.pow(math.max(dx, 0), 2) + math.pow(math.max(dy, 0), 2)) +
        math.min(math.max(dx, dy), 0) -
        radius;
    pixel.a = shape == IconShape.square
        ? 255
        : (255 * (.5 - distance).clamp(0.0, 1.0)).round();
  }
  return tile;
}
