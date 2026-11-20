import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';
import 'package:y300/core/eink/eink_paging_router.dart';

class _RecordingRipple implements EInkPageRippleService {
  final List<bool> forwards = <bool>[];

  @override
  Future<bool> triggerPageRipple({
    required bool forward,
    required EInkRippleSpeed speed,
  }) async {
    forwards.add(forward);
    return true;
  }
}

Widget _scrollable(ScrollController controller, {double contentHeight = 2000}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        controller: controller,
        children: [SizedBox(height: contentHeight)],
      ),
    ),
  );
}

void main() {
  testWidgets('tracks bounds and notifies only when they change', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = EInkScrollPageHandler(
      controller,
      ripple: const NoopEInkPageRippleService(),
    );
    addTearDown(handler.dispose);
    var notifications = 0;
    handler.addListener(() => notifications += 1);

    // 控制器尚未挂到滚动视图时没有可翻方向。
    expect(handler.canPageUp, isFalse);
    expect(handler.canPageDown, isFalse);

    await tester.pumpWidget(_scrollable(controller));
    handler.refreshBounds();
    expect(handler.canPageUp, isFalse);
    expect(handler.canPageDown, isTrue);
    expect(notifications, 1);

    controller.jumpTo(200);
    await tester.pump();
    expect(handler.canPageUp, isTrue);
    expect(handler.canPageDown, isTrue);
    expect(notifications, 2);

    controller.jumpTo(260);
    await tester.pump();
    expect(notifications, 2);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(handler.canPageUp, isTrue);
    expect(handler.canPageDown, isFalse);
    expect(notifications, 3);
  });

  testWidgets('pages by 85 percent of the viewport and clamps at ends', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final ripple = _RecordingRipple();
    final handler = EInkScrollPageHandler(controller, ripple: ripple);
    addTearDown(handler.dispose);

    await tester.pumpWidget(_scrollable(controller));
    handler.refreshBounds();

    handler.pageDown();
    await tester.pump();
    expect(controller.offset, closeTo(510, 0.5));
    expect(ripple.forwards, [true]);

    handler.pageUp();
    await tester.pump();
    expect(controller.offset, 0);
    expect(ripple.forwards, [true, false]);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    handler.pageDown();
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(ripple.forwards, hasLength(2));
  });

  testWidgets('re-attaches the listener when the controller is replaced', (
    tester,
  ) async {
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final handler = EInkScrollPageHandler(
      first,
      ripple: const NoopEInkPageRippleService(),
    );
    addTearDown(handler.dispose);

    await tester.pumpWidget(_scrollable(first));
    handler.refreshBounds();
    expect(handler.canPageDown, isTrue);

    await tester.pumpWidget(_scrollable(second));
    handler.controller = second;
    await tester.pump();

    expect(first.hasClients, isFalse);
    expect(handler.canPageDown, isTrue);

    second.jumpTo(200);
    await tester.pump();
    expect(handler.canPageUp, isTrue);

    handler.pageDown();
    await tester.pump();
    expect(second.offset, closeTo(710, 0.5));
    expect(first.hasClients, isFalse);
  });

  testWidgets(
    'reports no direction when several positions share a controller',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final handler = EInkScrollPageHandler(
        controller,
        ripple: const NoopEInkPageRippleService(),
      );
      addTearDown(handler.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 300,
                  child: ListView(
                    controller: controller,
                    children: const [SizedBox(height: 1000)],
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: ListView(
                    controller: controller,
                    children: const [SizedBox(height: 1000)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      handler.refreshBounds();

      expect(handler.canPageUp, isFalse);
      expect(handler.canPageDown, isFalse);
    },
  );

  testWidgets('stops listening after dispose', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = EInkScrollPageHandler(
      controller,
      ripple: const NoopEInkPageRippleService(),
    );

    await tester.pumpWidget(_scrollable(controller));
    handler.refreshBounds();
    expect(handler.canPageDown, isTrue);

    handler.dispose();
    controller.jumpTo(200);
    await tester.pump();

    // dispose 后刷新是安全的空操作，不会再读取控制器。
    handler.refreshBounds();
    expect(handler.canPageDown, isTrue);
  });
}
