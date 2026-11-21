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
}
