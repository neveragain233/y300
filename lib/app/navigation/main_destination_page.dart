import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/navigation/history_entry_router.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/message_routes.dart';
import 'package:y300/app/startup/main_shell_library_gate.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/comic/presentation/comic_tab_page.dart';
import 'package:y300/features/favorites/presentation/favorite_shelf_page.dart';
import 'package:y300/features/forum/presentation/forum_shell_page.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_controller.dart';
import 'package:y300/features/history/presentation/history_page.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_bottom_bar.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/novel/presentation/novel_tab_page.dart';
import 'package:y300/features/profile/presentation/profile_blog_page.dart';

typedef MainDestinationRouteFactory = Route<void> Function(
  MainShellDestination destination,
);

/// Opening a destination does not change navigation visibility or tab state.
final mainDestinationRouteFactoryProvider =
    Provider<MainDestinationRouteFactory>((ref) {
      final libraryReady = ref.watch(mainShellLibraryReadinessProvider);
      return (destination) {
        if (!destination.isManaged) {
          throw ArgumentError.value(destination, 'destination');
        }
        return MaterialPageRoute<void>(
          builder: (_) => ProviderScope(
            overrides: [
              mainShellLibraryReadinessProvider.overrideWithValue(libraryReady),
              // A pushed shelf must not take over the selection owner of the shell
              // underneath it. Both the shelf and its action bar use this scope.
              shelfSelectionHostControllerProvider.overrideWith((ref) {
                final controller = ShelfSelectionHostController();
                ref.onDispose(controller.dispose);
                return controller;
              }),
              forumWebViewPopOnRootBackProvider.overrideWithValue(true),
            ],
            child: switch (destination) {
              MainShellDestination.favorites ||
              MainShellDestination.comic ||
              MainShellDestination.novel => Scaffold(
                body: MainDestinationPage(destination: destination),
                bottomNavigationBar: const ShelfSelectionBottomBar(),
              ),
              _ => MainDestinationPage(destination: destination),
            },
          ),
        );
      };
    }, dependencies: [mainShellLibraryReadinessProvider]);

/// The same feature pages serve both the lazy main shell and standalone routes.
class MainDestinationPage extends ConsumerWidget {
  const MainDestinationPage({
    super.key,
    required this.destination,
    this.isActive = true,
    this.browserController,
    this.globalOrigin = Offset.zero,
  });

  final MainShellDestination destination;
  final bool isActive;
  final AdaptiveDetailController? browserController;
  final Offset globalOrigin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = switch (destination) {
      MainShellDestination.forum => ForumShellPage(
        isActive: isActive,
        browserController: browserController,
        globalOrigin: globalOrigin,
      ),
      MainShellDestination.favorites => MainShellLibraryGate(
        child: FavoriteShelfPage(isActive: isActive),
      ),
      MainShellDestination.comic => MainShellLibraryGate(
        child: ComicTabPage(isActive: isActive),
      ),
      MainShellDestination.novel => MainShellLibraryGate(
        child: NovelTabPage(isActive: isActive),
      ),
      MainShellDestination.blogs => ProfileBlogPage(isActive: isActive),
      MainShellDestination.history => HistoryPage(
        onOpenEntry: ref.read(historyEntryRouterProvider).open,
        imageReferer: ref.watch(forumImageRefererProvider),
      ),
      MainShellDestination.messages => MessageCenterDestination(
        isActive: isActive,
      ),
      MainShellDestination.more => throw ArgumentError.value(
        destination,
        'destination',
      ),
    };
    final needsDetailHost = switch (destination) {
      MainShellDestination.favorites ||
      MainShellDestination.comic ||
      MainShellDestination.novel ||
      MainShellDestination.history => true,
      _ => false,
    };
    // 已在外层宿主内（从论坛根页推入的记录等）时复用外层宿主，详情才能
    // 驱动主壳隐藏底栏；独立推入根导航栈的页面仍自带宿主。
    if (!needsDetailHost || hasAdaptiveDetailHost(context)) return page;
    return AdaptiveDetailHost(
      controller: browserController,
      isActive: isActive,
      globalOrigin: globalOrigin,
      child: page,
    );
  }
}
