import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:y300/shared/widgets/app_confirm_dialog.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets('confirm answers true and closes the dialog', (tester) async {
    final harness = await _pumpDialogHost(tester);

    await harness.open(tester);
    expect(find.text('删除这个分类？'), findsOneWidget);
    expect(find.text('删除后列表会回到未分类。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();

    expect(harness.result, isTrue);
    expect(find.text('删除这个分类？'), findsNothing);
  });

  testWidgets('cancel answers false', (tester) async {
    final harness = await _pumpDialogHost(tester);

    await harness.open(tester);
    await tester.tap(find.byKey(const Key('cancel')));
    await tester.pumpAndSettle();

    expect(harness.result, isFalse);
    expect(find.text('删除这个分类？'), findsNothing);
  });

  testWidgets('tapping outside answers false', (tester) async {
    final harness = await _pumpDialogHost(tester);

    await harness.open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(harness.result, isFalse);
    expect(find.text('删除这个分类？'), findsNothing);
  });

  testWidgets('the back button answers false', (tester) async {
    final harness = await _pumpDialogHost(tester);

    await harness.open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(harness.result, isFalse);
    expect(find.text('删除这个分类？'), findsNothing);
  });

  testWidgets('a non-dismissible dialog keeps the page waiting', (
    tester,
  ) async {
    final harness = await _pumpDialogHost(tester, dismissible: false);

    await harness.open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('删除这个分类？'), findsOneWidget);
    expect(harness.completed, isFalse);

    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();
    expect(harness.result, isTrue);
  });

  testWidgets('a repeated tap does not pop the page behind the dialog', (
    tester,
  ) async {
    final harness = await _pumpDialogHost(tester);

    await harness.open(tester);
    // 收回动画期间按钮仍在树上：第二次回答不得再 pop 一层页面。
    final confirm = tester.widget<prism_button.TextButton>(
      find.byKey(const Key('confirm')),
    );
    confirm.onPressed!();
    confirm.onPressed!();
    await tester.pumpAndSettle();

    expect(harness.result, isTrue);
    expect(find.byKey(const Key('open-dialog')), findsOneWidget);
  });

  testWidgets('a destructive action still answers true once', (tester) async {
    final harness = await _pumpDialogHost(tester, destructive: true);

    await harness.open(tester);
    await tester.tap(find.byKey(const Key('confirm')));
    await tester.pumpAndSettle();

    expect(harness.result, isTrue);
    expect(harness.calls, 1);
  });
}

class _DialogHarness {
  bool? result;
  bool completed = false;
  int calls = 0;

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-dialog')));
    await tester.pumpAndSettle();
  }
}

Future<_DialogHarness> _pumpDialogHost(
  WidgetTester tester, {
  bool dismissible = true,
  bool destructive = false,
}) async {
  final harness = _DialogHarness();
  await tester.pumpWidget(
    LocalizedTestApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-dialog'),
              onPressed: () async {
                harness.calls++;
                harness.result = await showAppConfirmDialog(
                  context: context,
                  title: '删除这个分类？',
                  message: '删除后列表会回到未分类。',
                  confirmLabel: '删除',
                  cancelLabel: '取消',
                  destructive: destructive,
                  dismissible: dismissible,
                  confirmKey: const Key('confirm'),
                  cancelKey: const Key('cancel'),
                );
                harness.completed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  return harness;
}
