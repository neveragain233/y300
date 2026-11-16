import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/media/image_downscale_policy.dart';
import 'package:y300/features/image_loading/domain/app_image_source.dart';
import 'package:y300/features/image_loading/presentation/app_image.dart';
import 'package:y300/features/library_shared/data/providers/library_cover_providers.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/presentation/images/library_cover_image.dart';
import 'package:y300/features/library_shared/presentation/images/library_cover_image_provider.dart';
import 'package:y300/shared/widgets/library_cover_failure_placeholder.dart';

/// 书架/详情共用封面展示：本地文件优先，来源封面兜底。
///
/// 三态语义由调用方配合：
/// - 没有配置任何封面时，调用方直接渲染排版封面，不进入本控件；
/// - 有封面资源但尚未解码时为中性占位；
/// - 资源加载失败时显示可重试的失败态。
class ShelfCoverImage extends ConsumerStatefulWidget {
  const ShelfCoverImage({
    super.key,
    required this.coverKey,
    this.localPath,
    this.remoteUrl,
    this.imageReferer,
    required this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.downscalePolicy = const WidthBoundImageDownscalePolicy(),
    required this.placeholder,
    this.coverAsset,
    this.usage = LibraryCoverUsage.shelf,
    this.failureColor,
    this.compactFailure = false,
  });

  final String coverKey;
  final String? localPath;
  final String? remoteUrl;
  final String? imageReferer;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// `BoxFit.cover` 下的对齐点（自定义封面焦点）。默认居中。
  final AlignmentGeometry alignment;
  final ImageDownscalePolicy downscalePolicy;
  final Widget placeholder;
  final LibraryCoverAssetRef? coverAsset;
  final LibraryCoverUsage usage;
  final Color? failureColor;

  /// 列表 52 逻辑像素槽位使用紧凑重试胶囊。
  final bool compactFailure;

  @override
  ConsumerState<ShelfCoverImage> createState() => _ShelfCoverImageState();
}

class _ShelfCoverImageState extends ConsumerState<ShelfCoverImage> {
  bool _failed = false;
  int _attempt = 0;
  LibraryCoverImageProvider? _failedProvider;

  @override
  void didUpdateWidget(covariant ShelfCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverAsset != widget.coverAsset ||
        oldWidget.localPath != widget.localPath ||
        oldWidget.remoteUrl != widget.remoteUrl) {
      _failed = false;
      _attempt = 0;
      _failedProvider = null;
    }
  }

  void _handleFailure([LibraryCoverImageProvider? provider]) {
    if (!mounted || _failed) {
      return;
    }
    _failedProvider = provider;
    setState(() => _failed = true);
  }

  Future<void> _retry() async {
    if (!_failed) {
      return;
    }
    final asset = widget.coverAsset;
    final failedProvider = _failedProvider;
    _failedProvider = null;
    // 失败可能来自已落地但损坏的文件；清掉后再解码才能重新下载。
    if (asset != null) {
      await ref.read(libraryCoverStoreProvider).invalidate(asset);
    }
    // 已失败的 completer 仍可能留在图片缓存里，必须先驱逐再重建。
    await failedProvider?.evict();
    if (!mounted) {
      return;
    }
    setState(() {
      _failed = false;
      _attempt += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return LibraryCoverFailurePlaceholder(
        color:
            widget.failureColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        onRetry: _retry,
        compact: widget.compactFailure,
      );
    }
    return KeyedSubtree(key: ValueKey<int>(_attempt), child: _buildCover());
  }

  Widget _buildCover() {
    final asset = widget.coverAsset;
    if (asset != null) {
      return LibraryCoverImage(
        asset: asset,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        placeholder: widget.placeholder,
        usage: widget.usage,
        onError: _handleFailure,
      );
    }
    final remote = widget.remoteUrl?.trim();
    final networkSource = (remote != null && remote.isNotEmpty)
        ? NetworkAppImageSource(url: remote, referer: widget.imageReferer)
        : null;
    return AppImage(
      key: ValueKey<String>('shelf-cover-${widget.coverKey}'),
      localPath: widget.localPath,
      networkSource: networkSource,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      downscalePolicy: widget.downscalePolicy,
      placeholder: widget.placeholder,
      onImageFailed: _handleFailure,
    );
  }
}
