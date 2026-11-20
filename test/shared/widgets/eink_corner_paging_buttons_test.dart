import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';
import 'package:y300/core/eink/eink_paging_router.dart';
import 'package:y300/shared/widgets/eink_corner_paging_buttons.dart';

const _upKey = Key('eink-corner-page-up');
const _downKey = Key('eink-corner-page-down');

Future<void> _pumpCorner(
  WidgetTester tester, {
  required ScrollController controller,
  required EInkScrollPageHandler handler,
  double contentHeight = 2000,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Stack(
          children: [
            ListView(
              controller: controller,
              children: [SizedBox(height: contentHeight)],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: EInkCornerPagingButtons(handler: handler),
            ),
          ],
        ),
      ),
    ),
  );
  handler.refreshBounds();
  await tester.pump();
}

EInkScrollPageHandler _createHandler(ScrollController controller) {
  return EInkScrollPageHandler(
    controller,
    ripple: const NoopEInkPageRippleService(),
  );
}

void main() {
  testWidgets('uses a 48dp hit area around a 36dp square', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = _createHandler(controller);
    addTearDown(handler.dispose);

    await _pumpCorner(tester, controller: controller, handler: handler);
    controller.jumpTo(200);
    await tester.pump();

    expect(find.byKey(_upKey), findsOneWidget);
    expect(find.byKey(_downKey), findsOneWidget);
    expect(tester.getSize(find.byKey(_upKey)), const Size(48, 48));
    expect(tester.getSize(find.byKey(_downKey)), const Size(48, 48));

    final visual = find.descendant(
      of: find.byKey(_upKey),
      matching: find.byType(Container),
    );
    expect(tester.getSize(visual), const Size(36, 36));
    expect(
      tester.getTopLeft(find.byKey(_upKey)).dy,
      lessThan(tester.getTopLeft(find.byKey(_downKey)).dy),
    );
  });

  testWidgets('taps page in both directions', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = _createHandler(controller);
    addTearDown(handler.dispose);

    await _pumpCorner(tester, controller: controller, handler: handler);
    controller.jumpTo(200);
    await tester.pump();

    await tester.tap(find.byKey(_downKey));
    await tester.pump();
    expect(controller.offset, greaterThan(200));

    final afterDown = controller.offset;
    await tester.tap(find.byKey(_upKey));
    await tester.pump();
    expect(controller.offset, lessThan(afterDown));
  });

  testWidgets('disables the direction that cannot page with muted colors', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = _createHandler(controller);
    addTearDown(handler.dispose);

    await _pumpCorner(tester, controller: controller, handler: handler);

    expect(tester.widget<GestureDetector>(find.byKey(_upKey)).onTap, isNull);
    expect(
      tester.widget<GestureDetector>(find.byKey(_downKey)).onTap,
      isNotNull,
    );

    final upIcon = tester.widget<Icon>(
      find.descendant(of: find.byKey(_upKey), matching: find.byType(Icon)),
    );
    expect(upIcon.color, const Color(0xFFA0A0A0));
    final upDecoration = _decorationOf(tester, _upKey);
    expect((upDecoration.border! as Border).top.color, const Color(0xFFE0E0E0));

    final downIcon = tester.widget<Icon>(
      find.descendant(of: find.byKey(_downKey), matching: find.byType(Icon)),
    );
    expect(downIcon.color, const Color(0xFF222222));
    final downDecoration = _decorationOf(tester, _downKey);
    expect(downDecoration.color, const Color(0xFFFFFFFF));
    expect(
      (downDecoration.border! as Border).top.color,
      const Color(0xFFCCCCCC),
    );
  });

  testWidgets('uses dark tokens under a dark theme', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = _createHandler(controller);
    addTearDown(handler.dispose);

    await _pumpCorner(
      tester,
      controller: controller,
      handler: handler,
      brightness: Brightness.dark,
    );

    final disabledIcon = tester.widget<Icon>(
      find.descendant(of: find.byKey(_upKey), matching: find.byType(Icon)),
    );
    expect(disabledIcon.color, const Color(0xFF5A5A5A));
    final disabledDecoration = _decorationOf(tester, _upKey);
    expect(
      (disabledDecoration.border! as Border).top.color,
      const Color(0xFF2E2E2E),
    );

    final enabledIcon = tester.widget<Icon>(
      find.descendant(of: find.byKey(_downKey), matching: find.byType(Icon)),
    );
    expect(enabledIcon.color, const Color(0xFFEAEAEA));
    final enabledDecoration = _decorationOf(tester, _downKey);
    expect(enabledDecoration.color, const Color(0xFF141414));
    expect(
      (enabledDecoration.border! as Border).top.color,
      const Color(0xFF555555),
    );
  });

  testWidgets('renders nothing when neither direction can page', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final handler = _createHandler(controller);
    addTearDown(handler.dispose);

    await _pumpCorner(
      tester,
      controller: controller,
      handler: handler,
      contentHeight: 10,
    );

    expect(find.byKey(_upKey), findsNothing);
    expect(find.byKey(_downKey), findsNothing);
  });
}

BoxDecoration _decorationOf(WidgetTester tester, Key key) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byKey(key), matching: find.byType(Container)),
  );
  return container.decoration! as BoxDecoration;
}
