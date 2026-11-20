import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'reader_models.dart';

/// One compact reading-status line shared by the novel reading modes.
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

  /// Chapter title used by the e-ink variant; the standard bar ignores it and
  /// keeps its established single-line geometry.
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
/// [standard] keeps the existing palette-driven line. [eInk] is the fixed
/// 24dp footer used while the runtime e-ink mode is on.
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

/// Persistent reading status shown below the reading viewport.
///
/// The chapter sits on the left and the mode-specific position on the right;
/// it deliberately avoids controls and any decorative progress line. Opening
/// the reader menu stays a center-tap action, and progress seeking stays in the
/// overlay bottom panel.
class ReaderReadingStatusBar extends StatelessWidget {
  const ReaderReadingStatusBar({
    super.key,
    required this.status,
    required this.background,
    required this.foreground,
    this.variant = ReaderReadingStatusBarVariant.standard,
    this.now,
  });

  final ReaderReadingStatus status;
  final Color background;
  final Color foreground;
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

    return Semantics(
      container: true,
      label: status.semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          key: const Key('shared-reader-persistent-status-bar'),
          color: background,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: ReaderReadingStatusBarLayout.bottomInset(context),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ReaderReadingStatusBarLayout.horizontalPadding,
                  vertical: ReaderReadingStatusBarLayout.verticalPadding,
                ),
                child: Row(
                  children: [
                    // 左侧占满剩余宽度，右侧按内容宽度贴住右边缘；两者都
                    // 用 flex 会把空白对半分，右下角就只剩半个屏宽。
                    Expanded(
                      child: status.leading.isEmpty
                          ? const SizedBox.shrink()
                          : _StatusText(
                              key: const Key(
                                'shared-reader-persistent-status-leading',
                              ),
                              text: status.leading,
                              style: textStyle,
                              alignment: TextAlign.start,
                            ),
                    ),
                    if (status.trailing.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _StatusText(
                        key: const Key(
                          'shared-reader-persistent-status-trailing',
                        ),
                        text: status.trailing,
                        style: textStyle,
                        alignment: TextAlign.end,
                        maxWidth: MediaQuery.sizeOf(context).width * 0.6,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
        final availableWidth = math.max(
          0.0,
          maxWidth - ReaderReadingStatusBarLayout.eInkHorizontalPadding * 2,
        );
        final parts = _resolveEInkParts(
          availableWidth: availableWidth,
          textScaler: textScaler,
          textDirection: textDirection,
          textStyle: textStyle,
          progressStyle: progressStyle,
          timeText: formattedTime,
        );

        return Semantics(
          container: true,
          label: parts.semanticsLabel,
          child: ExcludeSemantics(
            child: Material(
              key: const Key('shared-reader-persistent-status-bar'),
              color: resolvedBackground,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: ReaderReadingStatusBarLayout.bottomInset(context),
                  ),
                  child: Container(
                    key: const Key('shared-reader-persistent-status-eink'),
                    height: ReaderReadingStatusBarLayout.eInkContentHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal:
                          ReaderReadingStatusBarLayout.eInkHorizontalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: resolvedBackground,
                      border: Border(
                        top: BorderSide(
                          color: dividerColor,
                          width:
                              ReaderReadingStatusBarLayout.eInkTopBorderWidth,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: parts.leftText.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  parts.leftText,
                                  key: const Key(
                                    'shared-reader-persistent-status-eink-left',
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle,
                                ),
                        ),
                        if (parts.progressText.isNotEmpty) ...[
                          const SizedBox(width: _eInkSegmentGap),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: parts.progressMaxWidth,
                            ),
                            child: Text(
                              parts.progressText,
                              key: const Key(
                                'shared-reader-persistent-status-eink-progress',
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: progressStyle,
                            ),
                          ),
                        ],
                        if (parts.showTime) ...[
                          const SizedBox(width: _eInkSegmentGap),
                          Text(
                            parts.timeText,
                            key: const Key(
                              'shared-reader-persistent-status-eink-time',
                            ),
                            maxLines: 1,
                            softWrap: false,
                            style: textStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Resolves the three e-ink segments under the available width.
  ///
  /// The fixed degradation order is title, time, progress. Progress is never
  /// removed: it is ellipsized into the space the title/time drops free up.
  _EInkStatusParts _resolveEInkParts({
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
    var leftWidth = _measureEInkText(
      leftText,
      textStyle,
      textScaler,
      textDirection,
    );
    final progressWidth = progressText.isEmpty
        ? 0.0
        : _measureEInkText(
            progressText,
            progressStyle,
            textScaler,
            textDirection,
          );
    final timeWidth = _measureEInkText(
      timeText,
      textStyle,
      textScaler,
      textDirection,
    );

    double totalWidth({required bool withTime}) {
      var width = leftWidth;
      if (progressText.isNotEmpty) {
        width += _eInkSegmentGap + progressWidth;
      }
      if (withTime) {
        width += _eInkSegmentGap + timeWidth;
      }
      return width;
    }

    if (includeTitle && totalWidth(withTime: true) > availableWidth) {
      includeTitle = false;
      leftText = leftTextFor(includeTitle: false);
      leftWidth = _measureEInkText(
        leftText,
        textStyle,
        textScaler,
        textDirection,
      );
    }
    var showTime = totalWidth(withTime: true) <= availableWidth;
    // Progress is never dropped. When it cannot keep its intrinsic width it
    // gets at least 60% of the line and ellipsizes, so a long chapter ordinal
    // can still shrink instead of squeezing the progress away entirely.
    final progressMaxWidth = math.max(
      0.0,
      math.min(
        progressWidth,
        math.max(
          availableWidth - leftWidth - _eInkSegmentGap,
          availableWidth * _eInkProgressWidthFraction,
        ),
      ),
    );
    final semanticsLabel = [
      if (leftText.isNotEmpty) leftText,
      if (progressText.isNotEmpty) progressText,
      if (showTime) timeText,
    ].join('，');

    return _EInkStatusParts(
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

const double _eInkSegmentGap = 10;
const double _eInkProgressWidthFraction = 0.6;

double _measureEInkText(
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
class _EInkStatusParts {
  const _EInkStatusParts({
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

class _StatusText extends StatelessWidget {
  const _StatusText({
    super.key,
    required this.text,
    required this.style,
    required this.alignment,
    this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final TextAlign alignment;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment,
      style: style,
    );
    final width = maxWidth;
    return width == null
        ? child
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: child,
          );
  }
}
