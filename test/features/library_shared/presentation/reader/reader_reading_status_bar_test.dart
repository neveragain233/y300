import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_reading_status_bar.dart';

void main() {
  testWidgets('chapter stays left and the page label hugs the right edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ReaderReadingStatusBar(
              status: ReaderReadingStatus(
                leading: '第 371 / 451 章',
                trailing: '第 1 / 12 页',
                semanticsLabel: '第 371 / 451 章，第 1 / 12 页',
              ),
              background: Colors.white,
              foreground: Colors.black,
            ),
          ),
        ),
      ),
    );

    final leading = find.byKey(
      const Key('shared-reader-persistent-status-leading'),
    );
    final trailing = find.byKey(
      const Key('shared-reader-persistent-status-trailing'),
    );
    expect(tester.getTopLeft(leading).dx, closeTo(12, 1));
    expect(
      tester.getTopRight(trailing).dx,
      closeTo(400 - ReaderReadingStatusBarLayout.horizontalPadding, 1),
      reason: '右侧文字必须贴住右边缘，而不是落在屏宽中部。',
    );
    expect(tester.getCenter(trailing).dx, greaterThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels on a narrow bar stay inside the right edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ReaderReadingStatusBar(
              status: ReaderReadingStatus(
                leading: '第 371 / 451 章',
                trailing: '本章 100% · 约剩 999 页',
                semanticsLabel: '第 371 / 451 章，本章 100%',
              ),
              background: Colors.white,
              foreground: Colors.black,
            ),
          ),
        ),
      ),
    );

    final trailing = find.byKey(
      const Key('shared-reader-persistent-status-trailing'),
    );
    expect(
      tester.getTopRight(trailing).dx,
      closeTo(280 - ReaderReadingStatusBarLayout.horizontalPadding, 1),
    );
    expect(tester.takeException(), isNull);
  });
}
