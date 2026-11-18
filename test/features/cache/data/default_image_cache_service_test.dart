import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui';

import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/cache/data/services/default_image_cache_service.dart';
import 'package:y300/features/cache/data/providers/image_cache_directory_provider.dart';
import 'package:y300/features/cache/data/repositories/image_cache_repository.dart';
import 'package:y300/features/cache/data/services/image_cache_diagnostic_recorder.dart';
import 'package:y300/features/cache/data/services/image_cache_failure_backoff.dart';
import 'package:y300/features/cache/data/services/y300_forum_resource_file_service.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/services/forum_image_dimension_index.dart';
import 'package:y300/features/cache/domain/services/forum_image_request_resolver.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';

part 'default_image_cache_service_missing_cooldown_cases.dart';
part 'default_image_cache_service_failure_diagnostics_cases.dart';
part 'default_image_cache_service_ensure_cached_cases.dart';
part 'default_image_cache_service_owner_clear_cases.dart';
part 'default_image_cache_service_dimension_cases.dart';
part 'default_image_cache_service_retention_cases.dart';
part 'default_image_cache_service_undecodable_cases.dart';

void main() {
  _missingImageCooldownCases();
  _failureDiagnosticsCases();
  _ensureCachedCases();
  _ownerClearCases();
  _dimensionCases();
  _retentionCases();
  _undecodableCacheFileCases();
}

final Uint8List _onePixelPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
);

const _confirmedNotFound = ForumResourceFileServiceException(
  ForumResourceFailure(
    kind: ForumResourceFailureKind.notFound,
    code: 'resource_not_found',
    statusCode: 404,
  ),
);

ImageCacheRequest _missingImageRequest({
  String cacheKey = 'missing/image',
  String sourceUrl = 'https://bbs.yamibo.com/data/attachment/missing.jpg',
  String? referer = 'https://bbs.yamibo.com/thread-1-1-1.html',
}) => ImageCacheRequest(
  cacheKey: cacheKey,
  sourceUrl: sourceUrl,
  referer: referer,
  ownerType: ImageCacheOwnerType.thread,
  ownerId: 'thread-owner',
  role: ImageCacheRole.threadInline,
);

DefaultImageCacheService _missingImageService({
  required _ControlledFailureDownloader downloader,
  _MemoryImageCacheRepository? repository,
  _RecordingImageCacheDiagnosticRecorder? recorder,
  BaseCacheManager? manager,
  ImageCacheFailureBackoff? failureBackoff,
  Object? Function()? failureScopeFor,
}) => DefaultImageCacheService(
  repository: repository ?? _MemoryImageCacheRepository(),
  cacheManagerFuture: Future<BaseCacheManager>.value(
    manager ?? _UnusedCacheManager(),
  ),
  directoryResolver: const ImageCacheDirectoryResolver(),
  downloader: downloader,
  diagnosticRecorder: recorder ?? const NoopImageCacheDiagnosticRecorder(),
  failureBackoff: failureBackoff,
  failureScopeFor: failureScopeFor,
);

Future<io.File> _temporaryFailureCacheImage() async {
  final directory = await io.Directory.systemTemp.createTemp(
    'y300-image-failure-cooldown-',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  final imageFile = io.File('${directory.path}/valid-cache.jpg');
  await imageFile.writeAsBytes(<int>[1, 2, 3]);
  return imageFile;
}

CachedImageRecord _cachedMissingImageRecord(
  ImageCacheRequest request,
  String path,
) => CachedImageRecord(
  cacheKey: request.cacheKey,
  ownerType: request.ownerType.dbValue,
  ownerId: request.ownerId,
  role: request.role.dbValue,
  lastSourceUrl: request.sourceUrl,
  localPath: path,
  bytes: 3,
  protected: false,
  createdAt: DateTime.utc(2026, 10, 14),
  updatedAt: DateTime.utc(2026, 10, 14),
);

ForumResourceFileServiceException _resourceFailure(
  ForumResourceFailureKind kind, [
  int? statusCode,
]) => ForumResourceFileServiceException(
  ForumResourceFailure(
    kind: kind,
    code: 'resource_failure',
    statusCode: statusCode,
  ),
);

class _ControlledFailureDownloader implements ImageFileDownloader {
  _ControlledFailureDownloader({
    this.failure = _confirmedNotFound,
    this.onDownload,
  });

  final Object failure;
  final Future<String> Function(int call)? onDownload;
  int downloadCount = 0;
  bool? lastForce;

  @override
  Future<String> download({
    required BaseCacheManager cacheManager,
    required String sourceUrl,
    required String cacheKey,
    Map<String, String>? headers,
    bool force = false,
  }) async {
    downloadCount++;
    lastForce = force;
    final callback = onDownload;
    if (callback != null) return callback(downloadCount);
    throw failure;
  }
}

class _MutableFileCacheManager extends _UnusedCacheManager {
  FileInfo? cached;
  Object? lookupFailure;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    final failure = lookupFailure;
    if (failure != null) throw failure;
    return cached;
  }
}

class _SpyImageFileDownloader implements ImageFileDownloader {
  _SpyImageFileDownloader({required this.localPath, this.downloadCompleter});

  final String localPath;
  final Completer<String>? downloadCompleter;
  int downloadCount = 0;
  Map<String, String>? lastHeaders;
  String? lastSourceUrl;
  bool? lastForce;

  @override
  Future<String> download({
    required BaseCacheManager cacheManager,
    required String sourceUrl,
    required String cacheKey,
    Map<String, String>? headers,
    bool force = false,
  }) async {
    downloadCount += 1;
    lastSourceUrl = sourceUrl;
    lastHeaders = headers;
    lastForce = force;
    return downloadCompleter?.future ?? localPath;
  }
}

class _FailingImageFileDownloader implements ImageFileDownloader {
  const _FailingImageFileDownloader();

  @override
  Future<String> download({
    required BaseCacheManager cacheManager,
    required String sourceUrl,
    required String cacheKey,
    Map<String, String>? headers,
    bool force = false,
  }) {
    throw const ForumResourceFileServiceException(
      ForumResourceFailure(
        kind: ForumResourceFailureKind.invalidContent,
        code: 'resource_is_not_image',
        statusCode: 200,
      ),
    );
  }
}

class _RecordingImageCacheDiagnosticRecorder
    implements ImageCacheDiagnosticRecorder {
  final List<ImageCacheFailureDiagnostic> events =
      <ImageCacheFailureDiagnostic>[];

  @override
  void recordFailure(ImageCacheFailureDiagnostic event) {
    events.add(event);
  }
}

class _ThrowingImageCacheDiagnosticRecorder
    implements ImageCacheDiagnosticRecorder {
  const _ThrowingImageCacheDiagnosticRecorder();

  @override
  void recordFailure(ImageCacheFailureDiagnostic event) {
    throw StateError('diagnostic recorder failed');
  }
}

class _MemoryImageCacheRepository implements ImageCacheRepository {
  final Map<String, CachedImageRecord> records = <String, CachedImageRecord>{};
  int getByKeyCalls = 0;
  int touchCalls = 0;

  @override
  Future<int> calculateUsageBytes({required bool includeProtected}) async {
    return records.values
        .where((record) => includeProtected || !record.protected)
        .fold<int>(0, (sum, record) => sum + record.bytes);
  }

  @override
  Future<List<ImageCacheUsageGroup>> calculateUsageGroups() async {
    return records.values
        .map((record) {
          return ImageCacheUsageGroup(
            ownerType: record.ownerType,
            role: record.role,
            retentionClass: record.retentionClass.dbValue,
            protected: record.protected,
            bytes: record.bytes,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> deleteByKey(String cacheKey) async {
    records.remove(cacheKey);
  }

  @override
  Future<CachedImageRecord?> getByKey(String cacheKey) async {
    getByKeyCalls++;
    return records[cacheKey];
  }

  @override
  Future<List<CachedImageRecord>> listByOwner({
    required String ownerType,
    required String ownerId,
  }) async {
    return records.values
        .where(
          (record) =>
              record.ownerType == ownerType && record.ownerId == ownerId,
        )
        .toList(growable: false);
  }

  @override
  Future<List<CachedImageRecord>> listUnprotectedByAccessTime() async {
    final unprotected =
        records.values.where((record) => !record.protected).toList()
          ..sort((a, b) {
            final aTime = a.lastAccessedAt ?? a.updatedAt;
            final bTime = b.lastAccessedAt ?? b.updatedAt;
            return aTime.compareTo(bTime);
          });
    return unprotected;
  }

  @override
  Future<List<CachedImageRecord>> listUnprotectedByRoles({
    required List<String> roles,
  }) async {
    if (roles.isEmpty) {
      return const <CachedImageRecord>[];
    }
    return records.values
        .where((record) => !record.protected && roles.contains(record.role))
        .toList(growable: false);
  }

  @override
  Future<List<CachedImageRecord>> listProtectedCovers() async {
    return records.values
        .where(
          (record) =>
              record.protected &&
              (record.role == ImageCacheRole.cover.dbValue ||
                  record.role == ImageCacheRole.customCover.dbValue),
        )
        .toList(growable: false);
  }

  @override
  Future<void> touch(String cacheKey, DateTime accessedAt) async {
    touchCalls++;
  }

  @override
  Future<void> updateDimensions({
    required String cacheKey,
    required int width,
    required int height,
    required DateTime updatedAt,
  }) async {
    final record = records[cacheKey];
    if (record == null) {
      return;
    }
    records[cacheKey] = record.copyWith(
      width: width,
      height: height,
      updatedAt: updatedAt,
      lastAccessedAt: updatedAt,
    );
  }

  @override
  Future<void> upsert(CachedImageRecord record) async {
    records[record.cacheKey] = record;
  }
}

class _UnusedCacheManager implements BaseCacheManager {
  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> emptyCache() async {}

  @override
  Stream<FileInfo> getFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => null;

  @override
  Future<FileInfo?> getFileFromMemory(String key) async => null;

  @override
  Future<file.File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<file.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<file.File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFile(String key) async {}
}
