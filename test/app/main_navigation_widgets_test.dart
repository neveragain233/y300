import 'package:flutter/material.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/navigation_dock.dart';
import 'package:prism_ui/press_region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';

import '../test_support/localized_test_app.dart';

void main() {
  swipeTests();

  testWidgets('glass levels switch the immersive capsule material', (
    tester,
  ) async {
    Future<void> pump(AppGlassLevel level) {
      return tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: MainNavigationCapsule(
              items: _swipeItems(),
              selectedIndex: 0,
              glassLevel: level,
            ),
          ),
        ),
      );
    }

    await pump(AppGlassLevel.off);
    expect(find.byType(LiquidGlass), findsNothing);

    await pump(AppGlassLevel.standard);
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(
      find.byKey(const Key('main-shell-immersive-navigation')),
      findsOneWidget,
    );

    await pump(AppGlassLevel.enhanced);
    expect(find.byType(LiquidGlass), findsOneWidget);
  });

  testWidgets('switching the glass level rebuilds the material in place', (
    tester,
  ) async {
    final level = ValueNotifier<AppGlassLevel>(AppGlassLevel.off);
    addTearDown(level.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: ValueListenableBuilder<AppGlassLevel>(
          valueListenable: level,
          builder: (context, value, _) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: MainNavigationCapsule(
              items: _swipeItems(),
              selectedIndex: 0,
              glassLevel: value,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LiquidGlass), findsNothing);

    level.value = AppGlassLevel.enhanced;
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlass), findsOneWidget);

    level.value = AppGlassLevel.off;
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlass), findsNothing);
    expect(
      find.byKey(const Key('main-shell-immersive-navigation')),
      findsOneWidget,
    );
  });

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
      final bar = find.byType(FloatingNavigationBar);
      expect(tester.getSize(bar).height, greaterThanOrEqualTo(48));
      expect(tester.widget<FloatingNavigationBar>(bar).selectedIndex, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy bottom bar uses PressRegion with 48dp targets, semantics, and 2x text safety',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(280, 700);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var selected = 0;
        final items = [
          for (var i = 0; i < 5; i++)
            MainNavigationItem(
              id: 'tab$i',
              label: ['论坛', '收藏', '书架', '消息', '我的'][i],
              icon: const Icon(Icons.circle_outlined),
              selectedIcon: const Icon(Icons.circle),
            ),
        ];

        await tester.pumpWidget(
          LocalizedTestApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: MainLegacyNavigationBar(
                  items: items,
                  selectedIndex: selected,
                  onSelected: (index) => setState(() => selected = index),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(PressRegion), findsNWidgets(5));

        for (var i = 0; i < 5; i++) {
          final target = find.byKey(
            ValueKey<String>('main-shell-destination-tab$i'),
          );
          final size = tester.getSize(target);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(selected, i);
          expect(
            tester.getSemantics(target),
            isSemantics(
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              hasTapAction: true,
            ),
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'navigation rail preserves 80dp compact geometry using PressRegion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var selected = 0;
      final items = _swipeItems();

      await tester.pumpWidget(
        LocalizedTestApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Row(
                children: [
                  MainNavigationRail(
                    items: items,
                    selectedIndex: selected,
                    onSelected: (index) => setState(() => selected = index),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(PressRegion), findsNWidgets(items.length));
      expect(
        tester
            .getSize(find.byKey(const Key('main-shell-navigation-rail')))
            .width,
        80,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('main-shell-rail-destination-target2'),
        ),
      );
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy bar and rail use high-contrast primary pill and zero duration in eInk mode',
    (tester) async {
      final items = _swipeItems();
      await tester.pumpWidget(
        LocalizedTestApp(
          home: EInkModeScope(
            enabled: true,
            child: Row(
              children: [
                MainNavigationRail(items: items, selectedIndex: 1),
                Expanded(
                  child: Scaffold(
                    body: const SizedBox.expand(),
                    bottomNavigationBar: MainLegacyNavigationBar(
                      items: items,
                      selectedIndex: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scheme = Theme.of(
        tester.element(find.byType(MainLegacyNavigationBar)),
      ).colorScheme;
      final pressRegions = tester.widgetList<PressRegion>(
        find.byType(PressRegion),
      );
      for (final region in pressRegions) {
        expect(region.overlay, isNull);
      }
      final tweens = tester.widgetList<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      for (final tween in tweens) {
        expect(tween.duration, Duration.zero);
      }
      final selectedPills = find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is ShapeDecoration &&
            decoration.shape == const StadiumBorder() &&
            decoration.color == scheme.primary;
      });
      expect(selectedPills, findsNWidgets(2));
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
