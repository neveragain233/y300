import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';

/// Shared cache of seamless 512x512 grayscale paper and grain overlay tiles.
///
/// Decodes each PNG tile once per process and exposes a [Listenable] so mounted
/// reader backgrounds and page sheets repaint cleanly as soon as decoding ends.
class NovelReaderTextureCache extends ChangeNotifier {
  NovelReaderTextureCache._();

  static final NovelReaderTextureCache instance = NovelReaderTextureCache._();

  final Map<NovelReaderBackgroundTexture, ui.Image> _images =
      <NovelReaderBackgroundTexture, ui.Image>{};
  final Map<NovelReaderBackgroundTexture, Future<ui.Image?>> _inFlight =
      <NovelReaderBackgroundTexture, Future<ui.Image?>>{};
  final Map<(NovelReaderBackgroundTexture, double), ui.ImageShader> _shaders =
      <(NovelReaderBackgroundTexture, double), ui.ImageShader>{};

  static String? _assetPathFor(NovelReaderBackgroundTexture texture) {
    return switch (texture) {
      NovelReaderBackgroundTexture.solid => null,
      NovelReaderBackgroundTexture.paper =>
        'assets/textures/novel_paper_tile.png',
      NovelReaderBackgroundTexture.grain =>
        'assets/textures/novel_grain_tile.png',
    };
  }

  /// Returns the decoded tile image for [texture] if ready, otherwise triggers
  /// an async load and returns `null`.
  ui.Image? imageFor(NovelReaderBackgroundTexture texture) {
    if (texture == NovelReaderBackgroundTexture.solid) {
      return null;
    }
    final cached = _images[texture];
    if (cached != null) {
      return cached;
    }
    _inFlight.putIfAbsent(texture, () => _load(texture));
    return null;
  }

  /// Ensures [texture] is decoded if its asset is bundled; returns `null` when
  /// [texture] is solid or the asset cannot be decoded.
  Future<ui.Image?> ensureLoaded(NovelReaderBackgroundTexture texture) {
    if (texture == NovelReaderBackgroundTexture.solid) {
      return Future<ui.Image?>.value(null);
    }
    final cached = _images[texture];
    if (cached != null) {
      return Future<ui.Image?>.value(cached);
    }
    return _inFlight.putIfAbsent(texture, () => _load(texture));
  }

  /// Returns a cached repeating [ui.ImageShader] for [texture] at [tileScale].
  ui.ImageShader? shaderFor(
    NovelReaderBackgroundTexture texture, {
    required double tileScale,
  }) {
    final image = imageFor(texture);
    if (image == null) {
      return null;
    }
    final key = (texture, tileScale);
    return _shaders.putIfAbsent(
      key,
      () => ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Matrix4.diagonal3Values(tileScale, tileScale, 1.0).storage,
      ),
    );
  }

  Future<ui.Image?> _load(NovelReaderBackgroundTexture texture) async {
    final path = _assetPathFor(texture);
    if (path == null) {
      _inFlight.remove(texture);
      return null;
    }
    ui.Codec? codec;
    try {
      final data = await rootBundle.load(path);
      codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _images[texture] = frame.image;
      notifyListeners();
      return frame.image;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
      _inFlight.remove(texture);
    }
  }
}

/// Reusable reader paper surface combining base [color] and optional seamless
/// grayscale [texture] overlay.
///
/// E-Ink mode and [NovelReaderBackgroundTexture.solid] always stay a clean
/// single-pass [ColoredBox] with zero texture overhead.
class NovelReaderPaperSurface extends StatelessWidget {
  const NovelReaderPaperSurface({
    super.key,
    required this.color,
    required this.texture,
    required this.child,
    this.isDark,
    this.surfaceKey,
    this.textureKey,
  });

  final Color color;
  final NovelReaderBackgroundTexture texture;
  final bool? isDark;
  final Key? surfaceKey;
  final Key? textureKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (EInkModeScope.of(context) ||
        texture == NovelReaderBackgroundTexture.solid) {
      return ColoredBox(key: surfaceKey, color: color, child: child);
    }
    final resolvedIsDark =
        isDark ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark);
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return ColoredBox(
      key: surfaceKey,
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: textureKey,
                  painter: _NovelReaderTexturePainter(
                    texture: texture,
                    isDark: resolvedIsDark,
                    devicePixelRatio: devicePixelRatio,
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

/// Stable paper material behind novel body text.
///
/// E-Ink mode always falls back to a clean solid surface.
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
    return NovelReaderPaperSurface(
      surfaceKey: const Key('novel-reader-background'),
      textureKey: const Key('novel-reader-background-texture'),
      color: palette.background,
      texture: palette.backgroundTexture,
      isDark: palette.brightness == Brightness.dark,
      child: child,
    );
  }
}

class _NovelReaderTexturePainter extends CustomPainter {
  _NovelReaderTexturePainter({
    required this.texture,
    required this.isDark,
    required this.devicePixelRatio,
  }) : super(repaint: NovelReaderTextureCache.instance);

  final NovelReaderBackgroundTexture texture;
  final bool isDark;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || texture == NovelReaderBackgroundTexture.solid) {
      return;
    }
    final tileScale = texture == NovelReaderBackgroundTexture.grain
        ? 1.0 / devicePixelRatio.clamp(1.0, 4.0)
        : 1.0 / devicePixelRatio.clamp(1.0, 2.0);
    final shader = NovelReaderTextureCache.instance.shaderFor(
      texture,
      tileScale: tileScale,
    );
    if (shader == null) {
      return;
    }
    final paint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.low
      ..color = Color.fromRGBO(255, 255, 255, isDark ? 0.50 : 0.68);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_NovelReaderTexturePainter oldDelegate) =>
      oldDelegate.texture != texture ||
      oldDelegate.isDark != isDark ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
