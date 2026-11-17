import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/settings/app_appearance_settings_repository.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/settings/app_navigation_lens_motion.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

final appAppearanceSettingsRepositoryProvider =
    Provider<AppAppearanceSettingsRepository>((ref) {
      return SharedPrefsAppAppearanceSettingsRepository(
        preferencesStore: ref.watch(preferencesStoreProvider),
      );
    });

final appAppearanceControllerProvider =
    AsyncNotifierProvider<AppAppearanceController, AppAppearanceSettings>(
      AppAppearanceController.new,
    );

class AppAppearanceController extends AsyncNotifier<AppAppearanceSettings> {
  Future<void> _saveTail = Future<void>.value();
  AppAppearanceSettings? _committed;
  int _revision = 0;
  AppAppearanceSettingsRepository get _repository =>
      ref.read(appAppearanceSettingsRepositoryProvider);

  @override
  Future<AppAppearanceSettings> build() async {
    final settings = await _repository.load();
    _committed = settings;
    return settings;
  }

  Future<void> setThemeFamily(AppThemeFamily family) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.themeFamily == family &&
        previous.colorSource == AppThemeColorSource.preset) {
      return;
    }

    final next = previous.copyWith(
      themeFamily: family,
      colorSource: AppThemeColorSource.preset,
    );
    await _saveOrRollback(next);
  }

  Future<void> setColorSource(AppThemeColorSource source) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.colorSource == source) return;
    await _saveOrRollback(previous.copyWith(colorSource: source));
  }

  Future<void> setNavigationBarStyle(AppNavigationBarStyle style) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.navigationBarStyle == style) return;
    await _saveOrRollback(previous.copyWith(navigationBarStyle: style));
  }

  Future<void> setGlassLevel(AppGlassLevel level) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.glassLevel == level) return;
    await _saveOrRollback(previous.copyWith(glassLevel: level));
  }

  Future<void> setNavigationSwipeEnabled(bool enabled) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.navigationSwipeEnabled == enabled) return;
    await _saveOrRollback(previous.copyWith(navigationSwipeEnabled: enabled));
  }

  Future<void> setNavigationLensMotion(AppNavigationLensMotion motion) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.navigationLensMotion == motion) return;
    await _saveOrRollback(previous.copyWith(navigationLensMotion: motion));
  }

  /// 恢复默认外观：只重置外观字段，语言与账号数据保持原样。
  Future<void> resetAppearance() async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    final defaults = AppAppearanceSettings.defaults();
    final next = defaults.copyWith(
      languagePreference: previous.languagePreference,
    );
    if (_sameAppearanceFields(previous, next)) return;
    await _saveOrRollback(next);
  }

  Future<void> setBrightnessPreference(
    AppBrightnessPreference preference,
  ) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.brightnessPreference == preference) {
      return;
    }

    final next = previous.copyWith(brightnessPreference: preference);
    await _saveOrRollback(next);
  }

  Future<void> _saveOrRollback(AppAppearanceSettings next) async {
    final revision = ++_revision;
    state = AsyncData(next);
    final repository = _repository;
    final save = _saveTail.then((_) async {
      try {
        await repository.save(next);
        _committed = next;
      } catch (error, stackTrace) {
        if (ref.mounted && revision == _revision) {
          state = AsyncData(_committed ?? AppAppearanceSettings.defaults());
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
    _saveTail = save.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    await save;
  }

  bool _sameAppearanceFields(AppAppearanceSettings a, AppAppearanceSettings b) {
    return a.themeFamily == b.themeFamily &&
        a.colorSource == b.colorSource &&
        a.navigationBarStyle == b.navigationBarStyle &&
        a.navigationSwipeEnabled == b.navigationSwipeEnabled &&
        a.navigationLensMotion == b.navigationLensMotion &&
        a.glassLevel == b.glassLevel &&
        a.brightnessPreference == b.brightnessPreference;
  }

  Future<void> setLanguagePreference(AppLanguage preference) async {
    final previous = state.value ?? AppAppearanceSettings.defaults();
    if (previous.languagePreference == preference) {
      return;
    }

    final next = previous.copyWith(languagePreference: preference);
    await _saveOrRollback(next);
  }
}
