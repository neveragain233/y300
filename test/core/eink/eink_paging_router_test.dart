import 'dart:async';

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
  void pageUp() => upCalls += 1;

  @override
  void pageDown() => downCalls += 1;
}

void main() {
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
    await Future<void>.delayed(Duration.zero);

    keys.emit(HardwarePageKeyDirection.next);
    await Future<void>.delayed(Duration.zero);

    expect(second.downCalls, 1);
    expect(first.downCalls, 0);

    router.setVisible('reader', false);
    keys.emit(HardwarePageKeyDirection.previous);
    await Future<void>.delayed(Duration.zero);

    expect(first.upCalls, 1);
  });

  test('native interception follows user switch and active handlers', () async {
    final handler = _RecordingHandler();
    router.register('reader', handler);
    await Future<void>.delayed(Duration.zero);
    expect(keys.enabledCalls.every((enabled) => !enabled), isTrue);

    router.setHardwareKeysEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(keys.enabledCalls.last, isTrue);

    router.unregister('reader');
    await Future<void>.delayed(Duration.zero);
    expect(keys.enabledCalls.last, isFalse);
  });

  test('ignores key events while the user switch is off', () async {
    final handler = _RecordingHandler();
    router.register('reader', handler);
    await Future<void>.delayed(Duration.zero);

    keys.emit(HardwarePageKeyDirection.next);
    await Future<void>.delayed(Duration.zero);

    expect(handler.downCalls, 0);
  });
}
