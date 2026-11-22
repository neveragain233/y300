import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism_popup;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets('opens from the source button and picks one value once', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          const AppPopupMenuItem<String>(
            key: Key('menu-refresh'),
            value: 'refresh',
            label: '刷新页面',
            icon: Icon(Icons.refresh),
          ),
          const AppPopupMenuItem<String>(value: 'compose', label: '发帖'),
        ],
        onSelected: events.add,
        onCanceled: () => events.add('canceled'),
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsOneWidget);
    expect(find.byKey(const Key('menu-refresh')), findsOneWidget);
    expect(events, isEmpty);
    // 无图标项不预留图标列：标签起点比带图标项更靠前。
    expect(
      tester.getRect(find.text('发帖')).left,
      lessThan(tester.getRect(find.text('刷新页面')).left),
    );

    await tester.tap(find.byKey(const Key('menu-refresh')));
    // 选中动作随弹出关闭立即执行，不等待收回动画结束。
    await tester.pump();
    expect(events, ['refresh']);
    await tester.pumpAndSettle();
    // 旧完成回调不再二次执行业务。
    expect(events, ['refresh']);
    expect(find.text('刷新页面'), findsNothing);
    expect(find.byKey(const Key('menu-button')), findsOneWidget);
  });

  testWidgets('a disabled button never opens the menu', (tester) async {
    await tester.pumpWidget(
      _menuApp(
        enabled: false,
        items: (context) => [
          const AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsNothing);
  });

  testWidgets('cancel closes once without running an item or reopening', (
    tester,
  ) async {
    var canceled = 0;
    final selected = <String>[];
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          const AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
        onSelected: selected.add,
        onCanceled: () => canceled++,
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(selected, isEmpty);
    expect(canceled, 1);
    expect(find.text('刷新页面'), findsNothing);
    expect(find.byKey(const Key('menu-button')), findsOneWidget);
  });

  testWidgets('back closes the menu and reports cancellation once', (
    tester,
  ) async {
    var canceled = 0;
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          const AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
        onCanceled: () => canceled++,
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(canceled, 1);
    expect(find.text('刷新页面'), findsNothing);
  });

  testWidgets('a disabled item keeps the menu open and runs nothing', (
    tester,
  ) async {
    final selected = <String>[];
    var canceled = 0;
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          const AppPopupMenuItem<String>(
            key: Key('menu-loading'),
            value: 'loading',
            label: '处理中',
            enabled: false,
          ),
          const AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
        onSelected: selected.add,
        onCanceled: () => canceled++,
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-loading')));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(canceled, 0);
    expect(find.text('刷新页面'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(canceled, 1);
  });

  testWidgets('checked items expose their state', (tester) async {
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          const AppPopupMenuItem<String>(
            key: Key('menu-by-title'),
            value: 'by-title',
            label: '按标题排序',
            checked: true,
          ),
          const AppPopupMenuItem<String>(
            key: Key('menu-by-time'),
            value: 'by-time',
            label: '按时间排序',
            checked: false,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();

    final checked = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(const Key('menu-by-title')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(checked, isSemantics(hasCheckedState: true, isChecked: true));
    final unchecked = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(const Key('menu-by-time')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(unchecked, isSemantics(hasCheckedState: true, isChecked: false));
  });

  testWidgets('divider starts a new group without adding a row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _menuApp(
        items: (context) => const [
          AppPopupMenuItem<String>(value: 'add', label: '新建分类'),
          PopupMenuDivider(),
          AppPopupMenuItem<String>(value: 'refresh', label: '刷新书架'),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('新建分类'), findsOneWidget);
    expect(find.text('刷新书架'), findsOneWidget);
    // 分隔线只画出分组间距，不占一行菜单项。
    final first = tester.getRect(find.text('新建分类'));
    final second = tester.getRect(find.text('刷新书架'));
    expect(second.top - first.bottom, greaterThan(30));
  });

  testWidgets('a long menu scrolls inside the available height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          for (var index = 0; index < 24; index++)
            AppPopupMenuItem<String>(
              key: Key('menu-item-$index'),
              value: '$index',
              label: '菜单项 $index',
            ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();

    final scrollFinder = find.ancestor(
      of: find.byKey(const Key('menu-item-0')),
      matching: find.byType(Scrollable),
    );
    expect(scrollFinder, findsWidgets);
    final position = tester.state<ScrollableState>(scrollFinder.first).position;
    expect(position.maxScrollExtent, greaterThan(0));
    // 菜单高度受可用高度约束，而不是按全部项目撑开。
    expect(
      tester.getRect(find.byKey(const Key('menu-item-23'))).bottom,
      greaterThan(tester.getRect(find.byKey(const Key('menu-button'))).bottom),
    );

    await tester.drag(scrollFinder.first, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('the menu measures its width from the content', (tester) async {
    await tester.pumpWidget(
      _menuApp(
        items: (context) => const [
          AppPopupMenuItem<String>(
            key: Key('menu-short'),
            value: 'short',
            label: '刷新',
          ),
          AppPopupMenuItem<String>(
            key: Key('menu-long'),
            value: 'long',
            label: '从帖子图片设置自定义封面',
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();

    final shortWidth = tester
        .getSize(find.byKey(const Key('menu-short')))
        .width;
    final longWidth = tester.getSize(find.byKey(const Key('menu-long'))).width;
    expect(shortWidth, closeTo(longWidth, 0.01));
    // 长文案撑到可用宽度上限，而不是沿用旧的固定上限截断整张菜单。
    expect(longWidth, greaterThan(200));
    expect(longWidth, lessThanOrEqualTo(280));
  });

  testWidgets('the source button comes back after the menu closes', (
    tester,
  ) async {
    var canceled = 0;
    await tester.pumpWidget(
      _menuApp(
        items: (context) => [
          const AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
        onCanceled: () => canceled++,
      ),
    );

    final button = find.byKey(const Key('menu-button'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(_sourceOpacity(tester), 0);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(canceled, 1);
    expect(_sourceOpacity(tester), 1);
    // 按钮恢复后可再次打开，说明快照与旧路由都已释放。
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsOneWidget);
  });

  testWidgets('the first frames continue the source button in the app theme', (
    tester,
  ) async {
    final boundary = GlobalKey();
    final theme = AppTheme.dark();
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: theme,
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: AppGlassEnvironment(
            glassLevel: AppGlassLevel.standard,
            child: child!,
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AppPopupMenuButton<String>(
                key: const Key('menu-button'),
                itemBuilder: (context) => const [
                  AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
                ],
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.getRect(find.byKey(const Key('menu-button')));
    // 按钮自身不画面，取图标以外的位置作为顶栏底色。
    final sample = button.topLeft + const Offset(7, 7);
    final atRest = await _capture(tester, boundary);
    final barColor = atRest.at(sample);
    expect(barColor.computeLuminance(), lessThan(0.2));

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pump();
    // 路由压入的这一帧来源按钮仍在，画面与按下前一致。
    expect(_sourceOpacity(tester), 1);
    final pushed = await _capture(tester, boundary);
    expect(_colorDelta(pushed.at(sample), barColor), lessThan(0.02));

    await tester.pump(const Duration(milliseconds: 16));
    // 来源按钮换成快照继续显示：图标仍在原处，底色没有被另一套实色顶替。
    expect(_sourceOpacity(tester), 0);
    final tookOver = await _capture(tester, boundary);
    expect(_colorDelta(tookOver.at(sample), barColor), lessThan(0.06));
    expect(tookOver.brightestIn(button), greaterThan(0.1));

    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsOneWidget);
    // 菜单外壳与内容同用应用主题，而不是界面库的浅色兜底主题。
    final mapped = prismColorSchemeOf(
      Theme.of(tester.element(find.byKey(const Key('menu-button'))))
          .colorScheme,
    );
    final shell = prism.Theme.of(tester.element(find.text('刷新页面')));
    expect(shell.colorScheme.surface, mapped.surface);
    expect(shell.colorScheme.onSurface, mapped.onSurface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom trigger child opens the menu in place of the icon', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      _menuApp(
        child: const Text('书架'),
        tooltip: '切换书架',
        items: (context) => const [
          AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
        onSelected: selected.add,
      ),
    );

    expect(find.byIcon(Icons.adaptive.more), findsNothing);
    expect(find.byTooltip('切换书架'), findsOneWidget);

    await tester.tap(find.text('书架'));
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsOneWidget);
    await tester.tap(find.text('刷新页面'));
    await tester.pumpAndSettle();
    expect(selected, ['refresh']);
    expect(find.text('书架'), findsOneWidget);
  });

  testWidgets('targetBuilder supplies its own trigger and opens the menu', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AppPopupMenuButton<String>(
                key: const Key('menu-button'),
                itemBuilder: (context) => const [
                  AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
                ],
                onSelected: selected.add,
                targetBuilder: (context, open) => IconButton(
                  key: const Key('custom-trigger'),
                  tooltip: '更多',
                  onPressed: open,
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('custom-trigger')), findsOneWidget);
    expect(find.byIcon(Icons.adaptive.more), findsNothing);
    await tester.tap(find.byKey(const Key('custom-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsOneWidget);
    await tester.tap(find.text('刷新页面'));
    await tester.pumpAndSettle();
    expect(selected, ['refresh']);
  });

  testWidgets('a disabled custom trigger never opens the menu', (tester) async {
    await tester.pumpWidget(
      _menuApp(
        child: const Text('书架'),
        enabled: false,
        items: (context) => const [
          AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
      ),
    );

    await tester.tap(find.text('书架'));
    await tester.pumpAndSettle();
    expect(find.text('刷新页面'), findsNothing);
  });

  testWidgets('a danger item is drawn in the error color', (tester) async {
    await tester.pumpWidget(
      _menuApp(
        items: (context) => const [
          AppPopupMenuItem<String>(
            key: Key('menu-delete'),
            value: 'delete',
            label: '删除',
            danger: true,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('menu-delete'));
    final label = tester
        .widgetList<RichText>(
          find.descendant(of: row, matching: find.byType(RichText)),
        )
        .firstWhere((text) => text.text.toPlainText() == '删除');
    expect(
      label.text.style?.color,
      Theme.of(tester.element(row)).colorScheme.error,
    );
  });

  testWidgets('reduced motion shows and closes the menu without a morph', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _menuApp(
        reduceMotion: true,
        items: (context) => const [
          AppPopupMenuItem<String>(
            key: Key('menu-refresh'),
            value: 'refresh',
            label: '刷新页面',
          ),
        ],
        onSelected: events.add,
        onCanceled: () => events.add('canceled'),
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pump();
    // 没有展开动画：路由时长为零，首帧即是最终画面，也没有内容模糊。
    expect(find.text('刷新页面'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.text('刷新页面')))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    // 没有在跑的动画：后续帧只来自锚点定位的一次同步。
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.hasRunningAnimations, isFalse);
    // 不做快照接续，来源按钮保持可见。
    expect(_sourceOpacity(tester), 1);

    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('刷新页面'), findsOneWidget);
    // 菜单打开期间来源按钮一直在，不需要快照替身。
    expect(_sourceOpacity(tester), 1);

    await tester.tap(find.byKey(const Key('menu-refresh')));
    await tester.pump();
    expect(events, ['refresh']);
    expect(find.text('刷新页面'), findsNothing);
    expect(_sourceOpacity(tester), 1);
    await tester.pumpAndSettle();
    // 旧完成回调不再二次执行业务。
    expect(events, ['refresh']);

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(events, ['refresh', 'canceled']);
    expect(find.text('刷新页面'), findsNothing);

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(events, ['refresh', 'canceled', 'canceled']);
    expect(find.text('刷新页面'), findsNothing);

    // 关闭后按钮可再次打开，快照与旧路由都已释放。
    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pump();
    expect(find.text('刷新页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the normal menu keeps the upstream morph durations', (
    tester,
  ) async {
    await tester.pumpWidget(
      _menuApp(
        items: (context) => const [
          AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.text('刷新页面')))!;
    // 展开450毫秒；有来源快照的收回500毫秒。
    expect(route.transitionDuration, const Duration(milliseconds: 450));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'dark menu opening paints single scrim without final brightness jump',
    (tester) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.dark(),
          builder: (context, child) => RepaintBoundary(
            key: boundary,
            child: AppGlassEnvironment(
              glassLevel: AppGlassLevel.standard,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.white)),
                Positioned(
                  top: 24,
                  right: 16,
                  child: AppPopupMenuButton<String>(
                    key: const Key('menu-button'),
                    itemBuilder: (context) => const [
                      AppPopupMenuItem<String>(value: 'short', label: 'A'),
                      AppPopupMenuItem<String>(
                        value: 'long',
                        label: '从帖子图片设置自定义封面',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu-button')));
      await tester.pump();
      // 展开 400ms 时弹簧已接近终态，但 Morph 尚未退场（bare 仍为 true）。
      await tester.pump(const Duration(milliseconds: 400));

      final cardRect = tester.getRect(find.byType(prism_popup.PopupMenuCard));
      final sample = Offset(
        cardRect.right - 20,
        tester.getCenter(find.text('A')).dy,
      );
      final opening = await _capture(tester, boundary);
      final openingLuminance = opening.at(sample).computeLuminance();

      await tester.pumpAndSettle();
      final settled = await _capture(tester, boundary);
      final settledLuminance = settled.at(sample).computeLuminance();

      // 若开合期 Morph 与 Card 重复绘制压黑层，展开末帧会明显偏暗，
      // 收敛到稳态时亮度会出现大幅跳升。
      expect((openingLuminance - settledLuminance).abs(), lessThan(0.05));
      expect(
        _colorDelta(opening.at(sample), settled.at(sample)),
        lessThan(0.06),
      );
    },
  );

  testWidgets(
    'pushes onto root navigator above nested shell navigator and aligns anchor',
    (tester) async {
      final root = GlobalKey<NavigatorState>();
      final nested = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        LocalizedTestApp(
          navigatorKey: root,
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 100),
                  child: Navigator(
                    key: nested,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Center(
                          child: AppPopupMenuButton<String>(
                            key: const Key('nested-menu-button'),
                            itemBuilder: (_) => const [
                              AppPopupMenuItem<String>(
                                key: Key('nested-menu-item'),
                                value: 'refresh',
                                label: '刷新页面',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: ColoredBox(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonRect = tester.getRect(
        find.byKey(const Key('nested-menu-button')),
      );
      await tester.tap(find.byKey(const Key('nested-menu-button')));
      await tester.pumpAndSettle();

      final item = find.byKey(const Key('nested-menu-item'));
      expect(item, findsOneWidget);
      expect(Navigator.of(tester.element(item)), same(root.currentState));
      expect(
        Navigator.of(tester.element(item)),
        isNot(same(nested.currentState)),
      );
      final menuCardRect = tester.getRect(
        find.byType(prism_popup.PopupMenuCard),
      );
      expect(menuCardRect.right, closeTo(buttonRect.right, 2));
    },
  );
}

double _sourceOpacity(WidgetTester tester) {
  final opacity = tester.widget<Opacity>(
    find
        .descendant(
          of: find.byType(AppPopupMenuButton<String>),
          matching: find.byType(Opacity),
        )
        .first,
  );
  return opacity.opacity;
}

Widget _menuApp({
  required List<PopupMenuEntry<String>> Function(BuildContext context) items,
  ValueChanged<String>? onSelected,
  VoidCallback? onCanceled,
  bool enabled = true,
  Widget? child,
  String? tooltip,
  ThemeData? theme,
  bool reduceMotion = false,
}) {
  return LocalizedTestApp(
    theme: theme ?? AppTheme.light(),
    // 系统减少动态效果是应用级 MediaQuery，覆盖页面与覆盖层。
    builder: reduceMotion
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          )
        : null,
    home: Scaffold(
      appBar: AppBar(
        actions: [
          AppPopupMenuButton<String>(
            key: const Key('menu-button'),
            itemBuilder: items,
            onSelected: onSelected,
            onCanceled: onCanceled,
            enabled: enabled,
            tooltip: tooltip,
            child: child,
          ),
        ],
      ),
      body: const SizedBox.expand(),
    ),
  );
}

/// 一帧画面的像素读数：按逻辑坐标取色，测试环境像素比为 1。
class _Frame {
  const _Frame(this._bytes, this._size);

  final ByteData _bytes;
  final Size _size;

  Color at(Offset point) {
    final x = point.dx.round().clamp(0, _size.width.round() - 1);
    final y = point.dy.round().clamp(0, _size.height.round() - 1);
    final index = (y * _size.width.round() + x) * 4;
    return Color.fromARGB(
      _bytes.getUint8(index + 3),
      _bytes.getUint8(index),
      _bytes.getUint8(index + 1),
      _bytes.getUint8(index + 2),
    );
  }

  /// [rect] 内最亮一点的亮度，用于确认来源快照（深色顶栏上的浅色图标）
  /// 仍在画面上，而不是被一帧空白顶替。
  double brightestIn(Rect rect) {
    var brightest = 0.0;
    for (var x = 4.0; x < rect.width - 4; x += 2) {
      for (var y = 4.0; y < rect.height - 4; y += 2) {
        final luminance = at(rect.topLeft + Offset(x, y)).computeLuminance();
        if (luminance > brightest) {
          brightest = luminance;
        }
      }
    }
    return brightest;
  }
}

Future<_Frame> _capture(WidgetTester tester, GlobalKey boundary) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => render.toImage()))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  return _Frame(bytes, size);
}

/// 逐通道差异，用于判断一帧画面是否接续了来源按钮。
double _colorDelta(Color a, Color b) => [
  (a.r - b.r).abs(),
  (a.g - b.g).abs(),
  (a.b - b.b).abs(),
].reduce((left, right) => left > right ? left : right);
