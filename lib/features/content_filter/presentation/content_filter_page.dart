import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/storage/app_data_backup_providers.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/application/whitelisted_users_controller.dart';
import 'package:y300/features/content_filter/data/backup/content_filter_backup_sections.dart';
import 'package:y300/features/content_filter/presentation/blocked_keywords_page.dart';
import 'package:y300/features/content_filter/presentation/blocked_threads_page.dart';
import 'package:y300/features/content_filter/presentation/web_blacklist_page.dart';
import 'package:y300/features/content_filter/presentation/whitelisted_users_page.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 内容屏蔽入口页：列出屏蔽主题、关键词规则、可信用户白名单、网页黑名单与规则备份恢复。
class ContentFilterPage extends ConsumerStatefulWidget {
  const ContentFilterPage({super.key, this.managedBlacklistRouteBuilder});

  /// Host-owned managed web route for editing the list on the website.
  final Route<void> Function()? managedBlacklistRouteBuilder;

  @override
  ConsumerState<ContentFilterPage> createState() => _ContentFilterPageState();
}

class _ContentFilterPageState extends ConsumerState<ContentFilterPage> {
  bool _backupBusy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blockedThreads = ref.watch(blockedThreadsControllerProvider);
    final blockedKeywords = ref.watch(blockedKeywordsControllerProvider);
    final whitelistedUsers = ref.watch(whitelistedUsersControllerProvider);
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
                      key: const Key('content-filter-whitelisted-users-entry'),
                      leading: const Icon(Icons.verified_user_outlined),
                      title: l10n.contentFilterWhitelistedUsersSection,
                      subtitle: whitelistedUsers.when(
                        data: (users) => l10n
                            .contentFilterWhitelistedUsersCount(users.length),
                        loading: () => l10n.commonLoading,
                        error: (_, _) => l10n.contentFilterLoadFailed,
                      ),
                      showChevron: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WhitelistedUsersPage(),
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
                                widget.managedBlacklistRouteBuilder,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppGroupedSection(
                  title: l10n.contentFilterBackupSectionTitle,
                  children: [
                    AppGroupedRow(
                      key: const Key('content-filter-backup-export-entry'),
                      leading: const Icon(Icons.upload_file_outlined),
                      title: l10n.contentFilterBackupExport,
                      subtitle: l10n.contentFilterBackupExportDetail,
                      onTap: _backupBusy ? null : () => unawaited(_export()),
                    ),
                    AppGroupedRow(
                      key: const Key('content-filter-backup-import-entry'),
                      leading: const Icon(Icons.download_outlined),
                      title: l10n.contentFilterBackupImport,
                      subtitle: l10n.contentFilterBackupImportDetail,
                      onTap: _backupBusy ? null : () => unawaited(_import()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppGroupedSection(
                  children: [
                    AppGroupedRow(
                      key: const Key('content-filter-builtin-exemption-entry'),
                      leading: const Icon(Icons.shield_outlined),
                      title: l10n.contentFilterBuiltInExemptionTitle,
                      subtitle: l10n.contentFilterBuiltInExemptionDetail,
                      trailing: Text(
                        l10n.contentFilterBuiltInExemptionLocked,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    setState(() => _backupBusy = true);
    try {
      final service = ref.read(appDataBackupServiceProvider);
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final uri = await service.exportToFile(
        fileName: 'y300-content-filter-backup-$stamp.json',
        sectionIds: ContentFilterBackupSectionIds.all,
        dialogTitle: l10n.contentFilterBackupExport,
      );
      if (!mounted || uri == null) {
        return;
      }
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterBackupExportSuccess,
      );
    } on Object {
      if (!mounted) return;
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterBackupExportFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    setState(() => _backupBusy = true);
    try {
      final service = ref.read(appDataBackupServiceProvider);
      final raw = await service.pickJsonFromFile();
      if (!mounted || raw == null) {
        return;
      }
      final preview = service.inspectJson(
        raw,
        allowedSectionIds: ContentFilterBackupSectionIds.all,
      );
      if (preview.totalItems == 0) {
        showTransientSnackBarWithMessenger(
          messenger,
          feedbackStyle,
          l10n.contentFilterBackupEmpty,
        );
        return;
      }
      final mode = await _confirmImportMode(l10n, preview);
      if (!mounted || mode == null) {
        return;
      }
      final result = await service.importJson(
        raw,
        mode: mode,
        allowedSectionIds: ContentFilterBackupSectionIds.all,
      );
      if (!mounted) return;
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterBackupImportSuccess(
          result.totalImported,
          result.totalSkipped,
        ),
      );
    } on AppDataBackupFormatException catch (error) {
      if (!mounted) return;
      final message = switch (error.reason) {
        AppDataBackupFormatError.unsupportedVersion =>
          l10n.contentFilterBackupUnsupportedVersion,
        AppDataBackupFormatError.fileTooLarge =>
          l10n.contentFilterBackupFileTooLarge,
        AppDataBackupFormatError.invalidJson ||
        AppDataBackupFormatError.missingSections =>
          l10n.contentFilterBackupInvalidFile,
      };
      showTransientSnackBarWithMessenger(messenger, feedbackStyle, message);
    } on Object {
      if (!mounted) return;
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterBackupImportFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _backupBusy = false);
      }
    }
  }

  Future<AppDataBackupImportMode?> _confirmImportMode(
    AppLocalizations l10n,
    AppDataBackupPreview preview,
  ) {
    int countFor(String sectionId) {
      for (final section in preview.sections) {
        if (section.sectionId == sectionId) {
          return section.itemCount;
        }
      }
      return 0;
    }

    final keywordsCount = countFor(
      ContentFilterBackupSectionIds.blockedKeywords,
    );
    final threadsCount = countFor(ContentFilterBackupSectionIds.blockedThreads);
    final usersCount = countFor(ContentFilterBackupSectionIds.whitelistedUsers);

    return showDialog<AppDataBackupImportMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('content-filter-backup-preview-dialog'),
        title: Text(l10n.contentFilterBackupPreviewTitle),
        content: Text(
          l10n.contentFilterBackupPreviewSummary(
            preview.totalItems,
            keywordsCount,
            threadsCount,
            usersCount,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('content-filter-backup-import-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          OutlinedButton(
            key: const Key('content-filter-backup-import-replace'),
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(AppDataBackupImportMode.replace),
            child: Text(l10n.contentFilterBackupImportReplace),
          ),
          FilledButton(
            key: const Key('content-filter-backup-import-merge'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(AppDataBackupImportMode.merge),
            child: Text(l10n.contentFilterBackupImportMerge),
          ),
        ],
      ),
    );
  }
}
