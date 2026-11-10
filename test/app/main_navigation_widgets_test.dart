import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';

import '../test_support/localized_test_app.dart';

void main() {
  swipeTests();

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

List<MainNavigationItem> _swipeItems() => [
  for (var index = 0; index < 4; index++)
    MainNavigationItem(
      id: 'target$index',
      label: ['论坛', '收藏', '书架', '我的'][index],
      icon: const Icon(Icons.circle_outlined),
      selectedIcon: const Icon(Icons.circle),
    ),
];

Future<void> _pumpSwipeCapsule(
  WidgetTester tester, {
  required ValueNotifier<int> selected,
  required List<int> commits,
  required bool swipeEnabled,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 700);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    LocalizedTestApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (context, index, _) => Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: MainNavigationCapsule(
            items: _swipeItems(),
            selectedIndex: index,
            swipeEnabled: swipeEnabled,
            onSelected: (next) {
              commits.add(next);
              selected.value = next;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void swipeTests() {
  testWidgets('swipe commits the release position only', (tester) async {
    final selected = ValueNotifier<int>(0);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await _pumpSwipeCapsule(
      tester,
      selected: selected,
      commits: commits,
      swipeEnabled: true,
    );

    final capsule = find.byType(MainNavigationCapsule);
    await tester.drag(capsule, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(selected.value, 1);
    expect(commits, [1]);

    await tester.drag(capsule, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(selected.value, 1);
    expect(commits, [1]);

    await tester.drag(capsule, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(selected.value, 0);
    expect(commits, [1, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe ignores velocity and cancels without committing', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await _pumpSwipeCapsule(
      tester,
      selected: selected,
      commits: commits,
      swipeEnabled: true,
    );

    // 同一起始位置下，快速小幅甩动仍按落点回到原项。
    await tester.fling(
      find.byType(MainNavigationCapsule),
      const Offset(30, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(selected.value, 0);
    expect(commits, isEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MainNavigationCapsule)),
    );
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selected.value, 0);
    expect(commits, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe disabled leaves taps as the only commit', (tester) async {
    final selected = ValueNotifier<int>(0);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await _pumpSwipeCapsule(
      tester,
      selected: selected,
      commits: commits,
      swipeEnabled: false,
    );

    await tester.drag(find.byType(MainNavigationCapsule), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(selected.value, 0);
    expect(commits, isEmpty);
  });

  testWidgets('swipe works with animations disabled', (tester) async {
    final selected = ValueNotifier<int>(0);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await _pumpSwipeCapsule(
      tester,
      selected: selected,
      commits: commits,
      swipeEnabled: true,
      disableAnimations: true,
    );

    await tester.drag(find.byType(MainNavigationCapsule), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(selected.value, 1);
    expect(commits, [1]);
    expect(tester.takeException(), isNull);
  });
}
