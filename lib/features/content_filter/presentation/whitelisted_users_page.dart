import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/application/whitelisted_users_controller.dart';
import 'package:y300/features/content_filter/domain/models/whitelisted_user.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 可信用户白名单管理页：按 UID 添加或移除豁免关键词屏蔽的用户。
class WhitelistedUsersPage extends ConsumerStatefulWidget {
  const WhitelistedUsersPage({super.key});

  @override
  ConsumerState<WhitelistedUsersPage> createState() =>
      _WhitelistedUsersPageState();
}

class _WhitelistedUsersPageState extends ConsumerState<WhitelistedUsersPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncUsers = ref.watch(whitelistedUsersControllerProvider);

    return Scaffold(
      key: const Key('whitelisted-users-page'),
      appBar: AppPageAppBar(
        title: l10n.contentFilterWhitelistedUsersSection,
        actions: [
          IconButton(
            key: const Key('content-filter-add-whitelist-user-button'),
            tooltip: l10n.contentFilterWhitelistedUserAdd,
            onPressed: () => unawaited(_openAddSheet()),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: asyncUsers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.contentFilterLoadFailed,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('content-filter-whitelist-retry-button'),
                        onPressed: () =>
                            ref.invalidate(whitelistedUsersControllerProvider),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
              data: (users) => ListView(
                key: const Key('content-filter-whitelisted-users-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  AppGroupedSection(
                    title: l10n.contentFilterWhitelistedUsersHint,
                    children: [
                      if (users.isEmpty)
                        Padding(
                          key: const Key('content-filter-whitelist-user-empty'),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                          child: Text(
                            l10n.contentFilterWhitelistedUsersEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (final user in users)
                          AppGroupedRow(
                            key: Key(
                              'content-filter-whitelist-user-${user.uid}',
                            ),
                            leading: const Icon(Icons.verified_user_outlined),
                            title: user.username.isNotEmpty
                                ? user.username
                                : 'UID ${user.uid}',
                            subtitle: user.username.isNotEmpty
                                ? 'UID ${user.uid}'
                                : null,
                            trailing: TextButton(
                              key: Key(
                                'content-filter-delete-whitelist-user-${user.uid}',
                              ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(56, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () => unawaited(_removeUser(user)),
                              child: Text(l10n.contentFilterKeywordDelete),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddSheet() async {
    await showAdaptivePanel<void>(
      context: context,
      builder: (_) => const _AddWhitelistedUserSheet(),
    );
  }

  Future<void> _removeUser(WhitelistedUser entry) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final controller = ref.read(whitelistedUsersControllerProvider.notifier);
    final removed = await controller.remove(entry.uid);
    if (!mounted) return;
    if (!removed) {
      showTransientSnackBarWithMessenger(
        messenger,
        feedbackStyle,
        l10n.contentFilterSaveFailed,
      );
      return;
    }
    showTransientSnackBarWithMessenger(
      messenger,
      feedbackStyle,
      l10n.contentFilterKeywordDeleted(
        entry.username.isNotEmpty ? entry.username : 'UID ${entry.uid}',
      ),
      action: SnackBarAction(
        label: l10n.contentFilterUndo,
        onPressed: () => unawaited(controller.undoRemove(entry)),
      ),
    );
  }
}

class _AddWhitelistedUserSheet extends ConsumerStatefulWidget {
  const _AddWhitelistedUserSheet();

  @override
  ConsumerState<_AddWhitelistedUserSheet> createState() =>
      _AddWhitelistedUserSheetState();
}

class _AddWhitelistedUserSheetState
    extends ConsumerState<_AddWhitelistedUserSheet> {
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _errorText;
  bool _saving = false;

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final uid = _uidController.text.trim();
    if (normalizeWhitelistedUid(uid) == null) {
      setState(() => _errorText = l10n.contentFilterWhitelistedUserUidInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final result = await ref
        .read(whitelistedUsersControllerProvider.notifier)
        .add(uid: uid, username: _nameController.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result.status) {
      case WhitelistedUserMutationStatus.created:
        Navigator.of(context).pop();
      case WhitelistedUserMutationStatus.alreadyExists:
        setState(() => _errorText = l10n.contentFilterWhitelistedUserDuplicate);
      case WhitelistedUserMutationStatus.invalidUid:
        setState(
          () => _errorText = l10n.contentFilterWhitelistedUserUidInvalid,
        );
      case WhitelistedUserMutationStatus.failed:
        setState(() => _errorText = l10n.contentFilterSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + viewInsetsBottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.contentFilterWhitelistedUserAdd,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            AppTextInput(
              key: const Key('content-filter-whitelist-uid-input'),
              controller: _uidController,
              label: l10n.contentFilterWhitelistedUserUidLabel,
              hintText: l10n.contentFilterWhitelistedUserUidHint,
              errorText: _errorText,
              keyboardType: TextInputType.number,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: 12),
            AppTextInput(
              key: const Key('content-filter-whitelist-name-input'),
              controller: _nameController,
              label: l10n.contentFilterWhitelistedUserNameLabel,
              hintText: l10n.contentFilterWhitelistedUserNameHint,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('content-filter-whitelist-cancel'),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('content-filter-whitelist-save'),
                    onPressed: _saving ? null : () => unawaited(_submit()),
                    child: Text(l10n.commonSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
