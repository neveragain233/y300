import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/card_surface.dart' show PressLook;
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/motion.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
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
      }
      // 玻璃圆底在按钮内部，按 44 视觉叠在 48 命中区中央。
      for (final owner in [
        find.byType(AppToolbarBackButton),
        find.byType(AppToolbarCloseButton),
      ]) {
        final surface = find.descendant(
          of: owner,
          matching: find.byType(AppGlassSurface),
        );
        expect(surface, findsOneWidget);
        expect(tester.getSize(surface).shortestSide, 44);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('icon button presses through the elastic spring model', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _glassApp(
        level: AppGlassLevel.standard,
        home: Scaffold(
          body: Center(
            child: AppToolbarIconButton(
              buttonKey: const Key('elastic-icon'),
              tooltip: '搜索',
              onPressed: () => pressed += 1,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final button = find.byKey(const Key('elastic-icon'));
    expect(tester.widget<prism_button.IconButton>(button).tooltip, '搜索');
    expect(
      find.ancestor(of: button, matching: find.byType(ElasticPress)),
      findsOneWidget,
    );
    // 弹簧按压替代水波纹：按钮自身不再挂 InkWell。
    expect(
      find.descendant(of: button, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(tester.getSize(button).shortestSide, AppToolbarButtonSize.hitTarget);
    final box = tester.renderObject<RenderBox>(button);
    expect(ElasticPress.liftOf(box), 0);
    expect(ElasticPress.paintBoundsOf(box), Offset.zero & box.size);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(ElasticPress.liftOf(box), greaterThan(0));
    expect(ElasticPress.paintBoundsOf(box).width, greaterThan(box.size.width));

    // 按住拖动时表面跟手偏移，而不是只做缩放。
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      ElasticPress.paintBoundsOf(box).center.dx,
      greaterThan(box.size.width / 2),
    );
    // 拖出按钮后不再提交点击。
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressed, 0);
    expect(ElasticPress.liftOf(box), 0);
    expect(ElasticPress.paintBoundsOf(box), Offset.zero & box.size);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the action capsule answers a press as one elastic surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _glassApp(
        level: AppGlassLevel.standard,
        home: _actionsScaffold(actionCount: 3),
      ),
    );
    await tester.pump();

    // 相关动作胶囊与末项圆键各自整体响应，内部按钮仍独立命中。
    final surfaces = find.byType(AppGlassSurface);
    expect(surfaces, findsNWidgets(2));
    for (var index = 0; index < 2; index += 1) {
      expect(
        find.ancestor(
          of: surfaces.at(index),
          matching: find.byType(ElasticPress),
        ),
        findsOneWidget,
      );
    }
    for (var index = 0; index < 3; index += 1) {
      expect(
        tester.getSize(find.byKey(_actionKey(index))).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }

    // Material 子按钮不再起水波纹或按压高亮，反馈归胶囊膨胀。
    final capsule = tester.element(surfaces.first);
    expect(Theme.of(capsule).splashFactory, same(NoSplash.splashFactory));
    expect(
      IconButtonTheme.of(capsule).style?.overlayColor
          ?.resolve(<WidgetState>{WidgetState.pressed}),
      Colors.transparent,
    );

    final capsuleBox = tester.renderObject<RenderBox>(surfaces.first);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_actionKey(0))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(ElasticPress.liftOf(capsuleBox), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(ElasticPress.liftOf(capsuleBox), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app buttons inside the capsule share its single glass layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _glassApp(
        level: AppGlassLevel.standard,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('title'),
            actions: [
              AppToolbarActions(
                children: [
                  for (var index = 0; index < 3; index += 1)
                    AppToolbarIconButton(
                      buttonKey: _actionKey(index),
                      tooltip: '动作 $index',
                      onPressed: () {},
                      icon: Icon(
                        index.isEven ? Icons.bookmark : Icons.more_vert,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 胶囊与末项圆键各一层玻璃，组内公共按钮不再自画圆底。
    final surfaces = find.byType(AppGlassSurface);
    expect(surfaces, findsNWidgets(2));
    expect(find.byType(ElasticPress), findsNWidgets(2));
    for (var index = 0; index < 3; index += 1) {
      final button = find.byKey(_actionKey(index));
      expect(tester.getSize(button).shortestSide, 48);
      expect(
        find.descendant(of: button, matching: find.byType(AppGlassSurface)),
        findsNothing,
      );
    }

    // 整组按压仍然生效并回到静止。
    final capsule = tester.renderObject<RenderBox>(surfaces.first);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_actionKey(0))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(ElasticPress.liftOf(capsule), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(ElasticPress.liftOf(capsule), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the capsule glass follows its size tier over a 48 hit row', (
    tester,
  ) async {
    for (final (size, visual) in [
      (AppToolbarButtonSize.bar, 44.0),
      (AppToolbarButtonSize.compact, 32.0),
    ]) {
      await tester.pumpWidget(
        _glassApp(
          level: AppGlassLevel.standard,
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AppToolbarActions(
                  size: size,
                  children: [
                    for (var index = 0; index < 3; index += 1)
                      IconButton(
                        key: _actionKey(index),
                        onPressed: () {},
                        icon: Icon(
                          index.isEven ? Icons.mail_outline : Icons.more_vert,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final surfaces = find.byType(AppGlassSurface);
      expect(surfaces, findsNWidgets(2));
      for (var index = 0; index < 2; index += 1) {
        // 胶囊玻璃只画视觉高度，行布局与命中区仍是 48。
        expect(tester.getSize(surfaces.at(index)).height, visual);
        expect(
          tester.getSize(surfaces.at(index)).width,
          greaterThanOrEqualTo(48),
        );
      }
      for (var index = 0; index < 3; index += 1) {
        expect(tester.getSize(find.byKey(_actionKey(index))).shortestSide, 48);
      }
    }
  });

  testWidgets(
    'bar and compact sizes keep one glass circle inside a 48 target',
    (tester) async {
      for (final (size, visual, iconExtent) in [
        (AppToolbarButtonSize.bar, 44.0, 24.0),
        (AppToolbarButtonSize.compact, 32.0, 20.0),
      ]) {
        await tester.pumpWidget(
          _glassApp(
            level: AppGlassLevel.standard,
            home: Scaffold(
              body: Center(
                child: AppToolbarIconButton(
                  size: size,
                  buttonKey: const Key('sized-icon'),
                  tooltip: '更多',
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final button = find.byKey(const Key('sized-icon'));
        // 命中区统一 48，玻璃圆底按档位收到中央。
        expect(
          tester.getSize(button).shortestSide,
          AppToolbarButtonSize.hitTarget,
        );
        final glass = find.descendant(
          of: find.byType(AppToolbarIconButton),
          matching: find.byType(AppGlassSurface),
        );
        expect(glass, findsOneWidget);
        expect(tester.getSize(glass).shortestSide, visual);
        final glyph = find.descendant(of: button, matching: find.byType(Icon));
        expect(tester.getSize(glyph).shortestSide, iconExtent);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('back and close drop Material ink for the spring feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _glassApp(
        level: AppGlassLevel.off,
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppToolbarBackButton(onPressed: () {}),
                AppToolbarCloseButton(
                  buttonKey: const Key('toolbar-close'),
                  tooltip: '关闭',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final backStyle = tester
        .widget<IconButton>(
          find.descendant(
            of: find.byType(BackButton),
            matching: find.byType(IconButton),
          ),
        )
        .style;
    final closeStyle = tester
        .widget<IconButton>(find.byKey(const Key('toolbar-close')))
        .style;
    for (final style in [backStyle, closeStyle]) {
      expect(style?.splashFactory, same(NoSplash.splashFactory));
      expect(
        style?.overlayColor?.resolve(<WidgetState>{WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
    }
    expect(
      find.ancestor(
        of: find.byType(AppGlassSurface).first,
        matching: find.byType(ElasticPress),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('back and close swell on press and settle after a cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _glassApp(
        level: AppGlassLevel.off,
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppToolbarBackButton(),
                AppToolbarCloseButton(
                  buttonKey: const Key('toolbar-close'),
                  tooltip: '关闭',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(AppToolbarBackButton)),
    );
    expect(find.byTooltip(localizations.backButtonTooltip), findsOneWidget);

    final back = find.byType(BackButton);
    final box = tester.renderObject<RenderBox>(back);
    final gesture = await tester.startGesture(tester.getCenter(back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(ElasticPress.liftOf(box), greaterThan(0));
    // 取消手势时也回到静止，而不是停在膨胀状态。
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(ElasticPress.liftOf(box), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps static state colors instead of swelling', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light(),
        builder: (context, child) => EInkModeScope(
          enabled: true,
          child: PrismMotionScope(
            reduceMotion: true,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('title'),
            actions: [
              AppToolbarActions(
                children: [
                  IconButton(
                    key: _actionKey(0),
                    onPressed: () {},
                    icon: const Icon(Icons.mail_outline),
                  ),
                  IconButton(
                    key: _actionKey(1),
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppToolbarIconButton(
                  buttonKey: const Key('static-icon'),
                  tooltip: '搜索',
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                ),
                AppToolbarBackButton(onPressed: () {}),
                AppToolbarCloseButton(
                  buttonKey: const Key('static-close'),
                  tooltip: '关闭',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ElasticPress), findsNothing);
    // 图标按钮退回即时状态色，不再膨胀。
    final iconButton = tester.widget<prism_button.IconButton>(
      find.byKey(const Key('static-icon')),
    );
    expect(iconButton.style?.pressLook, PressLook.none);
    expect(
      iconButton.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.pressed,
      }),
      isNot(Colors.transparent),
    );
    for (final style in [
      tester.widget<IconButton>(find.byKey(const Key('static-close'))).style,
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byType(BackButton),
              matching: find.byType(IconButton),
            ),
          )
          .style,
    ]) {
      expect(
        style?.backgroundColor?.resolve(<WidgetState>{WidgetState.pressed}),
        isNot(Colors.transparent),
      );
    }
    expect(
      IconButtonTheme.of(tester.element(find.byKey(_actionKey(0))))
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{WidgetState.pressed}),
      isNot(Colors.transparent),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled icon button keeps its disabled color and 48 target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _glassApp(
        level: AppGlassLevel.off,
        home: const Scaffold(
          body: Center(
            child: AppToolbarIconButton(
              buttonKey: Key('disabled-icon'),
              tooltip: '搜索',
              onPressed: null,
              icon: Icon(Icons.search),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final button = find.byKey(const Key('disabled-icon'));
    final widget = tester.widget<prism_button.IconButton>(button);
    expect(widget.onPressed, isNull);
    expect(
      widget.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      Theme.of(tester.element(button)).colorScheme.onSurface
          .withValues(alpha: .38),
    );
    final box = tester.renderObject<RenderBox>(button);
    expect(tester.getSize(button).shortestSide, 48);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 禁用按钮不膨胀，但仍保留读屏名称。
    expect(ElasticPress.liftOf(box), 0);
    expect(widget.tooltip, '搜索');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'menu button opens the shared anchored menu from its glass trigger',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _glassApp(
          level: AppGlassLevel.standard,
          home: Scaffold(
            body: Center(
              child: AppToolbarMenuButton<String>(
                buttonKey: const Key('toolbar-menu'),
                tooltip: '更多',
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => const [
                  AppPopupMenuItem<String>(value: 'refresh', label: '刷新页面'),
                  AppPopupMenuItem<String>(value: 'compose', label: '发帖'),
                ],
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final trigger = find.byKey(const Key('toolbar-menu'));
      expect(find.byType(AppToolbarIconButton), findsOneWidget);
      expect(
        find.descendant(of: trigger, matching: find.byType(InkWell)),
        findsNothing,
      );

      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('刷新页面'));
      await tester.pump();
      expect(selected, ['refresh']);
      await tester.pumpAndSettle();
      expect(find.text('刷新页面'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
