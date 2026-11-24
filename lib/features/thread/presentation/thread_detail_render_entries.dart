import 'package:flutter/foundation.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/thread/domain/models/thread_post_target.dart';
import 'package:y300/features/thread/presentation/thread_detail_content_projection.dart';

import 'thread_detail_prepared_body.dart';

/// Builds stable visual entries without parsing or caching post bodies.
@immutable
class ThreadDetailRenderEntryPlanner {
  const ThreadDetailRenderEntryPlanner();

  List<ThreadDetailRenderEntry> buildEntries({
    required List<ThreadPost> posts,
    String? targetPid,
    ThreadPostLanding landing = ThreadPostLanding.top,
    Map<String, ThreadDetailBodyManifest> bodyManifests = const {},
    bool Function(ThreadPost sourcePost)? isCollapsed,
  }) {
    return buildProjectionEntries(
      posts: [
        for (final post in posts)
          ThreadDetailPostProjection(sourcePost: post, displayPost: post),
      ],
      targetPid: targetPid,
      landing: landing,
      bodyManifests: bodyManifests,
      isCollapsed: isCollapsed,
    );
  }

  List<ThreadDetailRenderEntry> buildProjectionEntries({
    required List<ThreadDetailPostProjection> posts,
    String? targetPid,
    ThreadPostLanding landing = ThreadPostLanding.top,
    Map<String, ThreadDetailBodyManifest> bodyManifests = const {},
    bool Function(ThreadPost sourcePost)? isCollapsed,
    List<ThreadDetailPostProjection> tailPosts = const [],
    bool showFilteredTailHeader = false,
    bool filteredTailExpanded = false,
  }) {
    final entries = <ThreadDetailRenderEntry>[];
    final normalizedTargetPid = targetPid?.trim();
    for (var index = 0; index < posts.length; index++) {
      final post = posts[index];
      if (index > 0 && posts[index - 1].sourcePost.isFirst) {
        entries.add(const ThreadDetailRenderEntry.repliesHeader());
      }
      _appendPostEntries(
        entries: entries,
        post: post,
        postIndex: index,
        normalizedTargetPid: normalizedTargetPid,
        landing: landing,
        bodyManifests: bodyManifests,
        isCollapsed: isCollapsed,
      );
    }
    // 首楼不在本页时（分页或过滤），回复区从顶部开始，切换入口随之置顶。
    if ((posts.isNotEmpty ||
            (showFilteredTailHeader && tailPosts.isNotEmpty)) &&
        !posts.any((post) => post.sourcePost.isFirst)) {
      entries.insert(0, const ThreadDetailRenderEntry.repliesHeader());
    }
    // 无回复或筛选后只有首楼时，仍在首楼末尾保留切换入口。
    if (posts.isNotEmpty && posts.last.sourcePost.isFirst) {
      entries.add(const ThreadDetailRenderEntry.repliesHeader());
    }
    if (showFilteredTailHeader) {
      entries.add(const ThreadDetailRenderEntry.filteredTailHeader());
      if (filteredTailExpanded) {
        for (var tailIndex = 0; tailIndex < tailPosts.length; tailIndex++) {
          _appendPostEntries(
            entries: entries,
            post: tailPosts[tailIndex],
            postIndex: posts.length + tailIndex,
            normalizedTargetPid: normalizedTargetPid,
            landing: landing,
            bodyManifests: bodyManifests,
            isCollapsed: isCollapsed,
          );
        }
      }
    }
    entries.add(const ThreadDetailRenderEntry.pagination());
    if (normalizedTargetPid?.isNotEmpty == true) {
      entries.add(const ThreadDetailRenderEntry.targetSpacer());
    }
    return List<ThreadDetailRenderEntry>.unmodifiable(entries);
  }

  void _appendPostEntries({
    required List<ThreadDetailRenderEntry> entries,
    required ThreadDetailPostProjection post,
    required int postIndex,
    required String? normalizedTargetPid,
    required ThreadPostLanding landing,
    required Map<String, ThreadDetailBodyManifest> bodyManifests,
    required bool Function(ThreadPost sourcePost)? isCollapsed,
  }) {
    if (isCollapsed?.call(post.sourcePost) ?? false) {
      entries.add(
        ThreadDetailRenderEntry.blacklistedPost(
          key: 'thread-post-blacklisted-entry-${post.sourcePost.pid}',
          sourcePost: post.sourcePost,
          displayPost: post.displayPost,
          postIndex: postIndex,
        ),
      );
      return;
    }
    final manifest = bodyManifests[post.sourcePost.pid];
    if (manifest != null ||
        landing == ThreadPostLanding.bodyEnd &&
            post.sourcePost.pid == normalizedTargetPid) {
      final pid = post.sourcePost.pid;
      entries.addAll([
        ThreadDetailRenderEntry.postHeader(
          key: 'thread-post-header-entry-$pid',
          sourcePost: post.sourcePost,
          displayPost: post.displayPost,
          postIndex: postIndex,
        ),
        if (manifest == null)
          ThreadDetailRenderEntry.postBody(
            key: 'thread-post-body-entry-$pid',
            sourcePost: post.sourcePost,
            displayPost: post.displayPost,
            postIndex: postIndex,
          )
        else
          for (final chunk in manifest.chunks)
            ThreadDetailRenderEntry.postBodyChunk(
              key: 'thread-post-body-chunk-$pid-${chunk.ordinal}',
              sourcePost: post.sourcePost,
              displayPost: post.displayPost,
              postIndex: postIndex,
              bodyManifest: manifest,
              chunkOrdinal: chunk.ordinal,
            ),
        ThreadDetailRenderEntry.postFooter(
          key: 'thread-post-footer-entry-$pid',
          sourcePost: post.sourcePost,
          displayPost: post.displayPost,
          postIndex: postIndex,
        ),
      ]);
      return;
    }
    entries.add(
      ThreadDetailRenderEntry.postCard(
        key: 'thread-post-card-entry-${post.sourcePost.pid}',
        sourcePost: post.sourcePost,
        displayPost: post.displayPost,
        postIndex: postIndex,
      ),
    );
  }
}

enum ThreadDetailRenderEntryKind {
  repliesHeader,
  postCard,
  postHeader,
  postBody,
  postBodyChunk,
  postFooter,
  blacklistedPost,
  filteredTailHeader,
  pagination,
  targetSpacer,
}

@immutable
class ThreadDetailRenderEntry {
  const ThreadDetailRenderEntry._({
    required this.kind,
    required this.key,
    this.sourcePost,
    this.displayPost,
    required this.postIndex,
    this.bodyManifest,
    this.chunkOrdinal,
  });

  const ThreadDetailRenderEntry.repliesHeader()
    : this._(
        kind: ThreadDetailRenderEntryKind.repliesHeader,
        key: 'thread-replies-header-entry',
        postIndex: -1,
      );

  const ThreadDetailRenderEntry.postCard({
    required String key,
    required ThreadPost sourcePost,
    required ThreadPost displayPost,
    required int postIndex,
  }) : this._(
         kind: ThreadDetailRenderEntryKind.postCard,
         key: key,
         sourcePost: sourcePost,
         displayPost: displayPost,
         postIndex: postIndex,
       );

  const ThreadDetailRenderEntry.postHeader({
    required String key,
    required ThreadPost sourcePost,
    required ThreadPost displayPost,
    required int postIndex,
  }) : this._(
         kind: ThreadDetailRenderEntryKind.postHeader,
         key: key,
         sourcePost: sourcePost,
         displayPost: displayPost,
         postIndex: postIndex,
       );

  const ThreadDetailRenderEntry.postBody({
    required String key,
    required ThreadPost sourcePost,
    required ThreadPost displayPost,
    required int postIndex,
  }) : this._(
         kind: ThreadDetailRenderEntryKind.postBody,
         key: key,
         sourcePost: sourcePost,
         displayPost: displayPost,
         postIndex: postIndex,
       );

  const ThreadDetailRenderEntry.postFooter({
    required String key,
    required ThreadPost sourcePost,
    required ThreadPost displayPost,
    required int postIndex,
  }) : this._(
         kind: ThreadDetailRenderEntryKind.postFooter,
         key: key,
         sourcePost: sourcePost,
         displayPost: displayPost,
         postIndex: postIndex,
       );

  const ThreadDetailRenderEntry.postBodyChunk({
    required String key,
    required ThreadPost sourcePost,
    required ThreadPost displayPost,
    required int postIndex,
    required ThreadDetailBodyManifest bodyManifest,
    required int chunkOrdinal,
  }) : this._(
         kind: ThreadDetailRenderEntryKind.postBodyChunk,
         key: key,
         sourcePost: sourcePost,
         displayPost: displayPost,
         postIndex: postIndex,
         bodyManifest: bodyManifest,
         chunkOrdinal: chunkOrdinal,
       );

  const ThreadDetailRenderEntry.blacklistedPost({
    required String key,
    required ThreadPost sourcePost,
    required ThreadPost displayPost,
    required int postIndex,
  }) : this._(
         kind: ThreadDetailRenderEntryKind.blacklistedPost,
         key: key,
         sourcePost: sourcePost,
         displayPost: displayPost,
         postIndex: postIndex,
       );

  const ThreadDetailRenderEntry.filteredTailHeader()
    : this._(
        kind: ThreadDetailRenderEntryKind.filteredTailHeader,
        key: 'thread-filtered-tail-header',
        postIndex: -1,
      );

  const ThreadDetailRenderEntry.pagination()
    : this._(
        kind: ThreadDetailRenderEntryKind.pagination,
        key: 'thread-detail-pagination',
        postIndex: -1,
      );

  const ThreadDetailRenderEntry.targetSpacer()
    : this._(
        kind: ThreadDetailRenderEntryKind.targetSpacer,
        key: 'thread-detail-target-scroll-spacer',
        postIndex: -1,
      );

  final ThreadDetailRenderEntryKind kind;
  final String key;
  final ThreadPost? sourcePost;
  final ThreadPost? displayPost;
  final int postIndex;
  final ThreadDetailBodyManifest? bodyManifest;
  final int? chunkOrdinal;
}
