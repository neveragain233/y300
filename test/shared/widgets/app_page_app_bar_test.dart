import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import '../../test_support/localized_test_app.dart';

/// 压入页顶栏的可选槽位：搜索态与选择态复用同一外壳，不再复制第二套顶栏。
void main() {
  testWidgets('string title keeps the pushed page shell', (tester) async {
    const surface = Color(0xFFF2EDE6);
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: ThemeData(scaffoldBackgroundColor: surface),
        home: const Scaffold(appBar: AppPageAppBar(title: '页面标题')),
      ),
    );

    expect(find.text('页面标题'), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, surface);
    expect(appBar.titleSpacing, 2);
    expect(appBar.centerTitle, isFalse);
    // 首页不可返回时不出现空操作返回键。
    expect(find.byType(AppToolbarBackButton), findsNothing);
  });

  testWidgets('titleWidget, leading and titleSpacing override the slots', (
    tester,
  ) async {
    var leadingTaps = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          appBar: AppPageAppBar(
            leading: IconButton(
              key: const Key('custom-leading'),
              onPressed: () => leadingTaps += 1,
              icon: const Icon(Icons.close),
            ),
            titleWidget: const Text('自定义标题', key: Key('custom-title')),
            titleSpacing: 0,
            actions: [
              IconButton(
                key: const Key('custom-action'),
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('custom-title')), findsOneWidget);
    expect(find.byKey(const Key('custom-leading')), findsOneWidget);
    expect(find.byKey(const Key('custom-action')), findsOneWidget);
    expect(find.byType(AppToolbarActions), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.titleSpacing, 0);
    expect(find.byType(AppToolbarBackButton), findsNothing);

    await tester.tap(find.byKey(const Key('custom-leading')));
    expect(leadingTaps, 1);
  });

  testWidgets('pushed page back button is one glass surface with a 48 target', (
    tester,
  ) async {
    final theme = ThemeData(
      scaffoldBackgroundColor: const Color(0xFFF2EDE6),
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    Future<void> pumpApp({
      required AppGlassLevel level,
      bool highContrast = false,
    }) {
      return tester.pumpWidget(
        LocalizedTestApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: highContrast),
            child: AppGlassEnvironment(glassLevel: level, child: child!),
          ),
          initialRoute: '/page',
          routes: {
            '/': (_) => const Scaffold(body: SizedBox.expand()),
            '/page': (_) =>
                const Scaffold(appBar: AppPageAppBar(title: '页面标题')),
          },
        ),
      );
    }

    for (final level in [AppGlassLevel.standard, AppGlassLevel.enhanced]) {
      await pumpApp(level: level);
      await tester.pump();

      expect(find.byType(AppToolbarBackButton), findsOneWidget);
      expect(find.byType(LiquidGlass), findsOneWidget);
      expect(
        tester.getSize(find.byType(BackButton)).shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .widget<IconButton>(find.byType(BackButton))
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(tester.takeException(), isNull);
    }

    for (final sample in [
      (level: AppGlassLevel.off, highContrast: false),
      (level: AppGlassLevel.standard, highContrast: true),
    ]) {
      await pumpApp(level: sample.level, highContrast: sample.highContrast);
      await tester.pump();

      expect(find.byType(LiquidGlass), findsNothing);
      final surface = tester.widget<AppGlassSurface>(
        find.byType(AppGlassSurface),
      );
      expect(surface.baseColor, theme.colorScheme.surfaceContainerHigh);
      expect(tester.takeException(), isNull);
    }
  });
}
