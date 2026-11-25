import 'package:test/test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_adapters.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:yamibo_forum_client/src/adapters/thread_detail_snapshot_codec.dart';

/// 移动版详情页只有首楼带着查看/回复统计块；后续页没有该块。
const _mobileFirstPageHtml = '''
<html><body id="forum">
<div class="viewthread">
  <h2 class="view_tit">Fixture thread</h2>
  <div class="plc" id="pid1">
    <div class="display pione">
      <div class="authi">
        <div class="mtit"><span class="y">1#</span><span class="z">
          <a href="home.php?mod=space&amp;uid=10">Author</a></span></div>
        <div class="mtime">2026-01-01
          <div class="y"><em>120</em><em>52</em></div>
        </div>
      </div>
      <div class="message"><p>Opening.</p></div>
    </div>
  </div>
</div>
<div class="pg"><a class="nxt" href="forum.php?mod=viewthread&amp;tid=100&amp;page=2">Next</a></div>
</body></html>
''';

const _mobileSecondPageHtml = '''
<html><body id="forum">
<div class="viewthread">
  <div class="plc" id="pid21">
    <div class="display">
      <div class="authi">
        <div class="mtit"><span class="y">21#</span><span class="z">
          <a href="home.php?mod=space&amp;uid=11">Reply author</a></span></div>
        <div class="mtime">2026-01-02</div>
      </div>
      <div class="message"><p>Second page reply.</p></div>
    </div>
  </div>
</div>
</body></html>
''';

const _desktopHtmlWithStats = '''
<html><body id="nv_forum">
<div id="postlist"><div class="hm">查看: 120 回复: 52</div></div>
</body></html>
''';

const _desktopHtmlWithoutStats = '''
<html><body id="nv_forum"><div id="postlist"></div></body></html>
''';

void main() {
  final parser = ThreadDetailHtmlParser(
    siteOrigin: Uri.parse('https://bbs.example.test'),
  );

  ThreadDetailData parse(String html, {required int page}) =>
      parser.parse(html, fallbackTid: '100', fallbackPage: page);

  group('server counts availability', () {
    test('mobile first page reports the first-post statistics block', () {
      final detail = parse(_mobileFirstPageHtml, page: 1);

      expect(detail.hasServerCounts, isTrue);
      expect(detail.replies, 52);
      expect(detail.views, 120);
      expect(detail.posts.single.isFirst, isTrue);
    });

    test('mobile second page reports counts as unknown instead of zero', () {
      final detail = parse(_mobileSecondPageHtml, page: 2);

      expect(detail.hasServerCounts, isFalse);
      expect(detail.replies, 0);
      expect(detail.views, 0);
      expect(detail.posts.single.isFirst, isFalse);
    });

    test('desktop statistics text stays the count source', () {
      expect(parse(_desktopHtmlWithStats, page: 1).hasServerCounts, isTrue);
      expect(parse(_desktopHtmlWithStats, page: 1).replies, 52);
      expect(parse(_desktopHtmlWithoutStats, page: 2).hasServerCounts, isFalse);
    });
  });

  group('snapshot counts availability', () {
    const codec = ThreadDetailSnapshotCodec();

    test('round trip keeps unknown counts distinguishable from zero', () {
      final unknown = parse(_mobileSecondPageHtml, page: 2);
      final restored = codec.decode(codec.encode(unknown));

      expect(restored.hasServerCounts, isFalse);
      expect(restored.replies, 0);
      expect(restored.posts.single.pid, '21');
    });

    test('round trip keeps parsed counts', () {
      final restored = codec.decode(
        codec.encode(parse(_mobileFirstPageHtml, page: 1)),
      );

      expect(restored.hasServerCounts, isTrue);
      expect(restored.replies, 52);
    });

    test('snapshots written before the field decode as unknown', () {
      final encoded = codec.encode(parse(_mobileFirstPageHtml, page: 1));
      (encoded as Map<String, Object?>).remove('hasServerCounts');

      final restored = codec.decode(encoded);

      expect(restored.hasServerCounts, isFalse);
      expect(restored.replies, 52);
    });

    test(
      'maps displayorder 1..4 to isPinned and round-trips through snapshot codec',
      () {
        const mapper = ThreadDetailApiMapper();
        final pinned = mapper.mapVariables(<String, Object?>{
          'fid': '5',
          'thread': <String, Object?>{
            'tid': '99',
            'fid': '5',
            'subject': 'Pinned',
            'author': 'Mod',
            'replies': '0',
            'views': '10',
            'displayorder': '2',
          },
          'postlist': <Object?>[],
        }, page: 1);
        final normal = mapper.mapVariables(<String, Object?>{
          'fid': '5',
          'thread': <String, Object?>{
            'tid': '100',
            'fid': '5',
            'subject': 'Normal',
            'author': 'User',
            'replies': '0',
            'views': '10',
            'displayorder': '0',
          },
          'postlist': <Object?>[],
        }, page: 1);

        expect(pinned.isPinned, isTrue);
        expect(normal.isPinned, isFalse);

        final restoredPinned = codec.decode(codec.encode(pinned));
        final restoredNormal = codec.decode(codec.encode(normal));
        expect(restoredPinned.isPinned, isTrue);
        expect(restoredNormal.isPinned, isFalse);
      },
    );
  });
}
