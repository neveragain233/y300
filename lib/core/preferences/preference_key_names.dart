/// Raw names behind the typed preference registry and compatibility aliases.
abstract final class PreferenceKeyNames {
  static const externalBrowser = 'app.links.external_browser.v1';
  static const restoreReader = 'reader.restore.enabled.v1';
  static const activeReader = 'reader.active.session.v1';
  static const appThemeColorSource = 'app_theme_color_source';
  static const appAppearanceSnapshotV1 = 'app.appearance.snapshot.v1';
  static const appThemeFamily = 'app_theme_family';
  static const readerHardwarePageKeys = 'reader_hardware_page_keys';
  static const readerImmersiveFullscreen = 'reader_immersive_fullscreen';
  static const readerBoldFont = 'reader_bold_font';
  static const appThemePreference = 'app_theme_preference';
  static const appLanguagePreference = 'app_language_preference';
  static const appNavigationSnapshotV1 = 'app.navigation.snapshot.v1';
  static const appUpdateReleaseNotesSnapshotV1 =
      'app.update.release_notes.snapshot.v1';
  static const dailyAutoSignInEnabledV1Prefix =
      'profile.daily_sign_in.auto_enabled.v1.';
  static const threadQuickScrollDockSide = 'thread.quick_scroll.dock_side.v1';
  static const threadControlsV1 = 'thread.controls.v1';

  static const forumHtmlReaderFontScale = 'forum_html_reader_font_scale';
  static const forumHtmlReaderFontFamily = 'reader.forum_html.font_family.v1';
  static const forumHtmlReaderLineHeightScale =
      'forum_html_reader_line_height_scale';
  static const forumHtmlReaderConversionMode =
      'forum_html_reader_conversion_mode';
  static const forumHtmlReaderPreserveAuthorFontSize =
      'forum_html_reader_preserve_author_font_size';
  static const forumHtmlReaderMigrationVersion =
      'forum_html_reader_migration_version';

  static const imageReaderSnapshotV1 = 'reader.image.v1';
  static const legacyImageReaderMode = 'reader_pref_mode';
  static const legacyImageReaderPageFit = 'reader_pref_page_fit';
  static const legacyImageReaderBackground = 'reader_pref_background';
  static const legacyImageReaderPageSpacing = 'reader_pref_page_spacing';
  static const legacyImageReaderShowPageIndicator =
      'reader_pref_show_page_indicator';

  static const novelReaderSnapshotV1 = 'reader.novel.v1';
  static const novelChapterInteractionsDockV1 =
      'reader.novel.chapter_interactions_dock.v1';
  static const novelReaderMigrationVersion = 'reader.novel.migration_version';
  static const novelChapterOpenModeV1 = 'novel.chapter_open_mode.v1';
  static const novelChapterOpenModeMigrationVersion =
      'novel.chapter_open_mode.migration_version';

  static const composerDefaultsSnapshotV1 = 'composer.defaults.v1';
  static const composerDraftMigrationVersion =
      'composer.drafts.migration_version';

  static const libraryShelfComicSnapshotV1 = 'library.shelf.comic.v1';
  static const libraryShelfNovelSnapshotV1 = 'library.shelf.novel.v1';
  static const libraryShelfFavoriteSnapshotV1 = 'library.shelf.favorite.v1';
  static const libraryShelfBookshelfSnapshotV1 = 'library.shelf.bookshelf.v1';
  static const libraryShelfComicMigrationVersion =
      'library.shelf.comic.migration_version';
  static const libraryShelfNovelMigrationVersion =
      'library.shelf.novel.migration_version';
  static const libraryShelfFavoriteMigrationVersion =
      'library.shelf.favorite.migration_version';
  static const libraryShelfBookshelfMigrationVersion =
      'library.shelf.bookshelf.migration_version';

  static const imageCacheMaxBytes = 'image_cache_max_bytes';
  static const cacheMaxBytesV1 = 'storage.cache.max_bytes.v1';
  static const legacyComicCacheDirectory = 'comic_cache_dir';
  static const legacyCacheRootMigrationVersion =
      'storage.cache_root.migration_version';
  static const downloadStorageDirectory = 'download_storage_dir';

  static const replyStickerLastGroupId = 'reply_sticker_last_group_id';

  static const contentFilterBlockedThreadsV1 =
      'content_filter.blocked_threads.v1';

  static const contentFilterBlockedKeywordsV1 =
      'content_filter.blocked_keywords.v1';

  static const contentFilterHideKeywordThreadsInListsV1 =
      'content_filter.hide_keyword_threads_in_lists.v1';

  static const contentFilterHideBlockedKeywordThreadsCompletelyV1 =
      'content_filter.hide_blocked_keyword_threads_completely.v1';

  static const contentFilterWebBlacklistSnapshotV1 =
      'content_filter.web_blacklist.snapshot.v1';

  static const contentFilterWebBlacklistPendingV1 =
      'content_filter.web_blacklist.pending.v1';

  static const blacklistHideInitiatedThreadsV1 =
      'blacklist.hide_initiated_threads.v1';

  static const recentSearchSnapshotV1 = 'search.recent.snapshot.v1';

  static const legacyThreadTextFontScale = 'thread_text_font_scale';
  static const legacyThreadTextLineHeightScale =
      'thread_text_line_height_scale';
}
