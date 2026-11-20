import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/eink_mode.dart';
import 'package:y300/core/eink/eink_hardware_page_keys.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';
import 'package:y300/core/eink/eink_paging_router.dart';
import 'package:y300/shared/widgets/eink_scroll_pager.dart';

const _upKey = Key('eink-corner-page-up');
const _downKey = Key('eink-corner-page-down');
const _edgePreviousKey = Key('eink-edge-tap-previous');
const _edgeNextKey = Key('eink-edge-tap-next');

class _FakeKeysService implements EInkHardwarePageKeysService {
  final StreamController<HardwarePageKeyDirection> controller =
      StreamController<HardwarePageKeyDirection>.broadcast();
  final List<bool> enabledCalls = <bool>[];

  @override
  Stream<HardwarePageKeyDirection> get directions => controller.stream;

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledCalls.add(enabled);
  }

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

class _FakeRippleService implements EInkPageRippleService {
  int calls = 0;

  @override
  Future<bool> triggerPageRipple({
    required bool forward,
    required EInkRippleSpeed speed,
  }) async {
    calls += 1;
    return true;
  }
}

class _Harness {
  _Harness({required this.edgeTapPaging}) {
    router = EInkPagingRouter(keys, ripple);
  }

  final bool edgeTapPaging;
  final _FakeKeysService keys = _FakeKeysService();
  final _FakeRippleService ripple = _FakeRippleService();
  late final EInkPagingRouter router;
  late final overrides = [
    eInkPagingRouterProvider.overrideWith((ref) {
      routerReads += 1;
      return router;
    }),
    eInkEdgeTapPagingProvider.overrideWithValue(edgeTapPaging),
  ];
  int routerReads = 0;

  Future<void> dispose() async {
    await router.dispose();
    await keys.dispose();
  }
}

Future<void> _pumpPager(
  WidgetTester tester, {
  required _Harness harness,
  required ScrollController controller,
  required ValueNotifier<bool?> enabled,
  ValueNotifier<bool>? scopeEnabled,
  ValueNotifier<bool>? tickerEnabled,
  bool cornerButtons = true,
  bool edgeTapAllowed = true,
  double edgeTopInset = 0,
  double edgeBottomInset = 0,
  double contentHeight = 2000,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: harness.overrides,
      child: MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool?>(
            valueListenable: enabled,
            builder: (context, enabledValue, _) {
              // 局部 final 固定被测组件；闭包若捕获会被重新赋值的变量，
              // 内层 builder 就会构建它自己并无限递归。
              final pager = EInkScrollPager(
                controller: controller,
                enabled: enabledValue,
                cornerButtons: cornerButtons,
                edgeTapAllowed: edgeTapAllowed,
                edgeTopInset: edgeTopInset,
                edgeBottomInset: edgeBottomInset,
                child: ListView(
                  controller: controller,
                  children: [SizedBox(height: contentHeight)],
                ),
              );
              Widget content = pager;
              if (scopeEnabled != null) {
                content = ValueListenableBuilder<bool>(
                  valueListenable: scopeEnabled,
                  builder: (context, scopeValue, _) =>
                      EInkModeScope(enabled: scopeValue, child: pager),
                );
              }
              if (tickerEnabled != null) {
                final wrapped = content;
                content = ValueListenableBuilder<bool>(
                  valueListenable: tickerEnabled,
                  builder: (context, tickerValue, _) =>
                      TickerMode(enabled: tickerValue, child: wrapped),
                );
              }
              return content;
            },
          ),
        ),
      ),
    ),
  );
  // 首帧布局结束后 pager 补算边界，角标与边缘层在下一帧出现。
  await tester.pump();
}

void main() {
  test('edge tap paging defaults to off in appearance settings', () {
    expect(AppAppearanceSettings.defaults().eInkEdgeTapPaging, isFalse);
  });

  testWidgets('renders nothing and never touches the router when disabled', (
    tester,
  ) async {
    final harness = _Harness(edgeTapPaging: true);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(false);
    addTearDown(enabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
    );

    expect(find.byKey(_upKey), findsNothing);
    expect(find.byKey(_downKey), findsNothing);
    expect(find.byKey(_edgePreviousKey), findsNothing);
    expect(find.byKey(_edgeNextKey), findsNothing);
    expect(harness.routerReads, 0);
    expect(harness.keys.enabledCalls, isEmpty);
  });

  testWidgets('shows corner buttons without edge layers by default', (
    tester,
  ) async {
    final harness = _Harness(edgeTapPaging: false);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(true);
    addTearDown(enabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
    );

    expect(find.byKey(_upKey), findsOneWidget);
    expect(find.byKey(_downKey), findsOneWidget);
    expect(find.byKey(_edgePreviousKey), findsNothing);
    expect(find.byKey(_edgeNextKey), findsNothing);
    // 用户没有打开阅读器硬件键开关，注册不应触碰原生通道。
    expect(harness.keys.enabledCalls, isEmpty);

    expect(tester.widget<GestureDetector>(find.byKey(_upKey)).onTap, isNull);
    expect(
      tester.widget<GestureDetector>(find.byKey(_downKey)).onTap,
      isNotNull,
    );

    await tester.tap(find.byKey(_downKey));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    expect(harness.ripple.calls, 1);
  });

  testWidgets('edge layers appear only when the edge setting is on', (
    tester,
  ) async {
    final harness = _Harness(edgeTapPaging: true);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(true);
    addTearDown(enabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
      edgeTopInset: 12,
      edgeBottomInset: 20,
    );

    // 顶部只能向下翻，因此只出现右侧窄条。
    expect(find.byKey(_edgePreviousKey), findsNothing);
    expect(find.byKey(_edgeNextKey), findsOneWidget);
    final size = tester.getSize(find.byKey(_edgeNextKey));
    expect(size.width, 24);
    expect(size.height, 600 - 12 - 20);

    controller.jumpTo(200);
    await tester.pump();
    expect(find.byKey(_edgePreviousKey), findsOneWidget);
    expect(find.byKey(_edgeNextKey), findsOneWidget);

    final before = controller.offset;
    await tester.tap(find.byKey(_edgeNextKey));
    await tester.pump();
    expect(controller.offset, greaterThan(before));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(_edgePreviousKey), findsOneWidget);
    expect(find.byKey(_edgeNextKey), findsNothing);
  });

  testWidgets('edgeTapAllowed false keeps the setting from adding layers', (
    tester,
  ) async {
    final harness = _Harness(edgeTapPaging: true);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(true);
    addTearDown(enabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
      edgeTapAllowed: false,
    );

    expect(find.byKey(_edgePreviousKey), findsNothing);
    expect(find.byKey(_edgeNextKey), findsNothing);
  });

  testWidgets('unregisters when disabled and registers again when enabled', (
    tester,
  ) async {
    final harness = _Harness(edgeTapPaging: true);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(true);
    addTearDown(enabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
    );
    expect(find.byKey(_downKey), findsOneWidget);
    expect(find.byKey(_edgeNextKey), findsOneWidget);

    harness.router.setHardwareKeysEnabled(true);
    await tester.pump();
    expect(harness.keys.enabledCalls, [true]);

    enabled.value = false;
    await tester.pump();
    expect(find.byKey(_upKey), findsNothing);
    expect(find.byKey(_downKey), findsNothing);
    expect(find.byKey(_edgeNextKey), findsNothing);
    expect(harness.keys.enabledCalls, [true, false]);

    enabled.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_downKey), findsOneWidget);
    expect(find.byKey(_edgeNextKey), findsOneWidget);
    expect(harness.keys.enabledCalls, [true, false, true]);
  });

  testWidgets('follows EInkModeScope when enabled is null', (tester) async {
    final harness = _Harness(edgeTapPaging: false);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(null);
    addTearDown(enabled.dispose);
    final scopeEnabled = ValueNotifier<bool>(false);
    addTearDown(scopeEnabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
      scopeEnabled: scopeEnabled,
    );

    expect(find.byKey(_downKey), findsNothing);
    expect(harness.routerReads, 0);

    scopeEnabled.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_downKey), findsOneWidget);

    scopeEnabled.value = false;
    await tester.pump();
    expect(find.byKey(_downKey), findsNothing);
  });

  testWidgets('registers as hidden while TickerMode is off', (tester) async {
    final harness = _Harness(edgeTapPaging: false);
    addTearDown(harness.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final enabled = ValueNotifier<bool?>(true);
    addTearDown(enabled.dispose);
    final tickerEnabled = ValueNotifier<bool>(false);
    addTearDown(tickerEnabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: controller,
      enabled: enabled,
      tickerEnabled: tickerEnabled,
    );
    harness.router.setHardwareKeysEnabled(true);
    await tester.pump();
    expect(harness.keys.enabledCalls, isEmpty);

    tickerEnabled.value = true;
    await tester.pump();
    expect(harness.keys.enabledCalls, [true]);

    tickerEnabled.value = false;
    await tester.pump();
    expect(harness.keys.enabledCalls, [true, false]);
  });

  testWidgets('moves the handler to a replacement controller', (tester) async {
    final harness = _Harness(edgeTapPaging: false);
    addTearDown(harness.dispose);
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final enabled = ValueNotifier<bool?>(true);
    addTearDown(enabled.dispose);

    await _pumpPager(
      tester,
      harness: harness,
      controller: first,
      enabled: enabled,
    );
    expect(find.byKey(_downKey), findsOneWidget);

    await _pumpPager(
      tester,
      harness: harness,
      controller: second,
      enabled: enabled,
    );
    await tester.pump();

    expect(first.hasClients, isFalse);
    await tester.tap(find.byKey(_downKey));
    await tester.pump();
    expect(second.offset, greaterThan(0));
  });
}
