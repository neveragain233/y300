import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/presentation/thread_controls_settings_page.dart';
import 'package:y300/features/thread/presentation/thread_controls_preferences_controller.dart';
import 'package:y300/shared/widgets/app_select_menu.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'scroll hiding starts disabled and can be enabled from settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(threadControlsPreferencesControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LocalizedTestApp(home: ThreadControlsSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(
        const Key('thread-controls-hide-on-scroll-setting'),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<AppSwitchRow>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<AppSwitchRow>(toggle).value, isTrue);
      expect(
        container
            .read(threadControlsPreferencesControllerProvider)
            .requireValue
            .hideOnScroll,
        isTrue,
      );
    },
  );

  testWidgets('side select commits once and cancels without saving', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(threadControlsPreferencesControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LocalizedTestApp(home: ThreadControlsSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thread-controls-compact-setting')));
    await tester.pumpAndSettle();

    // 旧的展开选项已换成同一套锚定菜单。
    final side = find.byKey(const Key('thread-controls-side'));
    await tester.ensureVisible(side);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<ThreadControlsSide>), findsNothing);

    await tester.tap(side);
    await tester.pumpAndSettle();
    final current = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(AppSelectMenu.itemKeyOf(ThreadControlsSide.right)),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(current, isSemantics(hasCheckedState: true, isChecked: true));

    await tester.tap(
      find.byKey(AppSelectMenu.itemKeyOf(ThreadControlsSide.left)),
    );
    await tester.pumpAndSettle();
    expect(
      container
          .read(threadControlsPreferencesControllerProvider)
          .requireValue
          .side,
      ThreadControlsSide.left,
    );

    // 返回取消保留当前值。
    await tester.tap(side);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      container
          .read(threadControlsPreferencesControllerProvider)
          .requireValue
          .side,
      ThreadControlsSide.left,
    );
  });
}
