import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';

/// 运行时墨水屏模式：来源是外观设置，切换后立即生效。
///
/// Widget 层优先读 [EInkModeScope]，非 widget 代码与需要在 build 之外
/// 反应的组件读取本 provider。
final eInkModeProvider = Provider<bool>((ref) {
  final settings = ref.watch(appAppearanceControllerProvider);
  return settings.asData?.value.eInkMode ?? false;
});

/// 边缘点击翻页开关；只在墨水屏模式下有意义。
final eInkEdgeTapPagingProvider = Provider<bool>((ref) {
  final settings = ref.watch(appAppearanceControllerProvider);
  return settings.asData?.value.eInkEdgeTapPaging ?? false;
});
