import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/links/external_link_opener.dart';
import 'package:y300/core/network/forum_availability.dart';
import 'package:y300/features/reader_shared/application/active_reader_session.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/core/config/app_config.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/content_filter/presentation/content_filter_page.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_driver.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_route_factory.dart';
import 'package:y300/features/more/presentation/about_page.dart';
import 'package:y300/features/more/presentation/appearance_page.dart';
import 'package:y300/features/more/presentation/data_storage_page.dart';
import 'package:y300/features/more/presentation/more_debug_tools.dart';
import 'package:y300/features/more/presentation/navigation_management_page.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_anchor.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_index.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_page.dart';
import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/presentation/thread_controls_preferences_controller.dart';
import 'package:y300/features/thread/presentation/thread_controls_settings_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 全屏设置主页：把原先散在“我的”里的应用偏好收敛为四个分组。
///
/// 进入下级页的行显示箭头；数据与存储进入独立全屏页；调试分组只
/// 在 Debug 构建出现。外观、导航管理等沿用原页面和原保存路径，这里只负责
/// 入口和路由。
///
/// 顶栏搜索入口打开本地索引搜索页；选中结果后由本页统一转场：设置内分组
/// 就地滚动并短暂高亮，外观分组压入带锚点的外观页，下级页直接打开。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.debugTools = const MoreDebugTools()});

  static const String routeName = '/more/settings';

  /// 可注入的调试工具入口，便于验证分组门控；生产默认取 Debug 构建的行。
  final MoreDebugTools debugTools;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final SettingsSearchRevealController _revealController =
      SettingsSearchRevealController();

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigationReady =
        ref.watch(mainNavigationSettingsControllerProvider).value != null;
    final controlsPreferences = ref
        .watch(threadControlsPreferencesControllerProvider)
        .value;
    final externalBrowser = ref.watch(externalBrowserPreferenceProvider).value;
    final debugTiles = widget.debugTools.buildTiles(context, l10n);
    return Scaffold(
      key: const Key('settings-page'),
      appBar: AppPageAppBar(
        title: l10n.moreSectionSettings,
        actions: [
          IconButton(
            key: const Key('settings-search-entry'),
            tooltip: l10n.settingsSearchTooltip,
            style: IconButton.styleFrom(minimumSize: const Size.square(48)),
            onPressed: () => _openSearch(includeDebug: debugTiles.isNotEmpty),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              key: const Key('settings-page-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _anchor(
                    SettingsSearchTarget.settingsAppearanceNavigation,
                    AppGroupedSection(
                      title: l10n.settingsSectionAppearanceNavigation,
                      margin: EdgeInsets.zero,
                      children: [
                        AppGroupedRow(
                          key: const Key('more-appearance-entry'),
                          leading: const Icon(Icons.palette_outlined),
                          title: l10n.appearanceTitle,
                          showChevron: true,
                          onTap: () => _pushPage(const AppearancePage()),
                        ),
                        AppGroupedRow(
                          key: const Key('more-navigation-management-entry'),
                          leading: const Icon(Icons.view_week_outlined),
                          title: l10n.moreNavigationManagement,
                          enabled: navigationReady,
                          showChevron: true,
                          onTap: navigationReady
                              ? () =>
                                    _pushPage(const NavigationManagementPage())
                              : null,
                        ),
                      ],
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.settingsBrowsingPosts,
                    AppGroupedSection(
                      title: l10n.settingsSectionBrowsingPosts,
                      margin: EdgeInsets.zero,
                      children: [
                        AppGroupedRow(
                          key: const Key('more-content-filter-entry'),
                          leading: const Icon(Icons.visibility_off_outlined),
                          title: l10n.contentFilterEntry,
                          showChevron: true,
                          onTap: _pushContentFilter,
                        ),
                        AppGroupedRow(
                          key: const Key('more-thread-controls-entry'),
                          leading: const Icon(Icons.touch_app_outlined),
                          title: l10n.threadControlsTitle,
                          showChevron: true,
                          onTap: () =>
                              _pushPage(const ThreadControlsSettingsPage()),
                        ),
                        AppSwitchRow(
                          key: const Key('settings-restore-active-reader'),
                          title: l10n.restoreActiveReader,
                          leading: const Icon(Icons.auto_stories_outlined),
                          value:
                              ref
                                  .watch(restoreReaderPreferenceProvider)
                                  .value ??
                              false,
                          disabled: !ref
                              .watch(restoreReaderPreferenceProvider)
                              .hasValue,
                          onChanged: (enabled) async {
                            try {
                              await ref
                                  .read(
                                    restoreReaderPreferenceProvider.notifier,
                                  )
                                  .set(enabled);
                            } catch (_) {
                              if (context.mounted) {
                                showTransientSnackBar(
                                  context,
                                  l10n.threadControlsSaveFailed,
                                );
                              }
                            }
                          },
                        ),
                        AppSwitchRow(
                          key: const Key('settings-cache-only'),
                          title: l10n.networkForceCache,
                          leading: const Icon(Icons.offline_bolt_outlined),
                          value: ref.watch(forumAvailabilityProvider).forced,
                          onChanged: ref
                              .read(forumAvailabilityProvider)
                              .setManual,
                        ),
                        AppGroupedRow(
                          leading: const Icon(Icons.open_in_browser),
                          key: const Key('settings-external-browser'),
                          title: l10n.externalBrowserPreference,
                          subtitle: externalBrowser == true
                              ? l10n.externalBrowserStandalone
                              : l10n.externalBrowserInApp,
                          enabled: externalBrowser != null,
                          onTap: externalBrowser == null
                              ? null
                              : () async {
                                  final next = await showDialog<bool>(
                                    context: context,
                                    builder: (dialog) => SimpleDialog(
                                      title: Text(
                                        l10n.externalBrowserPreference,
                                      ),
                                      children: [
                                        for (final value in [false, true])
                                          AppGroupedRow(
                                            title: value
                                                ? l10n.externalBrowserStandalone
                                                : l10n.externalBrowserInApp,
                                            selected: value == externalBrowser,
                                            trailing: value == externalBrowser
                                                ? const Icon(Icons.check)
                                                : null,
                                            onTap: () =>
                                                Navigator.pop(dialog, value),
                                          ),
                                      ],
                                    ),
                                  );
                                  if (next == null || !mounted) return;
                                  try {
                                    await ref
                                        .read(
                                          externalBrowserPreferenceProvider
                                              .notifier,
                                        )
                                        .set(next);
                                  } catch (_) {
                                    if (context.mounted) {
                                      showTransientSnackBar(
                                        context,
                                        l10n.threadControlsSaveFailed,
                                      );
                                    }
                                  }
                                },
                        ),
                        AppSwitchRow(
                          key: const Key('settings-expand-ratings-by-default'),
                          leading: const Icon(Icons.favorite_outline),
                          title: l10n.threadExpandRatingsByDefault,
                          subtitle: l10n.threadExpandRatingsByDefaultHint,
                          disabled: controlsPreferences == null,
                          value:
                              controlsPreferences?.expandRatingsByDefault ??
                              true,
                          onChanged: controlsPreferences == null
                              ? null
                              : (value) => unawaited(
                                  _saveThreadPreferences(
                                    context,
                                    l10n,
                                    controlsPreferences.copyWith(
                                      expandRatingsByDefault: value,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.settingsStorageAbout,
                    AppGroupedSection(
                      title: l10n.settingsSectionStorageAbout,
                      margin: EdgeInsets.zero,
                      children: [
                        AppGroupedRow(
                          key: const Key('more-data-storage-entry'),
                          leading: const Icon(Icons.storage_outlined),
                          title: l10n.moreDataAndStorage,
                          showChevron: true,
                          onTap: () => _pushPage(const DataStoragePage()),
                        ),
                        AppGroupedRow(
                          key: const Key('more-about-entry'),
                          leading: const Icon(Icons.info_outline),
                          title: l10n.moreAbout,
                          showChevron: true,
                          onTap: () => _pushPage(const AboutPage()),
                        ),
                      ],
                    ),
                  ),
                  if (debugTiles.isNotEmpty)
                    _anchor(
                      SettingsSearchTarget.settingsDebug,
                      AppGroupedSection(
                        title: l10n.settingsSectionDebug,
                        margin: EdgeInsets.zero,
                        children: debugTiles,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 分组间距放在锚点外，高亮描边只围住标题与分组表面。
  Widget _anchor(SettingsSearchTarget target, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SettingsSearchSectionAnchor(
        key: Key('settings-search-anchor-${target.name}'),
        revealController: _revealController,
        target: target,
        child: child,
      ),
    );
  }

  Future<void> _openSearch({required bool includeDebug}) async {
    final target = await Navigator.of(context).push<SettingsSearchTarget>(
      MaterialPageRoute<SettingsSearchTarget>(
        settings: const RouteSettings(name: SettingsSearchPage.routeName),
        builder: (_) => SettingsSearchPage(includeDebug: includeDebug),
      ),
    );
    if (!mounted || target == null) {
      return;
    }
    await _openSearchTarget(target);
  }

  /// 搜索结果只有一条统一转场：设置内分组就地定位，其余页面压入或弹层。
  Future<void> _openSearchTarget(SettingsSearchTarget target) async {
    if (target.page == SettingsSearchPageKind.appearance) {
      await _pushPage(AppearancePage(initialSection: target));
      return;
    }
    if (target.isSectionAnchor) {
      _revealController.reveal(target);
      return;
    }
    switch (target) {
      case SettingsSearchTarget.navigationManagement:
        await _pushPage(const NavigationManagementPage());
      case SettingsSearchTarget.contentFilter:
        await _pushContentFilter();
      case SettingsSearchTarget.threadControls:
        await _pushPage(const ThreadControlsSettingsPage());
      case SettingsSearchTarget.dataStorage:
        await _pushPage(const DataStoragePage());
      case SettingsSearchTarget.about:
        await _pushPage(const AboutPage());
      default:
        break;
    }
  }

  Future<void> _pushPage(Widget page) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _saveThreadPreferences(
    BuildContext context,
    AppLocalizations l10n,
    ThreadControlsPreferences next,
  ) async {
    final saved = await ref
        .read(threadControlsPreferencesControllerProvider.notifier)
        .savePreferences(next);
    if (!saved && context.mounted) {
      showTransientSnackBar(context, l10n.threadControlsSaveFailed);
    }
  }

  Future<void> _pushContentFilter() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContentFilterPage(
          managedBlacklistRouteBuilder: _managedBlacklistRoute(ref),
        ),
      ),
    );
  }

  Route<void> Function() _managedBlacklistRoute(WidgetRef ref) {
    return () {
      final owner = ref.read(verifiedSessionOwnerProvider);
      return ref.read(forumWebViewRouteFactoryProvider)(
        ForumWebViewLaunchConfig(
          initialUri: Uri.parse(AppConfig.siteBaseUrl).replace(
            path: '/home.php',
            queryParameters: <String, String>{
              'mod': 'space',
              'do': 'friend',
              'view': 'blacklist',
            },
          ),
          popOnRootBack: true,
          purpose: ForumWebViewHostPurpose.form,
          navigationPolicy: ForumWebViewNavigationPolicy.keepWebView,
          expectedAccountId: owner?.uid,
        ),
      );
    };
  }
}
