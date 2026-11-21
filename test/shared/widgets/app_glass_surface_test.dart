import 'package:flutter/material.dart';
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:prism_ui/liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  Widget surface(AppGlassLevel level, {ThemeData? theme, bool eInk = false}) {
    return LocalizedTestApp(
      theme: theme,
      builder: eInk
          ? (context, child) => EInkModeScope(enabled: true, child: child!)
          : null,
      home: Scaffold(
        body: Center(
          child: AppGlassSurface(
            key: const Key('glass-surface'),
            level: level,
            borderRadius: 24,
            child: const SizedBox(
              key: Key('glass-content'),
              width: 200,
              height: 80,
              child: Text('玻璃内容'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('off renders the theme surface without glass', (tester) async {
    await tester.pumpWidget(surface(AppGlassLevel.off));

    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.byKey(const Key('glass-content')), findsOneWidget);
  });

  testWidgets('off paints no material elevation', (tester) async {
    await tester.pumpWidget(surface(AppGlassLevel.off));

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('glass-surface')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.elevation, 0);
  });

  testWidgets('standard and enhanced render the glass surface', (tester) async {
    for (final level in [AppGlassLevel.standard, AppGlassLevel.enhanced]) {
      await tester.pumpWidget(surface(level));

      expect(find.byType(LiquidGlass), findsOneWidget);
      expect(find.byKey(const Key('glass-content')), findsOneWidget);
    }
  });

  test('light toolbar glass draws no shadow; dark shadow is bounded', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(AppGlassSurface.shadowsOf(light.colorScheme, eInk: false), isEmpty);

    final shadows = AppGlassSurface.shadowsOf(dark.colorScheme, eInk: false);
    expect(shadows, hasLength(1));
    expect(shadows.single.blurRadius, inInclusiveRange(10, 14));
    expect(shadows.single.color.a, lessThanOrEqualTo(0.18));
  });

  test('eink mode draws no toolbar shadow in either brightness', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(AppGlassSurface.shadowsOf(theme.colorScheme, eInk: true), isEmpty);
    }
  });

  testWidgets('dark glass carries the bounded shadow', (tester) async {
    await tester.pumpWidget(
      surface(AppGlassLevel.standard, theme: AppTheme.dark()),
    );

    final glass = tester.widget<LiquidGlass>(find.byType(LiquidGlass));
    expect(glass.shadows, hasLength(1));
    expect(glass.shadows.single.blurRadius, inInclusiveRange(10, 14));
    expect(glass.shadows.single.color.a, lessThanOrEqualTo(0.18));
  });

  testWidgets('light glass carries no shadow', (tester) async {
    await tester.pumpWidget(
      surface(AppGlassLevel.standard, theme: AppTheme.light()),
    );

    final glass = tester.widget<LiquidGlass>(find.byType(LiquidGlass));
    expect(glass.shadows, isEmpty);
  });

  testWidgets('eink forces opaque bordered zero-elevation surface over glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface(AppGlassLevel.standard, theme: AppTheme.dark(), eInk: true),
    );

    expect(find.byType(LiquidGlass), findsNothing);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('glass-surface')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.elevation, 0);
    expect(
      material.shape,
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.eInkBorderColor(Brightness.dark)),
      ),
    );
  });

  testWidgets('AppPrismTheme applies high-contrast bordered buttons in eink', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.build(
          family: AppThemeFamily.warmPaper,
          brightness: Brightness.light,
          eInkMode: true,
        ),
        builder: (context, child) =>
            EInkModeScope(enabled: true, child: child!),
        home: Scaffold(
          body: AppPrismTheme(
            child: Builder(
              builder: (context) {
                final buttonTheme = prism_button.ButtonTheme.of(context);
                expect(
                  buttonTheme.filled?.side?.resolve(const <WidgetState>{}),
                  BorderSide(color: AppTheme.eInkBorderColor(Brightness.light)),
                );
                expect(
                  buttonTheme.text?.side?.resolve(const <WidgetState>{}),
                  BorderSide(color: AppTheme.eInkBorderColor(Brightness.light)),
                );
                return prism_button.TextButton(
                  onPressed: () {},
                  child: const Text('确认'),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('确认'), findsOneWidget);
  });

  testWidgets('high contrast falls back to the opaque surface', (tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: child!,
        ),
        home: const Scaffold(
          body: AppGlassSurface(
            level: AppGlassLevel.enhanced,
            borderRadius: 24,
            child: SizedBox(width: 100, height: 50),
          ),
        ),
      ),
    );

    expect(find.byType(LiquidGlass), findsNothing);
  });
}
