import 'package:flutter/widgets.dart';
import 'package:y300/core/config/app_edition.dart';

abstract final class AppLayoutTokens {
  static const double compactSpacing = 8;
  static const double contentSpacing = 16;
  static const double sectionSpacing = 24;
  static const double panelRadius = 16;
  static const double minimumTapTarget = 48;
  static const double readingMaxWidth = 760;
  static const double imageReadingMaxWidth = 960;
  static const Duration feedbackDuration = Duration(milliseconds: 200);

  static Duration motionDuration(BuildContext context) {
    if (AppEdition.isEInk) {
      return Duration.zero;
    }
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : feedbackDuration;
  }
}
