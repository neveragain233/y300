import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/presentation/services/thread_floor_navigation_coordinator.dart';
import 'package:y300/features/thread/presentation/widgets/thread_floating_controls.dart';
import 'package:y300/l10n/app_localizations.dart';

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
        ),
      ),
    ),
  ),
);

class _Viewport implements ThreadFloorViewport {
  @override
  bool atBottom = false;
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
