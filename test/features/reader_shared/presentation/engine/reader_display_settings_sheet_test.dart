import 'package:flutter/material.dart';

import '../../../../test_support/localized_test_app.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_display_settings_sheet.dart';

void main() {
  testWidgets('renders display choices as independent outlined buttons', (
    tester,
  ) async {
    ReaderModePreference? selectedMode;
    ReaderPageFitPreference? selectedFit;
    ReaderBackgroundPreference? selectedBackground;

    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ReaderDisplaySettingsSheet(
            preferences: ReaderPreferences.defaults(),
            onModeChanged: (value) => selectedMode = value,
            onPageFitChanged: (value) => selectedFit = value,
            onBackgroundChanged: (value) => selectedBackground = value,
            onPageSpacingChanged: (_) {},
            onShowPageIndicatorChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNWidgets(10));
    expect(find.text('垂直'), findsOneWidget);
    expect(find.text('左到右'), findsOneWidget);
    expect(find.text('宽度'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('原始'), findsNothing);

    final selectedButtonFinder = find.ancestor(
      of: find.text('左到右'),
      matching: find.byType(OutlinedButton),
    );
    final unselectedButtonFinder = find.ancestor(
      of: find.text('垂直'),
      matching: find.byType(OutlinedButton),
    );
    final selectedButton = tester.widget<OutlinedButton>(selectedButtonFinder);
    final unselectedButton = tester.widget<OutlinedButton>(
      unselectedButtonFinder,
    );
    expect(tester.getSize(selectedButtonFinder).height, lessThanOrEqualTo(40));
    expect(
      selectedButton.style?.side?.resolve(const <WidgetState>{})?.color,
      Colors.transparent,
    );
    expect(
      unselectedButton.style?.side?.resolve(const <WidgetState>{})?.color,
      isNot(Colors.transparent),
    );

    await tester.tap(find.text('左到右'));
    await tester.tap(find.text('高度'));
    await tester.tap(find.text('黑'));
    await tester.pump();

    expect(selectedMode, ReaderModePreference.ltr);
    expect(selectedFit, ReaderPageFitPreference.fitHeight);
    expect(selectedBackground, ReaderBackgroundPreference.black);
  });

  testWidgets('shows the background note only in paged modes', (tester) async {
    const note = 'paged mode note';
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ReaderDisplaySettingsSheet(
            preferences: ReaderPreferences.defaults(),
            backgroundNote: note,
            onModeChanged: (_) {},
            onPageFitChanged: (_) {},
            onBackgroundChanged: (_) {},
            onPageSpacingChanged: (_) {},
            onShowPageIndicatorChanged: (_) {},
          ),
        ),
      ),
    );

    // 默认是左到右翻页，说明可见且背景选项仍保留。
    expect(
      find.byKey(const Key('comic-reader-paged-background-note')),
      findsOneWidget,
    );
    expect(find.text(note), findsOneWidget);
    expect(find.text('黑'), findsOneWidget);

    await tester.tap(find.text('垂直'));
    await tester.pump();
    expect(
      find.byKey(const Key('comic-reader-paged-background-note')),
      findsNothing,
    );
    expect(find.text('黑'), findsOneWidget);
  });

  testWidgets('renders Traditional Chinese display choices', (tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        locale: const Locale('zh', 'TW'),
        home: Scaffold(
          body: ReaderDisplaySettingsSheet(
            preferences: ReaderPreferences.defaults(),
            onModeChanged: (_) {},
            onPageFitChanged: (_) {},
            onBackgroundChanged: (_) {},
            onPageSpacingChanged: (_) {},
            onShowPageIndicatorChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('顯示設定'), findsOneWidget);
    expect(find.text('閱讀模式'), findsOneWidget);
    expect(find.text('由左至右'), findsOneWidget);
    expect(find.text('寬度'), findsOneWidget);
  });
}
