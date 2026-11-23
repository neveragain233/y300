import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/segmented_control.dart' as prism;
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_display_settings_sheet.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'organizes display choices across three tabs with segmented controls',
    (tester) async {
      ReaderModePreference? selectedMode;
      ReaderPageFitPreference? selectedFit;
      ReaderBackgroundPreference? selectedBackground;
      bool? selectedFullscreen;
      final spacingPreviews = <double>[];
      final spacingCommits = <double>[];

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: ReaderDisplaySettingsSheet(
              preferences: ReaderPreferences.defaults(),
              onModeChanged: (value) => selectedMode = value,
              onPageFitChanged: (value) => selectedFit = value,
              onBackgroundChanged: (value) => selectedBackground = value,
              onPageSpacingPreview: spacingPreviews.add,
              onPageSpacingChanged: spacingCommits.add,
              onShowPageIndicatorChanged: (_) {},
              fullscreenEnabled: true,
              onFullscreenChanged: (value) => selectedFullscreen = value,
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        find.byKey(const Key('reader-display-panel-tabs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reader-display-panel-summary')),
        findsOneWidget,
      );
      expect(
        find.byType(prism.SegmentedControl<ReaderDisplayTab>),
        findsOneWidget,
      );
      expect(find.text('排版'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('阅读'), findsOneWidget);
      expect(find.text('宽度'), findsOneWidget);
      expect(find.text('高度'), findsOneWidget);
      expect(find.text('屏幕'), findsOneWidget);
      expect(find.text('原始'), findsNothing);

      await tester.tap(find.text('高度'));
      await tester.pumpAndSettle();
      expect(selectedFit, ReaderPageFitPreference.fitHeight);

      await tester.tap(
        find.byKey(const Key('comic-reader-page-spacing-increase')),
      );
      await tester.pumpAndSettle();
      expect(spacingPreviews, [4]);
      expect(spacingCommits, [4]);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text('主题'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('黑'));
      await tester.pumpAndSettle();
      expect(selectedBackground, ReaderBackgroundPreference.black);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text('阅读'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('垂直'), findsOneWidget);
      expect(find.text('左到右'), findsOneWidget);
      await tester.tap(find.text('右到左'));
      await tester.pumpAndSettle();
      expect(selectedMode, ReaderModePreference.rtl);
      expect(
        find.byKey(const Key('comic-reader-page-indicator-switch')),
        findsOneWidget,
      );
      final fullscreenSwitch = find.byKey(
        const Key('comic-reader-fullscreen-switch'),
      );
      expect(fullscreenSwitch, findsOneWidget);
      await tester.tap(fullscreenSwitch);
      await tester.pumpAndSettle();
      expect(selectedFullscreen, isFalse);
    },
  );

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

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text('主题'),
      ),
    );
    await tester.pumpAndSettle();

    // 默认是左到右翻页，说明可见且背景选项仍保留。
    expect(
      find.byKey(const Key('comic-reader-paged-background-note')),
      findsOneWidget,
    );
    expect(find.text(note), findsOneWidget);
    expect(find.text('黑'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text('阅读'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('垂直'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text('主题'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('comic-reader-paged-background-note')),
      findsNothing,
    );
    expect(find.text('黑'), findsOneWidget);
  });

  testWidgets(
    'renders Traditional Chinese display choices and mode sheet uses grouped rows',
    (tester) async {
      await tester.pumpWidget(
        LocalizedTestApp(
          locale: const Locale('zh', 'TW'),
          home: Scaffold(
            body: ReaderDisplaySettingsSheet(
              preferences: ReaderPreferences.defaults(),
              onModeChanged: _noopMode,
              onPageFitChanged: _noopFit,
              onBackgroundChanged: _noopBg,
              onPageSpacingChanged: _noopSpacing,
              onShowPageIndicatorChanged: _noopBool,
            ),
          ),
        ),
      );

      expect(find.text('排版'), findsOneWidget);
      expect(find.text('主題'), findsOneWidget);
      expect(find.text('閱讀'), findsOneWidget);
      expect(find.text('寬度'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text('閱讀'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('閱讀模式'), findsOneWidget);
      expect(find.text('由左至右'), findsOneWidget);

      await tester.pumpWidget(
        const LocalizedTestApp(
          locale: Locale('zh', 'TW'),
          home: Scaffold(
            body: ReaderModeSheet(currentMode: ReaderModePreference.ltr),
          ),
        ),
      );
      expect(find.byType(Radio<ReaderModePreference>), findsNothing);
      expect(find.byType(AppGroupedRow), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey<String>('comic-reader-mode-ltr')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets('eInkMode hides gray option and handles persisted gray safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      EInkModeScope(
        enabled: true,
        child: LocalizedTestApp(
          home: Scaffold(
            body: ReaderDisplaySettingsSheet(
              preferences: ReaderPreferences.defaults().copyWith(
                background: ReaderBackgroundPreference.gray,
              ),
              onModeChanged: _noopMode,
              onPageFitChanged: _noopFit,
              onBackgroundChanged: _noopBg,
              onPageSpacingChanged: _noopSpacing,
              onShowPageIndicatorChanged: _noopBool,
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('reader-display-panel-tabs')),
        matching: find.text('主题'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('主题'), findsWidgets);
    expect(find.text('白'), findsOneWidget);
    expect(find.text('黑'), findsOneWidget);
    expect(find.text('灰'), findsNothing);
  });

  testWidgets(
    'shows page effect and speed only in non-eInk horizontal modes with callbacks',
    (tester) async {
      ReaderPageEffect? selectedEffect;
      ReaderPageSpeed? selectedSpeed;

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: ReaderDisplaySettingsSheet(
              preferences: ReaderPreferences.defaults().copyWith(
                readerMode: ReaderModePreference.ltr,
              ),
              onModeChanged: _noopMode,
              onPageFitChanged: _noopFit,
              onBackgroundChanged: _noopBg,
              onPageSpacingChanged: _noopSpacing,
              onShowPageIndicatorChanged: _noopBool,
              onPageEffectChanged: (value) => selectedEffect = value,
              onPageSpeedChanged: (value) => selectedSpeed = value,
            ),
          ),
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text('阅读'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('comic-reader-page-effect-select')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('comic-reader-page-speed-select')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('comic-reader-page-effect-select')),
      );
      await tester.pumpAndSettle();
      expect(find.text('段落接续'), findsNothing);
      await tester.tap(find.text('纸页翻动').last);
      await tester.pumpAndSettle();
      expect(selectedEffect, ReaderPageEffect.paper);

      await tester.tap(find.byKey(const Key('comic-reader-page-speed-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('利落').last);
      await tester.pumpAndSettle();
      expect(selectedSpeed, ReaderPageSpeed.brisk);

      // 切换为垂直模式后隐藏翻页动画与速度。
      await tester.tap(find.text('垂直'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('comic-reader-page-effect-select')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('comic-reader-page-speed-select')),
        findsNothing,
      );

      // 不传入回调（帖子/日志看图页）或 E-ink 模式下不显示。
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: ReaderDisplaySettingsSheet(
              preferences: ReaderPreferences.defaults().copyWith(
                readerMode: ReaderModePreference.ltr,
              ),
              onModeChanged: _noopMode,
              onPageFitChanged: _noopFit,
              onBackgroundChanged: _noopBg,
              onPageSpacingChanged: _noopSpacing,
              onShowPageIndicatorChanged: _noopBool,
            ),
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader-display-panel-tabs')),
          matching: find.text('阅读'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('comic-reader-page-effect-select')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('comic-reader-page-speed-select')),
        findsNothing,
      );
    },
  );
}

void _noopMode(ReaderModePreference _) {}
void _noopFit(ReaderPageFitPreference _) {}
void _noopBg(ReaderBackgroundPreference _) {}
void _noopSpacing(double _) {}
void _noopBool(bool _) {}
