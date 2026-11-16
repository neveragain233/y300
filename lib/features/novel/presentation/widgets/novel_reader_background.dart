import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';

/// Stable paper material behind novel body text.
///
/// The texture is a static low-contrast layer painted from a fixed seed, so
/// theme and brightness changes never randomize it. Images and illustrations
/// keep their own color above this layer.
class NovelReaderBackground extends StatelessWidget {
  const NovelReaderBackground({
    super.key,
    required this.palette,
    required this.child,
  });

  final NovelReaderPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (palette.backgroundTexture == NovelReaderBackgroundTexture.solid) {
      return ColoredBox(
        key: const Key('novel-reader-background'),
        color: palette.background,
        child: child,
      );
    }
    return ColoredBox(
      key: const Key('novel-reader-background'),
      color: palette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const Key('novel-reader-background-texture'),
                  painter: _NovelReaderTexturePainter(
                    texture: palette.backgroundTexture,
                    isDark: palette.brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _NovelReaderTexturePainter extends CustomPainter {
  const _NovelReaderTexturePainter({
    required this.texture,
    required this.isDark,
  });

  /// Fixed seed keeps the same work stable across rebuilds and restarts.
  static const int _seed = 0x5930A1;

  final NovelReaderBackgroundTexture texture;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final random = math.Random(_seed);
    switch (texture) {
      case NovelReaderBackgroundTexture.solid:
        return;
      case NovelReaderBackgroundTexture.paper:
        _paintPaper(canvas, size, random);
        return;
      case NovelReaderBackgroundTexture.grain:
        _paintGrain(canvas, size, random);
        return;
    }
  }

  void _paintPaper(Canvas canvas, Size size, math.Random random) {
    // Dark surfaces limit highlight detail, so the fiber stays dimmer there.
    final fiber = Paint()
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0x0AFFFFFF) : const Color(0x0E2B241C);
    final count = (size.width * size.height / 12000).clamp(24, 180).toInt();
    for (var index = 0; index < count; index += 1) {
      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final length = 5 + random.nextDouble() * 16;
      canvas.drawLine(start, start.translate(length, 0), fiber);
    }
  }

  void _paintGrain(Canvas canvas, Size size, math.Random random) {
    final grain = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0x08FFFFFF) : const Color(0x10201A14);
    final count = (size.width * size.height / 2400).clamp(60, 900).toInt();
    for (var index = 0; index < count; index += 1) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.4 + random.nextDouble() * 0.5,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(_NovelReaderTexturePainter oldDelegate) =>
      oldDelegate.texture != texture || oldDelegate.isDark != isDark;
}
