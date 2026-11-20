import 'package:y300/l10n/app_localizations.dart';

/// 设置搜索能打开的目标页面。
enum SettingsSearchPageKind { settings, appearance }

/// 设置搜索能定位到的目标：页面整体或页面内的一个分组。
///
/// 设置主页四组与外观页五组、恢复默认各有锚点；导航管理、内容屏蔽、
/// 帖子悬浮操作、数据与存储和关于是整页打开，没有分组锚点。
enum SettingsSearchTarget {
  settingsAppearanceNavigation,
  settingsBrowsingPosts,
  settingsStorageAbout,
  settingsDebug,
  appearanceTop,
  appearanceThemeMode,
  appearanceColorTheme,
  appearanceGlass,
  appearanceEInk,
  appearanceBoldFont,
  appearanceNavigation,
  appearanceLanguage,
  appearanceReset,
  navigationManagement,
  contentFilter,
  threadControls,
  dataStorage,
  about;

  SettingsSearchPageKind get page => switch (this) {
    settingsAppearanceNavigation ||
    settingsBrowsingPosts ||
    settingsStorageAbout ||
    settingsDebug ||
    navigationManagement ||
    contentFilter ||
    threadControls ||
    dataStorage ||
    about => SettingsSearchPageKind.settings,
    appearanceTop ||
    appearanceThemeMode ||
    appearanceColorTheme ||
    appearanceGlass ||
    appearanceEInk ||
    appearanceBoldFont ||
    appearanceNavigation ||
    appearanceLanguage ||
    appearanceReset => SettingsSearchPageKind.appearance,
  };

  /// 目标是否为页面内分组：true 时滚动到锚点，false 时整页打开。
  bool get isSectionAnchor => switch (this) {
    navigationManagement ||
    contentFilter ||
    threadControls ||
    dataStorage ||
    about => false,
    _ => true,
  };
}

/// 一条设置搜索索引：显示用的标题与摘要，加只在匹配时使用的关键词串。
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.id,
    required this.target,
    required this.title,
    required this.summary,
    required this.keywords,
  });

  /// 稳定标识，用于结果行 Key 与常用入口筛选。
  final String id;
  final SettingsSearchTarget target;
  final String title;
  final String summary;

  /// 同义说法串，不展示；按包含匹配参与命中。
  final String keywords;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return title.toLowerCase().contains(normalized) ||
        summary.toLowerCase().contains(normalized) ||
        keywords.toLowerCase().contains(normalized);
  }
}

/// 显式索引：条目顺序就是设置主页四组与外观页各组的展示顺序。
///
/// 不建倒排索引、不做拼音转换，匹配只在标题、摘要和关键词串上做包含判断；
/// 调试分组仅调试构建可见，由 [includeDebug] 决定是否收录。
List<SettingsSearchEntry> buildSettingsSearchIndex(
  AppLocalizations l10n, {
  bool includeDebug = false,
}) {
  return <SettingsSearchEntry>[
    SettingsSearchEntry(
      id: 'settings-section-appearance-navigation',
      target: SettingsSearchTarget.settingsAppearanceNavigation,
      title: l10n.settingsSectionAppearanceNavigation,
      summary: l10n.settingsSearchSummaryAppearanceNavigation,
      keywords: l10n.settingsSearchKeywordsAppearanceNavigation,
    ),
    SettingsSearchEntry(
      id: 'appearance',
      target: SettingsSearchTarget.appearanceTop,
      title: l10n.appearanceTitle,
      summary: l10n.settingsSearchSummaryAppearance,
      keywords: l10n.settingsSearchKeywordsAppearance,
    ),
    SettingsSearchEntry(
      id: 'navigation-management',
      target: SettingsSearchTarget.navigationManagement,
      title: l10n.moreNavigationManagement,
      summary: l10n.settingsSearchSummaryNavigationManagement,
      keywords: l10n.settingsSearchKeywordsNavigationManagement,
    ),
    SettingsSearchEntry(
      id: 'settings-section-browsing-posts',
      target: SettingsSearchTarget.settingsBrowsingPosts,
      title: l10n.settingsSectionBrowsingPosts,
      summary: l10n.settingsSearchSummaryBrowsingPosts,
      keywords: l10n.settingsSearchKeywordsBrowsingPosts,
    ),
    SettingsSearchEntry(
      id: 'content-filter',
      target: SettingsSearchTarget.contentFilter,
      title: l10n.contentFilterEntry,
      summary: l10n.settingsSearchSummaryContentFilter,
      keywords: l10n.settingsSearchKeywordsContentFilter,
    ),
    SettingsSearchEntry(
      id: 'thread-controls',
      target: SettingsSearchTarget.threadControls,
      title: l10n.threadControlsTitle,
      summary: l10n.settingsSearchSummaryThreadControls,
      keywords: l10n.settingsSearchKeywordsThreadControls,
    ),
    SettingsSearchEntry(
      id: 'settings-section-storage-about',
      target: SettingsSearchTarget.settingsStorageAbout,
      title: l10n.settingsSectionStorageAbout,
      summary: l10n.settingsSearchSummaryStorageAbout,
      keywords: l10n.settingsSearchKeywordsStorageAbout,
    ),
    SettingsSearchEntry(
      id: 'data-storage',
      target: SettingsSearchTarget.dataStorage,
      title: l10n.moreDataAndStorage,
      summary: l10n.settingsSearchSummaryDataStorage,
      keywords: l10n.settingsSearchKeywordsDataStorage,
    ),
    SettingsSearchEntry(
      id: 'about',
      target: SettingsSearchTarget.about,
      title: l10n.moreAbout,
      summary: l10n.settingsSearchSummaryAbout,
      keywords: l10n.settingsSearchKeywordsAbout,
    ),
    if (includeDebug)
      SettingsSearchEntry(
        id: 'settings-section-debug',
        target: SettingsSearchTarget.settingsDebug,
        title: l10n.settingsSectionDebug,
        summary: l10n.settingsSearchSummaryDebug,
        keywords: l10n.settingsSearchKeywordsDebug,
      ),
    SettingsSearchEntry(
      id: 'appearance-theme-mode',
      target: SettingsSearchTarget.appearanceThemeMode,
      title: l10n.appearanceThemeModeSectionTitle,
      summary: l10n.settingsSearchSummaryThemeMode,
      keywords: l10n.settingsSearchKeywordsThemeMode,
    ),
    SettingsSearchEntry(
      id: 'appearance-color-theme',
      target: SettingsSearchTarget.appearanceColorTheme,
      title: l10n.moreColorThemeSectionTitle,
      summary: l10n.settingsSearchSummaryColorTheme,
      keywords: l10n.settingsSearchKeywordsColorTheme,
    ),
    SettingsSearchEntry(
      id: 'appearance-bold-font',
      target: SettingsSearchTarget.appearanceBoldFont,
      title: l10n.appearanceTextSectionTitle,
      summary: l10n.settingsSearchSummaryBoldFont,
      keywords: l10n.settingsSearchKeywordsBoldFont,
    ),
    SettingsSearchEntry(
      id: 'appearance-glass',
      target: SettingsSearchTarget.appearanceGlass,
      title: l10n.moreGlassSectionTitle,
      summary: l10n.settingsSearchSummaryGlass,
      keywords: l10n.settingsSearchKeywordsGlass,
    ),
    SettingsSearchEntry(
      id: 'appearance-eink',
      target: SettingsSearchTarget.appearanceEInk,
      title: l10n.appearanceEInkSectionTitle,
      summary: l10n.settingsSearchSummaryEInk,
      keywords: l10n.settingsSearchKeywordsEInk,
    ),
    SettingsSearchEntry(
      id: 'appearance-navigation',
      target: SettingsSearchTarget.appearanceNavigation,
      title: l10n.moreNavigationSectionTitle,
      summary: l10n.settingsSearchSummaryNavigation,
      keywords: l10n.settingsSearchKeywordsNavigation,
    ),
    SettingsSearchEntry(
      id: 'appearance-language',
      target: SettingsSearchTarget.appearanceLanguage,
      title: l10n.appLanguageSectionTitle,
      summary: l10n.settingsSearchSummaryLanguage,
      keywords: l10n.settingsSearchKeywordsLanguage,
    ),
    SettingsSearchEntry(
      id: 'appearance-reset',
      target: SettingsSearchTarget.appearanceReset,
      title: l10n.appearanceResetAction,
      summary: l10n.settingsSearchSummaryReset,
      keywords: l10n.settingsSearchKeywordsReset,
    ),
  ];
}

/// 空输入时展示的常用入口，按索引顺序取用。
const List<String> settingsSearchRecommendedIds = <String>[
  'appearance',
  'appearance-theme-mode',
  'appearance-glass',
  'content-filter',
  'data-storage',
  'about',
];

/// 从已建好的索引里挑出常用入口，保持索引顺序。
List<SettingsSearchEntry> recommendedSettingsSearchEntries(
  List<SettingsSearchEntry> index,
) {
  return <SettingsSearchEntry>[
    for (final entry in index)
      if (settingsSearchRecommendedIds.contains(entry.id)) entry,
  ];
}
