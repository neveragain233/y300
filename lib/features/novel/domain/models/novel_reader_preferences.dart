import 'package:y300/features/novel/domain/models/novel_reader_spacing.dart';

enum NovelReaderThemePreset {
  followApp,
  light,
  paperWhite,
  cream,
  sepia,
  sage,
  gray,
  dark,
  charcoal,
  ink,
}

enum NovelReaderFlowMode { vertical, pagedLtr, pagedRtl }

/// Names are stable schema-1 snapshot tokens, independent of reading direction.
enum NovelReaderPageEffect { slide, paper, fade, cover, staggered }

enum NovelReaderPageSpeed {
  relaxed(1.35),
  standard(1),
  brisk(0.7);

  const NovelReaderPageSpeed(this.durationScale);
  final double durationScale;
}

enum NovelReaderTextAlignMode { start, justify, center }

/// Who owns ordinary body color inside a novel chapter.
enum NovelReaderBodyColorMode {
  /// The reading palette replaces author foregrounds and decorative
  /// backgrounds; concealment, structure and link targets stay intact.
  followReadingTheme,

  /// Author colors remain, with the existing readability adaptation.
  preserveAuthorColors,
}

/// Independent background material drawn beneath novel body text.
enum NovelReaderBackgroundTexture { solid, paper, grain }

/// First-line indentation of ordinary body paragraphs.
enum NovelReaderParagraphIndentMode { increase, keep, remove }

/// Traditional/simplified conversion direction for the novel reader.
enum NovelReaderConversionMode { none, toSimplified, toTraditional }

extension NovelReaderConversionModeCodec on NovelReaderConversionMode {
  String get storageValue {
    switch (this) {
      case NovelReaderConversionMode.none:
        return 'none';
      case NovelReaderConversionMode.toSimplified:
        return 'toSimplified';
      case NovelReaderConversionMode.toTraditional:
        return 'toTraditional';
    }
  }

  static NovelReaderConversionMode fromStorage(String? value) {
    switch (value) {
      case 'toSimplified':
        return NovelReaderConversionMode.toSimplified;
      case 'toTraditional':
        return NovelReaderConversionMode.toTraditional;
      case 'none':
      default:
        return NovelReaderConversionMode.none;
    }
  }
}

extension NovelReaderThemePresetCodec on NovelReaderThemePreset {
  String get storageValue {
    switch (this) {
      case NovelReaderThemePreset.followApp:
        return 'followApp';
      case NovelReaderThemePreset.light:
        return 'light';
      case NovelReaderThemePreset.paperWhite:
        return 'paperWhite';
      case NovelReaderThemePreset.cream:
        return 'cream';
      case NovelReaderThemePreset.sepia:
        return 'sepia';
      case NovelReaderThemePreset.sage:
        return 'sage';
      case NovelReaderThemePreset.gray:
        return 'gray';
      case NovelReaderThemePreset.dark:
        return 'dark';
      case NovelReaderThemePreset.charcoal:
        return 'charcoal';
      case NovelReaderThemePreset.ink:
        return 'ink';
    }
  }

  static NovelReaderThemePreset fromStorage(String? value) {
    switch (value) {
      case 'followApp':
      case 'followSystem':
      case 'follow_system':
      case 'system':
        return NovelReaderThemePreset.followApp;
      case 'light':
        return NovelReaderThemePreset.light;
      case 'paperWhite':
        return NovelReaderThemePreset.paperWhite;
      case 'cream':
        return NovelReaderThemePreset.cream;
      case 'sepia':
        return NovelReaderThemePreset.sepia;
      case 'sage':
        return NovelReaderThemePreset.sage;
      case 'gray':
        return NovelReaderThemePreset.gray;
      case 'dark':
        return NovelReaderThemePreset.dark;
      case 'charcoal':
        return NovelReaderThemePreset.charcoal;
      case 'ink':
        return NovelReaderThemePreset.ink;
      default:
        return NovelReaderThemePreset.followApp;
    }
  }
}

extension NovelReaderBodyColorModeCodec on NovelReaderBodyColorMode {
  String get storageValue {
    switch (this) {
      case NovelReaderBodyColorMode.followReadingTheme:
        return 'followReadingTheme';
      case NovelReaderBodyColorMode.preserveAuthorColors:
        return 'preserveAuthorColors';
    }
  }

  static NovelReaderBodyColorMode fromStorage(String? value) {
    return value == 'preserveAuthorColors'
        ? NovelReaderBodyColorMode.preserveAuthorColors
        : NovelReaderBodyColorMode.followReadingTheme;
  }
}

extension NovelReaderBackgroundTextureCodec on NovelReaderBackgroundTexture {
  String get storageValue {
    switch (this) {
      case NovelReaderBackgroundTexture.solid:
        return 'solid';
      case NovelReaderBackgroundTexture.paper:
        return 'paper';
      case NovelReaderBackgroundTexture.grain:
        return 'grain';
    }
  }

  static NovelReaderBackgroundTexture fromStorage(String? value) {
    switch (value) {
      case 'paper':
        return NovelReaderBackgroundTexture.paper;
      case 'grain':
        return NovelReaderBackgroundTexture.grain;
      case 'solid':
      default:
        return NovelReaderBackgroundTexture.solid;
    }
  }
}

extension NovelReaderParagraphIndentModeCodec
    on NovelReaderParagraphIndentMode {
  String get storageValue {
    switch (this) {
      case NovelReaderParagraphIndentMode.increase:
        return 'increase';
      case NovelReaderParagraphIndentMode.keep:
        return 'keep';
      case NovelReaderParagraphIndentMode.remove:
        return 'remove';
    }
  }

  static NovelReaderParagraphIndentMode fromStorage(String? value) {
    switch (value) {
      case 'increase':
        return NovelReaderParagraphIndentMode.increase;
      case 'remove':
        return NovelReaderParagraphIndentMode.remove;
      case 'keep':
      default:
        return NovelReaderParagraphIndentMode.keep;
    }
  }
}

extension NovelReaderFlowModeCodec on NovelReaderFlowMode {
  String get storageValue {
    switch (this) {
      case NovelReaderFlowMode.vertical:
        return 'vertical';
      case NovelReaderFlowMode.pagedLtr:
        return 'pagedLtr';
      case NovelReaderFlowMode.pagedRtl:
        return 'pagedRtl';
    }
  }

  static NovelReaderFlowMode fromStorage(
    String? value, {
    NovelReaderFlowMode fallback = NovelReaderFlowMode.vertical,
  }) {
    switch (value) {
      case 'pagedLtr':
      case 'paged_ltr':
        return NovelReaderFlowMode.pagedLtr;
      case 'pagedRtl':
      case 'paged_rtl':
        return NovelReaderFlowMode.pagedRtl;
      case 'vertical':
        return NovelReaderFlowMode.vertical;
      default:
        return fallback;
    }
  }
}

extension NovelReaderTextAlignModeCodec on NovelReaderTextAlignMode {
  String get storageValue {
    switch (this) {
      case NovelReaderTextAlignMode.start:
        return 'start';
      case NovelReaderTextAlignMode.justify:
        return 'justify';
      case NovelReaderTextAlignMode.center:
        return 'center';
    }
  }

  static NovelReaderTextAlignMode fromStorage(String? value) {
    switch (value) {
      case 'justify':
        return NovelReaderTextAlignMode.justify;
      case 'center':
        return NovelReaderTextAlignMode.center;
      case 'start':
      default:
        return NovelReaderTextAlignMode.start;
    }
  }
}

class NovelReaderPreferences {
  NovelReaderPreferences({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.pagePadding,
    required this.fontFamily,
    this.flowMode = NovelReaderFlowMode.pagedLtr,
    this.pageEffect = NovelReaderPageEffect.slide,
    this.pageSpeed = NovelReaderPageSpeed.standard,
    NovelReaderThemePreset themePreset = NovelReaderThemePreset.followApp,
    this.contentMaxWidth = 720,
    this.paragraphIndent = NovelReaderParagraphIndentMode.keep,
    this.fontWeight = 400,
    this.textAlign = NovelReaderTextAlignMode.start,
    this.showProgressIndicator = true,
    this.conversionMode = NovelReaderConversionMode.none,
    this.safeAreaEnabled = true,
    this.bodyBrightness = 1,
    this.backgroundTexture = NovelReaderBackgroundTexture.solid,
    this.bodyColorMode = NovelReaderBodyColorMode.followReadingTheme,
    String? themeMode,
  }) : themePreset = themeMode == null
           ? themePreset
           : NovelReaderThemePresetCodec.fromStorage(themeMode);

  const NovelReaderPreferences._({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.pagePadding,
    required this.fontFamily,
    required this.flowMode,
    required this.pageEffect,
    required this.pageSpeed,
    required this.themePreset,
    required this.contentMaxWidth,
    required this.paragraphIndent,
    required this.fontWeight,
    required this.textAlign,
    required this.showProgressIndicator,
    required this.conversionMode,
    required this.safeAreaEnabled,
    required this.bodyBrightness,
    required this.backgroundTexture,
    required this.bodyColorMode,
  });

  factory NovelReaderPreferences.defaults() {
    return const NovelReaderPreferences._(
      fontSize: 18.5,
      lineHeight: 1.6,
      paragraphSpacing: 10,
      pagePadding: NovelReaderSpacing.pagedPagePadding,
      fontFamily: 'system',
      flowMode: NovelReaderFlowMode.pagedLtr,
      pageEffect: NovelReaderPageEffect.slide,
      pageSpeed: NovelReaderPageSpeed.standard,
      themePreset: NovelReaderThemePreset.followApp,
      contentMaxWidth: 720,
      paragraphIndent: NovelReaderParagraphIndentMode.keep,
      fontWeight: 400,
      textAlign: NovelReaderTextAlignMode.start,
      showProgressIndicator: true,
      conversionMode: NovelReaderConversionMode.none,
      safeAreaEnabled: true,
      bodyBrightness: 1,
      backgroundTexture: NovelReaderBackgroundTexture.solid,
      bodyColorMode: NovelReaderBodyColorMode.followReadingTheme,
    );
  }

  /// Bounds for the independent body-text brightness slider.
  static const double minimumBodyBrightness = 0.55;
  static const double maximumBodyBrightness = 1;

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double pagePadding;

  /// Persisted choice: `system` or a font content ID, never an engine family.
  final String fontFamily;
  final NovelReaderFlowMode flowMode;
  final NovelReaderPageEffect pageEffect;
  final NovelReaderPageSpeed pageSpeed;
  final NovelReaderThemePreset themePreset;
  final double contentMaxWidth;
  final NovelReaderParagraphIndentMode paragraphIndent;
  final int fontWeight;
  final NovelReaderTextAlignMode textAlign;
  final bool showProgressIndicator;
  final NovelReaderConversionMode conversionMode;
  final bool safeAreaEnabled;

  /// Scales body text tone only; reader controls keep their own palette.
  final double bodyBrightness;
  final NovelReaderBackgroundTexture backgroundTexture;
  final NovelReaderBodyColorMode bodyColorMode;

  String get themeMode => themePreset.storageValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NovelReaderPreferences &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.paragraphSpacing == paragraphSpacing &&
        other.pagePadding == pagePadding &&
        other.fontFamily == fontFamily &&
        other.flowMode == flowMode &&
        other.pageEffect == pageEffect &&
        other.pageSpeed == pageSpeed &&
        other.themePreset == themePreset &&
        other.contentMaxWidth == contentMaxWidth &&
        other.paragraphIndent == paragraphIndent &&
        other.fontWeight == fontWeight &&
        other.textAlign == textAlign &&
        other.showProgressIndicator == showProgressIndicator &&
        other.conversionMode == conversionMode &&
        other.safeAreaEnabled == safeAreaEnabled &&
        other.bodyBrightness == bodyBrightness &&
        other.backgroundTexture == backgroundTexture &&
        other.bodyColorMode == bodyColorMode;
  }

  @override
  int get hashCode => Object.hash(
    fontSize,
    lineHeight,
    paragraphSpacing,
    pagePadding,
    fontFamily,
    flowMode,
    pageEffect,
    pageSpeed,
    themePreset,
    contentMaxWidth,
    paragraphIndent,
    fontWeight,
    textAlign,
    showProgressIndicator,
    conversionMode,
    safeAreaEnabled,
    bodyBrightness,
    backgroundTexture,
    bodyColorMode,
  );

  NovelReaderPreferences copyWith({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? pagePadding,
    String? themeMode,
    String? fontFamily,
    NovelReaderFlowMode? flowMode,
    NovelReaderPageEffect? pageEffect,
    NovelReaderPageSpeed? pageSpeed,
    NovelReaderThemePreset? themePreset,
    double? contentMaxWidth,
    NovelReaderParagraphIndentMode? paragraphIndent,
    int? fontWeight,
    NovelReaderTextAlignMode? textAlign,
    bool? showProgressIndicator,
    NovelReaderConversionMode? conversionMode,
    bool? safeAreaEnabled,
    double? bodyBrightness,
    NovelReaderBackgroundTexture? backgroundTexture,
    NovelReaderBodyColorMode? bodyColorMode,
  }) {
    return NovelReaderPreferences._(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      pagePadding: pagePadding ?? this.pagePadding,
      fontFamily: fontFamily ?? this.fontFamily,
      flowMode: flowMode ?? this.flowMode,
      pageEffect: pageEffect ?? this.pageEffect,
      pageSpeed: pageSpeed ?? this.pageSpeed,
      themePreset: themeMode == null
          ? (themePreset ?? this.themePreset)
          : NovelReaderThemePresetCodec.fromStorage(themeMode),
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      showProgressIndicator:
          showProgressIndicator ?? this.showProgressIndicator,
      conversionMode: conversionMode ?? this.conversionMode,
      safeAreaEnabled: safeAreaEnabled ?? this.safeAreaEnabled,
      bodyBrightness: bodyBrightness ?? this.bodyBrightness,
      backgroundTexture: backgroundTexture ?? this.backgroundTexture,
      bodyColorMode: bodyColorMode ?? this.bodyColorMode,
    );
  }
}
