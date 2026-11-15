import 'dart:async';

import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart'
    hide ForumHomeRepository, ForumHomeFavoriteForum;
import 'package:y300/features/forum/data/repositories/forum_home_repository.dart';
import 'package:y300/features/cache/domain/models/document_cache_models.dart';

import '../../../support/forum_home_test_support.dart';

import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/history_entry_router.dart';
import 'package:y300/app/navigation/main_destination_page.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/app/navigation/main_navigation_settings_repository.dart';
import 'package:y300/features/messages/data/message_repository_provider.dart';
import 'package:y300/features/messages/presentation/message_center_page.dart';
import 'package:y300/features/messages/presentation/message_feed_providers.dart';
import 'package:y300/features/messages/application/message_attention_controller.dart';
import 'package:y300/features/messages/application/message_attention_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_attention_icon.dart';

import '../../messages/support/message_test_repository.dart';

import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/core/network/cookie_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';

import '../../../support/forum_auth_test_support.dart';

import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/features/comic/data/providers/comic_refresh_workflow_providers.dart';
import 'package:y300/features/comic/domain/models/comic_detail_models.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/models/comic_shelf_models.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_models.dart';
import 'package:y300/features/favorites/data/providers/favorite_providers.dart';
import 'package:y300/features/favorites/data/services/favorite_sync_service.dart';
import 'package:y300/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:y300/features/favorites/domain/models/favorite_cache_models.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_driver.dart';
import 'package:y300/features/history/data/providers/history_providers.dart';
import 'package:y300/features/history/domain/models/history_models.dart';
import 'package:y300/features/history/domain/repositories/history_repository.dart';
import 'package:y300/features/library_shared/data/providers/library_state_providers.dart';
import 'package:y300/features/library_shared/domain/repositories/library_state_repository.dart';
import 'package:y300/features/library_shared/data/providers/library_task_notification_providers.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/models/library_state_models.dart';
import 'package:y300/features/library_shared/domain/services/library_task_notification_service.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/pages/unified_shelf_page.dart';
import 'package:y300/features/more/presentation/more_page.dart';
import 'package:y300/features/more/presentation/navigation_management_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/data/providers/novel_providers.dart';
import 'package:y300/features/novel/data/repositories/novel_repository.dart';
import 'package:y300/features/novel/domain/models/novel_reader_marks.dart';
import 'package:y300/features/startup/presentation/main_shell_page.dart';
import 'package:y300/app/startup/main_shell_startup_providers.dart';
import 'package:y300/features/thread/domain/thread_content_classifier.dart';
import 'package:y300/l10n/app_localizations_zh.dart';
import 'package:y300/features/profile/data/providers/profile_read_providers.dart';
import 'package:y300/features/profile/presentation/profile_blog_page.dart';

import '../../profile/test_support/blog_directory_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(400, 800);
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  for (final style in AppNavigationBarStyle.values) {
    testWidgets(
      'feedback avoids $style chrome and internal overlays in the real shell',
      (tester) async {
        final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
          ComicSearchRefreshQueueSnapshot.empty,
        );
        final selection = ShelfSelectionHostController();
        addTearDown(queue.dispose);
        addTearDown(selection.dispose);
        await _pumpSelectionShell(
          tester,
          queueSnapshot: queue,
          selectionHost: selection,
          webViewDriver: _FakeForumWebViewDriver(),
        );
        final home = tester.element(find.byKey(const Key('forum-home-list')));
        final container = ProviderScope.containerOf(home);
        await container
            .read(appAppearanceControllerProvider.notifier)
            .setNavigationBarStyle(style);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(home);
        var undo = 0;
        showTransientSnackBar(
          home,
          l10n.contentFilterSaveFailed,
          action: SnackBarAction(
            label: l10n.contentFilterUndo,
            onPressed: () => undo++,
          ),
        );
        await tester.pumpAndSettle();
        final chrome = style == AppNavigationBarStyle.immersive
            ? find.byType(MainNavigationCapsule)
            : find.byType(NavigationBar);
        expect(
          tester.getRect(find.text(l10n.contentFilterUndo)).bottom,
          lessThan(tester.getRect(chrome).top),
        );
        await tester.tap(find.text(l10n.contentFilterUndo));
        await tester.pumpAndSettle();
        expect(undo, 1);
        unawaited(
          Navigator.of(home).push(
            MaterialPageRoute<void>(
              builder: (_) => const TransientFeedbackObstacle(
                bottom: 180,
                child: Scaffold(body: SizedBox.expand()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        showTransientSnackBar(home, l10n.contentFilterSaveFailed);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text(l10n.contentFilterSaveFailed)).bottom,
          lessThan(620),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final startupPage in MainStartupPage.values) {
    testWidgets(
      'cold launch resolves $startupPage once independently of order',
      (tester) async {
        final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
          ComicSearchRefreshQueueSnapshot.empty,
        );
        final selection = ShelfSelectionHostController();
        addTearDown(queue.dispose);
        addTearDown(selection.dispose);
        final repository = _FakeMainNavigationSettingsRepository(
          MainNavigationSettings(
            startupPage: startupPage,
            managedOrder: MainShellDestination.defaultManagedOrder.reversed,
            hiddenDestinations: MainShellDestination.defaultHiddenDestinations,
          ),
        );
        await _pumpSelectionShell(
          tester,
          queueSnapshot: queue,
          selectionHost: selection,
          webViewDriver: _FakeForumWebViewDriver(),
          navigationRepository: repository,
        );
        final initial = startupPage == MainStartupPage.forum
            ? 'forum'
            : 'novel';
        expect(find.byKey(Key('main-shell-page-$initial')), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MainShellPage)),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MainShellPage)),
        );
        await _tapNavigationGroup(tester, l10n.appNavigationMy);
        await container
            .read(mainNavigationSettingsControllerProvider.notifier)
            .setStartupPage(
              startupPage == MainStartupPage.forum
                  ? MainStartupPage.bookshelf
                  : MainStartupPage.forum,
            );
        await tester.pumpAndSettle();
        expect(find.byType(MorePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rail and phone navigation retain visited forum and shelf instances',
    (tester) async {
      final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        webViewDriver: _FakeForumWebViewDriver(),
      );
      final home = tester.element(find.byKey(const Key('forum-home-list')));
      tester.view.physicalSize = const Size(1100, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(home),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(l10n.appNavigationBookshelf),
        ),
      );
      await _pumpShellTab(tester);
      final comic = tester.element(
        find.byKey(const Key('main-shell-page-comic')),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(l10n.appNavigationForum),
        ),
      );
      await _pumpShellTab(tester);
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(MainNavigationCapsule), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(home),
      );
      await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
      expect(
        tester.element(find.byKey(const Key('main-shell-page-comic'))),
        same(comic),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reselecting and revisiting forum preserves the actual source route',
    (tester) async {
      final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        webViewDriver: _FakeForumWebViewDriver(),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      final homeContext = tester.element(
        find.byKey(const Key('forum-home-list')),
      );
      unawaited(
        Navigator.of(homeContext).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('fake-section'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('fake-section'), findsOneWidget);

      await _tapNavigationGroup(tester, l10n.appNavigationForum);
      await tester.pumpAndSettle();

      expect(find.text('fake-section'), findsOneWidget);
      await _tapNavigationGroup(tester, l10n.appNavigationMy);
      await _tapNavigationGroup(tester, l10n.appNavigationForum);
      expect(find.text('fake-section'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('immersive navigation is the default and clears content', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );
    final capsule = tester.widget<MainNavigationCapsule>(
      find.byType(MainNavigationCapsule),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.byKey(const Key('main-shell-immersive-navigation')),
      findsOneWidget,
    );
    expect(capsule.items.map((item) => item.label), <String>[
      l10n.appNavigationForum,
      l10n.appNavigationFavorites,
      l10n.appNavigationBookshelf,
      l10n.appNavigationMy,
    ]);
    expect(capsule.selectedIndex, 0);
    expect(capsule.swipeEnabled, isTrue);
    final listRect = tester.getRect(find.byKey(const Key('forum-home-list')));
    final capsuleRect = tester.getRect(find.byType(MainNavigationCapsule));
    // 正文视口铺到屏幕底部，内容从胶囊后方滚过，只在滚动尾部预留空间。
    expect(listRect.bottom, greaterThan(capsuleRect.top));
    final homeList = tester.widget<ListView>(
      find.byKey(const Key('forum-home-list')),
    );
    expect((homeList.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));

    await _tapNavigationGroup(tester, l10n.appNavigationFavorites);
    final shelfList = tester.widget<ListView>(
      find.byKey(const Key('unified-shelf-list-view')),
    );
    expect((shelfList.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));

    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    final moreList = tester.widget<ListView>(
      find.byKey(const Key('more-page-list')),
    );
    expect((moreList.padding! as EdgeInsets).bottom, greaterThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });

  for (final style in AppNavigationBarStyle.values) {
    for (final destination in [
      MainShellDestination.favorites,
      MainShellDestination.comic,
    ]) {
      testWidgets(
        'shelf modal covers shell chrome for ${destination.name} with ${style.name}',
        (tester) async {
          tester.view.padding = const FakeViewPadding(bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
            ComicSearchRefreshQueueSnapshot.empty,
          );
          final selection = ShelfSelectionHostController();
          addTearDown(queue.dispose);
          addTearDown(selection.dispose);
          await _pumpSelectionShell(
            tester,
            queueSnapshot: queue,
            selectionHost: selection,
            webViewDriver: _FakeForumWebViewDriver(),
          );
          final shellContext = tester.element(find.byType(MainShellPage));
          final appearance = ProviderScope.containerOf(shellContext)
              .read(appAppearanceControllerProvider.notifier);
          await appearance.setNavigationBarStyle(style);
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(shellContext);
          await _tapNavigationGroup(
            tester,
            destination == MainShellDestination.favorites
                ? l10n.appNavigationFavorites
                : l10n.appNavigationBookshelf,
          );
          await tester.pumpAndSettle();
          final page = find.byKey(Key('main-shell-page-${destination.name}'));
          final source = tester.element(page);
          final before = tester.getRect(page);
          final selectedIndex = _selectedNavigationIndex(tester);
          final navigation = style == AppNavigationBarStyle.immersive
              ? find.byType(MainNavigationCapsule)
              : find.byType(NavigationBar);
          final navigationPoint =
              tester.getTopLeft(navigation) + const Offset(30, 30);
          await tester.tap(
            find.byKey(const Key('unified-shelf-filter-button')),
          );
          await tester.pumpAndSettle();

          final sheet = find.byType(BottomSheet);
          final sheetContext = tester.element(sheet);
          expect(
            Navigator.of(sheetContext),
            same(Navigator.of(shellContext, rootNavigator: true)),
          );
          expect(find.text(l10n.commonApply).hitTestable(), findsOneWidget);
          expect(find.text(l10n.commonCancel).hitTestable(), findsOneWidget);
          expect(tester.getRect(page), before);
          await tester.tap(find.text(l10n.commonApply));
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(tester.element(page), same(source));

          await tester.tap(
            find.byKey(const Key('unified-shelf-filter-button')),
          );
          await tester.pumpAndSettle();
          // 底栏所在位置只能命中弹层或遮罩，不能切换背景入口。
          await tester.tapAt(navigationPoint);
          await tester.pumpAndSettle();
          expect(_selectedNavigationIndex(tester), selectedIndex);
          if (sheet.evaluate().isNotEmpty) {
            await tester.tap(find.text(l10n.commonCancel));
            await tester.pumpAndSettle();
          }
          expect(tester.element(page), same(source));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('legacy navigation switches without losing page state', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final home = tester.element(find.byKey(const Key('forum-home-list')));
    final container = ProviderScope.containerOf(home);
    final controller = container.read(appAppearanceControllerProvider.notifier);
    await controller.setNavigationBarStyle(AppNavigationBarStyle.legacy);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MainNavigationCapsule), findsNothing);
    expect(_navigationLabels(tester), hasLength(4));
    expect(
      tester.element(find.byKey(const Key('forum-home-list'))),
      same(home),
    );
    final legacyPageRect = tester.getRect(
      find.byKey(const Key('main-shell-page-forum')),
    );
    final legacyListRect = tester.getRect(
      find.byKey(const Key('forum-home-list')),
    );
    expect(legacyListRect.bottom, closeTo(legacyPageRect.bottom, 1));

    await controller.setNavigationBarStyle(AppNavigationBarStyle.immersive);
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationCapsule), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.element(find.byKey(const Key('forum-home-list'))),
      same(home),
    );
    final immersiveListRect = tester.getRect(
      find.byKey(const Key('forum-home-list')),
    );
    final capsuleRect = tester.getRect(find.byType(MainNavigationCapsule));
    expect(immersiveListRect.bottom, greaterThan(capsuleRect.top));

    // 切换样式只在主壳重建底栏，入口页面的滚动位置保持。
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );
    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    await tester.drag(
      find.byKey(const Key('more-page-list')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    ScrollableState moreScrollable() => tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('more-page-list')),
        matching: find.byType(Scrollable),
      ),
    );
    final offset = moreScrollable().position.pixels;
    expect(offset, greaterThan(0));

    await controller.setNavigationBarStyle(AppNavigationBarStyle.legacy);
    await tester.pumpAndSettle();
    expect(moreScrollable().position.pixels, offset);

    await controller.setNavigationBarStyle(AppNavigationBarStyle.immersive);
    await tester.pumpAndSettle();
    expect(moreScrollable().position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive capsule swipe switches groups on release', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final capsuleFinder = find.byType(MainNavigationCapsule);
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      0,
    );
    await tester.drag(capsuleFinder, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      1,
    );
    expect(find.byKey(const Key('main-shell-page-favorites')), findsOneWidget);

    await tester.drag(capsuleFinder, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      0,
    );
    expect(find.byKey(const Key('main-shell-page-forum')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled swipe leaves taps as the only group switch', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );
    await container
        .read(appAppearanceControllerProvider.notifier)
        .setNavigationSwipeEnabled(false);
    await tester.pumpAndSettle();

    final capsuleFinder = find.byType(MainNavigationCapsule);
    await tester.drag(capsuleFinder, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MainNavigationCapsule>(capsuleFinder).selectedIndex,
      0,
    );
    expect(find.byKey(const Key('main-shell-page-forum')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding entries falls back to a visible group and keeps a bar', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );
    final controller = container.read(
      mainNavigationSettingsControllerProvider.notifier,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );

    await controller.setVisibility(MainShellDestination.forum, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-shell-page-favorites')), findsOneWidget);
    expect(_navigationLabels(tester), <String>['收藏', '书架', '我的']);

    await controller.setVisibility(MainShellDestination.favorites, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);
    expect(_navigationLabels(tester), <String>['书架', '我的']);

    await controller.setVisibility(MainShellDestination.comic, false);
    await controller.setVisibility(MainShellDestination.novel, false);
    await tester.pumpAndSettle();
    expect(_navigationLabels(tester), <String>[l10n.appNavigationMy]);
    expect(
      tester
          .widget<MainNavigationCapsule>(find.byType(MainNavigationCapsule))
          .selectedIndex,
      0,
    );
    expect(find.byType(MorePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookshelf group opens one mixed page without type switcher', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MainShellPage)),
    );
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    final bookshelfPage = find.byKey(const Key('main-shell-page-comic'));
    final original = tester.element(bookshelfPage);
    expect(find.byKey(const Key('main-bookshelf-switcher')), findsNothing);
    expect(find.byKey(const Key('main-shell-page-novel')), findsNothing);
    final recentReading = find.byKey(const Key('unified-shelf-recent-reading'));
    expect(recentReading, findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(recentReading).onPressed,
      isNull,
    );

    await _tapNavigationGroup(tester, l10n.appNavigationFavorites);
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(tester.element(bookshelfPage), same(original));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard hides the immersive chrome and restores it', (
    tester,
  ) async {
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationCapsule), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('main-shell-page-forum'))).bottom,
      lessThanOrEqualTo(501),
    );

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationCapsule), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('forum-home-list'))).bottom,
      greaterThan(tester.getRect(find.byType(MainNavigationCapsule)).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('attention follows configured navigation without reading feeds', (
    tester,
  ) async {
    final attention = MessageAttentionController();
    const owner = (
      sessionOwner: (uid: '101', revision: 0),
      sourceGeneration: 0,
    );
    attention.setOwner(owner);
    attention.accept(
      const ForumMessageAttentionObservation(
        viewerUserId: '101',
        source: ForumMessageAttentionSource.mobileHtml,
        combinedHint: ForumMessageAttentionState.present,
      ),
      owner: owner,
      sequence: attention.nextRequestSequence(),
    );
    final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selection = ShelfSelectionHostController();
    final messages = MessageTestRepository();
    addTearDown(attention.dispose);
    addTearDown(queue.dispose);
    addTearDown(selection.dispose);
    await _pumpSelectionShell(
      tester,
      queueSnapshot: queue,
      selectionHost: selection,
      webViewDriver: _FakeForumWebViewDriver(),
      attention: attention,
      messages: messages,
    );

    MainNavigationItem groupItem(MainNavigationGroup group) => tester
        .widget<MainNavigationCapsule>(find.byType(MainNavigationCapsule))
        .items
        .firstWhere((item) => item.id == group.name);
    void expectDot(MainNavigationGroup target, bool expected) {
      final entry = groupItem(target);
      expect((entry.icon as MessageAttentionIcon).showAttention, expected);
      expect(
        (entry.selectedIcon as MessageAttentionIcon).showAttention,
        expected,
      );
    }

    expectDot(MainNavigationGroup.my, false);
    expectDot(MainNavigationGroup.forum, true);
    final context = tester.element(find.byType(MainShellPage));
    final l10n = AppLocalizations.of(context);
    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    await tester.pumpAndSettle();
    expectDot(MainNavigationGroup.my, false);
    expect(find.byKey(const Key('more-my-messages-entry')), findsNothing);
    expect(attention.value.hasUnacknowledgedAttention, false);

    await _tapNavigationGroup(tester, l10n.appNavigationForum);
    attention.accept(
      const ForumMessageAttentionObservation(
        viewerUserId: '101',
        source: ForumMessageAttentionSource.api,
        privateMessages: ForumMessageAttentionState.present,
        notifications: ForumMessageAttentionState.absent,
        notificationCount: 0,
      ),
      owner: owner,
      sequence: attention.nextRequestSequence(),
    );
    await tester.pump();
    expectDot(MainNavigationGroup.my, false);

    final navigation = ProviderScope.containerOf(context)
        .read(mainNavigationSettingsControllerProvider.notifier);
    await navigation.setVisibility(MainShellDestination.messages, true);
    await tester.pump();
    expectDot(MainNavigationGroup.messages, true);
    expectDot(MainNavigationGroup.my, false);
    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    expect(find.byKey(const Key('more-my-messages-entry')), findsNothing);
    final epoch = attention.value.attentionEpoch;
    await navigation.reorder(6, 0);
    await tester.pump();
    expectDot(MainNavigationGroup.messages, true);
    expect(attention.value.attentionEpoch, epoch);
    expect(messages.reads, isEmpty);
    expect(messages.notificationReads, isEmpty);
    await navigation.setVisibility(MainShellDestination.messages, false);
    await tester.pump();
    expectDot(MainNavigationGroup.my, false);
    expect(attention.value.attentionEpoch, epoch);
    expect(find.byKey(const Key('more-my-messages-entry')), findsNothing);
    await navigation.setVisibility(MainShellDestination.forum, false);
    await tester.pumpAndSettle();
    final fallback = tester.widget<ListTile>(
      find.byKey(const Key('more-my-messages-entry')),
    );
    expect((fallback.leading! as MessageAttentionIcon).showAttention, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cached forum stays mounted while covers wait and only shelves are gated',
    (tester) async {
      final covers = Completer<void>();
      final network = Completer<ForumHomeReadResult>();
      final repository = _FakeForumHomeRepository(
        cachedEntry: ForumHomeCacheEntry(
          payload: ForumHomePayload(
            directory: const ForumDirectoryData(
              sections: [
                ForumDirectorySection(
                  identity: 'cached',
                  title: 'Last home',
                  forums: [
                    ForumDirectoryForum(
                      fid: '16',
                      title: 'Cached forum',
                      description: '',
                      todayPosts: 5,
                    ),
                  ],
                ),
              ],
            ),
            isLoggedIn: false,
            favoriteForums: [],
          ),
          capabilities: forumHomeTestCapabilities,
          metadata: const DataReadMetadata.network(),
          updatedAt: DateTime(2026),
          cacheAccountId: 'anonymous',
        ),
        network: network.future,
      );
      final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        webViewDriver: _FakeForumWebViewDriver(),
        homeRepository: repository,
        libraryReady: covers.future,
      );
      expect(covers.isCompleted, isFalse);
      expect(find.text('Cached forum'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final before = tester.element(find.byKey(const Key('forum-home-list')));
      // Standalone shelves from navigation management use the same barrier.
      final route = ProviderScope.containerOf(
        before,
      ).read(mainDestinationRouteFactoryProvider)(MainShellDestination.comic);
      final navigator = Navigator.of(before);
      unawaited(navigator.push(route));
      await _pumpShellTab(tester);
      expect(
        find.byKey(const Key('main-shell-library-loading')),
        findsOneWidget,
      );
      expect(find.byType(UnifiedShelfPage), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
      expect(
        find.byKey(const Key('main-shell-library-loading')),
        findsOneWidget,
      );
      expect(find.byType(UnifiedShelfPage), findsNothing);
      await _tapNavigationGroup(tester, l10n.appNavigationForum);
      final reads = repository.cacheReads;
      covers.complete();
      await tester.pump();
      await tester.pump();
      expect(
        tester.element(find.byKey(const Key('forum-home-list'))),
        same(before),
      );
      expect(repository.cacheReads, reads);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      network.complete(forumHomeReadSuccess(repository.cachedEntry!.payload));
      await tester.pumpAndSettle();
      await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
      expect(find.byKey(const Key('main-shell-library-loading')), findsNothing);
      expect(find.byType(UnifiedShelfPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management opens hidden shelves with isolated working selection bars',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final shellHost = ShelfSelectionHostController();
      addTearDown(queueSnapshot.dispose);
      addTearDown(shellHost.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queueSnapshot,
        selectionHost: shellHost,
        webViewDriver: _FakeForumWebViewDriver(),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShellPage)),
      );
      final settingsController = container.read(
        mainNavigationSettingsControllerProvider.notifier,
      );
      for (final destination in [
        MainShellDestination.comic,
        MainShellDestination.novel,
        MainShellDestination.favorites,
      ]) {
        await settingsController.setVisibility(destination, false);
      }
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MainShellPage)),
      );
      await _tapNavigationGroup(tester, l10n.appNavigationMy);
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-navigation-management-entry')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('more-page-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('more-navigation-management-entry')),
      );
      await tester.pumpAndSettle();
      final settingsBefore = container
          .read(mainNavigationSettingsControllerProvider)
          .requireValue
          .settings;

      for (final destination in ['bookshelf', 'favorites']) {
        await tester.tap(
          find.byKey(ValueKey('navigation-management-open-$destination')),
        );
        await _pumpShellTab(tester);
        final shelf = find.byType(UnifiedShelfPage);
        expect(shelf, findsOneWidget);
        final pageContainer = ProviderScope.containerOf(tester.element(shelf));
        final pageHost = pageContainer.read(
          shelfSelectionHostControllerProvider,
        );
        expect(pageHost, isNot(same(shellHost)));
        expect(
          tester.widget<UnifiedShelfPage>(shelf).selectionHost,
          same(pageHost),
        );
        final calls = <String>[];
        pageHost.activate(
          ownerToken: Object(),
          moduleKey: tester.widget<UnifiedShelfPage>(shelf).adapter.moduleKey,
          activeCategoryId: 'default',
          selectedCount: 1,
          selectedWorkIds: {'fixture'},
          selectionActions: const [
            SelectionAction(
              id: SelectionActionIds.download,
              icon: Icons.download,
            ),
          ],
          delegate: _selectionDelegate(
            onRun: (request) async {
              calls.add(request.actionId);
              return const SelectionActionOutcome(
                code: SelectionActionOutcomeCode.noChange,
              );
            },
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('selection-action-bar')), findsOneWidget);
        expect(shellHost.isActive, isFalse);
        await tester.tap(find.byKey(const Key('selection-action-download')));
        await tester.pump();
        expect(calls, [SelectionActionIds.download]);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationManagementPage), findsOneWidget);
        expect(pageHost.isActive, isFalse);
        expect(shellHost.isActive, isFalse);
        expect(
          container
              .read(mainNavigationSettingsControllerProvider)
              .requireValue
              .settings,
          settingsBefore,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('MainShellPage can switch across all six lazy tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final textScale = ValueNotifier<double>(2);
    final blogs = BlogDirectoryFixture();
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    addTearDown(textScale.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blogAccountIdProvider.overrideWithValue('101'),
          userBlogDirectoryRepositoryProvider.overrideWithValue(blogs),
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          historyRepositoryProvider.overrideWithValue(
            const _FakeHistoryRepository(),
          ),
        ],
        child: LocalizedTestApp(
          builder: (context, child) {
            return ValueListenableBuilder<double>(
              valueListenable: textScale,
              builder: (context, scale, _) {
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                );
              },
            );
          },
          home: const MainShellPage(),
        ),
      ),
    );

    await _pumpMainShellReady(tester);

    final l10n = AppLocalizationsZh();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    final capsule = tester.widget<MainNavigationCapsule>(
      find.byType(MainNavigationCapsule),
    );
    expect(capsule.items.map((item) => item.label), <String>[
      l10n.appNavigationForum,
      l10n.appNavigationFavorites,
      l10n.appNavigationBookshelf,
      l10n.appNavigationMy,
    ]);
    expect(_navigationIconData(capsule.items[1].icon), Icons.star_border);
    expect(_navigationIconData(capsule.items[1].selectedIcon), Icons.star);
    expect(
      _navigationIconData(capsule.items[2].icon),
      Icons.auto_stories_outlined,
    );
    final initialStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(
      initialStack.children,
      hasLength(MainShellDestination.values.length),
    );
    expect(blogs.queries, isEmpty);
    final initialTickerModes = _builtTickerModes(initialStack);
    expect(initialTickerModes, hasLength(1));
    expect(initialTickerModes.single.enabled, isTrue);
    expect(tester.takeException(), isNull);

    textScale.value = 1;
    await tester.binding.setSurfaceSize(const Size(800, 700));
    await tester.pump();

    await _tapNavigationGroup(tester, l10n.appNavigationFavorites);
    expect(find.byKey(const Key('unified-shelf-list-view')), findsOneWidget);

    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);
    expect(find.byKey(const Key('main-bookshelf-switcher')), findsNothing);

    await _tapNavigationGroup(tester, l10n.appNavigationMy);
    expect(find.byKey(const Key('more-login-entry')), findsOneWidget);
    final fullyBuiltStack = tester.widget<IndexedStack>(
      find.byType(IndexedStack),
    );
    final fullyBuiltTickerModes = _builtTickerModes(fullyBuiltStack);
    expect(fullyBuiltTickerModes, hasLength(4));
    expect(
      fullyBuiltTickerModes.map((tickerMode) => tickerMode.enabled),
      <bool>[false, false, false, true],
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShellPage)),
    );

    await container
        .read(mainNavigationSettingsControllerProvider.notifier)
        .setVisibility(MainShellDestination.forum, false);
    await tester.pumpAndSettle();
    // 论坛隐藏时由“我的”接替记录入口，日志始终可用。
    final navigator = Navigator.of(
      tester.element(find.byKey(const Key('more-page-list'))),
    );
    await tester.tap(find.byKey(const ValueKey('more-destination-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-page')), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MainShellPage), findsOneWidget);
    expect(find.byType(MorePage), findsOneWidget);

    await container
        .read(mainNavigationSettingsControllerProvider.notifier)
        .setVisibility(MainShellDestination.blogs, true);
    await tester.pumpAndSettle();
    expect(blogs.queries, isEmpty);
    await tester.tap(find.byKey(const ValueKey('more-destination-blogs')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileBlogPage), findsOneWidget);
    expect(blogs.queries, hasLength(1));
    Navigator.of(tester.element(find.byType(ProfileBlogPage))).pop();
    await tester.pumpAndSettle();

    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history opened from forum routes its threads through the forum host',
    (tester) async {
      final queue = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selection = ShelfSelectionHostController();
      addTearDown(queue.dispose);
      addTearDown(selection.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queue,
        selectionHost: selection,
        webViewDriver: _FakeForumWebViewDriver(),
        historyRepository: _FakeHistoryRepository(items: [_historyEntry()]),
        historyEntryRouter: _NavigatingHistoryEntryRouter(),
      );

      await tester.tap(find.byKey(const Key('forum-home-history-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-page')), findsOneWidget);
      // 记录页仍是主壳的来源页，底栏保留；只有打开详情才退出底栏。
      expect(
        find.byKey(const Key('main-shell-immersive-navigation')),
        findsOneWidget,
      );
      // 不能让记录页再套一层宿主，否则详情会被截留在内层。
      expect(find.byType(AdaptiveDetailHost), findsOneWidget);

      await tester.tap(find.text('测试记录帖子'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-history-detail')), findsOneWidget);
      expect(
        find.byKey(const Key('main-shell-immersive-navigation')),
        findsNothing,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-page')), findsOneWidget);
      expect(
        find.byKey(const Key('main-shell-immersive-navigation')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'MainShellPage applies custom order with stable lazy destination slots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final webViewDriver = _FakeForumWebViewDriver();
      final navigationRepository = _FakeMainNavigationSettingsRepository(
        MainNavigationSettings(
          managedOrder: const <MainShellDestination>[
            MainShellDestination.novel,
            MainShellDestination.comic,
            MainShellDestination.forum,
            MainShellDestination.favorites,
            MainShellDestination.history,
          ],
          hiddenDestinations: const <MainShellDestination>{
            MainShellDestination.forum,
            MainShellDestination.history,
            MainShellDestination.blogs,
            MainShellDestination.messages,
          },
        ),
      );
      final messages = MessageTestRepository();
      addTearDown(queueSnapshot.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mainNavigationSettingsRepositoryProvider.overrideWithValue(
              navigationRepository,
            ),
            messageAccountIdProvider.overrideWithValue('10'),
            messageRepositoryProvider.overrideWithValue(messages),
            comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            localFavoriteRepositoryProvider.overrideWith(
              (ref) => _FakeLocalFavoriteRepository(),
            ),
            favoriteSyncServiceProvider.overrideWith(
              (ref) => _FakeFavoriteSyncService(),
            ),
            comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
              queueSnapshot,
            ),
            mainShellBackgroundTaskStarterProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellNotificationInitializerProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellReplyDraftAttachmentMaintenanceStarterProvider
                .overrideWithValue(() async {}),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
            historyRepositoryProvider.overrideWithValue(
              const _FakeHistoryRepository(),
            ),
          ],
          child: const LocalizedTestApp(home: MainShellPage()),
        ),
      );

      await _pumpMainShellReady(tester);

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-novel')), findsOneWidget);
      expect(find.byKey(const Key('main-shell-page-forum')), findsNothing);

      expect(find.byKey(const Key('main-bookshelf-switcher')), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShellPage)),
      );
      final controller = container.read(
        mainNavigationSettingsControllerProvider.notifier,
      );

      // 漫画移到最前，书架规范入口从小说切到漫画，但页面栈只保留一个书架页。
      await controller.reorder(1, 0);
      await tester.pump();

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-novel')), findsNothing);
      expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);

      await controller.setVisibility(MainShellDestination.comic, false);
      await tester.pump();

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-comic')), findsNothing);
      expect(find.byKey(const Key('main-shell-page-novel')), findsOneWidget);

      await controller.setVisibility(MainShellDestination.comic, true);
      await tester.pump();

      expect(_navigationLabels(tester), <String>['书架', '收藏', '我的']);
      expect(_selectedNavigationIndex(tester), 0);
      expect(find.byKey(const Key('main-shell-page-novel')), findsNothing);
      expect(find.byKey(const Key('main-shell-page-comic')), findsOneWidget);

      expect(messages.reads, isEmpty);
      await controller.setVisibility(MainShellDestination.messages, true);
      await tester.pump();
      final label = AppLocalizationsZh().appNavigationMessages;
      expect(_navigationLabels(tester), <String>['书架', '收藏', '消息', '我的']);
      await _tapNavigationGroup(tester, label);
      expect(messages.reads, hasLength(1));
      expect(messages.notificationReads, isEmpty);
      messages.reads.single.result.complete(messageTestPage([]));
      await _pumpShellTab(tester);
      final messageElement = tester.element(find.byType(MessageCenterPage));
      await _tapNavigationGroup(tester, '书架');
      await _tapNavigationGroup(tester, label);
      expect(
        tester.element(find.byType(MessageCenterPage)),
        same(messageElement),
      );
      expect(messages.reads, hasLength(1));
    },
  );

  testWidgets('navigation group icon changes after tap', (tester) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );

    await _pumpMainShellReady(tester);

    Finder capsuleIcon(IconData icon) => find.descendant(
      of: find.byType(MainNavigationCapsule),
      matching: find.byIcon(icon),
    );
    expect(capsuleIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(capsuleIcon(Icons.auto_stories), findsNothing);

    await _tapNavigationGroup(tester, '书架');

    expect(capsuleIcon(Icons.auto_stories_outlined), findsNothing);
    expect(capsuleIcon(Icons.auto_stories), findsOneWidget);
  });

  testWidgets('mixed shelf keeps one search state across group switching', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );

    await _pumpMainShellReady(tester);

    final l10n = AppLocalizationsZh();
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    final bookshelf = tester.element(
      find.byKey(const Key('main-shell-page-comic')),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '混合关键词');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _tapNavigationGroup(tester, l10n.appNavigationForum);
    await _tapNavigationGroup(tester, l10n.appNavigationBookshelf);
    expect(
      tester.element(find.byKey(const Key('main-shell-page-comic'))),
      same(bookshelf),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '混合关键词',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MainShellPage immersive navigation reads the themed background color',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final webViewDriver = _FakeForumWebViewDriver();
      addTearDown(queueSnapshot.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            localFavoriteRepositoryProvider.overrideWith(
              (ref) => _FakeLocalFavoriteRepository(),
            ),
            favoriteSyncServiceProvider.overrideWith(
              (ref) => _FakeFavoriteSyncService(),
            ),
            comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
              queueSnapshot,
            ),
            mainShellBackgroundTaskStarterProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellNotificationInitializerProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          ],
          child: LocalizedTestApp(
            theme: AppTheme.light(),
            home: const MainShellPage(),
          ),
        ),
      );

      await _pumpMainShellReady(tester);

      final navigationBarContext = tester.element(
        find.byKey(const Key('main-shell-immersive-navigation')),
      );
      expect(
        NavigationBarTheme.of(navigationBarContext).backgroundColor,
        const Color(0xFFFDE6B9),
      );
    },
  );

  testWidgets(
    'MainShellPage notification permission wiring does not block shell build',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final notificationService = _FakeLibraryTaskNotificationService(
        initialPermission: LibraryTaskNotificationPermissionState.denied,
      );
      final webViewDriver = _FakeForumWebViewDriver();
      addTearDown(queueSnapshot.dispose);
      addTearDown(notificationService.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            localFavoriteRepositoryProvider.overrideWith(
              (ref) => _FakeLocalFavoriteRepository(),
            ),
            favoriteSyncServiceProvider.overrideWith(
              (ref) => _FakeFavoriteSyncService(),
            ),
            comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
              queueSnapshot,
            ),
            mainShellBackgroundTaskStarterProvider.overrideWithValue(
              (_) async {},
            ),
            libraryTaskNotificationServiceProvider.overrideWithValue(
              notificationService,
            ),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          ],
          child: const LocalizedTestApp(home: MainShellPage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MainShellPage warms up Yamibo profile session on startup', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    var warmupCalls = 0;
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellReplyDraftAttachmentMaintenanceStarterProvider
              .overrideWithValue(() async {}),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {
            warmupCalls += 1;
          }),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );

    await tester.pump();

    expect(warmupCalls, 1);
  });

  testWidgets('MainShellPage ignores Yamibo profile warmup failure', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellReplyDraftAttachmentMaintenanceStarterProvider
              .overrideWithValue(() async {}),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {
            throw StateError('warmup failed');
          }),
          ...forumAuthOverrides(_FakeAuthRepository()),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forum-home-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MainShellPage switches bottom bar when selection becomes active',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selectionHost = ShelfSelectionHostController();
      final webViewDriver = _FakeForumWebViewDriver();
      addTearDown(queueSnapshot.dispose);
      addTearDown(selectionHost.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
            novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
            libraryStateRepositoryProvider.overrideWithValue(
              _FakeLibraryStateRepository(),
            ),
            localFavoriteRepositoryProvider.overrideWith(
              (ref) => _FakeLocalFavoriteRepository(),
            ),
            favoriteSyncServiceProvider.overrideWith(
              (ref) => _FakeFavoriteSyncService(),
            ),
            comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
              queueSnapshot,
            ),
            mainShellBackgroundTaskStarterProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellNotificationInitializerProvider.overrideWithValue(
              (_) async {},
            ),
            mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
            ...forumAuthOverrides(_FakeAuthRepository()),
            shelfSelectionHostControllerProvider.overrideWithValue(
              selectionHost,
            ),
            forumHomeRepositoryProvider.overrideWithValue(
              _FakeForumHomeRepository(),
            ),
            forumWebViewDriverFactoryProvider.overrideWithValue(
              () => webViewDriver,
            ),
            cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
          ],
          child: const LocalizedTestApp(home: MainShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationCapsule), findsOneWidget);
      expect(find.byKey(const Key('selection-action-bar')), findsNothing);

      selectionHost.activate(
        ownerToken: Object(),
        moduleKey: LibraryModuleKey.comic,
        activeCategoryId: 'default',
        selectedCount: 1,
        selectedWorkIds: const <String>{'comic-1'},
        selectionActions: const <SelectionAction>[
          SelectionAction(
            id: SelectionActionIds.download,
            icon: Icons.download_outlined,
          ),
        ],
        delegate: _selectionDelegate(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationCapsule), findsNothing);
      expect(find.byKey(const Key('selection-action-bar')), findsOneWidget);

      selectionHost.deactivate(selectionHost.state!.ownerToken);
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationCapsule), findsOneWidget);
      expect(find.byKey(const Key('selection-action-bar')), findsNothing);
    },
  );

  testWidgets('MainShellPage selection action bar delegates button taps', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selectionHost = ShelfSelectionHostController();
    final calls = <String>[];
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    addTearDown(selectionHost.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          shelfSelectionHostControllerProvider.overrideWithValue(selectionHost),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    selectionHost.activate(
      ownerToken: Object(),
      moduleKey: LibraryModuleKey.comic,
      activeCategoryId: 'default',
      selectedCount: 1,
      selectedWorkIds: const <String>{'comic-1'},
      selectionActions: const <SelectionAction>[
        SelectionAction(
          id: SelectionActionIds.download,
          icon: Icons.download_outlined,
        ),
      ],
      delegate: _selectionDelegate(
        onRun: (request) async {
          calls.add(request.actionId);
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.noChange,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-download')),
    );
    await tester.pumpAndSettle();

    expect(calls, <String>[SelectionActionIds.download]);
    expect(selectionHost.isActive, isTrue);
  });

  testWidgets(
    'MainShellPage selection category creation safely handles cancel and confirm',
    (tester) async {
      final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
        ComicSearchRefreshQueueSnapshot.empty,
      );
      final selectionHost = ShelfSelectionHostController();
      final webViewDriver = _FakeForumWebViewDriver();
      final createdNames = <String>[];
      final requests = <SelectionActionExecutionRequest>[];
      addTearDown(queueSnapshot.dispose);
      addTearDown(selectionHost.dispose);
      await _pumpSelectionShell(
        tester,
        queueSnapshot: queueSnapshot,
        selectionHost: selectionHost,
        webViewDriver: webViewDriver,
      );

      selectionHost.activate(
        ownerToken: Object(),
        moduleKey: LibraryModuleKey.comic,
        activeCategoryId: 'default',
        selectedCount: 1,
        selectedWorkIds: const <String>{'comic-1'},
        selectionActions: const <SelectionAction>[
          SelectionAction(
            id: SelectionActionIds.assignCategory,
            icon: Icons.label_outline,
          ),
        ],
        delegate: ShelfSelectionHostDelegate(
          exitSelection: () async {},
          selectAllVisible: () async {},
          invertVisible: () async {},
          loadAvailableCategories: () async => const <LibraryCategory>[],
          createCategory: (name) async {
            createdNames.add(name);
            return 'created-category';
          },
          runSelectionAction: (request) async {
            requests.add(request);
            return const SelectionActionOutcome(
              code: SelectionActionOutcomeCode.noChange,
            );
          },
          refreshAfterAction: () async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-action-assign-category')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建分类'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOne);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(createdNames, isEmpty);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-action-assign-category')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建分类'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新分类');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(createdNames, const <String>['新分类']);
      expect(requests, hasLength(1));
      expect(requests.single.targetCategoryId, 'created-category');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MainShellPage unfavorite action requires confirmation', (
    tester,
  ) async {
    final queueSnapshot = ValueNotifier<ComicSearchRefreshQueueSnapshot>(
      ComicSearchRefreshQueueSnapshot.empty,
    );
    final selectionHost = ShelfSelectionHostController();
    var runCount = 0;
    final webViewDriver = _FakeForumWebViewDriver();
    addTearDown(queueSnapshot.dispose);
    addTearDown(selectionHost.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
          novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
          libraryStateRepositoryProvider.overrideWithValue(
            _FakeLibraryStateRepository(),
          ),
          localFavoriteRepositoryProvider.overrideWith(
            (ref) => _FakeLocalFavoriteRepository(),
          ),
          favoriteSyncServiceProvider.overrideWith(
            (ref) => _FakeFavoriteSyncService(),
          ),
          comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
            queueSnapshot,
          ),
          mainShellBackgroundTaskStarterProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellNotificationInitializerProvider.overrideWithValue(
            (_) async {},
          ),
          mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
          ...forumAuthOverrides(_FakeAuthRepository()),
          shelfSelectionHostControllerProvider.overrideWithValue(selectionHost),
          forumHomeRepositoryProvider.overrideWithValue(
            _FakeForumHomeRepository(),
          ),
          forumWebViewDriverFactoryProvider.overrideWithValue(
            () => webViewDriver,
          ),
          cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        ],
        child: const LocalizedTestApp(home: MainShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    selectionHost.activate(
      ownerToken: Object(),
      moduleKey: LibraryModuleKey.favorite,
      activeCategoryId: 'default',
      selectedCount: 2,
      selectedWorkIds: const <String>{'favorite:100', 'favorite:101'},
      selectionActions: const <SelectionAction>[
        SelectionAction(
          id: SelectionActionIds.unfavorite,
          icon: Icons.delete_outline,
          destructive: true,
          needsConfirm: true,
        ),
      ],
      delegate: _selectionDelegate(
        onRun: (request) async {
          runCount += 1;
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.success,
            changed: true,
            succeededCount: 2,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-unfavorite')),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认取消收藏'), findsOneWidget);
    expect(find.textContaining('会被清除'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(runCount, 0);
    expect(selectionHost.isActive, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('selection-action-unfavorite')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(runCount, 1);
    expect(selectionHost.isActive, isFalse);
  });
}

Future<void> _pumpShellTab(WidgetTester tester) async {
  // Shelf tabs can legitimately keep an indeterminate loading indicator
  // alive while their first async load is in flight. The test only needs a
  // bounded frame window for the tab transition, not global quiescence.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  // A newly mounted shelf first passes its own cover-readiness FutureBuilder.
  await tester.pump();
}

Future<void> _pumpSelectionShell(
  WidgetTester tester, {
  required ValueNotifier<ComicSearchRefreshQueueSnapshot> queueSnapshot,
  required ShelfSelectionHostController selectionHost,
  required _FakeForumWebViewDriver webViewDriver,
  ForumHomeRepository? homeRepository,
  Future<void>? libraryReady,
  MessageAttentionController? attention,
  MessageTestRepository? messages,
  MainNavigationSettingsRepository? navigationRepository,
  HistoryRepository? historyRepository,
  HistoryEntryRouter? historyEntryRouter,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (navigationRepository != null)
          mainNavigationSettingsRepositoryProvider.overrideWithValue(
            navigationRepository,
          ),
        if (messages != null)
          messageRepositoryProvider.overrideWithValue(messages),
        if (attention != null) ...[
          messageAttentionControllerProvider.overrideWithValue(attention),
          messageAttentionOwnerProvider.overrideWithValue(
            attention.value.owner,
          ),
        ],
        comicRepositoryProvider.overrideWithValue(_FakeComicRepository()),
        novelRepositoryProvider.overrideWithValue(_FakeNovelRepository()),
        libraryStateRepositoryProvider.overrideWithValue(
          _FakeLibraryStateRepository(),
        ),
        localFavoriteRepositoryProvider.overrideWith(
          (ref) => _FakeLocalFavoriteRepository(),
        ),
        favoriteSyncServiceProvider.overrideWith(
          (ref) => _FakeFavoriteSyncService(),
        ),
        comicSearchRefreshQueueSnapshotProvider.overrideWithValue(
          queueSnapshot,
        ),
        mainShellBackgroundTaskStarterProvider.overrideWithValue((_) async {
          await libraryReady;
        }),
        mainShellNotificationInitializerProvider.overrideWithValue(
          (_) async {},
        ),
        mainShellYamiboSessionWarmupProvider.overrideWithValue(() async {}),
        ...forumAuthOverrides(_FakeAuthRepository()),
        shelfSelectionHostControllerProvider.overrideWithValue(selectionHost),
        forumHomeRepositoryProvider.overrideWithValue(
          homeRepository ?? _FakeForumHomeRepository(),
        ),
        forumWebViewDriverFactoryProvider.overrideWithValue(
          () => webViewDriver,
        ),
        cookieStoreProvider.overrideWithValue(_FakeCookieStore()),
        historyRepositoryProvider.overrideWithValue(
          historyRepository ?? const _FakeHistoryRepository(),
        ),
        if (historyEntryRouter != null)
          historyEntryRouterProvider.overrideWithValue(historyEntryRouter),
      ],
      child: const LocalizedTestApp(home: MainShellPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMainShellReady(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    if (find
        .byKey(const Key('main-shell-navigation-loading'))
        .evaluate()
        .isEmpty) {
      // The selected destination can have its own async settings provider.
      // Give that child one frame after the shell configuration is ready.
      await tester.pump();
      return;
    }
  }
  fail('Main shell navigation settings did not finish loading');
}

List<TickerMode> _builtTickerModes(IndexedStack stack) {
  return stack.children
      .whereType<KeyedSubtree>()
      .map((subtree) => subtree.child)
      .whereType<TickerMode>()
      .toList(growable: false);
}

List<MainNavigationItem> _navigationItems(WidgetTester tester) {
  final capsule = find.byType(MainNavigationCapsule);
  if (capsule.evaluate().isNotEmpty) {
    return tester.widget<MainNavigationCapsule>(capsule).items;
  }
  final bar = find.byType(NavigationBar);
  if (bar.evaluate().isNotEmpty) {
    return tester
        .widget<NavigationBar>(bar)
        .destinations
        .cast<NavigationDestination>()
        .map(
          (destination) => MainNavigationItem(
            id: destination.label,
            label: destination.label,
            icon: destination.icon,
            selectedIcon: destination.selectedIcon ?? destination.icon,
          ),
        )
        .toList(growable: false);
  }
  return tester
      .widget<MainNavigationRail>(find.byType(MainNavigationRail))
      .items;
}

List<String> _navigationLabels(WidgetTester tester) =>
    _navigationItems(tester).map((item) => item.label).toList();

int _selectedNavigationIndex(WidgetTester tester) {
  final capsule = find.byType(MainNavigationCapsule);
  if (capsule.evaluate().isNotEmpty) {
    return tester.widget<MainNavigationCapsule>(capsule).selectedIndex;
  }
  final bar = find.byType(NavigationBar);
  if (bar.evaluate().isNotEmpty) {
    return tester.widget<NavigationBar>(bar).selectedIndex;
  }
  return tester
      .widget<MainNavigationRail>(find.byType(MainNavigationRail))
      .selectedIndex;
}

Future<void> _tapNavigationGroup(WidgetTester tester, String label) async {
  final capsule = find.byType(MainNavigationCapsule);
  final rail = find.byType(NavigationRail);
  final bar = find.byType(NavigationBar);
  final Finder target;
  if (capsule.evaluate().isNotEmpty) {
    target = find.descendant(of: capsule, matching: find.text(label));
  } else if (rail.evaluate().isNotEmpty) {
    target = find.descendant(of: rail, matching: find.text(label));
  } else {
    target = find.descendant(of: bar, matching: find.text(label));
  }
  await tester.tap(target);
  await _pumpShellTab(tester);
}

IconData? _navigationIconData(Widget widget) {
  return (widget as MessageAttentionIcon).icon;
}

ShelfSelectionHostDelegate _selectionDelegate({
  Future<SelectionActionOutcome> Function(
    SelectionActionExecutionRequest request,
  )?
  onRun,
}) {
  return ShelfSelectionHostDelegate(
    exitSelection: () async {},
    selectAllVisible: () async {},
    invertVisible: () async {},
    loadAvailableCategories: () async => const <LibraryCategory>[],
    createCategory: (name) async => 'created',
    runSelectionAction:
        onRun ??
        (request) async {
          return const SelectionActionOutcome(
            code: SelectionActionOutcomeCode.noChange,
          );
        },
    refreshAfterAction: () async {},
  );
}

HistoryEntry _historyEntry() {
  return HistoryEntry(
    target: const HistoryTargetKey(
      type: HistoryTargetType.thread,
      id: '572514',
    ),
    title: '测试记录帖子',
    contextLabel: '管理版',
    lastSurface: HistoryVisitSurface.threadNative,
    firstVisitedAt: DateTime(2026, 11, 13),
    lastVisitedAt: DateTime(2026, 11, 13, 12),
    visitCount: 1,
  );
}

class _NavigatingHistoryEntryRouter extends HistoryEntryRouter {
  _NavigatingHistoryEntryRouter()
    : super(
        comicWorkExists: (_) async => true,
        novelWorkExists: (_) async => true,
      );

  @override
  Future<HistoryOpenResult> open(
    BuildContext context,
    HistoryEntry entry,
  ) async {
    unawaited(
      openAdaptiveDetail<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                'fake-history-detail',
                key: Key('fake-history-detail'),
              ),
            ),
          ),
        ),
      ),
    );
    return const HistoryOpenSuccess();
  }
}

class _FakeHistoryRepository implements HistoryRepository {
  const _FakeHistoryRepository({this.items = const <HistoryEntry>[]});

  final List<HistoryEntry> items;

  @override
  Future<void> recordVisit(HistoryEntry candidate) async {}

  @override
  Future<HistoryQueryPage> query(HistoryQuery query) async {
    return HistoryQueryPage(items: items, hasMore: false);
  }

  @override
  Future<void> delete(HistoryTargetKey target) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> restore(HistoryEntry entry) async {}

  @override
  Stream<HistoryChange> watchChanges() {
    return const Stream<HistoryChange>.empty();
  }
}

class _FakeMainNavigationSettingsRepository
    implements MainNavigationSettingsRepository {
  _FakeMainNavigationSettingsRepository(this.settings);

  MainNavigationSettings settings;

  @override
  Future<MainNavigationSettings> load() async => settings;

  @override
  Future<void> save(MainNavigationSettings settings) async {
    this.settings = settings;
  }
}

class _FakeLibraryTaskNotificationService
    implements LibraryTaskNotificationService {
  _FakeLibraryTaskNotificationService({
    required LibraryTaskNotificationPermissionState? initialPermission,
  }) : _permissionState =
           ValueNotifier<LibraryTaskNotificationPermissionState?>(
             initialPermission,
           );

  final ValueNotifier<LibraryTaskNotificationPermissionState?> _permissionState;
  int initializeCalls = 0;
  int ensurePermissionCalls = 0;

  @override
  ValueListenable<LibraryTaskNotificationPermissionState?>
  get permissionState => _permissionState;

  @override
  Future<void> clear(LibraryTaskNotificationKey key) async {}

  @override
  Future<LibraryTaskNotificationPermissionState> ensurePermission() async {
    ensurePermissionCalls++;
    return _permissionState.value ??
        LibraryTaskNotificationPermissionState.denied;
  }

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> showOrUpdate(LibraryTaskNotification notification) async {}

  void dispose() {
    _permissionState.dispose();
  }
}

class _FakeForumWebViewDriver implements ForumWebViewDriver {
  @override
  Widget buildWidget({Key? key}) {
    return Container(key: key);
  }

  @override
  Future<ForumWebViewCapabilityProfile> probeCapabilities() async {
    return const ForumWebViewCapabilityProfile(
      documentStartMode: ForumWebViewDocumentStartMode.reliable,
      supportsContentBlockers: false,
      supportsTransparentBackground: true,
      supportsPlatformScrollTuning: true,
      supportsCookieHooks: true,
      supportsPageCommitVisible: true,
    );
  }

  @override
  Future<void> initialize({
    required ForumWebViewCallbacks callbacks,
    required ForumWebViewBootstrapConfig bootstrapConfig,
  }) async {}

  @override
  Future<void> load(Uri uri, {Map<String, String> headers = const {}}) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<bool> clearCookies() async {
    return true;
  }

  @override
  Future<String?> getTitle() async {
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    return false;
  }

  @override
  Future<void> goBack() async {}

  @override
  Future<void> runJavaScript(String script) async {}

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    return null;
  }

  @override
  Future<void> seedCookies({
    required String domain,
    required Map<String, String> cookies,
    String path = '/',
  }) async {}
}

class _FakeCookieStore extends CookieStore {
  @override
  Future<Map<String, String>> readCookieMap(Uri uri) async {
    return <String, String>{};
  }

  @override
  Future<String?> readCookieHeader(Uri uri) async {
    return null;
  }
}

class _FakeComicRepository implements ComicRepository {
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
  Future<String> createCategory({required String name}) async =>
      'mock-category';

  @override
  Future<void> clearEpisodeImageCache({required String episodeId}) async {}

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<ComicDetail?> getComicDetail({required String comicId}) async => null;

  @override
  Future<List<ComicEpisodeItem>> getComicEpisodes({
    required String comicId,
    bool descending = true,
  }) async {
    return const <ComicEpisodeItem>[];
  }

  @override
  Future<List<ComicEpisodeImageItem>> getEpisodeImages({
    required String episodeId,
  }) async {
    return const <ComicEpisodeImageItem>[];
  }

  @override
  Future<List<ComicShelfCategory>> getCategories() async {
    return <ComicShelfCategory>[
      ComicShelfCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<ComicShelfDisplaySettings> getDisplaySettings() async {
    return const ComicShelfDisplaySettings(gridColumnCount: 3);
  }

  @override
  Future<List<ComicShelfItem>> getShelfItems({
    String categoryId = 'default',
  }) async {
    return const <ComicShelfItem>[];
  }

  @override
  Future<bool> isInShelf({required String comicId}) async {
    return false;
  }

  @override
  Future<ComicReadingProgress?> getLastReadProgress({
    required String comicId,
  }) async => null;

  @override
  Future<ComicReadingProgress?> getReadingProgressForEpisode({
    required String comicId,
    required String episodeId,
  }) async => null;

  @override
  Future<List<ComicReadingProgress>> getReadingProgresses({
    required String comicId,
  }) async => const <ComicReadingProgress>[];

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
  Future<void> updateGridColumnCount({required int columnCount}) async {}

  @override
  Future<void> saveEpisodeImages({
    required String episodeId,
    required List<String> imageUrls,
  }) async {}

  @override
  Future<void> updateEpisodeImageCacheStatus({
    required String episodeId,
    required String imageUrl,
    required String cacheStatus,
    String? cacheLocalPath,
  }) async {}

  @override
  Future<void> updateLastReadProgress({
    required String comicId,
    required String episodeId,
    required int imageIndex,
    required double scrollOffset,
  }) async {}

  @override
  Future<void> updateCatalogUrl({
    required String comicId,
    required String catalogUrl,
  }) async {}

  @override
  Future<Set<String>> getKnownEpisodeTids({required String comicId}) async =>
      <String>{};
}

class _FakeNovelRepository implements NovelRepository {
  @override
  Future<String> createCategory({required String name}) async => 'default';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<NovelShelfCategory>> getCategories() async {
    return <NovelShelfCategory>[
      NovelShelfCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<NovelItem?> getDetail({required String novelId}) async => null;

  @override
  Future<NovelChapterContent?> getChapterContent({
    required String episodeId,
  }) async => null;

  @override
  Future<List<NovelEpisodeItem>> getEpisodes({
    required String novelId,
    bool descending = false,
  }) async {
    return const <NovelEpisodeItem>[];
  }

  @override
  Future<List<NovelItem>> getShelfItems({String categoryId = 'default'}) async {
    return const <NovelItem>[];
  }

  @override
  Future<void> moveNovelToCategory({
    required String novelId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<NovelReadingProgress?> getReadingProgress({
    required String novelId,
  }) async => null;

  @override
  Future<void> removeFromShelf({required String novelId}) async {}

  @override
  Future<void> purgeWork({required String novelId}) async {}

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> saveReadingProgress({
    required String novelId,
    required String episodeId,
    required double scrollOffset,
    NovelReaderFlowMode flowMode = NovelReaderFlowMode.vertical,
    int pageIndex = 0,
    int? pageCount,
    String? anchorNodeId,
    int anchorTextOffset = 0,
    int anchorFormatVersion = 0,
    String? anchorTextIdentity,
    bool? isProgressPercentValid,
    String? paginationKey,
    double progressPercent = 0,
  }) async {}

  @override
  Future<void> addReaderBookmark({
    required NovelReaderBookmark bookmark,
  }) async {}

  @override
  Future<List<NovelReaderBookmark>> listReaderBookmarks({
    required String novelId,
  }) async {
    return const <NovelReaderBookmark>[];
  }

  @override
  Future<void> removeReaderBookmark({required String bookmarkId}) async {}

  @override
  Future<void> toggleEpisodeBookmark({
    required String novelId,
    required String episodeId,
    required bool isBookmarked,
  }) async {}
}

class _FakeFavoriteSyncService implements FavoriteSyncService {
  final _progress = ValueNotifier<FavoriteSyncProgress>(
    FavoriteSyncProgress.idle,
  );

  @override
  ValueListenable<FavoriteSyncProgress> get progress => _progress;

  @override
  Future<void> runBackgroundMaintenance() async {}

  @override
  Future<FavoriteSyncResult> sync() async {
    return const FavoriteSyncResult(
      mode: FavoriteSyncMode.incremental,
      remoteCount: 1,
      fetchedPages: 1,
      upsertedCount: 0,
      removedRecords: <FavoriteThreadCacheRecord>[],
      detailLoadedCount: 0,
      failedDetailTids: <String>[],
    );
  }

  @override
  Future<FavoriteSyncResult> syncRecentlyAddedThread({required String tid}) {
    return sync();
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionInfo>> login({
    required String username,
    required String password,
    String questionId = '0',
    String answer = '',
  }) async {
    return const ApiFailure(
      ApiError(type: ApiErrorType.business, message: 'not implemented'),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<ApiResult<SessionInfo>> refreshSession() async {
    return const ApiSuccess(
      SessionInfo(
        uid: '0',
        username: '',
        formhash: 'fh_guest',
        isLoggedIn: false,
      ),
    );
  }

  @override
  Future<ApiResult<bool>> verifyAuthByForumIndex() async {
    return const ApiSuccess(false);
  }
}

class _FakeLocalFavoriteRepository implements LocalFavoriteRepository {
  @override
  Future<void> markThreadDetailPending({required String tid}) async {}

  final _category = LibraryCategory(
    categoryId: favoriteDefaultCategoryId,
    name: '默认',
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );

  final _item = LibraryWorkItem(
    workId: FavoriteShelfWorkId.fromTid('100'),
    categoryId: favoriteDefaultCategoryId,
    title: '收藏帖',
    secondaryName: '作者A',
    unreadCount: 0,
    totalChapterCount: 1,
    readChapterCount: 0,
    addedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<int> countActiveThreads() async => 1;

  @override
  Future<int> countMissingDetailRecords() async => 0;

  @override
  Future<String> createCategory({required String name}) async => 'fav-custom';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<void> finishSync({
    required FavoriteSyncMode mode,
    required int remoteCount,
    String? status,
    String? message,
  }) async {}

  @override
  Future<Set<String>> getActiveTids() async => const <String>{'100'};

  @override
  Future<List<FavoriteThreadCacheRecord>> getActiveThreadsForSnapshot() async =>
      const <FavoriteThreadCacheRecord>[];

  @override
  Future<bool> hasCompletedComicAutoRefreshBackfill() async => true;

  @override
  Future<void> markComicAutoRefreshBackfillCompleted({
    required int checkedCount,
    String? message,
  }) async {}

  @override
  Future<FavoriteThreadCacheRecord?> getActiveThreadByTid(String tid) async =>
      null;

  @override
  Future<List<FavoriteThreadCacheRecord>> getActiveThreadsByWorkId(
    String workId,
  ) async => const <FavoriteThreadCacheRecord>[];

  @override
  Future<bool> hasActiveThreadForWorkId(String workId) async => false;

  @override
  Future<int> markRemovedByWorkId(String workId) async => 0;

  @override
  Future<int> markRemovedByTids(Set<String> tids) async => 0;

  @override
  Future<List<FavoriteThreadCacheRecord>> getMissingDetailRecords({
    int limit = 20,
    Set<String> excludedTids = const <String>{},
  }) async {
    return const <FavoriteThreadCacheRecord>[];
  }

  @override
  Future<List<FavoriteThreadCacheRecord>>
  getComicAutoRefreshBackfillCandidates({
    int limit = 20,
    Set<String> excludedTids = const <String>{},
  }) async {
    return const <FavoriteThreadCacheRecord>[];
  }

  @override
  Future<FavoriteRouteTarget?> getRouteTargetByShelfWorkId(
    String workId,
  ) async {
    return const FavoriteRouteTarget(
      tid: '100',
      title: '收藏帖',
      contentKind: ThreadContentKind.forum,
      workId: 'thread:100',
    );
  }

  @override
  Future<FavoriteSyncSnapshot?> getSyncSnapshot() async {
    return FavoriteSyncSnapshot(
      syncKey: favoriteSyncKey,
      remoteCount: 1,
      localActiveCount: 1,
      lastSyncedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems(String categoryId) async {
    return <LibraryWorkItem>[_item];
  }

  @override
  Future<List<LibraryCategory>> loadVisibleCategories() async {
    return <LibraryCategory>[_category];
  }

  @override
  Future<void> markSyncFailure(String message) async {}

  @override
  Future<List<FavoriteThreadCacheRecord>> markRemovedTids(
    Set<String> activeRemoteTids,
  ) async {
    return const <FavoriteThreadCacheRecord>[];
  }

  @override
  Future<void> moveThreadToCategory({
    required String tid,
    required String toCategoryId,
  }) async {}

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async =>
      _item.workId;

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    return <String, List<LibraryWorkItem>>{
      for (final category in categories)
        category.categoryId: <LibraryWorkItem>[_item],
    };
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<void> updateThreadDetailMeta({
    required String tid,
    required String fid,
    required String typeid,
    required String? tagName,
    required ThreadContentKind contentKind,
    required String? workId,
  }) async {}

  @override
  Future<void> markThreadDetailInvalid({required String tid}) async {}

  @override
  Future<int> upsertRemoteThreads(
    List<FavoriteThreadCacheUpsert> items,
  ) async => 0;
}

class _FakeLibraryStateRepository implements LibraryStateRepository {
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
  }) async {
    return 0;
  }

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
  Future<int> countReadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return 0;
  }

  @override
  Future<int> countUnreadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return 0;
  }

  @override
  Future<String> createTag({required String name}) async => 'tag-1';

  @override
  Future<void> deleteTag({required String tagId}) async {}

  @override
  Future<LibraryModuleDisplaySettings> getDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode defaultDisplayMode,
  }) async {
    return LibraryModuleDisplaySettings(
      moduleKey: moduleKey,
      displayMode: defaultDisplayMode,
      gridColumns: 3,
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<LibraryEpisodeState?> getEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
  }) async {
    return null;
  }

  @override
  Future<List<LibraryTag>> getTags() async => const [];

  @override
  Future<LibraryWorkState?> getWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return null;
  }

  @override
  Future<List<LibraryTag>> getWorkTags({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return const [];
  }

  @override
  Future<bool> hasAnyTag({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) async {
    return false;
  }

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

class _FakeForumHomeRepository implements ForumHomeRepository {
  _FakeForumHomeRepository({this.cachedEntry, this.network});
  final ForumHomeCacheEntry? cachedEntry;
  final Future<ForumHomeReadResult>? network;
  int cacheReads = 0;
  @override
  Future<ForumHomeCacheEntry?> readCachedPayload({
    required DocumentRequestProfile requestProfile,
  }) async {
    cacheReads++;
    return cachedEntry;
  }

  @override
  Future<ForumHomeReadResult> getForumHomePayload({
    CacheLoadPolicy cachePolicy = CacheLoadPolicy.cacheFirst,
    DocumentRequestProfile? requestProfileOverride,
  }) async =>
      network ??
      forumHomeReadSuccess(
        ForumHomePayload(
          directory: const ForumDirectoryData(sections: []),
          isLoggedIn: false,
          favoriteForums: [],
        ),
      );
}
