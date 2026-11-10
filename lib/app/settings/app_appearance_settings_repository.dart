import 'dart:convert';

import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';

abstract class AppAppearanceSettingsRepository {
  Future<AppAppearanceSettings> load();

  Future<void> save(AppAppearanceSettings settings);
}

class SharedPrefsAppAppearanceSettingsRepository
    implements AppAppearanceSettingsRepository {
  SharedPrefsAppAppearanceSettingsRepository({
    PreferencesStore? preferencesStore,
  }) : _preferencesStore = preferencesStore ?? SharedPreferencesStore();

  final PreferencesStore _preferencesStore;

  @override
  Future<AppAppearanceSettings> load() async {
    final snapshot = await _preferencesStore.read(
      PreferenceKeys.appAppearanceSnapshotV1,
    );
    if (snapshot != null) {
      try {
        final json = jsonDecode(snapshot);
        if (json is Map<String, dynamic> && json['version'] == 1) {
          return AppAppearanceSettings(
            colorSource: _parseColorSource(json['source']),
            themeFamily: _parseThemeFamily(json['family']),
            navigationBarStyle: _parseNavigationBarStyle(json['navigation']),
            navigationSwipeEnabled: _parseNavigationSwipe(json['swipe']),
            brightnessPreference: _parseBrightnessPreference(
              json['brightness'],
            ),
            languagePreference: _parseLanguage(json['language']),
          );
        }
      } on FormatException {
        // 损坏的快照使用已有标量偏好恢复。
      }
    }
    return AppAppearanceSettings(
      colorSource: _parseColorSource(
        await _preferencesStore.read(PreferenceKeys.appThemeColorSource),
      ),
      themeFamily: _parseThemeFamily(
        await _preferencesStore.read(PreferenceKeys.appThemeFamily),
      ),
      brightnessPreference: _parseBrightnessPreference(
        await _preferencesStore.read(PreferenceKeys.appThemePreference),
      ),
      languagePreference: _parseLanguage(
        await _preferencesStore.read(PreferenceKeys.appLanguagePreference),
      ),
    );
  }

  @override
  Future<void> save(AppAppearanceSettings settings) async {
    // 快照是提交点。先保留旧值，再更新兼容键；中途失败或退出仍读到完整旧设置。
    final previous = _encode(await load());
    await _preferencesStore.write(
      PreferenceKeys.appAppearanceSnapshotV1,
      previous,
    );
    try {
      await _preferencesStore.write(
        PreferenceKeys.appThemeFamily,
        settings.themeFamily.name,
      );
      await _preferencesStore.write(
        PreferenceKeys.appThemePreference,
        settings.brightnessPreference.name,
      );
      await _preferencesStore.write(
        PreferenceKeys.appLanguagePreference,
        settings.languagePreference.name,
      );
      await _preferencesStore.write(
        PreferenceKeys.appThemeColorSource,
        settings.colorSource.name,
      );
      await _preferencesStore.write(
        PreferenceKeys.appAppearanceSnapshotV1,
        _encode(settings),
      );
    } catch (error, stackTrace) {
      // SharedPreferences 会先改缓存再返回保存结果；失败时也要恢复缓存中的提交点。
      try {
        await _preferencesStore.write(
          PreferenceKeys.appAppearanceSnapshotV1,
          previous,
        );
      } catch (_) {
        // 原始保存错误由控制器处理，恢复写入同样会先还原当前进程的缓存。
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String _encode(AppAppearanceSettings settings) => jsonEncode({
    'version': 1,
    'source': settings.colorSource.name,
    'family': settings.themeFamily.name,
    'navigation': settings.navigationBarStyle.name,
    'swipe': settings.navigationSwipeEnabled,
    'brightness': settings.brightnessPreference.name,
    'language': settings.languagePreference.name,
  });

  AppThemeColorSource _parseColorSource(Object? raw) {
    return raw == AppThemeColorSource.dynamic.name
        ? AppThemeColorSource.dynamic
        : AppThemeColorSource.preset;
  }

  AppNavigationBarStyle _parseNavigationBarStyle(Object? raw) {
    for (final style in AppNavigationBarStyle.values) {
      if (style.name == raw) {
        return style;
      }
    }
    return AppNavigationBarStyle.immersive;
  }

  /// 旧快照没有该字段，缺省保留新的默认值。
  bool _parseNavigationSwipe(Object? raw) {
    return raw is bool ? raw : true;
  }

  AppThemeFamily _parseThemeFamily(Object? raw) {
    for (final family in AppThemeFamily.values) {
      if (family.name == raw) {
        return family;
      }
    }
    return AppThemeFamily.warmPaper;
  }

  AppBrightnessPreference _parseBrightnessPreference(Object? raw) {
    for (final preference in AppBrightnessPreference.values) {
      if (preference.name == raw) {
        return preference;
      }
    }
    return AppBrightnessPreference.light;
  }

  AppLanguage _parseLanguage(Object? raw) {
    for (final language in AppLanguage.values) {
      if (language.name == raw) {
        return language;
      }
    }
    return AppLanguage.system;
  }
}
