import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 网页版黑名单子页：同步、成员列表、网页维护入口与屏蔽显示开关。
///
/// 只有进入本页才触发黑名单同步；返回内容屏蔽入口不会重新拉取名单。
class WebBlacklistPage extends ConsumerStatefulWidget {
  const WebBlacklistPage({super.key, this.managedBlacklistRouteBuilder});

  final Route<void> Function()? managedBlacklistRouteBuilder;

  @override
  ConsumerState<WebBlacklistPage> createState() => _WebBlacklistPageState();
}

class _WebBlacklistPageState extends ConsumerState<WebBlacklistPage> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(blacklistSyncControllerProvider.notifier).syncIfStale(),
        );
      }
    });
  }

  Future<void> _refreshBlacklist() async {
    if (_syncing) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    setState(() => _syncing = true);
    final outcome = await ref
        .read(blacklistSyncControllerProvider.notifier)
        .refresh(force: true);
    if (!mounted) {
      return;
    }
    setState(() => _syncing = false);
    if (outcome == BlacklistSyncOutcome.success) {
      return;
    }
    showTransientSnackBarWithMessenger(
      messenger,
      feedbackStyle,
      outcome == BlacklistSyncOutcome.noOwner
          ? l10n.contentFilterWebBlacklistLoginRequired
          : l10n.contentFilterWebBlacklistSyncFailed,
    );
  }

  Future<void> _openManagedBlacklist() async {
    final routeBuilder = widget.managedBlacklistRouteBuilder;
    if (routeBuilder == null) {
      return;
    }
    await Navigator.of(context).push(routeBuilder());
    if (!mounted) {
      return;
    }
    // Returning from the managed page is the point where website edits become
    // readable; merge them through the same single-flight refresh.
    await _refreshBlacklist();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(verifiedSessionOwnerProvider);
    final account = ref.watch(currentBlacklistAccountProvider);
    final blacklistLoading = ref
        .watch(blacklistSyncControllerProvider)
        .isLoading;
    final hideBlacklistedThreads = ref.watch(hideBlacklistedThreadsProvider);
    final syncing = _syncing || (blacklistLoading && account == null);
    return Scaffold(
      key: const Key('web-blacklist-page'),
      appBar: AppPageAppBar(title: l10n.contentFilterWebBlacklistSection),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const Key('content-filter-web-blacklist-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppGroupedSection(
                  title: account == null
                      ? l10n.contentFilterWebBlacklistSection
                      : '${l10n.contentFilterWebBlacklistSection} · '
                            '${l10n.contentFilterWebBlacklistCount(account.members.length)}',
                  children: [
                    AppGroupedRow(
                      key: const Key('content-filter-blacklist-refresh'),
                      leading: const Icon(Icons.sync),
                      title: l10n.contentFilterWebBlacklistRefresh,
                      trailing: syncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      enabled: owner != null && !syncing,
                      onTap: _refreshBlacklist,
                    ),
                    for (final member in account?.members ?? const [])
                      AppGroupedRow(
                        key: Key(
                          'content-filter-blacklist-member-${member.userId}',
                        ),
                        leading: const Icon(Icons.person_off_outlined),
                        title: member.username,
                        subtitle: l10n.contentFilterWebBlacklistMemberUid(
                          member.userId,
                        ),
                      ),
                    if (owner != null &&
                        widget.managedBlacklistRouteBuilder != null)
                      AppGroupedRow(
                        key: const Key('content-filter-open-blacklist-web'),
                        leading: const Icon(Icons.open_in_new, size: 20),
                        title: l10n.contentFilterWebBlacklistOpen,
                        showChevron: true,
                        enabled: !_syncing,
                        onTap: _openManagedBlacklist,
                      ),
                  ],
                ),
                _BlacklistStatus(
                  owner: owner,
                  account: account,
                  loading: blacklistLoading,
                  l10n: l10n,
                ),
                if (account != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(
                      l10n.contentFilterWebBlacklistNote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                AppGroupedSection(
                  children: [
                    AppSwitchRow(
                      key: const Key('content-filter-hide-blacklisted-threads'),
                      leading: const Icon(Icons.filter_alt_outlined),
                      title: l10n.contentFilterHideBlacklistedThreads,
                      subtitle: l10n.contentFilterHideBlacklistedThreadsDetail,
                      value: hideBlacklistedThreads,
                      onChanged: (value) =>
                          unawaited(_setHideBlacklistedThreads(value)),
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

  Future<void> _setHideBlacklistedThreads(bool value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final saved = await ref
        .read(blacklistDisplayPreferencesControllerProvider.notifier)
        .setHideThreadsStartedByBlacklistedUsers(value);
    if (!mounted || saved) {
      return;
    }
    showTransientSnackBarWithMessenger(
      messenger,
      feedbackStyle,
      l10n.contentFilterSaveFailed,
    );
  }
}

class _BlacklistStatus extends StatelessWidget {
  const _BlacklistStatus({
    required this.owner,
    required this.account,
    required this.loading,
    required this.l10n,
  });

  final VerifiedSessionOwner? owner;
  final BlacklistAccountSnapshot? account;
  final bool loading;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (owner == null) {
      message = l10n.contentFilterWebBlacklistLoginRequired;
    } else if (account == null) {
      message = loading
          ? l10n.contentFilterWebBlacklistRefreshing
          : l10n.contentFilterWebBlacklistNotSynced;
    } else if (account!.members.isEmpty) {
      message = l10n.contentFilterWebBlacklistEmpty;
    } else {
      final time = DateFormat.yMd(l10n.localeName)
          .add_Hm()
          .format(account!.lastSuccessAt.toLocal());
      message = l10n.contentFilterWebBlacklistLastSync(time);
    }
    return Padding(
      key: const Key('content-filter-blacklist-status'),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
