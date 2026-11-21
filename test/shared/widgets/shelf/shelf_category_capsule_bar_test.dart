import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/shelf/shelf_category_capsule_bar.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';

void main() {
  testWidgets(
    'selected capsule uses prism glass lens and ElasticPress without InkWell',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        var tapped = -1;
        final theme = ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.brown,
        );
        final palette = const ShelfThemePaletteResolver().resolve(theme);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: LiquidGlassScope(
              enabled: true,
              quality: LiquidGlassQuality.standard,
              child: Scaffold(
                body: ShelfCategoryCapsuleBar(
                  tabs: const <ShelfCategoryCapsuleTab>[
                    ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
                    ShelfCategoryCapsuleTab(id: 'b', label: '漫画·追更'),
                  ],
                  selectedIndex: 0,
                  onTap: (index) => tapped = index,
                  indicatorKey: const Key('indicator'),
                  tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final indicator = find.byKey(const Key('indicator'));
        expect(indicator, findsOneWidget);
        expect(find.byType(InkWell), findsNothing);
        expect(find.byType(ElasticPress), findsNWidgets(2));
        expect(find.byType(AppGlassSurface), findsNWidgets(2));

        final decorated = tester.widget<DecoratedBox>(
          find.descendant(of: indicator, matching: find.byType(DecoratedBox)),
        );
        final shape = decorated.decoration as ShapeDecoration;
        expect(
          shape.color,
          palette.categorySelectedBackground.withValues(alpha: 0.86),
        );

        final tabA = find.byKey(const ValueKey<String>('tab-a'));
        expect(tester.getSize(tabA).height, greaterThanOrEqualTo(48));
        final node = tester.getSemantics(tabA);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isSelected, Tristate.isTrue);

        await tester.tap(find.byKey(const ValueKey<String>('tab-b')));
        expect(tapped, 1);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'eInk mode drops ElasticPress and glass surfaces in favor of static high-contrast borders',
    (tester) async {
      final theme = AppTheme.build(
        family: AppThemeFamily.warmPaper,
        brightness: Brightness.light,
        eInkMode: true,
      );
      final palette = const ShelfThemePaletteResolver().resolve(theme);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: EInkModeScope(
            enabled: true,
            child: Scaffold(
              body: ShelfCategoryCapsuleBar(
                tabs: const <ShelfCategoryCapsuleTab>[
                  ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
                  ShelfCategoryCapsuleTab(id: 'b', label: '小说·追更'),
                ],
                selectedIndex: 0,
                onTap: (_) {},
                indicatorKey: const Key('indicator'),
                tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElasticPress), findsNothing);
      expect(find.byType(AppGlassSurface), findsNothing);
      final selectedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const Key('indicator')),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (selectedBox.decoration as ShapeDecoration).color,
        palette.categorySelectedBackground,
      );
      final unselectedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('tab-b')),
          matching: find.byType(DecoratedBox),
        ),
      );
      final unselectedShape =
          (unselectedBox.decoration as ShapeDecoration).shape as StadiumBorder;
      expect(unselectedShape.side.color, theme.colorScheme.outlineVariant);
    },
  );

  testWidgets('overflowing capsules scroll the selected tab into view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ShelfCategoryCapsuleBar(
              tabs: const <ShelfCategoryCapsuleTab>[
                ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
                ShelfCategoryCapsuleTab(id: 'b', label: '漫画·默认'),
                ShelfCategoryCapsuleTab(id: 'c', label: '漫画·追更'),
                ShelfCategoryCapsuleTab(id: 'd', label: '小说·默认'),
                ShelfCategoryCapsuleTab(id: 'e', label: '小说·追更'),
                ShelfCategoryCapsuleTab(id: 'f', label: '小说·已完结'),
              ],
              selectedIndex: 5,
              onTap: (_) {},
              indicatorKey: const Key('indicator'),
              tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey<String>('tab-f')));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  });

  testWidgets('capsule bar grows with large text without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ShelfCategoryCapsuleBar(
              tabs: const <ShelfCategoryCapsuleTab>[
                ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
                ShelfCategoryCapsuleTab(id: 'b', label: '漫画·一个很长的分类名称'),
              ],
              selectedIndex: 1,
              onTap: (_) {},
              indicatorKey: const Key('indicator'),
              tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('indicator')), findsOneWidget);
  });
}
