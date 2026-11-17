import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_bookshelf_switcher.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_shell_destination_presentation.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  const destinations = [
    MainShellDestination.comic,
    MainShellDestination.novel,
    MainShellDestination.blogs,
  ];

  testWidgets('a narrow switcher opens the app menu with the current checked', (
    tester,
  ) async {
    final selected = <MainShellDestination>[];
    await tester.pumpWidget(
      _switcherApp(
        width: 120,
        current: MainShellDestination.novel,
        destinations: destinations,
        onSelected: selected.add,
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.byType(SegmentedButton<MainShellDestination>), findsNothing);
    await tester.tap(find.byKey(const Key('main-bookshelf-switcher')));
    await tester.pumpAndSettle();

    // 顺序沿用传入的入口顺序，每项只出现一次。
    final tops = [
      for (final destination in destinations)
        tester.getRect(_menuRow(l10n, destination)).top,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(selected, isEmpty);

    // 当前入口的菜单行带勾选状态。
    final currentRow = find
        .ancestor(
          of: _menuRow(l10n, MainShellDestination.novel),
          matching: find.byType(MetaData),
        )
        .first;
    expect(
      tester.getSemantics(
        find.descendant(of: currentRow, matching: find.byType(Semantics)).first,
      ),
      isSemantics(hasCheckedState: true, isChecked: true),
    );

    await tester.tap(
      find.text(MainShellDestination.blogs.localizedLabel(l10n)),
    );
    await tester.pumpAndSettle();
    expect(selected, [MainShellDestination.blogs]);
    expect(
      find.text(MainShellDestination.novel.localizedLabel(l10n)),
      findsOne,
    );
  });

  testWidgets('a narrow switcher without a selection callback stays closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _switcherApp(
        width: 120,
        current: MainShellDestination.novel,
        destinations: destinations,
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    await tester.tap(find.byKey(const Key('main-bookshelf-switcher')));
    await tester.pumpAndSettle();
    expect(
      find.text(MainShellDestination.comic.localizedLabel(l10n)),
      findsNothing,
    );
    expect(
      find.text(MainShellDestination.blogs.localizedLabel(l10n)),
      findsNothing,
    );
    // 没有回调就没有菜单，触发控件仍显示当前入口。
    expect(
      find.text(MainShellDestination.novel.localizedLabel(l10n)),
      findsOne,
    );
  });

  testWidgets('a wide switcher keeps the segmented control', (tester) async {
    final selected = <MainShellDestination>[];
    await tester.pumpWidget(
      _switcherApp(
        width: 480,
        current: MainShellDestination.novel,
        destinations: destinations,
        onSelected: selected.add,
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.byKey(const Key('main-bookshelf-switcher')), findsOneWidget);
    expect(find.byType(SegmentedButton<MainShellDestination>), findsOneWidget);
    await tester.tap(
      find.text(MainShellDestination.blogs.localizedLabel(l10n)),
    );
    await tester.pumpAndSettle();
    expect(selected, [MainShellDestination.blogs]);
  });
}

/// 菜单位于 MetaData 行内，避免和触发控件上的同名文案混淆。
Finder _menuRow(AppLocalizations l10n, MainShellDestination destination) =>
    find.descendant(
      of: find.byType(MetaData),
      matching: find.text(destination.localizedLabel(l10n)),
    );

Widget _switcherApp({
  required double width,
  required MainShellDestination current,
  required List<MainShellDestination> destinations,
  ValueChanged<MainShellDestination>? onSelected,
}) {
  return LocalizedTestApp(
    theme: AppTheme.light(),
    home: Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SizedBox(
          width: width,
          child: MainBookshelfSwitcher(
            current: current,
            destinations: destinations,
            onSelected: onSelected,
          ),
        ),
      ),
    ),
  );
}
