import 'package:y300/features/library_shared/domain/models/library_models.dart';

/// 最近一次实际阅读停留的作品与章节。
class RecentReadingTarget {
  const RecentReadingTarget({
    required this.moduleKey,
    required this.workId,
    required this.episodeId,
    required this.readAt,
  });

  final LibraryModuleKey moduleKey;
  final String workId;
  final String episodeId;
  final DateTime readAt;
}

/// 单模块的最近阅读查询；实现只读取进度表最新一条并校验作品与章节仍存在。
abstract interface class RecentReadingSource {
  Future<RecentReadingTarget?> loadMostRecentReading();
}

/// 组合漫画与小说的最近阅读，按更新时间选择唯一目标。
class RecentReadingResolver {
  RecentReadingResolver({required Iterable<RecentReadingSource> sources})
    : _sources = List<RecentReadingSource>.unmodifiable(sources);

  final List<RecentReadingSource> _sources;

  Future<RecentReadingTarget?> resolve() async {
    final results = await Future.wait(
      _sources.map((source) => source.loadMostRecentReading()),
    );
    RecentReadingTarget? latest;
    for (final candidate in results) {
      if (candidate == null) {
        continue;
      }
      if (latest == null || _isLater(candidate, latest)) {
        latest = candidate;
      }
    }
    return latest;
  }

  bool _isLater(RecentReadingTarget candidate, RecentReadingTarget current) {
    final compared = candidate.readAt.compareTo(current.readAt);
    if (compared != 0) {
      return compared > 0;
    }
    final moduleCompared = candidate.moduleKey.name.compareTo(
      current.moduleKey.name,
    );
    if (moduleCompared != 0) {
      return moduleCompared < 0;
    }
    return candidate.workId.compareTo(current.workId) < 0;
  }
}
