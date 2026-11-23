import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/network/cookie_store.dart';
import 'package:y300/core/network/forum_availability.dart';
import 'package:y300/core/network/yamibo/yamibo_http_gateway.dart';
import 'package:y300/core/network/yamibo/yamibo_request_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'repeated gateway failures block transmission until one healthy probe',
    () async {
      SharedPreferences.setMockInitialValues({});
      final responses = _Responses();
      final state = ForumAvailability();
      final gateway = YamiboHttpGateway(
        cookieStore: CookieStore(),
        logger: Logger(),
        enableLog: false,
        availability: state,
        dio: Dio()..httpClientAdapter = responses,
      );
      const context = YamiboRequestContext(
        kind: YamiboRequestKind.html,
        operation: 'availability.test',
      );
      final uri = Uri.parse('https://bbs.yamibo.com/forum.php');
      for (final expected in [
        ForumAccessMode.suspected,
        ForumAccessMode.suspected,
        ForumAccessMode.maintenance,
      ]) {
        await gateway.getText(uri, context: context);
        expect(state.mode, expected);
      }
      final blocked = await gateway.postForm(uri, context: context, data: {});
      expect(blocked.errorOrNull?.code, 'forum_cache_only');
      expect(responses.count, 3);
      responses.status = 200;
      final first = state.retry(gateway.probeAvailability);
      expect(state.retry(gateway.probeAvailability), same(first));
      expect(await first, isTrue);
      expect(state.mode, ForumAccessMode.normal);
      expect(responses.count, 4);
    },
  );

  test(
    'cooldown evidence excludes rate limits, old responses and isolated faults',
    () async {
      var now = DateTime(2026, 1, 1);
      final state = ForumAvailability(clock: () => now);
      void response(int status, {bool security = false, String? body}) =>
          state.observe(
            generation: state.generation,
            status: status,
            securityResponse: security,
            body: body,
          );
      response(502);
      now = now.add(const Duration(minutes: 2));
      response(504);
      response(503, security: true);
      response(429);
      expect(state.mode, ForumAccessMode.normal);
      response(502);
      response(200);
      expect(state.blocked, isFalse);
      response(200, body: '<title>站点维护中</title>');
      final pending = Completer<bool>();
      final probe = state.retry(() => pending.future);
      state.setConnected(false);
      pending.complete(true);
      expect(await probe, isFalse);
      expect(state.mode, ForumAccessMode.offline);
      state.setConnected(true);
      expect(state.mode, ForumAccessMode.maintenance);
      state.setManual(false);
      expect(state.blocked, isFalse);
    },
  );
}

class _Responses implements HttpClientAdapter {
  int status = 502;
  int count = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    count++;
    return ResponseBody.fromString(
      '<html><a href="forum.php">forum</a></html>',
      status,
    );
  }

  @override
  void close({bool force = false}) {}
}
