import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

/// 阅读器硬件键翻页开关，漫画与小说阅读器的显示设置共用同一份持久化值。
///
/// 默认关闭：只有用户在两处任一显示设置里打开后，阅读器才会在前台拦截
/// 音量键与侧边翻页键。
class HardwarePageKeysController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final store = ref.watch(preferencesStoreProvider);
    return await store.read(PreferenceKeys.readerHardwarePageKeys) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final store = ref.read(preferencesStoreProvider);
    await store.write(PreferenceKeys.readerHardwarePageKeys, enabled);
    state = AsyncData(enabled);
  }
}

final hardwarePageKeysEnabledProvider =
    AsyncNotifierProvider<HardwarePageKeysController, bool>(
      HardwarePageKeysController.new,
    );
