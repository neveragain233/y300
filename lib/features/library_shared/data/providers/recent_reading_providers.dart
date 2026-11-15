import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/services/recent_reading.dart';
import 'package:y300/features/novel/data/providers/novel_providers.dart';
import 'package:y300/features/novel/domain/repositories/novel_reading_state_repository.dart';

/// 组合漫画与小说的逐章进度，得到最近实际阅读目标。
final recentReadingResolverProvider = Provider<RecentReadingResolver>((ref) {
  return RecentReadingResolver(
    sources: <RecentReadingSource>[
      _ComicRecentReadingSource(ref.watch(comicRepositoryProvider)),
      _NovelRecentReadingSource(ref.watch(novelRepositoryProvider)),
    ],
  );
});

class _ComicRecentReadingSource implements RecentReadingSource {
  _ComicRecentReadingSource(this._repository);

  final Object _repository;

  @override
  Future<RecentReadingTarget?> loadMostRecentReading() async {
    final repository = _repository;
    if (repository is! ComicRecentReadingQuery) {
      return null;
    }
    final progress = await repository.getMostRecentReadingProgress();
    if (progress == null) {
      return null;
    }
    return RecentReadingTarget(
      moduleKey: LibraryModuleKey.comic,
      workId: progress.comicId,
      episodeId: progress.episodeId,
      readAt: progress.updatedAt,
    );
  }
}

class _NovelRecentReadingSource implements RecentReadingSource {
  _NovelRecentReadingSource(this._repository);

  final Object _repository;

  @override
  Future<RecentReadingTarget?> loadMostRecentReading() async {
    final repository = _repository;
    if (repository is! NovelRecentReadingQuery) {
      return null;
    }
    final progress = await repository.getMostRecentReading();
    if (progress == null) {
      return null;
    }
    return RecentReadingTarget(
      moduleKey: LibraryModuleKey.novel,
      workId: progress.novelId,
      episodeId: progress.episodeId,
      readAt: progress.readAt,
    );
  }
}
