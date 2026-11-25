import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/thread/presentation/widgets/thread_page_picker_sheet.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'unknown totals accept any positive page number and reject zero',
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
                    anchorContext: context,
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
      expect(find.byKey(const Key('thread-page-picker-popup')), findsOneWidget);
      final input = find.byKey(const Key('thread-detail-page-input'));
      final l10n = AppLocalizations.of(tester.element(input));
      expect(find.text(l10n.threadControlsPageUnknown(5)), findsOneWidget);
      await tester.enterText(input, '0');
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.threadControlsJumpPage),
      );
      await tester.pump();
      expect(find.text(l10n.threadControlsInvalidPage), findsOneWidget);
      expect(selected, isNull);
      await tester.enterText(input, '99');
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.threadControlsJumpPage),
      );
      await tester.pumpAndSettle();
      expect(selected, 99);
    },
  );

  testWidgets(
    'anchored popup selects page from list and renders cleanly in E-Ink mode',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        EInkModeScope(
          enabled: true,
          child: LocalizedTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    key: const Key('open-pages-eink'),
                    onPressed: () async {
                      selected = await showThreadPagePicker(
                        context,
                        currentPage: 2,
                        lastPage: 5,
                        hasMore: true,
                        anchorContext: context,
                      );
                    },
                    child: const Text('pages'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-pages-eink')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('thread-page-picker-popup')), findsOneWidget);
      await tester.tap(find.byKey(const Key('thread-detail-page-option-4')));
      await tester.pumpAndSettle();
      expect(selected, 4);
    },
  );
}
