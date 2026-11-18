import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_hardware_page_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.adws.y300/eink_keys');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('enables host interception and emits hardware directions', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    final service = MethodChannelEInkHardwarePageKeysService(channel: channel);
    final directions = <HardwarePageKeyDirection>[];
    final subscription = service.directions.listen(directions.add);

    await service.setEnabled(true);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'setVolumePagingEnabled');
    expect(calls.single.arguments, isTrue);

    const codec = StandardMethodCodec();
    for (final argument in ['up', 'down']) {
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall('onHardwarePageKey', argument)),
        (data) {},
      );
    }
    await Future<void>.delayed(Duration.zero);

    expect(directions, [
      HardwarePageKeyDirection.previous,
      HardwarePageKeyDirection.next,
    ]);

    await subscription.cancel();
    await service.dispose();
  });

  test('skips the native bridge outside Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = true;
      return null;
    });

    final service = MethodChannelEInkHardwarePageKeysService(channel: channel);
    await service.setEnabled(true);

    expect(invoked, isFalse);
    await service.dispose();
  });
}
