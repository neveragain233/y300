part of 'network_comic_episode_refresh_service_test.dart';

SearchTestResponse _searchResponseForTids(List<String> tids) =>
    SearchTestResponse(
      items: [
        for (final tid in tids)
          SearchTestTopic(
            tid: tid,
            title: '测试漫画 第${int.parse(tid) ~/ 100}话',
            url: 'https://bbs.yamibo.com/thread-$tid-1-1.html',
            fid: '30',
          ),
      ],
      rateLimited: false,
    );

NetworkComicEpisodeRefreshService _buildService({
  required ComicEpisodeDiscoveryService discoveryService,
  required ForumSearchCoordinator searchCoordinator,
  ComicSubjectParser subjectParser = const RuleBasedComicSubjectParser(),
  ComicReaderFeatureFlags featureFlags = ComicReaderFeatureFlags.defaults,
  ThreadSeedFetcher? threadSeedFetcher,
  ComicRefreshKeywordResolver? keywordResolver,
  ComicSearchCandidateRanker? candidateRanker,
  ComicEpisodeLinkMerger? episodeLinkMerger,
}) {
  final resolvedSubjectParser = subjectParser;
  return NetworkComicEpisodeRefreshService(
    discoveryService: discoveryService,
    searchService: searchCoordinator,
    keywordResolver:
        keywordResolver ??
        DefaultComicRefreshKeywordResolver(
          subjectParser: resolvedSubjectParser,
          featureFlags: featureFlags,
        ),
    candidateRanker:
        candidateRanker ?? const DefaultComicSearchCandidateRanker(),
    episodeLinkMerger:
        episodeLinkMerger ??
        DefaultComicEpisodeLinkMerger(subjectParser: resolvedSubjectParser),
    threadSeedFetcher: threadSeedFetcher,
  );
}

class _FakeDiscoveryService extends ComicEpisodeDiscoveryService {
  _FakeDiscoveryService({
    required this.byTid,
    this.strategyByTid = const <String, EpisodeDiscoveryStrategy>{},
    this.catalogUrlByTid = const <String, String>{},
    this.byCatalogUrl = const <String, List<ComicEpisodeLink>>{},
    this.directLinksByTid = const <String, List<ComicEpisodeLink>>{},
  }) : super(
         repository: const _UnusedComicThreadDiscoveryRepository(),
         opPostParser: ComicConsecutiveOpPostParser(
           engine: ComicPostParsingEngine(),
         ),
         catalogDirectoryReader: _NoopCatalogDirectoryReader(),
       );

  final Map<String, List<ComicEpisodeLink>> byTid;
  final Map<String, EpisodeDiscoveryStrategy> strategyByTid;
  final Map<String, String> catalogUrlByTid;
  final Map<String, List<ComicEpisodeLink>> byCatalogUrl;
  final Map<String, List<ComicEpisodeLink>> directLinksByTid;
  final List<String> requestedTids = <String>[];
  final List<String> requestedCatalogUrls = <String>[];
  final List<String> preloadedTids = <String>[];
  final Map<String, bool> catalogFallbackAllowedByTid = <String, bool>{};

  @override
  Future<EpisodeDiscoveryResult> discoverFromTid(String tid) async {
    requestedTids.add(tid);
    return EpisodeDiscoveryResult(
      strategy: strategyByTid[tid] ?? EpisodeDiscoveryStrategy.direct,
      episodeLinks: byTid[tid] ?? const <ComicEpisodeLink>[],
      catalogUrl: catalogUrlByTid[tid],
    );
  }

  @override
  Future<EpisodeDiscoveryResult> discoverFromTidWithPreference({
    required String tid,
    required bool preferCatalogFirst,
    bool allowCatalogFallback = true,
    FavoriteSyncRequestGovernor? governor,
    ComicThreadDiscoveryDocument? preloadedRootDetail,
    ComicThreadDiscoveryCache? threadCache,
  }) async {
    if (preloadedRootDetail != null && preloadedRootDetail.tid == tid) {
      preloadedTids.add(tid);
    } else {
      requestedTids.add(tid);
    }
    catalogFallbackAllowedByTid[tid] = allowCatalogFallback;
    return EpisodeDiscoveryResult(
      strategy: strategyByTid[tid] ?? EpisodeDiscoveryStrategy.direct,
      episodeLinks:
          preloadedRootDetail != null && preloadedRootDetail.tid == tid
          ? directLinksByTid[tid] ?? const <ComicEpisodeLink>[]
          : byTid[tid] ?? const <ComicEpisodeLink>[],
      catalogUrl: catalogUrlByTid[tid],
    );
  }

  @override
  Future<List<ComicEpisodeLink>> discoverFromCatalogUrl(
    String catalogUrl, {
    FavoriteSyncRequestGovernor? governor,
  }) async {
    requestedCatalogUrls.add(catalogUrl);
    return byCatalogUrl[catalogUrl] ?? const <ComicEpisodeLink>[];
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

final class _RecordingDiscoveryRepository
    implements ComicThreadDiscoveryRepository {
  _RecordingDiscoveryRepository(this.details);

  final Map<String, ThreadDetailData> details;
  final List<String> requestedTids = <String>[];

  @override
  ComicThreadDiscoverySourceCapabilities get capabilities =>
      ComicThreadDiscoverySourceCapabilities(
        DataCapabilitySet.supported(ComicThreadDiscoveryCapability.values),
      );

  @override
  Future<
    DataReadResult<
      ComicThreadDiscoveryDocument,
      ComicThreadDiscoveryCapabilities
    >
  >
  load(ComicThreadDiscoveryRequest request) async {
    requestedTids.add(request.sourceTid);
    final detail = details[request.sourceTid];
    if (detail == null) {
      return const DataReadFailure(
        kind: DataReadFailureKind.business,
        diagnosticMessage: 'fixture_not_found',
      );
    }
    return DataReadSuccess(
      data: const ComicThreadDiscoveryProjector().project(detail),
      capabilities: ComicThreadDiscoveryCapabilities(capabilities.values),
      metadata: const DataReadMetadata.network(),
    );
  }
}

class _NoopCatalogDirectoryReader implements ComicCatalogDirectoryReader {
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

class _FakeForumSearchCoordinator implements ForumSearchCoordinator {
  _FakeForumSearchCoordinator({required SearchTestResponse response})
    : _response = response;

  final SearchTestResponse _response;
  final List<String> calledKeywords = <String>[];
  final List<ForumSearchQuery> queries = <ForumSearchQuery>[];
  final List<bool> waitPolicies = <bool>[];

  @override
  Future<ForumSearchExecution> search(
    ForumSearchQuery query, {
    bool enforceRateLimit = true,
    bool waitForRateLimit = false,
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    calledKeywords.add(query.normalizedKeyword);
    queries.add(query);
    waitPolicies.add(waitForRateLimit);
    return _execution(query);
  }

  @override
  Future<ForumSearchExecution> loadNextPage(
    ForumSearchQuery query,
    ForumSearchPageIdentity page,
  ) async {
    return _execution(query, currentPage: page.page);
  }

  ForumSearchExecution _execution(
    ForumSearchQuery query, {
    int currentPage = 1,
  }) {
    if (_response.rateLimited) {
      return ForumSearchExecution.rateLimited(_response.retryAfter);
    }
    final data = ForumSearchData(
      query: query.normalized(),
      topics: _response.items
          .map(
            (item) => ForumSearchTopicSummary(
              tid: item.tid,
              title: item.title,
              forumId: item.fid.isEmpty ? null : item.fid,
              authorName: item.author,
              publishedAtText: item.timeText,
            ),
          )
          .toList(growable: false),
      pagination: ForumSearchPagination(currentPage: currentPage),
    );
    return ForumSearchExecution.read(
      DataReadSuccess(
        data: data,
        capabilities: ForumSearchReadCapabilities(
          values: DataCapabilitySet<ForumSearchCapability>.supported(
            ForumSearchCapability.values,
          ),
          paginationPrecision: PaginationPrecision.unknown,
        ),
        metadata: const DataReadMetadata.network(),
      ),
    );
  }
}

ThreadDetailData _threadDetail({
  required String tid,
  required String subject,
  required String message,
}) {
  return ThreadDetailData(
    tid: tid,
    fid: '30',
    typeid: '398',
    subject: subject,
    author: 'Author',
    replies: 0,
    views: 1,
    currentPage: 1,
    perPage: 20,
    posts: <ThreadPost>[
      ThreadPost(
        pid: 'p1',
        author: 'Author',
        authorId: '1',
        message: message,
        number: 1,
        isFirst: true,
        dateline: '2026-01-01',
      ),
    ],
  );
}

class _SequencedForumSearchCoordinator implements ForumSearchCoordinator {
  _SequencedForumSearchCoordinator({
    required List<SearchTestResponse> responses,
  }) : _responses = responses;

  final List<SearchTestResponse> _responses;
  final List<String> calledKeywords = <String>[];
  int _index = 0;

  @override
  Future<ForumSearchExecution> search(
    ForumSearchQuery query, {
    bool enforceRateLimit = true,
    bool waitForRateLimit = false,
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
  }) async {
    calledKeywords.add(query.normalizedKeyword);
    final response = _responses[_index.clamp(0, _responses.length - 1).toInt()];
    _index++;
    return _FakeForumSearchCoordinator(response: response)._execution(query);
  }

  @override
  Future<ForumSearchExecution> loadNextPage(
    ForumSearchQuery query,
    ForumSearchPageIdentity page,
  ) async {
    return ForumSearchExecution.read(
      DataReadSuccess(
        data: ForumSearchData(
          query: query.normalized(),
          topics: const <ForumSearchTopicSummary>[],
          pagination: ForumSearchPagination(currentPage: page.page),
        ),
        capabilities: ForumSearchReadCapabilities(
          values: DataCapabilitySet<ForumSearchCapability>.supported(
            ForumSearchCapability.values,
          ),
          paginationPrecision: PaginationPrecision.unknown,
        ),
        metadata: const DataReadMetadata.network(),
      ),
    );
  }
}

class _RecordingKeywordResolver implements ComicRefreshKeywordResolver {
  _RecordingKeywordResolver({
    List<ComicRefreshKeyword> keywords = const <ComicRefreshKeyword>[],
  }) : _keywords = keywords;

  final List<ComicRefreshKeyword> _keywords;
  int callCount = 0;
  ComicEpisodeRefreshRequest? lastRequest;
  String? lastSubject;

  @override
  List<ComicRefreshKeyword> resolve(
    ComicEpisodeRefreshRequest request,
    String subject,
  ) {
    callCount++;
    lastRequest = request;
    lastSubject = subject;
    return _keywords;
  }
}

class _RecordingCandidateRanker implements ComicSearchCandidateRanker {
  _RecordingCandidateRanker({this.candidates = const <ComicSearchCandidate>[]});

  final List<ComicSearchCandidate> candidates;

  @override
  int get discoveryTopK => 3;

  int callCount = 0;
  List<ForumSearchTopicSummary> lastItems = const <ForumSearchTopicSummary>[];

  @override
  List<ComicSearchCandidate> rank({
    required List<ForumSearchTopicSummary> items,
  }) {
    callCount++;
    lastItems = items;
    return candidates;
  }
}

class _RecordingEpisodeLinkMerger implements ComicEpisodeLinkMerger {
  _RecordingEpisodeLinkMerger()
    : _delegate = const DefaultComicEpisodeLinkMerger(
        subjectParser: RuleBasedComicSubjectParser(),
      );

  final DefaultComicEpisodeLinkMerger _delegate;
  int mergeCallCount = 0;
  int sortCallCount = 0;
  int fromSearchCandidatesCallCount = 0;

  @override
  List<ComicEpisodeLink> fromSearchCandidates(
    List<ComicSearchCandidate> candidates, {
    required String Function(String tid) threadUrlBuilder,
  }) {
    fromSearchCandidatesCallCount++;
    return _delegate.fromSearchCandidates(
      candidates,
      threadUrlBuilder: threadUrlBuilder,
    );
  }

  @override
  List<ComicEpisodeLink> merge(
    List<ComicEpisodeLink> primary,
    List<ComicEpisodeLink> supplement, {
    bool preferSupplement = false,
  }) {
    mergeCallCount++;
    return _delegate.merge(
      primary,
      supplement,
      preferSupplement: preferSupplement,
    );
  }

  @override
  List<ComicEpisodeLink> sort(List<ComicEpisodeLink> links) {
    sortCallCount++;
    return _delegate.sort(links);
  }
}
