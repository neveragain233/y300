import 'dart:ui' show Tristate;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/settings/app_navigation_lens_motion.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_palette.dart';
import 'package:y300/app/y300_app.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/more/presentation/appearance_page.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_index.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('appearance changes apply immediately and drive the preview', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DynamicColorPlugin.channel,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DynamicColorPlugin.channel,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(_AnonymousSession.new),
        ],
        child: const Y300App(
          enableAppUpdatePrompt: false,
          home: AppearancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('appearance-page'));
    expect(page, findsOneWidget);
    expect(Theme.of(tester.element(page)).brightness, Brightness.light);
    _expectPreviewMatches(tester, tester.element(page));
    // 预览只画主题色块，不加载头像与网络图片。
    expect(find.byType(Image), findsNothing);

    final darkOption = find.byKey(const Key('appearance-theme-mode-dark'));
    await _scrollTo(tester, darkOption);
    await tester.tap(darkOption);
    await tester.pumpAndSettle();

    final darkContext = tester.element(
      find.byKey(const Key('appearance-page')),
    );
    expect(Theme.of(darkContext).brightness, Brightness.dark);
    final settings = ProviderScope.containerOf(darkContext)
        .read(appAppearanceControllerProvider)
        .value!;
    expect(settings.brightnessPreference, AppBrightnessPreference.dark);
    await _scrollUpTo(tester, find.byKey(const Key('appearance-preview')));
    _expectPreviewMatches(tester, darkContext);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dynamic color is disabled with an explanation when unavailable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpAppearancePage(tester);

      final dynamicOption = find.byKey(const Key('appearance-theme-dynamic'));
      await _scrollTo(tester, dynamicOption);
      final l10n = AppLocalizations.of(tester.element(dynamicOption));
      expect(
        find.byKey(const Key('appearance-dynamic-fallback')),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.moreThemeDynamicUnavailable(l10n.moreThemeFamilyWarmPaper),
        ),
        findsOneWidget,
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel(l10n.appearanceDynamicColorLabel),
      );
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.flagsCollection.isSelected, Tristate.isFalse);
      semantics.dispose();
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: dynamicOption,
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );

      await tester.tap(dynamicOption);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('appearance-page'))),
      );
      expect(
        container.read(appAppearanceControllerProvider).value!.colorSource,
        AppThemeColorSource.preset,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reset restores appearance fields and keeps the language', (
    tester,
  ) async {
    await _pumpAppearancePage(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('appearance-page'))),
    );
    final controller = container.read(appAppearanceControllerProvider.notifier);
    await controller.setLanguagePreference(AppLanguage.traditionalChinese);
    await controller.setThemeFamily(AppThemeFamily.plumPurple);
    await controller.setBrightnessPreference(AppBrightnessPreference.dark);
    await controller.setGlassLevel(AppGlassLevel.enhanced);
    await controller.setNavigationBarStyle(AppNavigationBarStyle.legacy);
    await controller.setNavigationSwipeEnabled(false);
    await controller.setNavigationLensMotion(
      AppNavigationLensMotion.fromSelection,
    );
    await tester.pumpAndSettle();

    final reset = find.byKey(const Key('appearance-reset'));
    await _scrollTo(tester, reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('appearance-page'))),
    );
    expect(find.text(l10n.appearanceResetConfirmBody), findsOneWidget);
    await tester.tap(find.byKey(const Key('appearance-reset-confirm')));
    await tester.pumpAndSettle();

    final settings = container.read(appAppearanceControllerProvider).value!;
    expect(settings.themeFamily, AppThemeFamily.warmPaper);
    expect(settings.colorSource, AppThemeColorSource.preset);
    expect(settings.brightnessPreference, AppBrightnessPreference.light);
    expect(settings.glassLevel, AppGlassLevel.standard);
    expect(settings.navigationBarStyle, AppNavigationBarStyle.immersive);
    expect(settings.navigationSwipeEnabled, isTrue);
    expect(settings.navigationLensMotion, AppNavigationLensMotion.followPress);
    expect(settings.languagePreference, AppLanguage.traditionalChinese);
    expect(find.text(l10n.appearanceResetDone), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lens follow switch defaults to follow press and saves the mode',
    (tester) async {
      await _pumpAppearancePage(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('appearance-page'))),
      );
      final follow = find.byKey(const Key('appearance-lens-follow'));
      await _scrollTo(tester, follow);

      expect(tester.widget<AppSwitchRow>(follow).value, isTrue);
      expect(
        find.text(l10n.appearanceLensFollowPressDescription),
        findsOneWidget,
      );

      await tester.tap(follow);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('appearance-page'))),
      );
      expect(
        container
            .read(appAppearanceControllerProvider)
            .value!
            .navigationLensMotion,
        AppNavigationLensMotion.fromSelection,
      );
      expect(tester.widget<AppSwitchRow>(follow).value, isFalse);
      expect(
        find.text(l10n.appearanceLensFromSelectionDescription),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save failure rolls back and shows a snackbar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAppearanceControllerProvider.overrideWith(
            _FailingAppearanceController.new,
          ),
        ],
        child: const LocalizedTestApp(home: AppearancePage()),
      ),
    );
    await tester.pumpAndSettle();

    final dark = find.byKey(const Key('appearance-theme-mode-dark'));
    await _scrollTo(tester, dark);
    await tester.tap(dark);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('appearance-page'))),
    );
    expect(find.textContaining(l10n.moreThemeSaveFailed('')), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('appearance-page'))),
    );
    expect(
      container
          .read(appAppearanceControllerProvider)
          .value!
          .brightnessPreference,
      AppBrightnessPreference.light,
    );
    expect(
      find.descendant(
        of: dark,
        matching: find.byKey(const Key('appearance-option-selected-check')),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial section scrolls to the group and highlights it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LocalizedTestApp(
          home: AppearancePage(
            initialSection: SettingsSearchTarget.appearanceGlass,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('appearance-page-list'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, greaterThan(0));
    final highlight = find.byKey(
      const Key('settings-search-highlight-appearanceGlass'),
    );
    expect(tester.widget<AnimatedOpacity>(highlight).opacity, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(highlight).opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('option cards stack in one column at large text', (tester) async {
    tester.view.physicalSize = const Size(280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: LocalizedTestApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AppearancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lightOption = find.byKey(const Key('appearance-theme-mode-light'));
    await _scrollTo(tester, lightOption);
    expect(tester.getSize(lightOption).width, closeTo(280 - 32, 1));
    await _scrollTo(
      tester,
      find.byKey(const Key('appearance-glass-level-off')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime e-ink switch applies immediately and confines options', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(_AnonymousSession.new),
        ],
        child: const Y300App(
          enableAppUpdatePrompt: false,
          home: AppearancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final modeSwitch = find.byKey(const Key('appearance-eink-mode-switch'));
    final edgeSwitch = find.byKey(const Key('appearance-eink-edge-tap-switch'));
    await _scrollTo(tester, modeSwitch);
    expect(tester.widget<AppSwitchRow>(modeSwitch).value, isFalse);
    expect(tester.widget<AppSwitchRow>(edgeSwitch).onChanged, isNull);

    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();

    final pageContext = tester.element(
      find.byKey(const Key('appearance-page')),
    );
    final settings = ProviderScope.containerOf(pageContext)
        .read(appAppearanceControllerProvider)
        .value!;
    expect(settings.eInkMode, isTrue);
    expect(
      Theme.of(pageContext).scaffoldBackgroundColor,
      AppThemePalette.eInk().scaffoldBackground,
    );
    expect(tester.widget<AppSwitchRow>(edgeSwitch).onChanged, isNotNull);
    expect(
      find.byKey(const Key('appearance-navigation-style-immersive')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('appearance-navigation-style-legacy')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAppearancePage(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: LocalizedTestApp(home: AppearancePage())),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUpTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    -220,
    scrollable: find.descendant(
      of: find.byKey(const Key('appearance-page-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('appearance-page-list')),
        matching: find.byType(Scrollable),
      ),
    );
  } else {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  }
  await tester.pumpAndSettle();
}

void _expectPreviewMatches(WidgetTester tester, BuildContext context) {
  final theme = Theme.of(context);
  final preview = find.byKey(const Key('appearance-preview'));
  expect(preview, findsOneWidget);
  final pageBackground = find.descendant(
    of: preview,
    matching: find.byKey(const Key('appearance-preview-page')),
  );
  expect(
    tester.widget<ColoredBox>(pageBackground).color,
    theme.scaffoldBackgroundColor,
  );
  final card = find.descendant(
    of: preview,
    matching: find.byKey(const Key('appearance-preview-card-0')),
  );
  expect(
    (tester.widget<Container>(card).decoration! as BoxDecoration).color,
    theme.colorScheme.surfaceContainerLowest,
  );
  final selected = find.descendant(
    of: preview,
    matching: find.byKey(const Key('appearance-preview-nav-selected')),
  );
  expect(
    (tester.widget<Container>(selected).decoration! as BoxDecoration).color,
    theme.colorScheme.primary,
  );
}

class _FailingAppearanceController extends AppAppearanceController {
  final _settings = AppAppearanceSettings.defaults();

  @override
  Future<AppAppearanceSettings> build() async => _settings;

  @override
  Future<void> setBrightnessPreference(
    AppBrightnessPreference preference,
  ) async {
    final previous = _settings;
    if (previous.brightnessPreference == preference) {
      return;
    }
    state = AsyncData(previous.copyWith(brightnessPreference: preference));
    // 模拟控制器保存失败后的回滚，页面只负责提示当前已回滚的状态。
    state = AsyncData(previous);
    throw StateError('save failed');
  }
}

class _AnonymousSession extends AuthSessionController {
  @override
  Future<AuthSessionViewState> build() async =>
      const AuthSessionViewState.signedOut();
}
