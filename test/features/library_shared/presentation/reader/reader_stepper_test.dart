import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/l10n/app_localizations_zh.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'steps once per tap, exposes 48dp buttons, and disables at bounds',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final l10n = AppLocalizationsZh();
      final changes = <double>[];
      final commits = <double>[];
      var value = 16.0;

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReaderStepper(
                keyPrefix: 'font',
                label: '字号',
                value: value,
                min: 14,
                max: 18,
                step: 2,
                fractionDigits: 0,
                unit: l10n.readerUnitPoint,
                onChanged: (next) {
                  changes.add(next);
                  setState(() => value = next);
                },
                onChangeEnd: commits.add,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('font-decrease'))),
        const Size(48, 48),
      );
      expect(
        tester.getSize(find.byKey(const Key('font-increase'))),
        const Size(48, 48),
      );
      expect(
        find.bySemanticsLabel(l10n.readerStepperDecrease('字号')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.readerStepperIncrease('字号')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          l10n.readerStepperValueSemantics('字号', '16${l10n.readerUnitPoint}'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('font-increase')));
      await tester.pump();
      expect(changes, [18]);
      expect(commits, [18]);

      // 到达上限后继续点加号不再越界触发。
      await tester.tap(find.byKey(const Key('font-increase')));
      await tester.pump();
      expect(commits, [18]);

      await tester.tap(find.byKey(const Key('font-decrease')));
      await tester.tap(find.byKey(const Key('font-decrease')));
      await tester.pump();
      expect(value, 14);
      expect(commits, [18, 16, 14]);
      semantics.dispose();
    },
  );

  testWidgets('long press repeats continuously and commits once on release', (
    tester,
  ) async {
    final changes = <double>[];
    final commits = <double>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ReaderStepper(
            keyPrefix: 'spacing',
            label: '页间距',
            value: 0,
            min: 0,
            max: 48,
            step: 4,
            unit: '像素',
            onChanged: changes.add,
            onChangeEnd: commits.add,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('spacing-increase'))),
    );
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 300));
    expect(changes.length, greaterThanOrEqualTo(3));
    expect(commits, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [changes.last]);
  });

  testWidgets(
    'numeric dialog commits valid input and silently reverts invalid',
    (tester) async {
      final changes = <double>[];
      final commits = <double>[];
      var value = 0.5;

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReaderStepper(
                keyPrefix: 'brightness',
                label: '亮度',
                value: value,
                min: 0.3,
                max: 1.0,
                step: 0.05,
                displayScale: 100,
                fractionDigits: 0,
                unit: '%',
                onChanged: (next) {
                  changes.add(next);
                  setState(() => value = next);
                },
                onChangeEnd: commits.add,
              ),
            ),
          ),
        ),
      );

      Future<void> submitText(String text) async {
        await tester.tap(find.byKey(const Key('brightness-value')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('brightness-input')), text);
        await tester.tap(find.byKey(const Key('brightness-confirm')));
        await tester.pumpAndSettle();
      }

      await submitText('abc');
      await submitText('');
      await submitText('120');
      await submitText('10');
      expect(changes, isEmpty);
      expect(commits, isEmpty);

      await submitText('80');
      expect(changes, [closeTo(0.8, 0.0001)]);
      expect(commits, [closeTo(0.8, 0.0001)]);
    },
  );
}
