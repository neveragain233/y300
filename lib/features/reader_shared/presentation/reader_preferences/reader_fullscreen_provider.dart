import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

/// 阅读器沉浸全屏开关，漫画（及图片）与小说阅读器的显示设置共用同一份持久化值。
///
/// 默认开启：阅读器在前台时隐藏系统状态栏与底部导航条，由用户在任一阅读器设置中关闭。
class ReaderFullscreenController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final store = ref.watch(preferencesStoreProvider);
    return await store.read(PreferenceKeys.readerImmersiveFullscreen) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final store = ref.read(preferencesStoreProvider);
    await store.write(PreferenceKeys.readerImmersiveFullscreen, enabled);
    state = AsyncData(enabled);
  }
}

final readerFullscreenEnabledProvider =
    AsyncNotifierProvider<ReaderFullscreenController, bool>(
      ReaderFullscreenController.new,
    );
