import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_key_names.dart';

/// Canonical registry for fixed-size device preference keys.
///
/// Existing scalar names remain unchanged for compatibility. New multi-field
/// snapshots use a domain-scoped, versioned name.
abstract final class PreferenceKeys {
  static const appThemeColorSource = PreferenceKey<String>(
    PreferenceKeyNames.appThemeColorSource,
  );
  static const appAppearanceSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.appAppearanceSnapshotV1,
  );
  static const appThemeFamily = PreferenceKey<String>(
    PreferenceKeyNames.appThemeFamily,
  );
  static const appThemePreference = PreferenceKey<String>(
    PreferenceKeyNames.appThemePreference,
  );
  static const appLanguagePreference = PreferenceKey<String>(
    PreferenceKeyNames.appLanguagePreference,
  );
  static const appNavigationSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.appNavigationSnapshotV1,
  );
  static const appUpdateReleaseNotesSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.appUpdateReleaseNotesSnapshotV1,
  );
  static PreferenceKey<bool> dailyAutoSignInEnabledForUid(String userId) =>
      PreferenceKey<bool>(
        '${PreferenceKeyNames.dailyAutoSignInEnabledV1Prefix}$userId',
      );
  static const threadQuickScrollDockSide = PreferenceKey<String>(
    PreferenceKeyNames.threadQuickScrollDockSide,
  );
  static const threadControlsV1 = PreferenceKey<String>(
    PreferenceKeyNames.threadControlsV1,
  );

  static const forumHtmlReaderFontScale = PreferenceKey<double>(
    PreferenceKeyNames.forumHtmlReaderFontScale,
  );
  static const forumHtmlReaderFontFamily = PreferenceKey<String>(
    PreferenceKeyNames.forumHtmlReaderFontFamily,
  );
  static const forumHtmlReaderLineHeightScale = PreferenceKey<double>(
    PreferenceKeyNames.forumHtmlReaderLineHeightScale,
  );
  static const forumHtmlReaderConversionMode = PreferenceKey<String>(
    PreferenceKeyNames.forumHtmlReaderConversionMode,
  );
  static const forumHtmlReaderPreserveAuthorFontSize = PreferenceKey<bool>(
    PreferenceKeyNames.forumHtmlReaderPreserveAuthorFontSize,
  );
  static const forumHtmlReaderMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.forumHtmlReaderMigrationVersion,
  );

  static const imageReaderSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.imageReaderSnapshotV1,
  );
  static const legacyImageReaderMode = PreferenceKey<String>(
    PreferenceKeyNames.legacyImageReaderMode,
  );
  static const legacyImageReaderPageFit = PreferenceKey<String>(
    PreferenceKeyNames.legacyImageReaderPageFit,
  );
  static const legacyImageReaderBackground = PreferenceKey<String>(
    PreferenceKeyNames.legacyImageReaderBackground,
  );
  static const legacyImageReaderPageSpacing = PreferenceKey<double>(
    PreferenceKeyNames.legacyImageReaderPageSpacing,
  );
  static const legacyImageReaderShowPageIndicator = PreferenceKey<bool>(
    PreferenceKeyNames.legacyImageReaderShowPageIndicator,
  );

  /// 阅读器硬件键翻页（音量键/侧边翻页键）开关，漫画与小说阅读器共用。
  static const readerHardwarePageKeys = PreferenceKey<bool>(
    PreferenceKeyNames.readerHardwarePageKeys,
  );

  /// 阅读器沉浸全屏（隐藏状态栏与底部导航条）开关，漫画与小说阅读器共用。
  static const readerImmersiveFullscreen = PreferenceKey<bool>(
    PreferenceKeyNames.readerImmersiveFullscreen,
  );

  /// 全应用加粗字体；墨水屏阅读器与普通界面共用同一份设置。
  static const readerBoldFont = PreferenceKey<bool>(
    PreferenceKeyNames.readerBoldFont,
  );

  static const novelReaderSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.novelReaderSnapshotV1,
  );
  static const novelChapterInteractionsDockV1 = PreferenceKey<String>(
    PreferenceKeyNames.novelChapterInteractionsDockV1,
  );
  static const novelReaderMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.novelReaderMigrationVersion,
  );
  static const novelChapterOpenModeV1 = PreferenceKey<String>(
    PreferenceKeyNames.novelChapterOpenModeV1,
  );
  static const novelChapterOpenModeMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.novelChapterOpenModeMigrationVersion,
  );

  static const composerDefaultsSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.composerDefaultsSnapshotV1,
  );
  static const composerDraftMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.composerDraftMigrationVersion,
  );

  static const libraryShelfComicSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.libraryShelfComicSnapshotV1,
  );
  static const libraryShelfNovelSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.libraryShelfNovelSnapshotV1,
  );
  static const libraryShelfFavoriteSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.libraryShelfFavoriteSnapshotV1,
  );
  static const libraryShelfBookshelfSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.libraryShelfBookshelfSnapshotV1,
  );
  static const libraryShelfComicMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.libraryShelfComicMigrationVersion,
  );
  static const libraryShelfNovelMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.libraryShelfNovelMigrationVersion,
  );
  static const libraryShelfFavoriteMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.libraryShelfFavoriteMigrationVersion,
  );
  static const libraryShelfBookshelfMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.libraryShelfBookshelfMigrationVersion,
  );

  static const imageCacheMaxBytes = PreferenceKey<int>(
    PreferenceKeyNames.imageCacheMaxBytes,
  );
  static const cacheMaxBytesV1 = PreferenceKey<int>(
    PreferenceKeyNames.cacheMaxBytesV1,
  );
  static const legacyComicCacheDirectory = PreferenceKey<String>(
    PreferenceKeyNames.legacyComicCacheDirectory,
  );
  static const legacyCacheRootMigrationVersion = PreferenceKey<int>(
    PreferenceKeyNames.legacyCacheRootMigrationVersion,
  );
  static const downloadStorageDirectory = PreferenceKey<String>(
    PreferenceKeyNames.downloadStorageDirectory,
  );

  static const replyStickerLastGroupId = PreferenceKey<String>(
    PreferenceKeyNames.replyStickerLastGroupId,
  );

  static const contentFilterBlockedThreadsV1 = PreferenceKey<String>(
    PreferenceKeyNames.contentFilterBlockedThreadsV1,
  );

  static const contentFilterWebBlacklistSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.contentFilterWebBlacklistSnapshotV1,
  );

  static const blacklistHideInitiatedThreadsV1 = PreferenceKey<bool>(
    PreferenceKeyNames.blacklistHideInitiatedThreadsV1,
  );

  static const recentSearchSnapshotV1 = PreferenceKey<String>(
    PreferenceKeyNames.recentSearchSnapshotV1,
  );

  static const legacyThreadTextFontScale = PreferenceKey<double>(
    PreferenceKeyNames.legacyThreadTextFontScale,
  );
  static const legacyThreadTextLineHeightScale = PreferenceKey<double>(
    PreferenceKeyNames.legacyThreadTextLineHeightScale,
  );
}
