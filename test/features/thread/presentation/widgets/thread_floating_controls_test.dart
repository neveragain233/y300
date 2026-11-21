import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/presentation/services/thread_floor_navigation_coordinator.dart';
import 'package:y300/features/thread/presentation/widgets/thread_floating_controls.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('external page loading disables single-button navigation', (
    tester,
  ) async {
    final visibility = ValueNotifier(true);
    addTearDown(visibility.dispose);
    var loading = true;
    final viewport = _Viewport()
      ..visiblePostId = 'p3'
      ..atBottom = true;
    final nav = ThreadFloorNavigationCoordinator(
      readPage: () => ThreadFloorPage(
        owner: 'test',
        page: 1,
        pids: const ['p1', 'p2', 'p3'],
        hasPrevious: false,
        hasNext: false,
        loading: loading,
      ),
      loadAdjacent: (_, _) async => false,
    )..bind(viewport);
    addTearDown(nav.dispose);
    var firstPosts = 0;
    await tester.pumpWidget(
      _app(
        nav,
        visibility,
        const ThreadControlsPreferences(singleNavigationButton: true),
        onFirst: () => firstPosts++,
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('thread-single-navigation-button'));
    expect(nav.atEnd, isFalse);
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    expect(tester.widget<TextButton>(button).onLongPress, isNull);
    loading = false;
    nav.refresh();
    await tester.pumpAndSettle();
    expect(nav.atEnd, isTrue);
    await tester.tap(button);
    expect(firstPosts, 1);
  });
  testWidgets('zero-width warm-up frame can grow into the normal controls', (
    tester,
  ) async {
    final visibility = ValueNotifier(true);
    addTearDown(visibility.dispose);
    final nav = _navigation(_Viewport());
    addTearDown(nav.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(Size.zero);
    await tester.pumpWidget(
      _app(nav, visibility, const ThreadControlsPreferences()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(320, 800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('thread-next-post-button')), findsOneWidget);
  });
  testWidgets(
    'full and compact controls fit phone, narrow and tablet widths at large font sizes',
    (tester) async {
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final viewport = _Viewport();
      final nav = _navigation(viewport);
      addTearDown(nav.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [280.0, 320.0, 411.0, 1000.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final compact in [false, true]) {
            await tester.pumpWidget(
              _app(
                nav,
                visibility,
                ThreadControlsPreferences(compact: compact),
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'width=$width scale=$scale compact=$compact',
            );
            for (final key in [
              'thread-next-post-button',
              'thread-previous-post-button',
              'thread-detail-appbar-reply-button',
              'test-favorite-button',
              'test-jump-button',
              'test-more-button',
            ]) {
              final size = tester.getSize(find.byKey(Key(key)));
              expect(size, const Size(48, 48));
            }
            final actions = [
              'test-favorite-button',
              'thread-detail-appbar-reply-button',
              'test-jump-button',
              'test-more-button',
            ];
            for (var i = 1; i < actions.length; i++) {
              final previous = tester.getRect(find.byKey(Key(actions[i - 1])));
              final current = tester.getRect(find.byKey(Key(actions[i])));
              expect(current.left - previous.right, closeTo(8, .01));
            }
          }
        }
      }
    },
  );
  testWidgets(
    'double navigation stays at the viewport right edge on tablet widths',
    (tester) async {
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final nav = _navigation(_Viewport());
      addTearDown(nav.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(1000, 900));
      await tester.pumpWidget(
        _app(nav, visibility, const ThreadControlsPreferences()),
      );
      await tester.pumpAndSettle();

      // 非紧凑主栏以视口为中心（224 宽），导航键贴右缘 16dp 边距。
      expect(
        tester.getTopLeft(find.byKey(const Key('test-favorite-button'))).dx,
        closeTo((1000 - 224) / 2 + 4, .5),
      );
      expect(
        tester.getTopRight(find.byKey(const Key('thread-next-post-button'))).dx,
        closeTo(980, .5),
      );

      // 紧凑栏的停靠侧只决定主栏位置，导航键保持右缘。
      for (final side in [ThreadControlsSide.left, ThreadControlsSide.right]) {
        await tester.pumpWidget(
          _app(
            nav,
            visibility,
            ThreadControlsPreferences(compact: true, side: side),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getTopRight(find.byKey(const Key('thread-next-post-button')))
              .dx,
          closeTo(980, .5),
          reason: 'side=$side',
        );
        final favorite = tester.getRect(
          find.byKey(const Key('test-favorite-button')),
        );
        if (side == ThreadControlsSide.left) {
          expect(favorite.left, closeTo(20, .5));
        } else {
          // 导航键占 112 宽并贴右缘，主栏紧挨其左侧（间距 12）。
          expect(favorite.left, closeTo(984 - 112 - 12 - 224 + 4, .5));
        }
      }
    },
  );

  testWidgets(
    'narrow layout lifts the navigation keys above the main bar on the right',
    (tester) async {
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final nav = _navigation(_Viewport());
      addTearDown(nav.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(
        _app(nav, visibility, const ThreadControlsPreferences(compact: true)),
      );
      await tester.pumpAndSettle();

      final next = tester.getRect(
        find.byKey(const Key('thread-next-post-button')),
      );
      final favorite = tester.getRect(
        find.byKey(const Key('test-favorite-button')),
      );
      expect(next.right, closeTo(300, .5));
      expect(next.bottom, lessThanOrEqualTo(favorite.top - 12 + .5));
      expect(favorite.left, greaterThanOrEqualTo(16));
    },
  );

  testWidgets('system horizontal safe insets keep both groups clear', (
    tester,
  ) async {
    final visibility = ValueNotifier(true);
    addTearDown(visibility.dispose);
    final nav = _navigation(_Viewport());
    addTearDown(nav.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(1000, 900));
    await tester.pumpWidget(
      _app(
        nav,
        visibility,
        const ThreadControlsPreferences(
          compact: true,
          side: ThreadControlsSide.left,
        ),
        horizontalSafeInsets: const EdgeInsets.only(left: 20, right: 30),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopRight(find.byKey(const Key('thread-next-post-button'))).dx,
      closeTo(950, .5),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('test-favorite-button'))).dx,
      closeTo(40, .5),
    );
  });

  testWidgets('scroll hiding is opt-in and preserves the control height', (
    tester,
  ) async {
    final visibility = ValueNotifier(false);
    addTearDown(visibility.dispose);
    final nav = _navigation(_Viewport());
    addTearDown(nav.dispose);
    await tester.pumpWidget(
      _app(nav, visibility, const ThreadControlsPreferences()),
    );
    await tester.pumpAndSettle();
    final gate = find.byKey(const Key('thread-floating-controls-pointer-gate'));
    expect(tester.widget<IgnorePointer>(gate).ignoring, isFalse);
    await tester.pumpWidget(
      _app(
        nav,
        visibility,
        const ThreadControlsPreferences(hideOnScroll: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<IgnorePointer>(gate).ignoring, isTrue);
    final hiddenHeight = tester
        .getSize(find.byType(ThreadFloatingControls))
        .height;
    visibility.value = true;
    await tester.pumpAndSettle();
    expect(tester.widget<IgnorePointer>(gate).ignoring, isFalse);
    expect(
      tester.getSize(find.byType(ThreadFloatingControls)).height,
      hiddenHeight,
    );
  });
  testWidgets(
    'single-button long press changes direction or returns to the first post',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final viewport = _Viewport();
      final nav = _navigation(viewport);
      addTearDown(nav.dispose);
      var firstPosts = 0;
      await tester.pumpWidget(
        _app(
          nav,
          visibility,
          const ThreadControlsPreferences(singleNavigationButton: true),
          onFirst: () => firstPosts++,
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('thread-single-navigation-button'));
      final l10n = AppLocalizations.of(tester.element(button));
      expect(tester.getSemantics(button).label, l10n.threadControlsNextPost);
      await tester.longPress(
        find.byKey(const Key('thread-single-navigation-button')),
      );
      await tester.pumpAndSettle();
      expect(viewport.targets, isEmpty);
      expect(nav.forward, isFalse);
      expect(
        tester.getSemantics(button).label,
        l10n.threadControlsPreviousPost,
      );
      await tester.tap(
        find.byKey(const Key('thread-single-navigation-button')),
      );
      await tester.pumpAndSettle();
      expect(viewport.targets, ['p1']);
      expect(firstPosts, 0);
      await tester.tap(
        find.byKey(const Key('thread-single-navigation-button')),
      );
      await tester.pumpAndSettle();
      expect(nav.forward, isTrue);
      expect(viewport.targets, ['p1']);
      await tester.pumpWidget(
        _app(
          nav,
          visibility,
          const ThreadControlsPreferences(
            singleNavigationButton: true,
            holdToFirstPost: true,
          ),
          onFirst: () => firstPosts++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const Key('thread-single-navigation-button')),
      );
      await tester.pumpAndSettle();
      expect(firstPosts, 1);
      semantics.dispose();
    },
  );
  testWidgets(
    'a single button at the bottom returns to the first post without a hold action',
    (tester) async {
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final viewport = _Viewport()..atBottom = true;
      final nav = _navigation(viewport)..reverseDirection();
      addTearDown(nav.dispose);
      var firstPosts = 0;
      await tester.pumpWidget(
        _app(
          nav,
          visibility,
          const ThreadControlsPreferences(singleNavigationButton: true),
          onFirst: () => firstPosts++,
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('thread-single-navigation-button'));
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.vertical_align_top),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(button).onLongPress, isNull);
      await tester.tap(button);
      expect(firstPosts, 1);
      expect(nav.forward, isTrue);
    },
  );

  testWidgets(
    'floating pills use prism glass surface and ElasticPress with active scope',
    (tester) async {
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final viewport = _Viewport()
        ..visiblePostId = 'p3'
        ..atBottom = true;
      final nav = _navigation(viewport);
      addTearDown(nav.dispose);
      var firstPosts = 0;

      await tester.pumpWidget(
        LiquidGlassScope(
          enabled: true,
          quality: LiquidGlassQuality.standard,
          child: _app(
            nav,
            visibility,
            const ThreadControlsPreferences(singleNavigationButton: true),
            onFirst: () => firstPosts++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppGlassSurface), findsNWidgets(2));
      expect(find.byType(LiquidGlass), findsNWidgets(2));
      expect(find.byType(ElasticPress), findsNWidgets(2));

      final button = find.byKey(const Key('thread-single-navigation-button'));
      await tester.tap(button);
      expect(firstPosts, 1);
    },
  );

  testWidgets(
    'eInk mode disables glass and ElasticPress with 1px outline border and zero motion',
    (tester) async {
      final visibility = ValueNotifier(true);
      addTearDown(visibility.dispose);
      final viewport = _Viewport();
      final nav = _navigation(viewport);
      addTearDown(nav.dispose);

      await tester.pumpWidget(
        EInkModeScope(
          enabled: true,
          child: LiquidGlassScope(
            enabled: true,
            quality: LiquidGlassQuality.standard,
            child: _app(nav, visibility, const ThreadControlsPreferences()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlass), findsNothing);
      expect(find.byType(ElasticPress), findsNothing);

      final surfaces = tester.widgetList<AppGlassSurface>(
        find.byType(AppGlassSurface),
      );
      expect(surfaces, hasLength(1));
      for (final surface in surfaces) {
        expect(surface.level, AppGlassLevel.off);
      }

      expect(find.byKey(const Key('test-favorite-button')), findsOneWidget);
      expect(
        find.byKey(const Key('thread-detail-appbar-reply-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('test-jump-button')), findsOneWidget);
      expect(find.byKey(const Key('test-more-button')), findsOneWidget);
      expect(find.byKey(const Key('thread-next-post-button')), findsNothing);
      expect(
        find.byKey(const Key('thread-previous-post-button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('thread-single-navigation-button')),
        findsNothing,
      );

      final scheme = Theme.of(
        tester.element(find.byType(ThreadFloatingControls)),
      ).colorScheme;
      final borderedMaterials = find.descendant(
        of: find.byType(AppGlassSurface),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Material) {
            return false;
          }
          final shape = widget.shape;
          return widget.elevation == 0 &&
              shape is RoundedRectangleBorder &&
              shape.borderRadius == BorderRadius.circular(28) &&
              shape.side ==
                  BorderSide(
                    color: AppTheme.eInkBorderColor(scheme.brightness),
                    width: 1,
                  );
        }),
      );
      expect(borderedMaterials, findsOneWidget);

      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(slide.duration, Duration.zero);
      expect(opacity.duration, Duration.zero);
    },
  );
}

ThreadFloorNavigationCoordinator _navigation(_Viewport viewport) =>
    ThreadFloorNavigationCoordinator(
      readPage: () => const ThreadFloorPage(
        owner: 'test',
        page: 1,
        pids: ['p1', 'p2', 'p3'],
        hasPrevious: false,
        hasNext: false,
      ),
      loadAdjacent: (_, _) async => false,
    )..bind(viewport);
Widget _app(
  ThreadFloorNavigationCoordinator nav,
  ValueNotifier<bool> visibility,
  ThreadControlsPreferences preferences, {
  double scale = 1,
  VoidCallback? onFirst,
  EdgeInsets horizontalSafeInsets = EdgeInsets.zero,
}) => LocalizedTestApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: ThreadFloatingControls(
          preferences: preferences,
          navigation: nav,
          visibility: visibility,
          favorite: IconButton(
            key: const Key('test-favorite-button'),
            onPressed: () {},
            icon: const Icon(Icons.star_border),
          ),
          reply: () {},
          jumpPage: IconButton(
            key: const Key('test-jump-button'),
            onPressed: () {},
            icon: const Icon(Icons.numbers),
          ),
          more: IconButton(
            key: const Key('test-more-button'),
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
          onFirstPost: onFirst ?? () {},
          onHeightChanged: (_) {},
          horizontalSafeInsets: horizontalSafeInsets,
        ),
      ),
    ),
  ),
);

class _Viewport implements ThreadFloorViewport {
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
  final targets = <String>[];
  @override
  Future<bool> revealPost(
    String pid, {
    required bool animate,
    required bool Function() isCurrent,
  }) async {
    targets.add(pid);
    visiblePostId = pid;
    return true;
  }
}
