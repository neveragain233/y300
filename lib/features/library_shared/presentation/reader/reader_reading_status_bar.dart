import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'reader_models.dart';

/// One compact reading-status line shared by the novel and image reading modes.
///
/// The bar is display-only: page progress must keep flowing through the
/// existing reading-progress pipeline, never through this presentation value.
@immutable
final class ReaderReadingStatus {
  const ReaderReadingStatus({
    required this.leading,
    required this.trailing,
    required this.semanticsLabel,
    this.title = '',
  });

  final String leading;
  final String trailing;
  final String semanticsLabel;

  /// Optional chapter or sequence title rendered after [leading] when width permits.
  final String title;

  @override
  bool operator ==(Object other) {
    return other is ReaderReadingStatus &&
        other.leading == leading &&
        other.trailing == trailing &&
        other.semanticsLabel == semanticsLabel &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(leading, trailing, semanticsLabel, title);
}

/// Visual contract of the persistent reading status bar.
///
/// [standard] uses a transparent overlay surface with palette-driven text.
/// [eInk] is the fixed 24dp opaque footer with a 1px top divider used while
/// runtime e-ink mode is active.
enum ReaderReadingStatusBarVariant { standard, eInk }

abstract final class ReaderReadingStatusBarLayout {
  static const double fontSize = 11;
  static const double lineHeight = 1.2;
  static const double horizontalPadding = 12;
  static const double verticalPadding = 5;
  static const double minimumBottomInset = 4;

  /// Fixed content height of the e-ink variant, excluding the bottom inset.
  static const double eInkContentHeight = 24;
  static const double eInkHorizontalPadding = 14;
  static const double eInkFontSize = 11;
  static const double eInkLineHeight = 1.1;
  static const double eInkTopBorderWidth = 1;

  /// Height of the bar content excluding the system bottom safe area.
  ///
  /// The floating dock location already accounts for the system safe area, so
  /// callers that need to sit above the bar must not add the inset twice.
  static double contentHeight(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return textScaler.scale(fontSize) * lineHeight + verticalPadding * 2;
  }

  /// Content height for the selected variant.
  ///
  /// The e-ink footer uses a fixed 24dp line regardless of the text scaler so
  /// pagination and dock clearance stay stable on small e-ink panels.
  static double contentHeightForVariant(
    BuildContext context,
    ReaderReadingStatusBarVariant variant,
  ) {
    return switch (variant) {
      ReaderReadingStatusBarVariant.standard => contentHeight(context),
      ReaderReadingStatusBarVariant.eInk => eInkContentHeight,
    };
  }

  /// Bottom inset used by the bar. Immersive Android reports the gesture
  /// region separately from system-bar padding, so both must be considered.
  static double bottomInset(BuildContext context) {
    return ReaderSystemUiInsets.bottom(context, minimum: minimumBottomInset);
  }

  /// Full height including the bottom safe area consumed by the bar itself.
  static double height(BuildContext context) {
    return contentHeight(context) + bottomInset(context);
  }

  /// Full height for the selected variant, including the bottom safe area.
  static double heightForVariant(
    BuildContext context,
    ReaderReadingStatusBarVariant variant,
  ) {
    return contentHeightForVariant(context, variant) + bottomInset(context);
  }

  /// Extra offset for a floating control above the bar.
  ///
  /// The Scaffold floating-action location already adds the system bottom
  /// padding; only the remainder belongs in the dock's own clearance.
  static double dockClearance(BuildContext context) {
    return height(context) - MediaQuery.paddingOf(context).bottom + 8;
  }

  /// Variant-aware dock clearance. The e-ink footer is 24dp tall, so docks
  /// must use this value instead of the text-scaled standard height.
  static double dockClearanceForVariant(
    BuildContext context,
    ReaderReadingStatusBarVariant variant,
  ) {
    return heightForVariant(context, variant) -
        MediaQuery.paddingOf(context).bottom +
        8;
  }
}

/// Persistent three-segment reading status shown at the bottom edge of the
/// reading viewport.
///
/// Renders left title/chapter metadata on the left and bold reading progress plus
/// real-time clock on the right, degrading gracefully on narrow widths.
class ReaderReadingStatusBar extends StatelessWidget {
  const ReaderReadingStatusBar({
    super.key,
    required this.status,
    required this.background,
    required this.foreground,
    this.progressForeground,
    this.variant = ReaderReadingStatusBarVariant.standard,
    this.now,
  });

  final ReaderReadingStatus status;
  final Color background;
  final Color foreground;

  /// Optional emphasis color for the bold progress segment in [standard] mode;
  /// defaults to [foreground] when omitted.
  final Color? progressForeground;
  final ReaderReadingStatusBarVariant variant;

  /// Test-only clock injection. Production rebuilds the line with the current
  /// time; the bar intentionally owns no timer so a stationary page never
  /// costs an e-ink refresh every minute.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      ReaderReadingStatusBarVariant.standard => _buildStandard(context),
      ReaderReadingStatusBarVariant.eInk => _buildEInk(context),
    };
  }

  Widget _buildStandard(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    final textStyle = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: ReaderReadingStatusBarLayout.fontSize,
      height: ReaderReadingStatusBarLayout.lineHeight,
      letterSpacing: 0,
      color: foreground,
    );
    final progressStyle = textStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: progressForeground ?? foreground,
    );
    return _buildThreeSegmentBar(
      context,
      materialColor: Colors.transparent,
      textStyle: textStyle,
      progressStyle: progressStyle,
      horizontalPadding: ReaderReadingStatusBarLayout.eInkHorizontalPadding,
      verticalPadding: ReaderReadingStatusBarLayout.verticalPadding,
      leftKey: const Key('shared-reader-persistent-status-leading'),
      progressKey: const Key('shared-reader-persistent-status-trailing'),
      timeKey: const Key('shared-reader-persistent-status-time'),
    );
  }

  Widget _buildEInk(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    // The e-ink palette ignores the theme palette on purpose: it is a fixed
    // black/white contract tuned for panel contrast.
    final resolvedBackground = isDark
        ? const Color(0xFF141414)
        : const Color(0xFFFFFFFF);
    final resolvedForeground = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF444444);
    final dividerColor = isDark
        ? const Color(0xFF333333)
        : const Color(0xFFCCCCCC);
    final textStyle = TextStyle(
      fontSize: ReaderReadingStatusBarLayout.eInkFontSize,
      height: ReaderReadingStatusBarLayout.eInkLineHeight,
      letterSpacing: 0,
      color: resolvedForeground,
    );
    final progressStyle = textStyle.copyWith(fontWeight: FontWeight.w600);
    return _buildThreeSegmentBar(
      context,
      materialColor: resolvedBackground,
      surfaceKey: const Key('shared-reader-persistent-status-eink'),
      fixedHeight: ReaderReadingStatusBarLayout.eInkContentHeight,
      topBorderColor: dividerColor,
      textStyle: textStyle,
      progressStyle: progressStyle,
      horizontalPadding: ReaderReadingStatusBarLayout.eInkHorizontalPadding,
      leftKey: const Key('shared-reader-persistent-status-eink-left'),
      progressKey: const Key('shared-reader-persistent-status-eink-progress'),
      timeKey: const Key('shared-reader-persistent-status-eink-time'),
      directTextKeys: true,
    );
  }

  Widget _buildThreeSegmentBar(
    BuildContext context, {
    required Color materialColor,
    required TextStyle textStyle,
    required TextStyle progressStyle,
    required double horizontalPadding,
    required Key leftKey,
    required Key progressKey,
    required Key timeKey,
    bool directTextKeys = false,
    Key? surfaceKey,
    double? fixedHeight,
    double verticalPadding = 0,
    Color? topBorderColor,
  }) {
    final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(now ?? DateTime.now()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : screenWidth;
        final availableWidth = math.max(0.0, maxWidth - horizontalPadding * 2);
        final parts = _resolveStatusParts(
          availableWidth: availableWidth,
          textScaler: textScaler,
          textDirection: textDirection,
          textStyle: textStyle,
          progressStyle: progressStyle,
          timeText: formattedTime,
        );

        final leftWidget = parts.leftText.isEmpty
            ? const SizedBox.shrink()
            : directTextKeys
            ? Text(
                parts.leftText,
                key: leftKey,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              )
            : KeyedSubtree(
                key: leftKey,
                child: Text(
                  parts.leftText,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              );
        final progressTextWidget = Text(
          parts.progressText,
          key: directTextKeys ? progressKey : null,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: progressStyle,
        );
        final progressBox = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: parts.progressMaxWidth),
          child: progressTextWidget,
        );

        final row = Row(
          children: [
            Expanded(child: leftWidget),
            if (parts.progressText.isNotEmpty) ...[
              const SizedBox(width: _segmentGap),
              directTextKeys
                  ? progressBox
                  : KeyedSubtree(key: progressKey, child: progressBox),
            ],
            if (parts.showTime) ...[
              const SizedBox(width: _segmentGap),
              Text(
                parts.timeText,
                key: timeKey,
                maxLines: 1,
                softWrap: false,
                style: textStyle,
              ),
            ],
          ],
        );

        final barContent = topBorderColor != null || fixedHeight != null
            ? Container(
                key: surfaceKey,
                height: fixedHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                decoration: BoxDecoration(
                  color: materialColor,
                  border: topBorderColor == null
                      ? null
                      : Border(
                          top: BorderSide(
                            color: topBorderColor,
                            width:
                                ReaderReadingStatusBarLayout.eInkTopBorderWidth,
                          ),
                        ),
                ),
                child: row,
              )
            : Padding(
                key: surfaceKey,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: row,
              );

        return Semantics(
          container: true,
          label: parts.semanticsLabel,
          child: ExcludeSemantics(
            child: Material(
              key: const Key('shared-reader-persistent-status-bar'),
              color: materialColor,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: ReaderReadingStatusBarLayout.bottomInset(context),
                  ),
                  child: barContent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Resolves the three segments under the available width.
  ///
  /// The fixed degradation order is title, time, progress. Progress is never
  /// removed: it is ellipsized into the space the title/time drops free up.
  _StatusParts _resolveStatusParts({
    required double availableWidth,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required TextStyle textStyle,
    required TextStyle progressStyle,
    required String timeText,
  }) {
    final leading = status.leading;
    final title = status.title;
    final progressText = status.trailing;

    String leftTextFor({required bool includeTitle}) {
      final parts = <String>[
        if (leading.isNotEmpty) leading,
        if (includeTitle && title.isNotEmpty) title,
      ];
      return parts.join(' · ');
    }

    var includeTitle = title.isNotEmpty;
    var leftText = leftTextFor(includeTitle: includeTitle);
    var leftWidth = _measureText(
      leftText,
      textStyle,
      textScaler,
      textDirection,
    );
    final progressWidth = progressText.isEmpty
        ? 0.0
        : _measureText(progressText, progressStyle, textScaler, textDirection);
    final timeWidth = _measureText(
      timeText,
      textStyle,
      textScaler,
      textDirection,
    );

    double totalWidth({required bool withTime}) {
      var width = leftWidth;
      if (progressText.isNotEmpty) {
        width += _segmentGap + progressWidth;
      }
      if (withTime) {
        width += _segmentGap + timeWidth;
      }
      return width;
    }

    if (includeTitle && totalWidth(withTime: true) > availableWidth) {
      includeTitle = false;
      leftText = leftTextFor(includeTitle: false);
      leftWidth = _measureText(leftText, textStyle, textScaler, textDirection);
    }
    final showTime = totalWidth(withTime: true) <= availableWidth;
    // Progress is never dropped. When it cannot keep its intrinsic width it
    // gets at least 60% of the line and ellipsizes, so a long chapter ordinal
    // can still shrink instead of squeezing the progress away entirely.
    final progressMaxWidth = math.max(
      0.0,
      math.min(
        progressWidth,
        math.max(
          availableWidth - leftWidth - _segmentGap,
          availableWidth * _progressWidthFraction,
        ),
      ),
    );
    final semanticsLabel = [
      if (leftText.isNotEmpty) leftText,
      if (progressText.isNotEmpty) progressText,
      if (showTime) timeText,
    ].join('，');

    return _StatusParts(
      leftText: leftText,
      progressText: progressText,
      timeText: timeText,
      showTime: showTime,
      progressMaxWidth: progressMaxWidth,
      semanticsLabel: semanticsLabel.isEmpty
          ? status.semanticsLabel
          : semanticsLabel,
    );
  }
}

const double _segmentGap = 10;
const double _progressWidthFraction = 0.6;

double _measureText(
  String text,
  TextStyle style,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  if (text.isEmpty) {
    return 0;
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

@immutable
class _StatusParts {
  const _StatusParts({
    required this.leftText,
    required this.progressText,
    required this.timeText,
    required this.showTime,
    required this.progressMaxWidth,
    required this.semanticsLabel,
  });

  final String leftText;
  final String progressText;
  final String timeText;
  final bool showTime;
  final double progressMaxWidth;
  final String semanticsLabel;
}
