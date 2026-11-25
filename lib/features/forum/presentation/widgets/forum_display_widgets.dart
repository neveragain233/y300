import 'package:flutter/material.dart';
import 'package:prism_ui/press_region.dart' as prism_press;
import 'package:y300/app/navigation/main_shell_bottom_inset.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_dimensions.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/services/keyword_filter_matcher.dart';
import 'package:y300/features/content_filter/domain/services/thread_block_identity.dart';
import 'package:y300/features/content_filter/presentation/widgets/keyword_filtered_thread_tile.dart';
import 'package:y300/features/content_filter/presentation/widgets/thread_block_menu_button.dart';
import 'package:y300/features/forum/domain/services/forum_chrome_image_adapter.dart';
import 'package:y300/features/forum/presentation/forum_display_content_projection.dart';
import 'package:y300/features/forum/presentation/forum_display_state.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_theme.dart';
import 'package:y300/shared/widgets/app_capsule_tab_bar.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/forum_cached_avatar.dart';
import 'package:y300/shared/widgets/forum_media_loading_style.dart';
import 'package:y300/shared/widgets/forum_native_surface.dart';
import 'package:y300/shared/widgets/forum_pull_to_refresh.dart';
import 'package:y300/shared/widgets/forum_thread_badges.dart';
import 'package:y300/shared/widgets/native_pagination_bar.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_status_views.dart';

class ForumDisplayContent extends StatefulWidget {
  const ForumDisplayContent({
    super.key,
    required this.projection,
    required this.scrollController,
    required this.filterAnchorKey,
    required this.headImageKey,
    required this.onLoadMore,
    required this.onLoadPrevious,
    required this.onSelectPage,
    required this.onOpenFilter,
    required this.onOpenThreadTag,
    required this.onOpenThread,
    this.onOpenRevealedThread,
    required this.onOpenTopEntry,
    required this.onOpenSubForum,
    this.blockedThreadIds = const <String>{},
    this.blacklistedUserIds = const <String>{},
    this.keywordFilterRules = KeywordFilterRuleSet.empty,
  });

  final ForumDisplayContentProjection projection;
  final ScrollController scrollController;
  final GlobalKey filterAnchorKey;
  final GlobalKey headImageKey;
  final VoidCallback onLoadMore;
  final VoidCallback onLoadPrevious;
  final ValueChanged<int> onSelectPage;
  final ValueChanged<ForumDisplayFilterItem> onOpenFilter;
  final ValueChanged<ForumThreadSummary> onOpenThreadTag;
  final ValueChanged<ForumThreadSummary> onOpenThread;
  final ValueChanged<ForumThreadSummary>? onOpenRevealedThread;
  final ValueChanged<ForumDisplayTopEntry> onOpenTopEntry;
  final ValueChanged<ForumDisplaySubForum> onOpenSubForum;

  /// Canonical thread ids hidden by local content rules.
  final Set<String> blockedThreadIds;

  /// Author ids hidden by the synced web blacklist.
  final Set<String> blacklistedUserIds;

  /// Active local keyword rules for list filtering.
  final KeywordFilterRuleSet keywordFilterRules;

  @override
  State<ForumDisplayContent> createState() => _ForumDisplayContentState();
}

class _ForumDisplayContentState extends State<ForumDisplayContent> {
  bool _topEntriesExpanded = false;
  final Set<String> _revealedKeywordThreadIds = <String>{};

  @override
  void didUpdateWidget(covariant ForumDisplayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_topEntrySignature(oldWidget.projection.sourceState.topEntries) !=
        _topEntrySignature(widget.projection.sourceState.topEntries)) {
      _topEntriesExpanded = false;
    }
    if (oldWidget.projection.sourceState.fid !=
            widget.projection.sourceState.fid ||
        oldWidget.projection.sourceState.currentPage !=
            widget.projection.sourceState.currentPage ||
        oldWidget.keywordFilterRules.revision !=
            widget.keywordFilterRules.revision) {
      _revealedKeywordThreadIds.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ForumDisplayThemePalette.resolve(Theme.of(context));
    final state = widget.projection.sourceState;
    final displayPrimaryFilters = _displayFilters(
      widget.projection.primaryFilters,
    );
    final displayTypeFilters = _displayFilters(widget.projection.typeFilters);
    final displaySubForums = _displaySubForums(widget.projection.subForums);
    final displayTopEntries = [
      for (final entry in _displayTopEntries(widget.projection.topEntries))
        if (!widget.blockedThreadIds.contains(
          ThreadBlockIdentity.normalizeTid(entry.tid),
        ))
          entry,
    ];
    final threadEntries = <_ForumThreadListItem>[];
    for (final projection in widget.projection.threads) {
      final source = projection.source;
      final normalizedTid =
          ThreadBlockIdentity.normalizeTid(source.tid) ?? source.tid.trim();
      if (widget.blockedThreadIds.contains(normalizedTid) ||
          widget.blacklistedUserIds.contains(source.uid.trim())) {
        continue;
      }
      final matchedKeyword = KeywordFilterMatcher.matchThreadListItem(
        subject: source.subject,
        convertedSubject: projection.displaySubject,
        excerpt: source.excerpt,
        convertedExcerpt: projection.displayExcerpt,
        ruleSet: widget.keywordFilterRules,
        authorId: source.uid,
      );
      if (matchedKeyword == null ||
          !widget.keywordFilterRules.hideBlockedContentCompletely) {
        threadEntries.add(
          _ForumThreadListItem(
            thread: _displayThread(projection),
            isKeywordFiltered: matchedKeyword != null,
            normalizedTid: normalizedTid,
          ),
        );
      }
    }
    final hiddenByRules =
        widget.projection.threads.isNotEmpty && threadEntries.isEmpty;
    final filterPadding = EdgeInsets.fromLTRB(
      16,
      4,
      displayTypeFilters.isNotEmpty ? 8 : 16,
      4,
    );
    final filterHeaderHeight = AppCapsuleTabBar.preferredHeight(
      context,
      labels: displayPrimaryFilters.map((item) => item.label),
      padding: filterPadding,
    );
    return ColoredBox(
      color: palette.background,
      child: CustomScrollView(
        key: const Key('forum-display-list'),
        controller: widget.scrollController,
        physics: ForumPullToRefresh.scrollPhysics,
        slivers: [
          if (state.headImageUrl?.trim().isNotEmpty == true)
            SliverToBoxAdapter(
              child: _ForumHeadImage(
                key: widget.headImageKey,
                fid: state.fid,
                url: state.headImageUrl!.trim(),
                label: widget.projection.displayTitle,
                palette: palette,
                initialDimensions: state.headImageDimensions,
              ),
            ),
          if (displayPrimaryFilters.isNotEmpty || displayTypeFilters.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _ForumDisplayFilterHeaderDelegate(
                anchorKey: widget.filterAnchorKey,
                height: filterHeaderHeight,
                filterPadding: filterPadding,
                primaryItems: displayPrimaryFilters,
                typeItems: displayTypeFilters,
                onSelected: (item) => widget.onOpenFilter(
                  _sourceFilter(item, [
                    ...widget.projection.primaryFilters,
                    ...widget.projection.typeFilters,
                  ]),
                ),
                palette: palette,
              ),
            ),
          if (displaySubForums.isNotEmpty)
            SliverToBoxAdapter(
              child: _SubForumList(
                subForums: displaySubForums,
                onOpenSubForum: (item) => widget.onOpenSubForum(
                  _sourceSubForum(item, widget.projection.subForums),
                ),
                palette: palette,
              ),
            ),
          if (displayTopEntries.isNotEmpty)
            SliverToBoxAdapter(
              child: _TopEntrySection(
                entries: displayTopEntries,
                isExpanded: _topEntriesExpanded,
                onToggle: () {
                  setState(() => _topEntriesExpanded = !_topEntriesExpanded);
                },
                onOpenEntry: (item) => widget.onOpenTopEntry(
                  _sourceTopEntry(item, widget.projection.topEntries),
                ),
                palette: palette,
              ),
            ),
          if (threadEntries.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyThreadList(
                palette: palette,
                hiddenByRules: hiddenByRules,
                hasMore: state.hasMore,
              ),
            )
          else
            _ThreadListSection(
              signature: _threadListSignature(state),
              entries: threadEntries,
              revealedKeywordThreadIds: _revealedKeywordThreadIds,
              onRevealKeywordThread: (tid) {
                setState(() => _revealedKeywordThreadIds.add(tid));
              },
              onHideKeywordThread: (tid) {
                setState(() => _revealedKeywordThreadIds.remove(tid));
              },
              onOpenThread: (item) => widget.onOpenThread(
                _sourceThread(item, widget.projection.threads),
              ),
              onOpenRevealedThread: (item) {
                final source = _sourceThread(item, widget.projection.threads);
                if (widget.onOpenRevealedThread != null) {
                  widget.onOpenRevealedThread!(source);
                } else {
                  widget.onOpenThread(source);
                }
              },
              onOpenThreadTag: (item) => widget.onOpenThreadTag(
                _sourceThread(item, widget.projection.threads),
              ),
              palette: palette,
            ),
          SliverPadding(
            // 沉浸式主导航覆盖层之下保留可滚出的页尾空间。
            padding: EdgeInsets.only(
              bottom: mainShellBottomScrollInset(context),
            ),
            sliver: SliverToBoxAdapter(
              child: _LoadMoreSection(
                currentPage: state.currentPage,
                lastPage: state.lastPage,
                canLoadPrevious: state.currentPage > 1,
                hasMore: state.hasMore,
                isLoadingMore: state.isLoadingMore,
                onLoadPrevious: widget.onLoadPrevious,
                onLoadMore: widget.onLoadMore,
                onSelectPage: widget.onSelectPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _topEntrySignature(List<ForumDisplayTopEntry> entries) {
    return entries.map((entry) => '${entry.tid}:${entry.url}').join('|');
  }

  String _threadListSignature(ForumDisplayPageState state) {
    final threads = state.threads;
    if (threads.isEmpty) {
      return '${state.currentPage}:empty';
    }
    return [
      state.currentPage,
      threads.length,
      threads.first.tid,
      threads.last.tid,
    ].join(':');
  }

  List<ForumDisplayFilterItem> _displayFilters(
    List<ForumDisplayFilterProjection> items,
  ) {
    return [
      for (final item in items)
        ForumDisplayFilterItem(
          label: item.displayLabel,
          url: item.source.url,
          isSelected: item.source.isSelected,
          typeid: item.source.typeid,
        ),
    ];
  }

  List<ForumDisplaySubForum> _displaySubForums(
    List<ForumDisplaySubForumProjection> items,
  ) {
    return [
      for (final item in items)
        ForumDisplaySubForum(
          fid: item.source.fid,
          title: item.displayTitle,
          url: item.source.url,
          iconUrl: item.source.iconUrl,
        ),
    ];
  }

  List<ForumDisplayTopEntry> _displayTopEntries(
    List<ForumDisplayTopEntryProjection> items,
  ) {
    return [
      for (final item in items)
        ForumDisplayTopEntry(
          title: item.displayTitle,
          url: item.source.url,
          tid: item.source.tid,
          badgeLabel: item.displayBadgeLabel,
          titleColorHex: item.source.titleColorHex,
          isAnnouncement: item.source.isAnnouncement,
        ),
    ];
  }

  ForumThreadSummary _displayThread(ForumDisplayThreadProjection item) {
    return item.source.copyWith(
      subject: item.displaySubject,
      excerpt: item.displayExcerpt,
      sourceTagName: item.displaySourceTagName,
      badgeLabel: item.displayBadgeLabel,
      badges: item.displayBadges,
      dateline: item.displayDateline,
    );
  }

  ForumDisplayFilterItem _sourceFilter(
    ForumDisplayFilterItem displayed,
    List<ForumDisplayFilterProjection> projections,
  ) {
    for (final projection in projections) {
      if (projection.source.url == displayed.url &&
          projection.source.typeid == displayed.typeid) {
        return projection.source;
      }
    }
    return displayed;
  }

  ForumDisplaySubForum _sourceSubForum(
    ForumDisplaySubForum displayed,
    List<ForumDisplaySubForumProjection> projections,
  ) {
    for (final projection in projections) {
      if (projection.source.fid == displayed.fid) {
        return projection.source;
      }
    }
    return displayed;
  }

  ForumDisplayTopEntry _sourceTopEntry(
    ForumDisplayTopEntry displayed,
    List<ForumDisplayTopEntryProjection> projections,
  ) {
    for (final projection in projections) {
      if (projection.source.tid == displayed.tid &&
          projection.source.url == displayed.url) {
        return projection.source;
      }
    }
    return displayed;
  }

  ForumThreadSummary _sourceThread(
    ForumThreadSummary displayed,
    List<ForumDisplayThreadProjection> projections,
  ) {
    for (final projection in projections) {
      if (projection.source.tid == displayed.tid) {
        return projection.source;
      }
    }
    return displayed;
  }
}

class _ForumDisplayFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ForumDisplayFilterHeaderDelegate({
    required this.anchorKey,
    required this.height,
    required this.filterPadding,
    required this.primaryItems,
    required this.typeItems,
    required this.onSelected,
    required this.palette,
  });

  final GlobalKey anchorKey;
  final double height;
  final EdgeInsetsGeometry filterPadding;
  final List<ForumDisplayFilterItem> primaryItems;
  final List<ForumDisplayFilterItem> typeItems;
  final ValueChanged<ForumDisplayFilterItem> onSelected;
  final ForumDisplayThemePalette palette;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _ForumDisplayFilterBand(
      anchorKey: anchorKey,
      height: height,
      filterPadding: filterPadding,
      primaryItems: primaryItems,
      typeItems: typeItems,
      onSelected: onSelected,
      palette: palette,
      overlapsContent: overlapsContent,
    );
  }

  @override
  bool shouldRebuild(covariant _ForumDisplayFilterHeaderDelegate oldDelegate) {
    return height != oldDelegate.height ||
        filterPadding != oldDelegate.filterPadding ||
        primaryItems != oldDelegate.primaryItems ||
        anchorKey != oldDelegate.anchorKey ||
        typeItems != oldDelegate.typeItems ||
        onSelected != oldDelegate.onSelected ||
        palette != oldDelegate.palette;
  }
}

class _ForumDisplayFilterBand extends StatelessWidget {
  const _ForumDisplayFilterBand({
    required this.anchorKey,
    required this.height,
    required this.filterPadding,
    required this.primaryItems,
    required this.typeItems,
    required this.onSelected,
    required this.palette,
    required this.overlapsContent,
  });

  final GlobalKey anchorKey;
  final double height;
  final EdgeInsetsGeometry filterPadding;
  final List<ForumDisplayFilterItem> primaryItems;
  final List<ForumDisplayFilterItem> typeItems;
  final ValueChanged<ForumDisplayFilterItem> onSelected;
  final ForumDisplayThemePalette palette;
  final bool overlapsContent;

  @override
  Widget build(BuildContext context) {
    final eInk = EInkModeScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return KeyedSubtree(
      key: anchorKey,
      child: ColoredBox(
        key: const Key('forum-display-filter-header'),
        color: palette.background,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: overlapsContent
                  ? Border(
                      bottom: BorderSide(
                        color: eInk
                            ? scheme.outlineVariant
                            : palette.outlineSoft.withValues(alpha: 0.72),
                      ),
                    )
                  : null,
              boxShadow: overlapsContent && !eInk
                  ? [
                      BoxShadow(
                        color: palette.stateLayer.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _FilterStrip(
                    items: primaryItems,
                    padding: filterPadding,
                    onSelected: onSelected,
                  ),
                ),
                if (typeItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TypeFilterMenu(
                      items: typeItems,
                      height: height,
                      onSelected: onSelected,
                      palette: palette,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForumDisplayGroup extends StatelessWidget {
  const _ForumDisplayGroup({
    required this.palette,
    required this.child,
    this.keyOverride,
    this.shadowAlpha = 0.12,
    this.shadowBlurRadius = 12,
    this.shadowOffset = const Offset(0, 4),
  });

  final ForumDisplayThemePalette palette;
  final Widget child;
  final Key? keyOverride;
  final double shadowAlpha;
  final double shadowBlurRadius;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final content = DecoratedBox(
      key: keyOverride,
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: radius,
        border: Border.all(color: palette.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: palette.stateLayer.withValues(alpha: shadowAlpha),
            blurRadius: shadowBlurRadius,
            offset: shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: content,
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider({required this.palette});

  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 12,
      endIndent: 12,
      color: palette.outlineSoft,
    );
  }
}

class _ForumHeadImage extends ConsumerStatefulWidget {
  const _ForumHeadImage({
    super.key,
    required this.fid,
    required this.url,
    required this.label,
    required this.palette,
    required this.initialDimensions,
  });

  final String fid;
  final String url;
  final String label;
  final ForumDisplayThemePalette palette;
  final ForumImageDimensions? initialDimensions;

  @override
  ConsumerState<_ForumHeadImage> createState() => _ForumHeadImageState();
}

class _ForumHeadImageState extends ConsumerState<_ForumHeadImage> {
  static const double _fallbackHeight = 72;

  ForumImageDimensions? _dimensions;
  bool _resolvedCurrentSource = false;

  @override
  void initState() {
    super.initState();
    _dimensions = _validDimensions(widget.initialDimensions);
  }

  @override
  void didUpdateWidget(covariant _ForumHeadImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.fid != widget.fid || oldWidget.url != widget.url;
    if (sourceChanged) {
      _resolvedCurrentSource = false;
      _dimensions = _validDimensions(widget.initialDimensions);
      return;
    }
    if (!_resolvedCurrentSource &&
        oldWidget.initialDimensions != widget.initialDimensions) {
      _dimensions = _validDimensions(widget.initialDimensions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = const ForumChromeImageAdapter().headImage(
      fid: widget.fid,
      imageUrl: widget.url,
    );
    final request = spec == null
        ? null
        : ref
              .watch(forumImageRequestResolverProvider)
              .resolveCacheRequest(spec);
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      key: const Key('forum-head-image-placeholder'),
      color: ForumMediaLoadingStyle.placeholderColorFor(
        theme.scaffoldBackgroundColor,
      ),
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : ForumMediaLoadingStyle.fadeInDuration;
    final sourceIdentity = '${widget.fid}\u0000${widget.url}';
    return Semantics(
      image: true,
      label: widget.label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final dimensions = _validDimensions(_dimensions);
          final targetHeight = dimensions == null
              ? _fallbackHeight
              : availableWidth / dimensions.aspectRatio;
          return ColoredBox(
            key: const Key('forum-display-head-image'),
            color: widget.palette.panel,
            child: AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                height: targetHeight,
                child: ClipRect(
                  child: CachedLibraryImage(
                    request: request,
                    width: double.infinity,
                    height: targetHeight,
                    decodeDisplaySize: Size(availableWidth, targetHeight),
                    placeholder: placeholder,
                    errorPlaceholder: placeholder,
                    referer: ref.watch(forumImageRefererProvider),
                    fit: BoxFit.fitWidth,
                    fadeInDuration: duration,
                    remoteDisplayPolicy:
                        CachedImageRemoteDisplayPolicy.afterCacheWrite,
                    onImageResolved: (size) =>
                        _handleImageResolved(size, sourceIdentity),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleImageResolved(Size size, String sourceIdentity) {
    if (sourceIdentity != '${widget.fid}\u0000${widget.url}') {
      return;
    }
    final dimensions = ForumImageDimensions.fromValues(
      width: size.width,
      height: size.height,
      source: ForumImageDimensionSource.decodedImage,
    );
    if (!mounted || dimensions == null || dimensions == _dimensions) {
      return;
    }
    setState(() {
      _resolvedCurrentSource = true;
      _dimensions = dimensions;
    });
  }

  ForumImageDimensions? _validDimensions(ForumImageDimensions? dimensions) {
    return dimensions?.isValid == true ? dimensions : null;
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.items,
    required this.padding,
    required this.onSelected,
  });

  final List<ForumDisplayFilterItem> items;
  final EdgeInsetsGeometry padding;
  final ValueChanged<ForumDisplayFilterItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIdx = items.indexWhere((item) => item.isSelected);
    return AppCapsuleTabBar(
      tabs: [
        for (final item in items)
          AppCapsuleTabItem(id: _filterIdentity(item), label: item.label),
      ],
      selectedIndex: selectedIdx >= 0 ? selectedIdx : null,
      indicatorKey: const Key('forum-display-filter-indicator'),
      tabKeyBuilder: (id) => Key('forum-display-filter-$id'),
      padding: padding,
      onTap: (index) {
        if (index < 0 || index >= items.length) {
          return;
        }
        final item = items[index];
        if (!item.isSelected) {
          onSelected(item);
        }
      },
    );
  }
}

class _TypeFilterMenu extends StatefulWidget {
  const _TypeFilterMenu({
    required this.items,
    required this.height,
    required this.onSelected,
    required this.palette,
  });

  final List<ForumDisplayFilterItem> items;
  final double height;
  final ValueChanged<ForumDisplayFilterItem> onSelected;
  final ForumDisplayThemePalette palette;

  @override
  State<_TypeFilterMenu> createState() => _TypeFilterMenuState();
}

class _TypeFilterMenuState extends State<_TypeFilterMenu> {
  bool _isMenuOpen = false;

  void _setMenuOpen(bool value) {
    if (!mounted || _isMenuOpen == value) {
      return;
    }
    setState(() => _isMenuOpen = value);
  }

  @override
  Widget build(BuildContext context) {
    return AppPopupMenuButton<int>(
      useRootNavigator: true,
      onOpened: () => _setMenuOpen(true),
      onCanceled: () => _setMenuOpen(false),
      onSelected: (index) {
        if (!mounted) {
          return;
        }
        _setMenuOpen(false);
        if (index < 0 || index >= widget.items.length) {
          return;
        }
        final item = widget.items[index];
        if (!item.isSelected) {
          widget.onSelected(item);
        }
      },
      itemBuilder: (_) => [
        for (var index = 0; index < widget.items.length; index++)
          AppPopupMenuItem<int>(
            key: Key(
              'forum-display-type-filter-'
              '${_filterIdentity(widget.items[index])}',
            ),
            value: index,
            label: widget.items[index].label,
            checked: widget.items[index].isSelected,
          ),
      ],
      targetBuilder: (_, open) => AppPrismTheme(
        child: SizedBox(
          key: const Key('forum-display-type-filter-menu'),
          width: 44,
          height: widget.height,
          child: prism_press.PressRegion(
            onTap: open,
            overlay: prism_press.PressRegion.pressOverlay,
            shape: const CircleBorder(),
            child: Center(
              child: _RotatingArrowIcon(
                isExpanded: _isMenuOpen,
                color: widget.palette.softText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RotatingArrowIcon extends StatelessWidget {
  const _RotatingArrowIcon({required this.isExpanded, required this.color});

  final bool isExpanded;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isExpanded ? 0.5 : 0),
      duration: AppMotion.duration(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      builder: (context, turns, child) {
        return RotationTransition(
          turns: AlwaysStoppedAnimation<double>(turns),
          child: child,
        );
      },
      child: Icon(Icons.keyboard_arrow_down, color: color, size: 20),
    );
  }
}

class _SubForumList extends StatefulWidget {
  const _SubForumList({
    required this.subForums,
    required this.onOpenSubForum,
    required this.palette,
  });

  final List<ForumDisplaySubForum> subForums;
  final ValueChanged<ForumDisplaySubForum> onOpenSubForum;
  final ForumDisplayThemePalette palette;

  @override
  State<_SubForumList> createState() => _SubForumListState();
}

class _SubForumListState extends State<_SubForumList> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return _ForumDisplayGroup(
      palette: widget.palette,
      keyOverride: const Key('forum-display-sub-forums'),
      shadowAlpha: 0.05,
      shadowBlurRadius: 7,
      shadowOffset: const Offset(0, 2),
      child: DecoratedBox(
        decoration: BoxDecoration(color: widget.palette.surfaceContainerLow),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('forum-display-sub-forums-toggle'),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      _RotatingArrowIcon(
                        isExpanded: _isExpanded,
                        color: widget.palette.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).forumDisplaySubForum,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: widget.palette.title,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isExpanded) _SoftDivider(palette: widget.palette),
            ClipRect(
              child: AnimatedSize(
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 220),
                ),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(
                    context,
                    const Duration(milliseconds: 180),
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        alignment: const Alignment(-1, -1),
                        child: child,
                      ),
                    );
                  },
                  child: _isExpanded
                      ? Column(
                          key: const ValueKey('forum-sub-forums-expanded'),
                          children: [
                            for (final subForum in widget.subForums)
                              _SubForumTile(
                                key: Key(
                                  'forum-display-sub-forum-${subForum.fid}',
                                ),
                                subForum: subForum,
                                onTap: () => widget.onOpenSubForum(subForum),
                                palette: widget.palette,
                              ),
                          ],
                        )
                      : const SizedBox(
                          key: ValueKey('forum-sub-forums-collapsed'),
                          width: double.infinity,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubForumTile extends StatelessWidget {
  const _SubForumTile({
    super.key,
    required this.subForum,
    required this.onTap,
    required this.palette,
  });

  final ForumDisplaySubForum subForum;
  final VoidCallback onTap;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subForum.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: palette.softText, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TopEntrySection extends StatelessWidget {
  const _TopEntrySection({
    required this.entries,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpenEntry,
    required this.palette,
  });

  final List<ForumDisplayTopEntry> entries;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<ForumDisplayTopEntry> onOpenEntry;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return _ForumDisplayGroup(
      palette: palette,
      keyOverride: const Key('forum-display-top-entries'),
      shadowAlpha: 0.05,
      shadowBlurRadius: 7,
      shadowOffset: const Offset(0, 2),
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.surfaceContainerLow),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('forum-display-top-entries-toggle'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      _RotatingArrowIcon(
                        isExpanded: isExpanded,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${AppLocalizations.of(context).forumDisplayAnnouncements} / '
                          '${AppLocalizations.of(context).forumDisplayPinned}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: palette.title,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded) _SoftDivider(palette: palette),
            ClipRect(
              child: AnimatedSize(
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 220),
                ),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(
                    context,
                    const Duration(milliseconds: 180),
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        alignment: const Alignment(-1, -1),
                        child: child,
                      ),
                    );
                  },
                  child: isExpanded
                      ? Column(
                          key: const ValueKey('forum-top-expanded'),
                          children: [
                            for (final entry in entries)
                              _TopEntryTile(
                                key: ValueKey(
                                  'forum-top-${_topEntryIdentity(entry)}',
                                ),
                                entry: entry,
                                onTap: () => onOpenEntry(entry),
                                palette: palette,
                              ),
                          ],
                        )
                      : const SizedBox(
                          key: ValueKey('forum-top-collapsed'),
                          width: double.infinity,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _filterIdentity(ForumDisplayFilterItem item) {
  final typeid = item.typeid.trim();
  final url = item.url.trim();
  return typeid.isEmpty ? url : '$typeid:$url';
}

String _topEntryIdentity(ForumDisplayTopEntry entry) {
  final tid = entry.tid.trim();
  final url = entry.url.trim();
  return tid.isEmpty ? url : '$tid:$url';
}

class _TopEntryTile extends StatelessWidget {
  const _TopEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.palette,
  });

  final ForumDisplayTopEntry entry;
  final VoidCallback onTap;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final color =
        _parseColor(entry.titleColorHex) ??
        (entry.isAnnouncement ? palette.warning : palette.accent);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.tid.trim().isEmpty ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 10, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SmallBadge(
                label: entry.badgeLabel.isNotEmpty
                    ? entry.badgeLabel
                    : (entry.isAnnouncement
                          ? AppLocalizations.of(context)
                                .forumDisplayAnnouncements
                          : AppLocalizations.of(context).forumDisplayPinned),
                accentColor: entry.isAnnouncement
                    ? palette.warning
                    : palette.accent,
                palette: palette,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumThreadListItem {
  const _ForumThreadListItem({
    required this.thread,
    required this.isKeywordFiltered,
    required this.normalizedTid,
  });

  final ForumThreadSummary thread;
  final bool isKeywordFiltered;
  final String normalizedTid;
}

class _ThreadListSection extends StatelessWidget {
  const _ThreadListSection({
    required this.signature,
    required this.entries,
    required this.revealedKeywordThreadIds,
    required this.onRevealKeywordThread,
    required this.onHideKeywordThread,
    required this.onOpenThread,
    required this.onOpenRevealedThread,
    required this.onOpenThreadTag,
    required this.palette,
  });

  final String signature;
  final List<_ForumThreadListItem> entries;
  final Set<String> revealedKeywordThreadIds;
  final ValueChanged<String> onRevealKeywordThread;
  final ValueChanged<String> onHideKeywordThread;
  final ValueChanged<ForumThreadSummary> onOpenThread;
  final ValueChanged<ForumThreadSummary> onOpenRevealedThread;
  final ValueChanged<ForumThreadSummary> onOpenThreadTag;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final indices = <Key, int>{
      for (var index = 0; index < entries.length; index++)
        ValueKey('forum-thread-row-${entries[index].thread.tid}'): index,
    };
    // Keep only the viewport/cache extent alive. Cross-fading whole pages
    // would retain both lists and start offscreen avatar work on page changes.
    return SliverPadding(
      key: ValueKey('forum-thread-list-$signature'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      sliver: SliverList.builder(
        key: const Key('forum-thread-list-group'),
        itemCount: entries.length,
        findChildIndexCallback: (key) => indices[key],
        itemBuilder: (context, index) {
          final entry = entries[index];
          final thread = entry.thread;
          final revealed =
              entry.isKeywordFiltered &&
              revealedKeywordThreadIds.contains(entry.normalizedTid);
          Widget row;
          if (entry.isKeywordFiltered && !revealed) {
            row = KeywordFilteredThreadPlaceholder(
              tid: thread.tid,
              palette: palette,
              onRevealOnce: () => onRevealKeywordThread(entry.normalizedTid),
            );
          } else {
            final card = _ThreadCard(
              thread: thread,
              onTap: () => revealed
                  ? onOpenRevealedThread(thread)
                  : onOpenThread(thread),
              onTapTag: () => onOpenThreadTag(thread),
              palette: palette,
            );
            row = revealed
                ? KeywordRevealedThreadWrapper(
                    tid: thread.tid,
                    palette: palette,
                    onHideAgain: () => onHideKeywordThread(entry.normalizedTid),
                    child: card,
                  )
                : card;
          }
          // Lazy rows may be recreated when scrolling back. Keep ready cards
          // visible immediately instead of replaying an entrance fade each time.
          return Padding(
            key: ValueKey('forum-thread-row-${thread.tid}'),
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: row,
          );
        },
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.onTap,
    required this.onTapTag,
    required this.palette,
  });

  final ForumThreadSummary thread;
  final VoidCallback onTap;
  final VoidCallback onTapTag;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final badges = thread.effectiveBadges;
    final titleColor = _parseColor(thread.titleColorHex) ?? palette.threadTitle;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: ForumNativeSurfaceShadows.card(palette.stateLayer),
      ),
      child: Material(
        color: palette.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('forum-thread-${thread.tid}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(
                      url: thread.avatarUrl,
                      ownerId: thread.uid.trim().isNotEmpty
                          ? thread.uid
                          : thread.author,
                      threadId: thread.tid,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ThreadAuthorBlock(
                        thread: thread,
                        palette: palette,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ThreadBlockMenuButton(
                      tid: thread.tid,
                      subject: thread.subject,
                      authorId: thread.uid,
                      author: thread.author,
                      color: palette.bodyText,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  thread.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: titleColor,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ForumThreadBadgeGroup(badges: badges),
                ],
                if (thread.excerpt.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    thread.excerpt.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: palette.bodyText, height: 1.35),
                  ),
                ],
                const SizedBox(height: 10),
                _ThreadFooter(
                  thread: thread,
                  onTapTag: onTapTag,
                  palette: palette,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadAuthorBlock extends StatelessWidget {
  const _ThreadAuthorBlock({required this.thread, required this.palette});

  final ForumThreadSummary thread;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final authorStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.author,
      fontWeight: FontWeight.w700,
      height: 1.08,
    );
    final dateStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: palette.bodyText,
      fontWeight: FontWeight.w600,
      height: 1.08,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          thread.author.isNotEmpty
              ? thread.author
              : AppLocalizations.of(context).forumDisplayAnonymous,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: authorStyle,
        ),
        if (thread.dateline.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            thread.dateline.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dateStyle,
          ),
        ],
      ],
    );
  }
}

class _ThreadFooter extends StatelessWidget {
  const _ThreadFooter({
    required this.thread,
    required this.onTapTag,
    required this.palette,
  });

  final ForumThreadSummary thread;
  final VoidCallback onTapTag;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final tagName = _forumTagNameForDisplay(thread.sourceTagName);
    final hasTag = tagName != null;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _MetricChip(
                icon: Icons.visibility_outlined,
                value: thread.views,
                palette: palette,
              ),
              _MetricChip(
                icon: Icons.chat_bubble_outline,
                value: thread.replies,
                palette: palette,
              ),
            ],
          ),
        ),
        if (hasTag) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: _ThreadTagChip(
                thread: thread,
                tagName: tagName,
                onTapTag: onTapTag,
                palette: palette,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThreadTagChip extends StatelessWidget {
  const _ThreadTagChip({
    required this.thread,
    required this.tagName,
    required this.onTapTag,
    required this.palette,
  });

  final ForumThreadSummary thread;
  final String tagName;
  final VoidCallback onTapTag;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final isClickable = thread.sourceTagUrl?.trim().isNotEmpty == true;
    return InkWell(
      key: Key('forum-thread-tag-${thread.tid}'),
      borderRadius: BorderRadius.circular(8),
      onTap: isClickable ? onTapTag : null,
      // 点击高度独立于标签表面，保持原版的紧凑外观。
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: isClickable ? 48 : 25),
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surfaceContainerHigh.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(8),
              border: isClickable
                  ? null
                  : Border.all(color: palette.outlineSoft),
              boxShadow: isClickable
                  ? [
                      BoxShadow(
                        color: palette.stateLayer.withValues(alpha: 0.045),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Text(
                tagName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.tag, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hash is a forum-side visual marker, not part of the tag label shown
/// in the native list. Keep this normalization at the presentation boundary
/// so the raw tag value remains available for parsing, snapshots and routing.
String? _forumTagNameForDisplay(String? sourceTagName) {
  final normalized = sourceTagName?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final displayName = normalized.replaceFirst(RegExp(r'^#+'), '').trim();
  return displayName.isEmpty ? null : displayName;
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.ownerId,
    required this.threadId,
  });

  final String? url;
  final String ownerId;
  final String threadId;

  @override
  Widget build(BuildContext context) {
    return ForumCachedAvatar(
      key: Key('forum-thread-summary-avatar-$threadId'),
      imageUrl: url?.trim(),
      ownerId: ownerId,
      ownerType: ImageCacheOwnerType.forumDisplay,
      size: 36,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.value,
    required this.palette,
  });

  final IconData icon;
  final int value;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.bodyText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.bodyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.accentColor,
    required this.palette,
  });

  final String label;
  final Color accentColor;
  final ForumDisplayThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: palette.stateLayer.withValues(alpha: 0.045),
            blurRadius: 5,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 26, minHeight: 18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accentColor,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreSection extends StatelessWidget {
  const _LoadMoreSection({
    required this.currentPage,
    required this.lastPage,
    required this.canLoadPrevious,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadPrevious,
    required this.onLoadMore,
    required this.onSelectPage,
  });

  final int currentPage;
  final int? lastPage;
  final bool canLoadPrevious;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadPrevious;
  final VoidCallback onLoadMore;
  final ValueChanged<int> onSelectPage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = currentPage > 0 ? currentPage : 1;
    return NativePaginationBar(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
      currentPage: page,
      lastPage: lastPage,
      hasMore: hasMore,
      canLoadPrevious: canLoadPrevious,
      isLoading: isLoadingMore,
      onLoadPrevious: onLoadPrevious,
      onLoadNext: onLoadMore,
      onSelectPage: onSelectPage,
      previousLabel: l10n.forumDisplayPreviousPage,
      currentLabel: l10n.forumDisplayPage(page),
      nextLabel: hasMore ? l10n.forumDisplayNextPage : l10n.forumDisplayNoMore,
      previousButtonKey: const Key('forum-display-prev-page-button'),
      currentPageButtonKey: const Key('forum-display-current-page-button'),
      nextButtonKey: const Key('forum-display-load-more-button'),
      menuKeyPrefix: 'forum-display',
    );
  }
}

class _EmptyThreadList extends StatelessWidget {
  const _EmptyThreadList({
    required this.palette,
    this.hiddenByRules = false,
    this.hasMore = false,
  });

  final ForumDisplayThemePalette palette;
  final bool hiddenByRules;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!hiddenByRules) {
      return AppEmptyState(title: l10n.forumDisplayEmpty);
    }
    return _ForumDisplayGroup(
      palette: palette,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.contentFilterHiddenOnPage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: palette.softText),
              ),
              if (hasMore) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.contentFilterHiddenOnPageHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.softText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color? _parseColor(String? source) {
  final value = source?.trim();
  if (value == null || value.isEmpty || !value.startsWith('#')) {
    return null;
  }
  final hex = value.substring(1);
  if (hex.length == 3) {
    final expanded = hex.split('').map((char) => '$char$char').join();
    return Color(int.parse('FF$expanded', radix: 16));
  }
  if (hex.length == 6) {
    return Color(int.parse('FF$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return null;
}
