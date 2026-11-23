import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/features/comic/domain/models/comic_detail_models.dart';
import 'package:y300/features/comic/domain/models/comic_download_queue_models.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/models/comic_shelf_models.dart';
import 'package:y300/features/comic/domain/repositories/comic_catalog_directory_reader.dart';
import 'package:y300/features/comic/domain/services/bulk_download_use_case.dart';
import 'package:y300/features/comic/domain/services/comic_consecutive_op_post_parser.dart';
import 'package:y300/features/comic/domain/services/comic_download_queue.dart';
import 'package:y300/features/comic/domain/services/comic_episode_discovery_service.dart';
import 'package:y300/features/comic/domain/services/comic_incremental_episode_discovery.dart';
import 'package:y300/features/comic/domain/services/comic_post_parsing_engine.dart';
import 'package:y300/features/comic/domain/services/comic_refresh_outcome_applier.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_models.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_service.dart';
import 'package:y300/features/comic/domain/services/comic_reader_feature_flags.dart';
import 'package:y300/features/comic/domain/services/comic_episode_refresh_service.dart';
import 'package:y300/features/comic/domain/services/comic_thread_discovery_cache.dart';
import 'package:y300/features/comic/domain/services/comic_first_episode_cover_service.dart';
import 'package:y300/features/favorites/domain/services/favorite_sync_request_governor.dart';
import 'package:y300/features/comic/presentation/adapters/comic_detail_adapter.dart';
import 'package:y300/features/library_shared/domain/repositories/library_state_repository.dart';
import 'package:y300/features/library_shared/domain/contracts/detail_module_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/models/library_state_models.dart';

part 'comic_detail_adapter_source_metadata_cases.dart';
part 'comic_detail_adapter_refresh_discovery_cases.dart';
part 'comic_detail_adapter_header_reader_route_cases.dart';
part 'comic_detail_adapter_reading_state_cases.dart';
part 'comic_detail_adapter_download_queue_cases.dart';
part 'comic_detail_adapter_chapter_list_cases.dart';

void main() {
  _sourceMetadataCases();
  _refreshDiscoveryCases();
  _headerAndReaderRouteCases();
  _readingStateCases();
  _downloadQueueCases();
  _chapterListCases();
}

class _FakeComicEpisodeRefreshService implements ComicEpisodeRefreshService {
  _FakeComicEpisodeRefreshService({
    ComicEpisodeRefreshOutcome? catalogOutcome,
    ComicEpisodeRefreshOutcome? searchOutcome,
  }) : _catalogOutcome = catalogOutcome,
       _searchOutcome = searchOutcome;

  String? requestedTid;
  ComicEpisodeRefreshRequest? lastRequest;
  int catalogOnlyCalls = 0;
  int fetchEpisodeLinksCalls = 0;
  int searchAndCurrentOnlyCalls = 0;
  final ComicEpisodeRefreshOutcome? _catalogOutcome;
  final ComicEpisodeRefreshOutcome? _searchOutcome;

  @override
  Future<List<ComicEpisodeLink>> fetchEpisodeLinks(
    ComicEpisodeRefreshRequest request,
  ) async {
    fetchEpisodeLinksCalls++;
    lastRequest = request;
    requestedTid = request.sourceTid;
    return const [
      ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
      ComicEpisodeLink(url: 'thread-102-1-1.html', rawText: '第2话'),
    ];
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogThenFallback(
    ComicEpisodeRefreshRequest request,
  ) async {
    lastRequest = request;
    requestedTid = request.sourceTid;
    final catalog = await fetchCatalogOnly(request);
    if (catalog.catalogMatched && catalog.hasLinks) {
      return catalog;
    }
    return fetchSearchAndCurrentOnly(request);
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogOnly(
    ComicEpisodeRefreshRequest request, {
    FavoriteSyncExecutionContext? executionContext,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    catalogOnlyCalls++;
    lastRequest = request;
    requestedTid = request.sourceTid;
    final outcome = _catalogOutcome;
    if (outcome != null) {
      return outcome;
    }
    return const ComicEpisodeRefreshOutcome(
      source: ComicEpisodeRefreshSource.catalog,
      links: [
        ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
        ComicEpisodeLink(url: 'thread-102-1-1.html', rawText: '第2话'),
      ],
      catalogMatched: true,
    );
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchSearchAndCurrentOnly(
    ComicEpisodeRefreshRequest request, {
    FavoriteSyncExecutionContext? executionContext,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    searchAndCurrentOnlyCalls++;
    lastRequest = request;
    requestedTid = request.sourceTid;
    final outcome = _searchOutcome;
    if (outcome != null) {
      return outcome;
    }
    final links = await fetchEpisodeLinks(request);
    return ComicEpisodeRefreshOutcome(
      source: ComicEpisodeRefreshSource.search,
      links: links,
      usedSearch: true,
    );
  }

  @override
  Future<List<ComicEpisodeLink>> fetchEpisodeLinksFromTid(String tid) async {
    return fetchEpisodeLinks(ComicEpisodeRefreshRequest(sourceTid: tid));
  }

  @override
  Future<ComicEpisodeRefreshOutcome> fetchCatalogDirect(
    String catalogUrl, {
    FavoriteSyncExecutionContext? executionContext,
  }) async {
    return ComicEpisodeRefreshOutcome(
      source: ComicEpisodeRefreshSource.catalog,
      links: const <ComicEpisodeLink>[
        ComicEpisodeLink(url: 'thread-101-1-1.html', rawText: '第1话'),
        ComicEpisodeLink(url: 'thread-102-1-1.html', rawText: '第2话'),
      ],
      catalogMatched: true,
      catalogUrl: catalogUrl,
    );
  }
}

class _RecordingRefreshOutcomeApplier implements ComicRefreshOutcomeApplier {
  final List<ComicRefreshApplyRequest> requests = <ComicRefreshApplyRequest>[];

  @override
  Future<ComicRefreshApplyResult> apply(
    ComicRefreshApplyRequest request,
  ) async {
    requests.add(request);
    return ComicRefreshApplyResult(
      status: ComicRefreshApplyStatus.applied,
      insertedCount: request.links.length,
      updatedCount: 0,
      totalCount: request.links.length,
      coverPromoted: false,
    );
  }
}

class _RecordingSearchQueue implements ComicSearchRefreshQueueEnqueuer {
  final List<ComicEpisodeRefreshRequest> enqueuedRequests =
      <ComicEpisodeRefreshRequest>[];
  final List<String> enqueuedTitles = <String>[];
  final List<ComicSearchRefreshOrigin> enqueuedOrigins =
      <ComicSearchRefreshOrigin>[];

  @override
  Future<ComicSearchRefreshEnqueueResult> enqueue({
    required ComicEpisodeRefreshRequest request,
    required String title,
    required ComicSearchRefreshOrigin origin,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
  }) async {
    enqueuedRequests.add(request);
    enqueuedTitles.add(title);
    enqueuedOrigins.add(origin);
    return ComicSearchRefreshEnqueueResult(
      entry: ComicSearchRefreshQueueEntry(
        id: enqueuedRequests.length,
        comicId: request.comicId ?? '',
        title: title,
        request: request,
        origin: origin,
        status: ComicSearchRefreshQueueStatus.pending,
        attempts: 0,
        availableAt: DateTime(2026, 5, 16),
        createdAt: DateTime(2026, 5, 16),
        updatedAt: DateTime(2026, 5, 16),
      ),
      position: 2,
      estimatedDuration: const Duration(seconds: 21),
      deduplicated: false,
    );
  }
}

class _FakeComicRepository
    implements
        ComicRepository,
        ComicCatalogOverrideRepository,
        ComicReadingProgressResetter,
        ComicWorkReadingStateResetter {
  _FakeComicRepository({
    this.progress,
    this.progresses,
    this.title = 'Test Comic',
    this.imageCountByEpisodeId = const <String, int>{},
    this.catalogUrl,
    this.customCatalogUrl,
  });

  final ComicReadingProgress? progress;
  final List<ComicReadingProgress>? progresses;
  final String title;
  final Map<String, int> imageCountByEpisodeId;
  final String? catalogUrl;
  final String? customCatalogUrl;
  String? lastCustomCatalogUrl;
  bool mergeCalled = false;
  List<ComicEpisodeLink> lastMergedLinks = const [];
  String? lastFallbackTid;
  final List<String> clearedProgress = <String>[];
  final List<String> resetComicIds = <String>[];

  @override
  Future<ComicDetail?> getComicDetail({required String comicId}) async {
    return ComicDetail(
      comicId: comicId,
      sourceTid: '100',
      sourceFid: '30',
      sourceTypeId: '398',
      sourceTagName: '韩国漫画',
      title: title,
      sourceTitle: 'Source Test Comic',
      customTitle: 'Custom Test Comic',
      author: 'Author A',
      sourceAuthor: 'Source Author',
      customAuthor: 'Custom Author',
      translationGroup: 'Group A',
      sourceTranslationGroup: 'Source Group',
      customTranslationGroup: 'Custom Group',
      customSearchTitle: 'Search Test Comic',
      coverImageUrl: null,
      updatedAt: DateTime(2026, 1, 1),
      episodeCount: 0,
      catalogUrl: catalogUrl,
      customCatalogUrl: customCatalogUrl,
    );
  }

  @override
  Future<ComicEpisodeRefreshResult> mergeEpisodesFromLinks({
    required String comicId,
    required List<ComicEpisodeLink> episodeLinks,
    required String fallbackSourceTid,
  }) async {
    mergeCalled = true;
    lastMergedLinks = episodeLinks;
    lastFallbackTid = fallbackSourceTid;
    return const ComicEpisodeRefreshResult(
      insertedCount: 2,
      updatedCount: 0,
      totalCount: 2,
    );
  }

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
  Future<void> purgeWork({required String comicId}) async {}
  @override
  Future<String> createCategory({required String name}) async => 'c1';
  @override
  Future<void> clearEpisodeImageCache({required String episodeId}) async {}
  @override
  Future<void> deleteCategory({required String categoryId}) async {}
  @override
  Future<List<ComicShelfCategory>> getCategories() async => const [];
  @override
  Future<ComicShelfDisplaySettings> getDisplaySettings() async =>
      const ComicShelfDisplaySettings(gridColumnCount: 3);
  @override
  Future<List<ComicEpisodeItem>> getComicEpisodes({
    required String comicId,
    bool descending = true,
  }) async {
    return const <ComicEpisodeItem>[
      ComicEpisodeItem(
        episodeId: 'comic:1:120',
        comicId: 'comic:1',
        episodeTitle: '后续',
        sourceTid: '120',
        sourceUrl: 'thread-120-1-1.html',
        orderIndex: 0,
        publishTimeText: null,
      ),
      ComicEpisodeItem(
        episodeId: 'comic:1:90',
        comicId: 'comic:1',
        episodeTitle: '首话',
        sourceTid: '90',
        sourceUrl: 'thread-90-1-1.html',
        orderIndex: 1,
        publishTimeText: null,
      ),
    ];
  }

  @override
  Future<List<ComicEpisodeImageItem>> getEpisodeImages({
    required String episodeId,
  }) async {
    final imageCount = imageCountByEpisodeId[episodeId] ?? 1;
    return List<ComicEpisodeImageItem>.generate(
      imageCount,
      (index) => ComicEpisodeImageItem(
        episodeId: episodeId,
        imageUrl: episodeId.endsWith(':90')
            ? 'https://img.test/90-${index + 1}.jpg'
            : 'https://img.test/120-${index + 1}.jpg',
        imageIndex: index,
        cacheStatus: 'none',
      ),
    );
  }

  @override
  Future<ComicReadingProgress?> getLastReadProgress({
    required String comicId,
  }) async =>
      progress ?? (progresses?.isEmpty == false ? progresses!.first : null);

  @override
  Future<ComicReadingProgress?> getReadingProgressForEpisode({
    required String comicId,
    required String episodeId,
  }) async {
    final candidates = await getReadingProgresses(comicId: comicId);
    return candidates.where((item) => item.episodeId == episodeId).firstOrNull;
  }

  @override
  Future<List<ComicReadingProgress>> getReadingProgresses({
    required String comicId,
  }) async =>
      progresses ??
      (progress == null
          ? const <ComicReadingProgress>[]
          : <ComicReadingProgress>[progress!]);
  @override
  Future<List<ComicShelfItem>> getShelfItems({
    String categoryId = 'default',
  }) async => const [];
  @override
  Future<bool> isInShelf({required String comicId}) async => true;
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
  }) async {}
  @override
  Future<void> updateCustomCover({
    required String comicId,
    required String? customCoverImageUrl,
  }) async {}
  @override
  Future<void> updateCustomCoverFromLocalFile({
    required String comicId,
    required String localCoverPath,
    String? sourceEpisodeId,
    int? sourceImageIndex,
    String? sourceImageUrl,
    double? focusX,
    double? focusY,
  }) async {}
  @override
  Future<void> updateCustomCoverFocus({
    required String comicId,
    required double? focusX,
    required double? focusY,
  }) async {}
  @override
  Future<void> updateCustomMetadata({
    required String comicId,
    String? customTitle,
    String? customAuthor,
    String? customTranslationGroup,
    String? customOriginalWork,
    String? customSearchTitle,
  }) async {}
  @override
  Future<void> clearCustomMetadata({
    required String comicId,
    bool title = false,
    bool author = false,
    bool translationGroup = false,
    bool originalWork = false,
    bool searchTitle = false,
  }) async {}
  @override
  Future<void> updateEpisodeImageCacheStatus({
    required String episodeId,
    required String imageUrl,
    required String cacheStatus,
    String? cacheLocalPath,
  }) async {}
  @override
  Future<void> updateGridColumnCount({required int columnCount}) async {}
  @override
  Future<void> updateLastReadProgress({
    required String comicId,
    required String episodeId,
    required int imageIndex,
    required double scrollOffset,
  }) async {}

  @override
  Future<void> clearReadingProgress({
    required String comicId,
    required String episodeId,
  }) async {
    clearedProgress.add(episodeId);
  }

  @override
  Future<void> resetComicReadingState({required String comicId}) async {
    resetComicIds.add(comicId);
  }

  @override
  Future<void> updateCatalogUrl({
    required String comicId,
    required String catalogUrl,
  }) async {}

  @override
  Future<void> updateCustomCatalogUrl({
    required String comicId,
    required String? catalogUrl,
  }) async {
    lastCustomCatalogUrl = catalogUrl;
  }

  @override
  Future<Set<String>> getKnownEpisodeTids({required String comicId}) async =>
      <String>{};
}

class _FakeComicRepositoryWithCoverWriter extends _FakeComicRepository
    implements ComicCoverCacheWriter {
  _FakeComicRepositoryWithCoverWriter({this.customCoverImageUrl});

  final String? customCoverImageUrl;
  String? lastCoverImageUrl;
  String? lastCoverLocalPath;
  String? lastCustomCoverLocalPath;

  @override
  Future<ComicDetail?> getComicDetail({required String comicId}) async {
    final detail = await super.getComicDetail(comicId: comicId);
    if (detail == null) {
      return null;
    }
    return ComicDetail(
      comicId: detail.comicId,
      sourceTid: detail.sourceTid,
      sourceFid: detail.sourceFid,
      sourceTypeId: detail.sourceTypeId,
      sourceTagName: detail.sourceTagName,
      title: detail.title,
      sourceTitle: detail.sourceTitle,
      customTitle: detail.customTitle,
      author: detail.author,
      sourceAuthor: detail.sourceAuthor,
      customAuthor: detail.customAuthor,
      translationGroup: detail.translationGroup,
      sourceTranslationGroup: detail.sourceTranslationGroup,
      customTranslationGroup: detail.customTranslationGroup,
      customSearchTitle: detail.customSearchTitle,
      coverImageUrl: customCoverImageUrl ?? detail.coverImageUrl,
      customCoverImageUrl: customCoverImageUrl,
      coverLocalPath: detail.coverLocalPath,
      customCoverLocalPath: detail.customCoverLocalPath,
      updatedAt: detail.updatedAt,
      episodeCount: detail.episodeCount,
    );
  }

  @override
  Future<void> updateCoverCache({
    required String comicId,
    String? coverImageUrl,
    String? coverLocalPath,
    String? customCoverLocalPath,
  }) async {
    lastCoverImageUrl = coverImageUrl;
    lastCoverLocalPath = coverLocalPath;
    lastCustomCoverLocalPath = customCoverLocalPath;
  }
}

class _FakeLibraryStateRepository implements LibraryStateRepository {
  _FakeLibraryStateRepository({
    this.workState,
    this.episodeStates = const <String, LibraryEpisodeState>{},
  });

  final LibraryWorkState? workState;
  final Map<String, LibraryEpisodeState> episodeStates;

  @override
  Future<void> bindTagToWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  }) async {}
  @override
  Future<int> countDownloadedEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async => 0;
  @override
  Future<int> countReadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async => 0;
  @override
  Future<int> countUnreadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async => 0;
  @override
  Future<void> purgeWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {}
  @override
  Future<void> setWorksReadState({
    required LibraryModuleKey moduleKey,
    required Set<String> workIds,
    required bool isRead,
    DateTime? readAt,
  }) async {}
  @override
  Future<String> createTag({required String name}) async => 't1';
  @override
  Future<void> deleteTag({required String tagId}) async {}
  @override
  Future<LibraryModuleDisplaySettings> getDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode defaultDisplayMode,
  }) async => LibraryModuleDisplaySettings(
    moduleKey: moduleKey,
    displayMode: defaultDisplayMode,
    gridColumns: 3,
    updatedAt: DateTime(2026, 1, 1),
  );
  @override
  Future<LibraryEpisodeState?> getEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
  }) async => episodeStates[episodeId];
  @override
  Future<List<LibraryTag>> getTags() async => const [];
  @override
  Future<LibraryWorkState?> getWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async => workState;
  @override
  Future<List<LibraryTag>> getWorkTags({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async => const [];
  @override
  Future<bool> hasAnyTag({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async => false;
  @override
  Future<void> renameTag({
    required String tagId,
    required String newName,
  }) async {}
  @override
  Future<void> unbindTagFromWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  }) async {}
  @override
  Future<void> upsertDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode displayMode,
    required int gridColumns,
  }) async {}
  @override
  Future<void> upsertEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
    required String workId,
    bool? isRead,
    bool? isDownloaded,
    bool? isBookmarked,
    DateTime? readAt,
    DateTime? downloadedAt,
  }) async {}
  @override
  Future<void> upsertWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
    String? lastReadEpisodeId,
    DateTime? lastReadAt,
    DateTime? checkUpdatedAt,
    DateTime? fetchedUpdatedAt,
    String? introText,
  }) async {}
}

class _RecordingLibraryStateRepository extends _FakeLibraryStateRepository {
  _RecordingLibraryStateRepository({super.episodeStates});

  final List<String> downloadedEpisodeIds = <String>[];

  @override
  Future<void> upsertEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
    required String workId,
    bool? isRead,
    bool? isDownloaded,
    bool? isBookmarked,
    DateTime? readAt,
    DateTime? downloadedAt,
  }) async {
    if (isDownloaded == true) {
      downloadedEpisodeIds.add(episodeId);
    }
  }
}

class _RecordingChapterResetStateRepository
    extends _FakeLibraryStateRepository {
  String? lastEpisodeId;
  bool? lastIsRead;
  DateTime? lastReadAt;

  @override
  Future<void> upsertEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
    required String workId,
    bool? isRead,
    bool? isDownloaded,
    bool? isBookmarked,
    DateTime? readAt,
    DateTime? downloadedAt,
  }) async {
    lastEpisodeId = episodeId;
    lastIsRead = isRead;
    lastReadAt = readAt;
  }
}

class _RecordingRangeStateRepository extends _FakeLibraryStateRepository
    implements LibraryEpisodeRangeReadStateRepository {
  String? lastWorkId;
  Set<String> lastEpisodeIds = <String>{};
  DateTime? lastReadAt;
  final List<Set<String>> restoreCalls = <Set<String>>[];

  @override
  Future<List<String>> setEpisodesReadState({
    required LibraryModuleKey moduleKey,
    required String workId,
    required Set<String> episodeIds,
    required bool isRead,
    DateTime? readAt,
  }) async {
    lastWorkId = workId;
    lastEpisodeIds = Set<String>.from(episodeIds);
    lastReadAt = readAt;
    return episodeIds.toList(growable: false);
  }

  @override
  Future<void> restoreEpisodesReadState({
    required LibraryModuleKey moduleKey,
    required String workId,
    required Set<String> episodeIds,
    required DateTime readAt,
  }) async {
    restoreCalls.add(Set<String>.from(episodeIds));
  }
}

class _RecordingBulkDownloadUseCase implements BulkDownloadUseCase {
  final List<Set<String>> requestedComicIds = <Set<String>>[];

  @override
  Future<BulkDownloadResult> downloadComics(Set<String> comicIds) async {
    requestedComicIds.add(Set<String>.from(comicIds));
    return BulkDownloadResult(
      requestedCount: comicIds.length,
      enqueuedCount: 0,
      deduplicatedCount: 0,
      skippedDownloadedCount: 0,
    );
  }
}

class _RecordingComicDownloadQueue implements ComicDownloadQueue {
  final ValueNotifier<ComicDownloadQueueSnapshot> _snapshot =
      ValueNotifier<ComicDownloadQueueSnapshot>(
        ComicDownloadQueueSnapshot.empty,
      );
  final List<ComicDownloadTarget> targets = <ComicDownloadTarget>[];

  void setStatus(ComicDownloadQueueStatus status) {
    final now = DateTime(2026, 7, 22);
    _snapshot.value = ComicDownloadQueueSnapshot(
      entries: <ComicDownloadQueueEntry>[
        ComicDownloadQueueEntry(
          id: 1,
          comicId: 'comic:1',
          episodeId: 'comic:1:120',
          comicTitle: 'Test Comic',
          episodeTitle: '后续',
          status: status,
          completedImages: 0,
          totalImages: null,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
  }

  @override
  ValueListenable<ComicDownloadQueueSnapshot> get snapshot => _snapshot;

  @override
  Future<ComicDownloadEnqueueResult> enqueueTargets(
    Iterable<ComicDownloadTarget> targets,
  ) async {
    final entries = targets.toList(growable: false);
    this.targets.addAll(entries);
    return ComicDownloadEnqueueResult(
      requestedCount: entries.length,
      enqueuedCount: entries.length,
      deduplicatedCount: 0,
      skippedDownloadedCount: 0,
    );
  }

  @override
  Future<void> cancel(int taskId) async {}

  @override
  Future<void> cancelComic(String comicId) async {}

  @override
  Future<void> cancelEpisode(String comicId, String episodeId) async {}

  @override
  Future<void> remove(int taskId) async {}

  @override
  Future<void> retry(int taskId) async {}

  @override
  Future<void> start() async {}
}

class _FakeDiscoveryService extends ComicEpisodeDiscoveryService {
  _FakeDiscoveryService({this.threadResult})
    : super(
        repository: const _UnusedComicThreadDiscoveryRepository(),
        opPostParser: ComicConsecutiveOpPostParser(
          engine: ComicPostParsingEngine(),
        ),
        catalogDirectoryReader: _FakeCatalogDirectoryReader(),
      );

  final ParsedThreadResult? threadResult;
  int fetchAndParseThreadCalls = 0;

  @override
  Future<ParsedThreadResult?> fetchAndParseThread(String tid) async {
    fetchAndParseThreadCalls++;
    return threadResult;
  }
}

class _FakeCatalogDirectoryReader implements ComicCatalogDirectoryReader {
  @override
  Future<
    DataReadResult<ComicCatalogDirectory, ComicCatalogDirectoryCapabilities>
  >
  load(ComicCatalogDirectoryRequest request) async => DataReadSuccess(
    data: const ComicCatalogDirectory(links: <ComicEpisodeLink>[]),
    capabilities: ComicCatalogDirectoryCapabilities(
      values: DataCapabilitySet.supported(
        ComicCatalogDirectoryCapability.values,
      ),
    ),
    metadata: const DataReadMetadata.network(),
  );
}

class _FakeIncrementalDiscovery extends ComicIncrementalEpisodeDiscovery {
  _FakeIncrementalDiscovery({this.directResult = const <ComicEpisodeLink>[]})
    : super(
        repository: const _UnusedComicThreadDiscoveryRepository(),
        opPostParser: ComicConsecutiveOpPostParser(
          engine: ComicPostParsingEngine(),
        ),
      );

  final List<ComicEpisodeLink> directResult;

  @override
  List<ComicEpisodeLink> discoverDirectIncremental({
    required List<ComicEpisodeLink> currentLinks,
    required Set<String> knownTids,
  }) {
    return directResult;
  }

  @override
  Future<List<ComicEpisodeLink>> discoverRecursiveIncremental({
    required String startTid,
    required Set<String> knownTids,
  }) async {
    return const <ComicEpisodeLink>[];
  }
}

final class _UnusedComicThreadDiscoveryRepository
    implements ComicThreadDiscoveryRepository {
  const _UnusedComicThreadDiscoveryRepository();

  @override
  ComicThreadDiscoverySourceCapabilities get capabilities =>
      ComicThreadDiscoverySourceCapabilities(
        DataCapabilitySet<ComicThreadDiscoveryCapability>.from(
          unsupported: ComicThreadDiscoveryCapability.values,
        ),
      );

  @override
  Future<
    DataReadResult<
      ComicThreadDiscoveryDocument,
      ComicThreadDiscoveryCapabilities
    >
  >
  load(ComicThreadDiscoveryRequest request) {
    throw UnimplementedError();
  }
}

ThreadDetailData _threadDetailWithTags(List<ThreadPostTagLink> tags) {
  return ThreadDetailData(
    tid: '100',
    fid: '30',
    subject: 'Source thread',
    author: 'Author',
    replies: 0,
    views: 1,
    currentPage: 1,
    perPage: 10,
    posts: [
      ThreadPost(
        pid: 'p1',
        author: 'Author',
        authorId: '1',
        message: '<p>body</p>',
        number: 1,
        isFirst: true,
        dateline: 'today',
        tagLinks: tags,
      ),
    ],
  );
}

final class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository(this.detail);

  final ThreadDetailData detail;
  final List<String> requestedTids = <String>[];

  @override
  ThreadDetailSourceCapabilities get capabilities =>
      ThreadDetailSourceCapabilities.full;

  @override
  Future<DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities>>
  getThreadDetail({
    required String tid,
    int page = 1,
    ThreadDetailQuery query = const ThreadDetailQuery(),
  }) async {
    requestedTids.add(tid);
    return DataReadSuccess<ThreadDetailData, ThreadDetailReadCapabilities>(
      data: detail,
      capabilities: ThreadDetailReadCapabilities(
        values: DataCapabilitySet.supported(ThreadDetailCapability.values),
        paginationPrecision: PaginationPrecision.unknown,
      ),
      metadata: const DataReadMetadata.network(),
    );
  }
}
