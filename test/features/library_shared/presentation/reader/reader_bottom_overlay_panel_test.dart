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
  testWidgets('ReaderBottomOverlayPanel renders actions in order', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPanel(
        actions: [
          _action(id: 'catalog', icon: Icons.list, label: '目录'),
          _action(id: 'display', icon: Icons.tune, label: '显示'),
          _action(id: 'cache', icon: Icons.download, label: '缓存'),
        ],
      ),
    );

    final catalogCenter = tester.getCenter(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
    );
    final displayCenter = tester.getCenter(
      find.byKey(const Key('shared-reader-bottom-action-display')),
    );
    final cacheCenter = tester.getCenter(
      find.byKey(const Key('shared-reader-bottom-action-cache')),
    );

    expect(catalogCenter.dx, lessThan(displayCenter.dx));
    expect(displayCenter.dx, lessThan(cacheCenter.dx));
  });

  testWidgets('ReaderBottomOverlayPanel disabled action cannot be tapped', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _buildPanel(
        actions: [
          _action(
            id: 'cache',
            icon: Icons.download,
            label: '缓存',
            enabled: false,
            onPressed: () => taps += 1,
          ),
        ],
      ),
    );

    await tester.tap(
      find.byKey(const Key('shared-reader-bottom-action-cache')),
    );
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('ReaderBottomOverlayPanel can hide progress control', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPanel(
        includeProgress: false,
        actions: [_action(id: 'catalog', icon: Icons.list, label: '目录')],
      ),
    );

    expect(
      find.byKey(const Key('shared-reader-progress-slider')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
      findsOneWidget,
    );
  });

  testWidgets(
    'action row renders separate circular compact buttons instead of merged pill',
    (tester) async {
      await tester.pumpWidget(
        _buildPanel(
          actions: [
            _action(id: 'mode', icon: Icons.swap_horiz, label: '翻页模式'),
            _action(id: 'catalog', icon: Icons.list, label: '目录'),
            _action(id: 'display', icon: Icons.tune, label: '显示'),
            _action(id: 'download', icon: Icons.download, label: '下载'),
          ],
        ),
      );

      final keys = [
        const Key('shared-reader-bottom-action-mode'),
        const Key('shared-reader-bottom-action-catalog'),
        const Key('shared-reader-bottom-action-display'),
        const Key('shared-reader-bottom-action-download'),
      ];
      final rects = [
        for (final key in keys) tester.getRect(_surfaceOf(find.byKey(key))),
      ];

      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].width, moreOrLessEquals(32, epsilon: 0.01));
        expect(rects[i].height, moreOrLessEquals(32, epsilon: 0.01));
        expect(
          tester.getSize(find.byKey(keys[i])).shortestSide,
          greaterThanOrEqualTo(48),
        );
        if (i > 0) {
          expect(rects[i].left, greaterThan(rects[i - 1].right));
        }
      }

      // 动作组在底栏居中。
      final panelWidth = tester
          .getSize(find.byKey(const Key('shared-reader-bottom-overlay-panel')))
          .width;
      expect(
        (rects.first.left + rects.last.right) / 2,
        moreOrLessEquals(panelWidth / 2, epsilon: 0.5),
      );
    },
  );

  testWidgets('action row stays centered and within 480 at wide widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _buildPanel(
        actions: [
          _action(id: 'mode', icon: Icons.swap_horiz, label: '翻页模式'),
          _action(id: 'catalog', icon: Icons.list, label: '目录'),
          _action(id: 'display', icon: Icons.tune, label: '显示'),
          _action(id: 'download', icon: Icons.download, label: '下载'),
        ],
      ),
    );

    final first = tester.getRect(
      _surfaceOf(find.byKey(const Key('shared-reader-bottom-action-mode'))),
    );
    final last = tester.getRect(
      _surfaceOf(find.byKey(const Key('shared-reader-bottom-action-download'))),
    );
    expect(last.right - first.left, lessThanOrEqualTo(480));
    expect(
      (first.left + last.right) / 2,
      moreOrLessEquals(1400 / 2, epsilon: 0.5),
    );
  });

  testWidgets('compact prev and next use the same size tier', (tester) async {
    await tester.pumpWidget(_buildPanel(actions: []));

    final previous = find.byKey(const Key('shared-reader-prev-button'));
    final next = find.byKey(const Key('shared-reader-next-button'));
    for (final finder in [previous, next]) {
      expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
      final surface = tester.getRect(_surfaceOf(finder));
      expect(surface.width, 32);
      expect(surface.height, 32);
    }
  });

  testWidgets('glass off and high contrast fall back to reader chrome color', (
    tester,
  ) async {
    final theme = AppTheme.light();
    final palette = const ReaderChromePaletteResolver().resolve(theme);
    for (final sample in [
      (level: AppGlassLevel.off, highContrast: false),
      (level: AppGlassLevel.standard, highContrast: true),
    ]) {
      await tester.pumpWidget(
        _buildPanel(
          theme: theme,
          glassLevel: sample.level,
          highContrast: sample.highContrast,
          actions: [
            _action(id: 'mode', icon: Icons.swap_horiz, label: '翻页模式'),
            _action(id: 'catalog', icon: Icons.list, label: '目录'),
            _action(id: 'download', icon: Icons.download, label: '下载'),
          ],
        ),
      );

      expect(find.byType(LiquidGlass), findsNothing);
      for (final key in [
        const Key('shared-reader-bottom-action-mode'),
        const Key('shared-reader-bottom-action-download'),
        const Key('shared-reader-prev-button'),
        const Key('shared-reader-next-button'),
      ]) {
        final surface = find.descendant(
          of: _surfaceOf(find.byKey(key)),
          matching: find.byType(Material),
        );
        expect(
          tester.widget<Material>(surface.first).color,
          palette.chromeBackground,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('each circular button owns one glass layer', (tester) async {
    await tester.pumpWidget(
      _buildPanel(
        glassLevel: AppGlassLevel.standard,
        actions: [
          _action(id: 'mode', icon: Icons.swap_horiz, label: '翻页模式'),
          _action(id: 'catalog', icon: Icons.list, label: '目录'),
          _action(id: 'display', icon: Icons.tune, label: '显示'),
          _action(id: 'download', icon: Icons.download, label: '下载'),
        ],
      ),
    );

    // 四个独立底栏圆钮与进度行两端各一层玻璃。
    expect(find.byType(LiquidGlass), findsNWidgets(6));
  });
}

/// 动作键所在 Stack 内的玻璃表面（独立键与组内键同层绘制）。
Finder _surfaceOf(Finder button) => find
    .descendant(
      of: find.ancestor(of: button, matching: find.byType(Stack)).first,
      matching: find.byType(AppGlassSurface),
    )
    .first;

Widget _buildPanel({
  required List<ReaderToolbarAction> actions,
  bool includeProgress = true,
  ThemeData? theme,
  AppGlassLevel? glassLevel,
  bool highContrast = false,
}) {
  return LocalizedTestApp(
    theme: theme,
    builder: (context, child) {
      Widget content = MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        child: child!,
      );
      if (glassLevel != null) {
        content = AppGlassEnvironment(glassLevel: glassLevel, child: content);
      }
      return content;
    },
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ReaderBottomOverlayPanel(
          config: ReaderBottomBarConfig(
            actions: actions,
            progress: includeProgress
                ? ReaderProgressConfig(
                    current: 1,
                    total: 10,
                    onChanged: (_) {},
                    onChangeEnd: (_) {},
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

ReaderToolbarAction _action({
  required String id,
  required IconData icon,
  required String label,
  bool enabled = true,
  VoidCallback? onPressed,
}) {
  return ReaderToolbarAction(
    id: id,
    icon: icon,
    label: label,
    enabled: enabled,
    onPressed: onPressed ?? () {},
  );
}
