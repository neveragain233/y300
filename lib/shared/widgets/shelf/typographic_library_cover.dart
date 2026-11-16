import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/shelf/library_cover_identity.dart';

enum LibraryCoverLayout { grid, detail, list }

/// 长期无封面作品的排版封面。
///
/// 网格与详情复用同一色相与文字排版；列表只保留身份色和来源图标（未知来源
/// 退回首字水印），标题继续由行内文字承担。纸面细节只画低对比细线，不引入
/// 图片、字体或第三方依赖。
class TypographicLibraryCover extends StatelessWidget {
  const TypographicLibraryCover({
    super.key,
    required this.identity,
    required this.title,
    this.author,
    this.layout = LibraryCoverLayout.grid,
    this.trailingBadge,
    this.reserveTopBadgeSpace = false,
  });

  final LibraryCoverIdentity identity;
  final String title;
  final String? author;
  final LibraryCoverLayout layout;
  final Widget? trailingBadge;

  /// 卡片左上角有未读角标时，作者行让出固定空间，避免与角标重叠。
  final bool reserveTopBadgeSpace;

  static const int _titleMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = const LibraryCoverPaletteResolver().resolve(
      theme: theme,
      identity: identity,
    );
    final background = switch (layout) {
      LibraryCoverLayout.list => _listWatermark(theme, colors),
      LibraryCoverLayout.grid => _textCover(
        theme,
        colors,
        titleStyle: theme.textTheme.bodySmall,
        authorStyle: theme.textTheme.labelSmall,
        padding: EdgeInsets.fromLTRB(8, reserveTopBadgeSpace ? 38 : 8, 8, 10),
      ),
      LibraryCoverLayout.detail => _textCover(
        theme,
        colors,
        titleStyle: theme.textTheme.bodySmall,
        authorStyle: theme.textTheme.labelSmall,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      ),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          key: const Key('typographic-cover-background'),
          color: colors.background,
        ),
        if (layout != LibraryCoverLayout.list)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TypographicPaperPainter(
                  seed: identity.hash,
                  fiber: colors.fiber,
                ),
              ),
            ),
          ),
        background,
      ],
    );
  }

  Widget _listWatermark(ThemeData theme, LibraryCoverColors colors) {
    final icon = _sourceIcon(identity.source);
    if (icon != null) {
      return ExcludeSemantics(
        child: Center(
          child: Icon(
            icon,
            key: const Key('typographic-cover-source-icon'),
            size: 22,
            color: colors.foreground.withValues(alpha: 0.88),
          ),
        ),
      );
    }
    final trimmed = title.trim();
    final mark = trimmed.isEmpty ? null : trimmed.characters.first;
    return Center(
      child: mark == null
          ? Icon(
              Icons.menu_book_outlined,
              size: 22,
              color: colors.foreground.withValues(alpha: 0.85),
            )
          : ExcludeSemantics(
              child: Text(
                mark,
                key: const Key('typographic-cover-watermark'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.foreground.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  /// 列表只保留来源图标；未知来源退回首字水印。
  static IconData? _sourceIcon(String source) {
    return switch (source) {
      'comic' => Icons.photo_library_outlined,
      'novel' => Icons.menu_book_outlined,
      _ => null,
    };
  }

  Widget _textCover(
    ThemeData theme,
    LibraryCoverColors colors, {
    required TextStyle? titleStyle,
    required TextStyle? authorStyle,
    required EdgeInsets padding,
  }) {
    final authorText = author?.trim();
    final badge = trailingBadge;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (authorText != null && authorText.isNotEmpty)
            Text(
              authorText,
              key: const Key('typographic-cover-author'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: authorStyle?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  key: const Key('typographic-cover-title'),
                  maxLines: _titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 6), badge],
            ],
          ),
        ],
      ),
    );
  }
}

/// 纸面细线。相同尺寸与种子只绘制一次，滚动回收时复用同一张 Picture。
class _TypographicPaperPainter extends CustomPainter {
  _TypographicPaperPainter({required this.seed, required this.fiber});

  final int seed;
  final Color fiber;

  @override
  void paint(Canvas canvas, Size size) {
    final picture = _PaperPictureCache.instance.pictureFor(
      size: size,
      seed: seed,
      fiber: fiber,
    );
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _TypographicPaperPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.fiber != fiber;
  }
}

@immutable
class _PaperKey {
  const _PaperKey({
    required this.width,
    required this.height,
    required this.seed,
    required this.fiber,
  });

  final double width;
  final double height;
  final int seed;
  final int fiber;

  @override
  bool operator ==(Object other) {
    return other is _PaperKey &&
        other.width == width &&
        other.height == height &&
        other.seed == seed &&
        other.fiber == fiber;
  }

  @override
  int get hashCode => Object.hash(width, height, seed, fiber);
}

class _PaperPictureCache {
  _PaperPictureCache._();

  static final _PaperPictureCache instance = _PaperPictureCache._();
  static const int _maxEntries = 24;

  final Map<_PaperKey, ui.Picture> _pictures = <_PaperKey, ui.Picture>{};

  ui.Picture pictureFor({
    required Size size,
    required int seed,
    required Color fiber,
  }) {
    final key = _PaperKey(
      width: size.width,
      height: size.height,
      seed: seed,
      fiber: fiber.toARGB32(),
    );
    final cached = _pictures.remove(key);
    if (cached != null) {
      _pictures[key] = cached;
      return cached;
    }
    final picture = _record(size: size, seed: seed, fiber: fiber);
    _pictures[key] = picture;
    while (_pictures.length > _maxEntries) {
      final oldest = _pictures.keys.first;
      _pictures.remove(oldest)?.dispose();
    }
    return picture;
  }

  ui.Picture _record({
    required Size size,
    required int seed,
    required Color fiber,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(seed);
    final paint = Paint()
      ..color = fiber
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) {
      return recorder.endRecording();
    }
    final fibers = 9 + random.nextInt(4);
    for (var index = 0; index < fibers; index += 1) {
      final y = 6 + random.nextDouble() * (height - 12);
      final x = random.nextDouble() * width * 0.35;
      final length = 8 + random.nextDouble() * width * 0.45;
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + length, width), y),
        paint,
      );
    }
    // 顶部一条极淡的横线与左右短竖线形成纸边感，避免整块纯色。
    canvas.drawLine(
      Offset(width * 0.16, height * 0.16),
      Offset(width * 0.84, height * 0.16),
      paint,
    );
    canvas.drawLine(
      Offset(width - 5, height * 0.3),
      Offset(width - 5, height * 0.3 + height * 0.18),
      paint,
    );
    return recorder.endRecording();
  }
}
