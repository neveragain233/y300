import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'AppGroupedRow InkWell covers entire row including top/bottom edges and chevron',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: AppGroupedSection(
              title: '设置',
              children: [
                AppGroupedRow(
                  key: const Key('chevron-row'),
                  leading: const Icon(Icons.palette_outlined),
                  title: '外观',
                  showChevron: true,
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );

      final rowFinder = find.byKey(const Key('chevron-row'));
      final inkWellFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(InkWell),
      );
      final rowRect = tester.getRect(rowFinder);
      final inkWellRect = tester.getRect(inkWellFinder);

      expect(rowRect.height, greaterThanOrEqualTo(56));
      expect(inkWellRect, rowRect);

      await tester.tapAt(Offset(rowRect.left + 4, rowRect.center.dy));
      await tester.tapAt(Offset(rowRect.center.dx, rowRect.top + 2));
      await tester.tapAt(Offset(rowRect.center.dx, rowRect.bottom - 2));
      await tester.tapAt(rowRect.center);
      await tester.tapAt(Offset(rowRect.right - 4, rowRect.center.dy));
      await tester.pump();

      expect(taps, 5);
    },
  );

  testWidgets('AppGroupedRow full hitbox includes decorative trailing', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: AppGroupedSection(
            children: [
              AppGroupedRow(
                key: const Key('trailing-icon-row'),
                title: '项目主页',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );

    final rowFinder = find.byKey(const Key('trailing-icon-row'));
    final rowRect = tester.getRect(rowFinder);
    expect(
      tester.getRect(
        find.descendant(of: rowFinder, matching: find.byType(InkWell)),
      ),
      rowRect,
    );

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.tapAt(Offset(rowRect.right - 4, rowRect.center.dy));
    await tester.pump();

    expect(taps, 2);
  });

  testWidgets(
    'interactive trailing controls handle taps once without firing outer row onTap',
    (tester) async {
      var rowTaps = 0;
      var deleteTaps = 0;
      final switchValues = <bool>[];

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: AppGroupedSection(
              children: [
                AppGroupedRow(
                  key: const Key('interactive-trailing-row'),
                  title: '书签条目',
                  onTap: () => rowTaps++,
                  trailing: AppToolbarIconButton(
                    buttonKey: const Key('trailing-delete-btn'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => deleteTaps++,
                  ),
                ),
                AppSwitchRow(
                  switchKey: const Key('row-switch-ctrl'),
                  title: '开关条目',
                  value: false,
                  onChanged: switchValues.add,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('trailing-delete-btn')));
      await tester.pump();
      expect(deleteTaps, 1);
      expect(rowTaps, 0);

      final interactiveRect = tester.getRect(
        find.byKey(const Key('interactive-trailing-row')),
      );
      await tester.tapAt(
        Offset(interactiveRect.left + 24, interactiveRect.top + 2),
      );
      await tester.tapAt(
        Offset(interactiveRect.left + 24, interactiveRect.center.dy),
      );
      await tester.pump();
      expect(rowTaps, 2);
      expect(deleteTaps, 1);

      await tester.tap(find.byKey(const Key('row-switch-ctrl')));
      final switchRowRect = tester.getRect(find.byType(AppSwitchRow));
      await tester.tapAt(
        Offset(switchRowRect.left + 24, switchRowRect.top + 2),
      );
      await tester.pump();
      expect(switchValues, [true, true]);
    },
  );

  testWidgets('disabled and non-interactive AppGroupedRow respect state', (
    tester,
  ) async {
    var disabledTaps = 0;
    var actionTaps = 0;

    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: AppGroupedSection(
            children: [
              AppGroupedRow(
                key: const Key('disabled-row'),
                title: '禁用条目',
                showChevron: true,
                enabled: false,
                onTap: () => disabledTaps++,
              ),
              AppGroupedRow(
                key: const Key('static-row'),
                title: '只读说明条目',
                trailing: TextButton(
                  key: const Key('inline-action-btn'),
                  onPressed: () => actionTaps++,
                  child: const Text('操作'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final disabledRect = tester.getRect(find.byKey(const Key('disabled-row')));
    await tester.tapAt(disabledRect.center);
    await tester.tapAt(Offset(disabledRect.right - 4, disabledRect.center.dy));
    await tester.pump();
    expect(disabledTaps, 0);

    final staticFinder = find.byKey(const Key('static-row'));
    expect(
      find.descendant(
        of: staticFinder,
        matching: find.ancestor(
          of: find.text('只读说明条目'),
          matching: find.byType(InkWell),
        ),
      ),
      findsNothing,
    );
    await tester.tap(find.text('只读说明条目'));
    await tester.tap(find.byKey(const Key('inline-action-btn')));
    await tester.pump();
    expect(actionTaps, 1);
  });

  testWidgets('AppGroupedSection honors custom dividerIndent', (tester) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: AppGroupedSection(
            dividerIndent: 16,
            children: [
              AppGroupedRow(title: '第一项'),
              AppGroupedRow(title: '第二项'),
            ],
          ),
        ),
      ),
    );

    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.indent, 16);
  });
}
