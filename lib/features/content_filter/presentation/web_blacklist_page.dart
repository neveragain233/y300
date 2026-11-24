import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_pending_mutation.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
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
  final Set<String> _busyUserIds = <String>{};

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

  Future<void> _removeMember(BlacklistMember member) async {
    if (_busyUserIds.contains(member.userId)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.contentFilterWebBlacklistRemoveTitle,
      message: l10n.contentFilterWebBlacklistRemoveBody(member.username),
      confirmLabel: l10n.contentFilterWebBlacklistRemove,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      confirmKey: const Key('content-filter-blacklist-remove-confirm'),
      cancelKey: const Key('content-filter-blacklist-remove-cancel'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    setState(() => _busyUserIds.add(member.userId));
    final outcome = await ref
        .read(blacklistSyncControllerProvider.notifier)
        .removeUser(userId: member.userId, username: member.username);
    if (!mounted) {
      return;
    }
    setState(() => _busyUserIds.remove(member.userId));
    final message = switch (outcome) {
      BlacklistRemoveOutcome.applied =>
        l10n.contentFilterWebBlacklistRemoveApplied(member.username),
      BlacklistRemoveOutcome.queued =>
        l10n.contentFilterWebBlacklistRemoveQueued(member.username),
      BlacklistRemoveOutcome.notListed =>
        l10n.contentFilterWebBlacklistRemoveNotListed(member.username),
      BlacklistRemoveOutcome.notLoggedIn =>
        l10n.contentFilterWebBlacklistLoginRequired,
      BlacklistRemoveOutcome.unsupported => l10n.blacklistBlockUnsupported,
      BlacklistRemoveOutcome.invalidTarget || BlacklistRemoveOutcome.rejected =>
        l10n.contentFilterWebBlacklistRemoveFailed,
      BlacklistRemoveOutcome.outcomeUnknown =>
        l10n.contentFilterWebBlacklistRemoveUnknown,
      BlacklistRemoveOutcome.stale || BlacklistRemoveOutcome.cancelled => null,
    };
    if (message != null) {
      showTransientSnackBarWithMessenger(messenger, feedbackStyle, message);
    }
  }

  Future<void> _retryPending(BlacklistPendingMutation mutation) async {
    if (_busyUserIds.contains(mutation.userId)) {
      return;
    }
    setState(() => _busyUserIds.add(mutation.userId));
    await ref
        .read(blacklistSyncControllerProvider.notifier)
        .retryPendingMutation(mutation);
    if (mounted) {
      setState(() => _busyUserIds.remove(mutation.userId));
    }
  }

  Future<void> _cancelPending(BlacklistPendingMutation mutation) async {
    if (_busyUserIds.contains(mutation.userId)) {
      return;
    }
    setState(() => _busyUserIds.add(mutation.userId));
    await ref
        .read(blacklistSyncControllerProvider.notifier)
        .cancelPendingMutation(mutation.userId);
    if (mounted) {
      setState(() => _busyUserIds.remove(mutation.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(verifiedSessionOwnerProvider);
    final sessionUid = ref.watch(blacklistSessionUidProvider);
    final account = ref.watch(currentBlacklistAccountProvider);
    final pendingMutations = ref.watch(
      currentBlacklistPendingMutationsProvider,
    );
    final pendingByUserId = <String, BlacklistPendingMutation>{
      for (final item in pendingMutations) item.userId: item,
    };
    final visibleMembers = <BlacklistMember>[
      for (final member in account?.members ?? const <BlacklistMember>[])
        if (pendingByUserId[member.userId]?.action !=
            BlacklistPendingAction.remove)
          member,
    ];
    final removeSupported = ref.watch(blacklistRemoveSupportedProvider);
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
                            '${l10n.contentFilterWebBlacklistCount(visibleMembers.length)}',
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
                    for (final member in visibleMembers)
                      AppGroupedRow(
                        key: Key(
                          'content-filter-blacklist-member-${member.userId}',
                        ),
                        leading: const Icon(Icons.person_off_outlined),
                        title: member.username,
                        subtitle: l10n.contentFilterWebBlacklistMemberUid(
                          member.userId,
                        ),
                        trailing: !removeSupported || sessionUid == null
                            ? null
                            : _busyUserIds.contains(member.userId)
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                key: Key(
                                  'content-filter-blacklist-remove-${member.userId}',
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(72, 48),
                                ),
                                onPressed: () => _removeMember(member),
                                child: Text(
                                  l10n.contentFilterWebBlacklistRemove,
                                ),
                              ),
                      ),
                    for (final item in pendingMutations)
                      _PendingMutationRow(
                        mutation: item,
                        busy: _busyUserIds.contains(item.userId),
                        canRetry: owner != null,
                        l10n: l10n,
                        onRetry: () => unawaited(_retryPending(item)),
                        onCancel: () => unawaited(_cancelPending(item)),
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

class _PendingMutationRow extends StatelessWidget {
  const _PendingMutationRow({
    required this.mutation,
    required this.busy,
    required this.canRetry,
    required this.l10n,
    required this.onRetry,
    required this.onCancel,
  });

  final BlacklistPendingMutation mutation;
  final bool busy;
  final bool canRetry;
  final AppLocalizations l10n;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch ((mutation.action, mutation.status)) {
      (BlacklistPendingAction.add, BlacklistPendingStatus.queued) =>
        l10n.contentFilterWebBlacklistPendingAddQueued(mutation.userId),
      (BlacklistPendingAction.add, BlacklistPendingStatus.needsVerification) =>
        l10n.contentFilterWebBlacklistPendingAddVerify(mutation.userId),
      (BlacklistPendingAction.remove, BlacklistPendingStatus.queued) =>
        l10n.contentFilterWebBlacklistPendingRemoveQueued(mutation.userId),
      (
        BlacklistPendingAction.remove,
        BlacklistPendingStatus.needsVerification,
      ) =>
        l10n.contentFilterWebBlacklistPendingRemoveVerify(mutation.userId),
    };
    return AppGroupedRow(
      key: Key('content-filter-blacklist-pending-${mutation.userId}'),
      leading: Icon(
        mutation.action == BlacklistPendingAction.remove
            ? Icons.person_remove_outlined
            : Icons.schedule_outlined,
      ),
      title: mutation.username,
      subtitle: subtitle,
      trailing: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canRetry)
                  TextButton(
                    key: Key(
                      'content-filter-blacklist-retry-${mutation.userId}',
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(56, 48),
                    ),
                    onPressed: onRetry,
                    child: Text(l10n.contentFilterWebBlacklistRetry),
                  ),
                TextButton(
                  key: Key(
                    'content-filter-blacklist-cancel-pending-${mutation.userId}',
                  ),
                  style: TextButton.styleFrom(minimumSize: const Size(56, 48)),
                  onPressed: onCancel,
                  child: Text(l10n.contentFilterWebBlacklistUndoPending),
                ),
              ],
            ),
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
