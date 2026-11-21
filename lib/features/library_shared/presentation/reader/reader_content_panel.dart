import 'package:flutter/material.dart';
import 'package:prism_ui/segmented_control.dart' as prism;
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_panel_theme.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

/// 阅读器内容面板分栏：目录 / 书签。
enum ReaderContentTab { catalog, bookmarks }

/// 内容面板书签页条目模型。
class ReaderBookmarkEntry {
  const ReaderBookmarkEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.isCurrent = false,
    required this.onTap,
    this.onDelete,
    this.rowKey,
    this.deleteKey,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final Key? rowKey;
  final Key? deleteKey;
}

/// 漫画与小说共用的阅读器“内容”面板（目录 / 书签）。
class ReaderContentPanel extends StatefulWidget {
  const ReaderContentPanel({
    super.key,
    required this.catalogBuilder,
    required this.bookmarks,
    this.initialTab = ReaderContentTab.catalog,
    this.palette,
    this.emptyBookmarksTitle,
  });

  final WidgetBuilder catalogBuilder;
  final List<ReaderBookmarkEntry> bookmarks;
  final ReaderContentTab initialTab;
  final ReaderPanelPalette? palette;
  final String? emptyBookmarksTitle;

  @override
  State<ReaderContentPanel> createState() => _ReaderContentPanelState();
}

class _ReaderContentPanelState extends State<ReaderContentPanel> {
  late ReaderContentTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: AppPrismTheme(
                child: prism.SegmentedControl<ReaderContentTab>(
                  key: const Key('reader-chapter-panel-tabs'),
                  segments: [
                    (ReaderContentTab.catalog, l10n.readerCatalog),
                    (ReaderContentTab.bookmarks, l10n.readerBookmarks),
                  ],
                  value: _tab,
                  onChanged: (next) {
                    if (next != _tab) {
                      setState(() => _tab = next);
                    }
                  },
                ),
              ),
            ),
            Expanded(
              child: _tab == ReaderContentTab.catalog
                  ? widget.catalogBuilder(context)
                  : _buildBookmarksBody(l10n, scheme),
            ),
          ],
        );
      },
    );

    final palette = widget.palette;
    if (palette != null) {
      body = ReaderPanelTheme(
        palette: palette,
        child: Material(color: palette.panelSurface, child: body),
      );
    }
    return body;
  }

  Widget _buildBookmarksBody(AppLocalizations l10n, ColorScheme scheme) {
    if (widget.bookmarks.isEmpty) {
      return AppEmptyState(
        title: widget.emptyBookmarksTitle ?? l10n.readerBookmarksEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        AppGroupedSection(
          margin: EdgeInsets.zero,
          children: [
            for (final item in widget.bookmarks)
              AppGroupedRow(
                key: item.rowKey,
                leading: Icon(
                  Icons.bookmark,
                  color: item.isCurrent ? scheme.primary : scheme.onSurface,
                ),
                title: item.title,
                subtitle: item.subtitle,
                selected: item.isCurrent ? true : null,
                onTap: item.onTap,
                trailing: item.onDelete == null
                    ? (item.isCurrent
                          ? Icon(Icons.check, size: 18, color: scheme.primary)
                          : null)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.isCurrent) ...[
                            Icon(Icons.check, size: 18, color: scheme.primary),
                            const SizedBox(width: 4),
                          ],
                          AppToolbarIconButton(
                            buttonKey: item.deleteKey,
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.readerBookmarkDelete(item.title),
                            size: AppToolbarButtonSize.compact,
                            glassLevel: AppGlassLevel.off,
                            baseColor: Colors.transparent,
                            foregroundColor: scheme.onSurfaceVariant,
                            onPressed: item.onDelete,
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ],
    );
  }
}
