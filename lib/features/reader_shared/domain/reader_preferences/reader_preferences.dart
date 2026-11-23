/// 跨阅读器共享的持久化显示偏好。
///
/// 漫画阅读器与帖子图片阅读器共用同一份偏好（阅读模式 / 页面适配 / 背景 /
/// 页间距 / 页码浮层），改一处两边生效。模型刻意保持小而稳定，方便后续在不
/// 改调用方的前提下演进实现细节。
library;

import 'package:y300/features/library_shared/presentation/reader/reader_page_turn_models.dart';

/// 阅读模式。
///
/// - `vertical`：垂直连续滚动（条漫）。
/// - `ltr` / `rtl`：单页横向翻页（左到右 / 右到左）。
enum ReaderModePreference { vertical, ltr, rtl }

enum ReaderPageFitPreference { fitWidth, fitHeight, contain }

enum ReaderBackgroundPreference { followTheme, black, white, gray }

/// 持久化阅读偏好快照。
class ReaderPreferences {
  const ReaderPreferences({
    required this.readerMode,
    required this.pageFit,
    required this.background,
    required this.pageSpacing,
    required this.showPageIndicator,
    this.pageEffect = ReaderPageEffect.slide,
    this.pageSpeed = ReaderPageSpeed.standard,
  });

  /// 无持久化数据时的默认值。
  factory ReaderPreferences.defaults() {
    return const ReaderPreferences(
      readerMode: ReaderModePreference.ltr,
      pageFit: ReaderPageFitPreference.fitWidth,
      background: ReaderBackgroundPreference.followTheme,
      pageSpacing: 0,
      showPageIndicator: true,
      pageEffect: ReaderPageEffect.slide,
      pageSpeed: ReaderPageSpeed.standard,
    );
  }

  final ReaderModePreference readerMode;
  final ReaderPageFitPreference pageFit;
  final ReaderBackgroundPreference background;

  /// 页间距。控制器层在持久化前已 clamp，渲染层可直接使用。
  final double pageSpacing;
  final bool showPageIndicator;
  final ReaderPageEffect pageEffect;
  final ReaderPageSpeed pageSpeed;

  ReaderPreferences copyWith({
    ReaderModePreference? readerMode,
    ReaderPageFitPreference? pageFit,
    ReaderBackgroundPreference? background,
    double? pageSpacing,
    bool? showPageIndicator,
    ReaderPageEffect? pageEffect,
    ReaderPageSpeed? pageSpeed,
  }) {
    return ReaderPreferences(
      readerMode: readerMode ?? this.readerMode,
      pageFit: pageFit ?? this.pageFit,
      background: background ?? this.background,
      pageSpacing: pageSpacing ?? this.pageSpacing,
      showPageIndicator: showPageIndicator ?? this.showPageIndicator,
      pageEffect: pageEffect ?? this.pageEffect,
      pageSpeed: pageSpeed ?? this.pageSpeed,
    );
  }
}
