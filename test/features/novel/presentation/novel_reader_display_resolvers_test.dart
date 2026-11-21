import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/features/fonts/fonts.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';
import 'package:y300/shared/utils/wcag_color_contrast.dart';

void main() {
  const themeResolver = NovelReaderThemeResolver();
  const typographyResolver = NovelReaderTypographyResolver();

  test('NovelReaderThemeResolver resolves stable preset palettes', () {
    final theme = ThemeData.light();

    final light = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.light,
      ),
      theme: theme,
    );
    final sepia = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.sepia,
      ),
      theme: theme,
    );
    final dark = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.dark,
      ),
      theme: theme,
    );

    expect(light.background, const Color(0xFFFDFDFD));
    expect(light.foreground, const Color(0xFF1F1F1F));
    expect(sepia.background, const Color(0xFFF4EAD7));
    expect(sepia.foreground, const Color(0xFF4C3A21));
    expect(dark.background, const Color(0xFF141414));
    expect(dark.foreground, const Color(0xFFE9E9E9));
  });

  test('body brightness dims article tone but not reader controls', () {
    final theme = ThemeData.light();
    final base = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.dark,
      ),
      theme: theme,
    );
    final dimmed = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.dark,
        bodyBrightness: 0.55,
      ),
      theme: theme,
    );

    expect(dimmed.foreground, isNot(base.foreground));
    expect(
      WcagColorContrast.ratio(dimmed.foreground, dimmed.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(dimmed.controlForeground, base.controlForeground);
    expect(dimmed.controlMuted, base.controlMuted);
  });

  test('expanded presets keep their brightness and readable body pairs', () {
    final theme = ThemeData.light();
    for (final preset in NovelReaderThemePreset.values) {
      final palette = themeResolver.resolve(
        preferences: NovelReaderPreferences.defaults().copyWith(
          themePreset: preset,
        ),
        theme: theme,
      );
      expect(
        WcagColorContrast.ratio(palette.foreground, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: preset.name,
      );
    }
    final paper = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.paperWhite,
      ),
      theme: theme,
    );
    final ink = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.ink,
      ),
      theme: ThemeData.dark(),
    );
    expect(paper.brightness, Brightness.light);
    expect(paper.background, const Color(0xFFFAFAF5));
    expect(ink.brightness, Brightness.dark);
    expect(ink.background, const Color(0xFF000000));
  });

  test('NovelReaderThemeResolver follows the active application theme', () {
    final preferences = NovelReaderPreferences.defaults().copyWith(
      themePreset: NovelReaderThemePreset.followApp,
    );

    for (final family in AppThemeFamily.values) {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(family: family, brightness: brightness);
        final palette = themeResolver.resolve(
          preferences: preferences,
          theme: theme,
        );

        expect(palette.brightness, theme.brightness);
        expect(palette.background, theme.scaffoldBackgroundColor);
        expect(palette.foreground, theme.colorScheme.onSurface);
        expect(palette.muted, theme.colorScheme.onSurfaceVariant);
        expect(palette.accent, theme.colorScheme.primary);
        expect(palette.surface, theme.colorScheme.surfaceContainer);
        expect(palette.link, theme.colorScheme.primary);
        expect(
          palette.quoteBackground,
          theme.colorScheme.surfaceContainerHighest,
        );
      }
    }
  });

  test('NovelReaderTypographyResolver applies advanced preferences', () {
    final theme = ThemeData.light();
    final palette = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults(),
      theme: theme,
    );
    final typography = typographyResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        fontSize: 21,
        lineHeight: 2,
        fontWeight: 700,
        fontFamily: _fontId,
        textAlign: NovelReaderTextAlignMode.justify,
        paragraphIndent: NovelReaderParagraphIndentMode.increase,
        contentMaxWidth: 680,
      ),
      theme: theme,
      palette: palette,
      resolvedFont: const ResolvedFont(
        id: _fontId,
        fontFamily: 'fixture-serif',
      ),
    );

    expect(typography.body.fontSize, 21);
    expect(typography.body.height, 2);
    expect(typography.body.fontWeight, FontWeight.w700);
    expect(typography.body.fontFamily, 'fixture-serif');
    expect(typography.textAlign, TextAlign.justify);
    expect(typography.paragraphIndent, NovelReaderParagraphIndentMode.increase);
    expect(typography.contentMaxWidth, 680);
  });

  test('unresolved content IDs never become engine family names', () {
    final preferences = NovelReaderPreferences.defaults().copyWith(
      fontFamily: _fontId,
    );
    final theme = ThemeData.light();
    final palette = themeResolver.resolve(
      preferences: preferences,
      theme: theme,
    );
    final typography = typographyResolver.resolve(
      preferences: preferences,
      theme: theme,
      palette: palette,
    );
    expect(typography.body.fontFamily, isNull);
    expect(typography.quote.fontFamily, isNull);
    expect(typography.link.fontFamily, isNull);
  });

  test('all reading styles share the resolved family and retain emphasis', () {
    final preferences = NovelReaderPreferences.defaults().copyWith(
      fontFamily: _fontId,
    );
    final theme = ThemeData.light();
    final palette = themeResolver.resolve(
      preferences: preferences,
      theme: theme,
    );
    final typography = typographyResolver.resolve(
      preferences: preferences,
      theme: theme,
      palette: palette,
      resolvedFont: const ResolvedFont(
        id: _fontId,
        fontFamily: 'fixture-reading-family',
      ),
    );
    for (final style in [
      typography.body,
      typography.chapterTitle,
      typography.quote,
      typography.link,
    ]) {
      expect(style.fontFamily, 'fixture-reading-family');
    }
    expect(typography.chapterTitle.fontWeight, FontWeight.w700);
    expect(typography.quote.color, palette.foreground);
    expect(typography.link.color, palette.link);
    expect(typography.body.fontSize, preferences.fontSize);
    expect(typography.body.height, preferences.lineHeight);
  });

  test('eInkMode narrows presets to monochrome followApp/light/ink and forces solid texture', () {
    final theme = ThemeData.light();
    final sepiaInEInk = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.sepia,
        backgroundTexture: NovelReaderBackgroundTexture.paper,
      ),
      theme: theme,
      eInkMode: true,
    );
    expect(sepiaInEInk.background, theme.scaffoldBackgroundColor);
    expect(sepiaInEInk.backgroundTexture, NovelReaderBackgroundTexture.solid);

    final lightInEInk = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.light,
        backgroundTexture: NovelReaderBackgroundTexture.grain,
      ),
      theme: theme,
      eInkMode: true,
    );
    expect(lightInEInk.background, const Color(0xFFFFFFFF));
    expect(lightInEInk.foreground, const Color(0xFF000000));
    expect(lightInEInk.backgroundTexture, NovelReaderBackgroundTexture.solid);

    final darkInEInk = themeResolver.resolve(
      preferences: NovelReaderPreferences.defaults().copyWith(
        themePreset: NovelReaderThemePreset.dark,
        backgroundTexture: NovelReaderBackgroundTexture.paper,
      ),
      theme: theme,
      eInkMode: true,
    );
    expect(darkInEInk.background, const Color(0xFF000000));
    expect(darkInEInk.foreground, const Color(0xFFFFFFFF));
    expect(darkInEInk.backgroundTexture, NovelReaderBackgroundTexture.solid);
  });
}

const _fontId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
