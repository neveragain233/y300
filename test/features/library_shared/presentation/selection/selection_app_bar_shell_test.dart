import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/features/library_shared/presentation/selection/selection_app_bar.dart';
import 'package:y300/l10n/app_localizations_zh.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

import '../../../../test_support/localized_test_app.dart';

/// 选择态顶栏与压入页共用外壳：页面表面、圆形关闭键、标题层级和动作胶囊。
void main() {
  testWidgets('selection app bar reuses the page app bar shell', (
    tester,
  ) async {
    const surface = Color(0xFFF2EDE6);
    final l10n = AppLocalizationsZh();
    var closeCount = 0;
    var selectAllCount = 0;
    var invertCount = 0;

    await tester.pumpWidget(
      LocalizedTestApp(
        theme: ThemeData(
          scaffoldBackgroundColor: surface,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          appBar: SelectionAppBar(
            selectedCount: 3,
            l10n: l10n,
            onClose: () => closeCount += 1,
            onSelectAll: () => selectAllCount += 1,
            onInvertSelection: () => invertCount += 1,
          ),
        ),
      ),
    );

    final context = tester.element(find.byKey(const Key('selection-app-bar')));
    final scheme = Theme.of(context).colorScheme;
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, surface);
    expect(find.text(l10n.librarySelectionSelectedCount(3)), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('selection-app-bar-title')))
          .style
          ?.fontWeight,
      FontWeight.w600,
    );

    // 关闭键是公共玻璃单按钮：键落在内部按压按钮上，玻璃圆底与按钮同层。
    final close = tester.widget<IconButton>(
      find.byKey(const Key('selection-app-bar-close')),
    );
    expect(
      close.style?.backgroundColor?.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    expect(
      tester
          .widget<AppGlassSurface>(
            find.descendant(
              of: find.byType(AppToolbarCloseButton),
              matching: find.byType(AppGlassSurface),
            ),
          )
          .baseColor,
      scheme.surfaceContainerHigh,
    );
    for (final key in const [
      Key('selection-app-bar-close'),
      Key('selection-app-bar-select-all'),
      Key('selection-app-bar-invert'),
    ]) {
      expect(
        tester.getSize(find.byKey(key)).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }

    // 相关动作共用一块胶囊玻璃，末项保留独立圆键；关闭档没有玻璃捕获。
    expect(find.byType(LiquidGlass), findsNothing);
    final actionSurfaces = find.descendant(
      of: find.byType(AppToolbarActions),
      matching: find.byType(AppGlassSurface),
    );
    expect(actionSurfaces, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      expect(
        tester.widget<AppGlassSurface>(actionSurfaces.at(index)).baseColor,
        scheme.surfaceContainerHigh,
      );
    }

    await tester.tap(find.byKey(const Key('selection-app-bar-close')));
    await tester.tap(find.byKey(const Key('selection-app-bar-select-all')));
    await tester.tap(find.byKey(const Key('selection-app-bar-invert')));
    expect(closeCount, 1);
    expect(selectAllCount, 1);
    expect(invertCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection app bar shares the app root glass source', (
    tester,
  ) async {
    final l10n = AppLocalizationsZh();
    await tester.pumpWidget(
      LocalizedTestApp(
        builder: (context, child) => AppGlassEnvironment(
          glassLevel: AppGlassLevel.standard,
          child: child!,
        ),
        home: Scaffold(
          appBar: SelectionAppBar(
            selectedCount: 2,
            l10n: l10n,
            onClose: () {},
            onSelectAll: () {},
            onInvertSelection: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // 关闭键、相关动作胶囊与末项圆键各一块玻璃，来源仍是应用根唯一宿主。
    expect(find.byType(AppGlassSurface), findsNWidgets(3));
    expect(find.byType(LiquidGlass), findsNWidgets(3));
    expect(find.byType(LiquidGlassHost), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiquidGlassHost),
        matching: find.byType(LiquidGlass),
      ),
      findsNWidgets(3),
    );
    await tester.tap(find.byKey(const Key('selection-app-bar-close')));
    expect(tester.takeException(), isNull);
  });
}
