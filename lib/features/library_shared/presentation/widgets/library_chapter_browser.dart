import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/library_shared/presentation/controllers/chapter_search_controller.dart';
import 'package:y300/features/recent_search/application/recent_searches_controller.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/features/recent_search/presentation/recent_search_view.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';

typedef ChapterBrowserRowBuilder<T> = Widget Function(
  BuildContext context,
  T value,
  VoidCallback confirmSearch,
);

/// 共享目录检索、浏览位置与定位；业务打开、进度和菜单仍由宿主持有。
class LibraryChapterBrowser<T> extends StatefulWidget {
  const LibraryChapterBrowser({
    super.key,
    required this.workId,
    required this.entries,
    required this.rowBuilder,
    required this.itemExtent,
    this.currentId,
    this.locateCurrentOnOpen = true,
    this.keyPrefix = 'library-chapter',
    this.searchFieldKey,
    this.emptyKey,
    this.scrollController,
    this.leadingSlivers = const [],
    this.trailingSlivers = const [],
    this.layoutBuilder,
    this.normalizeTexts,
    this.topObstruction = 0,
    this.controlsInList = false,
  });

  final String workId;
  final List<ChapterSearchEntry<T>> entries;
  final ChapterBrowserRowBuilder<T> rowBuilder;
  final double itemExtent;
  final String? currentId;
  final bool locateCurrentOnOpen;
  final String keyPrefix;
  final Key? searchFieldKey;
  final Key? emptyKey;
  final ScrollController? scrollController;
  final List<Widget> leadingSlivers;
  final List<Widget> trailingSlivers;
  final Widget Function(
    BuildContext,
    PreferredSizeWidget controls,
    Widget list,
  )?
  layoutBuilder;
  final ChapterSearchTextNormalizer? normalizeTexts;
  final double topObstruction;
  final bool controlsInList;

  static double controlsHeight(BuildContext context) =>
      math.max(48, MediaQuery.textScalerOf(context).scale(16) * 1.5 + 20) + 56;

  @override
  State<LibraryChapterBrowser<T>> createState() =>
      _LibraryChapterBrowserState<T>();
}

class _LibraryChapterBrowserState<T> extends State<LibraryChapterBrowser<T>> {
  late final ChapterSearchController<T> _search;
  late final ScrollController _ownedScrollController;
  final _text = TextEditingController();
  final _focus = FocusNode();
  double _listStart = 0;
  double _browseOffset = 0;
  int _navigationRevision = 0;

  ScrollController get _scroll =>
      widget.scrollController ?? _ownedScrollController;

  @override
  void initState() {
    super.initState();
    _ownedScrollController = ScrollController();
    _search = ChapterSearchController<T>(normalizeTexts: widget.normalizeTexts)
      ..updateEntries(widget.entries)
      ..addListener(_refresh);
    if (widget.locateCurrentOnOpen) _locate(widget.currentId);
  }

  @override
  void didUpdateWidget(covariant LibraryChapterBrowser<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId) {
      _navigationRevision++;
      _text.clear();
      _browseOffset = 0;
      _search.setQuery('');
    }
    _search.updateEntries(widget.entries);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _navigationRevision++;
    _search
      ..removeListener(_refresh)
      ..dispose();
    _ownedScrollController.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changeQuery(String value) {
    if (_search.query.isEmpty &&
        value.trim().isNotEmpty &&
        _scroll.hasClients) {
      _browseOffset = _scroll.offset;
    }
    final wasSearching = _search.query.isNotEmpty;
    _search.setQuery(value);
    if (value.trim().isEmpty) {
      if (wasSearching) {
        _jumpAfterLayout(() => _browseOffset, alignUnderHeader: false);
      }
    } else {
      _jumpAfterLayout(() => _listStart);
    }
  }

  void _clear() {
    _text.clear();
    _changeQuery('');
  }

  void _locate(String? id) {
    if (id == null) return;
    final index = widget.entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    _focus.unfocus();
    _clear();
    _jumpAfterLayout(
      () => _listStart + math.max(0, index - 2) * widget.itemExtent,
    );
  }

  void _jumpAfterLayout(
    double Function() offset, {
    bool alignUnderHeader = true,
  }) {
    final revision = ++_navigationRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _navigationRevision || !_scroll.hasClients) {
        return;
      }
      final position = _scroll.position;
      _scroll.jumpTo(
        (offset() - (alignUnderHeader ? widget.topObstruction : 0)).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  void _recordSearch() {
    final keyword = _search.query;
    final scope = RecentSearchScope.workChapters(widget.workId);
    if (keyword.isEmpty || scope == null) return;
    _focus.unfocus();
    final container = _providerContainer();
    if (container == null) return;
    unawaited(
      container
          .read(recentSearchesControllerProvider.notifier)
          .record(scope, keyword),
    );
  }

  ProviderContainer? _providerContainer() {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return null;
    }
  }

  Future<void> _showRecentSearches() async {
    final scope = RecentSearchScope.workChapters(widget.workId);
    final container = _providerContainer();
    if (scope == null || container == null) return;
    _focus.unfocus();
    final keyword = await showAdaptivePanel<String>(
      context: context,
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: RecentSearchView(
              scope: scope,
              onSelected: (value) => Navigator.of(context).pop(value),
            ),
          ),
        ),
      ),
    );
    if (!mounted || keyword == null) return;
    _text.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    _changeQuery(keyword);
  }

  Widget _recentButton(AppLocalizations l10n) {
    Widget button(bool enabled) => IconButton(
      key: Key('${widget.keyPrefix}-search-recent'),
      tooltip: l10n.recentSearchTitle,
      onPressed: enabled ? _showRecentSearches : null,
      icon: const Icon(Icons.history),
    );
    final scope = RecentSearchScope.workChapters(widget.workId);
    if (_providerContainer() == null || scope == null) return button(false);
    return Consumer(
      builder: (context, ref, _) =>
          button(ref.watch(recentSearchesProvider(scope)).isNotEmpty),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _search.results;
    final prefix = widget.keyPrefix;
    PreferredSizeWidget buildControls({bool compact = false}) => PreferredSize(
      preferredSize: Size.fromHeight(
        LibraryChapterBrowser.controlsHeight(context) - (compact ? 48 : 0),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SizedBox(
                height: LibraryChapterBrowser.controlsHeight(context) - 56,
                child: AppTextInput(
                  key: widget.searchFieldKey ?? Key('$prefix-search-field'),
                  controller: _text,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  hintText: l10n.libraryChapterSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _text.text.isNotEmpty
                      ? IconButton(
                          key: Key('$prefix-search-clear'),
                          tooltip: l10n.commonClear,
                          onPressed: _clear,
                          icon: const Icon(Icons.close, size: 20),
                        )
                      : _recentButton(l10n),
                  onChanged: _changeQuery,
                  onSubmitted: (_) => _recordSearch(),
                ),
              ),
            ),
            if (!compact)
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l10n.libraryChapterSearchCount(results.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      key: Key('$prefix-first'),
                      tooltip: l10n.libraryChapterLocateFirst,
                      onPressed: results.isEmpty
                          ? null
                          : () {
                              _focus.unfocus();
                              _jumpAfterLayout(() => _listStart);
                            },
                      icon: const Icon(Icons.first_page),
                    ),
                    IconButton(
                      key: Key('$prefix-current'),
                      tooltip: l10n.libraryChapterLocateCurrent,
                      onPressed:
                          widget.entries.any(
                            (entry) => entry.id == widget.currentId,
                          )
                          ? () => _locate(widget.currentId)
                          : null,
                      icon: const Icon(Icons.my_location),
                    ),
                    IconButton(
                      key: Key('$prefix-last'),
                      tooltip: l10n.libraryChapterLocateLast,
                      onPressed: results.isEmpty
                          ? null
                          : () {
                              _focus.unfocus();
                              _jumpAfterLayout(
                                () =>
                                    _listStart +
                                    (results.length - 1) * widget.itemExtent,
                              );
                            },
                      icon: const Icon(Icons.last_page),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    final controls = buildControls();
    Widget buildList() => Scrollbar(
      controller: _scroll,
      interactive: true,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          ...widget.leadingSlivers,
          if (widget.controlsInList) SliverToBoxAdapter(child: controls),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              _listStart = constraints.precedingScrollExtent;
              return results.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        key: widget.emptyKey ?? Key('$prefix-search-empty'),
                        child: Text(l10n.novelNoMatchingChapters),
                      ),
                    )
                  : SliverFixedExtentList.builder(
                      itemExtent: widget.itemExtent,
                      itemCount: results.length,
                      itemBuilder: (context, index) => widget.rowBuilder(
                        context,
                        results[index].value,
                        _recordSearch,
                      ),
                    );
            },
          ),
          ...widget.trailingSlivers,
        ],
      ),
    );
    final layoutBuilder = widget.layoutBuilder;
    if (layoutBuilder != null) {
      return layoutBuilder(context, controls, buildList());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 键盘压缩窗口时保留固定输入框，收起定位工具行以留出结果空间。
        final compact =
            constraints.maxHeight <
            controls.preferredSize.height + widget.itemExtent;
        return Column(
          children: [
            if (!widget.controlsInList)
              compact ? buildControls(compact: true) : controls,
            Expanded(child: buildList()),
          ],
        );
      },
    );
  }
}
