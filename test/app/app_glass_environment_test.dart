import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/y300_app.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

import '../test_support/localized_test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Widget environmentApp({
    required AppGlassLevel level,
    required Widget home,
    bool highContrast = false,
  }) {
    return LocalizedTestApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        child: AppGlassEnvironment(glassLevel: level, child: child!),
      ),
      home: home,
    );
  }

  testWidgets('standard and enhanced expose one enabled captured host', (
    tester,
  ) async {
    const expectedQuality = {
      AppGlassLevel.standard: LiquidGlassQuality.standard,
      AppGlassLevel.enhanced: LiquidGlassQuality.ultra,
    };
    for (final entry in expectedQuality.entries) {
      await tester.pumpWidget(
        environmentApp(
          level: entry.key,
          home: _glassScaffold(level: entry.key),
        ),
      );
      await tester.pump();

      final scope = tester.widget<LiquidGlassScope>(
        find.byType(LiquidGlassScope),
      );
      expect(scope.enabled, isTrue);
      expect(scope.quality, entry.value);
      expect(
        LiquidGlassScope.qualityOf(tester.element(find.byKey(_paneKey))),
        entry.value,
      );
      expect(
        tester.widget<LiquidGlassHost>(find.byType(LiquidGlassHost)).enabled,
        isTrue,
      );
      expect(
        find.ancestor(
          of: find.byType(LiquidGlassHost),
          matching: find.byType(LiquidGlassScope),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(LiquidGlass),
          matching: find.byType(LiquidGlassHost),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('off and high contrast disable capture', (tester) async {
    const samples = [
      (level: AppGlassLevel.off, highContrast: false),
      (level: AppGlassLevel.standard, highContrast: true),
      (level: AppGlassLevel.enhanced, highContrast: true),
    ];
    for (final sample in samples) {
      await tester.pumpWidget(
        environmentApp(
          level: sample.level,
          highContrast: sample.highContrast,
          home: _glassScaffold(level: sample.level),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<LiquidGlassScope>(find.byType(LiquidGlassScope)).enabled,
        isFalse,
      );
      expect(
        tester.widget<LiquidGlassHost>(find.byType(LiquidGlassHost)).enabled,
        isFalse,
      );
      expect(
        LiquidGlassScope.of(tester.element(find.byKey(_paneKey))),
        isFalse,
      );
      // 两类禁用档下 AppGlassSurface 退回主题实色，没有必要捕获的面板。
      expect(find.byType(LiquidGlass), findsNothing);
      expect(find.byKey(_paneKey), findsOneWidget);
    }
  });

  testWidgets('app root covers pushed routes and root panels with one host', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(_SignedOutSession.new),
        ],
        child: const Y300App(
          enableAppUpdatePrompt: false,
          home: _GlassRouteLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hostElement = tester.element(find.byType(LiquidGlassHost));
    expect(find.byType(LiquidGlassHost), findsOneWidget);
    expect(
      tester.widget<LiquidGlassHost>(find.byType(LiquidGlassHost)).enabled,
      isTrue,
    );
    expect(
      tester.widget<LiquidGlassScope>(find.byType(LiquidGlassScope)).enabled,
      isTrue,
    );

    // 普通路由 push 后仍使用同一个宿主，且路由内的面板读到启用档。
    await tester.tap(find.byKey(const Key('open-glass-route')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glass-route-page')), findsOneWidget);
    expect(tester.element(find.byType(LiquidGlassHost)), same(hostElement));
    expect(find.byType(LiquidGlassHost), findsOneWidget);
    expect(
      LiquidGlassScope.of(
        tester.element(find.byKey(const Key('glass-route-pane'))),
      ),
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.byType(LiquidGlass),
        matching: find.byType(LiquidGlassHost),
      ),
      findsOneWidget,
    );

    // 根导航模态面板不在路由页面内，但同样落在应用根宿主之下。
    await tester.tap(find.byKey(const Key('open-glass-panel')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(tester.element(find.byType(LiquidGlassHost)), same(hostElement));
    expect(
      LiquidGlassScope.of(
        tester.element(find.byKey(const Key('glass-panel-pane'))),
      ),
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.descendant(of: sheet, matching: find.byType(LiquidGlass)),
        matching: find.byType(LiquidGlassHost),
      ),
      findsOneWidget,
    );

    // 关闭档从应用根设置生效，宿主随之停止捕获。
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('glass-panel-pane'))),
    );
    await container
        .read(appAppearanceControllerProvider.notifier)
        .setGlassLevel(AppGlassLevel.off);
    await tester.pumpAndSettle();
    expect(
      tester.widget<LiquidGlassHost>(find.byType(LiquidGlassHost)).enabled,
      isFalse,
    );
    expect(
      tester.widget<LiquidGlassScope>(find.byType(LiquidGlassScope)).enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

const _paneKey = Key('glass-pane');

Widget _glassScaffold({required AppGlassLevel level}) {
  return Scaffold(
    body: Center(
      child: AppGlassSurface(
        level: level,
        borderRadius: 24,
        child: const SizedBox(key: _paneKey, width: 160, height: 48),
      ),
    ),
  );
}

class _SignedOutSession extends AuthSessionController {
  @override
  Future<AuthSessionViewState> build() async =>
      const AuthSessionViewState.signedOut();
}

class _GlassRouteLauncher extends StatelessWidget {
  const _GlassRouteLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-glass-route'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _GlassRoutePage()),
          ),
          child: const Text('打开分栏详情'),
        ),
      ),
    );
  }
}

class _GlassRoutePage extends StatelessWidget {
  const _GlassRoutePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('glass-route-page'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppGlassSurface(
              level: AppGlassLevel.standard,
              borderRadius: 24,
              child: SizedBox(
                key: Key('glass-route-pane'),
                width: 160,
                height: 48,
              ),
            ),
            FilledButton(
              key: const Key('open-glass-panel'),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  builder: (_) => const _GlassPanel(),
                );
              },
              child: const Text('打开面板'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 140,
      child: Center(
        child: AppGlassSurface(
          level: AppGlassLevel.standard,
          borderRadius: 24,
          child: SizedBox(key: Key('glass-panel-pane'), width: 160, height: 48),
        ),
      ),
    );
  }
}
