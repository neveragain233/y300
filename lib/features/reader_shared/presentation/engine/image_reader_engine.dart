import 'dart:async';

import 'package:continuous_image_geometry/continuous_image_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:y300/app/theme/app_system_ui.dart';
import 'package:y300/core/eink/eink_hardware_page_keys.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/eink/eink_paging_router.dart';
import 'package:y300/core/eink/eink_page_ripple.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/shared/widgets/reader_content_region.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/reader_shared/data/export/reader_image_export_providers.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/domain/export/reader_image_export.dart';
import 'package:y300/features/reader_shared/domain/metrics/reader_performance_metrics.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/continuous_image/continuous_image_reader_view.dart';
import 'package:y300/features/reader_shared/presentation/continuous_image/continuous_image_viewport_tracker.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_capability.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_background_resolver.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_display_settings_sheet.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_image_session_coordinator.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_paged_image_fit_surface.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_position_state.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_restore_coordinator.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_seek_coordinator.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_tail_surface.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_tail_action_controller.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_vertical_position_driver.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_vertical_compensation_coordinator.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_zoomable_image.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/reader_preferences_provider.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/hardware_page_keys_provider.dart';
import 'package:y300/features/reader_shared/presentation/reader_text_resolver.dart';
import 'package:y300/features/reader_shared/presentation/services/reader_image_session_preload_coordinator.dart';
import 'package:y300/features/reader_shared/presentation/services/reader_image_session_store.dart';
import 'package:y300/features/reader_shared/presentation/widgets/reader_thumbnail_strip.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 通用图片阅读壳：垂直/横向模式、缩放、overlay 工具栏、进度滑块、页码浮层、
/// 显示设置、滚动锚定补偿、解码预热。
///
/// 引擎零业务知识，一切业务差异（标题、章节、书签、缓存、过场卡、图片内容本体、
/// 阅读进度落地）通过 [ReaderCapability] 注入。漫画与帖子图片阅读器共用本引擎。
///
/// 行为对齐自原 `ComicReaderPage`：滚动锚定/补偿、滑块 commit 状态机、PageController
/// 同步等时序敏感逻辑均按原实现迁移，仅把业务部分替换为能力回调。
class ImageReaderEngine extends ConsumerWidget {
  const ImageReaderEngine({
    super.key,
    required this.capability,
    this.flowPolicy = ContinuousImageFlowPolicy.comicVerticalReading,
    this.listKey = const Key('image-reader-engine-image-list'),
    this.pageKey = const Key('image-reader-engine-page-view'),
    this.slotKeyPrefix = 'image-reader-engine-image-slot',
  });

  final ReaderCapability capability;
  final ContinuousImageFlowPolicy flowPolicy;
  final Key listKey;
  final Key pageKey;
  final String slotKeyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(readerPreferencesControllerProvider).value ??
        ReaderPreferences.defaults();
    final background = resolveReaderBackground(
      themeSurface: Theme.of(context).colorScheme.surface,
      background: preferences.background,
      readerMode: preferences.readerMode,
      pagedCanvasColor: capability.pagedCanvasColor,
      eInkMode: EInkModeScope.of(context),
    );
    return ReaderContentRegion(
      backgroundColor: background,
      maxWidth: preferences.readerMode == ReaderModePreference.vertical
          ? AppLayoutTokens.imageReadingMaxWidth
          : double.infinity,
      child: _ImageReaderEngineContent(
        capability: capability,
        flowPolicy: flowPolicy,
        listKey: listKey,
        pageKey: pageKey,
        slotKeyPrefix: slotKeyPrefix,
      ),
    );
  }
}

class _ImageReaderEngineContent extends ConsumerStatefulWidget {
  const _ImageReaderEngineContent({
    required this.capability,
    required this.flowPolicy,
    required this.listKey,
    required this.pageKey,
    required this.slotKeyPrefix,
  });
  final ReaderCapability capability;
  final ContinuousImageFlowPolicy flowPolicy;
  final Key listKey;
  final Key pageKey;
  final String slotKeyPrefix;
  @override
  ConsumerState<_ImageReaderEngineContent> createState() =>
      _ImageReaderEngineState();
}

class _ImageReaderEngineState extends ConsumerState<_ImageReaderEngineContent>
    implements ReaderEngineActions, EInkPageHandler {
  late ScrollController _scrollController;
  int _scrollControllerSessionGeneration = -1;
  PageController? _pageController;
  String? _pageControllerOwnerId;
  late final ReaderOverlayController _overlayController;
  late final ReaderGestureCoordinator _gestureCoordinator;
  late final ValueNotifier<bool> _zoomGate;
  late final ValueNotifier<int> _activePagedIndex;
  ScrollHoldController? _pagedZoomScrollHold;
  final Map<int, bool> _pagedHorizontalOverflowByIndex = <int, bool>{};
  final Map<String, ContinuousImageDimensions> _resolvedDimensionsByItemId =
      <String, ContinuousImageDimensions>{};

  int _lastKnownIndex = 0;
  ReaderSequencePosition _pagedPosition = const ReaderSequencePosition.image(0);
  final Set<String> _reportedTailSurfaceKeys = <String>{};
  final Set<String> _reportedAdvanceSurfaceKeys = <String>{};
  final Set<String> _reportedAdjacentPreloadKeys = <String>{};
  final ReaderTailActionController _tailActionController =
      ReaderTailActionController();

  final ReaderSeekCoordinator _seekCoordinator = ReaderSeekCoordinator();
  final ReaderRestoreCoordinator _restoreCoordinator =
      ReaderRestoreCoordinator();
  int? get _sliderPreviewIndex => _seekCoordinator.previewIndex;
  bool get _isSliderCommitInFlight => _seekCoordinator.isSliderLocked;
  int? get _pendingCommittedIndex => _seekCoordinator.pendingIndex;
  int get _seekGeneration => _seekCoordinator.generation;

  /// 缩略图拖动中的候选页；只影响页码和预览，不写阅读位置。
  int? _thumbnailPreviewIndex;
  int? get _effectivePreviewIndex =>
      _thumbnailPreviewIndex ?? _sliderPreviewIndex;
  Size? _lastReaderLayoutSize;

  final Set<int> _reportedVisibleImageIndexes = <int>{};

  final ReaderImageSessionCoordinator _readerSession =
      ReaderImageSessionCoordinator();
  String? get _lastOwnerId => _readerSession.current?.ownerId;
  int? get _lastContentRevision => _readerSession.current?.revision;
  int get _readerSessionGeneration => _readerSession.generation;
  ReaderPositionState? _positionState;
  bool _exitFlushed = false;
  Future<void>? _exitFlushFuture;

  int _verticalViewportPrimedGeneration = -1;
  ReaderModePreference _diagnosticMode = ReaderModePreference.vertical;
  bool _positionRetryScheduled = false;
  String? _exportingIdentity;
  final Set<String> _imageRetryInFlight = <String>{};

  // 连续图片高度/锚定基础设施（迁移自 ComicReaderPage）。
  static const ContinuousImageLayoutResolver _layoutResolver =
      ContinuousImageLayoutResolver();
  static const ContinuousImageViewportTracker _viewportTracker =
      ContinuousImageViewportTracker(layoutResolver: _layoutResolver);
  static const ContinuousImageScrollAnchorCoordinator _anchorCoordinator =
      ContinuousImageScrollAnchorCoordinator(layoutResolver: _layoutResolver);
  final InMemoryContinuousImageExtentRegistry _extentRegistry =
      InMemoryContinuousImageExtentRegistry();
  late final ReaderImageSessionStore _imageSessionStore;
  late final ReaderImageSessionPreloadCoordinator _sessionPreloadCoordinator;
  late final ReaderVerticalPositionDriver _verticalPositionDriver;
  final ReaderPerformanceMetricsCollector _performanceMetrics =
      ReaderPerformanceMetricsCollector();
  final Map<String, GlobalKey> _verticalItemAnchors = <String, GlobalKey>{};

  List<ContinuousImageItem> _latestItems = const <ContinuousImageItem>[];
  ContinuousImageLayoutIndex? _verticalLayoutIndex;
  List<ContinuousImageItem>? _indexedItems;
  double? _indexedWidth;
  final _verticalCompensation = ReaderVerticalCompensationCoordinator();

  // 视口尺寸变化后的锚点恢复：懒列表的离屏像素几何属于旧宽度，换宽度时
  // 重建视口并按锚点恢复，不触碰阅读提交与图片会话。
  Size? _verticalViewportSize;
  int _viewportRestoreGeneration = 0;
  int _verticalViewportRevision = 0;
  ({int index, String itemId, double fraction})? _viewportAnchor;

  late final EInkPagingRouter _hardwarePageKeysRouter;
  ProviderSubscription<AsyncValue<bool>>? _hardwarePageKeysSetting;
  bool _hardwarePageKeysEnabled = false;
  bool _hardwarePageKeysArmed = false;
  bool _hardwareKeysRouteVisible = true;
  ReaderPreferences? _lastKnownReaderPreferences;
  int _lastKnownImageTotal = 0;

  ReaderCapability get _capability => widget.capability;

  ReaderTailSurface? get _tailSurface => _capability.tailSurface;

  @override
  void initState() {
    super.initState();
    _scrollController = _createScrollController();
    _tailActionController.addListener(_onTailActionChanged);
    _overlayController = ReaderOverlayController()
      ..addListener(_onOverlayVisibilityChanged);
    _gestureCoordinator = ReaderGestureCoordinator(
      doubleTapTimeout: ReaderPagedTurnMotion.tapConfirmationDelay,
    );
    _zoomGate = ValueNotifier<bool>(false);
    _activePagedIndex = ValueNotifier<int>(0);
    _imageSessionStore = ReaderImageSessionStore();
    _sessionPreloadCoordinator = ReaderImageSessionPreloadCoordinator(
      sessionStore: _imageSessionStore,
      onScheduled: _recordSessionPreloadScheduled,
      onResult: _recordSessionPreload,
      performanceMetrics: _performanceMetrics,
    );
    _verticalPositionDriver = ReaderVerticalPositionDriver(
      isReady: () => mounted && _scrollController.hasClients,
      currentOffset: () => _scrollController.offset,
      clampOffset: _clampVerticalOffset,
      jumpTo: (offset) => _scrollController.jumpTo(offset),
      estimateOffset: _estimateVerticalOffset,
      exactOffset: _resolveExactVerticalOffset,
      waitForLayout: _waitForVerticalLayout,
    );
    _hardwarePageKeysRouter = ref.read(eInkPagingRouterProvider);
    _hardwarePageKeysRouter.register(this, this);
    _hardwarePageKeysSetting = ref.listenManual<AsyncValue<bool>>(
      hardwarePageKeysEnabledProvider,
      (previous, next) => _setHardwarePageKeysEnabled(next.value ?? false),
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (visible != _hardwareKeysRouteVisible) {
      _hardwareKeysRouteVisible = visible;
      _syncHardwareKeysArmed();
    }
  }

  void _setHardwarePageKeysEnabled(bool enabled) {
    _hardwarePageKeysEnabled = enabled;
    _hardwarePageKeysRouter.setHardwareKeysEnabled(enabled);
    _syncHardwareKeysArmed();
  }

  /// 只在横向翻页模式、且路由位于最上层时拦截实体键；垂直滚动模式不占用
  /// 音量键，弹层或切走的页面也不接收前景按键。
  void _syncHardwareKeysArmed() {
    final preferences = _lastKnownReaderPreferences;
    final armed =
        _hardwareKeysRouteVisible &&
        _hardwarePageKeysEnabled &&
        preferences != null &&
        _readerMode(preferences) != ContinuousImageReaderMode.vertical;
    if (armed == _hardwarePageKeysArmed) {
      return;
    }
    _hardwarePageKeysArmed = armed;
    _hardwarePageKeysRouter.setVisible(this, armed);
  }

  @override
  void pageUp() => _onHardwarePageKey(HardwarePageKeyDirection.previous);

  @override
  void pageDown() => _onHardwarePageKey(HardwarePageKeyDirection.next);

  /// 供角标与边缘步进判断是否还有上一屏；硬件键仲裁不读这两个 getter，
  /// 因此状态未知时返回 false 只会隐藏禁用态控件，不会吞掉按键。
  @override
  bool get canPageUp {
    final preferences = _lastKnownReaderPreferences;
    if (!mounted || preferences == null) {
      return false;
    }
    if (_readerMode(preferences) == ContinuousImageReaderMode.vertical) {
      return _canScrollVertically(-1);
    }
    final page = _currentPagedPage();
    return page != null && page > 0;
  }

  @override
  bool get canPageDown {
    final preferences = _lastKnownReaderPreferences;
    if (!mounted || preferences == null) {
      return false;
    }
    if (_readerMode(preferences) == ContinuousImageReaderMode.vertical) {
      return _canScrollVertically(1);
    }
    final page = _currentPagedPage();
    if (page == null) {
      return false;
    }
    return page < _pagedPageCount(_lastKnownImageTotal) - 1;
  }

  /// 横向当前页码；内容尚未就绪或页码不可用时返回 null。
  int? _currentPagedPage() {
    final total = _lastKnownImageTotal;
    if (total <= 0) {
      return null;
    }
    final pageCount = _pagedPageCount(total);
    final controller = _pageController;
    if (controller != null && controller.hasClients) {
      final page = controller.page;
      if (page != null && page.isFinite) {
        return page.round().clamp(0, pageCount - 1).toInt();
      }
    }
    return _pagedPageForPosition(
      _pagedPosition,
      total,
    ).clamp(0, pageCount - 1).toInt();
  }

  /// 滚动模式按当前位置判断；视口尚未布局或没有可滚动距离时为 false。
  bool _canScrollVertically(int direction) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return false;
    }
    const epsilon = 0.5;
    if (direction < 0) {
      return position.pixels > position.minScrollExtent + epsilon;
    }
    return position.pixels < position.maxScrollExtent - epsilon;
  }

  void _onHardwarePageKey(HardwarePageKeyDirection direction) {
    if (!mounted) {
      return;
    }
    _turnPage(
      forward: direction == HardwarePageKeyDirection.next,
      total: _lastKnownImageTotal,
    );
  }

  @override
  void dispose() {
    _hardwarePageKeysSetting?.close();
    _hardwarePageKeysRouter.unregister(this);
    _verticalCompensation.close();
    _readerSession.close();
    _restoreCoordinator.close();
    _seekCoordinator.close();
    if (!_exitFlushed) {
      unawaited(_capability.onExit());
    }
    _scrollController
      ..removeListener(_onVerticalScroll)
      ..removeListener(_tailActionController.schedule)
      ..dispose();
    _releasePagedZoomScrollHold();
    _pageController?.dispose();
    _overlayController
      ..removeListener(_onOverlayVisibilityChanged)
      ..dispose();
    _gestureCoordinator.dispose();
    _zoomGate.dispose();
    _activePagedIndex.dispose();
    _verticalPositionDriver.dispose();
    _sessionPreloadCoordinator.dispose();
    _imageSessionStore.dispose();
    _disposeTailSurface();
    _tailActionController.dispose();
    super.dispose();
  }

  void _onTailActionChanged() {
    if (mounted) setState(() {});
  }
  // ENGINE_BODY_PLACEHOLDER

  @override
  Widget build(BuildContext context) {
    final preferencesState = ref.watch(readerPreferencesControllerProvider);
    final preferences = preferencesState.value ?? ReaderPreferences.defaults();
    final mode = _readerMode(preferences);
    final content = _capability.content;
    final background = _backgroundColor(preferences);
    _diagnosticMode = preferences.readerMode;

    // 窗口布局变化后旧尺寸下的未提交缩略图候选不再有效。
    final layoutSize = MediaQuery.sizeOf(context);
    if (_lastReaderLayoutSize != null && _lastReaderLayoutSize != layoutSize) {
      _thumbnailPreviewIndex = null;
    }
    _lastReaderLayoutSize = layoutSize;

    if (content.isEmpty) {
      _verticalCompensation.deactivate();
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Text(
            AppLocalizations.of(context).readerNoImages,
            style: TextStyle(
              color:
                  ThemeData.estimateBrightnessForColor(background) ==
                      Brightness.dark
                  ? Colors.white70
                  : null,
            ),
          ),
        ),
      );
    }

    final positionState = _resetIfOwnerChanged(content, preferences.readerMode);
    _syncScrollControllerIfNeeded();
    _syncPageControllerIfNeeded(
      mode,
      positionState.committedLogicalIndex,
      content.ownerId,
    );
    _restorePositionIfNeeded(mode, preferences.readerMode, content);

    final total = content.length;
    _lastKnownReaderPreferences = preferences;
    _lastKnownImageTotal = total;
    _syncHardwareKeysArmed();
    final engineContext = _engineContext(preferences, total);
    final tail = _tailSurface;
    final actionSurface = tail is ReaderTailActionSurface
        ? tail as ReaderTailActionSurface
        : null;
    _tailActionController.configure(
      identity: (content.ownerId, tail, preferences.readerMode),
      surface: actionSurface,
      vertical: mode == ContinuousImageReaderMode.vertical,
      pagedVisible: _pagedPosition.isTail,
    );

    // Chrome and viewport must retire together: a chapter can change while a
    // modal is dismissing and the old tail's semantics are still offstage.
    final chromePalette = const ReaderChromePaletteResolver().resolve(
      Theme.of(context),
    );
    // 工具栏展开时系统栏图标跟随顶/底栏的 chrome 色，沉浸阅读时跟随有效画布背景。
    final overlaySurface = _overlayController.isMenuVisible
        ? chromePalette.chromeBackground
        : background;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 工具栏展开时顶/底栏的 chrome 色才是系统栏背后的实际颜色。
      value: AppSystemUi.onSurfaces(
        top: overlaySurface,
        bottom: overlaySurface,
      ),
      child: Scaffold(
        key: ValueKey<int>(_readerSessionGeneration),
        backgroundColor: background,
        body: Stack(
          children: [
            ReaderOverlayScaffold(
              controller: _overlayController,
              gestureCoordinator: _gestureCoordinator,
              topBar: _buildTopBar(engineContext),
              bottomBar: _buildBottomBar(engineContext, preferences),
              persistentFooter: _buildPersistentFooter(
                engineContext,
                preferences,
                background,
              ),
              onLeftTap: mode == ContinuousImageReaderMode.vertical
                  ? null
                  : () => _turnPageByTap(
                      mode: preferences.readerMode,
                      total: total,
                      isLeftTap: true,
                    ),
              onRightTap: mode == ContinuousImageReaderMode.vertical
                  ? null
                  : () => _turnPageByTap(
                      mode: preferences.readerMode,
                      total: total,
                      isLeftTap: false,
                    ),
              bottomSafeFraction: mode == ContinuousImageReaderMode.vertical
                  ? 0.2
                  : 0,
              tapZonesBlockedListenable: _zoomGate,
              child: _buildContentLayer(
                context: context,
                content: content,
                mode: mode,
                preferences: preferences,
                engineContext: engineContext,
              ),
            ),
            if (actionSurface != null)
              ReaderTailActionOverlay(
                key: ValueKey(_tailActionController.identity),
                controller: _tailActionController,
                surface: actionSurface,
                menuVisible: _overlayController.isMenuVisible,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVertical(
    ReaderContent content,
    ReaderPreferences preferences,
    ReaderEngineContext engineContext,
  ) {
    _restoreVerticalViewportIfChanged(content);
    final session = _readerSession.current!;
    final scrollController = _scrollController;
    _verticalCompensation.bind(
      session: session,
      controller: scrollController,
      // Explicit seek/restore owns its own layout corrections while active.
      isCurrent: () =>
          _isCurrentVerticalSessionToken(session, scrollController) &&
          !_isSliderCommitInFlight &&
          !(_positionState?.needsInitialRestore ?? true),
    );
    final pageSpacing = preferences.pageSpacing.clamp(0.0, 48.0).toDouble();
    final items = _applyVerticalPageSpacing(
      _applyResolvedVerticalDimensions(content.items),
      pageSpacing,
    );
    _scheduleVerticalPageSpacingCompensation(pageSpacing: pageSpacing);
    _latestItems = items;
    _syncVerticalItemAnchors(items);
    final verticalTrailing = _buildVerticalTrailingSpec(engineContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentVerticalSessionToken(session, scrollController)) {
        _verticalCompensation.syncPosition();
        if (_verticalViewportPrimedGeneration != _readerSessionGeneration) {
          // A ListView may build cached rows without scrolling. Resolve the
          // initial viewport here so only the actual reading position is
          // reported to the business capability. This is once per owner;
          // running it on every rebuild can create a persistent UI loop while
          // image extents are settling.
          _onVerticalScroll();
        }
        _submitSessionPreloadWindow(
          focusIndex: _lastKnownIndex,
          scrollDirection: ContinuousImageScrollDirection.idle,
        );
      }
    });
    final reader = NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _isCurrentVerticalSessionToken(session, scrollController)
          ? _onVerticalScrollNotification(notification)
          : false,
      child: ContinuousImageReaderView(
        key: ValueKey(_verticalViewportRevision),
        items: items,
        mode: ContinuousImageReaderMode.vertical,
        scrollController: scrollController,
        scrollCacheExtent: ScrollCacheExtent.pixels(
          MediaQuery.sizeOf(context).height *
              widget.flowPolicy.viewportCacheExtentFactor,
        ),
        layoutResolver: _layoutResolver,
        onExtentResolved: (extent) => _recordExtent(extent, session: session),
        verticalPadding: EdgeInsets.only(
          bottom: _tailSurface is ReaderTailActionSurface
              ? 0
              : _statusBarBottomClearance(preferences),
        ),
        verticalListKey: widget.listKey,
        slotKeyPrefix: widget.slotKeyPrefix,
        verticalItemAnchorKeyBuilder: (item, _) =>
            _verticalItemAnchors[item.id]!,
        verticalTrailingBuilder: verticalTrailing.builder,
        verticalTrailingItemCount: verticalTrailing.itemCount,
        verticalTrailingItemBuilder: verticalTrailing.indexedBuilder,
        itemBuilder: (context, item, index, {required paged}) {
          return _buildImage(item, index, preferences, paged: false);
        },
      ),
    );
    return ReaderZoomableImage(
      key: const Key('image-reader-engine-vertical-zoom-surface'),
      gestureCoordinator: _gestureCoordinator,
      behavior: ReaderZoomBehavior.continuousVertical,
      onZoomStateChanged: _onVerticalReaderZoomStateChanged,
      child: reader,
    );
  }

  Widget _buildPaged(ReaderContent content, ReaderPreferences preferences) {
    _deactivateVerticalSession();
    final items = content.items;
    final tail = _tailSurface;
    final pageController = _pageController;
    final session = _readerSession.current;
    _latestItems = items;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentImageSession(session) &&
          identical(pageController, _pageController)) {
        _precachePagedWindow(_lastKnownIndex);
      }
    });
    return ReaderPagedSwipeGate(
      blockedListenable: _zoomGate,
      child: ContinuousImageReaderView(
        key: ValueKey<String>('reader-paged-owner-${content.ownerId}'),
        items: items,
        mode: ContinuousImageReaderMode.horizontal,
        pageController: pageController,
        horizontalPhysics:
            EInkModeScope.of(context) ||
                _pagedHorizontalOverflowActive(preferences)
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        reverse: preferences.readerMode == ReaderModePreference.rtl,
        onPageChanged: pageController == null
            ? null
            : (pageIndex) {
                if (_isCurrentImageSession(session)) {
                  unawaited(
                    _onPageChanged(
                      pageIndex,
                      ownerId: content.ownerId,
                      pageController: pageController,
                    ),
                  );
                }
              },
        horizontalPageKey: widget.pageKey,
        horizontalPagePadding: () {
          final spacing = preferences.pageSpacing.clamp(0.0, 48.0).toDouble();
          return EdgeInsets.fromLTRB(
            spacing,
            spacing,
            spacing,
            spacing + _statusBarBottomClearance(preferences),
          );
        }(),
        horizontalTrailingBuilder: tail == null
            ? null
            : (context) => _buildPagedTail(context, tail),
        horizontalAdvanceBuilder: tail == null || !tail.hasAdvance
            ? null
            : (context) => _buildPagedAdvance(context, tail),
        layoutResolver: _layoutResolver,
        onExtentResolved: (extent) => _recordExtent(extent, session: session),
        itemBuilder: (context, item, index, {required paged}) {
          return _buildImage(item, index, preferences, paged: true);
        },
      ),
    );
  }

  void _restoreVerticalViewportIfChanged(ReaderContent content) {
    final next = MediaQuery.sizeOf(context);
    final previous = _verticalViewportSize;
    _verticalViewportSize = next;
    if (previous == null ||
        previous == next ||
        !_scrollController.hasClients ||
        (_positionState?.needsInitialRestore ?? true) ||
        _latestItems.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    var anchor = _viewportAnchor;
    if (anchor == null) {
      final index = _verticalLayoutFor(previous.width)
          .resolve(
            scrollOffset: position.pixels,
            viewportExtent: position.viewportDimension,
            userScrollDirection: ContinuousImageScrollDirection.idle,
          )
          .firstVisibleIndex;
      if (index == null || index >= _latestItems.length) return;
      final item = _latestItems[index];
      final start = _extentRegistry.estimateOffsetForIndex(
        index,
        _latestItems,
        crossAxisExtent: previous.width,
        resolver: _layoutResolver,
      );
      final height =
          _extentRegistry.extentOf(item.id)?.mainAxisExtent ??
          previous.width /
              _layoutResolver.resolveInitialHint(item: item).aspectRatio;
      anchor = (
        index: index,
        itemId: item.id,
        fraction: height > 0
            ? ((position.pixels - start) / height).clamp(0.0, 1.0)
            : 0.0,
      );
    }
    _viewportAnchor = anchor;
    // 懒列表保留的离屏像素几何属于旧宽度；替换视口，保留引擎、控制器和图片会话。
    _verticalViewportRevision++;
    final captured = anchor;
    final generation = ++_viewportRestoreGeneration;
    final session = _readerSession.current;
    final controller = _scrollController;
    // 布局恢复只调整视口，原阅读提交与图片可见证据保持不变。
    _gestureCoordinator.cancelPendingTap();
    _verticalPositionDriver.cancelActive(
      ReaderVerticalSeekCancelReason.superseded,
    );
    _seekCoordinator.reset(resetThrottle: false);
    // 视口已换宽：等待中的补偿按旧几何计算，直接丢弃并由锚点恢复接管。
    _verticalCompensation.cancelPending();
    _extentRegistry.clearForOwner(content.ownerId);
    _invalidateVerticalLayoutIndex();
    bool current() =>
        generation == _viewportRestoreGeneration &&
        _isCurrentVerticalSessionToken(session, controller) &&
        controller.hasClients &&
        captured.index < _latestItems.length &&
        _latestItems[captured.index].id == captured.itemId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!current()) return;
      final result = await _verticalPositionDriver.seekToIndex(captured.index);
      if (!current() || !result.reached) return;
      final start =
          _resolveExactVerticalOffset(captured.index) ??
          _estimateVerticalOffset(captured.index);
      final item = _latestItems[captured.index];
      final height =
          _extentRegistry.extentOf(item.id)?.mainAxisExtent ??
          next.width /
              _layoutResolver.resolveInitialHint(item: item).aspectRatio;
      if (start != null) {
        controller.jumpTo(
          _clampVerticalOffset(start + captured.fraction * height),
        );
      }
      // jumpTo 的通知与本帧尺寸通知都属于布局补偿。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current()) _viewportAnchor = null;
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  List<ContinuousImageItem> _applyVerticalPageSpacing(
    List<ContinuousImageItem> items,
    double pageSpacing,
  ) {
    if (items.every((item) => item.spacingAfter == pageSpacing)) {
      return items;
    }
    return List<ContinuousImageItem>.unmodifiable(
      items.map((item) => item.copyWith(spacingAfter: pageSpacing)),
    );
  }

  List<ContinuousImageItem> _applyResolvedVerticalDimensions(
    List<ContinuousImageItem> items,
  ) {
    if (!widget.flowPolicy.updateVisibleItemAspectRatio ||
        _resolvedDimensionsByItemId.isEmpty) {
      return items;
    }
    var changed = false;
    final resolvedItems = items
        .map((item) {
          final dimensions = _resolvedDimensionsByItemId[item.id];
          if (dimensions == null ||
              (item.knownWidth == dimensions.width &&
                  item.knownHeight == dimensions.height &&
                  item.knownDimensionSource ==
                      ContinuousImageDimensionSource.decodedImage)) {
            return item;
          }
          changed = true;
          return item.copyWith(
            knownWidth: dimensions.width,
            knownHeight: dimensions.height,
            knownDimensionSource: ContinuousImageDimensionSource.decodedImage,
          );
        })
        .toList(growable: false);
    return changed
        ? List<ContinuousImageItem>.unmodifiable(resolvedItems)
        : items;
  }

  void _scheduleVerticalPageSpacingCompensation({required double pageSpacing}) {
    final anchorIndex = _latestItems.isEmpty
        ? null
        : _lastKnownIndex.clamp(0, _latestItems.length - 1).toInt();
    final anchorId = anchorIndex == null ? null : _latestItems[anchorIndex].id;
    _verticalCompensation.updatePageSpacing(
      pageSpacing: pageSpacing,
      readAnchorOffset: () {
        if (anchorIndex == null ||
            anchorIndex >= _latestItems.length ||
            _latestItems[anchorIndex].id != anchorId) {
          return null;
        }
        return _resolveExactVerticalOffset(anchorIndex) ??
            _estimateVerticalOffset(anchorIndex);
      },
    );
  }

  Widget _buildImage(
    ContinuousImageItem item,
    int index,
    ReaderPreferences preferences, {
    required bool paged,
  }) {
    final ownerId = item.ownerId;
    final session = _readerSession.current;
    final pageController = _pageController;
    final aspectRatio = paged
        ? _resolvedDimensionsByItemId[item.id]?.aspectRatioOrNull ??
              _layoutResolver.resolveInitialHint(item: item).aspectRatio
        : null;
    final sessionBinding = _imageSessionStore.bindingFor(
      item,
      initialLocalPath: _capability.initialLocalPathFor(item),
    );
    final effectiveFit = _effectivePageFit(preferences, paged: paged);
    final image = _capability.buildImageContent(
      context,
      ReaderImageBuildSpec(
        item: item,
        index: index,
        paged: paged,
        fit: _imageFitFor(effectiveFit),
        sessionBinding: sessionBinding,
        expectedDisplaySize: _expectedImageDisplaySize(
          preferences,
          paged: paged,
          fit: effectiveFit,
          aspectRatio: aspectRatio,
        ),
        loadingIndicatorColor: _loadingIndicatorColor(preferences),
        onDimensionsResolved: (size) => _onImageDimensionsResolved(
          ownerId: ownerId,
          session: session,
          itemId: item.id,
          paged: paged,
          size: size,
        ),
        onRetry: () {
          if (_isCurrentImageSession(session)) {
            unawaited(_retrySessionImage(index));
          }
        },
      ),
    );
    if (!paged) {
      return image;
    }
    final fittedImage = ReaderPagedImageFitSurface(
      key: ValueKey<String>(
        'reader-paged-fit-$ownerId-${item.id}-'
        '${effectiveFit.name}-${preferences.readerMode.name}',
      ),
      ownerId: ownerId,
      itemId: item.id,
      pageIndex: index,
      pageFit: effectiveFit,
      readerMode: preferences.readerMode,
      aspectRatio: aspectRatio!,
      onHorizontalOverflowChanged: (hasOverflow) {
        _onPagedHorizontalOverflowChanged(
          ownerId: ownerId,
          session: session,
          pageIndex: index,
          hasOverflow: hasOverflow,
        );
      },
      onEdgeTurnRequested: (intent) {
        _onPagedEdgeTurnRequested(
          ownerId: ownerId,
          session: session,
          sourcePageIndex: index,
          expectedPageController: pageController,
          intent: intent,
        );
      },
      child: image,
    );
    return ReaderZoomableImage(
      key: ValueKey<String>('reader-zoom-surface-${item.id}'),
      gestureCoordinator: _gestureCoordinator,
      activePageIndexListenable: _activePagedIndex,
      pageIndex: index,
      resetToken: '${preferences.pageFit.name}:${preferences.readerMode.name}',
      onZoomStateChanged: (isZoomed) {
        if (_isCurrentImageSession(session)) {
          _onPagedImageZoomStateChanged(index, isZoomed);
        }
      },
      child: fittedImage,
    );
  }

  bool _pagedHorizontalOverflowActive(ReaderPreferences preferences) {
    if (preferences.pageFit != ReaderPageFitPreference.fitHeight ||
        !_pagedPosition.isImage) {
      return false;
    }
    final activeIndex = _pagedPosition.index;
    return activeIndex != null &&
        _pagedHorizontalOverflowByIndex[activeIndex] == true;
  }

  void _onImageDimensionsResolved({
    required String ownerId,
    required ReaderImageSessionToken? session,
    required String itemId,
    required bool paged,
    required Size size,
  }) {
    if (!_isCurrentImageSession(session) ||
        session?.ownerId != ownerId ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    final dimensions = ContinuousImageDimensions(
      width: size.width.round(),
      height: size.height.round(),
    );
    if (!dimensions.isValid ||
        (!paged && !widget.flowPolicy.updateVisibleItemAspectRatio)) {
      return;
    }
    final previous = _resolvedDimensionsByItemId[itemId];
    if (previous?.width == dimensions.width &&
        previous?.height == dimensions.height) {
      return;
    }
    _resolvedDimensionsByItemId[itemId] = dimensions;
    setState(() {});
  }

  void _onPagedHorizontalOverflowChanged({
    required String ownerId,
    required ReaderImageSessionToken? session,
    required int pageIndex,
    required bool hasOverflow,
  }) {
    if (!_isCurrentImageSession(session) || session?.ownerId != ownerId) {
      return;
    }
    final previous = _pagedHorizontalOverflowByIndex[pageIndex] == true;
    if (hasOverflow) {
      _pagedHorizontalOverflowByIndex[pageIndex] = true;
    } else {
      _pagedHorizontalOverflowByIndex.remove(pageIndex);
    }
    if (previous == hasOverflow ||
        !_pagedPosition.isImage ||
        _pagedPosition.index != pageIndex) {
      return;
    }
    setState(() {});
  }

  void _onPagedEdgeTurnRequested({
    required String ownerId,
    required ReaderImageSessionToken? session,
    required int sourcePageIndex,
    required PageController? expectedPageController,
    required ReaderPageTurnIntent intent,
  }) {
    final pageController = _pageController;
    final content = _capability.content;
    if (!_isCurrentImageSession(session) ||
        _zoomGate.value ||
        expectedPageController == null ||
        !identical(pageController, expectedPageController) ||
        !expectedPageController.hasClients ||
        session?.ownerId != ownerId ||
        content.ownerId != ownerId ||
        !_pagedPosition.isImage ||
        _pagedPosition.index != sourcePageIndex ||
        _activePagedIndex.value != sourcePageIndex) {
      return;
    }
    final currentPage = expectedPageController.page;
    if (currentPage == null || (currentPage - sourcePageIndex).abs() > 0.5) {
      return;
    }
    final delta = intent == ReaderPageTurnIntent.next ? 1 : -1;
    final target = sourcePageIndex + delta;
    if (target < 0 || target >= _pagedPageCount(content.length)) {
      return;
    }
    if (target < content.length) {
      _promoteSessionSeekTarget(target);
    }
    _animatePagedTurn(expectedPageController, target);
  }

  void _syncVerticalItemAnchors(List<ContinuousImageItem> items) {
    final activeIds = items.map((item) => item.id).toSet();
    _verticalItemAnchors.removeWhere(
      (itemId, _) => !activeIds.contains(itemId),
    );
    for (final item in items) {
      _verticalItemAnchors.putIfAbsent(
        item.id,
        () => GlobalKey(debugLabel: 'reader-vertical-anchor-${item.id}'),
      );
    }
  }

  _ReaderVerticalTrailingSpec _buildVerticalTrailingSpec(
    ReaderEngineContext engineContext,
  ) {
    final tail = _tailSurface;
    final legacyTrailing = _capability.verticalTrailingBuilder(engineContext);
    final tailCount = tail?.verticalItemCount ?? 0;
    if (tailCount <= 0) {
      return _ReaderVerticalTrailingSpec.single(legacyTrailing);
    }
    final hasActionBar = tail is ReaderTailActionSurface;
    return _ReaderVerticalTrailingSpec(
      itemCount:
          tailCount + (hasActionBar ? 1 : 0) + (legacyTrailing == null ? 0 : 1),
      indexedBuilder: (context, index) {
        if (index < tailCount) {
          return _buildVerticalTailItem(context, tail!, index);
        }
        if (legacyTrailing != null && index == tailCount) {
          final trailing = legacyTrailing(context);
          return hasActionBar
              ? ReaderTailVisibilityItem(
                  controller: _tailActionController,
                  identity: _tailActionController.identity,
                  child: trailing,
                )
              : trailing;
        }
        // The measured bar includes SafeArea. Reserve it once, after all
        // content, so it cannot create a gap before the chapter transition.
        return ReaderTailVisibilityItem(
          controller: _tailActionController,
          identity: _tailActionController.identity,
          child: SizedBox(height: _tailActionController.barHeight),
        );
      },
    );
  }

  Widget _buildPagedTail(BuildContext context, ReaderTailSurface tail) {
    _scheduleAdjacentPreloadIfReady(tail);
    return KeyedSubtree(
      key: Key('reader-tail-${tail.id}'),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: tail is ReaderTailActionSurface
              ? _tailActionController.barHeight
              : 0,
        ),
        child: tail.buildPaged(context, _tailActions(tail)),
      ),
    );
  }

  Widget _buildPagedAdvance(BuildContext context, ReaderTailSurface tail) {
    return KeyedSubtree(
      key: Key('reader-tail-advance-${tail.id}'),
      child: tail.buildAdvance(context, _tailActions(tail)),
    );
  }

  Widget _buildVerticalTailItem(
    BuildContext context,
    ReaderTailSurface tail,
    int index,
  ) {
    if (index == 0) {
      _scheduleTailVisible(tail);
    }
    _scheduleAdjacentPreloadIfReady(tail);
    final child = KeyedSubtree(
      key: Key('reader-tail-vertical-${tail.id}-$index'),
      child: tail.buildVerticalItem(context, _tailActions(tail), index),
    );
    if (tail is! ReaderTailActionSurface) return child;
    return ReaderTailVisibilityItem(
      key: ValueKey((_tailActionController.identity, index)),
      controller: _tailActionController,
      identity: _tailActionController.identity,
      child: child,
    );
  }

  ReaderTailActions _tailActions(ReaderTailSurface tail) {
    return ReaderTailActions(
      onRetry: () => _invokeTailCallback(tail, tail.onRetry),
      onAdvance: () => _invokeTailCallback(tail, tail.onAdvance),
    );
  }

  void _scheduleTailVisible(ReaderTailSurface tail) {
    final key = '${_lastOwnerId ?? '-'}:${tail.id}';
    if (!_reportedTailSurfaceKeys.add(key)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentTail(tail)) {
        return;
      }
      _invokeTailCallback(tail, tail.onVerticalVisible);
    });
  }

  void _scheduleAdjacentPreloadIfReady(ReaderTailSurface tail) {
    if (!tail.isAdjacentPreloadReady) {
      return;
    }
    final ownerId = _lastOwnerId;
    if (ownerId == null) {
      return;
    }
    final key = '$ownerId:${tail.id}';
    if (!_reportedAdjacentPreloadKeys.add(key)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentTail(tail)) {
        return;
      }
      unawaited(_prepareAdjacentPreload(tail, key));
    });
  }

  Future<void> _prepareAdjacentPreload(
    ReaderTailSurface tail,
    String key,
  ) async {
    final plan = await _capability.buildAdjacentPreloadPlan();
    if (!mounted || !_isCurrentTail(tail)) {
      return;
    }
    final ownerId = _lastOwnerId;
    if (ownerId == null || !_reportedAdjacentPreloadKeys.contains(key)) {
      return;
    }
    if (plan == null || plan.images.isEmpty) {
      return;
    }
    _sessionPreloadCoordinator.submitAdjacentWindow(
      context: context,
      plan: plan,
      precacheService: ref.read(forumImagePrecacheServiceProvider),
      expectedDisplaySize: _expectedPreloadDisplaySize(),
    );
  }

  void _invokeTailCallback(
    ReaderTailSurface tail,
    FutureOr<void> Function() callback,
  ) {
    unawaited(_invokeTailCallbackAndWait(tail, callback));
  }

  Future<void> _invokeTailCallbackAndWait(
    ReaderTailSurface tail,
    FutureOr<void> Function() callback,
  ) async {
    if (!_isCurrentTail(tail)) {
      return;
    }
    try {
      await callback();
    } catch (error, stack) {
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekFailed,
        status: 'tailCallbackFailed',
        result: error.runtimeType.toString(),
        message: stack.toString().split('\n').first,
      );
    }
  }

  bool _isCurrentTail(ReaderTailSurface tail) {
    return mounted && identical(_tailSurface, tail);
  }

  void _disposeTailSurface() {
    final tail = _tailSurface;
    if (tail == null) {
      return;
    }
    try {
      tail.dispose();
    } catch (_) {
      // A tail is optional chrome; disposal must never block reader teardown.
    }
  }

  String? _sequencePositionLabel() {
    final tail = _tailSurface;
    final position = _pagedPosition;
    if (tail == null || position.isImage) {
      return null;
    }
    if (position.isAdvance) return null;
    return tail.indicatorLabel(context);
  }

  double? _estimateVerticalOffset(int targetIndex) {
    if (!_scrollController.hasClients || _latestItems.isEmpty) {
      return null;
    }
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    if (!position.hasContentDimensions || maxScroll <= 0) {
      return null;
    }
    final clampedIndex = targetIndex.clamp(0, _latestItems.length - 1).toInt();
    final estimated = _extentRegistry.estimateOffsetForIndex(
      clampedIndex,
      _latestItems,
      crossAxisExtent: MediaQuery.sizeOf(context).width,
      resolver: _layoutResolver,
    );
    if (estimated.isFinite && (estimated > 0 || clampedIndex == 0)) {
      return estimated;
    }
    if (_latestItems.length <= 1) {
      return 0;
    }
    return maxScroll * (clampedIndex / (_latestItems.length - 1));
  }

  double? _resolveExactVerticalOffset(int targetIndex) {
    if (!_scrollController.hasClients ||
        targetIndex < 0 ||
        targetIndex >= _latestItems.length) {
      return null;
    }
    final item = _latestItems[targetIndex];
    final itemContext = _verticalItemAnchors[item.id]?.currentContext;
    final renderObject = itemContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      return null;
    }
    return viewport.getOffsetToReveal(renderObject, 0).offset;
  }

  double _clampVerticalOffset(double offset) {
    if (!_scrollController.hasClients || !offset.isFinite) {
      return 0;
    }
    final position = _scrollController.position;
    return offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  Future<void> _waitForVerticalLayout() async {
    await WidgetsBinding.instance.endOfFrame;
  }

  bool _onVerticalScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _viewportRestoreGeneration++;
      _viewportAnchor = null;
      _verticalPositionDriver.cancelActive(
        ReaderVerticalSeekCancelReason.userScroll,
      );
    }
    return false;
  }

  /// 运行时墨水屏模式下，横向翻页把 `fitWidth` 收成 `contain`，4:3 屏不再
  /// 裁掉两侧内容；滚动模式保持原适配。
  ReaderPageFitPreference _effectivePageFit(
    ReaderPreferences preferences, {
    required bool paged,
  }) {
    if (paged &&
        EInkModeScope.of(context) &&
        preferences.pageFit == ReaderPageFitPreference.fitWidth) {
      return ReaderPageFitPreference.contain;
    }
    return preferences.pageFit;
  }

  BoxFit _imageFitFor(ReaderPageFitPreference fit) {
    switch (fit) {
      case ReaderPageFitPreference.fitWidth:
        return BoxFit.fitWidth;
      case ReaderPageFitPreference.fitHeight:
        return BoxFit.fitHeight;
      case ReaderPageFitPreference.contain:
        return BoxFit.contain;
    }
  }

  Color _backgroundColor(ReaderPreferences preferences) {
    return resolveReaderBackground(
      themeSurface: Theme.of(context).colorScheme.surface,
      background: preferences.background,
      readerMode: preferences.readerMode,
      pagedCanvasColor: _capability.pagedCanvasColor,
      eInkMode: EInkModeScope.of(context),
    );
  }

  Color _loadingIndicatorColor(ReaderPreferences preferences) {
    final background = _backgroundColor(preferences);
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }

  ReaderEngineContext _engineContext(ReaderPreferences preferences, int total) {
    return ReaderEngineContext(
      currentIndex: _lastKnownIndex,
      totalCount: total,
      mode: _readerMode(preferences),
      actions: this,
    );
  }

  // --- owner reset / page controller sync / restore ---

  ScrollController _createScrollController() =>
      ScrollController(keepScrollOffset: false)
        ..addListener(_onVerticalScroll)
        ..addListener(_tailActionController.schedule);

  /// Owner、revision 或 controller 被替换后，旧的视口尺寸锚点不再有意义。
  /// 等待中的补偿也随会话一起丢弃，由下一次布局重新测量。
  void _deactivateVerticalSession() {
    _verticalViewportSize = null;
    _viewportRestoreGeneration++;
    _viewportAnchor = null;
    _verticalCompensation.deactivate();
  }

  void _syncScrollControllerIfNeeded() {
    if (_scrollControllerSessionGeneration == _readerSessionGeneration) return;
    final previous = _scrollController;
    _deactivateVerticalSession();
    previous
      ..removeListener(_onVerticalScroll)
      ..removeListener(_tailActionController.schedule);
    _scrollController = _createScrollController();
    _scrollControllerSessionGeneration = _readerSessionGeneration;
    // The old keyed viewport detaches during this frame's tree update.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  bool _isCurrentImageSession(ReaderImageSessionToken? session) {
    if (!mounted || session == null || !_readerSession.isCurrent(session)) {
      return false;
    }
    final content = _capability.content;
    return !content.isEmpty &&
        content.ownerId == session.ownerId &&
        content.sessionRevision == session.revision;
  }

  bool _isCurrentVerticalSessionToken(
    ReaderImageSessionToken? session,
    ScrollController controller,
  ) =>
      _isCurrentImageSession(session) &&
      identical(controller, _scrollController) &&
      _diagnosticMode == ReaderModePreference.vertical;

  bool _isCurrentVerticalSession(int generation, ScrollController controller) =>
      generation == _readerSessionGeneration &&
      _isCurrentVerticalSessionToken(_readerSession.current, controller);

  ReaderPositionState _resetIfOwnerChanged(
    ReaderContent content,
    ReaderModePreference readerMode,
  ) {
    final current = _positionState;
    if (current != null && current.ownerId == content.ownerId) {
      if (_lastContentRevision != content.sessionRevision) {
        _readerSession.activate(
          ownerId: content.ownerId,
          revision: content.sessionRevision,
        );
        _verticalPositionDriver.cancelActive(
          ReaderVerticalSeekCancelReason.ownerChanged,
        );
        _extentRegistry.clearForOwner(content.ownerId);
        _invalidateVerticalLayoutIndex();
        _verticalItemAnchors.clear();
        final initialIndex = content.initialIndex
            .clamp(0, content.length - 1)
            .toInt();
        final refreshedPosition = ReaderPositionState(
          ownerId: content.ownerId,
          initialLogicalIndex: initialIndex,
        );
        _positionState = refreshedPosition;
        _latestItems = const <ContinuousImageItem>[];
        _deactivateVerticalSession();
        _resolvedDimensionsByItemId.clear();
        _reportedVisibleImageIndexes.clear();
        _reportedTailSurfaceKeys.clear();
        _reportedAdvanceSurfaceKeys.clear();
        _reportedAdjacentPreloadKeys.clear();
        _pagedHorizontalOverflowByIndex.clear();
        _pagedPosition = ReaderSequencePosition.image(initialIndex);
        _setZoomGate(false, paged: false);
        _activePagedIndex.value = initialIndex;
        _lastKnownIndex = initialIndex;
        _thumbnailPreviewIndex = null;
        _seekCoordinator.reset(resetThrottle: false);
        _restoreCoordinator.invalidate();
        _sessionPreloadCoordinator.resetSession(
          readerOwnerId: content.ownerId,
          items: content.items,
        );
        return refreshedPosition;
      }
      return current;
    }
    final previous = _lastOwnerId;
    _verticalPositionDriver.cancelActive(
      ReaderVerticalSeekCancelReason.ownerChanged,
    );
    if (previous != null) {
      _extentRegistry.clearForOwner(previous);
    }
    _verticalItemAnchors.clear();
    _performanceMetrics.reset();
    _invalidateVerticalLayoutIndex();
    final initialIndex = content.initialIndex
        .clamp(0, content.length - 1)
        .toInt();
    final next = ReaderPositionState(
      ownerId: content.ownerId,
      initialLogicalIndex: initialIndex,
    );
    _positionState = next;
    _readerSession.activate(
      ownerId: content.ownerId,
      revision: content.sessionRevision,
    );
    _latestItems = const <ContinuousImageItem>[];
    _deactivateVerticalSession();
    _reportedVisibleImageIndexes.clear();
    _reportedTailSurfaceKeys.clear();
    _reportedAdvanceSurfaceKeys.clear();
    _reportedAdjacentPreloadKeys.clear();
    _pagedHorizontalOverflowByIndex.clear();
    _resolvedDimensionsByItemId.clear();
    _pagedPosition = ReaderSequencePosition.image(initialIndex);
    _setZoomGate(false, paged: false);
    _activePagedIndex.value = initialIndex;
    _lastKnownIndex = initialIndex;
    _thumbnailPreviewIndex = null;
    _seekCoordinator.reset();
    _restoreCoordinator.invalidate();
    _positionRetryScheduled = false;
    _sessionPreloadCoordinator.resetSession(
      readerOwnerId: content.ownerId,
      items: content.items,
    );
    _verticalViewportPrimedGeneration = -1;
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.readerSessionCreated,
      index: _lastKnownIndex,
      mode: readerMode,
      generation: _readerSessionGeneration,
      status: 'created',
      result: 'ready',
      message: _readerMemoryBudgetLogFields(),
    );
    return next;
  }

  String _readerMemoryBudgetLogFields() {
    final imageCache = PaintingBinding.instance.imageCache;
    const policy = ReaderImageSessionPreloadPolicy.aggressiveReaderSession;
    return 'decodedRadius=${policy.decodedRadius} '
        'diskRadius=${policy.diskRadius} '
        'maxConcurrent=${policy.maxConcurrentTasks} '
        'imageCacheMaxEntries=${imageCache.maximumSize} '
        'imageCacheMaxBytes=${imageCache.maximumSizeBytes}';
  }

  void _syncPageControllerIfNeeded(
    ContinuousImageReaderMode mode,
    int initialIndex,
    String ownerId,
  ) {
    if (mode == ContinuousImageReaderMode.vertical) {
      return;
    }
    final expectedInitialPage = initialIndex.clamp(0, 1 << 20).toInt();
    final controller = _pageController;
    if (controller == null || _pageControllerOwnerId != ownerId) {
      // The page controller belongs to one reader owner. Persisting its
      // scroll offset would restore a previous chapter's tail/sentinel page
      // and clamp it to the new chapter's last image.
      _pageController = PageController(
        initialPage: expectedInitialPage,
        keepPage: false,
      );
      _pageControllerOwnerId = ownerId;
      if (controller != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.dispose();
        });
      }
      return;
    }
  }

  void _restorePositionIfNeeded(
    ContinuousImageReaderMode mode,
    ReaderModePreference readerMode,
    ReaderContent content,
  ) {
    final positionState = _positionState;
    if (positionState == null ||
        positionState.ownerId != content.ownerId ||
        _isSliderCommitInFlight ||
        (!positionState.needsInitialRestore &&
            (mode == ContinuousImageReaderMode.vertical ||
                positionState.pendingPagedSeek == null))) {
      return;
    }
    final session = _readerSession.current;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isCurrentImageSession(session) ||
          _isSliderCommitInFlight ||
          !_isCurrentPositionState(positionState, content.length) ||
          _diagnosticMode != readerMode) {
        return;
      }
      if (positionState.needsInitialRestore) {
        final request = _restoreCoordinator.begin(
          isSurfaceCurrent: () =>
              _isCurrentImageSession(session) &&
              _isCurrentPositionState(positionState, content.length) &&
              _diagnosticMode == readerMode &&
              !_isSliderCommitInFlight,
        );
        if (request == null) return;
        try {
          if (mode == ContinuousImageReaderMode.vertical) {
            await _restoreVertical(content, positionState, request);
          } else {
            _restorePaged(content, readerMode, positionState, request);
          }
        } finally {
          _restoreCoordinator.finish(request);
        }
      }
      if (_isCurrentImageSession(session) &&
          mode == ContinuousImageReaderMode.horizontal) {
        _applyPendingPagedSeekIfPossible(content, positionState);
      }
    });
  }

  Future<void> _restoreVertical(
    ReaderContent content,
    ReaderPositionState positionState,
    ReaderRestoreRequest request,
  ) async {
    if (!positionState.needsInitialRestore ||
        !_restoreCoordinator.isCurrent(request)) {
      return;
    }
    final generation = request.generation;
    final targetIndex = positionState.initialLogicalIndex;
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.initialRestoreStarted,
      index: targetIndex,
      mode: ReaderModePreference.vertical,
      generation: generation,
      targetIndex: targetIndex,
      status: 'started',
      result: 'pending',
    );
    if (!_scrollController.hasClients) {
      _recordInitialRestoreCompleted(
        index: targetIndex,
        mode: ReaderModePreference.vertical,
        generation: generation,
        status: 'pending',
        result: 'controllerNotAttached',
      );
      _schedulePositionRetry();
      return;
    }

    final targetOffset = _capability.initialVerticalScrollOffset;
    _verticalCompensation.cancelPending();
    var result = 'noStoredOffset';
    ReaderVerticalSeekResult? verticalSeek;
    if (_scrollController.offset == 0 &&
        targetOffset != null &&
        targetOffset > 0) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        final offset = targetOffset.clamp(0.0, maxScroll).toDouble();
        if (offset > 0) {
          _scrollController.jumpTo(offset);
          result = 'jumped';
        }
      } else {
        result = 'noScrollableExtent';
      }
    } else if (_scrollController.offset == 0 && targetIndex > 0) {
      verticalSeek = await _verticalPositionDriver.seekToIndex(targetIndex);
      if (!_restoreCoordinator.isCurrent(request)) {
        return;
      }
      _performanceMetrics.recordSeek(
        elapsed: verticalSeek.elapsed,
        correctionDelta: verticalSeek.correctionDelta,
      );
      if (verticalSeek.status == ReaderVerticalSeekStatus.cancelled) {
        positionState.consumeInitialRestore();
        _recordInitialRestoreCompleted(
          index: _lastKnownIndex,
          mode: ReaderModePreference.vertical,
          generation: generation,
          status: 'cancelled',
          result: verticalSeek.cancelReason?.name ?? 'cancelled',
          elapsedMs: verticalSeek.elapsed.inMilliseconds,
          correctionDelta: verticalSeek.correctionDelta,
        );
        _scheduleVerticalProgressSync();
        return;
      }
      result = verticalSeek.exact ? 'indexExact' : 'indexEstimated';
    } else if (_scrollController.offset != 0) {
      result = 'alreadyMoved';
    }

    if (!_restoreCoordinator.isCurrent(request)) {
      return;
    }
    positionState.consumeInitialRestore();
    _commitLogicalIndex(targetIndex);
    _recordInitialRestoreCompleted(
      index: targetIndex,
      mode: ReaderModePreference.vertical,
      generation: generation,
      status: 'consumed',
      result: result,
      elapsedMs: verticalSeek?.elapsed.inMilliseconds,
      correctionDelta: verticalSeek?.correctionDelta,
    );
    _scheduleVerticalProgressSync();
  }

  void _restorePaged(
    ReaderContent content,
    ReaderModePreference readerMode,
    ReaderPositionState positionState,
    ReaderRestoreRequest request,
  ) {
    if (!positionState.needsInitialRestore ||
        !_restoreCoordinator.isCurrent(request)) {
      return;
    }
    final generation = request.generation;
    final targetPage = positionState.initialLogicalIndex;
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.initialRestoreStarted,
      index: targetPage,
      mode: readerMode,
      generation: generation,
      targetIndex: targetPage,
      status: 'started',
      result: 'pending',
    );
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) {
      _recordInitialRestoreCompleted(
        index: targetPage,
        mode: readerMode,
        generation: generation,
        status: 'pending',
        result: 'controllerNotAttached',
      );
      _schedulePositionRetry();
      return;
    }
    if (pageController.position.isScrollingNotifier.value) {
      _recordInitialRestoreCompleted(
        index: targetPage,
        mode: readerMode,
        generation: generation,
        status: 'pending',
        result: 'controllerStillScrolling',
      );
      _schedulePositionRetry();
      return;
    }
    final page = pageController.page;
    var result = 'alreadyAtTarget';
    if (page == null || (page - targetPage).abs() >= 0.01) {
      pageController.jumpToPage(targetPage);
      result = 'jumped';
    }
    positionState.consumeInitialRestore();
    _commitLogicalIndex(targetPage);
    _reportActualImageVisible(
      index: targetPage,
      ownerId: content.ownerId,
      sessionGeneration: _readerSessionGeneration,
    );
    _recordInitialRestoreCompleted(
      index: targetPage,
      mode: readerMode,
      generation: generation,
      status: 'consumed',
      result: result,
    );
  }

  void _recordInitialRestoreCompleted({
    required int index,
    required ReaderModePreference mode,
    required int generation,
    required String status,
    required String result,
    int? elapsedMs,
    double? correctionDelta,
  }) {
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.initialRestoreCompleted,
      index: index,
      mode: mode,
      generation: generation,
      targetIndex: index,
      status: status,
      result: result,
      elapsedMs: elapsedMs,
      correctionDelta: correctionDelta,
    );
  }

  bool _isCurrentPositionState(
    ReaderPositionState positionState,
    int expectedItemCount,
  ) {
    final content = _capability.content;
    return _isCurrentImageSession(_readerSession.current) &&
        identical(_positionState, positionState) &&
        content.ownerId == positionState.ownerId &&
        content.length == expectedItemCount;
  }

  void _commitLogicalIndex(int index) {
    final positionState = _positionState;
    if (positionState != null) {
      positionState.commitLogicalIndex(index);
    }
    _lastKnownIndex = index;
    if (_diagnosticMode != ReaderModePreference.vertical &&
        _activePagedIndex.value != index) {
      _setZoomGate(false, paged: true);
      _activePagedIndex.value = index;
    }
  }

  void _schedulePositionRetry() {
    if (_positionRetryScheduled) {
      return;
    }
    _positionRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionRetryScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool _queueOrApplyPagedSeek({
    required ReaderContent content,
    required ReaderPositionState positionState,
    required int targetIndex,
    required int generation,
    bool recordReached = false,
  }) {
    positionState.queuePagedSeek(index: targetIndex, generation: generation);
    return _applyPendingPagedSeekIfPossible(
      content,
      positionState,
      recordReached: recordReached,
    );
  }

  bool _applyPendingPagedSeekIfPossible(
    ReaderContent content,
    ReaderPositionState positionState, {
    bool recordReached = true,
  }) {
    final pending = positionState.pendingPagedSeek;
    if (pending == null ||
        !_isCurrentPositionState(positionState, content.length)) {
      return false;
    }
    if (pending.logicalIndex < 0 || pending.logicalIndex >= content.length) {
      positionState.clearPendingPagedSeek(pending);
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekFailed,
        index: positionState.committedLogicalIndex,
        generation: pending.generation,
        targetIndex: pending.logicalIndex,
        status: 'rejected',
        result: 'targetOutOfRange',
      );
      return false;
    }
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) {
      _schedulePositionRetry();
      return false;
    }
    final page = pageController.page;
    if (page == null || (page - pending.logicalIndex).abs() >= 0.01) {
      pageController.jumpToPage(pending.logicalIndex);
    }
    positionState.clearPendingPagedSeek(pending);
    _commitLogicalIndex(pending.logicalIndex);
    if (recordReached) {
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekReached,
        index: pending.logicalIndex,
        generation: pending.generation,
        targetIndex: pending.logicalIndex,
        status: 'completed',
        result: 'pendingApplied',
      );
    }
    return true;
  }

  // --- vertical scroll progress + active index ---

  void _onVerticalScroll() {
    if (!_scrollController.hasClients ||
        _viewportAnchor != null ||
        _isSliderCommitInFlight ||
        (_positionState?.needsInitialRestore ?? true)) {
      return;
    }
    _verticalViewportPrimedGeneration = _readerSessionGeneration;
    _verticalCompensation.syncPosition();
    _verticalCompensation.flushIfIdle();
    _hideReaderMenuForContentMotion();
    final position = _scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }
    final items = _latestItems;
    final total = items.length;
    if (total == 0) {
      return;
    }
    final viewport = _verticalLayoutFor(MediaQuery.sizeOf(context).width)
        .resolve(
          scrollOffset: position.pixels,
          viewportExtent: position.viewportDimension,
          userScrollDirection: _viewportTracker.directionFromPosition(position),
        );
    final index =
        viewport.lastEndVisibleIndex ??
        viewport.lastVisibleIndex ??
        viewport.firstVisibleIndex;
    // Tail rows contribute to scroll extent, but never to image progress or
    // image preloading. Keep the last real image position in the comment feed.
    if (index == null) return;
    _reportActualImageVisible(
      index: index,
      ownerId: _lastOwnerId ?? _capability.content.ownerId,
      sessionGeneration: _readerSessionGeneration,
    );
    if (index != _lastKnownIndex) {
      _commitLogicalIndex(index);
      _capability.onScrollProgress(index: index, offset: position.pixels);
      _submitSessionPreloadWindow(
        focusIndex: index,
        scrollDirection: viewport.userScrollDirection,
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _recordExtent(
    ContinuousImageExtent extent, {
    required ReaderImageSessionToken? session,
  }) {
    if (!_isCurrentImageSession(session) ||
        extent.ownerId != session?.ownerId) {
      return;
    }
    if ((extent.crossAxisExtent - MediaQuery.sizeOf(context).width).abs() >
        .5) {
      return;
    }
    final previous = _extentRegistry.extentOf(extent.itemId);
    final plan = _viewportAnchor == null
        ? _planScrollCompensation(previous, extent)
        : ContinuousImageScrollCompensationPlan.none('viewportRestore');
    _extentRegistry.record(extent);
    if (previous?.mainAxisExtent != extent.mainAxisExtent) {
      _verticalLayoutIndex = null;
    }
    _verticalCompensation.applyPlan(plan);
  }

  ContinuousImageLayoutIndex _verticalLayoutFor(double width) {
    if (_verticalLayoutIndex == null ||
        !identical(_indexedItems, _latestItems) ||
        _indexedWidth != width) {
      _verticalLayoutIndex = ContinuousImageLayoutIndex(
        items: _latestItems,
        extentRegistry: _extentRegistry,
        crossAxisExtent: width,
        resolver: _layoutResolver,
      );
      _indexedItems = _latestItems;
      _indexedWidth = width;
    }
    return _verticalLayoutIndex!;
  }

  void _invalidateVerticalLayoutIndex() {
    _verticalLayoutIndex = null;
    _indexedItems = null;
    _indexedWidth = null;
  }

  ContinuousImageScrollCompensationPlan _planScrollCompensation(
    ContinuousImageExtent? previous,
    ContinuousImageExtent next,
  ) {
    if (!_scrollController.hasClients || _latestItems.isEmpty) {
      return ContinuousImageScrollCompensationPlan.none('noScrollContext');
    }
    _verticalCompensation.syncPosition();
    final position = _scrollController.position;
    return _anchorCoordinator.planForExtentChange(
      previousExtent: previous,
      nextExtent: next,
      items: _latestItems,
      extentRegistry: _extentRegistry,
      allowScrollOffsetCompensation:
          widget.flowPolicy.allowScrollOffsetCompensation,
      metrics: ContinuousImageScrollAnchorMetrics(
        scrollOffset: position.pixels,
        minScrollExtent: position.minScrollExtent,
        maxScrollExtent: position.maxScrollExtent,
        viewportExtent: position.viewportDimension,
        userScrollDirection: _viewportTracker.directionFromPosition(position),
        isScrollActivityInProgress: position.isScrollingNotifier.value,
      ),
    );
  }

  void _reportActualImageVisible({
    required int index,
    required String ownerId,
    required int sessionGeneration,
  }) {
    final content = _capability.content;
    if (index < 0 ||
        index >= content.length ||
        _lastOwnerId != ownerId ||
        _readerSessionGeneration != sessionGeneration ||
        content.ownerId != ownerId ||
        !_reportedVisibleImageIndexes.add(index)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _lastOwnerId != ownerId ||
          _readerSessionGeneration != sessionGeneration ||
          _capability.content.ownerId != ownerId ||
          index < 0 ||
          index >= _capability.content.length) {
        return;
      }
      _capability.onImageVisible(index);
    });
  }

  // --- paged turning + page change ---

  Future<void> _onPageChanged(
    int pageIndex, {
    required String ownerId,
    required PageController pageController,
  }) async {
    if (!mounted ||
        _lastOwnerId != ownerId ||
        _capability.content.ownerId != ownerId ||
        !identical(_pageController, pageController)) {
      return;
    }
    final content = _capability.content;
    final page = pageController.page;
    if (page != null && (page - pageIndex).abs() > 0.5) {
      return;
    }
    final positionState = _positionState;
    if (positionState != null &&
        positionState.needsInitialRestore &&
        positionState.ownerId == content.ownerId &&
        pageIndex != content.initialIndex) {
      return;
    }
    final wasOnImage = _pagedPosition.isImage;
    final position = _pagedPositionForPage(pageIndex, content.length);
    if (!position.isImage) {
      _hideReaderMenuForContentMotion();
      _pagedPosition = position;
      if (position.isTail) {
        final tail = _tailSurface;
        if (tail != null) {
          final key = '${_lastOwnerId ?? '-'}:${tail.id}';
          if (_reportedTailSurfaceKeys.add(key)) {
            _invokeTailCallback(tail, tail.onVisible);
          }
        }
      } else if (position.isAdvance) {
        final tail = _tailSurface;
        if (tail != null) {
          final key = '${_lastOwnerId ?? '-'}:${tail.id}';
          if (_reportedAdvanceSurfaceKeys.add(key)) {
            unawaited(_invokeAdvanceCallbackAndAllowRetry(tail, key));
          }
        }
      }
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _pagedPosition = position;
    _reportActualImageVisible(
      index: pageIndex,
      ownerId: ownerId,
      sessionGeneration: _readerSessionGeneration,
    );
    if (pageIndex == _lastKnownIndex) {
      if (!wasOnImage && mounted) {
        setState(() {});
      }
      return;
    }
    final previousIndex = _lastKnownIndex;
    _hideReaderMenuForContentMotion();
    _commitLogicalIndex(pageIndex);
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.pageChanged,
      index: pageIndex,
      generation: _isSliderCommitInFlight ? _seekGeneration : null,
      targetIndex: _pendingCommittedIndex,
      status: 'arrived',
      result: 'pageChanged',
    );
    _capability.onScrollProgress(index: pageIndex, offset: 0);
    _submitSessionPreloadWindow(
      focusIndex: pageIndex,
      scrollDirection: pageIndex < previousIndex
          ? ContinuousImageScrollDirection.reverse
          : ContinuousImageScrollDirection.forward,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _invokeAdvanceCallbackAndAllowRetry(
    ReaderTailSurface tail,
    String key,
  ) async {
    await _invokeTailCallbackAndWait(tail, tail.onAdvance);
    if (mounted) {
      // A successful owner change clears this set during the next session
      // reset. On failure, removing the key lets the user retry after
      // returning to the comment tail; never animate the old PageView back.
      _reportedAdvanceSurfaceKeys.remove(key);
    }
  }

  void _turnPageByTap({
    required ReaderModePreference mode,
    required int total,
    required bool isLeftTap,
  }) {
    final isRtl = mode == ReaderModePreference.rtl;
    final isPreviousAction = isRtl ? !isLeftTap : isLeftTap;
    _turnPage(forward: !isPreviousAction, total: total);
  }

  /// 横向翻页的统一入口：触摸点按与硬件键只负责把方向翻译成 forward。
  void _turnPage({required bool forward, required int total}) {
    if (_zoomGate.value) {
      return;
    }
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) {
      return;
    }
    final current =
        pageController.page?.round() ??
        _pagedPageForPosition(_pagedPosition, total);
    final delta = forward ? 1 : -1;
    final target = (current + delta)
        .clamp(0, _pagedPageCount(total) - 1)
        .toInt();
    if (target == current) {
      return;
    }
    if (target < total) {
      _promoteSessionSeekTarget(target);
    }
    // 全量模式不触碰 EPDC 通道；翻页动画本身保持原样。
    if (EInkModeScope.of(context)) {
      unawaited(
        ref
            .read(einkPageRippleServiceProvider)
            .triggerPageRipple(
              forward: forward,
              speed: EInkRippleSpeed.standard,
            ),
      );
    }
    _animatePagedTurn(pageController, target);
  }

  void _animatePagedTurn(PageController pageController, int target) {
    if (AppMotion.reduceMotion(context)) {
      pageController.jumpToPage(target);
      return;
    }
    unawaited(
      pageController.animateToPage(
        target,
        duration: ReaderPagedTurnMotion.animationDuration,
        curve: ReaderPagedTurnMotion.animationCurve,
      ),
    );
  }

  int _pagedPageCount(int imageCount) {
    final tail = _tailSurface;
    if (tail == null) {
      return imageCount;
    }
    return imageCount + 1 + (tail.hasAdvance ? 1 : 0);
  }

  int _pagedPageForPosition(ReaderSequencePosition position, int imageCount) {
    if (position.isImage) {
      return (position.index ?? 0).clamp(0, imageCount - 1).toInt();
    }
    if (position.isTail) {
      return imageCount;
    }
    return imageCount + 1;
  }

  ReaderSequencePosition _pagedPositionForPage(int pageIndex, int imageCount) {
    if (pageIndex < imageCount) {
      return ReaderSequencePosition.image(pageIndex);
    }
    final tail = _tailSurface;
    if (tail == null) {
      return ReaderSequencePosition.image(
        pageIndex.clamp(0, imageCount - 1).toInt(),
      );
    }
    if (pageIndex == imageCount) {
      return ReaderSequencePosition.tail(tail.id);
    }
    if (tail.hasAdvance && pageIndex == imageCount + 1) {
      return ReaderSequencePosition.advance('${tail.id}:advance');
    }
    return ReaderSequencePosition.tail(tail.id);
  }

  // --- slider commit state machine ---

  void _onProgressChangeStart(double sliderValue, int total) {
    final index = sliderValue.round().clamp(0, total - 1).toInt();
    _thumbnailPreviewIndex = null;
    setState(() => _seekCoordinator.preview(index));
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.seekPreviewChanged,
      index: index,
      generation: _seekGeneration,
      targetIndex: index,
      status: 'started',
      result: 'preview',
    );
  }

  void _onProgressChanged(double sliderValue, int total) {
    final index = sliderValue.round().clamp(0, total - 1).toInt();
    final didChange = _sliderPreviewIndex != index;
    _thumbnailPreviewIndex = null;
    setState(() => _seekCoordinator.preview(index));
    if (didChange) {
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekPreviewChanged,
        index: index,
        generation: _seekGeneration,
        targetIndex: index,
        status: 'changed',
        result: 'preview',
      );
    }
  }

  Future<void> _onProgressChangeEnd({
    required double sliderValue,
    required ReaderPreferences preferences,
    required int total,
  }) {
    return _commitSeekToIndex(
      targetIndex: sliderValue.round().clamp(0, total - 1).toInt(),
      preferences: preferences,
      total: total,
      respectThrottle: true,
    );
  }

  Future<void> _commitSeekToIndex({
    required int targetIndex,
    required ReaderPreferences preferences,
    required int total,
    required bool respectThrottle,
  }) async {
    final content = _capability.content;
    final positionState = _positionState;
    if (!mounted ||
        positionState == null ||
        positionState.ownerId != content.ownerId ||
        total != content.length ||
        targetIndex < 0 ||
        targetIndex >= content.length) {
      if (mounted) {
        setState(() => _seekCoordinator.preview(null));
      }
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekFailed,
        index: _lastKnownIndex,
        mode: preferences.readerMode,
        generation: _seekGeneration,
        targetIndex: targetIndex,
        status: 'rejected',
        result: 'staleOwnerOrItemCount',
      );
      return;
    }
    final session = _readerSession.current;
    final request = _seekCoordinator.beginSlider(
      targetIndex: targetIndex,
      now: DateTime.now(),
      respectInterval: respectThrottle,
      isSurfaceCurrent: () =>
          _isCurrentImageSession(session) &&
          _isCurrentPositionState(positionState, total) &&
          _diagnosticMode == preferences.readerMode,
    );
    if (request == null) return;
    _verticalCompensation.cancelPending();
    _restoreCoordinator.invalidate();
    final previousIndex = _lastKnownIndex;
    final seekGeneration = request.generation;
    final seekStopwatch = Stopwatch()..start();
    var seekCorrectionDelta = 0.0;
    var performanceRecorded = false;
    if (positionState.needsInitialRestore) {
      positionState.consumeInitialRestore();
    }

    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.seekStarted,
      index: previousIndex,
      mode: preferences.readerMode,
      generation: seekGeneration,
      targetIndex: targetIndex,
      status: 'inFlight',
      result: 'pending',
    );

    setState(() {});
    _promoteSessionSeekTarget(targetIndex);

    try {
      var reached = false;
      if (preferences.readerMode == ReaderModePreference.vertical) {
        final verticalResult = await _jumpVerticalToIndex(targetIndex);
        if (!_seekCoordinator.isCurrent(request)) return;
        seekCorrectionDelta = verticalResult.correctionDelta;
        _performanceMetrics.recordSeek(
          elapsed: verticalResult.elapsed,
          correctionDelta: seekCorrectionDelta,
        );
        performanceRecorded = true;
        if (verticalResult.status == ReaderVerticalSeekStatus.cancelled) {
          _recordSeekSuperseded(
            seekGeneration: seekGeneration,
            targetIndex: targetIndex,
            mode: preferences.readerMode,
            reason: verticalResult.cancelReason?.name ?? 'cancelled',
            elapsedMs: verticalResult.elapsed.inMilliseconds,
            correctionDelta: seekCorrectionDelta,
          );
          _scheduleVerticalProgressSync();
          return;
        }
        if (!verticalResult.reached) {
          throw StateError('verticalSeekUnavailable');
        }
        if (!_seekCoordinator.isCurrent(request)) {
          _recordSeekSuperseded(
            seekGeneration: seekGeneration,
            targetIndex: targetIndex,
            mode: preferences.readerMode,
            elapsedMs: verticalResult.elapsed.inMilliseconds,
            correctionDelta: seekCorrectionDelta,
          );
          return;
        }
        _commitLogicalIndex(targetIndex);
        reached = true;
      } else {
        reached = _queueOrApplyPagedSeek(
          content: content,
          positionState: positionState,
          targetIndex: targetIndex,
          generation: seekGeneration,
        );
        if (reached) {
          _performanceMetrics.recordSeek(
            elapsed: seekStopwatch.elapsed,
            correctionDelta: 0,
          );
          performanceRecorded = true;
        }
      }

      if (!_seekCoordinator.isCurrent(request)) {
        _recordSeekSuperseded(
          seekGeneration: seekGeneration,
          targetIndex: targetIndex,
          mode: preferences.readerMode,
          elapsedMs: seekStopwatch.elapsed.inMilliseconds,
          correctionDelta: seekCorrectionDelta,
        );
        return;
      }
      await _capability.onSeek(
        index: targetIndex,
        offset:
            preferences.readerMode == ReaderModePreference.vertical &&
                _scrollController.hasClients
            ? _scrollController.offset
            : 0,
      );
      if (!_seekCoordinator.isCurrent(request)) return;
      if (reached) {
        _recordReaderDiagnostic(
          type: ContinuousImageDiagnosticEventType.seekReached,
          index: targetIndex,
          mode: preferences.readerMode,
          generation: seekGeneration,
          targetIndex: targetIndex,
          status: 'completed',
          result: 'reached',
          elapsedMs: seekStopwatch.elapsed.inMilliseconds,
          correctionDelta: seekCorrectionDelta,
        );
      } else {
        _recordReaderDiagnostic(
          type: ContinuousImageDiagnosticEventType.seekStarted,
          index: positionState.committedLogicalIndex,
          mode: preferences.readerMode,
          generation: seekGeneration,
          targetIndex: targetIndex,
          status: 'pendingAttach',
          result: 'queued',
        );
      }
    } catch (error) {
      if (!_seekCoordinator.isCurrent(request)) return;
      if (!performanceRecorded) {
        _performanceMetrics.recordSeek(
          elapsed: seekStopwatch.elapsed,
          correctionDelta: seekCorrectionDelta,
        );
      }
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekFailed,
        index: _lastKnownIndex,
        mode: preferences.readerMode,
        generation: seekGeneration,
        targetIndex: targetIndex,
        status: 'failed',
        result: error.runtimeType.toString(),
        elapsedMs: seekStopwatch.elapsed.inMilliseconds,
        correctionDelta: seekCorrectionDelta,
      );
    } finally {
      _releaseSliderCommitLock(request);
    }
  }

  void _recordSeekSuperseded({
    required int seekGeneration,
    required int targetIndex,
    required ReaderModePreference mode,
    String reason = 'ownerOrItemCountChanged',
    int? elapsedMs,
    double? correctionDelta,
  }) {
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.seekSuperseded,
      index: _lastKnownIndex,
      mode: mode,
      generation: seekGeneration,
      targetIndex: targetIndex,
      status: 'superseded',
      result: reason,
      elapsedMs: elapsedMs,
      correctionDelta: correctionDelta,
    );
  }

  void _releaseSliderCommitLock(ReaderSeekRequest request) {
    if (_seekCoordinator.finish(request) && mounted) {
      setState(() {});
      if (_diagnosticMode == ReaderModePreference.vertical) {
        _scheduleVerticalProgressSync();
      }
    }
  }

  Future<ReaderVerticalSeekResult> _jumpVerticalToIndex(int targetIndex) {
    return _verticalPositionDriver.seekToIndex(targetIndex);
  }

  void _scheduleVerticalProgressSync() {
    final sessionGeneration = _readerSessionGeneration;
    final scrollController = _scrollController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentVerticalSession(sessionGeneration, scrollController) &&
          !_isSliderCommitInFlight) {
        _onVerticalScroll();
      }
    });
  }

  void _precachePagedWindow(int centerIndex) {
    _submitSessionPreloadWindow(
      focusIndex: centerIndex,
      scrollDirection: ContinuousImageScrollDirection.idle,
    );
  }

  void _submitSessionPreloadWindow({
    required int focusIndex,
    required ContinuousImageScrollDirection scrollDirection,
  }) {
    final items = _latestItems;
    if (!mounted || items.isEmpty) {
      return;
    }
    _sessionPreloadCoordinator.submitWindow(
      context: context,
      content: ReaderContent(
        ownerId: _lastOwnerId ?? _capability.content.ownerId,
        items: items,
        initialIndex: _capability.content.initialIndex,
        sessionRevision: _capability.content.sessionRevision,
      ),
      focusIndex: focusIndex,
      scrollDirection: scrollDirection,
      capability: _capability,
      precacheService: ref.read(forumImagePrecacheServiceProvider),
      expectedDisplaySize: _expectedPreloadDisplaySize(),
    );
  }

  void _promoteSessionSeekTarget(int index) {
    final items = _latestItems;
    if (!mounted || items.isEmpty) {
      return;
    }
    _sessionPreloadCoordinator.promoteSeekTarget(
      context: context,
      content: ReaderContent(
        ownerId: _lastOwnerId ?? _capability.content.ownerId,
        items: items,
        initialIndex: _capability.content.initialIndex,
        sessionRevision: _capability.content.sessionRevision,
      ),
      index: index,
      capability: _capability,
      precacheService: ref.read(forumImagePrecacheServiceProvider),
      expectedDisplaySize: _expectedPreloadDisplaySize(),
    );
  }

  Future<void> _retrySessionImage(int index) async {
    final items = _latestItems;
    final content = _capability.content;
    if (!mounted || items.isEmpty || index < 0 || index >= items.length) {
      return;
    }
    final item = items[index];
    final ownerId = content.ownerId;
    final revision = content.sessionRevision;
    final session = _readerSession.current;
    final retryIdentity = '$ownerId:$revision:${item.id}';
    if (!_imageRetryInFlight.add(retryIdentity)) {
      return;
    }
    try {
      try {
        await _capability.beforeImageRetry(item: item, index: index);
      } catch (_) {
        // Business recovery is best effort. Preserve the original direct
        // image retry even when the chapter probe cannot be confirmed.
      }
      if (!mounted ||
          !_isCurrentImageSession(session) ||
          index >= _latestItems.length) {
        return;
      }
      final currentItem = _latestItems[index];
      if (currentItem.id != item.id || currentItem.url != item.url) {
        return;
      }
      await _sessionPreloadCoordinator.prepareOne(
        context: context,
        content: ReaderContent(
          ownerId: ownerId,
          items: _latestItems,
          initialIndex: _capability.content.initialIndex,
          sessionRevision: revision,
        ),
        index: index,
        capability: _capability,
        precacheService: ref.read(forumImagePrecacheServiceProvider),
        expectedDisplaySize: _expectedPreloadDisplaySize(),
        force: true,
      );
    } finally {
      _imageRetryInFlight.remove(retryIdentity);
    }
  }

  Size? _expectedPreloadDisplaySize() {
    if (!mounted) {
      return null;
    }
    final preferences =
        ref.read(readerPreferencesControllerProvider).value ??
        ReaderPreferences.defaults();
    final paged = _diagnosticMode != ReaderModePreference.vertical;
    return _expectedImageDisplaySize(
      preferences,
      paged: paged,
      fit: _effectivePageFit(preferences, paged: paged),
    );
  }

  /// 预解码尺寸必须与画布实际使用的适配一致，否则墨水屏把 `fitWidth` 收成
  /// `contain` 后仍会按 width 多解像素。
  Size _expectedImageDisplaySize(
    ReaderPreferences preferences, {
    required bool paged,
    required ReaderPageFitPreference fit,
    double? aspectRatio,
  }) {
    final mediaSize = MediaQuery.sizeOf(context);
    if (!paged) {
      return mediaSize;
    }
    final inset = preferences.pageSpacing.clamp(0.0, 48.0).toDouble() * 2;
    final viewport = Size(
      (mediaSize.width - inset).clamp(1.0, double.infinity).toDouble(),
      (mediaSize.height - inset).clamp(1.0, double.infinity).toDouble(),
    );
    final ratio = aspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return viewport;
    }
    switch (fit) {
      case ReaderPageFitPreference.fitWidth:
        return Size(viewport.width, viewport.width / ratio);
      case ReaderPageFitPreference.fitHeight:
        return Size(viewport.height * ratio, viewport.height);
      case ReaderPageFitPreference.contain:
        return applyBoxFit(
          BoxFit.contain,
          Size(ratio, 1),
          viewport,
        ).destination;
    }
  }

  void _recordSessionPreloadScheduled(
    ReaderImageSessionPreloadScheduled scheduled,
  ) {
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.prefetchScheduled,
      ownerId: scheduled.readerOwnerId,
      itemId: scheduled.itemId,
      index: scheduled.imageIndex,
      source: scheduled.spec.sourceUrl,
      generation: scheduled.generation,
      status: 'scheduled',
      result: 'pending',
      preloadKind: scheduled.kind.name,
      applied: true,
    );
  }

  void _recordSessionPreload(ReaderImageSessionPreloadResult result) {
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.prefetchCompleted,
      ownerId: result.readerOwnerId,
      itemId: result.itemId,
      index: result.imageIndex,
      source: result.spec.sourceUrl,
      generation: result.generation,
      status: 'completed',
      result: result.result.success ? 'success' : 'failure',
      preloadKind: result.kind.name,
      applied: result.applied,
      elapsedMs: result.elapsed.inMilliseconds,
      message:
          'diskAttempted=${result.result.diskCacheAttempted} '
          'diskHit=${result.result.fromDiskCache} '
          'decodeAttempted=${result.result.decodePrecacheAttempted} '
          'decoded=${result.result.decoded} '
          'stale=${result.stale} '
          'providerMatched=${result.providerMatched} '
          'reason=${result.result.failureReason ?? '-'} '
          '${_performanceMetrics.snapshot.toLogFields()}',
    );
  }

  // --- mode + display settings sheets ---

  @override
  void openDisplaySettings() {
    unawaited(_showDisplaySettingsSheet());
  }

  @override
  void openModeSheet() {
    unawaited(_showModeSheet());
  }

  @override
  void cycleReaderMode() {
    final currentMode =
        ref.read(readerPreferencesControllerProvider).value?.readerMode ??
        ReaderPreferences.defaults().readerMode;
    const modes = ReaderModePreference.values;
    final nextMode = modes[(currentMode.index + 1) % modes.length];
    unawaited(_onReaderModeChanged(nextMode));
  }

  @override
  void exportCurrentImage() {
    unawaited(_exportCurrentImage());
  }

  Future<void> _exportCurrentImage() async {
    final content = _capability.content;
    if (content.isEmpty) {
      return;
    }
    final index = _lastKnownIndex.clamp(0, content.length - 1).toInt();
    final item = content.items[index];
    final metadata = _capability.exportMetadataFor(item);
    if (metadata == null) {
      _showExportMessage(
        AppLocalizations.of(context).readerDownloadUnsupported,
      );
      return;
    }
    final identity = '${content.ownerId}:${item.id}';
    if (_exportingIdentity == identity) {
      return;
    }
    _exportingIdentity = identity;
    _overlayController.hideMenu();
    _showExportMessage(AppLocalizations.of(context).readerExportSaving);
    try {
      final result = await ref
          .read(readerImageExportServiceProvider)
          .export(
            ReaderImageExportRequest(
              cacheRequest: _capability.cacheRequestFor(item),
              metadata: metadata,
            ),
          );
      if (!mounted || _exportingIdentity != identity) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      _showExportMessage(
        result.success
            ? l10n.readerExportSaved(
                result.destination?.displayLocation ??
                    l10n.readerExportDefaultDestination,
              )
            : ReaderTextResolver.exportFailure(l10n, result.failureReason),
      );
    } finally {
      if (_exportingIdentity == identity) {
        _exportingIdentity = null;
      }
    }
  }

  void _showExportMessage(String message) {
    if (!mounted) {
      return;
    }
    showTransientSnackBar(context, message);
  }

  Future<void> _showDisplaySettingsSheet() async {
    _overlayController.hideMenu();
    final preferences =
        ref.read(readerPreferencesControllerProvider).value ??
        ReaderPreferences.defaults();
    final controller = ref.read(readerPreferencesControllerProvider.notifier);
    final baseTheme = Theme.of(context);
    final canvasBackground = resolveReaderBackground(
      themeSurface: baseTheme.colorScheme.surface,
      background: preferences.background,
      readerMode: preferences.readerMode,
      pagedCanvasColor: _capability.pagedCanvasColor,
      eInkMode: EInkModeScope.of(context),
    );
    final panelPalette = ReaderPanelPalette.fromCanvas(
      canvasBackground: canvasBackground,
      baseTheme: baseTheme,
    );
    await showAdaptivePanel<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panelPalette.panelSurface,
      builder: (context) => ReaderDisplaySettingsSheet(
        preferences: preferences,
        backgroundNote: _capability.pagedBackgroundSettingsNote,
        pagedCanvasColor: _capability.pagedCanvasColor,
        onModeChanged: (mode) => unawaited(_onReaderModeChanged(mode)),
        onPageFitChanged: (value) => unawaited(controller.setPageFit(value)),
        onBackgroundChanged: (value) =>
            unawaited(controller.setBackground(value)),
        onPageSpacingPreview: controller.previewPageSpacing,
        onPageSpacingChanged: (value) =>
            unawaited(controller.setPageSpacing(value)),
        onShowPageIndicatorChanged: (value) =>
            unawaited(controller.setShowPageIndicator(value)),
        hardwarePageKeysEnabled: _hardwarePageKeysEnabled,
        onHardwarePageKeysChanged: (value) => unawaited(
          ref.read(hardwarePageKeysEnabledProvider.notifier).setEnabled(value),
        ),
      ),
    );
  }

  Future<void> _showModeSheet() async {
    _overlayController.hideMenu();
    final preferences =
        ref.read(readerPreferencesControllerProvider).value ??
        ReaderPreferences.defaults();
    final currentMode = preferences.readerMode;
    final baseTheme = Theme.of(context);
    final canvasBackground = resolveReaderBackground(
      themeSurface: baseTheme.colorScheme.surface,
      background: preferences.background,
      readerMode: currentMode,
      pagedCanvasColor: _capability.pagedCanvasColor,
      eInkMode: EInkModeScope.of(context),
    );
    final panelPalette = ReaderPanelPalette.fromCanvas(
      canvasBackground: canvasBackground,
      baseTheme: baseTheme,
    );
    final selected = await showAdaptivePanel<ReaderModePreference>(
      context: context,
      backgroundColor: panelPalette.panelSurface,
      builder: (context) => ReaderModeSheet(
        currentMode: currentMode,
        canvasBackground: canvasBackground,
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    await _onReaderModeChanged(selected);
  }

  Future<void> _onReaderModeChanged(ReaderModePreference nextMode) async {
    final currentMode =
        ref.read(readerPreferencesControllerProvider).value?.readerMode ??
        ReaderPreferences.defaults().readerMode;
    if (currentMode == nextMode) {
      return;
    }
    // 模式切换同时改变缩略图视觉顺序和翻页固定底色，旧候选立即作废。
    _thumbnailPreviewIndex = null;
    if (currentMode == ReaderModePreference.vertical) {
      _verticalPositionDriver.cancelActive(
        ReaderVerticalSeekCancelReason.modeChanged,
      );
    }
    final positionState = _positionState;
    if (positionState == null) {
      return;
    }
    final targetIndex = positionState.committedLogicalIndex;
    final itemCount = _capability.content.length;
    final session = _readerSession.current;
    final request = _seekCoordinator.beginModeChange(
      targetIndex: targetIndex,
      isSurfaceCurrent: () =>
          _isCurrentImageSession(session) &&
          _isCurrentPositionState(positionState, itemCount),
    );
    if (request == null) return;
    _restoreCoordinator.invalidate();
    try {
      await ref
          .read(readerPreferencesControllerProvider.notifier)
          .setReaderMode(nextMode);
      if (!mounted || !_seekCoordinator.isCurrent(request)) {
        return;
      }
      positionState.consumeInitialRestore();
      final pendingPagedSeek = positionState.pendingPagedSeek;
      if (pendingPagedSeek != null) {
        positionState.clearPendingPagedSeek(pendingPagedSeek);
      }
      _commitLogicalIndex(targetIndex);
      _setZoomGate(false, paged: false);
      _activePagedIndex.value = targetIndex;
      if (nextMode == ReaderModePreference.vertical) {
        _pageController?.dispose();
        _pageController = null;
        _pageControllerOwnerId = null;
      }
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          !_seekCoordinator.isCurrent(request) ||
          _diagnosticMode != nextMode) {
        return;
      }

      final generation = request.generation;
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekStarted,
        index: targetIndex,
        mode: nextMode,
        generation: generation,
        targetIndex: targetIndex,
        status: 'modeSwitch',
        result: 'pending',
      );
      if (nextMode == ReaderModePreference.vertical) {
        final verticalResult = await _jumpVerticalToIndex(targetIndex);
        if (!_seekCoordinator.isCurrent(request) ||
            _diagnosticMode != nextMode) {
          return;
        }
        _performanceMetrics.recordSeek(
          elapsed: verticalResult.elapsed,
          correctionDelta: verticalResult.correctionDelta,
        );
        if (verticalResult.status == ReaderVerticalSeekStatus.cancelled) {
          _recordSeekSuperseded(
            seekGeneration: generation,
            targetIndex: targetIndex,
            mode: nextMode,
            reason: verticalResult.cancelReason?.name ?? 'cancelled',
            elapsedMs: verticalResult.elapsed.inMilliseconds,
            correctionDelta: verticalResult.correctionDelta,
          );
          _scheduleVerticalProgressSync();
          return;
        }
        if (!verticalResult.reached) {
          _recordReaderDiagnostic(
            type: ContinuousImageDiagnosticEventType.seekFailed,
            index: _lastKnownIndex,
            mode: nextMode,
            generation: generation,
            targetIndex: targetIndex,
            status: 'modeSwitch',
            result: 'verticalSeekUnavailable',
            elapsedMs: verticalResult.elapsed.inMilliseconds,
            correctionDelta: verticalResult.correctionDelta,
          );
          return;
        }
        if (!_seekCoordinator.isCurrent(request)) {
          return;
        }
        _commitLogicalIndex(targetIndex);
        _recordReaderDiagnostic(
          type: ContinuousImageDiagnosticEventType.seekReached,
          index: targetIndex,
          mode: nextMode,
          generation: generation,
          targetIndex: targetIndex,
          status: 'modeSwitch',
          result: 'reached',
          elapsedMs: verticalResult.elapsed.inMilliseconds,
          correctionDelta: verticalResult.correctionDelta,
        );
        return;
      }
      _queueOrApplyPagedSeek(
        content: _capability.content,
        positionState: positionState,
        targetIndex: targetIndex,
        generation: generation,
        recordReached: true,
      );
    } catch (error) {
      if (!_seekCoordinator.isCurrent(request)) return;
      _recordReaderDiagnostic(
        type: ContinuousImageDiagnosticEventType.seekFailed,
        index: _lastKnownIndex,
        mode: nextMode,
        generation: request.generation,
        targetIndex: targetIndex,
        status: 'modeSwitch',
        result: error.runtimeType.toString(),
      );
    } finally {
      _seekCoordinator.finish(request);
    }
  }

  ContinuousImageReaderMode _readerMode(ReaderPreferences preferences) {
    return preferences.readerMode == ReaderModePreference.vertical
        ? ContinuousImageReaderMode.vertical
        : ContinuousImageReaderMode.horizontal;
  }

  ReaderTopBarConfig _buildTopBar(ReaderEngineContext context) {
    final title = _capability.titleFor(context);
    return ReaderTopBarConfig(
      title: title.title,
      subtitle: title.subtitle,
      onBack: () => unawaited(_popReader(_capability.exitResult)),
      onTitleTap: () => unawaited(_popReader(_capability.exitResult)),
      actions: _withMenuDismiss(_capability.topActions(context)),
    );
  }

  double _statusBarBottomClearance(ReaderPreferences preferences) {
    if (!preferences.showPageIndicator) {
      return 0;
    }
    final variant = EInkModeScope.of(context)
        ? ReaderReadingStatusBarVariant.eInk
        : ReaderReadingStatusBarVariant.standard;
    return ReaderReadingStatusBarLayout.heightForVariant(context, variant);
  }

  Widget? _buildPersistentFooter(
    ReaderEngineContext engineContext,
    ReaderPreferences preferences,
    Color background,
  ) {
    if (!preferences.showPageIndicator || _tailActionController.visible) {
      return null;
    }
    final variant = EInkModeScope.of(context)
        ? ReaderReadingStatusBarVariant.eInk
        : ReaderReadingStatusBarVariant.standard;
    final isDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final foreground = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.black.withValues(alpha: 0.58);
    final progressForeground = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.80);
    final titleSpec = _capability.titleFor(engineContext);
    final leading = titleSpec.title.trim();
    final title = titleSpec.subtitle.trim();
    final trailing =
        _sequencePositionLabel() ??
        '${(_effectivePreviewIndex ?? _lastKnownIndex) + 1} / ${engineContext.totalCount}';
    final semanticsLabel = [
      if (leading.isNotEmpty) leading,
      if (title.isNotEmpty) title,
      trailing,
    ].join('，');
    return ReaderReadingStatusBar(
      status: ReaderReadingStatus(
        leading: leading,
        title: title,
        trailing: trailing,
        semanticsLabel: semanticsLabel,
      ),
      background: background,
      foreground: foreground,
      progressForeground: progressForeground,
      variant: variant,
    );
  }

  ReaderBottomBarConfig _buildBottomBar(
    ReaderEngineContext context,
    ReaderPreferences preferences,
  ) {
    final total = context.totalCount;
    final currentIndex = _effectivePreviewIndex ?? _lastKnownIndex;
    final nav = _capability.chapterNav(context);
    return ReaderBottomBarConfig(
      thumbnailStrip: _buildThumbnailStrip(preferences: preferences),
      progress: ReaderProgressConfig.discrete(
        current: currentIndex + 1,
        total: total,
        previousTooltip: nav?.previousTooltip,
        nextTooltip: nav?.nextTooltip,
        nextIcon: nav?.nextIcon ?? Icons.skip_next,
        previousEnabled: nav?.hasPrevious ?? false,
        nextEnabled: nav?.hasNext ?? false,
        interactionLocked: _isSliderCommitInFlight,
        onPrevious: nav?.onPrevious,
        onNext: nav?.onNext,
        onChangeStart: (value) => _onProgressChangeStart(value, total),
        onChanged: (value) => _onProgressChanged(value, total),
        onChangeEnd: (value) => _onProgressChangeEnd(
          sliderValue: value,
          preferences: preferences,
          total: total,
        ),
      ),
      actions: _withMenuDismiss(_capability.bottomActions(context)),
    );
  }

  Widget? _buildThumbnailStrip({required ReaderPreferences preferences}) {
    final content = _capability.content;
    if (!_capability.showsThumbnailStrip || content.length <= 1) {
      return null;
    }
    final active =
        _overlayController.isMenuVisible ||
        !_overlayController.isOverlayDismissed;
    return _capability.buildThumbnailStrip(
      context,
      ReaderThumbnailStripSpec(
        ownerId: content.ownerId,
        items: content.items,
        currentIndex: _lastKnownIndex.clamp(0, content.length - 1).toInt(),
        previewIndex: _thumbnailPreviewIndex,
        reversed: preferences.readerMode == ReaderModePreference.rtl,
        enabled: !_isSliderCommitInFlight,
        active: active,
        sessionBindingFor: _thumbnailSessionBindingFor,
        onPreview: _onThumbnailPreview,
        onSubmit: _onThumbnailSubmit,
        onCancel: _onThumbnailCancel,
      ),
    );
  }

  ReaderImageSessionBinding _thumbnailSessionBindingFor(
    ContinuousImageItem item,
  ) {
    final content = _capability.content;
    if (_imageSessionStore.readerOwnerId != content.ownerId ||
        _imageSessionStore.generation !=
            _sessionPreloadCoordinator.generation) {
      _imageSessionStore.startSession(
        readerOwnerId: content.ownerId,
        generation: _sessionPreloadCoordinator.generation,
        items: content.items,
      );
    }
    return _imageSessionStore.bindingFor(
      item,
      initialLocalPath: _capability.initialLocalPathFor(item),
    );
  }

  /// 缩略图候选只更新页码和预览，不提交阅读位置或已读证据。
  void _onThumbnailPreview(int index) {
    if (!mounted) {
      return;
    }
    final content = _capability.content;
    if (content.isEmpty) {
      return;
    }
    final target = index.clamp(0, content.length - 1).toInt();
    if (_thumbnailPreviewIndex == target) {
      return;
    }
    setState(() => _thumbnailPreviewIndex = target);
    _recordReaderDiagnostic(
      type: ContinuousImageDiagnosticEventType.seekPreviewChanged,
      index: _lastKnownIndex,
      generation: _seekGeneration,
      targetIndex: target,
      status: 'thumbnail',
      result: 'preview',
    );
  }

  void _onThumbnailCancel() {
    if (!mounted || _thumbnailPreviewIndex == null) {
      return;
    }
    setState(() => _thumbnailPreviewIndex = null);
  }

  void _onThumbnailSubmit(int index) {
    if (!mounted || _isSliderCommitInFlight) {
      return;
    }
    final content = _capability.content;
    if (content.isEmpty) {
      return;
    }
    final target = index.clamp(0, content.length - 1).toInt();
    if (_thumbnailPreviewIndex != null) {
      setState(() => _thumbnailPreviewIndex = null);
    }
    if (target == _lastKnownIndex) {
      return;
    }
    final preferences =
        ref.read(readerPreferencesControllerProvider).value ??
        ReaderPreferences.defaults();
    unawaited(
      _commitSeekToIndex(
        targetIndex: target,
        preferences: preferences,
        total: content.length,
        // 缩略图点按是明确的单次提交，不能被滑块节流吞掉。
        respectThrottle: false,
      ),
    );
  }

  /// 按动作策略收起 overlay 菜单。
  ///
  /// 默认动作会关闭菜单；模式轮询等需要连续操作的动作可以显式保留菜单。
  List<ReaderToolbarAction> _withMenuDismiss(
    List<ReaderToolbarAction> actions,
  ) {
    void run(VoidCallback action, {required bool dismissMenu}) {
      if (dismissMenu) {
        _overlayController.hideMenu();
      }
      action();
    }

    return actions
        .map(
          (action) => switch (action) {
            // 锚定菜单动作只转发菜单元数据；开合期间覆盖层保持可见，选中后
            // 才按 dismissMenu 收起，来源按钮快照才有稳定的接续位置。
            ReaderToolbarMenuAction(:final entries) => ReaderToolbarMenuAction(
              id: action.id,
              icon: action.icon,
              label: action.label,
              enabled: action.enabled,
              dismissMenu: action.dismissMenu,
              entries: [
                for (final entry in entries)
                  ReaderToolbarMenuEntry(
                    id: entry.id,
                    label: entry.label,
                    icon: entry.icon,
                    enabled: entry.enabled,
                    checked: entry.checked,
                    danger: entry.danger,
                    onSelected: () =>
                        run(entry.onSelected, dismissMenu: action.dismissMenu),
                  ),
              ],
            ),
            _ => ReaderToolbarAction(
              id: action.id,
              icon: action.icon,
              label: action.label,
              enabled: action.enabled,
              dismissMenu: action.dismissMenu,
              onPressed: () =>
                  run(action.onPressed, dismissMenu: action.dismissMenu),
            ),
          },
        )
        .toList(growable: false);
  }

  Future<void> _popReader([Object? result]) async {
    final route = ModalRoute.of(context);
    _exitFlushed = true;
    _exitFlushFuture ??= Future<void>.sync(_capability.onExit);
    // Every back action waits for the same preparation. A repeated toolbar tap
    // must neither reveal an unprepared body nor pop its route afterwards.
    await _exitFlushFuture;
    if (!mounted ||
        ModalRoute.of(context) != route ||
        !(route?.isCurrent ?? false)) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  Widget _buildContentLayer({
    required BuildContext context,
    required ReaderContent content,
    required ContinuousImageReaderMode mode,
    required ReaderPreferences preferences,
    required ReaderEngineContext engineContext,
  }) {
    final background = _backgroundColor(preferences);
    final chromePalette = const ReaderChromePaletteResolver().resolve(
      Theme.of(context),
    );
    final hint = _capability.topHint(engineContext);
    return Column(
      children: [
        if (hint != null)
          Container(
            width: double.infinity,
            color: chromePalette.chromeBackground,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: chromePalette.onChromeVariant),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: background,
            child: mode == ContinuousImageReaderMode.vertical
                ? _buildVertical(content, preferences, engineContext)
                : _buildPaged(content, preferences),
          ),
        ),
      ],
    );
  }

  void _onOverlayVisibilityChanged() {
    if (!mounted) {
      return;
    }
    if (!_overlayController.isMenuVisible && _thumbnailPreviewIndex != null) {
      // 工具栏收起即卸载缩略图条，未提交候选同时作废。
      _thumbnailPreviewIndex = null;
    }
    setState(() {});
  }

  void _onVerticalReaderZoomStateChanged(bool isZoomed) {
    if (_zoomGate.value == isZoomed) {
      return;
    }
    _setZoomGate(isZoomed, paged: false);
    _recordReaderDiagnostic(
      type: isZoomed
          ? ContinuousImageDiagnosticEventType.zoomActivated
          : ContinuousImageDiagnosticEventType.zoomDeactivated,
      index: _lastKnownIndex,
      mode: ReaderModePreference.vertical,
      status: isZoomed ? 'active' : 'inactive',
      result: isZoomed ? 'zoomed' : 'resting',
    );
  }

  void _onPagedImageZoomStateChanged(int imageIndex, bool isZoomed) {
    if (_activePagedIndex.value != imageIndex || _zoomGate.value == isZoomed) {
      return;
    }
    _setZoomGate(isZoomed, paged: true);
    _recordReaderDiagnostic(
      type: isZoomed
          ? ContinuousImageDiagnosticEventType.zoomActivated
          : ContinuousImageDiagnosticEventType.zoomDeactivated,
      index: imageIndex,
      status: isZoomed ? 'active' : 'inactive',
      result: isZoomed ? 'zoomed' : 'resting',
    );
  }

  void _setZoomGate(bool isZoomed, {required bool paged}) {
    if (paged && isZoomed) {
      _holdPagedScrollForZoom();
    } else {
      _releasePagedZoomScrollHold();
    }
    _zoomGate.value = isZoomed;
  }

  void _holdPagedScrollForZoom() {
    final controller = _pageController;
    if (_pagedZoomScrollHold != null ||
        controller == null ||
        !controller.hasClients) {
      return;
    }
    _pagedZoomScrollHold = controller.position.hold(() {
      _pagedZoomScrollHold = null;
    });
  }

  void _releasePagedZoomScrollHold() {
    final hold = _pagedZoomScrollHold;
    _pagedZoomScrollHold = null;
    hold?.cancel();
  }

  void _hideReaderMenuForContentMotion() {
    if (!_overlayController.isMenuVisible || _isSliderCommitInFlight) {
      return;
    }
    _overlayController.hideMenu();
  }

  void _recordReaderDiagnostic({
    required ContinuousImageDiagnosticEventType type,
    String? ownerId,
    String? itemId,
    int? index,
    String? source,
    ReaderModePreference? mode,
    int? generation,
    int? targetIndex,
    String? status,
    String? result,
    String? preloadKind,
    bool? applied,
    int? elapsedMs,
    double? correctionDelta,
    String message = '',
  }) {
    final recorder = _capability.diagnosticRecorder;
    if (!recorder.enabled) {
      return;
    }
    final content = _capability.content;
    final logicalIndex = index ?? _lastKnownIndex;
    final resolvedItemId =
        itemId ??
        (logicalIndex >= 0 && logicalIndex < content.items.length
            ? content.items[logicalIndex].id
            : '-');
    try {
      recorder.recordContinuousImage(
        ContinuousImageDiagnosticEvent(
          time: DateTime.now(),
          type: type,
          itemId: resolvedItemId,
          ownerId: ownerId ?? content.ownerId,
          index: logicalIndex,
          source: source,
          readerKind: _capability.readerKind.name,
          mode: (mode ?? _diagnosticMode).name,
          generation: generation,
          targetIndex: targetIndex,
          status: status,
          result: result,
          preloadKind: preloadKind,
          applied: applied,
          elapsedMs: elapsedMs,
          correctionDelta: correctionDelta,
          message: message,
        ),
      );
    } catch (_) {
      // Diagnostics must never alter reader interaction or cache behavior.
    }
  }
}

class _ReaderVerticalTrailingSpec {
  const _ReaderVerticalTrailingSpec({this.itemCount = 0, this.indexedBuilder})
    : builder = null;

  const _ReaderVerticalTrailingSpec.single(this.builder)
    : itemCount = builder == null ? 0 : 1,
      indexedBuilder = null;

  final WidgetBuilder? builder;
  final int itemCount;
  final IndexedWidgetBuilder? indexedBuilder;
}
