import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/presentation/widgets/keyword_rule_tester_card.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_capsule_tab_bar.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 本地关键词屏蔽管理页：彻底隐藏开关、屏蔽词/白名单双页签、规则开关与增删改。
class BlockedKeywordsPage extends ConsumerStatefulWidget {
  const BlockedKeywordsPage({super.key});

  @override
  ConsumerState<BlockedKeywordsPage> createState() =>
      _BlockedKeywordsPageState();
}

class _BlockedKeywordsPageState extends ConsumerState<BlockedKeywordsPage> {
  int _selectedTabIndex = 0;

  BlockedKeywordKind get _activeKind => _selectedTabIndex == 0
      ? BlockedKeywordKind.block
      : BlockedKeywordKind.allow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncRules = ref.watch(blockedKeywordsControllerProvider);
    final hideCompletely = ref.watch(
      hideBlockedKeywordThreadsCompletelyProvider,
    );
    return Scaffold(
      key: const Key('blocked-keywords-page'),
      appBar: AppPageAppBar(
        title: l10n.contentFilterKeywordsSection,
        actions: [
          IconButton(
            key: const Key('content-filter-add-keyword-button'),
            tooltip: l10n.contentFilterKeywordAdd,
            onPressed: () =>
                unawaited(_openKeywordEditor(defaultKind: _activeKind)),
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
                      title: l10n.contentFilterHideBlockedCompletely,
                      subtitle: l10n.contentFilterHideBlockedCompletelyDetail,
                      value: hideCompletely,
                      onChanged: (value) =>
                          unawaited(_setHideCompletely(value)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppCapsuleTabBar(
                  tabs: [
                    AppCapsuleTabItem(
                      id: 'block',
                      label: l10n.contentFilterTabBlock,
                    ),
                    AppCapsuleTabItem(
                      id: 'allow',
                      label: l10n.contentFilterTabAllow,
                    ),
                  ],
                  selectedIndex: _selectedTabIndex,
                  indicatorKey: const Key('content-filter-tab-indicator'),
                  tabKeyBuilder: (id) => Key('content-filter-tab-$id'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  onTap: (index) {
                    if (index != _selectedTabIndex) {
                      setState(() => _selectedTabIndex = index);
                    }
                  },
                ),
                const SizedBox(height: 12),
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
    List<BlockedKeyword> allRules,
  ) {
    final theme = Theme.of(context);
    final kind = _activeKind;
    final filtered = [
      for (final rule in allRules)
        if (rule.kind == kind) rule,
    ];
    return [
      if (kind == BlockedKeywordKind.allow)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            l10n.contentFilterWhitelistHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      AppGroupedSection(
        title: l10n.contentFilterKeywordsCount(filtered.length),
        children: [
          if (filtered.isEmpty)
            Padding(
              key: const Key('content-filter-blocked-keyword-empty'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Text(
                kind == BlockedKeywordKind.allow
                    ? l10n.contentFilterWhitelistEmpty
                    : l10n.contentFilterKeywordsEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final rule in filtered)
              AppGroupedRow(
                key: Key('content-filter-keyword-${rule.id}'),
                leading: Opacity(
                  opacity: rule.enabled ? 1.0 : 0.45,
                  child: Icon(_iconForRule(rule)),
                ),
                title: rule.keyword,
                subtitle: _subtitleForRule(l10n, rule),
                onTap: () => unawaited(_openKeywordEditor(existing: rule)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      key: Key('content-filter-toggle-keyword-${rule.id}'),
                      value: rule.enabled,
                      onChanged: (value) =>
                          unawaited(_toggleRuleEnabled(rule, value)),
                    ),
                    TextButton(
                      key: Key('content-filter-delete-keyword-${rule.id}'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(56, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => unawaited(_deleteKeyword(rule)),
                      child: Text(l10n.contentFilterKeywordDelete),
                    ),
                  ],
                ),
              ),
        ],
      ),
      const SizedBox(height: 16),
      KeywordRuleTesterCard(rules: allRules),
    ];
  }

  IconData _iconForRule(BlockedKeyword rule) {
    if (rule.isRegex) {
      return Icons.code_rounded;
    }
    if (rule.isWhitelist) {
      return Icons.verified_user_outlined;
    }
    return rule.scope == BlockedKeywordScope.includeBody
        ? Icons.article_outlined
        : Icons.chat_bubble_outline;
  }

  String _subtitleForRule(AppLocalizations l10n, BlockedKeyword rule) {
    final parts = <String>[
      rule.isRegex
          ? l10n.contentFilterRuleMatchRegex
          : l10n.contentFilterRuleMatchPlain,
      rule.isWhitelist
          ? l10n.contentFilterRuleKindAllow
          : (rule.scope == BlockedKeywordScope.includeBody
                ? l10n.contentFilterKeywordScopeIncludeBody
                : l10n.contentFilterKeywordScopeRepliesOnly),
      if (rule.effectiveWholeWord) l10n.contentFilterRuleWholeWordTag,
      if (rule.caseSensitive) l10n.contentFilterRuleCaseSensitiveTag,
      if (!rule.enabled) l10n.contentFilterRuleDisabled,
    ];
    return parts.join(' · ');
  }

  Future<void> _setHideCompletely(bool value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final saved = await ref
        .read(keywordFilterPreferencesControllerProvider.notifier)
        .setHideBlockedContentCompletely(value);
    if (!mounted || saved) {
      return;
    }
    showTransientSnackBarWithMessenger(
      messenger,
      feedbackStyle,
      l10n.contentFilterSaveFailed,
    );
  }

  Future<void> _toggleRuleEnabled(BlockedKeyword rule, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final feedbackStyle = TransientFeedbackStyle.capture(context);
    final saved = await ref
        .read(blockedKeywordsControllerProvider.notifier)
        .setEnabled(rule.id, enabled);
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

  Future<void> _openKeywordEditor({
    BlockedKeyword? existing,
    BlockedKeywordKind defaultKind = BlockedKeywordKind.block,
  }) async {
    await showAdaptivePanel<void>(
      context: context,
      builder: (_) =>
          _KeywordEditorSheet(existing: existing, defaultKind: defaultKind),
    );
  }
}

class _KeywordEditorSheet extends ConsumerStatefulWidget {
  const _KeywordEditorSheet({
    this.existing,
    this.defaultKind = BlockedKeywordKind.block,
  });

  final BlockedKeyword? existing;
  final BlockedKeywordKind defaultKind;

  @override
  ConsumerState<_KeywordEditorSheet> createState() =>
      _KeywordEditorSheetState();
}

class _KeywordEditorSheetState extends ConsumerState<_KeywordEditorSheet> {
  late final TextEditingController _controller;
  late BlockedKeywordKind _kind;
  late BlockedKeywordMatchType _matchType;
  late BlockedKeywordScope _scope;
  late bool _wholeWord;
  late bool _caseSensitive;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.keyword ?? '');
    _kind = widget.existing?.kind ?? widget.defaultKind;
    _matchType = widget.existing?.matchType ?? BlockedKeywordMatchType.plain;
    _scope = widget.existing?.scope ?? BlockedKeywordScope.repliesOnly;
    _wholeWord = widget.existing?.wholeWord ?? true;
    _caseSensitive =
        widget.existing?.caseSensitive ??
        (_matchType == BlockedKeywordMatchType.regex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateLocalError(AppLocalizations l10n, String raw) {
    final error = validateBlockedKeywordPattern(
      raw,
      _matchType,
      caseSensitive: _caseSensitive,
    );
    if (error == null) {
      return null;
    }
    return switch (error) {
      BlockedKeywordPatternError.empty => l10n.contentFilterKeywordEmptyError,
      BlockedKeywordPatternError.regexTooLong =>
        l10n.contentFilterKeywordRegexTooLongError,
      BlockedKeywordPatternError.invalidRegex =>
        l10n.contentFilterKeywordRegexError,
    };
  }

  Future<void> _submit() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final raw = _controller.text.trim();
    final localError = _validateLocalError(l10n, raw);
    if (localError != null) {
      setState(() => _errorText = localError);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final controller = ref.read(blockedKeywordsControllerProvider.notifier);
    final existing = widget.existing;
    final result = existing == null
        ? await controller.add(
            keyword: raw,
            scope: _scope,
            kind: _kind,
            matchType: _matchType,
            wholeWord: _wholeWord,
            caseSensitive: _caseSensitive,
          )
        : await controller.updateRule(
            id: existing.id,
            keyword: raw,
            scope: _scope,
            kind: _kind,
            matchType: _matchType,
            wholeWord: _wholeWord,
            caseSensitive: _caseSensitive,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result.status) {
      case BlockedKeywordMutationStatus.created:
      case BlockedKeywordMutationStatus.updated:
        Navigator.of(context).pop();
      case BlockedKeywordMutationStatus.invalid:
        setState(() => _errorText = l10n.contentFilterKeywordEmptyError);
      case BlockedKeywordMutationStatus.invalidRegex:
        setState(() => _errorText = l10n.contentFilterKeywordRegexError);
      case BlockedKeywordMutationStatus.regexTooLong:
        setState(() => _errorText = l10n.contentFilterKeywordRegexTooLongError);
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
              hintText: _matchType == BlockedKeywordMatchType.regex
                  ? l10n.contentFilterKeywordRegexHint
                  : l10n.contentFilterKeywordHint,
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
              l10n.contentFilterRuleKindLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<BlockedKeywordKind>(
              segments: [
                ButtonSegment(
                  value: BlockedKeywordKind.block,
                  label: Text(
                    l10n.contentFilterRuleKindBlock,
                    key: const Key('content-filter-kind-block'),
                  ),
                ),
                ButtonSegment(
                  value: BlockedKeywordKind.allow,
                  label: Text(
                    l10n.contentFilterRuleKindAllow,
                    key: const Key('content-filter-kind-allow'),
                  ),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) {
                setState(() => _kind = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.contentFilterRuleMatchTypeLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<BlockedKeywordMatchType>(
              segments: [
                ButtonSegment(
                  value: BlockedKeywordMatchType.plain,
                  label: Text(
                    l10n.contentFilterRuleMatchPlain,
                    key: const Key('content-filter-match-plain'),
                  ),
                ),
                ButtonSegment(
                  value: BlockedKeywordMatchType.regex,
                  label: Text(
                    l10n.contentFilterRuleMatchRegex,
                    key: const Key('content-filter-match-regex'),
                  ),
                ),
              ],
              selected: {_matchType},
              onSelectionChanged: (selection) {
                final nextType = selection.first;
                setState(() {
                  _matchType = nextType;
                  if (widget.existing == null) {
                    _caseSensitive = nextType == BlockedKeywordMatchType.regex;
                    _wholeWord = nextType == BlockedKeywordMatchType.plain;
                  }
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 16),
            AppGroupedSection(
              children: [
                if (_matchType == BlockedKeywordMatchType.plain)
                  AppSwitchRow(
                    key: const Key('content-filter-whole-word-switch'),
                    title: l10n.contentFilterWholeWordLabel,
                    subtitle: l10n.contentFilterWholeWordDetail,
                    value: _wholeWord,
                    onChanged: (value) => setState(() => _wholeWord = value),
                  ),
                AppSwitchRow(
                  key: const Key('content-filter-case-sensitive-switch'),
                  title: l10n.contentFilterCaseSensitiveLabel,
                  subtitle: l10n.contentFilterCaseSensitiveDetail,
                  value: _caseSensitive,
                  onChanged: (value) => setState(() => _caseSensitive = value),
                ),
              ],
            ),
            if (_kind == BlockedKeywordKind.block) ...[
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
                    onTap: () => setState(
                      () => _scope = BlockedKeywordScope.repliesOnly,
                    ),
                  ),
                  _ScopeOptionRow(
                    optionKey: const Key('content-filter-scope-include-body'),
                    title: l10n.contentFilterKeywordScopeIncludeBody,
                    subtitle: l10n.contentFilterKeywordScopeIncludeBodyDetail,
                    selected: _scope == BlockedKeywordScope.includeBody,
                    onTap: () => setState(
                      () => _scope = BlockedKeywordScope.includeBody,
                    ),
                  ),
                ],
              ),
            ],
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
