import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';

/// 目录与书签共用同一浏览入口，筛选不改变底下的阅读会话。
class ReaderChapterPanel<T> extends StatefulWidget {
  const ReaderChapterPanel({
    super.key,
    required this.entries,
    required this.isBookmarked,
    required this.builder,
  });
  final List<T> entries;
  final bool Function(T) isBookmarked;
  final Widget Function(BuildContext, List<T>) builder;
  @override
  State<ReaderChapterPanel<T>> createState() => _ReaderChapterPanelState<T>();
}

class _ReaderChapterPanelState<T> extends State<ReaderChapterPanel<T>> {
  bool _bookmarksOnly = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = _bookmarksOnly
        ? widget.entries.where(widget.isBookmarked).toList(growable: false)
        : widget.entries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SegmentedButton<bool>(
            key: const Key('reader-chapter-panel-tabs'),
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(80, 48)),
            ),
            segments: [
              ButtonSegment(value: false, label: Text(l10n.readerCatalog)),
              ButtonSegment(value: true, label: Text(l10n.readerBookmarks)),
            ],
            selected: {_bookmarksOnly},
            onSelectionChanged: (value) =>
                setState(() => _bookmarksOnly = value.single),
          ),
        ),
        Expanded(
          child: _bookmarksOnly && entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.readerBookmarksEmpty),
                  ),
                )
              : widget.builder(context, entries),
        ),
      ],
    );
  }
}
