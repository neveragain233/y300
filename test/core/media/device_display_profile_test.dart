import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/media/device_display_profile.dart';

void main() {
  test('computes physical short side from pixels and dpi', () {
    const profile = DeviceDisplayProfile(
      widthPixels: 1264,
      heightPixels: 1680,
      xdpi: 300,
      ydpi: 300,
      densityDpi: 480,
    );

    expect(profile.shortestSideInches, closeTo(4.213, 0.01));
  });

  test('phone short side stays below the e-ink large screen threshold', () {
    const profile = DeviceDisplayProfile(
      widthPixels: 1080,
      heightPixels: 2400,
      xdpi: 400,
      ydpi: 400,
      densityDpi: 480,
    );

    expect(profile.shortestSideInches, closeTo(2.7, 0.01));
  });

  test('rejects implausible dpi and pixel values', () {
    for (final (xdpi, pixels) in [
      (0.0, 1264),
      (100.0, 1264),
      (2000.0, 1264),
      (300.0, 0),
    ]) {
      final profile = DeviceDisplayProfile(
        widthPixels: pixels,
        heightPixels: pixels,
        xdpi: xdpi,
        ydpi: xdpi,
        densityDpi: 480,
      );
      expect(profile.shortestSideInches, isNull);
    }
  });

  test('resolver is a no-op outside Android', () async {
    expect(await const DeviceDisplayProfileResolver().resolve(), isNull);
  });
}
