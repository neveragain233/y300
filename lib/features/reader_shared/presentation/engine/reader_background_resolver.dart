import 'package:flutter/material.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';

/// 解析阅读画布的有效背景。
///
/// 横向单页允许能力显式固定画布颜色（漫画为纯黑）；纵向滚动始终使用用户保存
/// 的背景偏好。固定色只是当前模式的显示策略，不写回偏好。
Color resolveReaderBackground({
  required Color themeSurface,
  required ReaderBackgroundPreference background,
  required ReaderModePreference readerMode,
  Color? pagedCanvasColor,
}) {
  final preferred = switch (background) {
    ReaderBackgroundPreference.followTheme => themeSurface,
    ReaderBackgroundPreference.black => Colors.black,
    ReaderBackgroundPreference.white => Colors.white,
    ReaderBackgroundPreference.gray => const Color(0xFF202124),
  };
  if (readerMode == ReaderModePreference.vertical) {
    return preferred;
  }
  return pagedCanvasColor ?? preferred;
}
