import 'package:flutter_test/flutter_test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/novel/domain/models/novel_thread_models.dart';
import 'package:y300/features/novel/domain/services/novel_first_post_cover_candidates.dart';

void main() {
  group('NovelFirstPostCoverCandidates', () {
    test('collects only first post content images in DOM order', () async {
      final gateway = _FakeGateway(
        detail: ThreadDetailData(
          tid: '100',
          fid: '49',
          subject: '小说',
          author: '作者',
          replies: 1,
          views: 0,
          currentPage: 1,
          perPage: 20,
          posts: <ThreadPost>[
            _post(
              pid: '900',
              isFirst: true,
              message:
                  '<div class="message">'
                  '<img src="https://bbs.yamibo.com/data/attachment/forum/a.jpg">'
                  '<img src="https://bbs.yamibo.com/static/image/smiley/1.gif">'
                  '<img src="https://bbs.yamibo.com/uc_server/data/avatar/1.png">'
                  '<img src="https://bbs.yamibo.com/data/attachment/forum/b.png">'
                  '</div>',
            ),
            _post(
              pid: '901',
              message:
                  '<div class="message">'
                  '<img src="https://bbs.yamibo.com/data/attachment/forum/c.jpg">'
                  '</div>',
            ),
          ],
        ),
      );
      final service = NovelFirstPostCoverCandidates(gateway: gateway);

      final urls = await service.load(tid: '100');

      expect(urls, <String>[
        'https://bbs.yamibo.com/data/attachment/forum/a.jpg',
        'https://bbs.yamibo.com/data/attachment/forum/b.png',
      ]);
      expect(gateway.loadedTids, <String>['100']);
    });

    test('returns no candidates for a blank tid or empty thread', () async {
      final gateway = _FakeGateway(
        detail: ThreadDetailData(
          tid: '100',
          fid: '49',
          subject: '小说',
          author: '作者',
          replies: 0,
          views: 0,
          currentPage: 1,
          perPage: 20,
          posts: const <ThreadPost>[],
        ),
      );
      final service = NovelFirstPostCoverCandidates(gateway: gateway);

      expect(await service.load(tid: '  '), isEmpty);
      expect(await service.load(tid: '100'), isEmpty);
      expect(gateway.loadedTids, <String>['100']);
    });
  });
}

ThreadPost _post({
  required String pid,
  required String message,
  bool isFirst = false,
}) {
  return ThreadPost(
    pid: pid,
    author: '作者',
    authorId: '1',
    message: message,
    number: int.parse(pid) - 899,
    isFirst: isFirst,
    dateline: '2026-01-01',
  );
}

class _FakeGateway implements NovelSourceMetadataRecoveryGateway {
  _FakeGateway({required this.detail});

  final ThreadDetailData detail;
  final List<String> loadedTids = <String>[];

  @override
  Future<ThreadDetailData> loadFirstPage({required String tid}) async {
    loadedTids.add(tid);
    return detail;
  }
}
