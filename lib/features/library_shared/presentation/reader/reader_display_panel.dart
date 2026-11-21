import 'package:flutter/material.dart';
import 'package:prism_ui/segmented_control.dart' as prism;
import 'package:y300/features/library_shared/presentation/reader/reader_panel_theme.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 阅读器显示设置面板顶部分段。
enum ReaderDisplayTab { typography, theme, reading }

/// 漫画与小说共用的阅读器显示设置面板骨架。
///
/// 顶部固定「排版 / 主题 / 阅读」三段切换，下方一行展示当前配置摘要，
/// 每页仅挂载一组 `AppGroupedSection`；分段状态留在本地，不触发正文重建。
class ReaderDisplayPanel extends StatefulWidget {
  const ReaderDisplayPanel({
    super.key,
    this.panelKey,
    required this.summary,
    required this.typographyChildren,
    required this.themeChildren,
    required this.readingChildren,
    this.initialTab = ReaderDisplayTab.typography,
    this.onTabChanged,
    this.palette,
  });

  final Key? panelKey;
  final String summary;
  final List<Widget> typographyChildren;
  final List<Widget> themeChildren;
  final List<Widget> readingChildren;
  final ReaderDisplayTab initialTab;
  final ValueChanged<ReaderDisplayTab>? onTabChanged;
  final ReaderPanelPalette? palette;

  @override
  State<ReaderDisplayPanel> createState() => _ReaderDisplayPanelState();
}

class _ReaderDisplayPanelState extends State<ReaderDisplayPanel> {
  late ReaderDisplayTab _tab;
  late final Map<ReaderDisplayTab, ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _scrollControllers = {
      for (final tab in ReaderDisplayTab.values) tab: ScrollController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Widget> _childrenFor(ReaderDisplayTab tab) {
    switch (tab) {
      case ReaderDisplayTab.typography:
        return widget.typographyChildren;
      case ReaderDisplayTab.theme:
        return widget.themeChildren;
      case ReaderDisplayTab.reading:
        return widget.readingChildren;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return SafeArea(
          top: false,
          child: Column(
            key: widget.panelKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: AppPrismTheme(
                  child: prism.SegmentedControl<ReaderDisplayTab>(
                    key: const Key('reader-display-panel-tabs'),
                    segments: [
                      (ReaderDisplayTab.typography, l10n.novelTypography),
                      (ReaderDisplayTab.theme, l10n.novelTheme),
                      (ReaderDisplayTab.reading, l10n.novelReading),
                    ],
                    value: _tab,
                    onChanged: (next) {
                      if (next == _tab) {
                        return;
                      }
                      final controller = _scrollControllers[next];
                      if (controller != null && controller.hasClients) {
                        controller.jumpTo(0);
                      }
                      setState(() => _tab = next);
                      widget.onTabChanged?.call(next);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  widget.summary,
                  key: const Key('reader-display-panel-summary'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                // 用 IndexedStack 保留三栏测量高度，切换分段时不发生抽屉高度跳变。
                child: IndexedStack(
                  index: _tab.index,
                  alignment: AlignmentDirectional.topStart,
                  children: [
                    for (final tab in ReaderDisplayTab.values)
                      ExcludeFocus(
                        excluding: tab != _tab,
                        child: SingleChildScrollView(
                          key: ValueKey<ReaderDisplayTab>(tab),
                          controller: _scrollControllers[tab],
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: AppGroupedSection(
                            margin: EdgeInsets.zero,
                            dividerIndent: 16,
                            children: _childrenFor(tab),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    final palette = widget.palette;
    if (palette != null) {
      content = ReaderPanelTheme(
        palette: palette,
        child: Material(color: palette.panelSurface, child: content),
      );
    }
    return content;
  }
}
