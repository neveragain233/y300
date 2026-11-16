import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('paper and grain paint an independent background layer', (
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
      await tester.pump();

      expect(
        find.byKey(const Key('novel-reader-background-texture')),
        findsOneWidget,
        reason: texture.name,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
