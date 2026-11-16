import 'dart:ui';

/// WCAG 2 relative-luminance contrast helpers shared by reader and cover tones.
abstract final class WcagColorContrast {
  static const double minimumBodyTextContrast = 4.5;

  /// WCAG relative-luminance contrast ratio between two opaque colors.
  static double ratio(Color first, Color second) {
    final a = first.computeLuminance();
    final b = second.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Blends [source] toward [target] by [amount], stopping before the result
  /// falls below [minimumContrast] against [target].
  static Color blendWhileReadable({
    required Color source,
    required Color target,
    required double amount,
    double minimumContrast = minimumBodyTextContrast,
  }) {
    if (amount <= 0 || ratio(source, target) < minimumContrast) {
      return source;
    }
    final clamped = amount.clamp(0.0, 1.0);
    final direct = Color.lerp(source, target, clamped)!;
    if (ratio(direct, target) >= minimumContrast) {
      return direct;
    }
    var low = 0.0;
    var high = clamped;
    for (var step = 0; step < 12; step += 1) {
      final middle = (low + high) / 2;
      final candidate = Color.lerp(source, target, middle)!;
      if (ratio(candidate, target) >= minimumContrast) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return Color.lerp(source, target, low)!;
  }
}
