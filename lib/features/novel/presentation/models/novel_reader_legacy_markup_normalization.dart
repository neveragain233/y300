import 'package:flutter/foundation.dart';

enum NovelReaderLegacyMarkupNormalizationReason {
  emptyFontFace,
  invalidQuoteOnlyFontFace,
  invalidNoUsableFontFamilyToken,

  /// 紧挨块级元素的 `<br>` 在渲染器里不会产生额外行，测量前移除。
  blockAdjacentLineBreak,

  /// 块级元素嵌在行内格式元素内时，把行内格式移入块级元素。
  inlineFormattingBlockSplit,

  /// 只承载块级子元素的布局 `div` 展开，保留子元素本身。
  structuralWrapperUnwrapped,
}

@immutable
final class NovelReaderLegacyMarkupNormalizationSummary {
  const NovelReaderLegacyMarkupNormalizationSummary({
    required this.revision,
    required this.normalizedAttributeCount,
    this.reasonCounts =
        const <NovelReaderLegacyMarkupNormalizationReason, int>{},
  });

  static const none = NovelReaderLegacyMarkupNormalizationSummary(
    revision: 0,
    normalizedAttributeCount: 0,
  );

  final int revision;
  final int normalizedAttributeCount;
  final Map<NovelReaderLegacyMarkupNormalizationReason, int> reasonCounts;

  bool get changed => normalizedAttributeCount > 0;
}

@immutable
final class NovelReaderLegacyMarkupNormalizationResult {
  const NovelReaderLegacyMarkupNormalizationResult({
    required this.html,
    required this.summary,
  });

  final String html;
  final NovelReaderLegacyMarkupNormalizationSummary summary;
}
