import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

/// 全局加粗字体开关。默认关闭，打开后主题的各级字重整体提升一档。
class BoldFontController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final store = ref.watch(preferencesStoreProvider);
    return await store.read(PreferenceKeys.readerBoldFont) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final store = ref.read(preferencesStoreProvider);
    await store.write(PreferenceKeys.readerBoldFont, enabled);
    state = AsyncData(enabled);
  }
}

final boldFontEnabledProvider = AsyncNotifierProvider<BoldFontController, bool>(
  BoldFontController.new,
);
