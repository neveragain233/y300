import 'dart:async';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:test/test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_adapters.dart';

void main() {
  late _Network network;
  late _Formhash formhash;
  late ForumBlacklistCommand command;
  final config = ForumClientConfig(
    siteOrigin: Uri.parse('https://forum.example.test'),
    userAgent: 'mobile',
    desktopUserAgent: 'desktop',
  );
  setUp(() {
    network = _Network();
    formhash = _Formhash();
    command = ForumClientAdapterFactory(
      config: config,
      network: network,
    ).createForumBlacklistCommand(formhash);
    // The factory builds its own read repository; verification is observed
    // through the returned result and transport requests instead.
  });

  test('confirmed redirect plus listed target is applied', () async {
    network.status = 301;
    network.headers = {
      'Location': [
        'https://forum.example.test/home.php?mod=space&uid=701749&do=friend&view=blacklist&quickforward=1&start=',
      ],
    };
    // The factory's reader uses the same transport; answer the follow-up list
    // read with the live page shape.
    network.queue.addAll([
      _response(301, headers: network.headers),
      _response(200, body: _blacklistPage()),
    ]);
    final result = await command.execute(_submission());
    expect(result, isA<DataCommandApplied<ForumBlacklistAddReceipt>>());
    expect(result.receiptOrNull!.userId, '340113');
    expect(result.receiptOrNull!.username, 'hkw1024');

    final post = network.requests.first;
    expect(post.method, ForumRequestMethod.post);
    expect(post.followRedirects, isFalse);
    expect(post.uri.path, '/home.php');
    expect(post.uri.queryParameters, {
      'mod': 'spacecp',
      'ac': 'friend',
      'op': 'blacklist',
      'start': '',
    });
    expect(post.headers['Content-Type'], 'application/x-www-form-urlencoded');
    expect(post.body, {
      'formhash': 'fixture-hash',
      'username': 'hkw1024',
      'blacklistsubmit': 'true',
      'blacklistsubmit_btn': 'true',
    });
    expect(network.requests, hasLength(2));
    expect(network.requests.last.method, ForumRequestMethod.get);
    expect(network.requests.last.uri.queryParameters['view'], 'blacklist');
    expect(formhash.calls, 1);
  });

  test('submitted request mirrors the observed desktop blacklist form', () async {
    final document = html.parse(
      File('test/fixtures/blacklist/desktop.html').readAsStringSync(),
    );
    final form = document.querySelector('form[name="blackform"]')!;
    final action = Uri.parse(
      'https://forum.example.test/',
    ).resolve(form.attributes['action']!);
    expect(action.path, '/home.php');
    expect(action.queryParameters, {
      'mod': 'spacecp',
      'ac': 'friend',
      'op': 'blacklist',
      'start': '',
    });
    final names = <String>{
      ...form
          .querySelectorAll('input')
          .map((input) => input.attributes['name'])
          .whereType<String>(),
      ...form
          .querySelectorAll('button')
          .map((button) => button.attributes['name'])
          .whereType<String>(),
    };
    expect(
      names,
      containsAll(<String>[
        'username',
        'blacklistsubmit',
        'blacklistsubmit_btn',
        'formhash',
      ]),
    );

    network.queue = [
      _response(
        301,
        headers: {
          'Location': [
            'https://forum.example.test/home.php?mod=space&uid=701749&do=friend&view=blacklist&quickforward=1&start=',
          ],
        },
      ),
      _response(200, body: _blacklistPage()),
    ];
    expect(
      await command.execute(_submission()),
      isA<DataCommandApplied<ForumBlacklistAddReceipt>>(),
    );
    final post = network.requests.first;
    expect(post.uri.queryParameters, action.queryParameters);
    expect((post.body! as Map<String, String>).keys.toSet(), names);
  });

  test('200 success alert is confirmed by the complete blacklist', () async {
    network.queue = [
      _response(200, body: _successAlert()),
      _response(200, body: _blacklistPage()),
    ];
    final result = await command.execute(_submission());
    expect(result, isA<DataCommandApplied<ForumBlacklistAddReceipt>>());
    expect(network.requests, hasLength(2));
  });

  test('explicit error alert is a safe rejection without a re-read', () async {
    network.queue = [_response(200, body: _errorAlert())];
    final result = await command.execute(_submission());
    expect(result, isA<DataCommandRejected<ForumBlacklistAddReceipt>>());
    expect(result.failureOrNull!.diagnosticMessage, 'blacklist_add_rejected');
    expect(network.requests, hasLength(1));
  });

  test('login page and server auth failures are safe rejections', () async {
    network.queue = [_response(200, body: _loginPage())];
    expect(
      await command.execute(_submission()),
      isA<DataCommandRejected<ForumBlacklistAddReceipt>>(),
    );
    network.requests.clear();
    network.queue = [_response(403)];
    final forbidden = await command.execute(_submission());
    expect(forbidden, isA<DataCommandRejected<ForumBlacklistAddReceipt>>());
    expect(
      forbidden.failureOrNull!.kind,
      DataCommandFailureKind.unauthenticated,
    );
    expect(network.requests, hasLength(1));
  });

  test('unproven responses never claim the target was added', () async {
    final bodies = [
      '<html><body>no alert</body></html>',
      _successAlert().replaceAll('alert_right', 'alert_info'),
    ];
    for (final body in bodies) {
      network.requests.clear();
      network.queue = [_response(200, body: body)];
      final result = await command.execute(_submission());
      expect(
        result,
        isA<DataCommandOutcomeUnknown<ForumBlacklistAddReceipt>>(),
        reason: body,
      );
    }
    network.requests.clear();
    network.failure = true;
    expect(
      await command.execute(_submission()),
      isA<DataCommandOutcomeUnknown<ForumBlacklistAddReceipt>>(),
    );
    expect(network.requests, hasLength(1));
  });

  test('unrelated or off-site redirects are not success proof', () async {
    for (final location in [
      'https://forum.example.test/home.php?mod=space&do=friend&view=friend',
      'https://other.example.test/home.php?mod=space&uid=701749&do=friend&view=blacklist&quickforward=1',
      'https://forum.example.test/home.php?mod=space&uid=0&do=friend&view=blacklist&quickforward=1',
      'https://forum.example.test/home.php?mod=space&uid=701749&do=friend&view=blacklist&quickforward=1&ac=friend',
      'https://user:pass@forum.example.test/home.php?mod=space&uid=701749&do=friend&view=blacklist&quickforward=1',
    ]) {
      network.requests.clear();
      network.queue = [
        _response(
          302,
          headers: {
            'Location': [location],
          },
        ),
      ];
      final result = await command.execute(_submission());
      expect(
        result,
        isA<DataCommandOutcomeUnknown<ForumBlacklistAddReceipt>>(),
        reason: location,
      );
    }
  });

  test('successful response without the target listed stays unproven', () async {
    network.queue = [
      _response(
        301,
        headers: {
          'Location': [
            'https://forum.example.test/home.php?mod=space&uid=701749&do=friend&view=blacklist&quickforward=1',
          ],
        },
      ),
      _response(200, body: _blacklistPage(empty: true)),
    ];
    expect(
      await command.execute(_submission()),
      isA<DataCommandOutcomeUnknown<ForumBlacklistAddReceipt>>(),
    );
  });

  test('failed verification read stays unproven', () async {
    network.queue = [_response(200, body: _successAlert()), _response(500)];
    expect(
      await command.execute(_submission()),
      isA<DataCommandOutcomeUnknown<ForumBlacklistAddReceipt>>(),
    );
  });

  test('invalid identities never touch the network', () async {
    for (final submission in [
      _submission(userId: '0'),
      _submission(userId: '-1'),
      _submission(userId: ''),
      _submission(username: ''),
      _submission(username: ' hkw1024'),
      _submission(username: 'hkw\u0000'),
    ]) {
      expect(
        await command.execute(submission),
        isA<DataCommandNotSent<ForumBlacklistAddReceipt>>(),
      );
    }
    expect(network.requests, isEmpty);
    expect(formhash.calls, 0);
  });

  test('formhash failure or cancellation does not submit', () async {
    formhash.result = const ForumFormhashError(
      ForumTransportFailure(
        kind: ForumTransportFailureKind.unauthorized,
        code: 'login_required',
      ),
    );
    final unauthorized = await command.execute(_submission());
    expect(unauthorized, isA<DataCommandNotSent<ForumBlacklistAddReceipt>>());
    expect(
      unauthorized.failureOrNull!.kind,
      DataCommandFailureKind.unauthenticated,
    );

    formhash.result = const ForumFormhashSuccess('');
    expect(
      await command.execute(_submission()),
      isA<DataCommandNotSent<ForumBlacklistAddReceipt>>(),
    );

    formhash.result = const ForumFormhashSuccess('fixture-hash');
    final cancellation = ForumRequestCancellation();
    formhash.pending = Completer<void>();
    final pending = command.execute(_submission(cancellation: cancellation));
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    formhash.pending!.complete();
    expect(await pending, isA<DataCommandNotSent<ForumBlacklistAddReceipt>>());
    expect(network.requests, isEmpty);
  });

  test('facade and source overlays preserve command installation', () async {
    final missing = YamiboForumClient(config: config, network: network);
    expect(
      await missing.addToBlacklist(_submission()),
      isA<DataCommandUnsupported<ForumBlacklistAddReceipt>>(),
    );
    network.queue = [
      _response(200, body: _successAlert()),
      _response(200, body: _blacklistPage()),
    ];
    final installed = YamiboForumClientBuilder(
      config: config,
      network: network,
      formhashProvider: formhash,
    ).buildStandardClient();
    expect(
      await installed.addToBlacklist(_submission()),
      isA<DataCommandApplied<ForumBlacklistAddReceipt>>(),
    );
    final plan = ForumClientSourcePlan(friendBlacklistCommand: command);
    expect(
      plan.overlay(const ForumClientSourcePlan()).friendBlacklistCommand,
      same(command),
    );
    expect(
      const ForumClientSourcePlan().overlay(plan).friendBlacklistCommand,
      same(command),
    );
  });
}

ForumBlacklistAddSubmission _submission({
  String userId = '340113',
  String username = 'hkw1024',
  ForumRequestCancellation? cancellation,
}) => ForumBlacklistAddSubmission(
  userId: userId,
  username: username,
  cancellation: cancellation,
);

String _blacklistPage({bool empty = false}) => empty
    ? '<html><body><form name="blackform" action="home.php?mod=spacecp&ac=friend&op=blacklist&start=">'
          '<input type="hidden" name="formhash" value="fixture-hash"></form>'
          '<div id="friend_ul"><ul class="buddy cl"></ul></div></body></html>'
    : '<html><body><form name="blackform" action="home.php?mod=spacecp&ac=friend&op=blacklist&start=">'
          '<input type="hidden" name="formhash" value="fixture-hash"></form>'
          '<div id="friend_ul"><ul class="buddy cl">'
          '<li id="friend_340113_li"><h4>'
          '<a href="https://forum.example.test/space-uid-340113.html">hkw1024</a>'
          '</h4></li></ul></div></body></html>';

String _successAlert() =>
    '<html><body><div class="nfl"><div class="f_c altw">'
    '<div id="messagetext" class="alert_right"><p>操作成功</p>'
    '<p class="alert_btnleft"><a href="home.php?mod=space&amp;uid=701749&amp;do=friend&amp;view=blacklist&amp;quickforward=1&amp;start=">如果您的浏览器没有自动跳转</a></p>'
    '</div></div></div></body></html>';

String _errorAlert() =>
    '<html><body><div class="nfl"><div class="f_c altw">'
    '<div id="messagetext" class="alert_error"><p>指定的用户不存在</p>'
    '</div></div></div></body></html>';

String _loginPage() =>
    '<html><body><div id="messagelogin"></div>'
    '<form id="loginform" action="member.php?mod=logging&amp;action=login"></form>'
    '</body></html>';

ForumResponse<Object?> _response(
  int status, {
  String body = '',
  Map<String, List<String>> headers = const {},
}) => ForumResponse<Object?>(
  uri: Uri.parse(
    'https://forum.example.test/home.php?mod=spacecp&ac=friend&op=blacklist&start=',
  ),
  statusCode: status,
  headers: headers,
  body: body,
);

final class _Network implements ForumClientNetwork {
  final requests = <ForumRequest>[];
  List<ForumResponse<Object?>> queue = <ForumResponse<Object?>>[];
  bool failure = false;
  int status = 200;
  String body = '';
  Map<String, List<String>> headers = const {};

  @override
  Future<ForumTransportResult<ForumResponse<Object?>>> send(
    ForumRequest request,
  ) async {
    requests.add(request);
    if (failure) {
      return const ForumTransportError(
        ForumTransportFailure(
          kind: ForumTransportFailureKind.timeout,
          code: 'fixture_timeout',
        ),
      );
    }
    if (queue.isNotEmpty) {
      final response = queue.removeAt(0);
      return ForumTransportSuccess(
        ForumResponse<Object?>(
          uri: request.uri,
          statusCode: response.statusCode,
          headers: response.headers,
          body: response.body,
        ),
      );
    }
    return ForumTransportSuccess(
      ForumResponse<Object?>(
        uri: request.uri,
        statusCode: status,
        headers: headers,
        body: body,
      ),
    );
  }
}

final class _Formhash implements ForumFormhashProvider {
  int calls = 0;
  Completer<void>? pending;
  ForumFormhashResult result = const ForumFormhashSuccess('fixture-hash');
  @override
  Future<ForumFormhashResult> loadFormhash({
    bool preferProfile = true,
    ForumRequestCancellation? cancellation,
  }) async {
    calls++;
    await pending?.future;
    return result;
  }
}
