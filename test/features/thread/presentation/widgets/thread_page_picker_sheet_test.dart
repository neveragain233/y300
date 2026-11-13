import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/presentation/widgets/thread_page_picker_sheet.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'unknown totals accept only the known pages and the next available page',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-pages'),
                onPressed: () async {
                  selected = await showThreadPagePicker(
                    context,
                    currentPage: 5,
                    lastPage: null,
                    hasMore: true,
                  );
                },
                child: const Text('pages'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-pages')));
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('thread-detail-page-input'));
      final l10n = AppLocalizations.of(tester.element(input));
      expect(find.text(l10n.threadControlsPageUnknown(5)), findsOneWidget);
      await tester.enterText(input, '99');
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.threadControlsJumpPage),
      );
      await tester.pump();
      expect(find.text(l10n.threadControlsInvalidPage), findsOneWidget);
      expect(selected, isNull);
      await tester.enterText(input, '6');
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.threadControlsJumpPage),
      );
      await tester.pumpAndSettle();
      expect(selected, 6);
    },
  );
}
