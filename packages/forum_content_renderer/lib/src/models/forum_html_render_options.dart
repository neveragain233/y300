import '../html_rendering/theme/forum_html_color_adaptation_policy.dart';

/// Rendering values projected from Host preferences, without persistence or
/// text conversion policy.
final class ForumHtmlRenderOptions {
  const ForumHtmlRenderOptions({
    required this.fontScale,
    required this.lineHeightScale,
    required this.paragraphSpacing,
    required this.preserveAuthorFontSize,
    this.preserveAuthorFontFamily = true,
    this.enablePlainTextLinks = false,
    this.authorColorMode = ForumHtmlAuthorColorMode.preserve,
  });

  final double fontScale;
  final double lineHeightScale;
  final double paragraphSpacing;
  final bool preserveAuthorFontSize;

  /// False makes author face/font-family inherit the Host's selected body font.
  /// Size, weight, style and semantic code fonts keep their own policies.
  final bool preserveAuthorFontFamily;

  /// Display-only HTTP(S) linking. Readers using prepared HTML as semantic
  /// content keep the default to preserve their document and anchor identity.
  final bool enablePlainTextLinks;

  /// Reading-theme consumers such as the novel reader may own body color.
  final ForumHtmlAuthorColorMode authorColorMode;

  ForumHtmlRenderOptions copyWith({
    double? fontScale,
    double? lineHeightScale,
    double? paragraphSpacing,
    bool? preserveAuthorFontSize,
    bool? preserveAuthorFontFamily,
    bool? enablePlainTextLinks,
    ForumHtmlAuthorColorMode? authorColorMode,
  }) {
    return ForumHtmlRenderOptions(
      fontScale: fontScale ?? this.fontScale,
      lineHeightScale: lineHeightScale ?? this.lineHeightScale,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      preserveAuthorFontSize:
          preserveAuthorFontSize ?? this.preserveAuthorFontSize,
      preserveAuthorFontFamily:
          preserveAuthorFontFamily ?? this.preserveAuthorFontFamily,
      enablePlainTextLinks: enablePlainTextLinks ?? this.enablePlainTextLinks,
      authorColorMode: authorColorMode ?? this.authorColorMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ForumHtmlRenderOptions &&
        fontScale == other.fontScale &&
        lineHeightScale == other.lineHeightScale &&
        paragraphSpacing == other.paragraphSpacing &&
        preserveAuthorFontSize == other.preserveAuthorFontSize &&
        preserveAuthorFontFamily == other.preserveAuthorFontFamily &&
        enablePlainTextLinks == other.enablePlainTextLinks &&
        authorColorMode == other.authorColorMode;
  }

  @override
  int get hashCode => Object.hash(
    fontScale,
    lineHeightScale,
    paragraphSpacing,
    preserveAuthorFontSize,
    preserveAuthorFontFamily,
    enablePlainTextLinks,
    authorColorMode,
  );
}
