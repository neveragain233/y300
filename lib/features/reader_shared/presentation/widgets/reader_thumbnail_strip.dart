import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_chrome_palette.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/presentation/services/reader_image_session_store.dart';
import 'package:y300/l10n/app_localizations.dart';

/// 引擎向能力提供的单张缩略图/预览构建参数。
///
/// 缩略图与正文共用当前阅读会话的图片绑定和缓存请求，能力只需决定使用哪种
/// 展示方式（裁切、占位、失败态），不得另建缓存或网络通道。
class ReaderThumbnailImageSpec {
  const ReaderThumbnailImageSpec({
    required this.item,
    required this.index,
    required this.sessionBinding,
    required this.expectedDisplaySize,
    required this.preview,
  });

  final ContinuousImageItem item;

  /// 图片在章节内的逻辑序号，也是页码来源。
  final int index;
  final ReaderImageSessionBinding sessionBinding;
  final Size expectedDisplaySize;

  /// 中央候选大图；false 表示胶片条内的小图。
  final bool preview;
}

typedef ReaderThumbnailImageBuilder = Widget Function(
  BuildContext context,
  ReaderThumbnailImageSpec spec,
);

/// 引擎持有的缩略图条只读状态和回调。
///
/// 候选预览只改变这里的索引，不写阅读进度、不标已读；真正跳页只由 [onSubmit]
/// 触发一次，并继续走引擎现有的 seek/commit 链。
class ReaderThumbnailStripSpec {
  const ReaderThumbnailStripSpec({
    required this.ownerId,
    required this.items,
    required this.currentIndex,
    required this.previewIndex,
    required this.reversed,
    required this.enabled,
    this.active = true,
    required this.sessionBindingFor,
    required this.onPreview,
    required this.onSubmit,
    required this.onCancel,
  });

  final String ownerId;
  final List<ContinuousImageItem> items;

  /// 已确认的当前页。
  final int currentIndex;

  /// 拖动中的中央候选；null 表示没有未提交预览。
  final int? previewIndex;

  /// 右到左阅读时反转视觉顺序，页码仍使用逻辑序号。
  final bool reversed;

  final bool enabled;

  /// 底栏处于可见或退出动画期间为 true；完全归位后置 false 卸载缩略图解码列表
  /// 并保持槽位高度恒定，避免底栏滑入/滑出时高度跳变。
  final bool active;
  final ReaderImageSessionBinding Function(ContinuousImageItem item)
  sessionBindingFor;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onSubmit;
  final VoidCallback onCancel;
}

/// 苹果照片浏览器式的章内缩略图胶片条。
///
/// 列表本身只负责把可见缩略图交给共享图片会话；拖动时中央项即候选页，松手后
/// 吸附并交给引擎提交。列表使用无惯性物理，避免松手后的滚动继续改变目标。
class ReaderThumbnailStrip extends StatefulWidget {
  const ReaderThumbnailStrip({
    super.key,
    required this.spec,
    required this.imageBuilder,
  });

  final ReaderThumbnailStripSpec spec;
  final ReaderThumbnailImageBuilder imageBuilder;

  static const Key listKey = Key('reader-thumbnail-strip-list');
  static const Key previewKey = Key('reader-thumbnail-strip-preview');
  static const Key pageLabelKey = Key('reader-thumbnail-strip-page-label');
  static const Key hiddenKey = Key('reader-thumbnail-strip-hidden');

  static Key itemKey(int logicalIndex) =>
      ValueKey<String>('reader-thumbnail-strip-item-$logicalIndex');

  @override
  State<ReaderThumbnailStrip> createState() => _ReaderThumbnailStripState();
}

class _ReaderThumbnailStripState extends State<ReaderThumbnailStrip> {
  static const double _slotExtent = 64;
  static const double _thumbWidth = 52;
  static const double _thumbHeight = 72;
  static const double _slotHeight = 84;
  static const Duration _snapDuration = Duration(milliseconds: 160);
  static const Duration _selectionDuration = Duration(milliseconds: 120);

  final ScrollController _controller = ScrollController(
    keepScrollOffset: false,
  );
  double? _viewportWidth;
  bool _isDragging = false;
  int? _candidateIndex;
  double _dragStartOffset = 0;
  double _dragDelta = 0;
  int _centerGeneration = 0;

  int get _itemCount => widget.spec.items.length;

  @override
  void didUpdateWidget(covariant ReaderThumbnailStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.spec;
    final next = widget.spec;
    final contentChanged =
        previous.ownerId != next.ownerId ||
        previous.items.length != next.items.length;
    final directionChanged = previous.reversed != next.reversed;
    if (previous.active && !next.active) {
      // 完全归位后清理离屏列表并取消残留拖动，同时清空旧视口宽度以便下次展开居中。
      _isDragging = false;
      _candidateIndex = null;
      _viewportWidth = null;
      return;
    }
    if (!previous.active && next.active) {
      _viewportWidth = null;
      _scheduleCenter(next.currentIndex, animate: false);
      return;
    }
    if (contentChanged || directionChanged) {
      // 换章/换方向后旧候选与旧滚动偏移都不再属于同一序列。
      _isDragging = false;
      _candidateIndex = null;
      _scheduleCenter(next.currentIndex, animate: false);
      return;
    }
    if (_isDragging &&
        previous.previewIndex != null &&
        next.previewIndex == null) {
      // 引擎因布局/模式等变化清除了未提交候选，本地拖动同时作废。
      _isDragging = false;
      _candidateIndex = null;
      _scheduleCenter(next.currentIndex, animate: false);
      return;
    }
    if (!next.enabled && (_isDragging || _candidateIndex != null)) {
      _isDragging = false;
      _candidateIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.spec.onCancel();
      });
      _scheduleCenter(next.currentIndex, animate: false);
      return;
    }
    if (!_isDragging && previous.currentIndex != next.currentIndex) {
      _scheduleCenter(next.currentIndex, animate: !_reduceMotion());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_itemCount <= 1) {
      return const SizedBox.shrink(key: ReaderThumbnailStrip.hiddenKey);
    }
    final l10n = AppLocalizations.of(context);
    final palette = const ReaderChromePaletteResolver().resolve(
      Theme.of(context),
    );
    final selectedIndex = _selectedIndex;
    final previewIndex = _isDragging
        ? _candidateIndex
        : widget.spec.previewIndex;
    final pageLabel = l10n.readerThumbnailPageSemantics(
      selectedIndex + 1,
      _itemCount,
    );
    final labelStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: palette.chromeForeground);
    return AbsorbPointer(
      absorbing: !widget.spec.enabled,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        customSemanticsActions: widget.spec.enabled
            ? <CustomSemanticsAction, VoidCallback>{
                CustomSemanticsAction(
                  label: l10n.forumDisplayPreviousPage,
                ): () =>
                    _selectIndex(selectedIndex - 1),
                CustomSemanticsAction(label: l10n.forumDisplayNextPage): () =>
                    _selectIndex(selectedIndex + 1),
              }
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (previewIndex != null)
              _buildPreview(context, previewIndex, pageLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Semantics(
                    label: pageLabel,
                    excludeSemantics: true,
                    child: Text(
                      '${selectedIndex + 1} / $_itemCount',
                      key: ReaderThumbnailStrip.pageLabelKey,
                      style: labelStyle,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _slotHeight,
              child: !widget.spec.active
                  ? const SizedBox.expand()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = constraints.maxWidth;
                        _syncViewport(viewportWidth);
                        return Listener(
                          // 系统取消指针时拖动手势只会收到 end；先在这里作废候选，
                          // 避免把被打断的浏览提交成跳页。
                          onPointerCancel: (_) => _cancelScrubByPointer(),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            // Scrubbing starts at touch-down instead of discarding
                            // the first slop distance, like a photo browser.
                            dragStartBehavior: DragStartBehavior.down,
                            onHorizontalDragStart: _handleDragStart,
                            onHorizontalDragUpdate: _handleDragUpdate,
                            onHorizontalDragEnd: (_) => _finishScrub(),
                            onHorizontalDragCancel: _cancelScrubByPointer,
                            child: ListView.builder(
                              key: ReaderThumbnailStrip.listKey,
                              controller: _controller,
                              scrollDirection: Axis.horizontal,
                              itemExtent: _slotExtent,
                              // 手势由外层拖动识别器统一驱动，列表本身不参与滚动竞争。
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: math.max(
                                  0.0,
                                  viewportWidth / 2 - _slotExtent / 2,
                                ),
                              ),
                              itemCount: _itemCount,
                              itemBuilder: (context, physicalIndex) {
                                final logicalIndex = widget.spec.reversed
                                    ? _itemCount - 1 - physicalIndex
                                    : physicalIndex;
                                return _buildThumbnail(
                                  context,
                                  logicalIndex,
                                  selected: logicalIndex == selectedIndex,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, int index, String pageLabel) {
    final size = _previewSize(context);
    final item = widget.spec.items[index];
    return Padding(
      key: ReaderThumbnailStrip.previewKey,
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: Semantics(
          label: pageLabel,
          image: true,
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: widget.imageBuilder(
                context,
                ReaderThumbnailImageSpec(
                  item: item,
                  index: index,
                  sessionBinding: widget.spec.sessionBindingFor(item),
                  expectedDisplaySize: size,
                  preview: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    int logicalIndex, {
    required bool selected,
  }) {
    final l10n = AppLocalizations.of(context);
    final palette = const ReaderChromePaletteResolver().resolve(
      Theme.of(context),
    );
    final reduceMotion = _reduceMotion();
    final item = widget.spec.items[logicalIndex];
    return Semantics(
      key: ReaderThumbnailStrip.itemKey(logicalIndex),
      button: true,
      selected: selected,
      label: l10n.readerThumbnailPageSemantics(logicalIndex + 1, _itemCount),
      customSemanticsActions: widget.spec.enabled
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: l10n.forumDisplayPreviousPage): () =>
                  _selectIndex(logicalIndex - 1),
              CustomSemanticsAction(label: l10n.forumDisplayNextPage): () =>
                  _selectIndex(logicalIndex + 1),
            }
          : null,
      onTap: widget.spec.enabled ? () => _selectIndex(logicalIndex) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.spec.enabled ? () => _selectIndex(logicalIndex) : null,
          child: Center(
            child: AnimatedScale(
              scale: selected && !reduceMotion ? 1.08 : 1,
              duration: reduceMotion ? Duration.zero : _selectionDuration,
              curve: Curves.easeOutCubic,
              child: Container(
                width: _thumbWidth,
                height: _thumbHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : palette.chromeForeground.withValues(alpha: 0.18),
                    width: selected ? 2.4 : 1,
                  ),
                ),
                child: widget.imageBuilder(
                  context,
                  ReaderThumbnailImageSpec(
                    item: item,
                    index: logicalIndex,
                    sessionBinding: widget.spec.sessionBindingFor(item),
                    expectedDisplaySize: const Size(_thumbWidth, _thumbHeight),
                    preview: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _selectedIndex {
    final count = _itemCount;
    final raw = _isDragging
        ? _candidateIndex
        : (widget.spec.previewIndex ?? widget.spec.currentIndex);
    return (raw ?? widget.spec.currentIndex).clamp(0, count - 1).toInt();
  }

  int _logicalIndexAt(double pixels) {
    final physical = (pixels / _slotExtent)
        .round()
        .clamp(0, _itemCount - 1)
        .toInt();
    return widget.spec.reversed ? _itemCount - 1 - physical : physical;
  }

  double _offsetForLogical(int index) {
    final logical = index.clamp(0, _itemCount - 1).toInt();
    final physical = widget.spec.reversed ? _itemCount - 1 - logical : logical;
    return physical * _slotExtent;
  }

  void _handleDragStart(DragStartDetails _) {
    if (!widget.spec.enabled || !_controller.hasClients) {
      return;
    }
    _dragStartOffset = _controller.offset;
    _dragDelta = 0;
    final candidate = _logicalIndexAt(_dragStartOffset);
    setState(() {
      _isDragging = true;
      _candidateIndex = candidate;
    });
    widget.spec.onPreview(candidate);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || !_controller.hasClients) {
      return;
    }
    _dragDelta -= details.delta.dx;
    final position = _controller.position;
    final target = (_dragStartOffset + _dragDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _controller.jumpTo(target);
    _updateScrub(target);
  }

  void _updateScrub(double pixels) {
    final candidate = _logicalIndexAt(pixels);
    if (candidate == _candidateIndex) {
      return;
    }
    setState(() => _candidateIndex = candidate);
    widget.spec.onPreview(candidate);
  }

  void _finishScrub() {
    final candidate = _candidateIndex;
    final current = widget.spec.currentIndex;
    setState(() {
      _isDragging = false;
      _candidateIndex = null;
    });
    if (candidate == null) {
      return;
    }
    _scheduleCenter(candidate, animate: !_reduceMotion());
    if (candidate == current) {
      widget.spec.onCancel();
      return;
    }
    // 松手只提交一次；吸附动画不会再次触发候选或提交。
    widget.spec.onSubmit(candidate);
  }

  void _cancelScrubByPointer() {
    if (!_isDragging) {
      return;
    }
    final current = widget.spec.currentIndex;
    setState(() {
      _isDragging = false;
      _candidateIndex = null;
    });
    _scheduleCenter(current, animate: !_reduceMotion());
    widget.spec.onCancel();
  }

  void _selectIndex(int index) {
    if (!widget.spec.enabled) {
      return;
    }
    final target = index.clamp(0, _itemCount - 1).toInt();
    setState(() {
      _isDragging = false;
      _candidateIndex = null;
    });
    _scheduleCenter(target, animate: !_reduceMotion());
    if (target == widget.spec.currentIndex) {
      widget.spec.onCancel();
      return;
    }
    widget.spec.onSubmit(target);
  }

  void _syncViewport(double width) {
    if (_viewportWidth == width) {
      return;
    }
    final hadLayout = _viewportWidth != null;
    _viewportWidth = width;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!hadLayout) {
        // 打开时只居中，不产生候选或跳页。
        _centerIndex(widget.spec.currentIndex, animate: false);
        return;
      }
      if (_isDragging ||
          _candidateIndex != null ||
          widget.spec.previewIndex != null) {
        _isDragging = false;
        _candidateIndex = null;
        widget.spec.onCancel();
      }
      _centerIndex(widget.spec.currentIndex, animate: false);
    });
  }

  void _scheduleCenter(int index, {required bool animate}) {
    final generation = ++_centerGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _centerGeneration) {
        return;
      }
      _centerIndex(index, animate: animate);
    });
  }

  void _centerIndex(int index, {required bool animate}) {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final target = _offsetForLogical(index)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (animate && !_reduceMotion()) {
      unawaited(
        _controller.animateTo(
          target,
          duration: _snapDuration,
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    _controller.jumpTo(target);
  }

  Size _previewSize(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    var height = media.height * 0.2;
    if (media.height < 700 || textScale > 1.2) {
      // 矮窗口或大字号先压缩预览，保留缩略图和页码操作。
      height = media.height * 0.11;
    }
    final availableWidth = _viewportWidth ?? media.width;
    return Size(
      math.min(availableWidth * 0.66, 220.0),
      height.clamp(44.0, 150.0).toDouble(),
    );
  }

  bool _reduceMotion() => AppMotion.reduceMotion(context);
}
