import 'package:y300/features/library_shared/presentation/reader/reader_page_turn_models.dart';
import 'package:y300/features/reader_shared/domain/export/reader_image_export.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/l10n/app_localizations.dart';

abstract final class ReaderTextResolver {
  static String mode(AppLocalizations l10n, ReaderModePreference value) {
    return switch (value) {
      ReaderModePreference.vertical => l10n.readerModeVertical,
      ReaderModePreference.ltr => l10n.readerModeLtr,
      ReaderModePreference.rtl => l10n.readerModeRtl,
    };
  }

  static String modeChoice(AppLocalizations l10n, ReaderModePreference value) {
    return switch (value) {
      ReaderModePreference.vertical => l10n.readerModeVerticalContinuous,
      ReaderModePreference.ltr => l10n.readerModeSingleLtr,
      ReaderModePreference.rtl => l10n.readerModeSingleRtl,
    };
  }

  static String pageFit(AppLocalizations l10n, ReaderPageFitPreference value) {
    return switch (value) {
      ReaderPageFitPreference.fitWidth => l10n.readerPageFitWidth,
      ReaderPageFitPreference.fitHeight => l10n.readerPageFitHeight,
      ReaderPageFitPreference.contain => l10n.readerPageFitContain,
    };
  }

  static String background(
    AppLocalizations l10n,
    ReaderBackgroundPreference value,
  ) {
    return switch (value) {
      ReaderBackgroundPreference.followTheme => l10n.readerBackgroundTheme,
      ReaderBackgroundPreference.black => l10n.readerBackgroundBlack,
      ReaderBackgroundPreference.white => l10n.readerBackgroundWhite,
      ReaderBackgroundPreference.gray => l10n.readerBackgroundGray,
    };
  }

  static String pageEffect(AppLocalizations l10n, ReaderPageEffect value) {
    return switch (value) {
      ReaderPageEffect.slide => l10n.novelPageEffectSlide,
      ReaderPageEffect.paper => l10n.novelPageEffectPaper,
      ReaderPageEffect.fade => l10n.novelPageEffectFade,
      ReaderPageEffect.cover => l10n.novelPageEffectCover,
    };
  }

  static String pageSpeed(AppLocalizations l10n, ReaderPageSpeed value) {
    return switch (value) {
      ReaderPageSpeed.relaxed => l10n.novelPageSpeedRelaxed,
      ReaderPageSpeed.standard => l10n.novelPageSpeedStandard,
      ReaderPageSpeed.brisk => l10n.novelPageSpeedBrisk,
    };
  }

  static String exportFailure(
    AppLocalizations l10n,
    ReaderImageExportFailureReason? reason,
  ) {
    return switch (reason) {
      ReaderImageExportFailureReason.cacheUnavailable =>
        l10n.readerExportCacheUnavailable,
      ReaderImageExportFailureReason.permissionDenied =>
        l10n.readerExportPermissionDenied,
      ReaderImageExportFailureReason.permissionRestricted =>
        l10n.readerExportPermissionRestricted,
      ReaderImageExportFailureReason.unsupportedPlatform =>
        l10n.readerExportUnsupportedPlatform,
      ReaderImageExportFailureReason.unsupportedFormat =>
        l10n.readerExportUnsupportedFormat,
      ReaderImageExportFailureReason.mediaWriteFailed ||
      null => l10n.readerExportFailed,
    };
  }
}
