import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/l10n/app_localizations_zh.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'reader controls use Traditional Chinese fallbacks and semantics',
    (tester) async {
      final l10n = AppLocalizationsZhTw();
      await tester.pumpWidget(
        LocalizedTestApp(
          locale: const Locale('zh', 'TW'),
          home: Scaffold(
            body: ReaderProgressControl(
              config: ReaderProgressConfig(
                current: 3,
                total: 12,
                onChanged: (_) {},
                onChangeEnd: (_) {},
              ),
            ),
          ),
        ),
      );

      final previous = tester.widget<prism_button.IconButton>(
        find.byKey(const Key('shared-reader-prev-button')),
      );
      final next = tester.widget<prism_button.IconButton>(
        find.byKey(const Key('shared-reader-next-button')),
      );
      final slider = tester.widget<Slider>(
        find.byKey(const Key('shared-reader-progress-slider')),
      );

      expect(previous.tooltip, l10n.readerPrevious);
      expect(next.tooltip, l10n.readerNext);
      expect(
        slider.semanticFormatterCallback?.call(2),
        l10n.readerProgressSemantics('3', '12'),
      );
    },
  );

  testWidgets('reader controls preserve explicit tooltip overrides', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ReaderProgressControl(
            config: ReaderProgressConfig(
              current: 1,
              total: 2,
              previousTooltip: 'Raw Previous Override',
              nextTooltip: 'Raw Next Override',
              onChanged: (_) {},
              onChangeEnd: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-prev-button')),
          )
          .tooltip,
      'Raw Previous Override',
    );
    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-next-button')),
          )
          .tooltip,
      'Raw Next Override',
    );
  });

  testWidgets('reader top bar localizes back and keeps raw titles', (
    tester,
  ) async {
    final l10n = AppLocalizationsZhTw();
    await tester.pumpWidget(
      LocalizedTestApp(
        locale: const Locale('zh', 'TW'),
        home: Scaffold(
          body: ReaderTopOverlayBar(
            config: ReaderTopBarConfig(
              title: 'Raw Work 标题',
              subtitle: 'Raw Chapter 章節',
              actions: const <ReaderToolbarAction>[],
              onBack: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<prism_button.IconButton>(
            find.byKey(const Key('shared-reader-top-back-button')),
          )
          .tooltip,
      l10n.readerBack,
    );
    expect(find.text('Raw Work 标题'), findsOneWidget);
    expect(find.text('Raw Chapter 章節'), findsOneWidget);
  });

  testWidgets('reader display panel and stepper localize in zh_TW', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final l10n = AppLocalizationsZhTw();
    await tester.pumpWidget(
      LocalizedTestApp(
        locale: const Locale('zh', 'TW'),
        home: Scaffold(
          body: ReaderDisplayPanel(
            summary: '18磅',
            typographyChildren: [
              ReaderStepper(
                label: '字號',
                value: 18,
                min: 14,
                max: 30,
                step: 1,
                unit: l10n.readerUnitPoint,
                onChanged: (_) {},
              ),
            ],
            themeChildren: const [SizedBox()],
            readingChildren: const [SizedBox()],
          ),
        ),
      ),
    );

    expect(find.text(l10n.novelTypography), findsOneWidget);
    expect(find.text(l10n.novelTheme), findsOneWidget);
    expect(find.text(l10n.novelReading), findsOneWidget);
    expect(find.text('18${l10n.readerUnitPoint}'), findsOneWidget);
    expect(
      find.bySemanticsLabel(l10n.readerStepperDecrease('字號')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
