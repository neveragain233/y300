import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/app/theme/app_theme_palette.dart';
import 'package:y300/app/y300_app.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/presentation/models/novel_reader_pagination_key.dart';
import 'package:y300/features/novel/presentation/services/novel_forum_html_render_theme_factory.dart';
import 'package:y300/features/novel/presentation/services/novel_html_reader_preferences_adapter.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_html_preparation_service.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_hybrid_pagination_planner.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_measure_adapter.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_pagination_renderer_validator.dart';
import 'package:y300/features/reader_shared/presentation/widgets/reader_reading_footer.dart';
import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/presentation/services/thread_floor_navigation_coordinator.dart';
import 'package:y300/features/thread/presentation/widgets/thread_floating_controls.dart';
import 'package:y300/shared/widgets/eink_paging.dart';

import '../features/novel/test_support/novel_pagination_html_fixtures.dart';
import '../test_support/localized_test_app.dart';

void main() {
  tearDown(() {
    EInkEpdcChannel.enabled = false;
    EInkEpdcChannel.isEinkMode = false;
    EInkEpdcChannel.setTestOverride(null);
  });

  test('eink palettes expose high-contrast monochrome tokens', () {
    final light = AppThemePalette.einkLight();
    expect(light.scaffoldBackground, const Color(0xFFFFFFFF));
    expect(light.onSurface, const Color(0xFF111111));
    expect(light.surfaceContainer, const Color(0xFFF4F4F4));
    expect(light.outlineVariant, const Color(0xFFCCCCCC));

    final dark = AppThemePalette.einkDark();
    expect(dark.scaffoldBackground, const Color(0xFF000000));
    expect(dark.onSurface, const Color(0xFFFFFFFF));
    expect(dark.outlineVariant, const Color(0xFF444444));

    final theme = AppTheme.build(
      family: AppThemeFamily.eink,
      brightness: Brightness.light,
    );
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.colorScheme.shadow, Colors.transparent);
    expect(theme.colorScheme.scrim, Colors.transparent);
  });

  testWidgets('Y300App disables animations and arms EPDC only in eink family', (
    tester,
  ) async {
    Future<void> pumpWithFamily(AppThemeFamily family) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey<AppThemeFamily>(family),
          overrides: [
            appAppearanceControllerProvider.overrideWith(
              () => _FixedAppearanceController(
                AppAppearanceSettings.defaults().copyWith(
                  themeFamily: family,
                ),
              ),
            ),
          ],
          child: const Y300App(
            enableAppUpdatePrompt: false,
            home: _ProbeHome(),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpWithFamily(AppThemeFamily.eink);
    expect(EInkEpdcChannel.isEinkMode, isTrue);
    expect(EInkEpdcChannel.enabled, isTrue);
    final einkApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(einkApp.themeAnimationDuration, Duration.zero);
    expect(einkApp.scrollBehavior, isA<EInkScrollBehavior>());
    expect(einkApp.theme?.splashFactory, NoSplash.splashFactory);
    final einkContext = tester.element(find.byType(_ProbeHome));
    expect(MediaQuery.disableAnimationsOf(einkContext), isTrue);
    expect(EInkModeScope.of(einkContext), isTrue);

    await pumpWithFamily(AppThemeFamily.warmPaper);
    expect(EInkEpdcChannel.isEinkMode, isFalse);
    expect(EInkEpdcChannel.enabled, isFalse);
    final warmApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(warmApp.themeAnimationDuration, kThemeAnimationDuration);
    expect(warmApp.scrollBehavior, isNull);
    final warmContext = tester.element(find.byType(_ProbeHome));
    expect(MediaQuery.disableAnimationsOf(warmContext), isFalse);
    expect(EInkModeScope.of(warmContext), isFalse);
  });

  test('EInkEpdcChannel forwards ripple calls only when enabled', () async {
    final calls = <bool>[];
    EInkEpdcChannel.setTestOverride((forward, _) async {
      calls.add(forward);
    });

    EInkEpdcChannel.enabled = false;
    await EInkEpdcChannel.triggerPageRipple(forward: true);
    expect(calls, isEmpty);

    EInkEpdcChannel.enabled = true;
    await EInkEpdcChannel.triggerPageRipple(forward: true);
    await EInkEpdcChannel.triggerPageRipple(forward: false);
    expect(calls, <bool>[true, false]);
  });

  test('useNavigationRail lowers landscape threshold to 600dp in eink mode', () {
    const landscape43 = Size(672, 505);
    const portrait43 = Size(505, 672);

    EInkEpdcChannel.isEinkMode = false;
    expect(AppWindowLayout(size: landscape43).useNavigationRail, isFalse);
    expect(AppWindowLayout(size: portrait43).useNavigationRail, isFalse);

    EInkEpdcChannel.isEinkMode = true;
    expect(AppWindowLayout(size: landscape43).useNavigationRail, isTrue);
    expect(AppWindowLayout(size: portrait43).useNavigationRail, isFalse);
  });

  testWidgets('EInkCornerPagingButtons renders only when EInkModeScope is on', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    Future<void> pumpPager(bool enabled) async {
      await tester.pumpWidget(
        LocalizedTestApp(
          home: EInkModeScope(
            enabled: enabled,
            child: Scaffold(
              body: Stack(
                children: [
                  ListView.builder(
                    controller: controller,
                    itemCount: 40,
                    itemBuilder: (_, index) =>
                        SizedBox(height: 60, child: Text('Item $index')),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: EInkCornerPagingButtons(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await pumpPager(true);
    expect(find.byKey(const Key('eink-corner-page-up')), findsOneWidget);
    expect(find.byKey(const Key('eink-corner-page-down')), findsOneWidget);

    await tester.tap(find.byKey(const Key('eink-corner-page-down')));
    await tester.pump();
    expect(controller.offset, greaterThan(0));

    await pumpPager(false);
    expect(find.byKey(const Key('eink-corner-page-up')), findsNothing);
    expect(find.byKey(const Key('eink-corner-page-down')), findsNothing);
  });

  testWidgets('ReaderReadingFooter shows title, progress, and HH:mm clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: ReaderReadingFooter(
            title: 'episode 355 仙台同学选择的东西',
            progressText: '7/9',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('episode 355 仙台同学选择的东西'), findsOneWidget);
    expect(find.text('7/9'), findsOneWidget);
    expect(find.textContaining(':'), findsOneWidget);
  });

  testWidgets(
    'ThreadFloatingControls hides native floor nav buttons only when E-Ink mode is on',
    (tester) async {
      final visibility = ValueNotifier<bool>(true);
      addTearDown(visibility.dispose);
      final viewport = _TestFloorViewport();
      final nav = ThreadFloorNavigationCoordinator(
        readPage: () => const ThreadFloorPage(
          owner: 'test',
          page: 1,
          pids: <String>['p1', 'p2', 'p3'],
          hasPrevious: false,
          hasNext: true,
          loading: false,
        ),
        loadAdjacent: (_, _) async => false,
      )..bind(viewport);
      addTearDown(nav.dispose);

      Future<void> pumpControls({
        required bool einkEnabled,
        required bool singleButton,
      }) async {
        await tester.pumpWidget(
          LocalizedTestApp(
            home: EInkModeScope(
              enabled: einkEnabled,
              child: Scaffold(
                floatingActionButton: ThreadFloatingControls(
                  preferences: ThreadControlsPreferences(
                    singleNavigationButton: singleButton,
                  ),
                  navigation: nav,
                  visibility: visibility,
                  favorite: const SizedBox.shrink(),
                  reply: () {},
                  jumpPage: const SizedBox.shrink(),
                  more: const SizedBox.shrink(),
                  onFirstPost: () {},
                  onHeightChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpControls(einkEnabled: false, singleButton: true);
      expect(
        find.byKey(const Key('thread-single-navigation-button')),
        findsOneWidget,
      );

      await pumpControls(einkEnabled: true, singleButton: true);
      expect(
        find.byKey(const Key('thread-single-navigation-button')),
        findsNothing,
      );

      await pumpControls(einkEnabled: false, singleButton: false);
      expect(find.byKey(const Key('thread-next-post-button')), findsOneWidget);
      expect(
        find.byKey(const Key('thread-previous-post-button')),
        findsOneWidget,
      );

      await pumpControls(einkEnabled: true, singleButton: false);
      expect(find.byKey(const Key('thread-next-post-button')), findsNothing);
      expect(
        find.byKey(const Key('thread-previous-post-button')),
        findsNothing,
      );
    },
  );

  group('7-inch 4:3 E-Ink HTML display ratio tests', () {
    final fragmentFiles = <({String id, String path})>[
      (
        id: 'centered_divider_overflow_v1',
        path: 'test/features/novel/fixtures/pagination/centered_divider_overflow_v1.html',
      ),
      (
        id: 'act23_ruby_collapse_v1',
        path: 'test/features/novel/fixtures/pagination/act23_ruby_collapse_v1.html',
      ),
      (
        id: 'nested_title_attachment_v1',
        path: 'test/features/novel/fixtures/pagination/nested_title_attachment_v1.html',
      ),
      (
        id: 'phase6_ruby_protected_inline_v1',
        path: 'test/features/novel/fixtures/pagination/phase6_ruby_protected_inline_v1.html',
      ),
    ];

    final viewports = <({String name, Size screenSize, double width, double height})>[
      (
        name: '4:3 portrait 505x672',
        screenSize: const Size(505, 672),
        width: 473.0,
        height: 616.0,
      ),
      (
        name: '4:3 landscape 672x505',
        screenSize: const Size(672, 505),
        width: 640.0,
        height: 449.0,
      ),
    ];

    final fixtureLoader = NovelPaginationHtmlFixtureLoader();
    final samples = <({String id, String title, Future<String> Function() loadHtml})>[
      for (final file in fragmentFiles)
        (
          id: file.id,
          title: file.id,
          loadHtml: () async => File(file.path).readAsStringSync(),
        ),
      for (final sample in novelPaginationHtmlFixtures)
        (
          id: sample.id,
          title: sample.title,
          loadHtml: () async => fixtureLoader.loadFirstPostMessage(sample),
        ),
    ];

    for (final vp in viewports) {
      for (final sample in samples) {
        testWidgets(
          '${sample.id} paginates and renders without overflow at ${vp.name}',
          (tester) async {
            EInkEpdcChannel.isEinkMode = true;
            tester.view.physicalSize = vp.screenSize;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final novelPreferences = NovelReaderPreferences.defaults();
            final appTheme = AppTheme.build(
              family: AppThemeFamily.eink,
              brightness: Brightness.light,
            );
            final palette = const NovelReaderThemeResolver().resolve(
              preferences: novelPreferences,
              theme: appTheme,
            );
            final htmlTheme = const NovelForumHtmlRenderThemeFactory()
                .fromPalette(palette);
            final htmlPreferences = const NovelHtmlReaderPreferencesAdapter()
                .map(novelPreferences);

            late BuildContext hostContext;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  imageCacheServiceProvider.overrideWithValue(
                    _NoopImageCacheService(),
                  ),
                ],
                child: LocalizedTestApp(
                  theme: appTheme,
                  home: Builder(
                    builder: (context) {
                      hostContext = context;
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            );

            final rawHtml = await sample.loadHtml();
            final episode = NovelEpisodeItem(
              episodeId: 'eink-43-${sample.id}',
              novelId: 'eink-43-novel',
              sourceTid: '7300',
              episodeTitle: sample.title,
              orderIndex: 0,
            );
            final chapter = (await tester.runAsync(
              () => const DefaultNovelReaderHtmlPreparationService().prepare(
                rawHtml: rawHtml,
                episode: episode,
                preferences: htmlPreferences,
                theme: htmlTheme,
                sourceId: episode.episodeId,
                threadId: episode.sourceTid,
                imageCacheOwnerId: episode.sourceTid,
              ),
            ))!;

            const blockSpacingMode = ForumHtmlBlockSpacingMode.discuzLineDivs;
            final baseStyle = ForumHtmlStylePolicy(
              htmlPreferences,
              theme: htmlTheme,
              blockSpacingMode: blockSpacingMode,
            ).baseTextStyle(hostContext);

            final key = NovelReaderPaginationKey(
              episodeId: chapter.episodeId,
              contentHash: chapter.contentHash,
              viewportWidthPx: NovelReaderPaginationKey.logicalPixels(vp.width),
              viewportHeightPx:
                  NovelReaderPaginationKey.logicalPixels(vp.height),
              typographySignature: 'eink-43-${vp.name}',
              themeSignature: chapter.themeSignature,
              imageDimensionRevision: chapter.imageDimensionRevision,
              rendererRevision: 12,
            );

            final plan = (await tester.runAsync(
              () => DefaultNovelReaderHybridPaginationPlanner(
                measureAdapter: const _FourByThreeMeasureAdapter(),
                preferences: htmlPreferences,
                theme: htmlTheme,
                baseStyle: baseStyle,
                validationPolicy: const NovelReaderPaginationValidationPolicy(
                  interval: 10000,
                ),
              ).paginate(chapter, key),
            ))!;

            expect(plan.pages, isNotEmpty);
            expect(
              plan.pages.every((page) => page.html.trim().isNotEmpty),
              isTrue,
            );
            expect(
              plan.pages.every(
                (page) =>
                    page.requiresInnerScroll ||
                    page.usedHeight <= key.viewportHeightPx,
              ),
              isTrue,
              reason: '${sample.id} at ${vp.name} exceeded viewport height',
            );

            final pagesToRender = <int>{0, plan.pages.length - 1};
            for (final index in pagesToRender) {
              final page = plan.pages[index];
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    imageCacheServiceProvider.overrideWithValue(
                      _NoopImageCacheService(),
                    ),
                  ],
                  child: LocalizedTestApp(
                    theme: appTheme,
                    home: Scaffold(
                      body: Center(
                        child: SizedBox(
                          width: vp.width,
                          height: vp.height,
                          child: ForumHtmlWidgetPostRenderer(
                            key: ValueKey<String>(
                              '${sample.id}-${vp.name}-$index',
                            ),
                            html: page.html,
                            theme: htmlTheme,
                            preparedDocument: chapter.renderDocument.copyWith(
                              preparedHtml: page.html,
                            ),
                            preferences: htmlPreferences,
                            sourceId: '${episode.episodeId}:$index',
                            threadId: episode.sourceTid,
                            imageCacheOwnerId: episode.sourceTid,
                            buildAsync: false,
                            enableCaching: false,
                            blockSpacingMode: blockSpacingMode,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '${sample.id} page $index threw overflow/exception at ${vp.name}',
              );
            }
          },
        );
      }
    }
  });
}

class _FixedAppearanceController extends AppAppearanceController {
  _FixedAppearanceController(this._settings);

  final AppAppearanceSettings _settings;

  @override
  Future<AppAppearanceSettings> build() async => _settings;
}

class _ProbeHome extends StatelessWidget {
  const _ProbeHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

final class _FourByThreeMeasureAdapter
    implements NovelReaderPaginationMeasureAdapter {
  const _FourByThreeMeasureAdapter();

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) async {
    if (request.html.contains('showcollapse_box')) {
      return const NovelReaderPaginationMeasureResult(height: 80.0);
    }
    if (request.html.contains('<img')) {
      return const NovelReaderPaginationMeasureResult(height: 240.0);
    }
    final text = request.html.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    final viewportWidth = request.key.viewportWidthPx.toDouble();
    final charsPerLine = (viewportWidth / 19.0).floor().clamp(8, 80);
    final lines = (text.runes.length / charsPerLine).ceil().clamp(1, 60);
    final lineHeight = request.html.contains('<ruby') ? 60.0 : 32.0;
    return NovelReaderPaginationMeasureResult(height: lines * lineHeight + 20.0);
  }
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

class _TestFloorViewport implements ThreadFloorViewport {
  @override
  bool atBottom = false;

  @override
  void refreshEndGeometry() {}

  @override
  double? get scrollPixels => 0;

  @override
  List<ThreadFloorImageStop> imageStops(String pid) => const [];

  @override
  bool isPostHeaderAbove(String pid) => false;

  @override
  Future<bool> revealImageStop(
    ThreadFloorImageStop stop, {
    required bool animate,
    required bool Function() isCurrent,
  }) async => isCurrent();

  @override
  Future<bool> revealPageEnd({
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return false;
    atBottom = true;
    return true;
  }

  @override
  String? visiblePostId = 'p2';

  @override
  Future<bool> revealPost(
    String pid, {
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    visiblePostId = pid;
    return true;
  }
}
