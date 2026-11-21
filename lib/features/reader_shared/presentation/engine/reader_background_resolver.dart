import 'package:flutter/material.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';

/// 墨水屏模式下忽略深灰背景偏好，显示上统一回退至跟随主题（不改写原持久化值）。
ReaderBackgroundPreference effectiveReaderBackgroundPreference(
  ReaderBackgroundPreference background, {
  required bool eInkMode,
}) {
  if (eInkMode && background == ReaderBackgroundPreference.gray) {
    return ReaderBackgroundPreference.followTheme;
  }
  return background;
}

/// 解析阅读画布的有效背景。
///
/// 横向单页允许能力显式固定画布颜色；未固定时在纵向滚动与横向翻页模式下均使用
/// 用户保存的背景偏好（墨水屏模式下会跳过灰底并回退到跟随主题）。
Color resolveReaderBackground({
  required Color themeSurface,
  required ReaderBackgroundPreference background,
  required ReaderModePreference readerMode,
  Color? pagedCanvasColor,
  bool eInkMode = false,
}) {
  final effective = effectiveReaderBackgroundPreference(
    background,
    eInkMode: eInkMode,
  );
  final preferred = switch (effective) {
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
