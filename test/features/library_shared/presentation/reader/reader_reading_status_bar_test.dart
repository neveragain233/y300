import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_reading_status_bar.dart';

void main() {
  testWidgets(
    'standard bar is transparent and aligns three segments across full width',
    (tester) async {
      tester.view.physicalSize = const Size(520, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderReadingStatusBar(
                status: const ReaderReadingStatus(
                  leading: '第 371 / 451 章',
                  title: '雨夜归途',
                  trailing: '第 1 / 12 页',
                  semanticsLabel: '第 371 / 451 章，第 1 / 12 页',
                ),
                background: Colors.white,
                foreground: Colors.black54,
                progressForeground: Colors.black87,
                now: DateTime(2026, 1, 2, 13, 4),
              ),
            ),
          ),
        ),
      );

      final bar = tester.widget<Material>(
        find.byKey(const Key('shared-reader-persistent-status-bar')),
      );
      expect(bar.color, Colors.transparent);

      final leading = find.byKey(
        const Key('shared-reader-persistent-status-leading'),
      );
      final trailing = find.byKey(
        const Key('shared-reader-persistent-status-trailing'),
      );
      final time = find.byKey(
        const Key('shared-reader-persistent-status-time'),
      );
      final leadingText = tester.widget<Text>(
        find.descendant(of: leading, matching: find.byType(Text)),
      );
      final progressText = tester.widget<Text>(
        find.descendant(of: trailing, matching: find.byType(Text)),
      );

      expect(leadingText.data, '第 371 / 451 章 · 雨夜归途');
      expect(leadingText.style?.color, Colors.black54);
      expect(progressText.style?.fontWeight, FontWeight.w600);
      expect(progressText.style?.color, Colors.black87);
      expect(
        tester.getTopLeft(leading).dx,
        closeTo(ReaderReadingStatusBarLayout.eInkHorizontalPadding, 1),
      );
      expect(
        tester.getTopRight(time).dx,
        closeTo(520 - ReaderReadingStatusBarLayout.eInkHorizontalPadding, 1),
      );
      expect(
        tester.getTopRight(trailing).dx,
        lessThanOrEqualTo(tester.getTopLeft(time).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow standard bar drops title then time while keeping progress',
    (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderReadingStatusBar(
                status: const ReaderReadingStatus(
                  leading: '第 371 / 451 章',
                  title: '非常长的章节标题用于验证窄屏先截断或降级',
                  trailing: '本章 100% · 约剩 999 页',
                  semanticsLabel: '第 371 / 451 章，本章 100%',
                ),
                background: Colors.white,
                foreground: Colors.black,
                now: DateTime(2026, 1, 2, 13, 4),
              ),
            ),
          ),
        ),
      );

      final leadingText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('shared-reader-persistent-status-leading')),
          matching: find.byType(Text),
        ),
      );
      expect(leadingText.data, '第 371 / 451 章');
      expect(
        find.byKey(const Key('shared-reader-persistent-status-time')),
        findsNothing,
      );
      final trailing = find.byKey(
        const Key('shared-reader-persistent-status-trailing'),
      );
      expect(
        tester.getTopRight(trailing).dx,
        lessThanOrEqualTo(
          240 - ReaderReadingStatusBarLayout.eInkHorizontalPadding + 1,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
