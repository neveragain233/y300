import 'dart:collection';
import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:y300/app/settings/app_edition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:y300/core/media/image_display_provider.dart';
import 'package:y300/core/media/image_downscale_policy.dart';
import 'package:y300/features/image_loading/data/app_image_providers.dart';
import 'package:y300/features/image_loading/domain/app_image_source.dart';
import 'package:y300/shared/widgets/forum_default_avatar.dart';

/// 统一图片显示控件——缓存层对外的唯一入口。
///
/// 核心特性：**自食其力**。加载顺序为
///   本地文件（资产/已预热） → 网络（URL-keyed 磁盘+内存缓存）。
/// 它**不依赖任何后台预热队列**：即使队列没把封面下好，只要有网络 URL，控件
/// 自己就会去取并缓存。这正是修复“快滑看不到封面、停下才加载”的关键。
///
/// 网络分支用 `CachedNetworkImageProvider` + 共享的 `flutter_cache_manager`
/// 实例，按规范化 URL 做 key（同一张图同一份缓存）。缓存层始终保存原文件，
/// 显示层再通过 [ResizeImage] 降采样，避免缓存库额外解析并重编码原图。
/// 本地文件存在性的有界同步缓存。
///
/// 滚动时同一个路径会在每帧 build 里被查询，直接 `File.existsSync()` 会
/// 反复做磁盘 stat；这里记住最近 512 个结果，首次之后不再触碰文件系统。
final class _LocalFileExistenceCache {
  const _LocalFileExistenceCache._();

  static const int _maxEntries = 512;
  static final LinkedHashMap<String, bool> _cache =
      LinkedHashMap<String, bool>();

  static bool check(String path) {
    final cached = _cache.remove(path);
    if (cached != null) {
      _cache[path] = cached;
      return cached;
    }
    final exists = io.File(path).existsSync();
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[path] = exists;
    return exists;
  }
}

class AppImage extends ConsumerStatefulWidget {
  const AppImage({
    super.key,
    this.localPath,
    this.networkSource,
    required this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.downscalePolicy = const WidthBoundImageDownscalePolicy(),
    required this.placeholder,
    this.errorPlaceholder,
    this.onImageFailed,
  });

  /// 本地文件路径（资产层提供或预热已落地）。存在则优先展示，不再走网络。
  final String? localPath;

  /// 网络兜底来源。本地缺失时由它自食其力地加载并缓存。
  final NetworkAppImageSource? networkSource;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// `BoxFit.cover` 下的对齐点（焦点选区）。默认居中；自定义封面可传入
  /// 由焦点坐标映射出的 [Alignment]，让宽幅图对齐到合适区域而不裁剪原图。
  final AlignmentGeometry alignment;
  final ImageDownscalePolicy downscalePolicy;
  final Widget placeholder;
  final Widget? errorPlaceholder;

  final VoidCallback? onImageFailed;

  @override
  ConsumerState<AppImage> createState() => _AppImageState();
}

class _AppImageState extends ConsumerState<AppImage> {
  /// 本帧显示框尺寸与 DPR，由 build 时的 LayoutBuilder 写入，供降采样解析复用。
  Size _displaySize = Size.zero;
  double _devicePixelRatio = 1;
  bool _networkResolved = false;
  String? _reportedFailureIdentity;

  /// 墨水屏变体用 Rec.709 灰度矩阵合成位图，避免彩色图片在灰阶面板上
  /// 出现不可预期的明度；普通构建不增加合成层。
  static const List<double> _eInkGrayscale = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  Widget _applyEInkFilter(Widget child) {
    if (!AppEdition.isEInk) {
      return child;
    }
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_eInkGrayscale),
      child: child,
    );
  }

  @override
  void didUpdateWidget(covariant AppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        !_hasSameNetworkRequestIdentity(
          oldWidget.networkSource,
          widget.networkSource,
        )) {
      _networkResolved = false;
      _reportedFailureIdentity = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _displaySize = Size(
          _finiteOr(widget.width, constraints.maxWidth),
          _finiteOr(widget.height, constraints.maxHeight),
        );
        _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        return _applyEInkFilter(_buildContent(context));
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    // 1) 本地文件优先（资产层 / 预热已落地）：直接读文件，不触发网络。
    final local = widget.localPath?.trim();
    if (local != null && local.isNotEmpty) {
      final file = io.File(local);
      if (_LocalFileExistenceCache.check(file.path)) {
        final fileProvider = FileImage(file);
        // cover 用 cover 感知降采样修复横长竖短图模糊；其它 fit 走宽度优先策略。
        final displayProvider = resolveDownscaledImageProvider(
          base: fileProvider,
          fit: widget.fit,
          displaySize: _displaySize,
          devicePixelRatio: _devicePixelRatio,
          downscalePolicy: widget.downscalePolicy,
        );
        return Image(
          image: displayProvider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            _markImageFailed('file:${file.path}');
            return _effectiveErrorPlaceholder;
          },
        );
      }
    }

    // 2) 网络兜底：自食其力地下载并缓存（URL-keyed，共享 cacheManager）。
    final source = widget.networkSource;
    if (source != null && source.resolvedUrl.isNotEmpty) {
      if (isForumDefaultOrUnsupportedAvatarUrl(source.resolvedUrl)) {
        return _effectiveErrorPlaceholder;
      }
      return _buildNetworkImage(source);
    }

    return widget.placeholder;
  }

  Widget _buildNetworkImage(NetworkAppImageSource source) {
    // Wait for the one application cache manager. Falling back to the plugin's
    // default manager would bypass the shared Cookie/WAF resource transport.
    final cacheManagerAsync = ref.watch(appImageCacheManagerProvider);
    return cacheManagerAsync.when(
      data: (manager) => _buildResolvedNetworkImage(
        source,
        cacheManager: manager.rawCacheManager,
      ),
      loading: () => widget.placeholder,
      error: (error, stackTrace) {
        _markImageFailed('cache-manager:${source.cacheKey}');
        return _effectiveErrorPlaceholder;
      },
    );
  }

  Widget _buildResolvedNetworkImage(
    NetworkAppImageSource source, {
    required BaseCacheManager cacheManager,
  }) {
    final provider = CachedNetworkImageProvider(
      source.resolvedUrl,
      cacheKey: source.cacheKey,
      cacheManager: cacheManager,
      headers: source.referer == null
          ? null
          : <String, String>{'Referer': source.referer!},
    );
    final displayProvider = resolveDownscaledImageProvider(
      base: provider,
      fit: widget.fit,
      displaySize: _displaySize,
      devicePixelRatio: _devicePixelRatio,
      downscalePolicy: widget.downscalePolicy,
    );
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        if (!_networkResolved) widget.placeholder,
        Image(
          image: displayProvider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              _markNetworkResolved();
              return child;
            }
            return const SizedBox.shrink();
          },
          errorBuilder: (context, error, stackTrace) {
            _markNetworkResolved();
            _markImageFailed('net:${source.cacheKey}');
            return _effectiveErrorPlaceholder;
          },
        ),
      ],
    );
  }

  bool _hasSameNetworkRequestIdentity(
    NetworkAppImageSource? previous,
    NetworkAppImageSource? next,
  ) {
    if (previous == null || next == null) {
      return previous == next;
    }
    return previous.resolvedUrl == next.resolvedUrl &&
        previous.cacheKey == next.cacheKey &&
        previous.referer == next.referer;
  }

  double _finiteOr(double? preferred, double fallback) {
    if (preferred != null && preferred.isFinite) {
      return preferred;
    }
    return fallback.isFinite ? fallback : double.nan;
  }

  void _markNetworkResolved() {
    if (_networkResolved) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_networkResolved) {
        setState(() => _networkResolved = true);
      }
    });
  }

  void _markImageFailed(String identity) {
    final callback = widget.onImageFailed;
    if (callback == null || _reportedFailureIdentity == identity) {
      return;
    }
    _reportedFailureIdentity = identity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback();
      }
    });
  }

  Widget get _effectiveErrorPlaceholder =>
      widget.errorPlaceholder ?? widget.placeholder;
}
