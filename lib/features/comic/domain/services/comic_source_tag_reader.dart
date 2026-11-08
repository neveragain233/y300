import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/comic/domain/models/comic_detail_models.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';

/// One topic tag of a comic's source thread.
final class ComicSourceTag {
  const ComicSourceTag({required this.label, required this.tagId});

  final String label;
  final String tagId;
}

/// Reads a comic's source-thread identity and topic tags without depending on
/// image parsing, so failure and empty-image states can still offer the entry.
abstract interface class ComicSourceTagReader {
  Future<String?> resolveSourceTid({
    required String comicId,
    String? episodeId,
  });

  Future<List<ComicSourceTag>> readSourceTags({
    required String comicId,
    String? episodeId,
  });
}

final class DefaultComicSourceTagReader implements ComicSourceTagReader {
  const DefaultComicSourceTagReader({
    required ComicRepository repository,
    required ThreadRepository threadRepository,
  }) : _repository = repository,
       _threadRepository = threadRepository;

  final ComicRepository _repository;
  final ThreadRepository _threadRepository;

  @override
  Future<String?> resolveSourceTid({
    required String comicId,
    String? episodeId,
  }) async {
    ComicDetail? detail;
    try {
      detail = await _repository.getComicDetail(comicId: comicId);
    } catch (_) {
      detail = null;
    }
    final workTid = detail?.sourceTid.trim() ?? '';
    if (workTid.isNotEmpty) {
      return workTid;
    }
    // Fall back to an existing chapter when the work row has no source id.
    try {
      final episodes = await _repository.getComicEpisodes(comicId: comicId);
      final preferred = episodeId?.trim();
      if (preferred != null && preferred.isNotEmpty) {
        for (final episode in episodes) {
          if (episode.episodeId == preferred) {
            final tid = episode.sourceTid.trim();
            if (tid.isNotEmpty) {
              return tid;
            }
          }
        }
      }
      for (final episode in episodes) {
        final tid = episode.sourceTid.trim();
        if (tid.isNotEmpty) {
          return tid;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Future<List<ComicSourceTag>> readSourceTags({
    required String comicId,
    String? episodeId,
  }) async {
    final tid = await resolveSourceTid(comicId: comicId, episodeId: episodeId);
    if (tid == null) {
      return const <ComicSourceTag>[];
    }
    final DataReadResult<ThreadDetailData, ThreadDetailReadCapabilities> result;
    try {
      result = await _threadRepository.getThreadDetail(tid: tid);
    } catch (_) {
      return const <ComicSourceTag>[];
    }
    if (result
        is! DataReadSuccess<ThreadDetailData, ThreadDetailReadCapabilities>) {
      return const <ComicSourceTag>[];
    }
    ThreadPost? firstPost;
    for (final post in result.data.posts) {
      if (post.isFirst) {
        firstPost = post;
        break;
      }
    }
    firstPost ??= result.data.posts.isEmpty ? null : result.data.posts.first;
    if (firstPost == null) {
      return const <ComicSourceTag>[];
    }
    final tags = <ComicSourceTag>[];
    final seen = <String>{};
    for (final tag in firstPost.tagLinks) {
      final tagId = tag.tagId?.trim() ?? '';
      if (tagId.isEmpty || !seen.add(tagId)) {
        continue;
      }
      final label = tag.label.trim();
      tags.add(ComicSourceTag(label: label.isEmpty ? tagId : label, tagId: tagId));
    }
    return List<ComicSourceTag>.unmodifiable(tags);
  }
}
