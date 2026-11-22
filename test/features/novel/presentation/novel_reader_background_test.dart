import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';
import 'package:y300/features/novel/presentation/widgets/novel_reader_background.dart';

void main() {
  const resolver = NovelReaderThemeResolver();

  NovelReaderPalette paletteFor(
    NovelReaderBackgroundTexture texture,
    NovelReaderThemePreset preset,
  ) {
    return resolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        backgroundTexture: texture,
        themePreset: preset,
      ),
      theme: ThemeData.light(),
    );
  }

  testWidgets('solid paper keeps a plain base color without a texture layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NovelReaderBackground(
          palette: paletteFor(
            NovelReaderBackgroundTexture.solid,
            NovelReaderThemePreset.cream,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(
      find.byKey(const Key('novel-reader-background-texture')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(NovelReaderBackground),
        matching: find.byType(ColoredBox),
      ),
      findsOneWidget,
    );
  });

  testWidgets('paper and grain paint an independent visible texture layer', (
    tester,
  ) async {
    for (final texture in [
      NovelReaderBackgroundTexture.paper,
      NovelReaderBackgroundTexture.grain,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderBackground(
            palette: paletteFor(texture, NovelReaderThemePreset.ink),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.runAsync(
        () => NovelReaderTextureCache.instance.ensureLoaded(texture),
      );
      await tester.pump();

      final customPaintFinder = find.byKey(
        const Key('novel-reader-background-texture'),
      );
      expect(customPaintFinder, findsOneWidget, reason: texture.name);
      final paint = tester.widget<CustomPaint>(customPaintFinder);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paint.painter!.paint(canvas, const Size(128, 128));
      final picture = recorder.endRecording();
      final bytes = await tester.runAsync(() async {
        final image = picture.toImageSync(64, 64);
        final data = await image.toByteData();
        image.dispose();
        picture.dispose();
        return data;
      });
      final raw = bytes!.buffer.asUint8List();
      final hasVisiblePixels = raw.any((byte) => byte != 0);
      expect(hasVisiblePixels, isTrue, reason: texture.name);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('eInk mode suppresses decorative texture layer', (tester) async {
    await tester.pumpWidget(
      EInkModeScope(
        enabled: true,
        child: MaterialApp(
          home: NovelReaderBackground(
            palette: paletteFor(
              NovelReaderBackgroundTexture.paper,
              NovelReaderThemePreset.cream,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('novel-reader-background-texture')),
      findsNothing,
    );
  });

  test('NovelReaderTextureTuning preserves hue coherence across light and dark themes', () {
    final cream = NovelReaderTextureTuning.resolve(
      background: const Color(0xFFFBF3E2),
      isDark: false,
      texture: NovelReaderBackgroundTexture.paper,
    );
    expect(cream.tileScale, 0.75);
    expect(cream.valleyAlpha, closeTo(0.149, 0.01));
    expect(cream.ridgeAlpha, greaterThan(0.10));
    // 暖米色压暗后维持偏暖中性褐调（R >= G > B），不能爆成高饱和橙黄。
    expect(cream.valleyR, greaterThanOrEqualTo(cream.valleyG));
    expect(cream.valleyG, greaterThan(cream.valleyB));
    expect(cream.valleyR - cream.valleyB, lessThan(45.0));

    final sage = NovelReaderTextureTuning.resolve(
      background: const Color(0xFFE9F0E4),
      isDark: false,
      texture: NovelReaderBackgroundTexture.grain,
    );
    expect(sage.tileScale, 0.60);
    // 浅绿保持绿色通道主色相，不发粉或发灰失色。
    expect(sage.valleyG, greaterThan(sage.valleyR));
    expect(sage.valleyG, greaterThan(sage.valleyB));

    final ink = NovelReaderTextureTuning.resolve(
      background: const Color(0xFF000000),
      isDark: true,
      texture: NovelReaderBackgroundTexture.paper,
    );
    expect(ink.valleyAlpha, 0.0);
    expect(ink.ridgeAlpha, closeTo(0.097, 0.002));
    expect(ink.ridgeR, closeTo(62.0, 1.0));

    final followMoonDark = NovelReaderTextureTuning.resolve(
      background: const Color(0xFF121820),
      isDark: true,
      texture: NovelReaderBackgroundTexture.grain,
    );
    expect(followMoonDark.tileScale, 0.60);
    expect(followMoonDark.valleyAlpha, greaterThan(0.0));
    expect(followMoonDark.ridgeB, greaterThan(followMoonDark.ridgeR));
  });

  testWidgets(
    'paper and grain modulate pixels across light, cream, sage, charcoal and ink presets',
    (tester) async {
      for (final texture in [
        NovelReaderBackgroundTexture.paper,
        NovelReaderBackgroundTexture.grain,
      ]) {
        await tester.runAsync(
          () => NovelReaderTextureCache.instance.ensureLoaded(texture),
        );
        for (final preset in [
          NovelReaderThemePreset.cream,
          NovelReaderThemePreset.sage,
          NovelReaderThemePreset.charcoal,
          NovelReaderThemePreset.ink,
        ]) {
          final palette = paletteFor(texture, preset);
          await tester.pumpWidget(
            MaterialApp(
              home: NovelReaderBackground(
                palette: palette,
                child: const SizedBox.expand(),
              ),
            ),
          );
          await tester.pump();

          final paint = tester.widget<CustomPaint>(
            find.byKey(const Key('novel-reader-background-texture')),
          );
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 128, 128),
            Paint()..color = palette.background,
          );
          paint.painter!.paint(canvas, const Size(128, 128));
          final picture = recorder.endRecording();
          final bytes = await tester.runAsync(() async {
            final image = picture.toImageSync(64, 64);
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            picture.dispose();
            return data;
          });
          final raw = bytes!.buffer.asUint8List();
          var minLuma = 255.0;
          var maxLuma = 0.0;
          var bgDiffCount = 0;
          final bgR = (palette.background.r * 255.0).round();
          final bgG = (palette.background.g * 255.0).round();
          final bgB = (palette.background.b * 255.0).round();
          for (var i = 0; i < raw.length; i += 4) {
            final r = raw[i];
            final g = raw[i + 1];
            final b = raw[i + 2];
            final luma = 0.299 * r + 0.587 * g + 0.114 * b;
            if (luma < minLuma) minLuma = luma;
            if (luma > maxLuma) maxLuma = luma;
            if ((r - bgR).abs() >= 2 ||
                (g - bgG).abs() >= 2 ||
                (b - bgB).abs() >= 2) {
              bgDiffCount += 1;
            }
          }
          expect(
            maxLuma - minLuma,
            greaterThanOrEqualTo(5.0),
            reason: '${texture.name} on ${preset.name}',
          );
          expect(
            bgDiffCount,
            greaterThan(250),
            reason: '${texture.name} modulated pixel count on ${preset.name}',
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
