import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:y300/core/links/external_link_opener.dart';

void main() {
  for (final scenario in [
    'tab',
    'unsupported',
    'failed',
    'exception',
    'external',
  ]) {
    test('browser dispatch $scenario', () async {
      final modes = <LaunchMode>[];
      final uri = Uri.parse('https://example.org/read?a=1#post');
      final opener = BrowserLinkOpener(
        externalBrowser: () async => scenario == 'external',
        supportsTabs: () async => scenario != 'unsupported',
        open: (target, mode) async {
          expect(target, uri);
          modes.add(mode);
          if (mode == LaunchMode.externalApplication) return true;
          if (scenario == 'exception') {
            throw PlatformException(code: 'unavailable');
          }
          return scenario == 'tab';
        },
      );
      expect(await opener.launch(uri), isTrue);
      expect(modes, [
        if (scenario != 'unsupported' && scenario != 'external')
          LaunchMode.inAppBrowserView,
        if (scenario != 'tab') LaunchMode.externalApplication,
      ]);
      expect(await opener.launch(Uri.parse('javascript:alert(1)')), isFalse);
    });
  }
}
