import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_appearance_settings_repository.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/app/y300_app.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/more/presentation/appearance_settings_sheet.dart';
import 'package:y300/app/content_rendering/native_forum_html_render_theme_factory.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../test_support/localized_test_app.dart';

void main() {
  test('failed commit restores cache even when the platform updates cache before failure', () async {
    final store = _Store();
    final repository = SharedPrefsAppAppearanceSettingsRepository(
      preferencesStore: store,
    );
    final previous = AppAppearanceSettings.defaults().copyWith(
      themeFamily: AppThemeFamily.moonWhite,
      colorSource: AppThemeColorSource.dynamic,
    );
    await repository.save(previous);
    store.failWrite = store.writes + 6;
    store.mutateBeforeFailure = true;
    await expectLater(
      repository.save(
        previous.copyWith(
          themeFamily: AppThemeFamily.plumPurple,
          colorSource: AppThemeColorSource.preset,
        ),
      ),
      throwsStateError,
    );
    final reloaded = await SharedPrefsAppAppearanceSettingsRepository(
      preferencesStore: store,
    ).load();
    expect(reloaded.themeFamily, previous.themeFamily);
    expect(reloaded.colorSource, previous.colorSource);
    await repository.save(
      reloaded.copyWith(brightnessPreference: AppBrightnessPreference.dark),
    );
    final saved = await repository.load();
    expect(saved.themeFamily, previous.themeFamily);
    expect(saved.colorSource, previous.colorSource);
    expect(saved.brightnessPreference, AppBrightnessPreference.dark);
  });

  testWidgets(
    'palette refresh and appearance changes preserve navigation and content state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      Color palette = Colors.teal;
      var reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DynamicColorPlugin.channel,
        (call) async {
          if (call.method == DynamicColorPlugin.accentColorMethodName) {
            reads++;
            return palette.toARGB32();
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DynamicColorPlugin.channel,
          null,
        ),
      );
      final probe = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionControllerProvider.overrideWith(_AnonymousSession.new),
          ],
          child: Y300App(
            enableAppUpdatePrompt: false,
            home: _Probe(key: probe),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = probe.currentState!;
      original.scroll.jumpTo(240);
      original.expanded.value = true;
      await tester.pump();
      final container = ProviderScope.containerOf(probe.currentContext!);
      final controller = container.read(
        appAppearanceControllerProvider.notifier,
      );
      await controller.setColorSource(AppThemeColorSource.dynamic);
      await tester.pumpAndSettle();
      expect(
        Theme.of(probe.currentContext!).colorScheme.primary,
        ColorScheme.fromSeed(seedColor: palette).primary,
      );
      final navigator = Navigator.of(probe.currentContext!);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('route-state')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await controller.setBrightnessPreference(AppBrightnessPreference.dark);
      palette = Colors.indigo;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, greaterThan(1));
      expect(find.text('route-state'), findsOneWidget);
      expect(identical(probe.currentState, original), isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(original.scroll.offset, 240);
      expect(original.expanded.value, isTrue);
      expect(
        Theme.of(probe.currentContext!).colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: palette,
          brightness: Brightness.dark,
        ).primary,
      );
    },
  );

  for (final brightness in Brightness.values) {
    test('dynamic $brightness uses system roles and neutral shell', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      );
      final theme = AppTheme.build(
        family: AppThemeFamily.warmPaper,
        brightness: brightness,
        colorSource: AppThemeColorSource.dynamic,
        dynamicScheme: scheme,
      );
      expect(theme.colorScheme, scheme);
      expect(theme.scaffoldBackgroundColor, scheme.surface);
      expect(theme.appBarTheme.backgroundColor, scheme.surfaceContainer);
      expect(theme.appBarTheme.foregroundColor, scheme.onSurface);
      expect(theme.navigationBarTheme.backgroundColor, scheme.surfaceContainer);
      expect(theme.y300NativeContent.card, scheme.surfaceContainerLow);
      expect(theme.y300NativeContent.body, scheme.onSurface);
      expect(theme.y300NativeContent.title, scheme.onSurface);
      expect(theme.y300NativeContent.accent, scheme.primary);
      expect(ThreadDetailNativePalette.resolve(theme).accent, scheme.primary);
      expect(
        ThreadDetailNativePalette.resolve(theme).card,
        scheme.surfaceContainerLow,
      );
      expect(
        const ForumHtmlRenderThemeFactory().fromNativeTheme(theme: theme).link,
        scheme.primary,
      );
      expect(
        theme.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
        brightness == Brightness.light ? Brightness.dark : Brightness.light,
      );
    });

    test('unavailable dynamic $brightness uses saved family exactly', () {
      for (final family in AppThemeFamily.values) {
        final expected = AppTheme.build(family: family, brightness: brightness);
        final actual = AppTheme.build(
          family: family,
          brightness: brightness,
          colorSource: AppThemeColorSource.dynamic,
        );
        expect(actual.colorScheme, expected.colorScheme);
        expect(actual.appBarTheme, expected.appBarTheme);
        expect(actual.y300NativeContent.body, expected.y300NativeContent.body);
      }
    });
  }

  test(
    'preset ignores available system scheme and keeps light icons on dark bar',
    () {
      final theme = AppTheme.build(
        family: AppThemeFamily.moonWhite,
        brightness: Brightness.light,
        dynamicScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      );
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF2E3F5A));
      expect(
        theme.appBarTheme.systemOverlayStyle!.statusBarIconBrightness,
        Brightness.light,
      );
    },
  );

  test('old preferences and unknown source preserve saved preset', () async {
    for (final source in [null, 'future']) {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.appThemeFamily.name: 'moonWhite',
        PreferenceKeys.appThemeColorSource.name: ?source,
      });
      final settings = await SharedPrefsAppAppearanceSettingsRepository()
          .load();
      expect(settings.colorSource, AppThemeColorSource.preset);
      expect(settings.themeFamily, AppThemeFamily.moonWhite);
    }
  });

  test(
    'snapshot commit keeps source and preset atomic after a partial write',
    () async {
      final store = _Store();
      final repository = SharedPrefsAppAppearanceSettingsRepository(
        preferencesStore: store,
      );
      await repository.save(
        AppAppearanceSettings.defaults().copyWith(
          colorSource: AppThemeColorSource.dynamic,
          themeFamily: AppThemeFamily.moonWhite,
        ),
      );
      store.failKey = PreferenceKeys.appThemeColorSource.name;
      await expectLater(
        repository.save(
          AppAppearanceSettings.defaults().copyWith(
            themeFamily: AppThemeFamily.plumPurple,
            brightnessPreference: AppBrightnessPreference.dark,
          ),
        ),
        throwsStateError,
      );
      final restored = await repository.load();
      expect(restored.colorSource, AppThemeColorSource.dynamic);
      expect(restored.themeFamily, AppThemeFamily.moonWhite);
      expect(restored.brightnessPreference, AppBrightnessPreference.light);
      store.failKey = null;
      await repository.save(
        restored.copyWith(colorSource: AppThemeColorSource.preset),
      );
      expect((await repository.load()).colorSource, AppThemeColorSource.preset);
    },
  );

  test('rapid choices serialize saves; late failure does not roll back newest choice', () async {
    final repository = _DelayedRepository();
    final container = ProviderContainer(
      overrides: [
        appAppearanceSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appAppearanceControllerProvider.future);
    final controller = container.read(appAppearanceControllerProvider.notifier);
    final first = controller.setColorSource(AppThemeColorSource.dynamic);
    final failed = expectLater(first, throwsStateError);
    final second = controller.setThemeFamily(AppThemeFamily.moonWhite);
    await Future<void>.delayed(Duration.zero);
    expect(repository.saves, hasLength(1));
    repository.pending.first.completeError(StateError('failed'));
    await failed;
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(appAppearanceControllerProvider).value!.themeFamily,
      AppThemeFamily.moonWhite,
    );
    expect(repository.saves, hasLength(2));
    repository.pending.last.complete();
    await second;
    expect(repository.saves.last.colorSource, AppThemeColorSource.preset);
  });

  test(
    'dynamic retains last preset and choosing that preset switches source',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.appThemeFamily.name: 'plumPurple',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appAppearanceControllerProvider.future);
      final controller = container.read(
        appAppearanceControllerProvider.notifier,
      );
      await controller.setColorSource(AppThemeColorSource.dynamic);
      expect(
        container.read(appAppearanceControllerProvider).value!.themeFamily,
        AppThemeFamily.plumPurple,
      );
      await controller.setThemeFamily(AppThemeFamily.plumPurple);
      final loaded = await SharedPrefsAppAppearanceSettingsRepository().load();
      expect(loaded.colorSource, AppThemeColorSource.preset);
      expect(loaded.themeFamily, AppThemeFamily.plumPurple);
    },
  );

  testWidgets(
    'narrow traditional appearance exposes dynamic choice and fallback',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: LocalizedTestApp(
            locale: const Locale('zh', 'TW'),
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const Scaffold(body: AppearanceSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamicChoice = find.byKey(const Key('appearance-theme-dynamic'));
      await tester.ensureVisible(dynamicChoice);
      await tester.tap(dynamicChoice);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(dynamicChoice));
      expect(
        find.descendant(
          of: dynamicChoice,
          matching: find.text(l10n.moreThemeDynamic),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.moreThemeDynamicDescription), findsOneWidget);
      expect(
        find.byKey(const Key('appearance-dynamic-fallback')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'appearance sheet switches navigation style and gates swipe in legacy',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: LocalizedTestApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AppearanceSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('appearance-settings-sheet'));
      await tester.drag(sheet, const Offset(0, -220));
      await tester.pumpAndSettle();

      final immersive = find.byKey(
        const Key('appearance-navigation-style-immersive'),
      );
      final legacy = find.byKey(
        const Key('appearance-navigation-style-legacy'),
      );
      final swipe = find.byKey(const Key('appearance-navigation-swipe'));
      expect(immersive, findsOneWidget);
      expect(legacy, findsOneWidget);
      expect(tester.widget<SwitchListTile>(swipe).value, isTrue);
      expect(tester.widget<SwitchListTile>(swipe).onChanged, isNotNull);

      await tester.ensureVisible(legacy);
      await tester.tap(legacy);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(sheet));
      final settings = container.read(appAppearanceControllerProvider).value!;
      expect(settings.navigationBarStyle, AppNavigationBarStyle.legacy);
      expect(tester.widget<SwitchListTile>(swipe).onChanged, isNull);
      final l10n = AppLocalizations.of(tester.element(sheet));
      expect(find.text(l10n.moreNavigationSwipeUnavailable), findsOneWidget);

      await tester.tap(immersive);
      await tester.pumpAndSettle();
      expect(
        container
            .read(appAppearanceControllerProvider)
            .value!
            .navigationBarStyle,
        AppNavigationBarStyle.immersive,
      );
      expect(tester.widget<SwitchListTile>(swipe).onChanged, isNotNull);

      await tester.tap(swipe);
      await tester.pumpAndSettle();
      expect(
        container
            .read(appAppearanceControllerProvider)
            .value!
            .navigationSwipeEnabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Store implements PreferencesStore {
  final values = <String, Object>{};
  String? failKey;
  int writes = 0;
  int? failWrite;
  bool mutateBeforeFailure = false;
  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async =>
      values[key.name] as T?;
  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async =>
      values.containsKey(key.name);
  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async =>
      values.remove(key.name);
  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    writes++;
    if (mutateBeforeFailure) values[key.name] = value;
    if (failKey == key.name || failWrite == writes) throw StateError('failed');
    values[key.name] = value;
  }
}

class _DelayedRepository implements AppAppearanceSettingsRepository {
  final saves = <AppAppearanceSettings>[];
  final pending = <Completer<void>>[];
  @override
  Future<AppAppearanceSettings> load() async =>
      AppAppearanceSettings.defaults();
  @override
  Future<void> save(AppAppearanceSettings settings) {
    saves.add(settings);
    final completer = Completer<void>();
    pending.add(completer);
    return completer.future;
  }
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final scroll = ScrollController();
  final expanded = ValueNotifier(false);
  @override
  void dispose() {
    scroll.dispose();
    expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView.builder(
      controller: scroll,
      itemCount: 50,
      itemBuilder: (_, index) => SizedBox(height: 64, child: Text('$index')),
    ),
  );
}

class _AnonymousSession extends AuthSessionController {
  @override
  Future<AuthSessionViewState> build() async =>
      const AuthSessionViewState.signedOut();
}
