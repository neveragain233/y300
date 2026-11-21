import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('ReaderOverlayScaffold hides menu by default', (tester) async {
    await tester.pumpWidget(_buildScaffold());

    final top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    final bottom = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-bottom-overlay-hit-test-gate')),
    );

    expect(top.ignoring, isTrue);
    expect(bottom.ignoring, isTrue);
  });

  testWidgets('ReaderOverlayScaffold center tap toggles menu visibility', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScaffold());

    await tester.tapAt(const Offset(400, 300));
    await _pumpTapAndOverlayAnimation(tester);

    var top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(top.ignoring, isFalse);

    await tester.tapAt(const Offset(400, 300));
    await _pumpTapAndOverlayAnimation(tester);

    top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(top.ignoring, isTrue);
  });

  testWidgets('ReaderOverlayScaffold respects initially visible menu', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScaffold(menuInitiallyVisible: true));

    final top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );

    expect(top.ignoring, isFalse);
  });

  testWidgets('ReaderOverlayScaffold overlay action triggers callback', (
    tester,
  ) async {
    var actionTaps = 0;
    await tester.pumpWidget(
      _buildScaffold(
        menuInitiallyVisible: true,
        topActions: [
          ReaderToolbarAction(
            id: 'search',
            icon: Icons.search,
            label: '搜索',
            onPressed: () => actionTaps += 1,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('shared-reader-top-action-search')));
    await tester.pump();

    expect(actionTaps, 1);
  });

  testWidgets('overlay controls are excluded from reader tap zones', (
    tester,
  ) async {
    var actionTaps = 0;
    final controller = ReaderOverlayController()..showMenu();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _buildScaffold(
        controller: controller,
        bottomActions: [
          ReaderToolbarAction(
            id: 'display',
            icon: Icons.tune,
            label: '显示',
            onPressed: () => actionTaps += 1,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    await tester.pump(const Duration(milliseconds: 330));

    expect(actionTaps, 1);
    expect(controller.isMenuVisible, isTrue);
  });

  testWidgets('ReaderOverlayScaffold center callback keeps default toggle', (
    tester,
  ) async {
    var centerTaps = 0;
    await tester.pumpWidget(_buildScaffold(onCenterTap: () => centerTaps += 1));

    await tester.tapAt(const Offset(400, 300));
    await _pumpTapAndOverlayAnimation(tester);

    final top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(centerTaps, 1);
    expect(top.ignoring, isFalse);
  });

  testWidgets('ReaderOverlayScaffold controller can hide visible menu', (
    tester,
  ) async {
    final controller = ReaderOverlayController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_buildScaffold(controller: controller));

    await tester.tapAt(const Offset(400, 300));
    await _pumpTapAndOverlayAnimation(tester);

    var top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(top.ignoring, isFalse);
    expect(controller.isMenuVisible, isTrue);

    controller.hideMenu();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    top = tester.widget<IgnorePointer>(
      find.byKey(const Key('shared-reader-top-overlay-hit-test-gate')),
    );
    expect(top.ignoring, isTrue);
    expect(controller.isMenuVisible, isFalse);
  });

  testWidgets(
    'ReaderOverlayScaffold uses reader chrome background in dark theme',
    (tester) async {
      final theme = AppTheme.dark();
      final palette = const ReaderChromePaletteResolver().resolve(theme);

      await tester.pumpWidget(
        _buildScaffold(theme: theme, menuInitiallyVisible: true),
      );

      final top = tester.widget<Material>(
        find.byKey(const Key('shared-reader-top-overlay-bar')),
      );
      final bottom = tester.widget<Material>(
        find.byKey(const Key('shared-reader-bottom-overlay-panel')),
      );

      expect(top.color, palette.chromeBackground);
      expect(bottom.color, palette.chromeBackground);
    },
  );
  testWidgets(
    'hidden overlays release focus and semantics without changing the body',
    (tester) async {
      final controller = ReaderOverlayController()..showMenu();
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildScaffold(
          controller: controller,
          topActions: [
            ReaderToolbarAction(
              id: 'search',
              icon: Icons.search,
              label: '查找章节',
              onPressed: () {},
            ),
          ],
        ),
      );
      final body = find.byKey(const Key('reader-test-body'));
      final element = tester.element(body);
      final rect = tester.getRect(body);
      final focus = Focus.of(tester.element(find.byIcon(Icons.search)));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      bool hasAction() => tester.semantics
          .simulatedAccessibilityTraversal()
          .any((node) => node.getSemanticsData().tooltip == '查找章节');
      expect(hasAction(), isTrue);
      controller.hideMenu();
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(hasAction(), isFalse);
      expect(tester.element(body), same(element));
      expect(tester.getRect(body), rect);
      semantics.dispose();
    },
  );

  testWidgets(
    'large phone toolbar respects reduced motion and preserves body budget',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 650);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ReaderOverlayController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _buildScaffold(
          controller: controller,
          textScale: 2,
          reduceMotion: true,
          animationDuration: const Duration(milliseconds: 600),
        ),
      );
      final before = tester.getRect(find.byKey(const Key('reader-test-body')));
      controller.showMenu();
      await tester.pump();
      final top = tester.widget<SlideTransition>(
        find.descendant(
          of: find.byKey(const Key('shared-reader-top-overlay')),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(top.position.value, Offset.zero);
      expect(tester.getRect(find.byKey(const Key('reader-test-body'))), before);
      controller.hideMenu();
      await tester.pump();
      expect(top.position.value, const Offset(0, -1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reader top buttons follow app glass and fall back to chrome', (
    tester,
  ) async {
    final theme = AppTheme.light();
    final palette = const ReaderChromePaletteResolver().resolve(theme);
    final back = find.byKey(const Key('shared-reader-top-back-button'));
    final action = find.byKey(const Key('shared-reader-top-action-search'));
    final topActions = [
      ReaderToolbarAction(
        id: 'search',
        icon: Icons.search,
        label: '查找章节',
        onPressed: () {},
      ),
    ];

    Future<void> pump({
      required AppGlassLevel? level,
      bool highContrast = false,
    }) async {
      await tester.pumpWidget(
        _buildScaffold(
          theme: theme,
          menuInitiallyVisible: true,
          topActions: topActions,
          glassLevel: level,
          highContrast: highContrast,
        ),
      );
      await tester.pump();
    }

    Finder surfaceOf(Finder button) => find.descendant(
      of: find.ancestor(of: button, matching: find.byType(Stack)).first,
      matching: find.byType(AppGlassSurface),
    );

    for (final level in [AppGlassLevel.standard, AppGlassLevel.enhanced]) {
      await pump(level: level);
      // 返回键、动作胶囊与进度行两端的紧凑按钮各一块玻璃，来源是应用根唯一宿主。
      expect(find.byType(LiquidGlass), findsNWidgets(4));
      expect(find.byType(LiquidGlassHost), findsOneWidget);
      expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
      // 独立返回键的玻璃与按钮同层绘制（48 命中区内收视觉圆底）；
      // 胶囊内的动作共用动作胶囊那一层玻璃。
      expect(surfaceOf(back), findsOneWidget);
      expect(surfaceOf(action), findsOneWidget);
      expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
    }

    for (final sample in [
      (level: AppGlassLevel.off, highContrast: false),
      (level: AppGlassLevel.standard, highContrast: true),
    ]) {
      await pump(level: sample.level, highContrast: sample.highContrast);
      expect(find.byType(LiquidGlass), findsNothing);
      for (final surfaceFinder in [
        surfaceOf(back).first,
        surfaceOf(action).first,
      ]) {
        expect(
          tester.widget<AppGlassSurface>(surfaceFinder).baseColor,
          palette.chromeBackground,
        );
        expect(
          tester
              .widget<Material>(
                find
                    .descendant(
                      of: surfaceFinder,
                      matching: find.byType(Material),
                    )
                    .first,
              )
              .color,
          palette.chromeBackground,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'persistentFooter overlays bottom without shrinking body and tracks dismissal',
    (tester) async {
      final controller = ReaderOverlayController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _buildScaffold(
          controller: controller,
          animationDuration: const Duration(milliseconds: 200),
          persistentFooter: const SizedBox(
            key: Key('test-persistent-footer'),
            height: 28,
          ),
        ),
      );

      final scaffoldSize = tester.getSize(
        find.byKey(const Key('shared-reader-overlay-scaffold')),
      );
      expect(
        tester.getSize(find.byKey(const Key('reader-test-body'))),
        scaffoldSize,
      );
      expect(
        tester
            .getBottomLeft(find.byKey(const Key('test-persistent-footer')))
            .dy,
        scaffoldSize.height,
      );
      expect(controller.isOverlayDismissed, isTrue);

      controller.showMenu();
      await tester.pump();
      expect(controller.isOverlayDismissed, isFalse);
      await tester.pump(const Duration(milliseconds: 220));
      expect(controller.isOverlayDismissed, isFalse);

      controller.hideMenu();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isOverlayDismissed, isFalse);

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();
      expect(controller.isOverlayDismissed, isTrue);
    },
  );
}

Future<void> _pumpTapAndOverlayAnimation(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 330));
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pump();
}

Widget _buildScaffold({
  bool menuInitiallyVisible = false,
  List<ReaderToolbarAction> topActions = const <ReaderToolbarAction>[],
  List<ReaderToolbarAction> bottomActions = const <ReaderToolbarAction>[],
  Widget? persistentFooter,
  VoidCallback? onCenterTap,
  ReaderOverlayController? controller,
  ThemeData? theme,
  double textScale = 1,
  bool reduceMotion = false,
  Duration animationDuration = Duration.zero,
  AppGlassLevel? glassLevel,
  bool highContrast = false,
}) {
  return LocalizedTestApp(
    theme: theme,
    builder: (context, child) {
      final content = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          highContrast: highContrast,
        ),
        child: child!,
      );
      return glassLevel == null
          ? content
          : AppGlassEnvironment(glassLevel: glassLevel, child: content);
    },
    home: Scaffold(
      body: ReaderOverlayScaffold(
        controller: controller,
        menuInitiallyVisible: menuInitiallyVisible,
        animationDuration: animationDuration,
        onCenterTap: onCenterTap,
        persistentFooter: persistentFooter,
        topBar: ReaderTopBarConfig(
          title: '作品名',
          subtitle: '章节名',
          actions: topActions,
          onBack: () {},
        ),
        bottomBar: ReaderBottomBarConfig(
          progress: ReaderProgressConfig(
            current: 1,
            total: 10,
            onChanged: (_) {},
            onChangeEnd: (_) {},
          ),
          actions: bottomActions,
        ),
        child: const ColoredBox(
          key: Key('reader-test-body'),
          color: Colors.white,
        ),
      ),
    ),
  );
}
