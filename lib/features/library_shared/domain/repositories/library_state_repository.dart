import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_state_models.dart';

/// 统一状态仓储抽象。
///
/// 该仓储独立于 comic/novel 主仓储，避免“业务数据”和“跨模块状态”强耦合。
abstract class LibraryStateRepository {
  Future<void> upsertWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
    String? lastReadEpisodeId,
    DateTime? lastReadAt,
    DateTime? checkUpdatedAt,
    DateTime? fetchedUpdatedAt,
    String? introText,
  });

  Future<LibraryWorkState?> getWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  });

  Future<void> upsertEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
    required String workId,
    bool? isRead,
    bool? isDownloaded,
    bool? isBookmarked,
    DateTime? readAt,
    DateTime? downloadedAt,
  });

  Future<LibraryEpisodeState?> getEpisodeState({
    required LibraryModuleKey moduleKey,
    required String episodeId,
  });

  Future<int> countUnreadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  });

  Future<int> countReadEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  });

  Future<int> countDownloadedEpisodes({
    required LibraryModuleKey moduleKey,
    required String workId,
  });

  /// 批量写入一个或多个作品下全部章节的已读状态。
  ///
  /// 该接口面向持久化层，要求以集合式 upsert 保证“原本没有状态行的章节”
  /// 也能在一次事务内写入到统一状态表。
  Future<void> setWorksReadState({
    required LibraryModuleKey moduleKey,
    required Set<String> workIds,
    required bool isRead,
    DateTime? readAt,
  }) {
    throw UnimplementedError(
      'setWorksReadState($moduleKey, $workIds, $isRead)',
    );
  }

  /// 删除一个作品在 shared 状态表里的全部状态和标签绑定。
  Future<void> purgeWorkState({
    required LibraryModuleKey moduleKey,
    required String workId,
  }) {
    throw UnimplementedError('purgeWorkState($moduleKey, $workId)');
  }

  Future<void> upsertDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode displayMode,
    required int gridColumns,
  });

  Future<LibraryModuleDisplaySettings> getDisplaySettings({
    required LibraryModuleKey moduleKey,
    required LibraryDisplayMode defaultDisplayMode,
  });

  Future<String> createTag({required String name});

  Future<List<LibraryTag>> getTags();

  Future<void> renameTag({required String tagId, required String newName});

  Future<void> deleteTag({required String tagId});

  Future<void> bindTagToWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  });

  Future<void> unbindTagFromWork({
    required LibraryModuleKey moduleKey,
    required String workId,
    required String tagId,
  });

  Future<List<LibraryTag>> getWorkTags({
    required LibraryModuleKey moduleKey,
    required String workId,
  });

  Future<bool> hasAnyTag({
    required LibraryModuleKey moduleKey,
    required String workId,
  });
}

/// 可选能力：按章节集合写入一个作品的已读状态。
///
/// 具体模块仓储实现该合同；共享详情页据此提供“已读到此”。
abstract interface class LibraryEpisodeRangeReadStateRepository {
  /// 批量写入一个作品内指定章节的已读状态。
  ///
  /// 以集合式 upsert 在一次事务内覆盖原本没有状态行的章节，只改已读标记
  /// 与标记时间。返回本次真正改变已读状态的章节编号，供撤销使用。
  Future<List<String>> setEpisodesReadState({
    required LibraryModuleKey moduleKey,
    required String workId,
    required Set<String> episodeIds,
    required bool isRead,
    DateTime? readAt,
  });

  /// 撤销一次范围标记：只清除仍保留 [readAt] 标记时间的已读章节。
  Future<void> restoreEpisodesReadState({
    required LibraryModuleKey moduleKey,
    required String workId,
    required Set<String> episodeIds,
    required DateTime readAt,
  });
}

/// Optional aggregate query used by shelf adapters that expose work-level
/// chapter bookmark filtering.
abstract interface class LibraryBookmarkStateQuery {
  Future<bool> hasAnyBookmarkedEpisode({
    required LibraryModuleKey moduleKey,
    required String workId,
  });
}
