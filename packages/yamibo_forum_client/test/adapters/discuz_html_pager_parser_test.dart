import 'package:test/test.dart';
import 'package:yamibo_forum_client/src/adapters/forum_display_html_parser.dart';
import 'package:yamibo_forum_client/src/adapters/thread_detail_snapshot_codec.dart';
import 'package:yamibo_forum_client/yamibo_forum_client.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_adapters.dart';

void main() {
  final siteOrigin = Uri.parse('https://bbs.yamibo.com');
  final threadParser = ThreadDetailHtmlParser(siteOrigin: siteOrigin);
  final forumParser = ForumDisplayHtmlParser(siteOrigin: siteOrigin);

  String mobileThreadHtml({required String pgHtml, int replies = 120}) =>
      '''
<html><body id="forum">
  <div class="viewthread">
    <div class="view_tit">Fixture thread</div>
    <div class="plc" id="pid1">
      <div class="display pione"><div class="authi">
        <div class="mtit"><span class="z"><a href="home.php?mod=space&uid=10">Alice</a></span><span class="y">1#</span></div>
        <div class="mtime"><span class="y"><em>500</em><em>$replies</em></span></div>
      </div></div>
      <div class="message">Body</div>
    </div>
    $pgHtml
  </div>
</body></html>
''';

  test('last page without a.last or a.nxt resolves lastPage == currentPage', () {
    final html = mobileThreadHtml(
      pgHtml:
          '<div class="pg">'
          '<a class="prev" href="forum.php?mod=viewthread&tid=100&page=4">上一页</a>'
          '<a href="forum.php?mod=viewthread&tid=100&page=1">1</a>'
          '<a href="forum.php?mod=viewthread&tid=100&page=2">2</a>'
          '<a href="forum.php?mod=viewthread&tid=100&page=3">3</a>'
          '<a href="forum.php?mod=viewthread&tid=100&page=4">4</a>'
          '<strong>5</strong>'
          '</div>',
    );
    final data = threadParser.parse(html, fallbackTid: '100', fallbackPage: 5);
    expect(data.currentPage, 5);
    expect(data.lastPage, 5);
    expect(data.hasMore, isFalse);
  });

  test('parses .pg label span total pages', () {
    final html = mobileThreadHtml(
      pgHtml:
          '<div class="pg">'
          '<strong>3</strong>'
          '<label><input name="custompage" value="3">'
          '<span title="共 20 页"> / 20 页</span></label>'
          '<a class="nxt" href="forum.php?mod=viewthread&tid=100&page=4">下一页</a>'
          '</div>',
    );
    final data = threadParser.parse(html, fallbackTid: '100', fallbackPage: 3);
    expect(data.currentPage, 3);
    expect(data.lastPage, 20);
    expect(data.hasMore, isTrue);
  });

  test('parses mobile select pager options for current and total pages', () {
    final html = mobileThreadHtml(
      pgHtml:
          '<div class="pg">'
          '<a class="prev" href="forum.php?mod=viewthread&tid=100&page=1">上一页</a>'
          '<select>'
          '<option value="1">1 / 12</option>'
          '<option value="2" selected>2 / 12</option>'
          '<option value="12">12 / 12</option>'
          '</select>'
          '<a class="nxt" href="forum.php?mod=viewthread&tid=100&page=3">下一页</a>'
          '</div>',
    );
    final data = threadParser.parse(html, fallbackTid: '100', fallbackPage: 2);
    expect(data.currentPage, 2);
    expect(data.lastPage, 12);
    expect(data.hasMore, isTrue);
  });

  test(
    'directional-only mobile pager leaves lastPage null with directional precision',
    () async {
      final html = mobileThreadHtml(
        pgHtml:
            '<div class="pg">'
            '<a class="nxt" href="forum.php?mod=viewthread&tid=100&page=2">下一页</a>'
            '</div>',
      );
      final data = threadParser.parse(
        html,
        fallbackTid: '100',
        fallbackPage: 1,
      );
      expect(data.currentPage, 1);
      expect(data.lastPage, isNull);
      expect(data.hasMore, isTrue);
      expect(data.nextPageUrl, contains('page=2'));

      final forumHtml = '''
<html><body id="forum">
  <div class="threadlist_box"><div class="threadlist"><ul></ul></div>
  <div class="pg"><a class="nxt" href="forum.php?mod=forumdisplay&fid=30&page=2">下一页</a></div>
  </div>
</body></html>
''';
      final forum = forumParser.parse(
        forumHtml,
        fallbackFid: '30',
        fallbackPage: 1,
      );
      expect(forum.lastPage, isNull);
      expect(forum.hasMore, isTrue);

      final factory = ForumClientAdapterFactory(
        config: ForumClientConfig(
          siteOrigin: siteOrigin,
          apiOrigin: Uri.parse('https://bbs.yamibo.com/api/mobile/index.php'),
          userAgent: 'mobile-test',
          desktopUserAgent: 'desktop-test',
        ),
        network: _FixedHtmlNetwork(html),
      );
      final repo = factory.createHtmlThreadDetail();
      final res = await repo.getThreadDetail(tid: '100', page: 1);
      final success =
          res
              as DataReadSuccess<
                ThreadDetailData,
                ThreadDetailReadCapabilities
              >;
      expect(
        success.capabilities.paginationPrecision,
        PaginationPrecision.directional,
      );
      expect(
        success.capabilities.supports(ThreadDetailCapability.exactPagination),
        isFalse,
      );
    },
  );

  test(
    'single-page HTML without .pg has hasMore=false even when replies > posts',
    () {
      final html = mobileThreadHtml(pgHtml: '', replies: 500);
      final data = threadParser.parse(
        html,
        fallbackTid: '100',
        fallbackPage: 1,
      );
      expect(data.lastPage, isNull);
      expect(data.hasMore, isFalse);
    },
  );

  test(
    'snapshot codec round-trips hasMoreOverride and decodes legacy null',
    () {
      const codec = ThreadDetailSnapshotCodec();
      final data = ThreadDetailData(
        tid: '100',
        fid: '33',
        subject: 'Test',
        author: 'Alice',
        replies: 500,
        views: 1000,
        currentPage: 1,
        perPage: 20,
        hasMoreOverride: false,
        posts: [
          ThreadPost(
            pid: '1',
            author: 'Alice',
            authorId: '10',
            message: '<p>Body</p>',
            number: 1,
            isFirst: true,
            dateline: '2026-01-01',
          ),
        ],
      );
      final encoded = codec.encode(data) as Map<String, Object?>;
      expect(encoded['hasMoreOverride'], isFalse);
      final decoded = codec.decode(encoded);
      expect(decoded.hasMoreOverride, isFalse);
      expect(decoded.hasMore, isFalse);

      encoded.remove('hasMoreOverride');
      final legacy = codec.decode(encoded);
      expect(legacy.hasMoreOverride, isNull);
      expect(legacy.hasMore, isTrue);
    },
  );
}

final class _FixedHtmlNetwork implements ForumClientNetwork {
  _FixedHtmlNetwork(this.body);
  final String body;

  @override
  Future<ForumTransportResult<ForumResponse<Object?>>> send(
    ForumRequest request,
  ) async {
    return ForumTransportSuccess(
      ForumResponse(
        uri: request.uri,
        statusCode: 200,
        headers: const {},
        body: body,
      ),
    );
  }
}
