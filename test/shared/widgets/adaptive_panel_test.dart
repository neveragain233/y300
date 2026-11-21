import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  for (final useRootNavigator in [false, true]) {
    testWidgets('nested panel respects root ownership $useRootNavigator', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final root = GlobalKey<NavigatorState>();
      final nested = GlobalKey<NavigatorState>();
      String? result;
      await tester.pumpWidget(
        LocalizedTestApp(
          navigatorKey: root,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 200),
              child: Navigator(
                key: nested,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () async {
                        result = await showAdaptivePanel<String>(
                          context: context,
                          useRootNavigator: useRootNavigator,
                          builder: (context) => TextButton(
                            onPressed: () => Navigator.of(context).pop('done'),
                            child: const Text('confirm'),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final panel = find.byKey(const Key('adaptive-side-panel'));
      expect(
        tester.getRect(panel),
        Rect.fromLTWH(useRootNavigator ? 720 : 520, 0, 480, 800),
      );
      expect(
        Navigator.of(tester.element(panel)),
        same(useRootNavigator ? root.currentState : nested.currentState),
      );
      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      expect(result, 'done');
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(400, 800), const Size(1200, 800)]) {
    testWidgets('panel overlays without changing source geometry at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final source = GlobalKey();
      var selections = 0;
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(
              builder: (context) => SizedBox.expand(
                key: source,
                child: TextButton(
                  onPressed: () => showAdaptivePanel<void>(
                    context: context,
                    builder: (context) => SizedBox(
                      height: 240,
                      child: Column(
                        children: [
                          const TextField(),
                          TextButton(
                            onPressed: () {
                              selections++;
                              Navigator.pop(context);
                            },
                            child: Text(
                              AppLocalizations.of(context).commonConfirm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      final element = source.currentContext;
      final before = tester.getRect(find.byKey(source));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(source.currentContext, same(element));
      expect(tester.getRect(find.byKey(source)), before);
      expect(
        find.byKey(const Key('adaptive-side-panel')),
        size.width >= 720 ? findsOneWidget : findsNothing,
      );
      if (size.width >= 720) {
        expect(
          tester.getRect(find.byKey(const Key('adaptive-side-panel'))),
          const Rect.fromLTWH(720, 0, 480, 800),
        );
      }
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(source)), before);
      if (size.width >= 720) {
        expect(
          tester.getRect(find.byKey(const Key('adaptive-side-panel'))).bottom,
          500,
        );
      }
      final l10n = AppLocalizations.of(tester.element(find.byType(TextField)));
      await tester.tap(find.text(l10n.commonConfirm));
      await tester.pumpAndSettle();
      expect(selections, 1);
      expect(find.byType(TextField), findsNothing);
      tester.view.resetViewInsets();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('panel stays on the originating side of a separating hinge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1700, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
            viewPadding: const EdgeInsets.only(top: 24),
            displayFeatures: const [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(820, 0, 60, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.unknown,
              ),
            ],
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Row(
            children: [
              const Spacer(),
              Expanded(
                child: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => showAdaptivePanel<void>(
                        context: context,
                        builder: (_) => const Text('panel'),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('adaptive-side-panel'))),
      const Rect.fromLTWH(1220, 24, 480, 876),
    );
    await tester.tap(find.byKey(const Key('adaptive-panel-close')));
    await tester.pumpAndSettle();
    expect(find.text('panel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel surface falls back to a solid full-height surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => LiquidGlassScope(
          enabled: true,
          quality: LiquidGlassQuality.standard,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showAdaptivePanel<void>(
                  context: context,
                  builder: (_) => const Text('panel'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('adaptive-side-panel'));
    expect(panel, findsOneWidget);
    expect(tester.widget<AppGlassSurface>(panel).level, isNull);
    // 高对比沿用主题实色：不建玻璃层，也不影响面板几何与关闭键。
    expect(
      find.descendant(of: panel, matching: find.byType(LiquidGlass)),
      findsNothing,
    );
    expect(tester.getRect(panel), const Rect.fromLTWH(720, 0, 480, 800));
    expect(find.byKey(const Key('adaptive-panel-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('adaptive-panel-close')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('short panel keeps footer actions reachable with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 420);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var confirmed = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showAdaptivePanel<void>(
                  context: context,
                  builder: (panelContext) => Column(
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (var index = 0; index < 12; index++)
                                SizedBox(height: 56, child: Text('设置项 $index')),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('panel-confirm'),
                        onPressed: () {
                          confirmed++;
                          Navigator.of(panelContext).pop();
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('panel-confirm'));
    expect(confirm, findsOneWidget);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(420));
    await tester.drag(find.text('设置项 0'), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cross-brightness side panel disables glass and uses contrasting close button',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        LocalizedTestApp(
          theme: ThemeData.light(useMaterial3: true),
          home: LiquidGlassScope(
            enabled: true,
            quality: LiquidGlassQuality.standard,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showAdaptivePanel<void>(
                      context: context,
                      backgroundColor: const Color(0xFF171717),
                      builder: (_) => const Text('dark panel'),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('adaptive-side-panel'));
      expect(panel, findsOneWidget);
      expect(tester.widget<AppGlassSurface>(panel).level, AppGlassLevel.off);
      expect(
        find.descendant(of: panel, matching: find.byType(LiquidGlass)),
        findsNothing,
      );

      final closeButton = tester.widget<AppToolbarCloseButton>(
        find.byType(AppToolbarCloseButton),
      );
      expect(closeButton.baseColor, const Color(0xFF171717));
      expect(closeButton.foregroundColor!.computeLuminance(), greaterThan(0.5));
    },
  );
}
