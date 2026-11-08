import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/l10n/app_localizations.dart';

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
    final asyncRules = ref.watch(blockedThreadsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contentFilterTitle)),
      body: ListView(
        key: const Key('content-filter-list'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          ..._buildThreadSection(asyncRules),
          const Divider(height: 28),
          _BlacklistHeader(
            title: l10n.contentFilterWebBlacklistSection,
            countLabel: account == null
                ? null
                : l10n.contentFilterWebBlacklistCount(account.members.length),
            syncing: _syncing || (blacklistLoading && account == null),
            onRefresh: owner == null ? null : _refreshBlacklist,
          ),
          _BlacklistStatus(
            owner: owner,
            account: account,
            loading: blacklistLoading,
            l10n: l10n,
          ),
          if (owner != null && account != null && account.members.isNotEmpty)
            for (final member in account.members)
              ListTile(
                key: Key('content-filter-blacklist-member-${member.userId}'),
                dense: true,
                leading: const Icon(Icons.person_off_outlined),
                title: Text(member.username),
                subtitle: Text(
                  l10n.contentFilterWebBlacklistMemberUid(member.userId),
                ),
              ),
          if (owner != null && widget.managedBlacklistRouteBuilder != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                key: const Key('content-filter-open-blacklist-web'),
                onPressed: _syncing ? null : _openManagedBlacklist,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.contentFilterWebBlacklistOpen),
              ),
            ),
          ],
          if (account != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                l10n.contentFilterWebBlacklistNote,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
        ],
      ),
    );
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
        _SectionHeader(
          title: l10n.contentFilterThreadsSection,
          trailing: l10n.contentFilterCount(rules.length),
        ),
        if (rules.isEmpty)
          Padding(
            key: const Key('content-filter-blocked-thread-empty'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Text(
              l10n.contentFilterThreadsEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          )
        else
          for (final rule in rules)
            ListTile(
              key: Key('content-filter-blocked-thread-${rule.tid}'),
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(
                rule.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(l10n.searchResultTid(rule.tid)),
              trailing: TextButton(
                key: Key('content-filter-unblock-${rule.tid}'),
                onPressed: () => _unblockThread(rule),
                child: Text(l10n.contentFilterUnblock),
              ),
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

class _BlacklistHeader extends StatelessWidget {
  const _BlacklistHeader({
    required this.title,
    required this.countLabel,
    required this.syncing,
    required this.onRefresh,
  });

  final String title;
  final String? countLabel;
  final bool syncing;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (countLabel != null)
                  Text(
                    countLabel!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
              ],
            ),
          ),
          if (syncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              key: const Key('content-filter-blacklist-refresh'),
              tooltip: l10n.contentFilterWebBlacklistRefresh,
              onPressed: onRefresh,
              icon: const Icon(Icons.sync),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            trailing,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
