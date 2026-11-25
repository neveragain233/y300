import 'package:flutter/material.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/services/keyword_filter_matcher.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

/// 关键词规则即时测试卡片：输入样本文本后实时显示命中、豁免或放行结果。
class KeywordRuleTesterCard extends StatefulWidget {
  const KeywordRuleTesterCard({super.key, required this.rules});

  final List<BlockedKeyword> rules;

  @override
  State<KeywordRuleTesterCard> createState() => _KeywordRuleTesterCardState();
}

class _KeywordRuleTesterCardState extends State<KeywordRuleTesterCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sample = _controller.text;
    final hasSample = sample.trim().isNotEmpty;
    final evaluation = hasSample
        ? KeywordFilterMatcher.evaluatePlainText(sample, widget.rules)
        : null;

    return AppGroupedSection(
      title: l10n.contentFilterTesterTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextInput(
                key: const Key('content-filter-rule-tester-input'),
                controller: _controller,
                hintText: l10n.contentFilterTesterHint,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              if (evaluation != null) ...[
                const SizedBox(height: 10),
                _TesterResultBanner(
                  key: const Key('content-filter-rule-tester-result'),
                  evaluation: evaluation,
                  theme: theme,
                  l10n: l10n,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TesterResultBanner extends StatelessWidget {
  const _TesterResultBanner({
    super.key,
    required this.evaluation,
    required this.theme,
    required this.l10n,
  });

  final KeywordEvaluationResult evaluation;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    final IconData icon;

    final matchedAllow = evaluation.matchedAllow;
    final matchedBlock = evaluation.matchedBlock;

    if (matchedAllow != null && matchedBlock != null) {
      text = l10n.contentFilterTesterExempted(
        matchedAllow.rule.keyword,
        matchedBlock.rule.keyword,
      );
      color = theme.colorScheme.primary;
      icon = Icons.verified_user_outlined;
    } else if (matchedAllow != null) {
      text = l10n.contentFilterTesterAllowedOnly(matchedAllow.rule.keyword);
      color = theme.colorScheme.primary;
      icon = Icons.check_circle_outline;
    } else if (matchedBlock != null) {
      text = l10n.contentFilterTesterBlocked(
        matchedBlock.rule.keyword,
        matchedBlock.snippet,
      );
      color = theme.colorScheme.error;
      icon = Icons.block_outlined;
    } else {
      text = l10n.contentFilterTesterNoMatch;
      color = theme.colorScheme.onSurfaceVariant;
      icon = Icons.check_circle_outline;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
