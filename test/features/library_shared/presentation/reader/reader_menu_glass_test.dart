import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 菜单玻璃在深色模式下压在白封面、漫画页这类高亮背景上时的可读性下限。
///
/// 背景采样先经菜单玻璃着色（tint），再叠压黑层（scrim）；这里用纯白作为
/// 最坏背景，近似计算合成底色，验证正文、辅助文字与危险态都达到 4.5:1。
void main() {
  double contrastRatio(Color foreground, Color background) {
    final a = foreground.computeLuminance();
    final b = background.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color menuCompositeOver(Color backdrop, {required bool dark}) {
    final style = LiquidGlassStyle.menu(
      prismColorSchemeOf(
        dark ? AppTheme.dark().colorScheme : AppTheme.light().colorScheme,
      ),
    );
    return Color.alphaBlend(
      menuScrim(
        prismColorSchemeOf(
          dark ? AppTheme.dark().colorScheme : AppTheme.light().colorScheme,
        ),
      ),
      Color.alphaBlend(style.tint, backdrop),
    );
  }

  test('dark menu scrim keeps white backdrops above 4.5:1', () {
    final scheme = AppTheme.dark().colorScheme;
    final composite = menuCompositeOver(Colors.white, dark: true);

    for (final foreground in [
      scheme.onSurface,
      scheme.onSurfaceVariant,
      scheme.error,
    ]) {
      expect(
        contrastRatio(foreground, composite),
        greaterThanOrEqualTo(4.5),
        reason: '$foreground over white menu',
      );
    }
  });

  test('dark menu scrim is a controlled black layer', () {
    final scheme = prismColorSchemeOf(AppTheme.dark().colorScheme);
    final scrim = menuScrim(scheme);
    expect(scrim.a, greaterThanOrEqualTo(0.4));
    expect(scrim.a, lessThanOrEqualTo(0.6));
    expect(scrim.r * 255, lessThanOrEqualTo(1));
    expect(scrim.g * 255, lessThanOrEqualTo(1));
    expect(scrim.b * 255, lessThanOrEqualTo(1));
  });

  test('light menu scrim stays almost off', () {
    final scrim = menuScrim(prismColorSchemeOf(AppTheme.light().colorScheme));
    expect(scrim.a, lessThanOrEqualTo(0.03));
  });

  test('menu shadows are tightened for light and bounded for dark', () {
    final light = menuShadows(prismColorSchemeOf(AppTheme.light().colorScheme));
    expect(light, hasLength(1));
    expect(light.single.color.a, lessThanOrEqualTo(0.08));
    expect(light.single.blurRadius, inInclusiveRange(16, 20));

    final dark = menuShadows(prismColorSchemeOf(AppTheme.dark().colorScheme));
    expect(dark, hasLength(1));
    expect(dark.single.color.a, lessThanOrEqualTo(0.18));
    expect(dark.single.blurRadius, inInclusiveRange(16, 20));
  });

  test('menu shadow does not stack with sub-menu depth', () {
    final scheme = prismColorSchemeOf(AppTheme.dark().colorScheme);
    final deep = menuShadows(scheme, 0.2);
    expect(
      deep.single.color.a,
      lessThanOrEqualTo(menuShadows(scheme).single.color.a),
    );
  });
}
