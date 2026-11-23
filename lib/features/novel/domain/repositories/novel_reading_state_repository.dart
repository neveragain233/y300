import 'package:y300/features/library_shared/domain/models/library_state_models.dart';

import '../models/novel_reading_progress.dart';

class NovelReadingStateSnapshot {
  NovelReadingStateSnapshot({
    required this.novelId,
    required Map<String, NovelReadingProgress> progressByEpisode,
    required Map<String, LibraryEpisodeState> episodeStates,
    this.recentEpisodeId,
  }) : progressByEpisode = Map.unmodifiable(progressByEpisode),
       episodeStates = Map.unmodifiable(episodeStates);

  final String novelId;
  final Map<String, NovelReadingProgress> progressByEpisode;
  final Map<String, LibraryEpisodeState> episodeStates;
  final String? recentEpisodeId;
  NovelReadingProgress? get recentProgress =>
      progressByEpisode[recentEpisodeId];
}

/// One atomic boundary for chapter positions, recent chapter and completion.
/// A producer guard is checked inside the transaction, including before commit.
abstract interface class NovelReadingStateRepository {
  Future<NovelReadingStateSnapshot> loadWorkState({required String novelId});
  Future<NovelReadingProgress?> getChapterProgress({
    required String novelId,
    required String episodeId,
  });
  Future<bool> commitProgress({
    required NovelReadingProgress progress,
    bool markCompleted = false,
    bool Function()? canCommit,
  });
  Future<bool> setChapterRead({
    required String novelId,
    required String episodeId,
    required bool isRead,
    bool Function()? canCommit,
  });
  Future<bool> resetChapter({
    required String novelId,
    required String episodeId,
    bool Function()? canCommit,
  });

  /// 标记一组章节为已读。只改已读标记与标记时间，保留章内位置、书签、
  /// 下载和最近阅读引用。返回本次真正从未读变为已读的章节；事务被屏障
  /// 退役时返回空集合。
  Future<Set<String>> setChaptersRead({
    required String novelId,
    required Set<String> episodeIds,
    required DateTime readAt,
    bool Function()? canCommit,
  });

  /// 撤销范围标记，只清除仍保留 [readAt] 标记时间的已读状态。
  Future<void> restoreChaptersRead({
    required String novelId,
    required Set<String> episodeIds,
    required DateTime readAt,
    bool Function()? canCommit,
  });
}

/// 跨作品读取最近一次小说阅读进度，只返回作品与章节仍有效的一条。
class NovelRecentReading {
  const NovelRecentReading({
    required this.novelId,
    required this.episodeId,
    required this.readAt,
  });

  final String novelId;
  final String episodeId;
  final DateTime readAt;
}

abstract interface class NovelRecentReadingQuery {
  Future<NovelRecentReading?> getMostRecentReading();
}

/// 仅更新作品级最近阅读记录（不改动章内位置锚点或已读状态）。
abstract interface class NovelRecentReadingTouchRepository {
  Future<bool> touchRecentReading({
    required String novelId,
    required String episodeId,
    DateTime? readAt,
    bool Function()? canCommit,
  });
}

/// Optional whole-work mutation. Clears public positions, the recent chapter
/// and current completion evidence atomically while preserving bookmarks.
abstract interface class NovelWorkReadingResetRepository {
  Future<bool> resetWorkReadingState({
    required String novelId,
    bool Function()? canCommit,
  });
}
