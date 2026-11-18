import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/comic/data/services/comic_download_service.dart';
import 'package:y300/features/comic/domain/services/comic_download_execution.dart';
import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/features/comic/domain/models/comic_detail_models.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/models/comic_shelf_models.dart';
import 'package:y300/features/comic/domain/services/comic_episode_images_fetch_result.dart';
import 'package:y300/features/comic/domain/services/comic_episode_images_unavailable.dart';
import 'package:y300/features/comic/domain/services/comic_episode_sequence.dart';
import 'package:y300/features/comic/domain/services/comic_reader_feature_flags.dart';
import 'package:y300/features/comic/domain/services/comic_reading_state_writer.dart';
import 'package:y300/features/comic/domain/services/comic_reader_service.dart';
import 'package:y300/features/comic/domain/services/comic_download_service.dart';
import 'package:y300/features/comic/data/providers/comic_reader_service_providers.dart';
import 'package:y300/features/comic/presentation/controllers/comic_reader_controller.dart';
import 'package:y300/features/comic/presentation/comic_presentation_models.dart';
import 'package:y300/features/library_shared/data/providers/library_cover_providers.dart';
import 'package:y300/features/library_shared/data/services/library_cover_store.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/storage/domain/download_storage_models.dart';

part 'comic_reader_controller_init_load_cases.dart';
part 'comic_reader_controller_position_restore_cases.dart';
part 'comic_reader_controller_reader_mode_cases.dart';
part 'comic_reader_controller_chapter_switch_cases.dart';
part 'comic_reader_controller_late_result_cases.dart';

void main() {
  test('provider rebuild creates a fresh image recovery owner', () async {
    final fixture = _ImageRecoveryFixture();
    await fixture.load();
    await fixture.controller.prepareImageRetry(
      expectedEpisodeId: 'yamibo:100:101',
    );
    fixture.container.invalidate(
      comicReaderControllerProvider(_ImageRecoveryFixture.args),
    );
    await fixture.load();
    await fixture.controller.prepareImageRetry(
      expectedEpisodeId: 'yamibo:100:101',
    );
    expect(fixture.service.fetchEpisodeImagesCalls, ['101', '101']);
  });

  for (final retirement in ['refresh', 'A-B-A', 'dispose']) {
    test('pending automatic retry is retired by $retirement', () async {
      final fixture = _ImageRecoveryFixture();
      await fixture.load();
      final probe = Completer<ComicEpisodeImagesFetchResult>();
      fixture.service.fetchCompleter = probe;
      await fixture.controller.onImageDisplayFailed(
        imageIndex: 0,
        imageUrl: 'https://img.test/101-1.jpg',
      );
      fixture.service.fetchCompleter = null;
      switch (retirement) {
        case 'refresh':
          fixture.service.fetchResultBuilder = (_) => ComicEpisodeImagesFetched(
            fixture.value.images.map((image) => image.imageUrl).toList(),
          );
          await fixture.controller.refreshCurrentEpisode();
        case 'A-B-A':
          await fixture.controller.openEpisode(episodeId: 'yamibo:100:102');
          await fixture.controller.openEpisode(episodeId: 'yamibo:100:101');
        case 'dispose':
          fixture.dispose();
      }
      final before = retirement == 'dispose' ? null : fixture.value;
      final replacements = fixture.repository.replaceEpisodeImagesCallCount;
      probe.complete(
        const ComicEpisodeImagesFetched(['https://img.test/ignored.jpg']),
      );
      await Future<void>.delayed(Duration.zero);
      if (before != null) {
        expect(fixture.value, same(before));
        expect(fixture.value.images.first.retryRevision, 0);
      }
      expect(fixture.repository.replaceEpisodeImagesCallCount, replacements);
    });
  }

  for (final callback in ['failure', 'resolution']) {
    test(
      'refresh retires a $callback callback waiting on cache metadata',
      () async {
        final fixture = _ImageRecoveryFixture();
        await fixture.load();
        final gate = Completer<void>();
        final probe = Completer<ComicEpisodeImagesFetchResult>();
        late Future<void> pending;
        if (callback == 'failure') {
          fixture.repository.cacheStatusWriteGate = gate;
          fixture.service.fetchCompleter = probe;
          pending = fixture.controller.onImageDisplayFailed(
            imageIndex: 0,
            imageUrl: 'https://img.test/101-1.jpg',
          );
        } else {
          fixture.repository.metadataWriteGate = gate;
          pending = fixture.controller.onImageResolved(
            imageIndex: 0,
            imageUrl: 'https://img.test/101-1.jpg',
            width: 777,
            height: 1111,
          );
        }
        await Future<void>.delayed(Duration.zero);
        fixture.service.fetchCompleter = null;
        fixture.service.fetchResultBuilder = (_) => ComicEpisodeImagesFetched(
          fixture.value.images.map((image) => image.imageUrl).toList(),
        );
        await fixture.controller.refreshCurrentEpisode();
        final refreshed = fixture.value;
        gate.complete();
        await pending;
        if (callback == 'failure') {
          probe.complete(const ComicEpisodeImagesFetched([]));
        }
        await Future<void>.delayed(Duration.zero);
        expect(fixture.value, same(refreshed));
        expect(fixture.value.images.first.failed, isFalse);
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  _initialLoadCases();
  _restoreProgressCases();
  _readerModeCases();
  _scrollProgressCases();
  _loadStateCases();
  _visibilityRestoreCases();
  _lateResolutionCases();
  _completionGateCases();
  _staleResolutionCases();
  _imageStatusCases();
  _lastPageCompletionCases();
  _bookmarkCases();
  _lateBookmarkCases();
  _episodeReadCases();
  _coverActionCases();
  _episodeSwitchCases();
  _lateProgressCases();
  _episodeImageFetchCases();
  _displayProbeCases();
  _refreshCases();
}

class _ImageRecoveryFixture {
  _ImageRecoveryFixture() {
    container = ProviderContainer(
      overrides: [
        comicRepositoryProvider.overrideWithValue(repository),
        comicReadingStateWriterProvider.overrideWithValue(
          _ReadingStateWriterSpy(repository),
        ),
        comicReaderServiceProvider.overrideWith((ref) async => service),
        comicDownloadServiceProvider.overrideWithValue(
          _NoopComicDownloadService(),
        ),
        imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
      ],
    );
    final subscription = container.listen(
      comicReaderControllerProvider(args),
      (_, _) {},
    );
    _closeSubscription = subscription.close;
    addTearDown(dispose);
  }
  static const args = ComicReaderArgs(
    comicId: 'yamibo:100',
    episodeId: 'yamibo:100:101',
  );
  final repository = _ReaderRepoForControllerTest();
  final service = _ReaderServiceSpy();
  late final ProviderContainer container;
  late final void Function() _closeSubscription;
  bool _disposed = false;
  ComicReaderController get controller =>
      container.read(comicReaderControllerProvider(args).notifier);
  ComicReaderViewState get value =>
      container.read(comicReaderControllerProvider(args)).requireValue;
  Future<ComicReaderViewState> load() =>
      container.read(comicReaderControllerProvider(args).future);
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closeSubscription();
    container.dispose();
  }
}

class _NoopComicDownloadService implements ComicDownloadService {
  @override
  Future<void> deleteEpisodeDownload({
    required String comicId,
    required String episodeId,
  }) async {}

  @override
  Future<DownloadedComicEpisode> downloadEpisode({
    required String comicId,
    required String episodeId,
    ComicDownloadProgressObserver? observer,
    ComicDownloadCancellationToken? cancellationToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ComicEpisodeImageItem>> getDownloadedEpisodeImages({
    required String comicId,
    required String episodeId,
  }) async {
    return const <ComicEpisodeImageItem>[];
  }
}

class _DownloadedComicServiceFake extends _NoopComicDownloadService {
  _DownloadedComicServiceFake(this.images);

  final List<ComicEpisodeImageItem> images;

  @override
  Future<List<ComicEpisodeImageItem>> getDownloadedEpisodeImages({
    required String comicId,
    required String episodeId,
  }) async {
    return images;
  }
}

class _ReaderServiceSpy implements ComicReaderService {
  final List<String> cachedImageUrls = <String>[];
  final List<List<String>> prefetchedBatches = <List<String>>[];
  final List<String> fetchEpisodeImagesCalls = <String>[];
  Completer<ComicEpisodeImagesFetchResult>? fetchCompleter;

  /// 测试可注入的拉取结果——空时默认返回 `Fetched([])`，等价于"成功但首楼无图"。
  ComicEpisodeImagesFetchResult Function(String tid)? fetchResultBuilder;

  @override
  Future<ComicImageCacheResult> cacheImage({
    required String imageUrl,
    String? cacheKey,
    ImageCacheOwnerType? ownerType,
    String? ownerId,
    ImageCacheRole role = ImageCacheRole.comicPage,
    String? episodeId,
    int? imageIndex,
    bool protected = false,
  }) async {
    cachedImageUrls.add(imageUrl);
    return ComicImageCacheResult(
      success: true,
      localPath: '/cache/mock.jpg',
      cacheKey: cacheKey,
    );
  }

  @override
  Future<ComicEpisodeImagesFetchResult> fetchEpisodeImages(String tid) async {
    fetchEpisodeImagesCalls.add(tid);
    final completer = fetchCompleter;
    if (completer != null) {
      return completer.future;
    }
    final builder = fetchResultBuilder;
    if (builder != null) {
      return builder(tid);
    }
    return const ComicEpisodeImagesFetched(<String>[]);
  }

  @override
  Future<void> prefetchImages({required List<String> imageUrls}) async {
    prefetchedBatches.add(imageUrls);
  }
}

class _FakeImageCacheService implements ImageCacheService {
  ImageCacheLocalCopyRequest? lastLocalCopyRequest;

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async => 0;

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    lastLocalCopyRequest = request;
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: '/protected/cover.jpg',
    );
  }

  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: '/cache/mock.jpg',
    );
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}
}

class _ControllerCoverStoreFake implements LibraryCoverStore {
  LibraryCoverAssetRef? installedAsset;
  String? installedSourcePath;

  @override
  Future<int> calculateUsageBytes() async => 0;

  @override
  Future<void> deleteAsset(String assetId) async {}

  @override
  Future<void> deleteOlderRevisions(LibraryCoverAssetRef asset) async {}

  @override
  Future<void> invalidate(LibraryCoverAssetRef asset) async {}

  @override
  Future<io.File> ensureAvailable(LibraryCoverAssetRef asset) async {
    throw UnimplementedError();
  }

  @override
  Future<io.File> fileFor(LibraryCoverAssetRef asset) async {
    throw UnimplementedError();
  }

  @override
  Future<void> installLocalFile({
    required LibraryCoverAssetRef asset,
    required String sourcePath,
  }) async {
    installedAsset = asset;
    installedSourcePath = sourcePath;
  }
}

class _ProgressWrite {
  const _ProgressWrite({required this.imageIndex, required this.scrollOffset});

  final int imageIndex;
  final double scrollOffset;
}

class _CacheStatusWrite {
  const _CacheStatusWrite({
    required this.episodeId,
    required this.imageUrl,
    required this.cacheStatus,
    this.cacheLocalPath,
  });

  final String episodeId;
  final String imageUrl;
  final String cacheStatus;
  final String? cacheLocalPath;
}

class _ImageMetadataWrite {
  const _ImageMetadataWrite({
    required this.episodeId,
    required this.imageUrl,
    this.width,
    this.height,
  });

  final String episodeId;
  final String imageUrl;
  final int? width;
  final int? height;
}

ProviderContainer _marksContainer(
  _ReaderRepoForControllerTest repository,
  ComicReadingStateWriter writer,
) => ProviderContainer(
  overrides: [
    comicRepositoryProvider.overrideWithValue(repository),
    comicReadingStateWriterProvider.overrideWithValue(writer),
    comicReaderServiceProvider.overrideWith((ref) async => _ReaderServiceSpy()),
    comicDownloadServiceProvider.overrideWithValue(_NoopComicDownloadService()),
    imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
  ],
);

class _AggregatedReadingStateWriterSpy extends _ReadingStateWriterSpy
    implements ComicReadingMarksReader {
  _AggregatedReadingStateWriterSpy(super.repository);
  final reads = <String>[];
  Completer<void>? bookmarkGate;

  @override
  Future<ComicEpisodeReadingMarks> readEpisodeMarks({
    required String comicId,
    required String episodeId,
  }) async {
    reads.add(episodeId);
    return ComicEpisodeReadingMarks(
      isRead: initiallyReadEpisodeIds.contains(episodeId),
      isBookmarked: bookmarkedEpisodeIds.contains(episodeId),
    );
  }

  @override
  Future<bool> isEpisodeRead({
    required String comicId,
    required String episodeId,
  }) => throw StateError('aggregate reader expected');

  @override
  Future<bool> isEpisodeBookmarked({
    required String comicId,
    required String episodeId,
  }) => throw StateError('aggregate reader expected');

  @override
  Future<void> setEpisodeBookmarked({
    required String comicId,
    required String episodeId,
    required bool isBookmarked,
  }) async {
    await super.setEpisodeBookmarked(
      comicId: comicId,
      episodeId: episodeId,
      isBookmarked: isBookmarked,
    );
    await bookmarkGate?.future;
  }
}

class _ReadingStateWriterSpy implements ComicReadingStateWriter {
  _ReadingStateWriterSpy(this.repository);

  final _ReaderRepoForControllerTest repository;
  final List<String> completedEpisodeIds = <String>[];
  final Set<String> initiallyReadEpisodeIds = <String>{};
  final Set<String> bookmarkedEpisodeIds = <String>{};

  @override
  Future<bool> isEpisodeRead({
    required String comicId,
    required String episodeId,
  }) async {
    return initiallyReadEpisodeIds.contains(episodeId);
  }

  @override
  Future<bool> isEpisodeBookmarked({
    required String comicId,
    required String episodeId,
  }) async {
    return bookmarkedEpisodeIds.contains(episodeId);
  }

  @override
  Future<void> saveProgress({
    required String comicId,
    required String episodeId,
    required int imageIndex,
    required double scrollOffset,
  }) {
    return repository.updateLastReadProgress(
      comicId: comicId,
      episodeId: episodeId,
      imageIndex: imageIndex,
      scrollOffset: scrollOffset,
    );
  }

  @override
  Future<void> markEpisodeCompleted({
    required String comicId,
    required String episodeId,
    required int imageIndex,
    required double scrollOffset,
    required DateTime completedAt,
  }) async {
    completedEpisodeIds.add(episodeId);
    await saveProgress(
      comicId: comicId,
      episodeId: episodeId,
      imageIndex: imageIndex,
      scrollOffset: scrollOffset,
    );
  }

  @override
  Future<void> setEpisodeRead({
    required String comicId,
    required String episodeId,
    required bool isRead,
    DateTime? readAt,
  }) async {
    if (isRead) {
      initiallyReadEpisodeIds.add(episodeId);
    } else {
      initiallyReadEpisodeIds.remove(episodeId);
    }
  }

  @override
  Future<void> setEpisodeBookmarked({
    required String comicId,
    required String episodeId,
    required bool isBookmarked,
  }) async {
    if (isBookmarked) {
      bookmarkedEpisodeIds.add(episodeId);
    } else {
      bookmarkedEpisodeIds.remove(episodeId);
    }
  }
}

/// Lightweight fake to document expected episode ordering in controller tests.
class _ReaderRepoForControllerTest
    implements
        ComicRepository,
        ComicEpisodeImageDirectoryReplacer,
        ComicCoverCacheWriter,
        ComicCustomCoverAssetWriter,
        ComicEpisodeImageCacheMetadataWriter {
  _ReaderRepoForControllerTest({
    this.singlePage = false,
    this.lastImageWidth,
    this.lastImageHeight,
    this.imageCount = 5,
    this.emptyEpisodeIds = const <String>{},
    this.readingProgresses = const <ComicReadingProgress>[],
    this.episodes,
  });

  final bool singlePage;
  final int? lastImageWidth;
  final int? lastImageHeight;
  final int imageCount;
  final List<ComicReadingProgress> readingProgresses;
  final List<ComicEpisodeItem>? episodes;

  /// 这些 episode 在 fetch+save 之前，DB 视为空。用来模拟"首次进入未缓存"。
  final Set<String> emptyEpisodeIds;
  final List<_ProgressWrite> progressWrites = <_ProgressWrite>[];
  final List<_CacheStatusWrite> cacheStatusWrites = <_CacheStatusWrite>[];
  final List<_ImageMetadataWrite> imageMetadataWrites = <_ImageMetadataWrite>[];
  Completer<void>? cacheStatusWriteGate;
  Completer<void>? metadataWriteGate;

  /// 追踪每个 episode 通过 [saveEpisodeImages] 持久化的 URL，做断言用。
  final Map<String, List<String>> savedImageUrlsByEpisode =
      <String, List<String>>{};
  int replaceEpisodeImagesCallCount = 0;
  String? lastCustomCoverLocalPath;
  int? lastActivatedCustomCoverRevision;
  double? lastCustomCoverFocusX;
  double? lastCustomCoverFocusY;

  @override
  Future<void> addToShelf({
    required String comicId,
    required String tid,
    required String fid,
    String? sourceTypeId,
    String? sourceTagName,
    required String title,
    required ParsedComicPost parsedPost,
  }) async {}

  @override
  Future<void> removeFromShelf({required String comicId}) async {}

  @override
  Future<String> createCategory({required String name}) async => 'mock';

  @override
  Future<void> clearEpisodeImageCache({required String episodeId}) async {}

  @override
  Future<void> updateCoverCache({
    required String comicId,
    String? coverImageUrl,
    String? coverLocalPath,
    String? customCoverLocalPath,
  }) async {
    lastCustomCoverLocalPath = customCoverLocalPath;
  }

  @override
  Future<void> updateCustomCoverFromLocalFile({
    required String comicId,
    required String localCoverPath,
    String? sourceEpisodeId,
    int? sourceImageIndex,
    String? sourceImageUrl,
    double? focusX,
    double? focusY,
  }) async {
    lastCustomCoverLocalPath = localCoverPath;
    lastCustomCoverFocusX = focusX;
    lastCustomCoverFocusY = focusY;
  }

  @override
  Future<void> updateCustomCoverFocus({
    required String comicId,
    required double? focusX,
    required double? focusY,
  }) async {
    lastCustomCoverFocusX = focusX;
    lastCustomCoverFocusY = focusY;
  }

  @override
  Future<void> activateCustomCoverAsset({
    required String comicId,
    required int revision,
    double? focusX,
    double? focusY,
  }) async {
    lastActivatedCustomCoverRevision = revision;
  }

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<ComicDetail?> getComicDetail({required String comicId}) async {
    return ComicDetail(
      comicId: comicId,
      sourceTid: '100',
      sourceFid: '30',
      title: '测试漫画',
      author: null,
      translationGroup: null,
      coverImageUrl: null,
      updatedAt: DateTime(2026, 1, 1),
      episodeCount: 3,
    );
  }

  @override
  Future<List<ComicEpisodeItem>> getComicEpisodes({
    required String comicId,
    bool descending = true,
  }) async {
    final list =
        <ComicEpisodeItem>[
          ...(episodes ?? const <ComicEpisodeItem>[]),
          const ComicEpisodeItem(
            episodeId: 'yamibo:100:101',
            comicId: 'yamibo:100',
            episodeTitle: '第1话',
            sourceTid: '101',
            sourceUrl: 'thread-101-1-1.html',
            orderIndex: 0,
            publishTimeText: null,
          ),
          const ComicEpisodeItem(
            episodeId: 'yamibo:100:102',
            comicId: 'yamibo:100',
            episodeTitle: '第2话',
            sourceTid: '102',
            sourceUrl: 'thread-102-1-1.html',
            orderIndex: 1,
            publishTimeText: null,
          ),
          const ComicEpisodeItem(
            episodeId: 'yamibo:100:103',
            comicId: 'yamibo:100',
            episodeTitle: '第3话',
            sourceTid: '103',
            sourceUrl: 'thread-103-1-1.html',
            orderIndex: 2,
            publishTimeText: null,
          ),
        ]..removeWhere(
          (episode) =>
              episodes != null &&
              !episodes!.any((item) => item.episodeId == episode.episodeId),
        );
    list.sort(
      (a, b) => descending
          ? b.orderIndex.compareTo(a.orderIndex)
          : a.orderIndex.compareTo(b.orderIndex),
    );
    return list;
  }

  @override
  Future<List<ComicEpisodeImageItem>> getEpisodeImages({
    required String episodeId,
  }) async {
    final saved = savedImageUrlsByEpisode[episodeId];
    if (saved != null) {
      return List<ComicEpisodeImageItem>.generate(saved.length, (index) {
        return ComicEpisodeImageItem(
          episodeId: episodeId,
          imageUrl: saved[index],
          imageIndex: index,
          cacheStatus: 'none',
        );
      });
    }
    // 模拟"DB 起初无图，等 saveEpisodeImages 写入后再有图"——用来跑
    // _ensureEpisodeImages 的 fetch+save 路径。
    if (emptyEpisodeIds.contains(episodeId)) {
      return const <ComicEpisodeImageItem>[];
    }
    if (singlePage) {
      return const <ComicEpisodeImageItem>[
        ComicEpisodeImageItem(
          episodeId: 'yamibo:100:101',
          imageUrl: 'https://img.test/101-1.jpg',
          imageIndex: 0,
          cacheStatus: 'none',
        ),
      ];
    }
    final sourceTid = episodeId.split(':').last;
    return List<ComicEpisodeImageItem>.generate(imageCount, (index) {
      final page = index + 1;
      return ComicEpisodeImageItem(
        episodeId: episodeId,
        imageUrl: 'https://img.test/$sourceTid-$page.jpg',
        imageIndex: index,
        cacheStatus: 'none',
        width: index == imageCount - 1 ? lastImageWidth : null,
        height: index == imageCount - 1 ? lastImageHeight : null,
      );
    });
  }

  @override
  Future<List<ComicShelfCategory>> getCategories() async =>
      const <ComicShelfCategory>[];

  @override
  Future<ComicShelfDisplaySettings> getDisplaySettings() async {
    return const ComicShelfDisplaySettings(gridColumnCount: 3);
  }

  @override
  Future<ComicReadingProgress?> getLastReadProgress({
    required String comicId,
  }) async {
    return readingProgresses.firstOrNull;
  }

  @override
  Future<ComicReadingProgress?> getReadingProgressForEpisode({
    required String comicId,
    required String episodeId,
  }) async => readingProgresses
      .where((progress) => progress.episodeId == episodeId)
      .firstOrNull;

  @override
  Future<List<ComicReadingProgress>> getReadingProgresses({
    required String comicId,
  }) async => List<ComicReadingProgress>.unmodifiable(readingProgresses);

  @override
  Future<List<ComicShelfItem>> getShelfItems({
    String categoryId = 'default',
  }) async => const <ComicShelfItem>[];

  @override
  Future<bool> isInShelf({required String comicId}) async => false;

  @override
  Future<void> purgeWork({required String comicId}) async {}

  @override
  Future<ComicEpisodeRefreshResult> mergeEpisodesFromLinks({
    required String comicId,
    required List<ComicEpisodeLink> episodeLinks,
    required String fallbackSourceTid,
  }) async {
    return const ComicEpisodeRefreshResult(
      insertedCount: 0,
      updatedCount: 0,
      totalCount: 0,
    );
  }

  @override
  Future<void> moveComicToCategory({
    required String comicId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> saveEpisodeImages({
    required String episodeId,
    required List<String> imageUrls,
  }) async {
    savedImageUrlsByEpisode[episodeId] = List<String>.unmodifiable(imageUrls);
  }

  @override
  Future<void> replaceEpisodeImages({
    required String episodeId,
    required List<String> imageUrls,
  }) async {
    replaceEpisodeImagesCallCount += 1;
    savedImageUrlsByEpisode[episodeId] = List<String>.unmodifiable(imageUrls);
  }

  @override
  Future<void> updateCustomCover({
    required String comicId,
    required String? customCoverImageUrl,
  }) async {}
  @override
  Future<void> updateCustomMetadata({
    required String comicId,
    String? customTitle,
    String? customAuthor,
    String? customTranslationGroup,
    String? customSearchTitle,
  }) async {}
  @override
  Future<void> clearCustomMetadata({
    required String comicId,
    bool title = false,
    bool author = false,
    bool translationGroup = false,
    bool searchTitle = false,
  }) async {}

  @override
  Future<void> updateEpisodeImageCacheStatus({
    required String episodeId,
    required String imageUrl,
    required String cacheStatus,
    String? cacheLocalPath,
  }) async {
    cacheStatusWrites.add(
      _CacheStatusWrite(
        episodeId: episodeId,
        imageUrl: imageUrl,
        cacheStatus: cacheStatus,
        cacheLocalPath: cacheLocalPath,
      ),
    );
    await cacheStatusWriteGate?.future;
  }

  @override
  Future<void> updateEpisodeImageCacheMetadata({
    required String episodeId,
    required String imageUrl,
    String? stableCacheKey,
    String? lastSourceUrl,
    String? localPath,
    int? width,
    int? height,
    int? bytes,
    String? mimeType,
    DateTime? lastAccessedAt,
    bool? protected,
  }) async {
    imageMetadataWrites.add(
      _ImageMetadataWrite(
        episodeId: episodeId,
        imageUrl: imageUrl,
        width: width,
        height: height,
      ),
    );
    await metadataWriteGate?.future;
  }

  @override
  Future<void> updateGridColumnCount({required int columnCount}) async {}

  @override
  Future<void> updateLastReadProgress({
    required String comicId,
    required String episodeId,
    required int imageIndex,
    required double scrollOffset,
  }) async {
    progressWrites.add(
      _ProgressWrite(imageIndex: imageIndex, scrollOffset: scrollOffset),
    );
  }

  @override
  Future<void> updateCatalogUrl({
    required String comicId,
    required String catalogUrl,
  }) async {}

  @override
  Future<Set<String>> getKnownEpisodeTids({required String comicId}) async =>
      <String>{};
}

Future<void> _waitForCondition(
  bool Function() isReady, {
  required String label,
  int attempts = 80,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (isReady()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for $label');
}
