import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/eink_scroll_pager.dart';

void main() {
  testWidgets('adds edge tap layers only when enabled', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EInkScrollPager(
            controller: controller,
            enabled: true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('eink-edge-tap-previous')), findsOneWidget);
    expect(find.byKey(const Key('eink-edge-tap-next')), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EInkScrollPager(
            controller: controller,
            enabled: false,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('eink-edge-tap-previous')), findsNothing);
  });
}
