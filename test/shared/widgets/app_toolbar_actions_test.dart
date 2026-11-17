import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  for (final family in AppThemeFamily.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'toolbar glyph uses its button surface foreground in $family $brightness',
        (tester) async {
          final theme = AppTheme.build(family: family, brightness: brightness);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                appBar: AppBar(
                  title: const Text('title'),
                  actions: [
                    AppToolbarActions(
                      children: [
                        IconButton(
                          key: const Key('mail'),
                          icon: const Icon(Icons.mail_outline),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          final glyph = tester.widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('mail')),
              matching: find.byType(RichText),
            ),
          );
          expect(glyph.text.style!.color, theme.colorScheme.onSurface);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('action cap and lone key each get one glass surface', (
    tester,
  ) async {
    for (final level in [AppGlassLevel.standard, AppGlassLevel.enhanced]) {
      await tester.pumpWidget(
        _glassApp(level: level, home: _actionsScaffold(actionCount: 3)),
      );
      await tester.pump();

      // 相关动作一个胶囊、末项一个独立圆键，来源共用应用根宿主。
      expect(find.byType(AppGlassSurface), findsNWidgets(2));
      expect(find.byType(LiquidGlass), findsNWidgets(2));
      expect(find.byType(LiquidGlassHost), findsOneWidget);
      _expectSingleLayer(tester);

      for (final key in [_actionKey(0), _actionKey(1), _actionKey(2)]) {
        expect(
          tester.getSize(find.byKey(key)).shortestSide,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('off and high contrast fall back to the theme surface', (
    tester,
  ) async {
    final theme = AppTheme.light();
    const samples = [
      (level: AppGlassLevel.off, highContrast: false),
      (level: AppGlassLevel.standard, highContrast: true),
      (level: AppGlassLevel.enhanced, highContrast: true),
    ];
    for (final sample in samples) {
      await tester.pumpWidget(
        _glassApp(
          level: sample.level,
          highContrast: sample.highContrast,
          home: _actionsScaffold(actionCount: 2),
        ),
      );
      await tester.pump();

      expect(find.byType(LiquidGlass), findsNothing);
      final surfaces = find.byType(AppGlassSurface);
      expect(surfaces, findsNWidgets(2));
      for (var index = 0; index < 2; index += 1) {
        final material = tester.widget<Material>(
          find
              .descendant(
                of: surfaces.at(index),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, theme.colorScheme.surfaceContainerHigh);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('back and close buttons share the glass button contract', (
    tester,
  ) async {
    for (final level in [AppGlassLevel.standard, AppGlassLevel.off]) {
      await tester.pumpWidget(
        _glassApp(
          level: level,
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppToolbarBackButton(onPressed: () {}),
                  AppToolbarCloseButton(
                    buttonKey: const Key('toolbar-close'),
                    tooltip: '退出选择',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final glass = level == AppGlassLevel.standard;
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(LiquidGlass), glass ? findsNWidgets(2) : findsNothing);
      final close = tester.widget<IconButton>(
        find.byKey(const Key('toolbar-close')),
      );
      expect(close.tooltip, '退出选择');
      expect(
        close.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      for (final finder in [
        find.byType(BackButton),
        find.byKey(const Key('toolbar-close')),
      ]) {
        expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
        expect(
          find.ancestor(of: finder, matching: find.byType(AppGlassSurface)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}

Key _actionKey(int index) => Key('toolbar-action-$index');

Widget _actionsScaffold({required int actionCount}) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('title'),
      actions: [
        AppToolbarActions(
          children: [
            for (var index = 0; index < actionCount; index += 1)
              IconButton(
                key: _actionKey(index),
                onPressed: () {},
                icon: Icon(
                  index.isEven ? Icons.mail_outline : Icons.notifications,
                ),
              ),
          ],
        ),
      ],
    ),
    body: const SizedBox.expand(),
  );
}

Widget _glassApp({
  required AppGlassLevel level,
  required Widget home,
  bool highContrast = false,
}) {
  return LocalizedTestApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: AppGlassEnvironment(glassLevel: level, child: child!),
    ),
    home: home,
  );
}

/// 玻璃表面内部只有透明水波纹层，不再叠第二层实色圆底。
void _expectSingleLayer(WidgetTester tester) {
  final opaqueMaterial = find.byWidgetPredicate(
    (widget) => widget is Material && (widget.color?.a ?? 0) > 0,
  );
  final surfaces = find.byType(AppGlassSurface);
  for (var index = 0; index < 2; index += 1) {
    expect(
      find.descendant(of: surfaces.at(index), matching: opaqueMaterial),
      findsNothing,
    );
  }
}
