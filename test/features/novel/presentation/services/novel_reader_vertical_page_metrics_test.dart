import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_vertical_page_metrics.dart';

void main() {
  test('a body that fits one viewport is one page', () {
    final metrics = NovelReaderVerticalPageMetrics.compute(
      bodyTop: 40,
      bodyHeight: 600,
      viewportTop: 0,
      viewportHeight: 800,
      lineHeight: 30,
      finalBoundaryKnown: true,
    );
    expect(metrics, isNotNull);
    expect(metrics!.currentPage, 1);
    expect(metrics.totalPages, 1);
    expect(metrics.remainingPages, 0);
    expect(metrics.progress, 1);
    expect(metrics.isEstimate, isFalse);
  });

  test('page units follow the tap step and stay bounded by the body end', () {
    NovelReaderVerticalPageMetrics atStart() =>
        NovelReaderVerticalPageMetrics.compute(
          bodyTop: 40,
          bodyHeight: 2040,
          viewportTop: 40,
          viewportHeight: 800,
          lineHeight: 30,
          finalBoundaryKnown: true,
        )!;
    NovelReaderVerticalPageMetrics atSecond() =>
        NovelReaderVerticalPageMetrics.compute(
          bodyTop: 40,
          bodyHeight: 2040,
          viewportTop: 780,
          viewportHeight: 800,
          lineHeight: 30,
          finalBoundaryKnown: true,
        )!;
    NovelReaderVerticalPageMetrics atEnd() =>
        NovelReaderVerticalPageMetrics.compute(
          bodyTop: 40,
          bodyHeight: 2040,
          viewportTop: 5000,
          viewportHeight: 800,
          lineHeight: 30,
          finalBoundaryKnown: true,
        )!;

    // step = 800 - 60 = 740; bodyRange = 1240; 2 pages.
    expect(atStart().currentPage, 1);
    expect(atStart().totalPages, 2);
    expect(atStart().remainingPages, 1);
    expect(atStart().progress, 0);
    expect(atSecond().currentPage, 2);
    expect(atSecond().remainingPages, 0);
    expect(atSecond().progress, closeTo(740 / 1240, 0.0001));
    expect(atEnd().currentPage, 2);
    expect(atEnd().remainingPages, 0);
    expect(atEnd().progress, 1);
  });

  test('a short viewport still advances by a whole viewport', () {
    final metrics = NovelReaderVerticalPageMetrics.compute(
      bodyTop: 0,
      bodyHeight: 2000,
      viewportTop: 0,
      viewportHeight: 50,
      lineHeight: 40,
      finalBoundaryKnown: false,
    )!;
    expect(metrics.totalPages, 39);
    expect(metrics.currentPage, 1);
    expect(metrics.isEstimate, isTrue);
  });

  test('invalid geometry produces no status', () {
    expect(
      NovelReaderVerticalPageMetrics.compute(
        bodyTop: 0,
        bodyHeight: 100,
        viewportTop: 0,
        viewportHeight: 0,
        lineHeight: 20,
        finalBoundaryKnown: true,
      ),
      isNull,
    );
    expect(
      NovelReaderVerticalPageMetrics.compute(
        bodyTop: -1,
        bodyHeight: 100,
        viewportTop: 0,
        viewportHeight: 100,
        lineHeight: 20,
        finalBoundaryKnown: true,
      ),
      isNull,
    );
  });
}
