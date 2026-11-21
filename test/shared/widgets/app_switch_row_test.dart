import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets('toggles from the row and from the switch', (tester) async {
    final values = <bool>[];
    await tester.pumpWidget(_switchApp(value: false, onChanged: values.add));

    await tester.tap(find.text('显示已读'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(prism.Switch));
    await tester.pumpAndSettle();

    expect(values, [true, true]);
  });

  testWidgets('exposes one merged switch node with its state', (tester) async {
    await tester.pumpWidget(_switchApp(value: true, onChanged: (_) {}));

    final node = tester.getSemantics(find.byType(AppSwitchRow));
    expect(node.label, contains('显示已读'));
    expect(node.label, contains('只在书架列表里隐藏已读条目'));
    expect(
      node,
      isSemantics(
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('keeps a 48 logical pixel switch target', (tester) async {
    await tester.pumpWidget(_switchApp(value: false, onChanged: (_) {}));

    final size = tester.getSize(find.byType(prism.Switch));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('disabled rows take no changes and say so', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _switchApp(value: false, onChanged: (_) => changes++, disabled: true),
    );

    await tester.tap(find.text('显示已读'));
    await tester.tap(find.byType(prism.Switch));
    await tester.pumpAndSettle();

    expect(changes, 0);
    final node = tester.getSemantics(find.byType(AppSwitchRow));
    expect(node, isSemantics(hasEnabledState: true, isEnabled: false));
  });

  testWidgets('a row without a handler is disabled', (tester) async {
    await tester.pumpWidget(_switchApp(value: true, onChanged: null));

    final node = tester.getSemantics(find.byType(AppSwitchRow));
    expect(node, isSemantics(hasEnabledState: true, isEnabled: false));
  });

  testWidgets('AppSwitch guarantees 48dp hit target and respects disabled', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Column(
            children: [
              AppSwitch(
                key: const Key('standalone-switch'),
                switchKey: const Key('inner-prism-switch'),
                value: false,
                onChanged: changes.add,
              ),
              const AppSwitch(
                key: Key('disabled-switch'),
                value: true,
                disabled: true,
                onChanged: _noopBool,
              ),
            ],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const Key('standalone-switch')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.byType(Switch), findsNothing);
    expect(find.byKey(const Key('inner-prism-switch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('standalone-switch')));
    await tester.tap(find.byKey(const Key('disabled-switch')));
    await tester.pump();
    expect(changes, [true]);
  });

  testWidgets('AppSwitchRow.compact toggles on row and switchKey tap', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: AppSwitchRow.compact(
            key: const Key('compact-row'),
            switchKey: const Key('compact-switch'),
            title: '安全区避让',
            value: false,
            onChanged: changes.add,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('compact-row'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.byKey(const Key('compact-switch')), findsOneWidget);
    final node = tester.getSemantics(find.byKey(const Key('compact-row')));
    expect(
      node,
      isSemantics(
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );

    await tester.tap(find.text('安全区避让'));
    await tester.tap(find.byKey(const Key('compact-switch')));
    await tester.pump();
    expect(changes, [true, true]);
  });
}

void _noopBool(bool _) {}

Widget _switchApp({
  required bool value,
  required ValueChanged<bool>? onChanged,
  bool disabled = false,
}) {
  return LocalizedTestApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AppGroupedSection(
          title: '阅读',
          children: [
            AppSwitchRow(
              title: '显示已读',
              subtitle: '只在书架列表里隐藏已读条目',
              value: value,
              onChanged: onChanged,
              disabled: disabled,
            ),
          ],
        ),
      ),
    ),
  );
}
