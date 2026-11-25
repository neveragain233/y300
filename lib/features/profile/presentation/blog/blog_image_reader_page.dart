import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/clipboard/clipboard_providers.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/cache/presentation/widgets/image_retry_placeholder.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/features/profile/presentation/blog/blog_image_reader_request.dart';
import 'package:y300/features/profile/presentation/blog/blog_read_providers.dart';
import 'package:y300/features/reader_shared/data/export/reader_image_export_providers.dart';
import 'package:y300/features/reader_shared/domain/export/reader_image_export.dart';
import 'package:y300/features/reader_shared/presentation/reader_text_resolver.dart';
import 'package:y300/features/thread/presentation/thread_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/image_lightbox/image_lightbox_page.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

int _nextBlogImageSession = 0;

Future<void> openBlogImageReader(
  BuildContext context,
  WidgetRef ref, {
  required Object accountOwner,
  required ForumHtmlReadableImageSequence sequence,
  required ForumHtmlImageRequest image,
  required String cacheOwnerId,
  required String referer,
}) async {
  if (!context.mounted ||
      ModalRoute.of(context)?.isCurrent == false ||
      !identical(accountOwner, ref.read(blogMutationBusProvider))) {
    return;
  }
  final request = BlogImageReaderRequest.fromImage(
    sequence: sequence,
    image: image,
    cacheOwnerId: cacheOwnerId,
    sessionOwnerId: '${sequence.sourceId}:${_nextBlogImageSession++}',
    referer: referer,
    resolver: ref.read(forumImageRequestResolverProvider),
  );
  if (request == null) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    buildImageLightboxRoute<void>(
      builder: (_) => BlogImageReaderPage(
        request: request,
        referer: referer,
        accountOwner: accountOwner,
      ),
    ),
  );
}

class BlogImageReaderPage extends ConsumerStatefulWidget {
  const BlogImageReaderPage({
    super.key,
    required this.request,
    required this.referer,
    required this.accountOwner,
  });

  final BlogImageReaderRequest request;
  final String referer;
  final Object accountOwner;

  @override
  ConsumerState<BlogImageReaderPage> createState() =>
      _BlogImageReaderPageState();
}

class _BlogImageReaderPageState extends ConsumerState<BlogImageReaderPage> {
  bool _expired = false;
  final Map<int, int> _retryTokens = <int, int>{};
  final Set<int> _prefetchedIndexes = <int>{};
  int? _exportingIndex;

  @override
  void initState() {
    super.initState();
    ref.listenManual(blogMutationBusProvider, (_, owner) {
      if (!identical(owner, widget.accountOwner) && !_expired) {
        setState(() => _expired = true);
      }
    }, fireImmediately: true);
    Future<void>.microtask(() {
      if (mounted && !_expired) {
        _prefetchAround(widget.request.initialIndex);
      }
    });
  }

  void _prefetchAround(int centerIndex) {
    final count = widget.request.requests.length;
    final precache = ref.read(forumImagePrecacheServiceProvider);
    for (final index in [centerIndex, centerIndex - 1, centerIndex + 1]) {
      if (index < 0 || index >= count || !_prefetchedIndexes.add(index)) {
        continue;
      }
      final cacheRequest = widget.request.requests[index];
      final uri = Uri.tryParse(cacheRequest.sourceUrl);
      if (uri == null) continue;
      unawaited(
        precache.ensureDiskCached(
          ForumImageLoadSpec(
            kind: ForumImageKind.blogInline,
            url: uri,
            ownerId: cacheRequest.ownerId,
            ownerType: ImageCacheOwnerType.blog,
            referer: widget.referer,
            imageIndex: index,
            cacheKey: cacheRequest.cacheKey,
          ),
        ),
      );
    }
  }

  Future<void> _copyImageUrl(int index) async {
    final requests = widget.request.requests;
    if (index < 0 || index >= requests.length) return;
    final url = requests[index].sourceUrl.trim();
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
    final requests = widget.request.requests;
    if (index < 0 || index >= requests.length || _exportingIndex == index) {
      return;
    }
    _exportingIndex = index;
    final cacheRequest = requests[index];
    final l10n = AppLocalizations.of(context);
    showTransientSnackBar(context, l10n.readerExportSaving);
    try {
      final result = await ref
          .read(readerImageExportServiceProvider)
          .export(
            ReaderImageExportRequest(
              cacheRequest: cacheRequest,
              metadata: ReaderImageExportMetadata(
                baseName: 'Y300-blog-${cacheRequest.ownerId}-${index + 1}',
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

  double? _aspectRatioFor(int index) {
    final dims = widget.request.items[index].knownDimensions;
    if (dims == null || dims.width <= 0 || dims.height <= 0) return null;
    return dims.width / dims.height;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_expired) {
      return Scaffold(
        appBar: AppPageAppBar(title: l10n.threadImageReaderTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.profileBlogCommentSessionChanged,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return ImageLightboxPage<void>(
      key: const Key('blog-image-lightbox-page'),
      itemCount: widget.request.requests.length,
      initialIndex: widget.request.initialIndex,
      initialAspectRatioFor: _aspectRatioFor,
      onPageChanged: _prefetchAround,
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
          key: ValueKey<String>('blog-lightbox-image-$index'),
          request: widget.request.requests[index],
          fit: BoxFit.contain,
          referer: widget.referer,
          placeholder: const SizedBox.shrink(),
          errorPlaceholder: ImageRetryPlaceholder(
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
