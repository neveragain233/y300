import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';

/// Shared cache of seamless 512x512 dual-channel paper and grain overlay tiles.
///
/// The red channel encodes depressed valleys/fibers and the green channel
/// encodes raised ridges/pulp highlights at full 8-bit precision so runtime
/// [ColorFilter.matrix] passes can tint them to any reader theme palette.
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

/// Resolved dual-polarity paper/grain tinting and opacity weights for a reader
/// background color.
@immutable
class NovelReaderTextureTuning {
  const NovelReaderTextureTuning({
    required this.valleyR,
    required this.valleyG,
    required this.valleyB,
    required this.valleyAlpha,
    required this.ridgeR,
    required this.ridgeG,
    required this.ridgeB,
    required this.ridgeAlpha,
    required this.tileScale,
  });

  final double valleyR;
  final double valleyG;
  final double valleyB;
  final double valleyAlpha;
  final double ridgeR;
  final double ridgeG;
  final double ridgeB;
  final double ridgeAlpha;
  final double tileScale;

  /// Derives hue-coherent valley and ridge colors plus luminance-adaptive
  /// standard (`1.00x`) blend weights across light, near-white, dark and OLED
  /// black reader themes.
  factory NovelReaderTextureTuning.resolve({
    required Color background,
    required bool isDark,
    required NovelReaderBackgroundTexture texture,
  }) {
    if (texture == NovelReaderBackgroundTexture.solid) {
      return const NovelReaderTextureTuning(
        valleyR: 0.0,
        valleyG: 0.0,
        valleyB: 0.0,
        valleyAlpha: 0.0,
        ridgeR: 0.0,
        ridgeG: 0.0,
        ridgeB: 0.0,
        ridgeAlpha: 0.0,
        tileScale: 1.0,
      );
    }

    final br = background.r * 255.0;
    final bg = background.g * 255.0;
    final bb = background.b * 255.0;
    final y = 0.299 * br + 0.587 * bg + 0.114 * bb;
    final l = y / 255.0;
    final dr = br - y;
    final dg = bg - y;
    final db = bb - y;

    final isPaper = texture == NovelReaderBackgroundTexture.paper;
    final tileScale = isPaper ? 0.75 : 0.60;

    if (!isDark) {
      final yv = math.max(20.0, y - 108.0);
      final yr = math.min(255.0, y + 56.0);
      final nearWhite = ((l - 0.90) / 0.10).clamp(0.0, 1.0);
      return NovelReaderTextureTuning(
        valleyR: (yv + dr * 1.35).clamp(0.0, 255.0),
        valleyG: (yv + dg * 1.35).clamp(0.0, 255.0),
        valleyB: (yv + db * 1.35).clamp(0.0, 255.0),
        valleyAlpha: isPaper
            ? (0.14 + 0.025 * nearWhite)
            : (0.13 + 0.025 * nearWhite),
        ridgeR: (yr + dr * 0.65).clamp(0.0, 255.0),
        ridgeG: (yr + dg * 0.65).clamp(0.0, 255.0),
        ridgeB: (yr + db * 0.65).clamp(0.0, 255.0),
        ridgeAlpha: (isPaper ? 0.17 : 0.15) * (1.0 - 0.60 * nearWhite),
        tileScale: tileScale,
      );
    }

    final yv = math.max(0.0, y * 0.22);
    final yr = math.min(140.0, y + 62.0);
    final pureBlack = ((0.08 - l) / 0.08).clamp(0.0, 1.0);
    return NovelReaderTextureTuning(
      valleyR: (yv + dr * 0.85).clamp(0.0, 255.0),
      valleyG: (yv + dg * 0.85).clamp(0.0, 255.0),
      valleyB: (yv + db * 0.85).clamp(0.0, 255.0),
      valleyAlpha: (isPaper ? 0.28 : 0.26) * (1.0 - pureBlack),
      ridgeR: (yr + dr * 1.25).clamp(0.0, 255.0),
      ridgeG: (yr + dg * 1.25).clamp(0.0, 255.0),
      ridgeB: (yr + db * 1.25).clamp(0.0, 255.0),
      ridgeAlpha: (isPaper ? 0.145 : 0.135) - 0.048 * pureBlack,
      tileScale: tileScale,
    );
  }
}

/// Reusable reader paper surface combining base [color] and optional seamless
/// hue-coherent [texture] overlay.
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
                    color: color,
                    isDark: resolvedIsDark,
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
    required this.color,
    required this.isDark,
  }) : tuning = NovelReaderTextureTuning.resolve(
         background: color,
         isDark: isDark,
         texture: texture,
       ),
       super(repaint: NovelReaderTextureCache.instance);

  final NovelReaderBackgroundTexture texture;
  final Color color;
  final bool isDark;
  final NovelReaderTextureTuning tuning;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || texture == NovelReaderBackgroundTexture.solid) {
      return;
    }
    final shader = NovelReaderTextureCache.instance.shaderFor(
      texture,
      tileScale: tuning.tileScale,
    );
    if (shader == null) {
      return;
    }
    final rect = Offset.zero & size;
    if (tuning.valleyAlpha > 0.0001) {
      _paintChannel(
        canvas,
        rect,
        shader: shader,
        r: tuning.valleyR,
        g: tuning.valleyG,
        b: tuning.valleyB,
        rAlphaWeight: tuning.valleyAlpha,
        gAlphaWeight: 0.0,
      );
    }
    if (tuning.ridgeAlpha > 0.0001) {
      _paintChannel(
        canvas,
        rect,
        shader: shader,
        r: tuning.ridgeR,
        g: tuning.ridgeG,
        b: tuning.ridgeB,
        rAlphaWeight: 0.0,
        gAlphaWeight: tuning.ridgeAlpha,
      );
    }
  }

  void _paintChannel(
    Canvas canvas,
    Rect rect, {
    required ui.ImageShader shader,
    required double r,
    required double g,
    required double b,
    required double rAlphaWeight,
    required double gAlphaWeight,
  }) {
    final paint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.low
      ..colorFilter = ColorFilter.matrix(<double>[
        0, 0, 0, 0, r, //
        0, 0, 0, 0, g, //
        0, 0, 0, 0, b, //
        rAlphaWeight, gAlphaWeight, 0, 0, 0, //
      ]);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_NovelReaderTexturePainter oldDelegate) =>
      oldDelegate.texture != texture ||
      oldDelegate.color != color ||
      oldDelegate.isDark != isDark;
}
