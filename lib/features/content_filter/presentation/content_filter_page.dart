import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/presentation/blocked_keywords_page.dart';
import 'package:y300/features/content_filter/presentation/blocked_threads_page.dart';
import 'package:y300/features/content_filter/presentation/web_blacklist_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';

/// 内容屏蔽入口页：只列出两个子菜单，不在进入时拉取或展开具体名单。
///
/// 本地屏蔽帖子与网页版黑名单各自在子页面加载、刷新和保存，进入这里不会
/// 触发黑名单同步，也不会把长列表直接铺在设置入口下。
class ContentFilterPage extends ConsumerWidget {
  const ContentFilterPage({super.key, this.managedBlacklistRouteBuilder});

  /// Host-owned managed web route for editing the list on the website.
  final Route<void> Function()? managedBlacklistRouteBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blockedThreads = ref.watch(blockedThreadsControllerProvider);
    final blockedKeywords = ref.watch(blockedKeywordsControllerProvider);
    final account = ref.watch(currentBlacklistAccountProvider);
    return Scaffold(
      key: const Key('content-filter-page'),
      appBar: AppPageAppBar(title: l10n.contentFilterTitle),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const Key('content-filter-menu'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppGroupedSection(
                  children: [
                    AppGroupedRow(
                      key: const Key('content-filter-blocked-threads-entry'),
                      leading: const Icon(Icons.visibility_off_outlined),
                      title: l10n.contentFilterThreadsSection,
                      subtitle: blockedThreads.when(
                        data: (rules) => l10n.contentFilterCount(rules.length),
                        loading: () => l10n.commonLoading,
                        error: (_, _) => l10n.contentFilterLoadFailed,
                      ),
                      showChevron: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BlockedThreadsPage(),
                        ),
                      ),
                    ),
                    AppGroupedRow(
                      key: const Key('content-filter-blocked-keywords-entry'),
                      leading: const Icon(Icons.filter_alt_off_outlined),
                      title: l10n.contentFilterKeywordsSection,
                      subtitle: blockedKeywords.when(
                        data: (rules) =>
                            l10n.contentFilterKeywordsCount(rules.length),
                        loading: () => l10n.commonLoading,
                        error: (_, _) => l10n.contentFilterLoadFailed,
                      ),
                      showChevron: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BlockedKeywordsPage(),
                        ),
                      ),
                    ),
                    AppGroupedRow(
                      key: const Key('content-filter-web-blacklist-entry'),
                      leading: const Icon(Icons.person_off_outlined),
                      title: l10n.contentFilterWebBlacklistSection,
                      subtitle: account == null
                          ? l10n.contentFilterWebBlacklistNotSynced
                          : l10n.contentFilterWebBlacklistCount(
                              account.members.length,
                            ),
                      showChevron: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WebBlacklistPage(
                            managedBlacklistRouteBuilder:
                                managedBlacklistRouteBuilder,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
