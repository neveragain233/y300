import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 本地关键词屏蔽管理页：列表标题隐藏开关与规则增删改。
class BlockedKeywordsPage extends ConsumerStatefulWidget {
  const BlockedKeywordsPage({super.key});

  @override
  ConsumerState<BlockedKeywordsPage> createState() =>
      _BlockedKeywordsPageState();
}

class _BlockedKeywordsPageState extends ConsumerState<BlockedKeywordsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncRules = ref.watch(blockedKeywordsControllerProvider);
    final hideInLists = ref.watch(hideKeywordThreadsInListsProvider);
    return Scaffold(
      key: const Key('blocked-keywords-page'),
      appBar: AppPageAppBar(
        title: l10n.contentFilterKeywordsSection,
        actions: [
          IconButton(
            key: const Key('content-filter-add-keyword-button'),
            tooltip: l10n.contentFilterKeywordAdd,
            onPressed: () => unawaited(_openKeywordEditor()),
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
            child: ListView(
              key: const Key('content-filter-blocked-keywords-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppGroupedSection(
                  children: [
                    AppSwitchRow(
                      key: const Key(
                        'content-filter-hide-keyword-threads-switch',
                      ),
                      leading: const Icon(Icons.visibility_off_outlined),
                      title: l10n.contentFilterHideKeywordThreadsInLists,
                      subtitle:
                          l10n.contentFilterHideKeywordThreadsInListsDetail,
                      value: hideInLists,
                      onChanged: (value) =>
                          unawaited(_setHideMatchingThreads(value)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...asyncRules.when(
                  loading: () => const [
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                  error: (_, _) => [
                    _BlockedKeywordsLoadFailure(
                      message: l10n.contentFilterLoadFailed,
                      onRetry: () => ref
                          .read(blockedKeywordsControllerProvider.notifier)
                          .reload(),
                    ),
                  ],
                  data: (rules) => _buildKeywordSection(l10n, rules),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildKeywordSection(
    AppLocalizations l10n,
    List<BlockedKeyword> rules,
  ) {
    final theme = Theme.of(context);
    return [
      AppGroupedSection(
        title: l10n.contentFilterKeywordsCount(rules.length),
        children: [
          if (rules.isEmpty)
            Padding(
              key: const Key('content-filter-blocked-keyword-empty'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Text(
                l10n.contentFilterKeywordsEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final rule in rules)
              AppGroupedRow(
                key: Key('content-filter-keyword-${rule.id}'),
                leading: Icon(
                  rule.scope == BlockedKeywordScope.includeBody
                      ? Icons.article_outlined
                      : Icons.chat_bubble_outline,
                ),
                title: rule.keyword,
                subtitle: rule.scope == BlockedKeywordScope.includeBody
                    ? l10n.contentFilterKeywordScopeIncludeBody
                    : l10n.contentFilterKeywordScopeRepliesOnly,
                onTap: () => unawaited(_openKeywordEditor(existing: rule)),
                trailing: TextButton(
                  key: Key('content-filter-delete-keyword-${rule.id}'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => unawaited(_deleteKeyword(rule)),
                  child: Text(l10n.contentFilterKeywordDelete),
                ),
              ),
        ],
      ),
    ];
  }

  Future<void> _setHideMatchingThreads(bool value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final saved = await ref
        .read(keywordFilterPreferencesControllerProvider.notifier)
        .setHideMatchingThreadsInLists(value);
    if (!mounted || saved) {
      return;
    }
    showTransientSnackBarWithMessenger(
      messenger,
      feedbackStyle,
      l10n.contentFilterSaveFailed,
    );
  }

  Future<void> _deleteKeyword(BlockedKeyword rule) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final controller = ref.read(blockedKeywordsControllerProvider.notifier);
    final removed = await controller.remove(rule.id);
    if (!mounted) {
      return;
    }
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
      l10n.contentFilterKeywordDeleted(rule.keyword),
      action: SnackBarAction(
        label: l10n.contentFilterUndo,
        onPressed: () {
          unawaited(
            controller.undoRemove(rule).then((restored) {
              if (!restored) {
                showTransientSnackBarWithMessenger(
                  messenger,
                  feedbackStyle,
                  l10n.contentFilterSaveFailed,
                );
              }
            }),
          );
        },
      ),
    );
  }

  Future<void> _openKeywordEditor({BlockedKeyword? existing}) async {
    await showAdaptivePanel<void>(
      context: context,
      builder: (_) => _KeywordEditorSheet(existing: existing),
    );
  }
}

class _KeywordEditorSheet extends ConsumerStatefulWidget {
  const _KeywordEditorSheet({this.existing});

  final BlockedKeyword? existing;

  @override
  ConsumerState<_KeywordEditorSheet> createState() =>
      _KeywordEditorSheetState();
}

class _KeywordEditorSheetState extends ConsumerState<_KeywordEditorSheet> {
  late final TextEditingController _controller;
  late BlockedKeywordScope _scope;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.keyword ?? '');
    _scope = widget.existing?.scope ?? BlockedKeywordScope.repliesOnly;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final raw = _controller.text.trim();
    if (normalizeBlockedKeyword(raw).isEmpty) {
      setState(() => _errorText = l10n.contentFilterKeywordEmptyError);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final controller = ref.read(blockedKeywordsControllerProvider.notifier);
    final existing = widget.existing;
    final result = existing == null
        ? await controller.add(keyword: raw, scope: _scope)
        : await controller.updateRule(
            id: existing.id,
            keyword: raw,
            scope: _scope,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result.status) {
      case BlockedKeywordMutationStatus.created:
      case BlockedKeywordMutationStatus.updated:
        Navigator.of(context).pop();
      case BlockedKeywordMutationStatus.invalid:
        setState(() => _errorText = l10n.contentFilterKeywordEmptyError);
      case BlockedKeywordMutationStatus.alreadyExists:
        setState(() => _errorText = l10n.contentFilterKeywordDuplicateError);
      case BlockedKeywordMutationStatus.failed:
        setState(() => _errorText = l10n.contentFilterSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + viewInsetsBottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing
                  ? l10n.contentFilterKeywordEdit
                  : l10n.contentFilterKeywordAdd,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            AppTextInput(
              key: const Key('content-filter-keyword-input'),
              controller: _controller,
              label: l10n.contentFilterKeywordLabel,
              hintText: l10n.contentFilterKeywordHint,
              errorText: _errorText,
              autofocus: !isEditing,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.contentFilterKeywordScopeLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            AppGroupedSection(
              children: [
                _ScopeOptionRow(
                  optionKey: const Key('content-filter-scope-replies-only'),
                  title: l10n.contentFilterKeywordScopeRepliesOnly,
                  subtitle: l10n.contentFilterKeywordScopeRepliesOnlyDetail,
                  selected: _scope == BlockedKeywordScope.repliesOnly,
                  onTap: () =>
                      setState(() => _scope = BlockedKeywordScope.repliesOnly),
                ),
                _ScopeOptionRow(
                  optionKey: const Key('content-filter-scope-include-body'),
                  title: l10n.contentFilterKeywordScopeIncludeBody,
                  subtitle: l10n.contentFilterKeywordScopeIncludeBodyDetail,
                  selected: _scope == BlockedKeywordScope.includeBody,
                  onTap: () =>
                      setState(() => _scope = BlockedKeywordScope.includeBody),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('content-filter-keyword-cancel'),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('content-filter-keyword-save'),
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

class _ScopeOptionRow extends StatelessWidget {
  const _ScopeOptionRow({
    required this.optionKey,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final Key optionKey;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppGroupedRow(
      key: optionKey,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class _BlockedKeywordsLoadFailure extends StatelessWidget {
  const _BlockedKeywordsLoadFailure({
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
              key: const Key('content-filter-keywords-retry-button'),
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
