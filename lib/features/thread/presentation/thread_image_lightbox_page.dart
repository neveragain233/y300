import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/clipboard/clipboard_providers.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/cache/presentation/widgets/image_retry_placeholder.dart';
import 'package:y300/features/reader_shared/data/export/reader_image_export_providers.dart';
import 'package:y300/features/reader_shared/domain/export/reader_image_export.dart';
import 'package:y300/features/reader_shared/presentation/reader_text_resolver.dart';
import 'package:y300/features/thread/domain/models/thread_image_open_models.dart';
import 'package:y300/features/thread/domain/models/thread_image_reader_exit_result.dart';
import 'package:y300/features/thread/presentation/thread_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/image_lightbox/image_lightbox_page.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 一般帖子、回复、漫画评论与小说插图使用的独立图片灯箱页。
///
/// 不依赖漫画阅读引擎与阅读偏好（条漫连续滚动、从右向左翻页等），
/// 仅复用原帖磁盘缓存、图片导出与退回原帖楼层锚定契约。
class ThreadImageLightboxPage extends ConsumerStatefulWidget {
  const ThreadImageLightboxPage({
    super.key,
    required this.request,
    this.imageReferer,
    this.onBeforeExit,
  });

  final ThreadImageOpenRequest request;
  final String? imageReferer;
  final Future<void> Function(ThreadImageReaderExitResult result)? onBeforeExit;

  @override
  ConsumerState<ThreadImageLightboxPage> createState() =>
      _ThreadImageLightboxPageState();
}

class _ThreadImageLightboxPageState
    extends ConsumerState<ThreadImageLightboxPage> {
  final Map<int, int> _retryTokens = <int, int>{};
  final Set<int> _prefetchedIndexes = <int>{};
  int? _exportingIndex;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        _prefetchNeighbors(widget.request.initialIndex);
      }
    });
  }

  @override
  void didUpdateWidget(ThreadImageLightboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.request, widget.request)) {
      _retryTokens.clear();
      _prefetchedIndexes.clear();
      _exportingIndex = null;
      Future<void>.microtask(() {
        if (mounted) {
          _prefetchNeighbors(widget.request.initialIndex);
        }
      });
    }
  }

  ImageCacheRequest _cacheRequestFor(int index) {
    final entry = widget.request.group.entries[index];
    return ImageCacheRequest(
      cacheKey: entry.cacheKey,
      sourceUrl: entry.url,
      ownerType: ImageCacheOwnerType.thread,
      ownerId: 'thread:${widget.request.tid}:post:${widget.request.pid}',
      role: ImageCacheRole.threadInline,
      imageIndex: entry.indexInPost,
      retentionClass: ImageRetentionClass.recentReader,
    );
  }

  void _prefetchNeighbors(int centerIndex) {
    final count = widget.request.group.entries.length;
    if (count <= 1) return;
    final cacheService = ref.read(imageCacheServiceProvider);
    for (final candidate in [centerIndex - 1, centerIndex + 1]) {
      if (candidate < 0 ||
          candidate >= count ||
          !_prefetchedIndexes.add(candidate)) {
        continue;
      }
      unawaited(cacheService.ensureCached(_cacheRequestFor(candidate)));
    }
  }

  Future<void> _copyImageUrl(int index) async {
    final entries = widget.request.group.entries;
    if (index < 0 || index >= entries.length) return;
    final url = entries[index].url.trim();
    if (url.isEmpty) return;
    await ref.read(clipboardTextWriterProvider).writeText(url);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showTransientSnackBar(
      context,
      ThreadTextResolver.copySuccess(l10n, l10n.threadDetailImageLink),
    );
  }

  Future<void> _exportImage(int index) async {
    final entries = widget.request.group.entries;
    if (index < 0 || index >= entries.length || _exportingIndex == index) {
      return;
    }
    _exportingIndex = index;
    final entry = entries[index];
    final l10n = AppLocalizations.of(context);
    showTransientSnackBar(context, l10n.readerExportSaving);
    try {
      final result = await ref
          .read(readerImageExportServiceProvider)
          .export(
            ReaderImageExportRequest(
              cacheRequest: _cacheRequestFor(index),
              metadata: ReaderImageExportMetadata(
                baseName:
                    'Y300-thread-${widget.request.tid}-post-${widget.request.pid}-${entry.indexInPost + 1}',
                albumName: 'Y300',
              ),
            ),
          );
      if (!mounted || _exportingIndex != index) return;
      final currentL10n = AppLocalizations.of(context);
      showTransientSnackBar(
        context,
        result.success
            ? currentL10n.readerExportSaved(
                result.destination?.displayLocation ??
                    currentL10n.readerExportDefaultDestination,
              )
            : ReaderTextResolver.exportFailure(
                currentL10n,
                result.failureReason,
              ),
      );
    } finally {
      if (_exportingIndex == index) {
        _exportingIndex = null;
      }
    }
  }

  Future<ThreadImageReaderExitResult?> _handleBeforeExit(
    int currentIndex,
    bool hasNavigated,
  ) async {
    final entries = widget.request.group.entries;
    if (!hasNavigated ||
        currentIndex == widget.request.initialIndex ||
        widget.request.group.tid != widget.request.tid ||
        widget.request.group.pid != widget.request.pid ||
        currentIndex < 0 ||
        currentIndex >= entries.length) {
      return null;
    }
    final entry = entries[currentIndex];
    final result = ThreadImageReaderExitResult(
      tid: widget.request.tid,
      pid: widget.request.pid,
      indexInPost: entry.indexInPost,
      cacheKey: entry.cacheKey,
      url: entry.url,
    );
    final prepare = widget.onBeforeExit;
    if (prepare != null) {
      try {
        await prepare(result);
      } catch (_) {
        // 退回定位失败不得阻塞用户关闭灯箱。
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.request.group.entries;
    final l10n = AppLocalizations.of(context);
    return ImageLightboxPage<ThreadImageReaderExitResult>(
      key: const Key('thread-image-lightbox-page'),
      itemCount: entries.length,
      initialIndex: widget.request.initialIndex,
      initialAspectRatioFor: (index) => entries[index].layoutHint?.aspectRatio,
      onPageChanged: _prefetchNeighbors,
      onBeforeExit: _handleBeforeExit,
      actionsFor: (context, index) => [
        ImageLightboxAction(
          key: const Key('image-lightbox-copy-link-button'),
          icon: Icons.link_rounded,
          tooltip: l10n.imageLightboxCopyLink,
          onPressed: () => unawaited(_copyImageUrl(index)),
        ),
        ImageLightboxAction(
          key: const Key('image-lightbox-save-button'),
          icon: Icons.download_outlined,
          tooltip: l10n.threadImageSave,
          onPressed: () => unawaited(_exportImage(index)),
        ),
      ],
      itemBuilder: (context, index, onSizeResolved) {
        final retryToken = _retryTokens[index] ?? 0;
        return CachedLibraryImage(
          key: ValueKey<String>('thread-lightbox-image-$index'),
          request: _cacheRequestFor(index),
          fit: BoxFit.contain,
          referer: widget.imageReferer,
          placeholder: const SizedBox.shrink(),
          errorPlaceholder: ImageRetryPlaceholder(
            retryButtonKey: ValueKey<String>(
              'thread-image-lightbox-retry-$index',
            ),
            onRetry: () {
              setState(() {
                _retryTokens[index] = retryToken + 1;
              });
            },
          ),
          showDelayedLoadingIndicator: true,
          loadingIndicatorColor: Colors.white,
          remoteDisplayPolicy: CachedImageRemoteDisplayPolicy.afterCacheWrite,
          retryToken: retryToken,
          onImageResolved: onSizeResolved,
        );
      },
    );
  }
}
