import 'dart:async';

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/services/forum_image_request_resolver.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/forum/data/models/forum_home_chrome_models.dart';
import 'package:y300/features/forum/data/services/forum_home_carousel_dimension_resolver.dart';
import 'package:y300/features/forum/domain/services/forum_chrome_image_adapter.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/forum_media_loading_style.dart';

class ForumHomeSearchEntry extends StatelessWidget {
  const ForumHomeSearchEntry({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eInk = EInkModeScope.of(context);
    final useGlass =
        !eInk &&
        !MediaQuery.highContrastOf(context) &&
        AppGlassSurface.levelOf(context).enabled;
    final shape = BorderRadius.circular(24);
    final foregroundColor = eInk
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.72);
    final content = InkWell(
      onTap: onTap,
      borderRadius: shape,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: foregroundColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: foregroundColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (useGlass) {
      return Semantics(
        button: true,
        label: label,
        child: LiquidGlass(
          style: LiquidGlassStyle.pill(prismColorSchemeOf(scheme)),
          borderRadius: shape,
          shadows: AppGlassSurface.shadowsOf(scheme, eInk: false),
          child: Material(type: MaterialType.transparency, child: content),
        ),
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: eInk ? scheme.surface : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            color: eInk
                ? AppTheme.eInkBorderColor(scheme.brightness)
                : scheme.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

class ForumHomeCarousel extends ConsumerStatefulWidget {
  const ForumHomeCarousel({
    super.key,
    required this.items,
    required this.imageReferer,
    required this.onOpen,
    this.isActive = true,
  });

  final List<ForumHomeCarouselItem> items;
  final String imageReferer;
  final ValueChanged<ForumHomeCarouselItem> onOpen;
  final bool isActive;
  static const double maxHeight = 180;

  @override
  ConsumerState<ForumHomeCarousel> createState() => _ForumHomeCarouselState();
}

class _ForumHomeCarouselState extends ConsumerState<ForumHomeCarousel> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  List<ForumHomeCarouselItem> _displayedItems = const <ForumHomeCarouselItem>[];
  List<ForumHomeCarouselItem>? _pendingItems;
  String? _displayedSignature;
  String? _pendingSignature;
  double? _displayedAspectRatio;
  int _currentIndex = 0;
  int _pendingGeneration = 0;
  int _displayGeneration = 0;

  @override
  void initState() {
    super.initState();
    _displayedItems = widget.items;
    _displayedSignature = _signatureFor(widget.items);
    _displayedAspectRatio = _aspectRatioFor(widget.items);
  }

  @override
  void didUpdateWidget(covariant ForumHomeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _signatureFor(widget.items);
    if (_displayedSignature == null) {
      _displayedItems = widget.items;
      _displayedSignature = nextSignature;
      _displayedAspectRatio = _aspectRatioFor(widget.items);
      return;
    }
    if (nextSignature == _displayedSignature) {
      _displayedItems = widget.items;
      _displayedAspectRatio =
          _aspectRatioFor(widget.items) ?? _displayedAspectRatio;
      if (_pendingSignature != null && _pendingSignature != nextSignature) {
        _pendingGeneration += 1;
        _pendingItems = null;
        _pendingSignature = null;
      }
      if (!oldWidget.isActive && widget.isActive && _pendingItems != null) {
        _applyPendingItemsIfPossible();
      }
      return;
    }

    if (widget.items.isEmpty) {
      _pendingGeneration += 1;
      _displayGeneration += 1;
      _displayedItems = widget.items;
      _displayedSignature = nextSignature;
      _displayedAspectRatio = null;
      _pendingItems = null;
      _pendingSignature = null;
      _currentIndex = 0;
      return;
    }

    _pendingItems = widget.items;
    _pendingSignature = nextSignature;
    final generation = ++_pendingGeneration;
    unawaited(_primePendingImages(generation));
    if (!widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _commitPendingItems();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedItems.isEmpty) {
      return const SizedBox.shrink();
    }
    final palette = ForumHomeNativePalette.resolve(Theme.of(context));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: _ForumHomeCarouselBody(
        aspectRatio:
            _displayedAspectRatio ??
            ForumHomeCarouselDimensionResolver.fallbackAspectRatio,
        controller: _carouselController,
        imageReferer: widget.imageReferer,
        imageRequestResolver: ref.watch(forumImageRequestResolverProvider),
        items: _displayedItems,
        isActive: widget.isActive,
        onOpen: widget.onOpen,
        palette: palette,
        onPageChanged: _handlePageChanged,
        displayGeneration: _displayGeneration,
        onFirstImageResolved: _handleFirstImageResolved,
      ),
    );
  }

  Future<void> _primePendingImages(int generation) async {
    final items = _pendingItems;
    if (items == null || items.isEmpty) {
      return;
    }
    final displaySize = _carouselDisplaySize(context, preferredItems: items);
    await Future.wait<void>(
      items.map((item) => _resolveImage(item, displaySize)),
    );
    if (!mounted || generation != _pendingGeneration) {
      return;
    }
    if (items.length <= 1 || !widget.isActive) {
      _commitPendingItems();
    }
  }

  Future<void> _resolveImage(
    ForumHomeCarouselItem item,
    Size expectedDisplaySize,
  ) async {
    final spec = const ForumChromeImageAdapter().carouselImage(item.imageUrl);
    if (spec == null) {
      return;
    }
    try {
      await ref
          .read(forumImagePrecacheServiceProvider)
          .precacheDecoded(
            context: context,
            spec: spec,
            expectedDisplaySize: expectedDisplaySize,
          );
    } catch (_) {
      return;
    }
  }

  Size _carouselDisplaySize(
    BuildContext context, {
    List<ForumHomeCarouselItem>? preferredItems,
  }) {
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final width = (mediaWidth - 32).clamp(1, double.infinity).toDouble();
    final ratio =
        _aspectRatioFor(preferredItems ?? _displayedItems) ??
        _displayedAspectRatio;
    final aspectRatio =
        ratio ?? ForumHomeCarouselDimensionResolver.fallbackAspectRatio;
    return Size(
      width,
      (width / aspectRatio).clamp(0, ForumHomeCarousel.maxHeight),
    );
  }

  void _handleFirstImageResolved(
    int generation,
    ForumHomeCarouselItem item,
    Size decodedSize,
  ) {
    if (generation != _displayGeneration || _displayedItems.isEmpty) {
      return;
    }
    final first = _displayedItems.first;
    if (first.imageUrl != item.imageUrl || first.targetUrl != item.targetUrl) {
      return;
    }
    final aspectRatio = decodedSize.width / decodedSize.height;
    if (!_isValidAspectRatio(aspectRatio) ||
        (_displayedAspectRatio != null &&
            (_displayedAspectRatio! - aspectRatio).abs() < 0.0001)) {
      return;
    }
    setState(() {
      _displayedAspectRatio = aspectRatio;
    });
  }

  void _handlePageChanged(int index, CarouselPageChangedReason reason) {
    _currentIndex = index;
    _applyPendingItemsIfPossible();
  }

  void _applyPendingItemsIfPossible() {
    final pending = _pendingItems;
    if (pending == null || pending.isEmpty) {
      return;
    }
    if (!widget.isActive || pending.length <= 1) {
      _commitPendingItems();
      return;
    }
    final lastIndex = _displayedItems.isEmpty ? 0 : _displayedItems.length - 1;
    if (_currentIndex >= lastIndex) {
      _commitPendingItems();
    }
  }

  void _commitPendingItems() {
    final pending = _pendingItems;
    if (pending == null) {
      return;
    }
    setState(() {
      _displayGeneration += 1;
      _displayedItems = pending;
      _displayedSignature = _pendingSignature;
      _displayedAspectRatio = _aspectRatioFor(pending) ?? _displayedAspectRatio;
      _pendingItems = null;
      _pendingSignature = null;
      _currentIndex = 0;
    });
    if (_displayedItems.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _carouselController.jumpToPage(0);
      });
    }
  }

  String _signatureFor(List<ForumHomeCarouselItem> items) {
    if (items.isEmpty) {
      return 'empty';
    }
    return items.map((item) => '${item.imageUrl}|${item.targetUrl}').join('||');
  }

  double? _aspectRatioFor(List<ForumHomeCarouselItem> items) {
    if (items.isEmpty) {
      return null;
    }
    final aspectRatio = items.first.aspectRatio;
    return _isValidAspectRatio(aspectRatio) ? aspectRatio : null;
  }

  bool _isValidAspectRatio(double? value) {
    return value != null && value.isFinite && value > 0;
  }
}

class _ForumHomeCarouselBody extends StatelessWidget {
  const _ForumHomeCarouselBody({
    required this.aspectRatio,
    required this.controller,
    required this.imageReferer,
    required this.imageRequestResolver,
    required this.items,
    required this.isActive,
    required this.onOpen,
    required this.palette,
    required this.onPageChanged,
    required this.displayGeneration,
    required this.onFirstImageResolved,
  });

  final double aspectRatio;
  final CarouselSliderController controller;
  final String imageReferer;
  final ForumImageRequestResolver imageRequestResolver;
  final List<ForumHomeCarouselItem> items;
  final bool isActive;
  final ValueChanged<ForumHomeCarouselItem> onOpen;
  final ForumHomeNativePalette palette;
  final int displayGeneration;
  final void Function(int index, CarouselPageChangedReason reason)
  onPageChanged;
  final void Function(int generation, ForumHomeCarouselItem item, Size size)
  onFirstImageResolved;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 24;
        final carouselHeight = (availableWidth / aspectRatio).clamp(
          0.0,
          ForumHomeCarousel.maxHeight,
        );
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : ForumMediaLoadingStyle.fadeInDuration;
        return AnimatedSize(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              key: const Key('forum-home-carousel'),
              width: double.infinity,
              height: carouselHeight,
              child: CarouselSlider.builder(
                carouselController: controller,
                itemCount: items.length,
                options: CarouselOptions(
                  height: carouselHeight,
                  viewportFraction: 1,
                  // TickerMode alone does not cancel the slider's periodic timer.
                  autoPlay:
                      isActive &&
                      !MediaQuery.disableAnimationsOf(context) &&
                      TickerMode.valuesOf(context).enabled &&
                      items.length > 1,
                  autoPlayInterval: const Duration(seconds: 3),
                  autoPlayAnimationDuration: const Duration(milliseconds: 240),
                  enableInfiniteScroll: items.length > 1,
                  disableCenter: true,
                  onPageChanged: onPageChanged,
                ),
                itemBuilder: (context, index, realIndex) {
                  final item = items[index];
                  final spec = const ForumChromeImageAdapter().carouselImage(
                    item.imageUrl,
                  );
                  return SizedBox.expand(
                    child: Material(
                      color: palette.carouselPlaceholder,
                      child: InkWell(
                        key: Key('forum-home-carousel-item-$index'),
                        onTap: () => onOpen(item),
                        child: CachedLibraryImage(
                          request: spec == null
                              ? null
                              : imageRequestResolver.resolveCacheRequest(spec),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          referer: imageReferer,
                          placeholder: ColoredBox(
                            color: palette.carouselPlaceholder,
                            child: const SizedBox.expand(),
                          ),
                          errorPlaceholder: ColoredBox(
                            color: palette.carouselPlaceholder,
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                          fadeInDuration: duration,
                          onImageResolved: index == 0
                              ? (size) => onFirstImageResolved(
                                  displayGeneration,
                                  item,
                                  size,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class ForumHomeSectionCard extends StatelessWidget {
  const ForumHomeSectionCard({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.children,
    required this.isCollapsed,
    required this.onToggle,
  });

  final String sectionKey;
  final String title;
  final List<Widget> children;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final palette = ForumHomeNativePalette.resolve(theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            key: Key('forum-section-title-$sectionKey'),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: Key('forum-section-toggle-$sectionKey'),
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: eInk
                              ? scheme.onSurface
                              : palette.sectionAccent,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: palette.sectionHeadingText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _ForumHomeSectionIndicator(
                        sectionKey: sectionKey,
                        isCollapsed: isCollapsed,
                        color: eInk
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppLayoutTokens.motionDuration(context),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppLayoutTokens.motionDuration(context),
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
              child: isCollapsed
                  ? const SizedBox.shrink(
                      key: ValueKey('forum-home-section-collapsed'),
                    )
                  : Padding(
                      key: ValueKey('forum-home-section-frame-$sectionKey'),
                      padding: const EdgeInsets.only(top: 4),
                      child: DecoratedBox(
                        key: ValueKey(
                          'forum-home-section-expanded-$sectionKey',
                        ),
                        decoration: BoxDecoration(
                          color: eInk
                              ? scheme.surface
                              : palette.sectionCardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: eInk
                                ? AppTheme.eInkBorderColor(scheme.brightness)
                                : palette.sectionCardBorder,
                            width: eInk ? 1 : 0.75,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumHomeSectionIndicator extends StatelessWidget {
  const _ForumHomeSectionIndicator({
    required this.sectionKey,
    required this.isCollapsed,
    required this.color,
  });

  final String sectionKey;
  final bool isCollapsed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isCollapsed ? -0.25 : 0,
      duration: AppLayoutTokens.motionDuration(context),
      curve: Curves.easeOutCubic,
      child: Icon(
        Icons.expand_more,
        key: Key('forum-section-indicator-$sectionKey'),
        size: 20,
        color: color,
      ),
    );
  }
}

class ForumHomeForumRow extends StatelessWidget {
  const ForumHomeForumRow({
    super.key,
    required this.title,
    required this.description,
    required this.todayPosts,
    required this.todayLabel,
    required this.isLast,
    required this.onTap,
  });

  final String title;
  final String description;
  final int? todayPosts;
  final String todayLabel;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final palette = ForumHomeNativePalette.resolve(theme);
    final textTheme = theme.textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: textTheme.titleMedium?.copyWith(
                              color: palette.forumTitle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TodayBadge(
                          todayPosts: todayPosts,
                          label: todayLabel,
                          textTheme: textTheme,
                          palette: palette,
                        ),
                      ],
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Divider(
                    height: 1,
                    thickness: 0.75,
                    color: eInk
                        ? AppTheme.eInkBorderColor(scheme.brightness)
                              .withValues(alpha: 0.45)
                        : palette.rowDivider,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge({
    required this.todayPosts,
    required this.label,
    required this.textTheme,
    required this.palette,
  });

  final int? todayPosts;
  final String label;
  final TextTheme textTheme;
  final ForumHomeNativePalette palette;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eInk = EInkModeScope.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedSwitcher(
          duration: AppLayoutTokens.motionDuration(context),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.vertical,
                alignment: const Alignment(-1, -1),
                child: child,
              ),
            );
          },
          child: todayPosts == null
              ? const SizedBox(key: ValueKey('forum-home-today-badge-empty'))
              : DecoratedBox(
                  key: const ValueKey('forum-home-today-badge-filled'),
                  decoration: BoxDecoration(
                    color: eInk
                        ? Colors.transparent
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedFlipCounter(
                          value: todayPosts!,
                          duration: AppLayoutTokens.motionDuration(context),
                          textStyle: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

@immutable
class ForumHomeNativePalette {
  const ForumHomeNativePalette({
    required this.background,
    required this.carouselPlaceholder,
    required this.sectionHeaderBackground,
    required this.sectionHeaderForeground,
    required this.sectionBodyBackground,
    required this.sectionAccent,
    required this.sectionHeadingText,
    required this.sectionCardBackground,
    required this.sectionCardBorder,
    required this.forumTitle,
    required this.descriptionText,
    required this.todayText,
    required this.rowDivider,
  });

  final Color background;
  final Color carouselPlaceholder;
  final Color sectionHeaderBackground;
  final Color sectionHeaderForeground;
  final Color sectionBodyBackground;
  final Color sectionAccent;
  final Color sectionHeadingText;
  final Color sectionCardBackground;
  final Color sectionCardBorder;
  final Color forumTitle;
  final Color descriptionText;
  final Color todayText;
  final Color rowDivider;

  static ForumHomeNativePalette resolve(ThemeData theme) {
    final scheme = theme.colorScheme;
    final native = theme.y300NativeContent;
    if (scheme.brightness == Brightness.dark) {
      return ForumHomeNativePalette(
        background: theme.scaffoldBackgroundColor,
        carouselPlaceholder: scheme.surfaceContainerHighest,
        sectionHeaderBackground: scheme.secondaryContainer,
        sectionHeaderForeground: scheme.onSecondaryContainer,
        sectionBodyBackground: scheme.surfaceContainer,
        sectionAccent: scheme.primary,
        sectionHeadingText: scheme.onSurface,
        sectionCardBackground: scheme.surfaceContainer,
        sectionCardBorder: scheme.outlineVariant.withValues(alpha: 0.35),
        forumTitle: scheme.primary,
        descriptionText: scheme.onSurfaceVariant,
        todayText: scheme.primary,
        rowDivider: scheme.outlineVariant.withValues(alpha: 0.62),
      );
    }
    return ForumHomeNativePalette(
      background: native.background,
      carouselPlaceholder:
          Color.lerp(native.accent, native.background, 0.8) ?? native.card,
      sectionHeaderBackground: native.accent,
      sectionHeaderForeground: native.onAccent,
      sectionBodyBackground: native.card,
      sectionAccent: native.accent,
      sectionHeadingText: scheme.onSurface,
      sectionCardBackground: scheme.surfaceContainerLowest,
      sectionCardBorder: scheme.outlineVariant.withValues(alpha: 0.45),
      forumTitle: native.title,
      descriptionText: native.neutralText,
      todayText: Colors.redAccent.shade200,
      rowDivider: scheme.outlineVariant.withValues(alpha: 0.58),
    );
  }
}
