import 'package:flutter/material.dart';
import 'package:y300/features/fonts/fonts.dart' show ResolvedFont;
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/shared/utils/wcag_color_contrast.dart';

/// Resolved reader colors. Body tone and control tone are separate: the body
/// brightness preference must never dim the directory, buttons or status bars.
class NovelReaderPalette {
  const NovelReaderPalette({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.muted,
    required this.accent,
    required this.surface,
    required this.link,
    required this.quoteBackground,
    required this.controlForeground,
    required this.controlMuted,
    required this.backgroundTexture,
  });

  final Brightness brightness;
  final Color background;

  /// Brightness-adjusted ordinary body and quote foreground.
  final Color foreground;

  /// Semantically secondary body information (chapter notes, status text).
  final Color muted;
  final Color accent;
  final Color surface;
  final Color link;
  final Color quoteBackground;

  /// Reader chrome colors; independent of [foreground].
  final Color controlForeground;
  final Color controlMuted;

  final NovelReaderBackgroundTexture backgroundTexture;
}

class NovelReaderThemeResolver {
  const NovelReaderThemeResolver();

  static const List<NovelReaderThemePreset> eInkPresets =
      <NovelReaderThemePreset>[
        NovelReaderThemePreset.followApp,
        NovelReaderThemePreset.light,
        NovelReaderThemePreset.ink,
      ];

  static NovelReaderThemePreset effectivePreset(
    NovelReaderThemePreset preset, {
    required bool eInkMode,
  }) {
    if (!eInkMode) {
      return preset;
    }
    return switch (preset) {
      NovelReaderThemePreset.followApp => NovelReaderThemePreset.followApp,
      NovelReaderThemePreset.light => NovelReaderThemePreset.light,
      NovelReaderThemePreset.ink ||
      NovelReaderThemePreset.dark => NovelReaderThemePreset.ink,
      _ => NovelReaderThemePreset.followApp,
    };
  }

  NovelReaderPalette resolve({
    required NovelReaderPreferences preferences,
    required ThemeData theme,
    bool eInkMode = false,
  }) {
    final effective = effectivePreset(
      preferences.themePreset,
      eInkMode: eInkMode,
    );
    final base = eInkMode
        ? _basePaletteForEInk(effective, theme)
        : _basePalette(effective, theme);
    final bodyForeground = WcagColorContrast.blendWhileReadable(
      source: base.foreground,
      target: base.background,
      // Night body brightness dims article text toward its paper, never past
      // the minimum readable contrast.
      amount: (1 - preferences.bodyBrightness) * 0.8,
    );
    return NovelReaderPalette(
      brightness: base.brightness,
      background: base.background,
      foreground: bodyForeground,
      muted: base.muted,
      accent: base.accent,
      surface: base.surface,
      link: base.link,
      quoteBackground: base.quoteBackground,
      controlForeground: base.foreground,
      controlMuted: base.muted,
      backgroundTexture: eInkMode
          ? NovelReaderBackgroundTexture.solid
          : preferences.backgroundTexture,
    );
  }

  NovelReaderPalette _basePaletteForEInk(
    NovelReaderThemePreset preset,
    ThemeData theme,
  ) {
    switch (preset) {
      case NovelReaderThemePreset.light:
        return const NovelReaderPalette(
          brightness: Brightness.light,
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF000000),
          muted: Color(0xFF555555),
          accent: Color(0xFF000000),
          surface: Color(0xFFFFFFFF),
          link: Color(0xFF000000),
          quoteBackground: Color(0xFFF0F0F0),
          controlForeground: Color(0xFF000000),
          controlMuted: Color(0xFF555555),
          backgroundTexture: NovelReaderBackgroundTexture.solid,
        );
      case NovelReaderThemePreset.ink:
        return const NovelReaderPalette(
          brightness: Brightness.dark,
          background: Color(0xFF000000),
          foreground: Color(0xFFFFFFFF),
          muted: Color(0xFFCCCCCC),
          accent: Color(0xFFFFFFFF),
          surface: Color(0xFF000000),
          link: Color(0xFFFFFFFF),
          quoteBackground: Color(0xFF1A1A1A),
          controlForeground: Color(0xFFFFFFFF),
          controlMuted: Color(0xFFCCCCCC),
          backgroundTexture: NovelReaderBackgroundTexture.solid,
        );
      case NovelReaderThemePreset.followApp:
      default:
        return _basePalette(NovelReaderThemePreset.followApp, theme);
    }
  }

  NovelReaderPalette _basePalette(
    NovelReaderThemePreset preset,
    ThemeData theme,
  ) {
    switch (preset) {
      case NovelReaderThemePreset.followApp:
        final scheme = theme.colorScheme;
        return NovelReaderPalette(
          brightness: theme.brightness,
          background: theme.scaffoldBackgroundColor,
          foreground: scheme.onSurface,
          muted: scheme.onSurfaceVariant,
          accent: scheme.primary,
          surface: scheme.surfaceContainer,
          link: scheme.primary,
          quoteBackground: scheme.surfaceContainerHighest,
          controlForeground: scheme.onSurface,
          controlMuted: scheme.onSurfaceVariant,
          backgroundTexture: NovelReaderBackgroundTexture.solid,
        );
      case NovelReaderThemePreset.light:
        return NovelReaderPalette(
          brightness: Brightness.light,
          background: const Color(0xFFFDFDFD),
          foreground: const Color(0xFF1F1F1F),
          muted: const Color(0xFF737373),
          accent: theme.colorScheme.primary,
          surface: theme.colorScheme.surface,
          link: theme.colorScheme.primary,
          quoteBackground: const Color(0xFFF1F1F1),
          controlForeground: const Color(0xFF1F1F1F),
          controlMuted: const Color(0xFF737373),
          backgroundTexture: NovelReaderBackgroundTexture.solid,
        );
      case NovelReaderThemePreset.paperWhite:
        return _light(
          background: const Color(0xFFFAFAF5),
          foreground: const Color(0xFF26241F),
          muted: const Color(0xFF6D6A61),
          surface: const Color(0xFFF1F1EA),
          quoteBackground: const Color(0xFFEDEDE4),
          accent: const Color(0xFF8A6D3B),
          link: const Color(0xFF5E4E96),
        );
      case NovelReaderThemePreset.cream:
        return _light(
          background: const Color(0xFFFBF3E2),
          foreground: const Color(0xFF4B4030),
          muted: const Color(0xFF857662),
          surface: const Color(0xFFF3E8D2),
          quoteBackground: const Color(0xFFF1E4CB),
          accent: const Color(0xFF9A7736),
          link: const Color(0xFF6F5AA8),
        );
      case NovelReaderThemePreset.sepia:
        return _light(
          background: const Color(0xFFF4EAD7),
          foreground: const Color(0xFF4C3A21),
          muted: const Color(0xFF8B7355),
          surface: const Color(0xFFEFE0C4),
          quoteBackground: const Color(0xFFE8D8B8),
          accent: const Color(0xFF7A5A28),
          link: const Color(0xFF6A55A3),
        );
      case NovelReaderThemePreset.sage:
        return _light(
          background: const Color(0xFFE9F0E4),
          foreground: const Color(0xFF26332A),
          muted: const Color(0xFF5E6E60),
          surface: const Color(0xFFE0E9DA),
          quoteBackground: const Color(0xFFDDE8D6),
          accent: const Color(0xFF4F6B52),
          link: const Color(0xFF415C9E),
        );
      case NovelReaderThemePreset.gray:
        return _light(
          background: const Color(0xFFE8E8E6),
          foreground: const Color(0xFF262626),
          muted: const Color(0xFF666666),
          surface: const Color(0xFFDFDFDD),
          quoteBackground: const Color(0xFFDDDDDB),
          accent: const Color(0xFF55606B),
          link: const Color(0xFF405E9E),
        );
      case NovelReaderThemePreset.dark:
        return _dark(
          background: const Color(0xFF141414),
          foreground: const Color(0xFFE9E9E9),
          muted: const Color(0xFFAAA39A),
          surface: const Color(0xFF202020),
          quoteBackground: const Color(0xFF242424),
          accent: theme.colorScheme.primary,
          link: const Color(0xFF8DB7FF),
        );
      case NovelReaderThemePreset.charcoal:
        return _dark(
          background: const Color(0xFF2B2D2E),
          foreground: const Color(0xFFE2E2DF),
          muted: const Color(0xFF9B9B96),
          surface: const Color(0xFF343637),
          quoteBackground: const Color(0xFF363839),
          accent: const Color(0xFF8FB3D9),
          link: const Color(0xFF9CC1FF),
        );
      case NovelReaderThemePreset.ink:
        return _dark(
          background: const Color(0xFF000000),
          foreground: const Color(0xFFD6D6D3),
          muted: const Color(0xFF8A8A86),
          surface: const Color(0xFF121212),
          quoteBackground: const Color(0xFF121212),
          accent: const Color(0xFF8FB3D9),
          link: const Color(0xFF9CC1FF),
        );
    }
  }

  NovelReaderPalette _light({
    required Color background,
    required Color foreground,
    required Color muted,
    required Color surface,
    required Color quoteBackground,
    required Color accent,
    required Color link,
  }) {
    return NovelReaderPalette(
      brightness: Brightness.light,
      background: background,
      foreground: foreground,
      muted: muted,
      accent: accent,
      surface: surface,
      link: link,
      quoteBackground: quoteBackground,
      controlForeground: foreground,
      controlMuted: muted,
      backgroundTexture: NovelReaderBackgroundTexture.solid,
    );
  }

  NovelReaderPalette _dark({
    required Color background,
    required Color foreground,
    required Color muted,
    required Color surface,
    required Color quoteBackground,
    required Color accent,
    required Color link,
  }) {
    return NovelReaderPalette(
      brightness: Brightness.dark,
      background: background,
      foreground: foreground,
      muted: muted,
      accent: accent,
      surface: surface,
      link: link,
      quoteBackground: quoteBackground,
      controlForeground: foreground,
      controlMuted: muted,
      backgroundTexture: NovelReaderBackgroundTexture.solid,
    );
  }
}

class NovelReaderTypography {
  const NovelReaderTypography({
    required this.body,
    required this.chapterTitle,
    required this.quote,
    required this.link,
    required this.textAlign,
    required this.paragraphIndent,
    required this.contentMaxWidth,
  });

  final TextStyle body;
  final TextStyle chapterTitle;
  final TextStyle quote;
  final TextStyle link;
  final TextAlign textAlign;
  final NovelReaderParagraphIndentMode paragraphIndent;
  final double contentMaxWidth;
}

class NovelReaderTypographyResolver {
  const NovelReaderTypographyResolver();

  NovelReaderTypography resolve({
    required NovelReaderPreferences preferences,
    required ThemeData theme,
    required NovelReaderPalette palette,
    ResolvedFont? resolvedFont,
  }) {
    // Preferences store content identity. Only a completed runtime resolution
    // may provide a family name to the renderer or its measurement paths.
    final fontFamily = (resolvedFont ?? ResolvedFont.system).fontFamily;
    final body = TextStyle(
      color: palette.foreground,
      fontSize: preferences.fontSize,
      height: preferences.lineHeight,
      fontFamily: fontFamily,
      fontWeight: _resolveFontWeight(preferences.fontWeight),
    );
    return NovelReaderTypography(
      body: body,
      chapterTitle:
          theme.textTheme.headlineSmall?.copyWith(
            color: palette.foreground,
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ) ??
          TextStyle(
            color: palette.foreground,
            fontSize: preferences.fontSize + 4,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
      quote: body,
      link: body.copyWith(color: palette.link),
      textAlign: _resolveTextAlign(preferences.textAlign),
      paragraphIndent: preferences.paragraphIndent,
      contentMaxWidth: preferences.contentMaxWidth,
    );
  }

  TextAlign _resolveTextAlign(NovelReaderTextAlignMode mode) {
    switch (mode) {
      case NovelReaderTextAlignMode.justify:
        return TextAlign.justify;
      case NovelReaderTextAlignMode.center:
        return TextAlign.center;
      case NovelReaderTextAlignMode.start:
        return TextAlign.start;
    }
  }

  FontWeight _resolveFontWeight(int value) {
    switch (value) {
      case 500:
        return FontWeight.w500;
      case 700:
        return FontWeight.w700;
      case 400:
      default:
        return FontWeight.w400;
    }
  }
}
