import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_checkbox_row.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets('toggles value, meets 48dp hit target, and merges semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <bool>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: AppCheckboxRow(
            key: const Key('row'),
            checkboxKey: const Key('box'),
            title: '允许转载',
            subtitle: '在个人空间列表公开可见',
            value: false,
            onChanged: changes.add,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('row'))).height,
      greaterThanOrEqualTo(48),
    );
    final node = tester.getSemantics(find.byKey(const Key('row')));
    expect(node.flagsCollection.isChecked, CheckedState.isFalse);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    expect(node.label, '允许转载\n在个人空间列表公开可见');

    await tester.tap(find.byKey(const Key('row')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('box')));
    await tester.pump();
    expect(changes, [true, true]);
    semantics.dispose();
  });

  testWidgets('supports compact, circular selected tint, and disabled state', (
    tester,
  ) async {
    const tint = Color(0xFF123456);
    var called = false;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Column(
            children: [
              AppCheckboxRow(
                key: const Key('selected-circle'),
                title: '好友甲',
                value: true,
                isCircle: true,
                compact: true,
                selected: true,
                selectedBackgroundColor: tint,
                onChanged: (_) {},
              ),
              const AppCheckboxRow(
                key: Key('disabled-row'),
                title: '已选好友',
                value: true,
                onChanged: null,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('selected-circle'))).height,
      greaterThanOrEqualTo(48),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('selected-circle')),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, tint);

    await tester.tap(find.byKey(const Key('disabled-row')));
    await tester.pump();
    expect(called, isFalse);
    final disabledNode = tester.getSemantics(
      find.byKey(const Key('disabled-row')),
    );
    expect(disabledNode.flagsCollection.isEnabled, Tristate.isFalse);
  });
}
