import 'dart:async';

import 'package:test/test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_adapters.dart';

void main() {
  late _Network network;
  late ForumBlacklistRepository repository;

  setUp(() {
    network = _Network();
    repository = ForumClientAdapterFactory(
      config: ForumClientConfig(
        siteOrigin: Uri.parse('https://forum.example.test'),
        userAgent: 'mobile-fixture',
        desktopUserAgent: 'desktop-fixture',
      ),
      network: network,
    ).createForumBlacklist();
  });

  test(
    'reads identities and avatars from the desktop blacklist page',
    () async {
      network.bodies = <String>[
        _page(rows: <String>[_row(11, 'Alice'), _row(12, "A'友")]),
      ];

      final result = await repository.load(const ForumBlacklistQuery());

      final data = result.dataOrNull!;
      expect(data.pagesRead, 1);
      expect(data.entries.map((entry) => entry.userId), <String>['11', '12']);
      expect(data.entries.map((entry) => entry.username), <String>[
        'Alice',
        "A'友",
      ]);
      expect(
        data.entries.first.avatarUrl,
        'https://forum.example.test/uc_server/avatar.php?uid=11',
      );
      final success =
          result
              as DataReadSuccess<
                ForumBlacklistData,
                ForumBlacklistReadCapabilities
              >;
      expect(
        success.capabilities.supports(ForumBlacklistCapability.completeList),
        isTrue,
      );
      expect(() => data.entries.clear(), throwsUnsupportedError);

      final request = network.requests.single;
      expect(request.method, ForumRequestMethod.get);
      expect(request.context.operation, 'blacklist.read');
      expect(request.context.pageKind, 'profile.blacklist');
      expect(request.headers['User-Agent'], 'desktop-fixture');
      expect(request.uri.queryParameters, <String, String>{
        'mod': 'space',
        'do': 'friend',
        'view': 'blacklist',
      });
      expect(request.followRedirects, isFalse);
    },
  );

  test('explicit empty blacklist is a successful complete read', () async {
    network.bodies = <String>[
      '<html><body>'
          '<form name="blackform" method="post" '
          'action="home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;start="></form>'
          '</body></html>',
    ];

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.dataOrNull!.entries, isEmpty);
    expect(result.dataOrNull!.pagesRead, 1);
  });

  test('login or malformed pages fail closed', () async {
    network.bodies = <String>['<html><body>请先登录</body></html>'];

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.failureOrNull!.kind, DataReadFailureKind.parse);
    expect(
      result.failureOrNull!.diagnosticMessage,
      'blacklist_response_unrecognized',
    );
  });

  test('an unparseable identity rejects the whole page', () async {
    network.bodies = <String>[
      _page(
        rows: <String>[
          _row(11, 'Alice').replaceFirst(
            '<a href="https://forum.example.test/space-uid-11.html">Alice</a>',
            '<a href="https://forum.example.test/home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist">黑名单除名</a>',
          ),
        ],
      ),
    ];

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.failureOrNull!.kind, DataReadFailureKind.parse);
  });

  test('follows validated pager links and returns the complete list', () async {
    final pageTwo = Uri.parse(
      'https://forum.example.test/home.php?mod=space&do=friend&view=blacklist&start=20',
    );
    network.bodies = <String>[
      _page(
        rows: <String>[_row(11, 'Alice')],
        pagerHref:
            'home.php?mod=space&amp;do=friend&amp;view=blacklist&amp;start=20',
      ),
      _page(rows: <String>[_row(13, 'Carol')]),
    ];

    final result = await repository.load(const ForumBlacklistQuery());

    final data = result.dataOrNull!;
    expect(data.pagesRead, 2);
    expect(data.entries.map((entry) => entry.userId), <String>['11', '13']);
    expect(network.requests.map((request) => request.uri), <Uri>[
      Uri.parse(
        'https://forum.example.test/home.php?mod=space&do=friend&view=blacklist',
      ),
      pageTwo,
    ]);
  });

  test('does not follow delete or unrelated list links', () async {
    network.bodies = <String>[
      _page(
        rows: <String>[_row(11, 'Alice')],
        extraAnchors:
            '<a href="home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;subop=delete&amp;uid=11">黑名单除名</a>'
            '<a href="home.php?mod=space&amp;do=friend&amp;view=blacklist">刷新</a>',
      ),
    ];

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.dataOrNull!.pagesRead, 1);
    expect(network.requests, hasLength(1));
  });

  test('a later page failure rejects the entire list', () async {
    network.bodies = <String>[
      _page(
        rows: <String>[_row(11, 'Alice')],
        pagerHref:
            'home.php?mod=space&amp;do=friend&amp;view=blacklist&amp;start=20',
      ),
      '<html><body>维护中</body></html>',
    ];

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.failureOrNull!.kind, DataReadFailureKind.parse);
    expect(result.dataOrNull, isNull);
  });

  test('duplicate identities across pages fail closed', () async {
    network.bodies = <String>[
      _page(
        rows: <String>[_row(11, 'Alice')],
        pagerHref:
            'home.php?mod=space&amp;do=friend&amp;view=blacklist&amp;start=20',
      ),
      _page(rows: <String>[_row(11, 'Alice')]),
    ];

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.failureOrNull!.kind, DataReadFailureKind.parse);
  });

  test('redirected login is unauthorized', () async {
    network.statusCode = 302;

    final result = await repository.load(const ForumBlacklistQuery());

    expect(result.failureOrNull!.kind, DataReadFailureKind.unauthorized);
  });
}

String _page({
  List<String> rows = const <String>[],
  String? pagerHref,
  String extraAnchors = '',
}) {
  return '<html><body>'
      '<form name="blackform" method="post" '
      'action="home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;start=">'
      '</form>'
      '<div id="friend_ul"><ul class="buddy cl">${rows.join()}</ul></div>'
      '$extraAnchors'
      '${pagerHref == null ? '' : '<div class="pg"><a class="nxt" href="$pagerHref">下一页</a></div>'}'
      '</body></html>';
}

String _row(int uid, String username) {
  return '<li id="friend_${uid}_li">'
      '<div class="avt"><a href="https://forum.example.test/space-uid-$uid.html">'
      '<img src="/uc_server/avatar.php?uid=$uid" class="user_avatar"></a></div>'
      '<h4>'
      '<span class="xg1 xw0 y">'
      '<a href="https://forum.example.test/home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;subop=delete&amp;uid=$uid&amp;start=">黑名单除名</a>'
      '</span>'
      '<a href="https://forum.example.test/space-uid-$uid.html">$username</a>'
      '<span id="friend_note_$uid" class="note xw0"></span>'
      '</h4>'
      '</li>';
}

final class _Network implements ForumClientNetwork {
  final List<ForumRequest> requests = <ForumRequest>[];
  List<String> bodies = <String>[];
  int statusCode = 200;
  int _index = 0;

  @override
  Future<ForumTransportResult<ForumResponse<Object?>>> send(
    ForumRequest request,
  ) async {
    requests.add(request);
    final body = bodies.isEmpty
        ? ''
        : bodies[_index < bodies.length ? _index : bodies.length - 1];
    _index++;
    return ForumTransportSuccess(
      ForumResponse(
        uri: request.uri,
        statusCode: statusCode,
        headers: const <String, List<String>>{
          'content-type': <String>['text/html'],
        },
        body: body,
      ),
    );
  }
}
