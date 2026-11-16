import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class ReaderChromeInsets {
  const ReaderChromeInsets({
    this.top = 0,
    this.bottom = 0,
    this.safeAreaTop = 0,
    this.safeAreaBottom = 0,
    this.pageIndicatorReservedHeight = 0,
  }) : assert(top >= 0),
       assert(bottom >= 0),
       assert(safeAreaTop >= 0),
       assert(safeAreaBottom >= 0),
       assert(pageIndicatorReservedHeight >= 0);

  const ReaderChromeInsets.zero() : this();

  final double top;
  final double bottom;
  final double safeAreaTop;
  final double safeAreaBottom;
  final double pageIndicatorReservedHeight;

  double get topInset => top + safeAreaTop;

  double get persistentBottomInset => bottom + safeAreaBottom;

  double get bottomInset => persistentBottomInset + pageIndicatorReservedHeight;

  @override
  bool operator ==(Object other) {
    return other is ReaderChromeInsets &&
        other.top == top &&
        other.bottom == bottom &&
        other.safeAreaTop == safeAreaTop &&
        other.safeAreaBottom == safeAreaBottom &&
        other.pageIndicatorReservedHeight == pageIndicatorReservedHeight;
  }

  @override
  int get hashCode => Object.hash(
    top,
    bottom,
    safeAreaTop,
    safeAreaBottom,
    pageIndicatorReservedHeight,
  );
}

/// System gesture insets that stay relevant after the reader hides the bars.
///
/// Android reports the gesture region separately from system-bar padding, so
/// floating reader controls must consider both instead of only [padding].
abstract final class ReaderSystemUiInsets {
  static double bottom(BuildContext context, {double minimum = 0}) {
    final media = MediaQuery.of(context);
    return math.max(
      math.max(media.padding.bottom, media.systemGestureInsets.bottom),
      minimum,
    );
  }
}

class ReaderToolbarAction {
  const ReaderToolbarAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.dismissMenu = true,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  /// Whether the reader overlay should close before invoking the action.
  ///
  /// Persistent controls such as a mode cycle can keep the menu open so the
  /// user can repeat the action without reopening the overlay.
  final bool dismissMenu;
}

class ReaderTopBarConfig {
  const ReaderTopBarConfig({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onBack,
    this.onTitleTap,
  });

  final String title;
  final String subtitle;
  final List<ReaderToolbarAction> actions;
  final VoidCallback onBack;
  final VoidCallback? onTitleTap;
}

class ReaderBottomBarConfig {
  const ReaderBottomBarConfig({
    required this.actions,
    this.progress,
    this.thumbnailStrip,
  });

  final List<ReaderToolbarAction> actions;
  final ReaderProgressConfig? progress;

  /// 进度条上方的可选导航内容槽（漫画缩略图条）。null 时不占位。
  final Widget? thumbnailStrip;
}

class ReaderProgressConfig {
  const ReaderProgressConfig({
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
    this.onPrevious,
    this.onNext,
    this.previousEnabled = true,
    this.nextEnabled = true,
    this.interactionLocked = false,
    this.previousTooltip,
    this.nextTooltip,
    this.previousIcon = Icons.skip_previous,
    this.nextIcon = Icons.skip_next,
  }) : value = null,
       min = 0,
       max = null,
       divisions = null,
       leadingLabel = null,
       trailingLabel = null,
       sliderEnabled = true;

  const ReaderProgressConfig.discrete({
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
    this.onPrevious,
    this.onNext,
    this.previousEnabled = true,
    this.nextEnabled = true,
    this.sliderEnabled = true,
    this.interactionLocked = false,
    this.previousTooltip,
    this.nextTooltip,
    this.previousIcon = Icons.skip_previous,
    this.nextIcon = Icons.skip_next,
    this.leadingLabel,
    this.trailingLabel,
  }) : value = null,
       min = 0,
       max = null,
       divisions = null;

  const ReaderProgressConfig.continuous({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.leadingLabel,
    required this.trailingLabel,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onPrevious,
    this.onNext,
    this.previousEnabled = true,
    this.nextEnabled = true,
    this.sliderEnabled = true,
    this.interactionLocked = false,
    this.previousTooltip,
    this.nextTooltip,
    this.previousIcon = Icons.skip_previous,
    this.nextIcon = Icons.skip_next,
  }) : current = null,
       total = null;

  final int? current;
  final int? total;
  final double? value;
  final double min;
  final double? max;
  final int? divisions;
  final String? leadingLabel;
  final String? trailingLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double>? onChangeStart;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool previousEnabled;
  final bool nextEnabled;
  final bool sliderEnabled;
  final bool interactionLocked;
  final String? previousTooltip;
  final String? nextTooltip;
  final IconData previousIcon;
  final IconData nextIcon;
}
