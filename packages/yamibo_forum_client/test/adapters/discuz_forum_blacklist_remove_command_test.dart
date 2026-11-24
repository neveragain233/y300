import 'package:test/test.dart';
import 'package:yamibo_forum_client/yamibo_forum_client.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_adapters.dart';

void main() {
  late _Network network;
  late ForumBlacklistRemoveCommand command;

  setUp(() {
    network = _Network();
    command = ForumClientAdapterFactory(
      config: ForumClientConfig(
        siteOrigin: Uri.parse('https://forum.example.test'),
        userAgent: 'mobile-fixture',
        desktopUserAgent: 'desktop-fixture',
      ),
      network: network,
    ).createForumBlacklistRemoveCommand();
  });

  test('removes member via 302 quickforward and verifies absence', () async {
    network.handlers.addAll([
      (_) => _htmlResponse(
        _page(rows: <String>[_row(42, 'Target'), _row(99, 'Other')]),
      ),
      (request) {
        expect(request.method, ForumRequestMethod.get);
        expect(request.context.operation, 'blacklist.remove');
        expect(request.followRedirects, isFalse);
        expect(request.uri.queryParameters, <String, String>{
          'mod': 'spacecp',
          'ac': 'friend',
          'op': 'blacklist',
          'subop': 'delete',
          'uid': '42',
          'start': '',
        });
        return ForumTransportSuccess(
          ForumResponse(
            uri: request.uri,
            statusCode: 302,
            headers: const <String, List<String>>{
              'location': <String>[
                'https://forum.example.test/home.php?mod=space&uid=11&do=friend&view=blacklist&quickforward=1&start=',
              ],
            },
            body: '',
          ),
        );
      },
      (_) => _htmlResponse(_page(rows: <String>[_row(99, 'Other')])),
    ]);

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandApplied<ForumBlacklistRemoveReceipt>>());
    expect(
      (result as DataCommandApplied<ForumBlacklistRemoveReceipt>)
          .receipt
          .userId,
      '42',
    );
  });

  test('removes member via 200 alert_right and multi-page discovery', () async {
    network.handlers.addAll([
      (_) => _htmlResponse(
        _page(
          rows: <String>[_row(11, 'First')],
          pagerHref:
              'home.php?mod=space&amp;do=friend&amp;view=blacklist&amp;start=20',
        ),
      ),
      (_) => _htmlResponse(_page(rows: <String>[_row(42, 'Target')])),
      (_) =>
          _htmlResponse('<div id="messagetext" class="alert_right">ok</div>'),
      (_) => _htmlResponse(_page(rows: <String>[_row(11, 'First')])),
    ]);

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandApplied<ForumBlacklistRemoveReceipt>>());
  });

  test('rejects when user is not listed on the live blacklist', () async {
    network.handlers.add(
      (_) => _htmlResponse(_page(rows: <String>[_row(99, 'Other')])),
    );

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandRejected<ForumBlacklistRemoveReceipt>>());
    expect(
      (result as DataCommandRejected<ForumBlacklistRemoveReceipt>).failure.code,
      'blacklist_remove_not_listed',
    );
  });

  test('fails closed with notSent when delete link is absent', () async {
    network.handlers.add(
      (_) =>
          _htmlResponse(_page(rows: <String>[_rowWithoutDelete(42, 'Target')])),
    );

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandNotSent<ForumBlacklistRemoveReceipt>>());
    expect(
      (result as DataCommandNotSent<ForumBlacklistRemoveReceipt>).failure.code,
      'blacklist_remove_action_unavailable',
    );
  });

  test('rejects foreign-origin or mismatched-uid delete links', () async {
    network.handlers.add(
      (_) => _htmlResponse(
        _page(
          rows: <String>[
            '<li id="friend_42_li">'
                '<h4>'
                '<a href="https://evil.example.test/home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;subop=delete&amp;uid=42">除名</a>'
                '<a href="https://forum.example.test/home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;subop=delete&amp;uid=99">除名2</a>'
                '<a href="https://forum.example.test/space-uid-42.html">Target</a>'
                '</h4>'
                '</li>',
          ],
        ),
      ),
    );

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandNotSent<ForumBlacklistRemoveReceipt>>());
    expect(
      (result as DataCommandNotSent<ForumBlacklistRemoveReceipt>).failure.code,
      'blacklist_remove_action_unavailable',
    );
  });

  test('maps 401 and login page to unauthenticated rejection', () async {
    network.handlers.addAll([
      (_) => _htmlResponse(_page(rows: <String>[_row(42, 'Target')])),
      (request) => ForumTransportSuccess(
        ForumResponse(
          uri: request.uri,
          statusCode: 200,
          headers: const <String, List<String>>{},
          body: '<div id="messagelogin"></div>',
        ),
      ),
    ]);

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandRejected<ForumBlacklistRemoveReceipt>>());
    expect(
      (result as DataCommandRejected<ForumBlacklistRemoveReceipt>).failure.kind,
      DataCommandFailureKind.unauthenticated,
    );
  });

  test('maps alert_error to validation rejection', () async {
    network.handlers.addAll([
      (_) => _htmlResponse(_page(rows: <String>[_row(42, 'Target')])),
      (_) =>
          _htmlResponse('<div id="messagetext" class="alert_error">err</div>'),
    ]);

    final result = await command.execute(
      const ForumBlacklistRemoveSubmission(userId: '42'),
    );

    expect(result, isA<DataCommandRejected<ForumBlacklistRemoveReceipt>>());
    expect(
      (result as DataCommandRejected<ForumBlacklistRemoveReceipt>).failure.kind,
      DataCommandFailureKind.validation,
    );
  });

  test(
    'returns outcomeUnknown when send fails or user remains listed',
    () async {
      network.handlers.addAll([
        (_) => _htmlResponse(_page(rows: <String>[_row(42, 'Target')])),
        (_) => const ForumTransportError(
          ForumTransportFailure(
            kind: ForumTransportFailureKind.network,
            code: 'timeout',
          ),
        ),
      ]);

      final networkFail = await command.execute(
        const ForumBlacklistRemoveSubmission(userId: '42'),
      );
      expect(
        networkFail,
        isA<DataCommandOutcomeUnknown<ForumBlacklistRemoveReceipt>>(),
      );

      network.handlers
        ..clear()
        ..addAll([
          (_) => _htmlResponse(_page(rows: <String>[_row(42, 'Target')])),
          (_) => _htmlResponse(
            '<div id="messagetext" class="alert_right">ok</div>',
          ),
          (_) => _htmlResponse(_page(rows: <String>[_row(42, 'Target')])),
        ]);

      final stillListed = await command.execute(
        const ForumBlacklistRemoveSubmission(userId: '42'),
      );
      expect(
        stillListed,
        isA<DataCommandOutcomeUnknown<ForumBlacklistRemoveReceipt>>(),
      );
    },
  );
}

String _page({List<String> rows = const <String>[], String? pagerHref}) {
  return '<html><body>'
      '<form name="blackform" method="post" '
      'action="home.php?mod=spacecp&amp;ac=friend&amp;op=blacklist&amp;start=">'
      '</form>'
      '<div id="friend_ul"><ul class="buddy cl">${rows.join()}</ul></div>'
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
      '</h4>'
      '</li>';
}

String _rowWithoutDelete(int uid, String username) {
  return '<li id="friend_${uid}_li">'
      '<h4><a href="https://forum.example.test/space-uid-$uid.html">$username</a></h4>'
      '</li>';
}

ForumTransportSuccess<ForumResponse<Object?>> _htmlResponse(String body) {
  return ForumTransportSuccess(
    ForumResponse(
      uri: Uri.parse(
        'https://forum.example.test/home.php?mod=space&do=friend&view=blacklist',
      ),
      statusCode: 200,
      headers: const <String, List<String>>{
        'content-type': <String>['text/html'],
      },
      body: body,
    ),
  );
}

final class _Network implements ForumClientNetwork {
  final List<
    ForumTransportResult<ForumResponse<Object?>> Function(ForumRequest request)
  >
  handlers = [];
  int _index = 0;

  @override
  Future<ForumTransportResult<ForumResponse<Object?>>> send(
    ForumRequest request,
  ) async {
    final handler = handlers[_index++];
    if (handler case final fn) {
      final result = fn(request);
      if (result is ForumTransportSuccess<ForumResponse<Object?>> &&
          result.response.statusCode == 200 &&
          result.response.uri.toString().contains('view=blacklist')) {
        return ForumTransportSuccess(
          ForumResponse(
            uri: request.uri,
            statusCode: result.response.statusCode,
            headers: result.response.headers,
            body: result.response.body,
          ),
        );
      }
      return result;
    }
  }
}
