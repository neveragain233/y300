import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/thread/presentation/thread_controls_settings_page.dart';
import 'package:y300/features/thread/presentation/thread_controls_preferences_controller.dart';

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
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        container
            .read(threadControlsPreferencesControllerProvider)
            .requireValue
            .hideOnScroll,
        isTrue,
      );
    },
  );
}
