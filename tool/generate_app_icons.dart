import 'dart:io';

import 'package:image/image.dart' as img;

import 'app_icons/icon_artwork.dart';

/// 从仓库根目录执行；原图、标志覆盖率、底色及系统裁切分别管理。
Future<void> main() async {
  const sourcePath = 'assets/app_icon_source.png';
  final source = img.decodePng(await File(sourcePath).readAsBytes());
  if (source == null ||
      source.width != source.height ||
      source.width < 1024 ||
      source.frames.length != 1 ||
      source.any((pixel) => pixel.a != pixel.maxChannelValue)) {
    throw StateError(
      'Expected one opaque square PNG of at least 1024px: $sourcePath',
    );
  }
  final artwork = extractIconArtwork(source);
  await _writePng(
    'assets/app_icon.png',
    renderIconTile(artwork, size: 1024, shape: IconShape.square),
  );
  await _writePng(
    'assets/app_icon_transparent.png',
    renderIconTile(artwork, size: 1024, shape: IconShape.roundedSquare),
  );
  await _writePng(
    'assets/app_icon_foreground.png',
    renderIconMark(artwork, size: 432, viewportSize: 288),
  );
  await _writePng(
    'assets/app_icon_foreground_dark.png',
    renderIconMark(
      artwork,
      size: 432,
      viewportSize: 288,
      tint: IconPalette.brandDark.foreground,
    ),
  );
  await _writePng(
    'assets/app_icon_monochrome.png',
    renderIconMark(artwork, size: 432, viewportSize: 288, tint: 0xffffff),
  );

  for (final variant in const {
    '': IconPalette.brand,
    '_dark': IconPalette.brandDark,
  }.entries) {
    // 旧系统只有这一层底板；安卓12以后由系统统一裁切前景和背景。
    final splashPlate = renderIconTile(
      artwork,
      size: 640,
      shape: IconShape.roundedSquare,
      palette: variant.value,
    );
    final splash = img.Image(width: 768, height: 768, numChannels: 4);
    img.compositeImage(splash, splashPlate, dstX: 64, dstY: 64);
    await _writePng('assets/splash_logo${variant.key}.png', splash);
    await _writePng(
      'assets/splash_logo_android12${variant.key}.png',
      renderIconMark(
        artwork,
        size: 960,
        viewportSize: 640,
        tint: variant.value.foreground,
      ),
    );
  }

  for (final entry in const {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  }.entries) {
    final size = (48 * entry.value).round();
    await _writePng(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      renderIconTile(artwork, size: size, shape: IconShape.roundedSquare),
    );
    await _writePng(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_round.png',
      renderIconTile(artwork, size: size, shape: IconShape.circle),
    );
    await _writePng(
      'android/app/src/main/res/drawable-${entry.key}/ic_launcher_monochrome.png',
      renderIconMark(
        artwork,
        size: (108 * entry.value).round(),
        viewportSize: (72 * entry.value).round(),
        tint: 0xffffff,
      ),
    );
    await _writePng(
      'android/app/src/main/res/drawable-night-${entry.key}/ic_launcher_foreground.png',
      renderIconMark(
        artwork,
        size: (108 * entry.value).round(),
        viewportSize: (72 * entry.value).round(),
        tint: IconPalette.brandDark.foreground,
      ),
    );
    for (final shape in const {
      'ic_launcher': IconShape.roundedSquare,
      'ic_launcher_round': IconShape.circle,
    }.entries) {
      await _writePng(
        'android/app/src/main/res/mipmap-night-${entry.key}/${shape.key}.png',
        renderIconTile(
          artwork,
          size: size,
          shape: shape.value,
          palette: IconPalette.brandDark,
        ),
      );
    }
    await _writePng(
      'android/app/src/main/res/drawable-${entry.key}/ic_launcher_foreground.png',
      renderIconMark(
        artwork,
        size: (108 * entry.value).round(),
        viewportSize: (72 * entry.value).round(),
      ),
    );
  }
  // 夜间限定符优先于密度；夜间自适应入口须覆盖同名旧版夜间位图。
  for (final version in [26, 33]) {
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      for (final night in ['', '-night']) {
        final monochrome = version >= 33
            ? '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
            : '';
        await _writeText(
          'android/app/src/main/res/mipmap$night-anydpi-v$version/$name.xml',
          '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/y300_icon_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
$monochrome</adaptive-icon>
''',
        );
      }
    }
  }
  for (final variant in const {
    'values': IconPalette.brand,
    'values-night': IconPalette.brandDark,
  }.entries) {
    final background =
        '#${variant.value.background.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    await _writeText(
      'android/app/src/main/res/${variant.key}/y300_icon_colors.xml',
      '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="y300_icon_background">$background</color>
</resources>
''',
    );
  }
  stdout.writeln(
    'Generated layered launcher icons, legacy fallbacks and splash sources.',
  );
  stdout.writeln('Next: dart run flutter_native_splash:create');
}

Future<void> _writePng(String path, img.Image image) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(img.encodePng(image));
}

Future<void> _writeText(String path, String value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(value);
}
