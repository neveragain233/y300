import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 已屏蔽帖子子页：只展示本地屏蔽的帖子并提供解除入口。
///
/// 从内容屏蔽入口进入后才加载列表；空态、失败重试和解除后的提示沿用原
/// 控制器，页面自身不触发网页版黑名单同步。
class BlockedThreadsPage extends ConsumerStatefulWidget {
  const BlockedThreadsPage({super.key});

  @override
  ConsumerState<BlockedThreadsPage> createState() => _BlockedThreadsPageState();
}

class _BlockedThreadsPageState extends ConsumerState<BlockedThreadsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncRules = ref.watch(blockedThreadsControllerProvider);
    return Scaffold(
      key: const Key('blocked-threads-page'),
      appBar: AppPageAppBar(title: l10n.contentFilterThreadsSection),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const Key('content-filter-blocked-threads-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: asyncRules.when(
                loading: () => const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
                error: (_, _) => [
                  _BlockedThreadsLoadFailure(
                    message: l10n.contentFilterLoadFailed,
                    onRetry: () => ref
                        .read(blockedThreadsControllerProvider.notifier)
                        .reload(),
                  ),
                ],
                data: (rules) => _buildThreadSection(l10n, rules),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildThreadSection(
    AppLocalizations l10n,
    List<BlockedThread> rules,
  ) {
    final theme = Theme.of(context);
    return [
      AppGroupedSection(
        title: l10n.contentFilterCount(rules.length),
        children: [
          if (rules.isEmpty)
            Padding(
              key: const Key('content-filter-blocked-thread-empty'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Text(
                l10n.contentFilterThreadsEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
                  // 解除是行尾的危险操作：扩大命中宽度，并保留至少48高度，
                  // 避免单手在屏幕右缘点到文字边缘时落空。
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _unblockThread(rule),
                  child: Text(l10n.contentFilterUnblock),
                ),
              ),
        ],
      ),
    ];
  }

  Future<void> _unblockThread(BlockedThread rule) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final restored = await ref
        .read(blockedThreadsControllerProvider.notifier)
        .unblock(rule.tid);
    if (!mounted) {
      return;
    }
    showTransientSnackBarWithMessenger(
      messenger,
      feedbackStyle,
      restored
          ? l10n.contentFilterUnblocked(rule.subject)
          : l10n.contentFilterSaveFailed,
    );
  }
}

class _BlockedThreadsLoadFailure extends StatelessWidget {
  const _BlockedThreadsLoadFailure({
    required this.message,
    required this.onRetry,
  });

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
