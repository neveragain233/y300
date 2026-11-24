import 'package:flutter/painting.dart';

/// Synchronizes `fontVariations['wght']` with semantic/CSS bold and weight
/// overrides so explicit variable weights never flatten emphasis.
abstract final class ForumHtmlVariableWeightPolicy {
  static const String weightAxisTag = 'wght';
  static const double relativeBoldDelta = 250.0;

  static final Expando<({double min, double max})> _axisBounds =
      Expando<({double min, double max})>('forumHtmlVariableWeightBounds');

  static List<FontVariation>? bindAxisBounds(
    List<FontVariation>? variations, {
    required double min,
    required double max,
  }) {
    if (variations == null || variations.isEmpty) {
      return variations;
    }
    final list = List<FontVariation>.unmodifiable(variations);
    _axisBounds[list] = (min: min, max: max);
    return list;
  }

  static ({double min, double max}) axisBoundsOf(
    List<FontVariation>? variations,
  ) {
    if (variations != null) {
      final bounds = _axisBounds[variations];
      if (bounds != null) {
        return bounds;
      }
    }
    return const (min: 1.0, max: 1000.0);
  }

  static double? wghtOf(TextStyle style) {
    final variations = style.fontVariations;
    if (variations == null || variations.isEmpty) {
      return null;
    }
    for (final variation in variations) {
      if (variation.axis == weightAxisTag) {
        return variation.value;
      }
    }
    return null;
  }

  static FontWeight nearestDiscreteWeight(double weight) {
    final index = ((weight.clamp(100.0, 900.0) / 100.0).round() - 1).clamp(
      0,
      8,
    );
    return FontWeight.values[index];
  }

  static TextStyle applyRelativeBold(TextStyle style) {
    final current = wghtOf(style);
    if (current == null) {
      return style.copyWith(fontWeight: FontWeight.w700);
    }
    final bounds = axisBoundsOf(style.fontVariations);
    final next = (current + relativeBoldDelta)
        .clamp(bounds.min, bounds.max)
        .toDouble();
    return style.copyWith(
      fontWeight: FontWeight.w700,
      fontVariations: _replaceWght(style.fontVariations!, next, bounds: bounds),
    );
  }

  static TextStyle applyRelativeLighter(TextStyle style) {
    final current = wghtOf(style);
    if (current == null) {
      return style.copyWith(fontWeight: FontWeight.w300);
    }
    final bounds = axisBoundsOf(style.fontVariations);
    final next = (current - relativeBoldDelta)
        .clamp(bounds.min, bounds.max)
        .toDouble();
    return style.copyWith(
      fontWeight: FontWeight.w300,
      fontVariations: _replaceWght(style.fontVariations!, next, bounds: bounds),
    );
  }

  static TextStyle applyExplicitWeight(TextStyle style, double weight) {
    final discrete = nearestDiscreteWeight(weight);
    final current = wghtOf(style);
    if (current == null) {
      return style.copyWith(fontWeight: discrete);
    }
    final bounds = axisBoundsOf(style.fontVariations);
    final next = weight.clamp(bounds.min, bounds.max).toDouble();
    return style.copyWith(
      fontWeight: discrete,
      fontVariations: _replaceWght(style.fontVariations!, next, bounds: bounds),
    );
  }

  static TextStyle clearWeightVariation(TextStyle style) {
    final current = style.fontVariations;
    if (current == null || current.isEmpty) {
      return style;
    }
    final kept = current
        .where((variation) => variation.axis != weightAxisTag)
        .toList(growable: false);
    if (kept.length == current.length) {
      return style;
    }
    return style.copyWith(
      fontVariations: List<FontVariation>.unmodifiable(kept),
    );
  }

  static List<FontVariation> _replaceWght(
    List<FontVariation> source,
    double nextWeight, {
    required ({double min, double max}) bounds,
  }) {
    final updated = List<FontVariation>.unmodifiable(<FontVariation>[
      for (final variation in source)
        variation.axis == weightAxisTag
            ? FontVariation(weightAxisTag, nextWeight)
            : variation,
    ]);
    _axisBounds[updated] = bounds;
    return updated;
  }
}
