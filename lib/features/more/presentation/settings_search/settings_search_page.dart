import 'package:flutter/material.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_index.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/inline_search_app_bar.dart';

/// 设置搜索页：本地过滤显式索引，选中后带着目标返回设置主页。
///
/// 空输入时列出常用设置入口；匹配只在本地索引上做包含判断，不发起请求，
/// 也不依赖拼音或倒排索引。
class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key, this.includeDebug = false});

  static const String routeName = '/more/settings/search';

  /// 调试构建才收录调试分组，由设置主页按实际可见分组传入。
  final bool includeDebug;

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState extends State<SettingsSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = buildSettingsSearchIndex(
      l10n,
      includeDebug: widget.includeDebug,
    );
    final query = _controller.text.trim();
    final results = query.isEmpty
        ? const <SettingsSearchEntry>[]
        : index.where((entry) => entry.matches(query)).toList(growable: false);
    return Scaffold(
      key: const Key('settings-search-page'),
      appBar: InlineSearchAppBar(
        controller: _controller,
        focusNode: _focusNode,
        fieldKey: const Key('settings-search-input'),
        backButtonKey: const Key('settings-search-back-button'),
        clearButtonKey: const Key('settings-search-clear-button'),
        hintText: l10n.settingsSearchHint,
        clearTooltip: l10n.commonClear,
        onBack: () => Navigator.of(context).maybePop(),
        onChanged: (_) => setState(() {}),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: query.isEmpty
                ? _buildRecommended(l10n, index)
                : results.isEmpty
                ? _buildEmptyState(l10n)
                : _buildResults(results),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommended(
    AppLocalizations l10n,
    List<SettingsSearchEntry> index,
  ) {
    final recommended = recommendedSettingsSearchEntries(index);
    return ListView(
      key: const Key('settings-search-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppGroupedSection(
          key: const Key('settings-search-recommended'),
          title: l10n.settingsSearchRecommendedTitle,
          children: [for (final entry in recommended) _buildResultRow(entry)],
        ),
      ],
    );
  }

  Widget _buildResults(List<SettingsSearchEntry> results) {
    return ListView(
      key: const Key('settings-search-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppGroupedSection(
          key: const Key('settings-search-results'),
          children: [for (final entry in results) _buildResultRow(entry)],
        ),
      ],
    );
  }

  Widget _buildResultRow(SettingsSearchEntry entry) {
    return AppGroupedRow(
      key: Key('settings-search-result-${entry.id}'),
      title: entry.title,
      subtitle: entry.summary,
      showChevron: true,
      onTap: () => Navigator.of(context).pop(entry.target),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('settings-search-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsSearchNoResults,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.settingsSearchNoResultsHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
