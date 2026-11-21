import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';

/// Stable paper material behind novel body text.
///
/// The texture is a deterministic tiled layer painted from a fixed seed, so
/// density stays consistent across screen sizes and theme switches never
/// randomize it. E-Ink mode always falls back to a clean solid surface.
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
    if (EInkModeScope.of(context) ||
        palette.backgroundTexture == NovelReaderBackgroundTexture.solid) {
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
  static const double _tileSize = 128.0;

  static final _PaperTileData _paperTile = _PaperTileData.generate(
    seed: _seed,
    tileSize: _tileSize,
  );
  static final _GrainTileData _grainTile = _GrainTileData.generate(
    seed: _seed + 7919,
    tileSize: _tileSize,
  );

  final NovelReaderBackgroundTexture texture;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || texture == NovelReaderBackgroundTexture.solid) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (texture) {
      case NovelReaderBackgroundTexture.solid:
        break;
      case NovelReaderBackgroundTexture.paper:
        _paintPaper(canvas, size);
      case NovelReaderBackgroundTexture.grain:
        _paintGrain(canvas, size);
    }
    canvas.restore();
  }

  void _paintPaper(Canvas canvas, Size size) {
    final weaveMajor = Paint()
      ..strokeWidth = 0.85
      ..color = isDark ? const Color(0x16FFFFFF) : const Color(0x165A4A38);
    final weaveMinor = Paint()
      ..strokeWidth = 0.65
      ..color = isDark ? const Color(0x0DFFFFFF) : const Color(0x0E5A4A38);
    final blobPrimary = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0x0DFFFFFF) : const Color(0x0E6B5842);
    final blobSecondary = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0x08D8D2C8) : const Color(0x0DFFFFFF);
    final primaryFiber = Paint()
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0x22FFFFFF) : const Color(0x264A3C2E);
    final highlightFiber = Paint()
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0x14D8D2C8) : const Color(0x22FFFFFF);

    // Subtle full-width laid-paper horizontal lines reinforce the paper grain.
    var step = 0;
    for (double y = 2.25; y < size.height; y += 4.5, step += 1) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        step % 5 == 0 ? weaveMajor : weaveMinor,
      );
    }

    final rows = (size.height / _tileSize).ceil();
    final cols = (size.width / _tileSize).ceil();
    for (var row = 0; row < rows; row += 1) {
      // Stagger alternate rows by half a tile to avoid vertical seam alignment.
      final startCol = row.isOdd ? -1 : 0;
      final xOffset = row.isOdd ? _tileSize * 0.5 : 0.0;
      for (var col = startCol; col < cols; col += 1) {
        final dx = col * _tileSize + xOffset;
        final dy = row * _tileSize;
        canvas.save();
        canvas.translate(dx, dy);
        for (var i = 0; i < _paperTile.blobs.length; i += 1) {
          canvas.drawOval(
            _paperTile.blobs[i],
            i.isEven ? blobPrimary : blobSecondary,
          );
        }
        for (var i = 0; i < _paperTile.fibers.length; i += 1) {
          final fiber = _paperTile.fibers[i];
          canvas.drawLine(
            fiber.$1,
            fiber.$2,
            i.isEven ? primaryFiber : highlightFiber,
          );
        }
        canvas.restore();
      }
    }
  }

  void _paintGrain(Canvas canvas, Size size) {
    final finePrimary = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = isDark ? const Color(0x28FFFFFF) : const Color(0x28382E24);
    final mediumPrimary = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.85
      ..color = isDark ? const Color(0x1EE8E2D8) : const Color(0x1E4A3C2E);
    final highlightSpeck = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.35
      ..color = isDark ? const Color(0x14CFC8BC) : const Color(0x26FFFFFF);

    final rows = (size.height / _tileSize).ceil();
    final cols = (size.width / _tileSize).ceil();
    for (var row = 0; row < rows; row += 1) {
      for (var col = 0; col < cols; col += 1) {
        canvas.save();
        canvas.translate(col * _tileSize, row * _tileSize);
        canvas.drawPoints(
          ui.PointMode.points,
          _grainTile.finePrimary,
          finePrimary,
        );
        canvas.drawPoints(
          ui.PointMode.points,
          _grainTile.mediumPrimary,
          mediumPrimary,
        );
        canvas.drawPoints(
          ui.PointMode.points,
          _grainTile.highlightSpeck,
          highlightSpeck,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_NovelReaderTexturePainter oldDelegate) =>
      oldDelegate.texture != texture || oldDelegate.isDark != isDark;
}

class _PaperTileData {
  const _PaperTileData({required this.blobs, required this.fibers});

  factory _PaperTileData.generate({
    required int seed,
    required double tileSize,
  }) {
    final random = math.Random(seed);
    final blobs = <Rect>[
      for (var i = 0; i < 8; i += 1)
        Rect.fromCenter(
          center: Offset(
            12 + random.nextDouble() * (tileSize - 24),
            12 + random.nextDouble() * (tileSize - 24),
          ),
          width: 14 + random.nextDouble() * 20,
          height: 8 + random.nextDouble() * 14,
        ),
    ];
    const angles = <double>[0.0, 0.58, -0.58, 1.12, -1.12];
    final fibers = <(Offset, Offset)>[];
    for (var i = 0; i < 36; i += 1) {
      final center = Offset(
        10 + random.nextDouble() * (tileSize - 20),
        10 + random.nextDouble() * (tileSize - 20),
      );
      final length = 7 + random.nextDouble() * 12;
      final angle =
          angles[i % angles.length] + (random.nextDouble() - 0.5) * 0.18;
      final dx = math.cos(angle) * length * 0.5;
      final dy = math.sin(angle) * length * 0.5;
      fibers.add((center.translate(-dx, -dy), center.translate(dx, dy)));
    }
    return _PaperTileData(blobs: blobs, fibers: fibers);
  }

  final List<Rect> blobs;
  final List<(Offset, Offset)> fibers;
}

class _GrainTileData {
  const _GrainTileData({
    required this.finePrimary,
    required this.mediumPrimary,
    required this.highlightSpeck,
  });

  factory _GrainTileData.generate({
    required int seed,
    required double tileSize,
  }) {
    final random = math.Random(seed);
    final finePrimary = <Offset>[];
    final mediumPrimary = <Offset>[];
    final highlightSpeck = <Offset>[];
    for (var i = 0; i < 260; i += 1) {
      final point = Offset(
        1 + random.nextDouble() * (tileSize - 2),
        1 + random.nextDouble() * (tileSize - 2),
      );
      switch (i % 4) {
        case 0:
        case 1:
          finePrimary.add(point);
        case 2:
          mediumPrimary.add(point);
        default:
          highlightSpeck.add(point);
      }
    }
    return _GrainTileData(
      finePrimary: finePrimary,
      mediumPrimary: mediumPrimary,
      highlightSpeck: highlightSpeck,
    );
  }

  final List<Offset> finePrimary;
  final List<Offset> mediumPrimary;
  final List<Offset> highlightSpeck;
}
