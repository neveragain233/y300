import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.adws.y300/epdc');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('forwards direction and speed to the host channel', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });

    final accepted = await const MethodChannelEInkPageRippleService()
        .triggerPageRipple(forward: false, speed: EInkRippleSpeed.fast);

    expect(accepted, isTrue);
    expect(received?.method, 'triggerPageRipple');
    expect(received?.arguments, <String, Object?>{
      'forward': false,
      'speed': 'fast',
    });
  });

  test('reports host refusal without raising', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);

    final accepted = await const MethodChannelEInkPageRippleService()
        .triggerPageRipple(forward: true, speed: EInkRippleSpeed.standard);

    expect(accepted, isFalse);
  });

  test('absorbs missing bridge and platform errors', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('no epdc bridge');
    });
    final missing = await const MethodChannelEInkPageRippleService()
        .triggerPageRipple(forward: true, speed: EInkRippleSpeed.slow);
    expect(missing, isFalse);

    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'engine_detached');
    });
    final failed = await const MethodChannelEInkPageRippleService()
        .triggerPageRipple(forward: true, speed: EInkRippleSpeed.slow);
    expect(failed, isFalse);
  });

  test('skips the channel outside Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return true;
    });

    final accepted = await const MethodChannelEInkPageRippleService()
        .triggerPageRipple(forward: true, speed: EInkRippleSpeed.standard);

    expect(accepted, isFalse);
    expect(invoked, isFalse);
  });
}
