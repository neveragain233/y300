import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

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
}
