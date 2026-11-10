import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    testWidgets('panel overlays without changing source geometry at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final source = GlobalKey();
      var selections = 0;
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(
              builder: (context) => SizedBox.expand(
                key: source,
                child: TextButton(
                  onPressed: () => showAdaptivePanel<void>(
                    context: context,
                    builder: (context) => SizedBox(
                      height: 240,
                      child: Column(
                        children: [
                          const TextField(),
                          TextButton(
                            onPressed: () {
                              selections++;
                              Navigator.pop(context);
                            },
                            child: Text(
                              AppLocalizations.of(context).commonConfirm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      final element = source.currentContext;
      final before = tester.getRect(find.byKey(source));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(source.currentContext, same(element));
      expect(tester.getRect(find.byKey(source)), before);
      expect(
        find.byKey(const Key('adaptive-side-panel')),
        size.width >= 720 ? findsOneWidget : findsNothing,
      );
      if (size.width >= 720) {
        expect(
          tester.getRect(find.byKey(const Key('adaptive-side-panel'))),
          const Rect.fromLTWH(720, 0, 480, 800),
        );
      }
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(source)), before);
      if (size.width >= 720) {
        expect(
          tester.getRect(find.byKey(const Key('adaptive-side-panel'))).bottom,
          500,
        );
      }
      final l10n = AppLocalizations.of(tester.element(find.byType(TextField)));
      await tester.tap(find.text(l10n.commonConfirm));
      await tester.pumpAndSettle();
      expect(selections, 1);
      expect(find.byType(TextField), findsNothing);
      tester.view.resetViewInsets();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('panel stays on the originating side of a separating hinge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1700, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
            viewPadding: const EdgeInsets.only(top: 24),
            displayFeatures: const [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(820, 0, 60, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.unknown,
              ),
            ],
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Row(
            children: [
              const Spacer(),
              Expanded(
                child: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => showAdaptivePanel<void>(
                        context: context,
                        builder: (_) => const Text('panel'),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('adaptive-side-panel'))),
      const Rect.fromLTWH(1220, 24, 480, 876),
    );
    await tester.tap(find.byKey(const Key('adaptive-panel-close')));
    await tester.pumpAndSettle();
    expect(find.text('panel'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
