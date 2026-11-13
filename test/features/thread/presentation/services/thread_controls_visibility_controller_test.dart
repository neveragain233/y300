import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/presentation/services/thread_controls_visibility_controller.dart';

void main() {
  testWidgets(
    'only opted-in user scrolling hides controls and explicit navigation restores them',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final context = tester.element(find.byType(SizedBox).first);
      final visibility = ThreadControlsVisibilityController();
      addTearDown(visibility.dispose);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 300,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      void direction(ScrollDirection direction) => visibility.handle(
        UserScrollNotification(
          metrics: metrics,
          context: context,
          direction: direction,
        ),
        enabled: true,
      );
      void scroll(double delta, {bool enabled = true}) => visibility.handle(
        ScrollUpdateNotification(
          metrics: metrics,
          context: context,
          scrollDelta: delta,
        ),
        enabled: enabled,
      );
      direction(ScrollDirection.reverse);
      scroll(40, enabled: false);
      expect(visibility.value, isTrue);
      direction(ScrollDirection.reverse);
      scroll(10);
      expect(visibility.value, isTrue);
      scroll(24);
      expect(visibility.value, isFalse);
      direction(ScrollDirection.forward);
      scroll(-12);
      expect(visibility.value, isTrue);
      direction(ScrollDirection.reverse);
      scroll(40);
      expect(visibility.value, isFalse);
      visibility.reset();
      scroll(100);
      expect(visibility.value, isTrue);
    },
  );
}
