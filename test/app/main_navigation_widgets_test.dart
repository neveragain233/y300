import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';

import '../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'five narrow destinations retain 48 pixel targets at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var selected = 0;
      await tester.pumpWidget(
        LocalizedTestApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: MainNavigationCapsule(
                items: [
                  for (var i = 0; i < 5; i++)
                    MainNavigationItem(
                      id: 'target$i',
                      label: ['论坛', '收藏', '书架', '消息', '我的'][i],
                      icon: const Icon(Icons.circle_outlined),
                      selectedIcon: const Icon(Icons.circle),
                    ),
                ],
                selectedIndex: selected,
                onSelected: (index) => setState(() => selected = index),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        final target = find.byKey(ValueKey('target$i'));
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        await tester.tap(target);
        await tester.pump();
        expect(selected, i);
      }
      final indicator = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                Theme.of(tester.element(find.byType(MainNavigationCapsule)))
                    .colorScheme
                    .primary,
      );
      expect(tester.getSize(indicator).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );
}
