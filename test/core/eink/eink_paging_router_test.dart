import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_hardware_page_keys.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';
import 'package:y300/core/eink/eink_paging_router.dart';

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

  void emit(HardwarePageKeyDirection direction) {
    controller.add(direction);
  }
}

class _FakeRippleService implements EInkPageRippleService {
  final List<bool> calls = <bool>[];

  @override
  Future<bool> triggerPageRipple({
    required bool forward,
    required EInkRippleSpeed speed,
  }) async {
    calls.add(forward);
    return true;
  }
}

class _RecordingHandler implements EInkPageHandler {
  int upCalls = 0;
  int downCalls = 0;

  @override
  bool get canPageUp => true;

  @override
  bool get canPageDown => true;

  @override
  void pageUp() => upCalls += 1;

  @override
  void pageDown() => downCalls += 1;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeKeysService keys;
  late _FakeRippleService ripple;
  late EInkPagingRouter router;

  setUp(() {
    keys = _FakeKeysService();
    ripple = _FakeRippleService();
    router = EInkPagingRouter(keys, ripple);
  });

  tearDown(() async {
    await router.dispose();
    await keys.dispose();
  });

  test('routes keys to the last registered visible handler', () async {
    final first = _RecordingHandler();
    final second = _RecordingHandler();
    router.register('list', first);
    router.register('reader', second);
    router.setHardwareKeysEnabled(true);
    await _flush();

    keys.emit(HardwarePageKeyDirection.next);
    await _flush();

    expect(second.downCalls, 1);
    expect(first.downCalls, 0);

    router.setVisible('reader', false);
    // 越过 180ms 去抖窗口，验证下一次事件交给下一个可见目标。
    await Future<void>.delayed(const Duration(milliseconds: 220));
    keys.emit(HardwarePageKeyDirection.previous);
    await _flush();

    expect(first.upCalls, 1);
  });

  test('stays silent until the user switch turns on', () async {
    final handler = _RecordingHandler();
    router.register('reader', handler);
    await _flush();
    expect(keys.enabledCalls, isEmpty);

    router.setHardwareKeysEnabled(true);
    await _flush();
    expect(keys.enabledCalls, [true]);

    router.unregister('reader');
    await _flush();
    expect(keys.enabledCalls, [true, false]);
  });

  test('does not intercept without a visible handler', () async {
    router.setHardwareKeysEnabled(true);
    await _flush();
    expect(keys.enabledCalls, isEmpty);

    final reader = _RecordingHandler();
    router.register('reader', reader, isVisible: false);
    await _flush();
    expect(keys.enabledCalls, isEmpty);

    router.setVisible('reader', true);
    await _flush();
    expect(keys.enabledCalls, [true]);
  });

  test('ignores key events while the user switch is off', () async {
    final handler = _RecordingHandler();
    router.register('reader', handler);
    await _flush();

    keys.emit(HardwarePageKeyDirection.next);
    await _flush();

    expect(handler.downCalls, 0);
  });

  test('debounces hardware directions within 180ms', () async {
    final handler = _RecordingHandler();
    router.register('reader', handler);
    router.setHardwareKeysEnabled(true);
    await _flush();

    keys.emit(HardwarePageKeyDirection.next);
    keys.emit(HardwarePageKeyDirection.next);
    await _flush();
    expect(handler.downCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 220));
    keys.emit(HardwarePageKeyDirection.next);
    await _flush();
    expect(handler.downCalls, 2);
  });

  testWidgets('ignores hardware keys while a text field owns focus', (
    tester,
  ) async {
    final handler = _RecordingHandler();
    router.register('reader', handler);
    router.setHardwareKeysEnabled(true);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
    );
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);

    keys.emit(HardwarePageKeyDirection.next);
    await tester.pump();
    expect(handler.downCalls, 0);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    keys.emit(HardwarePageKeyDirection.next);
    await tester.pump();
    expect(handler.downCalls, 1);
  });
}
