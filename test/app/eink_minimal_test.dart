import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/eink/eink_epdc_channel.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_palette.dart';
import 'package:y300/app/y300_app.dart';

void main() {
  tearDown(() {
    EInkEpdcChannel.enabled = false;
    EInkEpdcChannel.setTestOverride(null);
  });

  test('eink palettes expose high-contrast monochrome tokens', () {
    final light = AppThemePalette.einkLight();
    expect(light.scaffoldBackground, const Color(0xFFFFFFFF));
    expect(light.onSurface, const Color(0xFF111111));
    expect(light.surfaceContainer, const Color(0xFFF4F4F4));
    expect(light.outlineVariant, const Color(0xFFCCCCCC));

    final dark = AppThemePalette.einkDark();
    expect(dark.scaffoldBackground, const Color(0xFF000000));
    expect(dark.onSurface, const Color(0xFFFFFFFF));
    expect(dark.outlineVariant, const Color(0xFF444444));

    final theme = AppTheme.build(
      family: AppThemeFamily.eink,
      brightness: Brightness.light,
    );
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.colorScheme.shadow, Colors.transparent);
    expect(theme.colorScheme.scrim, Colors.transparent);
  });

  testWidgets('Y300App disables animations and arms EPDC only in eink family', (
    tester,
  ) async {
    Future<void> pumpWithFamily(AppThemeFamily family) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey<AppThemeFamily>(family),
          overrides: [
            appAppearanceControllerProvider.overrideWith(
              () => _FixedAppearanceController(
                AppAppearanceSettings.defaults().copyWith(
                  themeFamily: family,
                ),
              ),
            ),
          ],
          child: const Y300App(
            enableAppUpdatePrompt: false,
            home: _ProbeHome(),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpWithFamily(AppThemeFamily.eink);
    expect(EInkEpdcChannel.enabled, isTrue);
    final einkApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(einkApp.themeAnimationDuration, Duration.zero);
    expect(einkApp.scrollBehavior, isA<EInkScrollBehavior>());
    expect(einkApp.theme?.splashFactory, NoSplash.splashFactory);
    final einkContext = tester.element(find.byType(_ProbeHome));
    expect(MediaQuery.disableAnimationsOf(einkContext), isTrue);

    await pumpWithFamily(AppThemeFamily.warmPaper);
    expect(EInkEpdcChannel.enabled, isFalse);
    final warmApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(warmApp.themeAnimationDuration, kThemeAnimationDuration);
    expect(warmApp.scrollBehavior, isNull);
    final warmContext = tester.element(find.byType(_ProbeHome));
    expect(MediaQuery.disableAnimationsOf(warmContext), isFalse);
  });

  test('EInkEpdcChannel forwards ripple calls only when enabled', () async {
    final calls = <bool>[];
    EInkEpdcChannel.setTestOverride((forward, _) async {
      calls.add(forward);
    });

    EInkEpdcChannel.enabled = false;
    await EInkEpdcChannel.triggerPageRipple(forward: true);
    expect(calls, isEmpty);

    EInkEpdcChannel.enabled = true;
    await EInkEpdcChannel.triggerPageRipple(forward: true);
    await EInkEpdcChannel.triggerPageRipple(forward: false);
    expect(calls, <bool>[true, false]);
  });
}

class _FixedAppearanceController extends AppAppearanceController {
  _FixedAppearanceController(this._settings);

  final AppAppearanceSettings _settings;

  @override
  Future<AppAppearanceSettings> build() async => _settings;
}

class _ProbeHome extends StatelessWidget {
  const _ProbeHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
