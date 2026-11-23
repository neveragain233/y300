import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_chapter_browser.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'ReaderPanelTheme separates canvas, panel, and card surfaces across themes and glass-off',
    (tester) async {
      for (final canvas in const [
        Color(0xFF000000),
        Color(0xFFF4ECD8),
        Color(0xFFFFFFFF),
      ]) {
        final base = ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
        );
        final palette = ReaderPanelPalette.fromCanvas(
          canvasBackground: canvas,
          baseTheme: base,
        );
        expect(palette.panelSurface, isNot(canvas));
        expect(palette.cardSurface, isNot(palette.panelSurface));

        await tester.pumpWidget(
          LocalizedTestApp(
            theme: base,
            home: AppGlassSurface(
              level: AppGlassLevel.off,
              borderRadius: 0,
              baseColor: palette.panelSurface,
              child: ReaderPanelTheme(
                palette: palette,
                child: const Scaffold(body: Text('内容')),
              ),
            ),
          ),
        );
        final resolved = ReaderPanelTheme.maybeOf(
          tester.element(find.text('内容')),
        );
        expect(resolved, palette);
      }
    },
  );

  testWidgets(
    'ReaderDisplayPanel switches tabs, displays summary, and resets scroll per tab',
    (tester) async {
      final observedTabs = <ReaderDisplayTab>[];
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: SizedBox(
              height: 220,
              child: ReaderDisplayPanel(
                summary: '18.5磅 · 1.60倍 · 纸白',
                onTabChanged: observedTabs.add,
                typographyChildren: [
                  for (var i = 0; i < 8; i++)
                    SizedBox(height: 56, child: Text('排版项 $i')),
                ],
                themeChildren: const [
                  SizedBox(height: 56, child: Text('主题顶部项')),
                ],
                readingChildren: const [
                  SizedBox(height: 56, child: Text('阅读设置项')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('reader-display-panel-summary')),
        findsOneWidget,
      );
      expect(find.text('18.5磅 · 1.60倍 · 纸白'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('主题'));
      await tester.pumpAndSettle();
      expect(find.text('主题顶部项'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('主题顶部项')).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.byKey(const Key('reader-display-panel-summary')),
              )
              .dy,
        ),
      );

      await tester.tap(find.text('阅读'));
      await tester.pumpAndSettle();
      expect(find.text('阅读设置项'), findsOneWidget);
      expect(observedTabs, [ReaderDisplayTab.theme, ReaderDisplayTab.reading]);
    },
  );

  testWidgets(
    'ReaderContentPanel switches catalog/bookmarks, jumps, deletes, and shows empty state',
    (tester) async {
      var tappedId = '';
      var deletedId = '';
      var entries = [
        ReaderBookmarkEntry(
          id: 'bm-1',
          rowKey: const Key('bm-row-1'),
          deleteKey: const Key('bm-del-1'),
          title: '第一话',
          subtitle: '摘要片段',
          isCurrent: true,
          onTap: () => tappedId = 'bm-1',
          onDelete: () => deletedId = 'bm-1',
        ),
      ];

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReaderContentPanel(
                catalogBuilder: (_) => const Center(child: Text('目录区域')),
                bookmarks: entries,
              ),
            ),
          ),
        ),
      );

      expect(find.text('目录区域'), findsOneWidget);
      await tester.tap(find.text('书签'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bm-row-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('bm-row-1')));
      expect(tappedId, 'bm-1');

      await tester.tap(find.byKey(const Key('bm-del-1')));
      expect(deletedId, 'bm-1');

      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: ReaderContentPanel(
              initialTab: ReaderContentTab.bookmarks,
              catalogBuilder: (_) => const SizedBox(),
              bookmarks: const [],
            ),
          ),
        ),
      );
      expect(find.text('还没有书签章节'), findsOneWidget);
    },
  );

  test('ReaderPanelPalette rebuilds full ThemeData with >= 4.5 contrast across cross-brightness app themes', () {
    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    final baseThemes = <ThemeData>[
      for (final family in AppThemeFamily.values) ...[
        AppTheme.build(family: family, brightness: Brightness.light),
        AppTheme.build(family: family, brightness: Brightness.dark),
      ],
      AppTheme.build(
        family: AppThemeFamily.warmPaper,
        brightness: Brightness.light,
        eInkMode: true,
      ),
      AppTheme.build(
        family: AppThemeFamily.warmPaper,
        brightness: Brightness.dark,
        eInkMode: true,
      ),
    ];
    const canvases = <Color>[
      Color(0xFF000000),
      Color(0xFFF4ECD8),
      Color(0xFFFFFFFF),
    ];

    for (final base in baseThemes) {
      for (final canvas in canvases) {
        final palette = ReaderPanelPalette.fromCanvas(
          canvasBackground: canvas,
          baseTheme: base,
        );
        final derived = palette.applyToTheme(base);
        final expectedDark = palette.brightness == Brightness.dark;

        expect(derived.brightness, palette.brightness);
        expect(derived.colorScheme.brightness, palette.brightness);
        expect(
          contrastRatio(
            derived.textTheme.bodyLarge!.color!,
            palette.cardSurface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(
            derived.textTheme.bodyMedium!.color!,
            palette.cardSurface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(
            derived.textTheme.bodySmall!.color!,
            palette.panelSurface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(
            derived.colorScheme.onSurfaceVariant,
            palette.panelSurface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(derived.listTileTheme.textColor!, palette.cardSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(derived.listTileTheme.iconColor!, palette.cardSurface),
          greaterThanOrEqualTo(4.5),
        );
        final selectedRowBg = Color.alphaBlend(
          derived.listTileTheme.selectedTileColor!,
          palette.cardSurface,
        );
        expect(
          selectedRowBg.computeLuminance(),
          expectedDark ? lessThan(0.25) : greaterThan(0.5),
        );
        expect(
          contrastRatio(derived.listTileTheme.selectedColor!, selectedRowBg),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(
            derived.colorScheme.onSecondaryContainer,
            derived.colorScheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
        final iconButtonFg = derived.iconButtonTheme.style!.foregroundColor!
            .resolve(<WidgetState>{})!;
        expect(
          contrastRatio(iconButtonFg, palette.panelSurface),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  testWidgets(
    'ReaderContentPanel renders dark catalog rows and header controls cleanly inside light app theme',
    (tester) async {
      final lightAppTheme = AppTheme.build(
        family: AppThemeFamily.warmPaper,
        brightness: Brightness.light,
      );
      final darkPalette = ReaderPanelPalette.fromCanvas(
        canvasBackground: const Color(0xFF000000),
        baseTheme: lightAppTheme,
      );

      await tester.pumpWidget(
        LocalizedTestApp(
          theme: lightAppTheme,
          home: Scaffold(
            body: ReaderContentPanel(
              palette: darkPalette,
              bookmarks: const [],
              catalogBuilder: (context) => LibraryChapterBrowser<int>(
                workId: 'test-work',
                keyPrefix: 'test-chapter',
                currentId: '2',
                itemExtent: 56,
                entries: const [
                  ChapterSearchEntry(id: '1', title: '第一章', value: 1),
                  ChapterSearchEntry(id: '2', title: '第二章', value: 2),
                ],
                rowBuilder: (context, value, _) => Material(
                  color: darkPalette.cardSurface,
                  child: ListTile(
                    selected: value == 2,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('第$value章'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listTileContext = tester.element(find.byType(ListTile).first);
      final panelTheme = Theme.of(listTileContext);
      expect(panelTheme.brightness, Brightness.dark);
      expect(
        panelTheme.listTileTheme.textColor!.computeLuminance(),
        greaterThan(0.5),
      );
      expect(
        panelTheme.listTileTheme.selectedTileColor!.computeLuminance(),
        lessThan(0.25),
      );

      final countWidget = tester.widget<Text>(find.text('2 章'));
      expect(countWidget.style!.color!.computeLuminance(), greaterThan(0.35));
    },
  );

  testWidgets(
    'ReaderDisplayPanel locks panel height across unbalanced tabs and keeps top tabs anchored',
    (tester) async {
      const panelKey = Key('height-lock-display-panel');
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderDisplayPanel(
                panelKey: panelKey,
                summary: '18.5磅 · 1.60倍',
                typographyChildren: [
                  for (var i = 0; i < 5; i++)
                    SizedBox(height: 56, child: Text('排版项 $i')),
                ],
                themeChildren: const [
                  SizedBox(height: 56, child: Text('主题唯一项')),
                ],
                readingChildren: [
                  for (var i = 0; i < 3; i++)
                    SizedBox(height: 56, child: Text('阅读项 $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialPanelRect = tester.getRect(find.byKey(panelKey));
      final initialTabsRect = tester.getRect(
        find.byKey(const Key('reader-display-panel-tabs')),
      );

      await tester.tap(find.text('主题'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(panelKey)), initialPanelRect);
      expect(
        tester.getRect(find.byKey(const Key('reader-display-panel-tabs'))),
        initialTabsRect,
      );

      await tester.tap(find.text('阅读'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(panelKey)), initialPanelRect);
      expect(
        tester.getRect(find.byKey(const Key('reader-display-panel-tabs'))),
        initialTabsRect,
      );
    },
  );

  test('applyToReaderContentTheme drives ThreadDetailNativePalette across cross-brightness canvases', () {
    final lightApp = AppTheme.build(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.light,
    );
    final darkApp = AppTheme.build(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.dark,
    );
    final eInkLight = AppTheme.build(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.light,
      eInkMode: true,
    );

    final blackOnLight = ReaderPanelPalette.fromCanvas(
      canvasBackground: Colors.black,
      baseTheme: lightApp,
    ).applyToReaderContentTheme(lightApp);
    final blackNative = ThreadDetailNativePalette.resolve(blackOnLight);
    expect(blackOnLight.brightness, Brightness.dark);
    expect(blackNative.background, Colors.black);
    expect(blackNative.card.computeLuminance(), lessThan(0.1));
    expect(blackNative.bodyText.computeLuminance(), greaterThan(0.7));

    final whiteOnDark = ReaderPanelPalette.fromCanvas(
      canvasBackground: Colors.white,
      baseTheme: darkApp,
    ).applyToReaderContentTheme(darkApp);
    final whiteNative = ThreadDetailNativePalette.resolve(whiteOnDark);
    expect(whiteOnDark.brightness, Brightness.light);
    expect(whiteNative.background, Colors.white);
    expect(whiteNative.card.computeLuminance(), greaterThan(0.8));
    expect(whiteNative.bodyText.computeLuminance(), lessThan(0.2));

    final eInkBlack = ReaderPanelPalette.fromCanvas(
      canvasBackground: Colors.black,
      baseTheme: eInkLight,
    ).applyToReaderContentTheme(eInkLight);
    final eInkNative = ThreadDetailNativePalette.resolve(eInkBlack);
    expect(eInkNative.background, Colors.black);
    expect(eInkNative.bodyText, Colors.white);
    expect(eInkNative.accent, Colors.white);
  });
}
