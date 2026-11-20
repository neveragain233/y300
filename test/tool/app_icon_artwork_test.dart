import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/app_icons/icon_artwork.dart';

void main() {
  late img.Image artwork;
  setUpAll(() {
    artwork = extractIconArtwork(
      img.decodePng(File('assets/app_icon_source.png').readAsBytesSync())!,
    );
  });

  test(
    'adaptive viewport preserves source composition and continues edge artwork',
    () {
      expect(artwork.width, artwork.height);
      final source = img.decodePng(
        File('assets/app_icon_source.png').readAsBytesSync(),
      )!;
      expect(artwork.width, source.width);
      for (final density in [1.0, 1.5, 2.0, 3.0, 4.0]) {
        final size = (108 * density).round();
        final viewport = (72 * density).round();
        final inset = (size - viewport) ~/ 2;
        final mark = renderIconMark(
          artwork,
          size: size,
          viewportSize: viewport,
        );
        final tile = renderIconTile(
          artwork,
          size: viewport,
          shape: IconShape.square,
        );
        final composed = img.Image(width: size, height: size, numChannels: 4);
        img.fill(composed, color: img.ColorRgb8(255, 249, 226));
        img.compositeImage(composed, mark);
        for (final pixel in tile) {
          final adaptive = composed.getPixel(pixel.x + inset, pixel.y + inset);
          expect(
            [adaptive.r, adaptive.g, adaptive.b, adaptive.a],
            [pixel.r, pixel.g, pixel.b, pixel.a],
          );
        }
        // 红色斜面延伸到图层底部，避免系统位移时出现缩在内部的封闭红块。
        expect(mark.getPixel(size - 1, size - 1).a, greaterThan(240));
        expect(mark.getPixel(size ~/ 2, size - 1).a, greaterThan(240));
        expect(mark.getPixel(0, 0).a, 0);
        expect(
          mark.getPixel(size - 1, size - 1).r,
          mark.getPixel(size - inset - 1, size - inset - 1).r,
        );
      }
    },
  );

  test('circular crop retains the letter and lily while the red slope reaches the rim', () {
    final circle = renderIconTile(artwork, size: 256, shape: IconShape.circle);
    final square = renderIconTile(artwork, size: 256, shape: IconShape.square);
    // 分别取字母两臂、竖笔及百合上瓣、左右瓣的内部位置。
    for (final point in [
      (0.29, 0.22),
      (0.71, 0.22),
      (0.49, 0.70),
      (0.70, 0.62),
      (0.59, 0.68),
      (0.82, 0.66),
    ]) {
      final x = (point.$1 * 256).floor();
      final y = (point.$2 * 256).floor();
      final original = square.getPixel(x, y);
      final clipped = circle.getPixel(x, y);
      expect(original.g, lessThan(80));
      expect(
        [clipped.r, clipped.g, clipped.b, clipped.a],
        [original.r, original.g, original.b, original.a],
      );
    }
    expect(circle.getPixel(128, 254).g, lessThan(80));
    expect(circle.getPixel(0, 0).a, 0);
    final rounded = renderIconTile(
      artwork,
      size: 256,
      shape: IconShape.roundedSquare,
    );
    expect(rounded.getPixel(128, 255).g, lessThan(80));
    expect(rounded.getPixel(255, 200).g, lessThan(80));
    expect(rounded.getPixel(255, 255).a, 0);
  });

  test('palette changes color without changing mark coverage or layout', () {
    final original = renderIconMark(artwork, size: 432, viewportSize: 288);
    final tinted = renderIconMark(
      artwork,
      size: 432,
      viewportSize: 288,
      tint: 0x6652a0,
    );
    final mono = renderIconMark(
      artwork,
      size: 432,
      viewportSize: 288,
      tint: 0xffffff,
    );
    for (final pixel in original) {
      final colored = tinted.getPixel(pixel.x, pixel.y);
      final white = mono.getPixel(pixel.x, pixel.y);
      expect(colored.a, pixel.a);
      expect(white.a, pixel.a);
      if (pixel.a > 0) {
        expect([colored.r, colored.g, colored.b], [0x66, 0x52, 0xa0]);
        expect([white.r, white.g, white.b], [255, 255, 255]);
      }
    }
  });

  test('compatibility tiles retain yellow independently of their outline', () {
    for (final shape in [IconShape.circle, IconShape.roundedSquare]) {
      final tile = renderIconTile(artwork, size: 192, shape: shape);
      expect(tile.getPixel(0, 0).a, 0);
      final yellow = tile.getPixel(96, 8);
      expect([yellow.r, yellow.g, yellow.b, yellow.a], [255, 249, 226, 255]);
      final future = renderIconTile(
        artwork,
        size: 192,
        shape: shape,
        palette: const IconPalette(background: 0x202934, foreground: 0xafc8e6),
      );
      final dark = future.getPixel(96, 8);
      expect([dark.r, dark.g, dark.b, dark.a], [32, 41, 52, 255]);
    }
  });

  test('native launcher resources expose monochrome only on supported versions', () {
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      for (final version in [26, 33]) {
        for (final night in ['', '-night']) {
          final xml = File(
            'android/app/src/main/res/mipmap$night-anydpi-v$version/$name.xml',
          ).readAsStringSync();
          expect(xml, contains('<adaptive-icon'));
          expect(xml, contains('@color/y300_icon_background'));
          expect(xml, contains('@drawable/ic_launcher_foreground'));
          expect(xml.contains('<monochrome'), version >= 33);
          if (version >= 33) {
            expect(xml, contains('@drawable/ic_launcher_monochrome'));
          }
        }
      }
    }
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });

  test('generated dark and monochrome layers retain the light mark coverage', () {
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      img.Image read(String path) =>
          img.decodePng(File(path).readAsBytesSync())!;
      final light = read(
        'android/app/src/main/res/drawable-$density/ic_launcher_foreground.png',
      );
      final dark = read(
        'android/app/src/main/res/drawable-night-$density/ic_launcher_foreground.png',
      );
      final mono = read(
        'android/app/src/main/res/drawable-$density/ic_launcher_monochrome.png',
      );
      expect(dark.width, light.width);
      expect(mono.width, light.width);
      for (final pixel in light) {
        final night = dark.getPixel(pixel.x, pixel.y);
        final mask = mono.getPixel(pixel.x, pixel.y);
        expect(night.a, pixel.a);
        expect(mask.a, pixel.a);
        if (pixel.a > 0) {
          expect([night.r, night.g, night.b], [255, 180, 171]);
          expect([mask.r, mask.g, mask.b], [255, 255, 255]);
        }
      }
      expect(mono.getPixel(0, 0).a, 0);
      final legacy = read(
        'android/app/src/main/res/mipmap-night-$density/ic_launcher.png',
      );
      final background = legacy.getPixel(
        legacy.width ~/ 2,
        legacy.height ~/ 10,
      );
      expect([background.r, background.g, background.b], [32, 32, 29]);
    }
    for (final variant in {
      'values': '#FFF9E2',
      'values-night': '#20201D',
    }.entries) {
      expect(
        File('android/app/src/main/res/${variant.key}/y300_icon_colors.xml')
            .readAsStringSync(),
        contains(variant.value),
      );
    }
  });

  test('Android 12 splash leaves the final mask to the system', () {
    for (final suffix in ['', '_dark']) {
      final splash = img.decodePng(
        File('assets/splash_logo_android12$suffix.png').readAsBytesSync(),
      )!;
      expect(splash.width, 960);
      // 这处位于可见方形内、内接圆外；预裁圆形会截断红色斜面。
      expect(splash.getPixel(760, 760).a, greaterThan(240));
      expect(splash.getPixel(959, 959).a, greaterThan(240));
      // 底色由系统提供，素材不再携带圆形黄色底板。
      expect(splash.getPixel(480, 180).a, 0);
      expect(splash.getPixel(0, 0).a, 0);
    }
    // 单包只保留一套浅色启动主题；夜间不再覆盖系统启动屏底色。
    final style = File('android/app/src/main/res/values-v31/styles.xml')
        .readAsStringSync();
    expect(
      style,
      contains(
        'name="android:windowSplashScreenIconBackgroundColor">#FFF4F4F4',
      ),
    );
    expect(
      style,
      contains('name="android:windowSplashScreenBackground">#FFF4F4F4'),
    );
    expect(
      File('android/app/src/main/res/values-night-v31/styles.xml').existsSync(),
      isFalse,
    );
  });
}
