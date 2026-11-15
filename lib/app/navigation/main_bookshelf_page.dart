import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/data/use_cases/bulk_download_use_case_providers.dart';
import 'package:y300/features/comic/domain/services/comic_episode_sequence.dart';
import 'package:y300/features/comic/presentation/adapters/comic_shelf_adapter.dart';
import 'package:y300/features/comic/presentation/comic_detail_page.dart';
import 'package:y300/features/comic/presentation/comic_reader_page.dart';
import 'package:y300/features/favorites/data/use_cases/unfavorite_use_case_providers.dart';
import 'package:y300/features/library_shared/data/providers/library_state_providers.dart';
import 'package:y300/features/library_shared/data/providers/library_task_workflow_providers.dart';
import 'package:y300/features/library_shared/data/providers/library_view_preferences_providers.dart';
import 'package:y300/features/library_shared/data/providers/recent_reading_providers.dart';
import 'package:y300/features/library_shared/domain/contracts/library_view_preferences_repository.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/library_shared/domain/services/recent_reading.dart';
import 'package:y300/features/library_shared/presentation/adapters/mixed_shelf_adapter.dart';
import 'package:y300/features/library_shared/presentation/pages/unified_shelf_page.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/library_shared/presentation/services/recent_reading_action.dart';
import 'package:y300/features/novel/data/providers/novel_providers.dart';
import 'package:y300/features/novel/presentation/adapters/novel_shelf_adapter.dart';
import 'package:y300/features/novel/domain/models/novel_episode_open_policy.dart';
import 'package:y300/features/novel/presentation/novel_detail_page.dart';
import 'package:y300/features/novel/presentation/novel_reader_page.dart';

/// 主壳书架入口的唯一页面：漫画与小说共用一份混合列表。
///
/// 适配器在页面生命周期内保持同一实例；首次打开时把原单模块书架的显示方式
/// 种子写入混合书架偏好，之后的筛选、排序与分类各自独立保存。
class MainBookshelfPage extends ConsumerStatefulWidget {
  const MainBookshelfPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<MainBookshelfPage> createState() => _MainBookshelfPageState();
}

class _MainBookshelfPageState extends ConsumerState<MainBookshelfPage> {
  late final MixedShelfAdapter _adapter;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    final taskProgressHub = ref.read(libraryTaskProgressHubWorkflowProvider);
    final refreshBus = ref.read(libraryShelfRefreshBusProvider);
    final comicAdapter = ComicShelfAdapter(
      ref.read(comicRepositoryProvider),
      stateRepository: ref.read(libraryStateRepositoryProvider),
      featureFlags: ref.read(comicReaderFeatureFlagsProvider),
      shelfRefreshBus: refreshBus,
      taskProgressHub: taskProgressHub,
      duplicateMergeService: ref.read(comicDuplicateMergeServiceProvider),
      categoryAssignUseCaseResolver: () =>
          ref.read(comicShelfCategoryAssignUseCaseProvider),
      readingStateBatchWriterResolver: () =>
          ref.read(readingStateBatchWriterProvider),
      bulkDownloadUseCaseResolver: () => ref.read(bulkDownloadUseCaseProvider),
      unfavoriteWorkUseCaseResolver: () =>
          ref.read(unfavoriteWorkUseCaseProvider),
    );
    final novelAdapter = NovelShelfAdapter(
      ref.read(novelRepositoryProvider),
      stateRepository: ref.read(libraryStateRepositoryProvider),
      shelfRefreshBus: refreshBus,
      taskProgressHub: taskProgressHub,
      categoryAssignUseCaseResolver: () =>
          ref.read(novelShelfCategoryAssignUseCaseProvider),
      unfavoriteWorkUseCaseResolver: () =>
          ref.read(unfavoriteWorkUseCaseProvider),
    );
    _adapter = MixedShelfAdapter(
      comicAdapter: comicAdapter,
      novelAdapter: novelAdapter,
    );
    _ready = _seedBookshelfPreferences();
  }

  Future<void> _seedBookshelfPreferences() async {
    final repository = ref.read(libraryViewPreferencesRepositoryProvider);
    if (repository is! LibraryViewPreferencesSeeder) {
      return;
    }
    final seeder = repository as LibraryViewPreferencesSeeder;
    final settings = ref
        .read(mainNavigationSettingsControllerProvider)
        .value
        ?.settings;
    final seedModule = _seedBookshelfModule(settings);
    if (seedModule == null) {
      return;
    }
    await seeder.seedBookshelfFrom(sourceModule: seedModule);
  }

  LibraryModuleKey? _seedBookshelfModule(MainNavigationSettings? settings) {
    if (settings == null) {
      return LibraryModuleKey.comic;
    }
    for (final destination in settings.visibleManagedDestinations) {
      if (destination == MainShellDestination.comic) {
        return LibraryModuleKey.comic;
      }
      if (destination == MainShellDestination.novel) {
        return LibraryModuleKey.novel;
      }
    }
    return null;
  }

  Future<void> _openRecentReading(
    BuildContext context,
    RecentReadingTarget target,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    switch (target.moduleKey) {
      case LibraryModuleKey.comic:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ComicReaderPage(
              comicId: target.workId,
              episodeId: target.episodeId,
              openPolicy: ComicEpisodeOpenPolicy.restoreSavedPosition,
            ),
          ),
        );
      case LibraryModuleKey.novel:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => NovelReaderPage(
              novelId: target.workId,
              initialEpisodeId: target.episodeId,
              openPolicy: NovelEpisodeOpenPolicy.restoreLastPosition,
            ),
          ),
        );
      case LibraryModuleKey.favorite:
      case LibraryModuleKey.bookshelf:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(libraryViewPreferencesRepositoryProvider);
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return UnifiedShelfPage(
          adapter: _adapter,
          viewPreferencesRepository: repository,
          imageReferer: ref.watch(forumImageRefererProvider),
          isActive: widget.isActive,
          selectionHost: ref.watch(shelfSelectionHostControllerProvider),
          recentReadingAction: RecentReadingAction(
            resolve: () => ref.read(recentReadingResolverProvider).resolve(),
            open: _openRecentReading,
          ),
          onOpenWork: (context, workId) async {
            final parsed = LibraryWorkId.tryParse(workId);
            if (parsed == null) {
              return;
            }
            switch (parsed.source) {
              case LibraryModuleKey.comic:
                await openAdaptiveDetail(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ComicDetailPage(comicId: parsed.workId),
                  ),
                );
              case LibraryModuleKey.novel:
                await openAdaptiveDetail(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NovelDetailPage(novelId: parsed.workId),
                  ),
                );
              case LibraryModuleKey.favorite:
              case LibraryModuleKey.bookshelf:
                return;
            }
          },
        );
      },
    );
  }
}
