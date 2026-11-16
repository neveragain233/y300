import 'package:y300/features/novel/domain/models/novel_thread_models.dart';
import 'package:y300/features/thread/domain/services/forum_post_image_source_collector.dart';

/// 读取小说首楼图片作为封面候选。
///
/// 复用来源元数据恢复网关的 `version=4` 首页读取；章节正文仍由
/// `threadAuthorPosts` 的 `version=1` 负责，两者保持各自既有职责。
class NovelFirstPostCoverCandidates {
  const NovelFirstPostCoverCandidates({
    required NovelSourceMetadataRecoveryGateway gateway,
    ForumPostImageSourceCollector imageSourceCollector =
        const ForumPostImageSourceCollector(),
  }) : _gateway = gateway,
       _imageSourceCollector = imageSourceCollector;

  final NovelSourceMetadataRecoveryGateway _gateway;
  final ForumPostImageSourceCollector _imageSourceCollector;

  Future<List<String>> load({required String tid}) async {
    final normalized = tid.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final detail = await _gateway.loadFirstPage(tid: normalized);
    if (detail.posts.isEmpty) {
      return const <String>[];
    }
    return _imageSourceCollector.collect(detail.posts.first);
  }
}
