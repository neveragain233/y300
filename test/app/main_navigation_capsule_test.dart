import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/navigation_dock.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';
import 'package:y300/app/settings/app_glass_level.dart';

import '../test_support/localized_test_app.dart';

void main() {
  testWidgets('capsule scopes glass by level and falls back on high contrast', (
    tester,
  ) async {
    await _pumpCapsule(tester, glassLevel: AppGlassLevel.off);
    expect(find.byType(LiquidGlass), findsNothing);

    await _pumpCapsule(tester, glassLevel: AppGlassLevel.standard);
    var scope = tester.widget<LiquidGlassScope>(find.byType(LiquidGlassScope));
    expect(scope.enabled, isTrue);
    expect(scope.quality, LiquidGlassQuality.standard);
    expect(find.byType(LiquidGlass), findsOneWidget);

    await _pumpCapsule(tester, glassLevel: AppGlassLevel.enhanced);
    scope = tester.widget<LiquidGlassScope>(find.byType(LiquidGlassScope));
    expect(scope.enabled, isTrue);
    expect(scope.quality, LiquidGlassQuality.ultra);

    await _pumpCapsule(
      tester,
      glassLevel: AppGlassLevel.enhanced,
      highContrast: true,
    );
    scope = tester.widget<LiquidGlassScope>(find.byType(LiquidGlassScope));
    expect(scope.enabled, isFalse);
    expect(find.byType(LiquidGlass), findsNothing);
  });

  testWidgets('capsule draws the selected icon and keeps one label per slot', (
    tester,
  ) async {
    await _pumpCapsule(tester, selectedIndex: 1);

    expect(find.text('论坛'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('target1')),
        matching: find.byIcon(Icons.circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('target0')),
        matching: find.byIcon(Icons.circle_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(3));
  });

  testWidgets('capsule keeps a button and selection semantic per destination', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpCapsule(tester, selectedIndex: 2);

      final selected = tester.getSemantics(find.bySemanticsLabel('书架'));
      expect(selected.flagsCollection.isButton, isTrue);
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);

      final sibling = tester.getSemantics(find.bySemanticsLabel('论坛'));
      expect(sibling.flagsCollection.isButton, isTrue);
      expect(sibling.flagsCollection.isSelected, Tristate.isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('capsule activates a focused destination from the keyboard', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpCapsule(tester, swipeEnabled: true, onSelected: commits.add);

    Focus.of(tester.element(find.text('收藏'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(commits, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule clicks once per candidate change while dragging', (
    tester,
  ) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final commits = <int>[];
    await _pumpCapsule(tester, swipeEnabled: true, onSelected: commits.add);

    final itemWidth = tester
        .getSize(find.byKey(const ValueKey('target0')))
        .width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('target0'))),
    );
    // 未越过触摸容差的移动不建立拖动，也不触发触感。
    await gesture.moveBy(Offset(itemWidth * 0.2, 0));
    await tester.pump();
    expect(haptics, isEmpty);
    // 越过容差只建立拖动，候选仍从当前选中项起算。
    await gesture.moveBy(Offset(itemWidth * 0.3, 0));
    await tester.pump();
    expect(haptics, isEmpty);
    // 候选变化各触发一次，同一候选内继续移动不重复。
    await gesture.moveBy(Offset(itemWidth * 0.4, 0));
    await tester.pump();
    expect(haptics, hasLength(1));
    await gesture.moveBy(Offset(itemWidth * 0.1, 0));
    await tester.pump();
    expect(haptics, hasLength(1));
    await gesture.moveBy(Offset(-itemWidth * 0.2, 0));
    await tester.pump();
    expect(haptics, hasLength(1));
    await gesture.moveBy(Offset(-itemWidth * 0.4, 0));
    await tester.pump();
    expect(haptics, hasLength(2));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule retires an uncommitted drag when its entries change', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final commits = <int>[];
    final itemCount = ValueNotifier<int>(4);
    final selected = ValueNotifier<int>(0);
    addTearDown(itemCount.dispose);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ValueListenableBuilder<int>(
          valueListenable: itemCount,
          builder: (context, count, _) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (context, index, _) => MainNavigationCapsule(
                items: _items().take(count).toList(),
                selectedIndex: index,
                swipeEnabled: true,
                onSelected: commits.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('target0'))),
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    // 入口变化发生在松手之前，未提交的候选随旧排列一起退役。
    itemCount.value = 3;
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(selected.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule does not project release velocity into the choice', (
    tester,
  ) async {
    final commits = <int>[];
    await _pumpCapsule(tester, swipeEnabled: true, onSelected: commits.add);

    await tester.fling(
      find.byKey(const ValueKey('target0')),
      const Offset(40, 0),
      3000,
    );
    await tester.pumpAndSettle();
    expect(commits, isEmpty);

    await tester.fling(
      find.byKey(const ValueKey('target0')),
      const Offset(90, 0),
      3000,
    );
    await tester.pumpAndSettle();
    expect(commits, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule keeps the lens content copy through the settle', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    await _pumpCapsule(
      tester,
      selection: selected,
      glassLevel: AppGlassLevel.standard,
      disableAnimations: false,
    );
    expect(find.byIcon(Icons.circle), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('target1'))),
    );
    // 弹簧起始帧只记时，不计入位移；先走一帧再推进抬起。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    // 按住时透镜上叠加放大后的选中内容副本。
    expect(find.byIcon(Icons.circle), findsNWidgets(2));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    expect(selected.value, 1);
    // 松手后的落位弹簧期间仍保留同一副本。
    expect(find.byIcon(Icons.circle), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule passes the lens drag mode to prism_ui', (tester) async {
    await _pumpCapsule(tester);
    expect(
      tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .dragFromSelection,
      isTrue,
    );

    await _pumpCapsule(tester, dragFromSelection: false);
    expect(
      tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .dragFromSelection,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow press drags from the pressed destination', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(2);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await _pumpCapsule(
      tester,
      selection: selected,
      swipeEnabled: true,
      dragFromSelection: false,
      onSelected: commits.add,
    );
    final pitch =
        tester.getCenter(find.byKey(const ValueKey('target1'))).dx -
        tester.getCenter(find.byKey(const ValueKey('target0'))).dx;

    await tester.drag(find.byKey(const ValueKey('target0')), Offset(pitch, 0));
    await tester.pumpAndSettle();

    // 按下 target0 后再拖一格：落到 target1，而不是选中项 2 的下一格。
    expect(commits, <int>[1]);
    expect(selected.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection drag keeps moving from the selected destination', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(2);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await _pumpCapsule(
      tester,
      selection: selected,
      swipeEnabled: true,
      onSelected: commits.add,
    );
    final pitch =
        tester.getCenter(find.byKey(const ValueKey('target1'))).dx -
        tester.getCenter(find.byKey(const ValueKey('target0'))).dx;

    await tester.drag(find.byKey(const ValueKey('target0')), Offset(pitch, 0));
    await tester.pumpAndSettle();

    // 相对拖动：从选中项 2 开始，拖一格落到 3。
    expect(commits, <int>[3]);
    expect(selected.value, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule ignores drags while swipe is disabled', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final commits = <int>[];
    await _pumpCapsule(
      tester,
      glassLevel: AppGlassLevel.standard,
      onSelected: commits.add,
    );
    final before = tester.getRect(_lensPlatter());

    await tester.drag(
      find.byKey(const ValueKey('target0')),
      const Offset(150, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(_lensPlatter()), before);
    expect(commits, isEmpty);
    expect(haptics, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capsule fires onReselected on tap but not on drag-back', (
    tester,
  ) async {
    final commits = <int>[];
    final reselects = <int>[];
    await _pumpCapsule(
      tester,
      selectedIndex: 0,
      swipeEnabled: true,
      onSelected: commits.add,
      onReselected: reselects.add,
    );

    await tester.tap(find.byKey(const ValueKey('target0')));
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(reselects, <int>[0]);

    // 拖出后再拖回原项松手，不触发重选回根页。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('target0'))),
    );
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, isEmpty);
    expect(reselects, <int>[0]);
  });
}

List<MainNavigationItem> _items() => [
  for (final (index, label) in ['论坛', '收藏', '书架', '我的'].indexed)
    MainNavigationItem(
      id: 'target$index',
      label: label,
      icon: const Icon(Icons.circle_outlined),
      selectedIcon: const Icon(Icons.circle),
    ),
];

Future<void> _pumpCapsule(
  WidgetTester tester, {
  int selectedIndex = 0,
  ValueNotifier<int>? selection,
  bool swipeEnabled = false,
  AppGlassLevel glassLevel = AppGlassLevel.off,
  bool dragFromSelection = true,
  bool highContrast = false,
  bool disableAnimations = true,
  ValueChanged<int>? onSelected,
  ValueChanged<int>? onReselected,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  Widget capsule(int index, ValueChanged<int>? onSelected) =>
      MainNavigationCapsule(
        items: _items(),
        selectedIndex: index,
        swipeEnabled: swipeEnabled,
        dragFromSelection: dragFromSelection,
        glassLevel: glassLevel,
        onSelected: onSelected,
        onReselected: onReselected,
      );
  await tester.pumpWidget(
    LocalizedTestApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          highContrast: highContrast,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: selection == null
            ? capsule(selectedIndex, onSelected)
            : ValueListenableBuilder<int>(
                valueListenable: selection,
                builder: (context, value, _) => capsule(value, (index) {
                  onSelected?.call(index);
                  selection.value = index;
                }),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The lens platter the bar draws under its selected destination.
Finder _lensPlatter() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) {
    return false;
  }
  final decoration = widget.decoration;
  return decoration is ShapeDecoration && (decoration.color?.a ?? 0) > 0;
});
