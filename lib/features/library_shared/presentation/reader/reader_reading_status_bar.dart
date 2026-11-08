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
    required this.center,
    required this.trailing,
    required this.semanticsLabel,
    this.progress,
  });

  final String leading;
  final String center;
  final String trailing;
  final String semanticsLabel;

  /// Fraction in `0..1`; null keeps the progress line invisible but reserved.
  final double? progress;

  @override
  bool operator ==(Object other) {
    return other is ReaderReadingStatus &&
        other.leading == leading &&
        other.center == center &&
        other.trailing == trailing &&
        other.semanticsLabel == semanticsLabel &&
        other.progress == progress;
  }

  @override
  int get hashCode =>
      Object.hash(leading, center, trailing, semanticsLabel, progress);
}

abstract final class ReaderReadingStatusBarLayout {
  static const double fontSize = 11;
  static const double lineHeight = 1.2;
  static const double horizontalPadding = 12;
  static const double verticalPadding = 5;
  static const double progressLineHeight = 2;
  static const double borderWidth = 0.5;
  static const double minimumBottomInset = 4;

  /// Height of the bar content excluding the system bottom safe area.
  ///
  /// The floating dock location already accounts for the system safe area, so
  /// callers that need to sit above the bar must not add the inset twice.
  static double contentHeight(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return progressLineHeight +
        textScaler.scale(fontSize) * lineHeight +
        verticalPadding * 2 +
        borderWidth;
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

  /// Extra offset for a floating control above the bar.
  ///
  /// The Scaffold floating-action location already adds the system bottom
  /// padding; only the remainder belongs in the dock's own clearance.
  static double dockClearance(BuildContext context) {
    return height(context) - MediaQuery.paddingOf(context).bottom + 8;
  }
}

/// Persistent reading status shown below the reading viewport.
///
/// It deliberately avoids controls: opening the reader menu stays a center-tap
/// action, and progress seeking stays in the overlay bottom panel.
class ReaderReadingStatusBar extends StatelessWidget {
  const ReaderReadingStatusBar({
    super.key,
    required this.status,
    required this.background,
    required this.foreground,
    required this.divider,
    required this.progressColor,
  });

  final ReaderReadingStatus status;
  final Color background;
  final Color foreground;
  final Color divider;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    final textStyle = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: ReaderReadingStatusBarLayout.fontSize,
      height: ReaderReadingStatusBarLayout.lineHeight,
      letterSpacing: 0,
      color: foreground,
    );
    final progress = status.progress?.clamp(0.0, 1.0).toDouble();

    return Semantics(
      container: true,
      label: status.semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          key: const Key('shared-reader-persistent-status-bar'),
          color: background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: divider,
                  width: ReaderReadingStatusBarLayout.borderWidth,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: ReaderReadingStatusBarLayout.bottomInset(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: ReaderReadingStatusBarLayout.progressLineHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            key: const Key(
                              'shared-reader-persistent-status-progress-track',
                            ),
                            color: divider,
                          ),
                          if (progress != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FractionallySizedBox(
                                key: const Key(
                                  'shared-reader-persistent-status-progress',
                                ),
                                widthFactor: progress,
                                child: ColoredBox(color: progressColor),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal:
                            ReaderReadingStatusBarLayout.horizontalPadding,
                        vertical: ReaderReadingStatusBarLayout.verticalPadding,
                      ),
                      child: Row(
                        children: [
                          if (status.leading.isNotEmpty)
                            Flexible(
                              flex: 3,
                              child: _StatusText(
                                key: const Key(
                                  'shared-reader-persistent-status-leading',
                                ),
                                text: status.leading,
                                style: textStyle,
                                alignment: TextAlign.start,
                              ),
                            ),
                          if (status.leading.isNotEmpty &&
                              (status.center.isNotEmpty ||
                                  status.trailing.isNotEmpty))
                            const SizedBox(width: 8),
                          if (status.center.isNotEmpty)
                            Flexible(
                              flex: 5,
                              child: _StatusText(
                                key: const Key(
                                  'shared-reader-persistent-status-center',
                                ),
                                text: status.center,
                                style: textStyle,
                                alignment: TextAlign.center,
                              ),
                            ),
                          if (status.trailing.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 3,
                              child: _StatusText(
                                key: const Key(
                                  'shared-reader-persistent-status-trailing',
                                ),
                                text: status.trailing,
                                style: textStyle,
                                alignment: TextAlign.end,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    super.key,
    required this.text,
    required this.style,
    required this.alignment,
  });

  final String text;
  final TextStyle style;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment,
      style: style,
    );
  }
}
