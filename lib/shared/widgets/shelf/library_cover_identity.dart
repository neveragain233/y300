import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:y300/shared/utils/wcag_color_contrast.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

/// 排版封面的稳定身份：来源类型＋作品编号。
///
/// 身份只用于派生颜色，不参与路由或存储。同一作品在网格、列表、详情、
/// 重启和明暗切换下必须得到同一色相，因此这里不使用 [String.hashCode]，
/// 也不用每次重建都能变化的随机值。
@immutable
class LibraryCoverIdentity {
  const LibraryCoverIdentity({required this.source, required this.workId});

  final String source;
  final String workId;

  String get key => '$source/$workId';

  /// FNV-1a 32 位散列。固定算法与固定输入得到固定色相。
  int get hash => LibraryCoverIdentity.hashOf(key);

  static int hashOf(String value) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// 优先使用封面资产里的归属，使收藏页与模块书架、详情使用同一身份；
  /// 没有封面资产时退回当前模块与作品编号。
  static LibraryCoverIdentity resolve({
    required LibraryModuleKey moduleKey,
    required String workId,
    LibraryCoverAssetRef? coverAsset,
  }) {
    final assetId = coverAsset?.assetId;
    final owner = assetId == null
        ? null
        : LibraryCoverAssetIds.ownerOf(assetId);
    if (owner != null) {
      return LibraryCoverIdentity(
        source: owner.ownerType,
        workId: owner.ownerId,
      );
    }
    return LibraryCoverIdentity(source: moduleKey.name, workId: workId);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryCoverIdentity &&
        other.source == source &&
        other.workId == workId;
  }

  @override
  int get hashCode => Object.hash(source, workId);
}

/// 排版封面实际使用的颜色。
@immutable
class LibraryCoverColors {
  const LibraryCoverColors({
    required this.background,
    required this.foreground,
    required this.fiber,
  });

  final Color background;
  final Color foreground;

  /// 纸纤维与细线的低对比颜色。
  final Color fiber;
}

/// 由身份色相和当前主题解析排版封面配色。
///
/// 浅色主题取低饱和、高亮度；深色主题保持同一色相并降低亮度，最后混入少量
/// 主题表面色。文字颜色按实际底色对比度选择，保证书名与作者可读。
class LibraryCoverPaletteResolver {
  const LibraryCoverPaletteResolver();

  static const Color _ink = Color(0xFF23221E);
  static const Color _paperInk = Color(0xFFF6F2E8);

  LibraryCoverColors resolve({
    required ThemeData theme,
    required LibraryCoverIdentity identity,
  }) {
    final hash = identity.hash;
    final hue = (hash % 360).toDouble();
    final saturationStep = ((hash >> 11) % 100) / 100;
    final lightnessStep = ((hash >> 19) % 100) / 100;
    final isDark = theme.brightness == Brightness.dark;
    final saturation = isDark
        ? 0.14 + saturationStep * 0.12
        : 0.16 + saturationStep * 0.14;
    final lightness = isDark
        ? 0.20 + lightnessStep * 0.08
        : 0.84 + lightnessStep * 0.08;
    final hueColor = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
    final background = Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: 0.10),
      hueColor,
    );
    final foreground =
        WcagColorContrast.ratio(_ink, background) >=
            WcagColorContrast.ratio(_paperInk, background)
        ? _ink
        : _paperInk;
    return LibraryCoverColors(
      background: background,
      foreground: foreground,
      fiber: foreground.withValues(alpha: isDark ? 0.10 : 0.07),
    );
  }

  /// WCAG 相对亮度对比度。
  static double contrastRatio(Color first, Color second) =>
      WcagColorContrast.ratio(first, second);
}
