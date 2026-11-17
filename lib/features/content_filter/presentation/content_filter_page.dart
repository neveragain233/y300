import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

/// Management page for local blocked threads and the synced web blacklist.
class ContentFilterPage extends ConsumerStatefulWidget {
  const ContentFilterPage({super.key, this.managedBlacklistRouteBuilder});

  /// Host-owned managed web route for editing the list on the website.
  final Route<void> Function()? managedBlacklistRouteBuilder;

  @override
  ConsumerState<ContentFilterPage> createState() => _ContentFilterPageState();
}

class _ContentFilterPageState extends ConsumerState<ContentFilterPage> {
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
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            outcome == BlacklistSyncOutcome.noOwner
                ? l10n.contentFilterWebBlacklistLoginRequired
                : l10n.contentFilterWebBlacklistSyncFailed,
          ),
        ),
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
    final asyncRules = ref.watch(blockedThreadsControllerProvider);
    final syncing = _syncing || (blacklistLoading && account == null);
    return Scaffold(
      appBar: AppPageAppBar(title: l10n.contentFilterTitle),
      body: ListView(
        key: const Key('content-filter-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          ..._buildThreadSection(asyncRules),
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
                  key: Key('content-filter-blacklist-member-${member.userId}'),
                  leading: const Icon(Icons.person_off_outlined),
                  title: member.username,
                  subtitle: l10n.contentFilterWebBlacklistMemberUid(
                    member.userId,
                  ),
                ),
              if (owner != null && widget.managedBlacklistRouteBuilder != null)
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
    );
  }

  Future<void> _setHideBlacklistedThreads(bool value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = await ref
        .read(blacklistDisplayPreferencesControllerProvider.notifier)
        .setHideThreadsStartedByBlacklistedUsers(value);
    if (!mounted || saved) {
      return;
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.contentFilterSaveFailed)));
  }

  List<Widget> _buildThreadSection(AsyncValue<List<BlockedThread>> asyncRules) {
    final l10n = AppLocalizations.of(context);
    return asyncRules.when(
      loading: () => const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
      error: (_, _) => [
        _LoadFailure(
          message: l10n.contentFilterLoadFailed,
          onRetry: () =>
              ref.read(blockedThreadsControllerProvider.notifier).reload(),
        ),
      ],
      data: (rules) => [
        AppGroupedSection(
          title:
              '${l10n.contentFilterThreadsSection} · '
              '${l10n.contentFilterCount(rules.length)}',
          children: [
            if (rules.isEmpty)
              Padding(
                key: const Key('content-filter-blocked-thread-empty'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Text(
                  l10n.contentFilterThreadsEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final rule in rules)
                AppGroupedRow(
                  key: Key('content-filter-blocked-thread-${rule.tid}'),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: rule.subject,
                  subtitle: l10n.searchResultTid(rule.tid),
                  trailing: TextButton(
                    key: Key('content-filter-unblock-${rule.tid}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => _unblockThread(rule),
                    child: Text(l10n.contentFilterUnblock),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Future<void> _unblockThread(BlockedThread rule) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final restored = await ref
        .read(blockedThreadsControllerProvider.notifier)
        .unblock(rule.tid);
    if (!mounted) {
      return;
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? l10n.contentFilterUnblocked(rule.subject)
                : l10n.contentFilterSaveFailed,
          ),
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

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('content-filter-retry-button'),
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
