import 'dart:math' as math;

/// One tap-turn page unit for the scrolling reader.
///
/// Vertical reading has no measured pagination. The footer therefore treats
/// one tap step as one page so the displayed counter advances exactly when the
/// reader taps forward. The value is presentation-only and must never be used
/// for progress persistence or chapter completion.
final class NovelReaderVerticalPageMetrics {
  const NovelReaderVerticalPageMetrics({
    required this.currentPage,
    required this.totalPages,
    required this.remainingPages,
    required this.progress,
    required this.isEstimate,
  });

  final int currentPage;
  final int totalPages;
  final int remainingPages;

  /// Body-range progress in `0..1`, matching the persisted vertical percent.
  final double progress;

  /// True while the body's final boundary has not been laid out, so total page
  /// count and remaining pages are estimates.
  final bool isEstimate;

  static NovelReaderVerticalPageMetrics? compute({
    required double bodyTop,
    required double bodyHeight,
    required double viewportTop,
    required double viewportHeight,
    required double lineHeight,
    required bool finalBoundaryKnown,
  }) {
    if (!bodyTop.isFinite ||
        !bodyHeight.isFinite ||
        !viewportTop.isFinite ||
        !viewportHeight.isFinite ||
        bodyTop < 0 ||
        bodyHeight < 0 ||
        viewportHeight <= 0) {
      return null;
    }
    final safeLineHeight = lineHeight.isFinite && lineHeight > 0
        ? lineHeight
        : 1.0;
    final bodyRange = math.max(0.0, bodyHeight - viewportHeight);
    final distance = (viewportTop - bodyTop).clamp(0.0, bodyRange).toDouble();
    final step = _pageStep(viewportHeight, safeLineHeight);
    final totalPages = math.max(1, (bodyRange / step).ceil());
    final currentPage = math.min(totalPages, (distance / step).floor() + 1);
    final progress = bodyRange <= 0
        ? 1.0
        : (distance / bodyRange).clamp(0.0, 1.0).toDouble();
    return NovelReaderVerticalPageMetrics(
      currentPage: currentPage,
      totalPages: totalPages,
      remainingPages: totalPages - currentPage,
      progress: progress,
      isEstimate: !finalBoundaryKnown,
    );
  }

  /// Matches the actual tap-turn step: about one viewport with two lines kept
  /// as overlap. A degenerate viewport still advances by at least one pixel.
  static double _pageStep(double viewportHeight, double lineHeight) {
    final step = viewportHeight - lineHeight * 2;
    if (step >= 1) return step;
    return math.max(1.0, viewportHeight);
  }

  @override
  bool operator ==(Object other) {
    return other is NovelReaderVerticalPageMetrics &&
        other.currentPage == currentPage &&
        other.totalPages == totalPages &&
        other.remainingPages == remainingPages &&
        other.progress == progress &&
        other.isEstimate == isEstimate;
  }

  @override
  int get hashCode => Object.hash(
    currentPage,
    totalPages,
    remainingPages,
    progress,
    isEstimate,
  );
}
