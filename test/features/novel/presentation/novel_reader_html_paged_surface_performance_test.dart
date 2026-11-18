import 'dart:async';

import 'package:flutter/material.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/domain/models/novel_reader_document.dart';
import 'package:y300/features/novel/domain/services/novel_reader_progress_policy.dart';
import 'package:y300/features/novel/domain/models/novel_reader_marks.dart';
import 'package:y300/features/novel/domain/models/novel_reader_anchor_format.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_anchor_navigation_request.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_page_fragment.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_pagination_key.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_pagination_diagnostics.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_pagination_plan.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_pagination_position.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_pagination_progress.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_prepared_chapter.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_conversion_position.dart';
import 'package:y300/features/novel/presentation/services/novel_forum_html_render_theme_factory.dart';
import 'package:y300/features/novel/presentation/services/novel_html_reader_preferences_adapter.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_html_preparation_service.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_complex_html_boundary_cache.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_cache.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_measure_adapter.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_session_cache.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_prepared_chapter_cache.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_performance_policy.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_coordinator.dart';
import 'package:y300/features/novel/presentation/widgets/novel_reader_html_paged_surface.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_models.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';

part 'novel_reader_html_paged_surface_performance_geometry_cases.dart';
part 'novel_reader_html_paged_surface_performance_image_first_frame_cases.dart';
part 'novel_reader_html_paged_surface_performance_conversion_restore_cases.dart';
part 'novel_reader_html_paged_surface_performance_missing_page_wait_cases.dart';
part 'novel_reader_html_paged_surface_performance_background_backfill_cases.dart';
part 'novel_reader_html_paged_surface_performance_restore_anchor_cases.dart';

void main() {
  _pagedGeometryCases();
  _imageFirstFrameCases();
  _innerPageGeometryCases();
  _conversionRestoreCases();
  _layoutRebindCases();
  _conversionProvenanceCases();
  _paginationGeometryInsetsCases();
  _inlineMediaFirstFrameCases();
  _missingPageWaitCases();
  _claimedTurnRestoreCases();
  _missingPageRetirementCases();
  _layoutInputRebindCases();
  _backgroundBackfillCases();
  _disabledBudgetWaitCases();
  _restoreAnchorCases();
}

const _episode = NovelEpisodeItem(
  episodeId: 'performance-episode',
  novelId: 'performance-novel',
  sourceTid: '6300',
  episodeTitle: '性能降级',
  orderIndex: 0,
);

const _budgetPageTexts = <String>['第一页', '恢复目标页', '尾页'];
const _budgetRawHtml = '<p>第一页</p><p>恢复目标页</p><p>尾页</p>';

NovelReaderAnchorNavigationRequest _budgetNavigation(
  int requestId,
  int index,
) => NovelReaderAnchorNavigationRequest(
  requestId: requestId,
  anchor: NovelReaderTextAnchor(
    episodeId: _episode.episodeId,
    nodeId: 'paragraph-$index',
    formatVersion: 1,
    textIdentity: NovelReaderAnchorFormat.textIdentity(_budgetPageTexts[index]),
  ),
);

Future<NovelReaderPreparedChapter> _conversionChapter(
  _BudgetSurfaceHost host,
  String html,
) => const DefaultNovelReaderHtmlPreparationService().prepare(
  rawHtml: html,
  episode: _episode,
  preferences: const NovelHtmlReaderPreferencesAdapter().map(
    host.preferences.copyWith(conversionMode: NovelReaderConversionMode.none),
  ),
  theme: host.htmlTheme,
  sourceId: _episode.episodeId,
  threadId: _episode.sourceTid,
  imageCacheOwnerId: _episode.sourceTid,
);

Future<void> _pumpBudgetHost(
  WidgetTester tester,
  _BudgetSurfaceHost host,
) async {
  await tester.pumpWidget(host.build());
  await tester.pump();
  await tester.pump();
}

void _disposeBudgetHost(
  WidgetTester tester,
  _BudgetPaginationCoordinator coordinator,
) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await coordinator.close();
  });
}

final class _BudgetSurfaceHost {
  _BudgetSurfaceHost(
    this.coordinator, {
    this.targetPageWait = const Duration(milliseconds: 50),
    this.backgroundIdle = const Duration(milliseconds: 100),
    this.enforceBudgets = true,
    this.preparationService,
  }) {
    theme = ThemeData.light();
    final palette = const NovelReaderThemeResolver().resolve(
      preferences: preferences,
      theme: theme,
    );
    typography = const NovelReaderTypographyResolver().resolve(
      preferences: preferences,
      theme: theme,
      palette: palette,
    );
    htmlTheme = const NovelForumHtmlRenderThemeFactory().fromPalette(palette);
    coordinatorBuilder =
        ({
          required BuildContext context,
          required ForumHtmlThemeContext theme,
          required ForumHtmlReaderPreferences preferences,
          required String sourceId,
          required String? threadId,
          required String? imageCacheOwnerId,
          required String? imageReferer,
        }) {
          coordinatorBuildCount += 1;
          return coordinator;
        };
  }

  final _BudgetPaginationCoordinator coordinator;
  final Duration targetPageWait;
  final Duration backgroundIdle;
  final bool enforceBudgets;
  final NovelReaderHtmlPreparationService? preparationService;
  var preferences = NovelReaderPreferences.defaults().copyWith(
    flowMode: NovelReaderFlowMode.pagedLtr,
  );
  late final ThemeData theme;
  late NovelReaderTypography typography;
  late final ForumHtmlThemeContext htmlTheme;
  late final NovelReaderPaginationCoordinatorBuilder coordinatorBuilder;
  final positions = <NovelReaderPaginationPosition>[];
  final imagesReady = <bool>[];
  final scrollActivity = <bool>[];
  ForumHtmlImageHost? imageHost;
  final conversionPositions = <NovelReaderConversionPosition>[];
  NovelReaderConversionPosition? conversionPosition;
  String rawHtml = _budgetRawHtml;
  final navigation = NovelReaderPagedNavigationController();
  int scrollChoices = 0;
  int coordinatorBuildCount = 0;
  TextDirection direction = TextDirection.ltr;
  bool allowChapterTurns = false;
  int chapterTurns = 0;
  NovelReaderAnchorNavigationRequest? navigationRequest;
  NovelReaderPageSeekRequest? pageSeekRequest;
  NovelReaderDocument? semanticDocument;
  NovelReaderPaginationCache? paginationCache;
  NovelReaderPaginationMeasureCache? measureCache;
  NovelReaderComplexHtmlBoundaryCache? boundaryCache;
  NovelReaderPreparedChapterCache? preparedCache;
  bool useDefaultCoordinator = false;
  NovelReaderPaginationDiagnosticsSink diagnosticsSink =
      const NovelReaderNoopPaginationDiagnosticsSink();
  NovelReaderProgressSnapshot snapshot = const NovelReaderProgressSnapshot(
    novelId: 'performance-novel',
    episodeId: 'performance-episode',
    flowMode: NovelReaderFlowMode.pagedLtr,
    scrollOffset: 0,
    pageIndex: 0,
    progressPercent: 0,
  );

  Widget build() => LocalizedTestApp(
    theme: theme,
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: NovelReaderHtmlPagedSurface(
          rawHtml: rawHtml,
          semanticDocument: semanticDocument,
          conversionPosition: conversionPosition,
          onConversionPositionChanged: conversionPositions.add,
          episode: _episode,
          preferences: preferences,
          typography: typography,
          theme: htmlTheme,
          imageReferer: 'https://bbs.yamibo.com/',
          progressSnapshot: snapshot,
          navigationRequest: navigationRequest,
          pageSeekRequest: pageSeekRequest,
          navigationController: navigation,
          nextChapterTitle: allowChapterTurns ? _episode.episodeTitle : null,
          onTurnToAdjacentChapter: allowChapterTurns
              ? (_) {
                  chapterTurns += 1;
                  return false;
                }
              : null,
          coordinatorBuilder: useDefaultCoordinator ? null : coordinatorBuilder,
          preparationService: preparationService,
          paginationCache: paginationCache,
          paginationMeasureCache: measureCache,
          paginationBoundaryCache: boundaryCache,
          preparedChapterCache: preparedCache,
          diagnosticsSink: diagnosticsSink,
          performancePolicy: NovelReaderPaginationPerformancePolicy(
            targetPageWait: targetPageWait,
            backgroundIdle: backgroundIdle,
            enforceBudgets: enforceBudgets,
          ),
          onPositionChanged: positions.add,
          onImagesReadyChanged: imagesReady.add,
          onScrollActivityChanged: scrollActivity.add,
          imageHost: imageHost,
          onChooseScrollMode: () {
            scrollChoices += 1;
          },
        ),
      ),
    ),
  );
}

final class _ControlledPagedImageHost implements ForumHtmlImageHost {
  final frames = <String, ValueNotifier<int>>{};
  void show(String url) => frames[url]!.value = 1;
  void fail(String url) => frames[url]!.value = -1;
  void dispose() {
    for (final frame in frames.values) {
      frame.dispose();
    }
  }

  @override
  ForumHtmlDisplayImage? resolveImage({
    required Uri url,
    required int? imageIndex,
    required bool isSticker,
    Size? htmlSize,
  }) => _ControlledPagedDisplayImage(url.toString(), isSticker, htmlSize);

  @override
  Future<({Size size, ForumHtmlImageLayout layout})?> loadDimensions(
    ForumHtmlDisplayImage image,
  ) async => null;

  @override
  void onBlockImageResolved(ForumHtmlDisplayImage image, Size size) {}

  @override
  Future<void> prefetchDisk(
    ForumHtmlDisplayImage image, {
    required ForumHtmlImageWorkScope scope,
  }) async {}

  @override
  Widget buildImage({
    required ForumHtmlDisplayImage image,
    required BoxFit fit,
    required Widget placeholder,
    double? width,
    double? height,
    Widget? errorPlaceholder,
    VoidCallback? onRetry,
    ValueChanged<Size>? onImageResolved,
    VoidCallback? onImageFailed,
    VoidCallback? onFirstFrameRendered,
    bool showDelayedLoadingIndicator = false,
    bool waitForCacheWrite = false,
    int retryToken = 0,
  }) => ValueListenableBuilder<int>(
    valueListenable: frames.putIfAbsent(
      image.sourceUrl,
      () => ValueNotifier(0),
    ),
    builder: (_, frame, _) {
      if (frame == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onFirstFrameRendered?.call();
        });
        return SizedBox(
          width: width,
          height: height,
          child: const ColoredBox(color: Colors.red),
        );
      }
      if (frame == -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onImageFailed?.call();
        });
        return errorPlaceholder ?? placeholder;
      }
      return placeholder;
    },
  );
}

final class _ControlledPagedDisplayImage implements ForumHtmlDisplayImage {
  const _ControlledPagedDisplayImage(
    this.sourceUrl,
    this.isSticker,
    this.htmlSize,
  );
  @override
  final String sourceUrl;
  @override
  final bool isSticker;
  @override
  final Size? htmlSize;
  @override
  String get cacheKey => sourceUrl;
  @override
  Object get identity => sourceUrl;
  @override
  ForumHtmlImageLayout get initialLayout => ForumHtmlImageLayout(
    displaySize: htmlSize ?? const Size(160, 100),
    aspectRatio: 1.6,
  );
}

final class _GatedPreparationService
    implements NovelReaderHtmlPreparationService {
  final requests = <Completer<NovelReaderPreparedChapter>>[];
  final semanticDocuments = <NovelReaderDocument?>[];

  @override
  int get legacyMarkupNormalizerRevision => 1;

  @override
  Future<NovelReaderPreparedChapter> prepare({
    required String rawHtml,
    required NovelEpisodeItem episode,
    required ForumHtmlReaderPreferences preferences,
    required ForumHtmlThemeContext theme,
    required String sourceId,
    required String? threadId,
    required String? imageCacheOwnerId,
    NovelReaderDocument? semanticDocument,
  }) {
    final request = Completer<NovelReaderPreparedChapter>();
    semanticDocuments.add(semanticDocument);
    requests.add(request);
    return request.future;
  }
}

final class _BudgetPaginationAttempt {
  _BudgetPaginationAttempt(this.chapter, this.key);

  final NovelReaderPreparedChapter chapter;
  final NovelReaderPaginationKey key;
  final controller = StreamController<NovelReaderPaginationProgress>();
}

final class _BudgetPaginationCoordinator
    implements NovelReaderPaginationCoordinator {
  bool useFlowAnchors = false;
  Map<int, String> pageHtml = {};
  Set<int> innerScrollPages = {};
  final attempts = <_BudgetPaginationAttempt>[];
  int cancelPendingCount = 0;
  int clearCount = 0;

  @override
  Future<NovelReaderPaginationPlan> paginate({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) => Completer<NovelReaderPaginationPlan>().future;

  @override
  Stream<NovelReaderPaginationProgress> paginateIncrementally({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) {
    final attempt = _BudgetPaginationAttempt(chapter, key);
    attempts.add(attempt);
    return attempt.controller.stream;
  }

  void emit(
    int attemptIndex, {
    required int pageCount,
    bool isComplete = false,
    int measurementCount = 0,
    bool replaceFirstHtml = false,
  }) {
    final attempt = attempts[attemptIndex];
    final pages = <NovelReaderPageFragment>[
      for (var index = 0; index < pageCount; index++)
        _page(attempt, index, replaceFirstHtml: replaceFirstHtml),
    ];
    attempt.controller.add(
      NovelReaderPaginationProgress(
        plan: NovelReaderPaginationPlan(
          key: attempt.key,
          episodeId: attempt.chapter.episodeId,
          pages: pages,
          atomCount: 3,
          measurementCount: measurementCount,
        ),
        isComplete: isComplete,
        processedAtomCount: pageCount,
        totalAtomCount: 3,
      ),
    );
  }

  NovelReaderPageFragment _page(
    _BudgetPaginationAttempt attempt,
    int index, {
    required bool replaceFirstHtml,
  }) {
    final text = _budgetPageTexts[index];
    final start = useFlowAnchors
        ? attempt.chapter.flowUnits[index].startAnchor
        : NovelReaderTextAnchor(
            episodeId: attempt.chapter.episodeId,
            nodeId: 'paragraph-$index',
            formatVersion: 1,
            textIdentity: NovelReaderAnchorFormat.textIdentity(text),
          );
    final end = useFlowAnchors
        ? attempt.chapter.flowUnits[index].endAnchor
        : start.copyWith(textOffset: text.runes.length);
    return NovelReaderPageFragment(
      index: index,
      html:
          pageHtml[index] ??
          (useFlowAnchors
              ? attempt.chapter.flowUnits[index].html
              : replaceFirstHtml && index == 0
              ? '<p>被替换的正文</p>'
              : '<p>$text</p>'),
      startAnchor: start,
      endAnchor: end,
      anchorRanges: [NovelReaderPageAnchorRange(start: start, end: end)],
      imageIndices: const [],
      requiresInnerScroll: innerScrollPages.contains(index),
      usedHeight: 80,
      availableHeight: 600,
    );
  }

  void fail(int attemptIndex) {
    attempts[attemptIndex].controller.addError(
      StateError('controlled pagination failure'),
    );
  }

  Future<void> close() async {
    for (final attempt in attempts) {
      await attempt.controller.close();
    }
  }

  @override
  bool isCached(NovelReaderPaginationKey key) => false;

  // Keep the old source alive so tests can release a success/error after the
  // surface has retired that computation. The surface owns its subscription.
  @override
  void cancelPending() {
    cancelPendingCount += 1;
  }

  @override
  void clear() {
    clearCount += 1;
    cancelPending();
  }

  @override
  void clearEpisode(String episodeId) {
    cancelPending();
  }
}

final class _ControlledRestorePaginationCoordinator
    implements NovelReaderPaginationCoordinator {
  _ControlledRestorePaginationCoordinator({this.finalPageCount = 2});

  final int finalPageCount;
  StreamController<NovelReaderPaginationProgress>? _controller;
  NovelReaderPreparedChapter? _chapter;
  NovelReaderPaginationKey? _key;

  @override
  Future<NovelReaderPaginationPlan> paginate({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) => Completer<NovelReaderPaginationPlan>().future;

  @override
  Stream<NovelReaderPaginationProgress> paginateIncrementally({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) {
    _chapter = chapter;
    _key = key;
    late final StreamController<NovelReaderPaginationProgress> controller;
    controller = StreamController<NovelReaderPaginationProgress>(
      onListen: () {
        controller.add(_progress(pageCount: 1));
      },
    );
    _controller = controller;
    return controller.stream;
  }

  void emitTargetPage() {
    _controller?.add(_progress(pageCount: 2));
  }

  void emitComplete() {
    _controller?.add(_progress(pageCount: finalPageCount, isComplete: true));
  }

  NovelReaderPaginationProgress _progress({
    required int pageCount,
    bool isComplete = false,
  }) {
    final chapter = _chapter!;
    final key = _key!;
    final firstStart = NovelReaderTextAnchor(
      episodeId: 'performance-episode',
      nodeId: 'paragraph-0',
      formatVersion: 1,
      textIdentity: NovelReaderAnchorFormat.textIdentity('第一页'),
    );
    final firstEnd = firstStart.copyWith(textOffset: 3);
    final targetStart = NovelReaderTextAnchor(
      episodeId: 'performance-episode',
      nodeId: 'paragraph-1',
      formatVersion: 1,
      textIdentity: NovelReaderAnchorFormat.textIdentity('恢复目标页'),
    );
    final targetEnd = targetStart.copyWith(textOffset: 5);
    final lastStart = NovelReaderTextAnchor(
      episodeId: 'performance-episode',
      nodeId: 'paragraph-2',
      formatVersion: 1,
      textIdentity: NovelReaderAnchorFormat.textIdentity('尾页'),
    );
    final pages = <NovelReaderPageFragment>[
      NovelReaderPageFragment(
        index: 0,
        html: '<p>第一页</p>',
        startAnchor: firstStart,
        endAnchor: firstEnd,
        imageIndices: const <int>[],
        usedHeight: 80,
        availableHeight: 600,
      ),
      if (pageCount > 1)
        NovelReaderPageFragment(
          index: 1,
          html: '<p>恢复目标页</p>',
          startAnchor: targetStart,
          endAnchor: targetEnd,
          imageIndices: const <int>[],
          usedHeight: 80,
          availableHeight: 600,
        ),
      if (pageCount > 2)
        NovelReaderPageFragment(
          index: 2,
          html: '<p>尾页</p>',
          startAnchor: lastStart,
          endAnchor: lastStart.copyWith(textOffset: 2),
          imageIndices: const [],
          usedHeight: 80,
          availableHeight: 600,
        ),
    ];
    return NovelReaderPaginationProgress(
      plan: NovelReaderPaginationPlan(
        key: key,
        episodeId: chapter.episodeId,
        pages: pages,
        atomCount: 3,
      ),
      isComplete: isComplete,
      processedAtomCount: isComplete ? 3 : pageCount,
      totalAtomCount: 3,
    );
  }

  @override
  bool isCached(NovelReaderPaginationKey key) => false;

  @override
  void cancelPending() {
    unawaited(_controller?.close());
  }

  @override
  void clear() => cancelPending();

  @override
  void clearEpisode(String episodeId) => cancelPending();
}

final class _RecordingDiagnosticsSink
    implements NovelReaderPaginationDiagnosticsSink {
  final records = <NovelReaderPaginationDiagnostics>[];

  @override
  void record(NovelReaderPaginationDiagnostics diagnostics) {
    records.add(diagnostics);
  }
}

final class _CompleteRecordingPaginationCoordinator
    implements NovelReaderPaginationCoordinator {
  _CompleteRecordingPaginationCoordinator({this.pageHtml = '<p>安全区分页几何</p>'});

  final String pageHtml;
  NovelReaderPaginationKey? lastKey;

  @override
  Future<NovelReaderPaginationPlan> paginate({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) async {
    return _plan(chapter: chapter, key: key);
  }

  @override
  Stream<NovelReaderPaginationProgress> paginateIncrementally({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) {
    lastKey = key;
    return Stream<NovelReaderPaginationProgress>.value(
      NovelReaderPaginationProgress(
        plan: _plan(chapter: chapter, key: key),
        isComplete: true,
        processedAtomCount: 1,
        totalAtomCount: 1,
      ),
    );
  }

  NovelReaderPaginationPlan _plan({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) {
    final anchor = NovelReaderTextAnchor(
      episodeId: chapter.episodeId,
      nodeId: 'safe-area-paragraph',
    );
    return NovelReaderPaginationPlan(
      key: key,
      episodeId: chapter.episodeId,
      pages: <NovelReaderPageFragment>[
        NovelReaderPageFragment(
          index: 0,
          html: pageHtml,
          startAnchor: anchor,
          endAnchor: anchor,
          imageIndices: const <int>[],
          usedHeight: 80,
          availableHeight: key.viewportHeightPx.toDouble(),
        ),
      ],
      atomCount: 1,
    );
  }

  @override
  bool isCached(NovelReaderPaginationKey key) => false;

  @override
  void cancelPending() {}

  @override
  void clear() {}

  @override
  void clearEpisode(String episodeId) {}
}

class _NoopImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult(success: true, cacheKey: request.cacheKey);
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: request.sourcePath,
    );
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async => 0;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async => 0;

  @override
  Future<void> clearUnprotected() async {}
}
