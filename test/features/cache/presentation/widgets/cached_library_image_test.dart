import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/media/cover_aware_resize_image.dart';
import 'package:y300/core/media/encoded_image_dimension_probe.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/cache/presentation/widgets/library_cached_image.dart';

part 'cached_library_image_retry_loading_cases.dart';
part 'cached_library_image_cache_pipeline_cases.dart';
part 'cached_library_image_dimensions_stale_cases.dart';

void main() {
  _retryLoadingCases();
  _cachePipelineCases();
  _dimensionsStaleCases();
}

ImageCacheRequest _request(String cacheKey) {
  return ImageCacheRequest(
    cacheKey: cacheKey,
    sourceUrl: 'https://bbs.yamibo.com/data/attachment/forum/$cacheKey.jpg',
    ownerType: ImageCacheOwnerType.thread,
    ownerId: '100',
    role: ImageCacheRole.threadInline,
  );
}

Finder get _loadingIndicator =>
    find.byKey(const Key('cached-library-image-loading-indicator'));

Widget _localFallbackHarness(
  ImageCacheService cacheService, {
  String cacheKey = 'thread-image',
  String? preferredLocalPath,
  Future<bool> Function(String)? predicate,
  Widget? fallback = const SizedBox(key: Key('local-file-fallback')),
  Widget? errorPlaceholder = const SizedBox(key: Key('error-placeholder')),
  EncodedImageDimensionProbe? dimensionProbe,
  ValueChanged<String>? onLocalPathResolved,
  ValueChanged<Size>? onImageResolved,
  VoidCallback? onImageFailed,
  bool showDelayedLoadingIndicator = false,
}) {
  return ProviderScope(
    overrides: [
      imageCacheServiceProvider.overrideWithValue(cacheService),
      if (dimensionProbe != null)
        encodedImageDimensionProbeProvider.overrideWithValue(dimensionProbe),
    ],
    child: LocalizedTestApp(
      home: Center(
        child: SizedBox.square(
          dimension: 160,
          child: CachedLibraryImage(
            request: _request(cacheKey),
            preferredLocalPath: preferredLocalPath,
            localFileFallbackPredicate: predicate,
            localFileFallback: fallback,
            fit: BoxFit.cover,
            placeholder: const SizedBox(key: Key('placeholder')),
            errorPlaceholder: errorPlaceholder,
            remoteDisplayPolicy: CachedImageRemoteDisplayPolicy.afterCacheWrite,
            onLocalPathResolved: onLocalPathResolved,
            onImageResolved: onImageResolved,
            onImageFailed: onImageFailed,
            showDelayedLoadingIndicator: showDelayedLoadingIndicator,
          ),
        ),
      ),
    ),
  );
}

Widget _loadingHarness(
  ImageCacheService cacheService, {
  String cacheKey = 'thread-image',
  bool showDelayedLoadingIndicator = true,
  ImageProvider? imageProvider,
  ImageProvider? remoteImageProvider,
}) {
  return ProviderScope(
    overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
    child: LocalizedTestApp(
      home: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: CachedLibraryImage(
            request: _request(cacheKey),
            fit: BoxFit.contain,
            placeholder: const SizedBox(key: Key('placeholder')),
            errorPlaceholder: const SizedBox(key: Key('error-placeholder')),
            imageProviderOverride: imageProvider,
            showDelayedLoadingIndicator: showDelayedLoadingIndicator,
            remoteImageProviderOverride: remoteImageProvider,
          ),
        ),
      ),
    ),
  );
}

io.File _createTempPng(WidgetTester tester) {
  final directory = io.Directory.systemTemp.createTempSync(
    'cached_library_image_test_',
  );
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  final file = io.File('${directory.path}/image.png');
  file.writeAsBytesSync(base64Decode(_onePixelPngBase64), flush: true);
  return file;
}

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

/// 解开降采样包裹，取底层真实 provider（Phase 0 起 provider 可能被 ResizeImage 包裹）。
ImageProvider _underlyingProvider(ImageProvider provider) {
  if (provider is ResizeImage) {
    return provider.imageProvider;
  }
  if (provider is CoverAwareResizeImage) {
    return provider.imageProvider;
  }
  return provider;
}

class _ControlledImageCacheService
    implements
        ImageCacheService,
        ImageCacheDecodeFailureReporter,
        ImageCacheDimensionRecorder {
  final Map<String, Completer<CachedImageResult?>> _getCachedCompleters =
      <String, Completer<CachedImageResult?>>{};
  final Map<String, Completer<CachedImageResult>> _ensureCompleters =
      <String, Completer<CachedImageResult>>{};
  final Map<String, int> _getCachedCounts = <String, int>{};
  final List<ImageCacheRequest> decodeFailures = <ImageCacheRequest>[];
  final List<String?> decodeFailurePaths = <String?>[];
  final Map<String, Size> recordedDimensions = <String, Size>{};

  int getCachedCount(String cacheKey) => _getCachedCounts[cacheKey] ?? 0;

  bool ensureStarted(String cacheKey) {
    return _ensureCompleters.containsKey(cacheKey);
  }

  void completeGetCached(String cacheKey, CachedImageResult? result) {
    final completer = _getCachedCompleters.putIfAbsent(
      cacheKey,
      () => Completer<CachedImageResult?>(),
    );
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  void completeEnsure(String cacheKey, CachedImageResult result) {
    final completer = _ensureCompleters.putIfAbsent(
      cacheKey,
      () => Completer<CachedImageResult>(),
    );
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) {
    final cacheKey = request.cacheKey;
    return _ensureCompleters
        .putIfAbsent(cacheKey, () => Completer<CachedImageResult>())
        .future;
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) {
    _getCachedCounts[cacheKey] = (_getCachedCounts[cacheKey] ?? 0) + 1;
    return _getCachedCompleters
        .putIfAbsent(cacheKey, () => Completer<CachedImageResult?>())
        .future;
  }

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult.failed;
  }

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async {
    return 0;
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}

  @override
  void reportDecodeFailure({
    required ImageCacheRequest request,
    required Object error,
    StackTrace? stackTrace,
    String? localPath,
  }) {
    decodeFailures.add(request);
    decodeFailurePaths.add(localPath);
  }

  @override
  Future<void> recordResolvedDimensions({
    required String cacheKey,
    required Size size,
  }) async {
    recordedDimensions[cacheKey] = size;
  }
}

class _RetryableImageCacheService extends _ControlledImageCacheService
    implements ImageCacheFailureControl {
  final retryRequests = <ImageCacheRequest>[];
  final ensureRequests = <ImageCacheRequest>[];
  final operations = <String>[];

  @override
  void allowRetry(ImageCacheRequest request) {
    retryRequests.add(request);
    operations.add('retry:${request.cacheKey}');
  }

  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    ensureRequests.add(request);
    operations.add('ensure:${request.cacheKey}');
    return CachedImageResult.failed;
  }
}

class _ControlledDimensionProbe implements EncodedImageDimensionProbe {
  final Completer<Size> _completer = Completer<Size>();
  int calls = 0;

  void complete(Size size) {
    _completer.complete(size);
  }

  @override
  Future<Size> probe({required String cacheKey, required String localPath}) {
    calls += 1;
    return _completer.future;
  }
}

class _FailingDimensionProbe implements EncodedImageDimensionProbe {
  const _FailingDimensionProbe();

  @override
  Future<Size> probe({required String cacheKey, required String localPath}) {
    return Future<Size>.error(StateError('synthetic dimension failure'));
  }
}

class _KeyedControlledDimensionProbe implements EncodedImageDimensionProbe {
  final Map<String, Completer<Size>> _completers = <String, Completer<Size>>{};

  Iterable<String> get startedKeys => _completers.keys;

  void complete(String cacheKey, Size size) {
    _completers[cacheKey]!.complete(size);
  }

  @override
  Future<Size> probe({required String cacheKey, required String localPath}) {
    return _completers.putIfAbsent(cacheKey, Completer<Size>.new).future;
  }
}

class _SynchronousImageProvider
    extends ImageProvider<_SynchronousImageProvider> {
  const _SynchronousImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_SynchronousImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<_SynchronousImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SynchronousImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
    );
  }
}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  const _PendingImageProvider();

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PendingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}

class _ControlledImageProvider extends ImageProvider<_ControlledImageProvider> {
  final Completer<ImageInfo> _completer = Completer<ImageInfo>();

  void fail() {
    _completer.completeError(StateError('image failed'));
  }

  @override
  Future<_ControlledImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_ControlledImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _ControlledImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_completer.future);
  }
}
