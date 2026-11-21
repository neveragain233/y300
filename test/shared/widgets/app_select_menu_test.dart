import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_select_menu.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets('shows the current value and checks it in the shared menu', (
    tester,
  ) async {
    await tester.pumpWidget(_menuApp(value: 'forum', onSelected: (_) {}));

    expect(find.text('论坛'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    await tester.tap(find.byKey(const Key('select-menu')));
    await tester.pumpAndSettle();

    final current = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(AppSelectMenu.itemKeyOf('forum')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(current, isSemantics(hasCheckedState: true, isChecked: true));
    final other = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(AppSelectMenu.itemKeyOf('bookshelf')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(other, isSemantics(hasCheckedState: true, isChecked: false));
  });

  testWidgets('picks one option once and closes the menu', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(_menuApp(value: 'forum', onSelected: selected.add));

    await tester.tap(find.byKey(const Key('select-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppSelectMenu.itemKeyOf('bookshelf')));
    await tester.pump();
    expect(selected, ['bookshelf']);
    await tester.pumpAndSettle();
    expect(find.byKey(AppSelectMenu.itemKeyOf('bookshelf')), findsNothing);
    expect(selected, ['bookshelf']);
  });

  testWidgets('an outside tap or back cancels without committing', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(_menuApp(value: 'forum', onSelected: selected.add));

    await tester.tap(find.byKey(const Key('select-menu')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text('书架'), findsNothing);

    await tester.tap(find.byKey(const Key('select-menu')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.byKey(const Key('select-menu')), findsOneWidget);
  });

  testWidgets('a disabled select never opens the menu', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      _menuApp(value: 'forum', onSelected: selected.add, enabled: false),
    );

    await tester.tap(find.byKey(const Key('select-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(AppSelectMenu.itemKeyOf('bookshelf')), findsNothing);
    expect(selected, isEmpty);
  });

  testWidgets('disabled AppSelectOption cannot be selected', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Center(
            child: AppSelectMenu<String>(
              key: const Key('select-menu'),
              value: 'forum',
              options: const [
                AppSelectOption(value: 'forum', label: '论坛'),
                AppSelectOption(value: 'locked', label: '不可用', enabled: false),
              ],
              onSelected: selected.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('select-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(AppSelectMenu.itemKeyOf('locked')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
  });

  testWidgets('AppSelectField renders chrome and commits selected option', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppSelectField<String>(
              key: const Key('select-field'),
              label: '分类',
              hintText: '请选择分类',
              errorText: '必填项',
              prefixIcon: const Icon(Icons.folder_outlined),
              value: null,
              options: const [
                AppSelectOption(value: 'a', label: '轻小说'),
                AppSelectOption(value: 'b', label: '漫画'),
              ],
              onSelected: selected.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('分类'), findsOneWidget);
    expect(find.text('请选择分类'), findsOneWidget);
    expect(find.text('必填项'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('select-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppSelectMenu.itemKeyOf('b')));
    await tester.pumpAndSettle();

    expect(selected, ['b']);
  });

  testWidgets('disabled AppSelectField does not open menu', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Center(
            child: AppSelectField<String>(
              key: const Key('select-field'),
              enabled: false,
              value: 'a',
              options: const [
                AppSelectOption(value: 'a', label: '轻小说'),
                AppSelectOption(value: 'b', label: '漫画'),
              ],
              onSelected: selected.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('select-field')));
    await tester.pumpAndSettle();
    expect(find.byKey(AppSelectMenu.itemKeyOf('b')), findsNothing);
    expect(selected, isEmpty);
  });
}

Widget _menuApp({
  required String value,
  required ValueChanged<String> onSelected,
  bool enabled = true,
}) {
  return LocalizedTestApp(
    home: Scaffold(
      body: Center(
        child: AppSelectMenu<String>(
          key: const Key('select-menu'),
          value: value,
          enabled: enabled,
          options: const [
            AppSelectOption(value: 'forum', label: '论坛'),
            AppSelectOption(value: 'bookshelf', label: '书架'),
          ],
          onSelected: onSelected,
        ),
      ),
    ),
  );
}
