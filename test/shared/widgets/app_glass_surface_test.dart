import 'package:flutter/material.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  Widget surface(AppGlassLevel level) {
    return LocalizedTestApp(
      home: Scaffold(
        body: Center(
          child: AppGlassSurface(
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

  testWidgets('standard and enhanced render the glass surface', (tester) async {
    for (final level in [AppGlassLevel.standard, AppGlassLevel.enhanced]) {
      await tester.pumpWidget(surface(level));

      expect(find.byType(LiquidGlass), findsOneWidget);
      expect(find.byKey(const Key('glass-content')), findsOneWidget);
    }
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
