import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';

final externalBrowserPreferenceProvider =
    AsyncNotifierProvider<ExternalBrowserPreference, bool>(
      ExternalBrowserPreference.new,
    );

class ExternalBrowserPreference extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref
          .watch(preferencesStoreProvider)
          .read(PreferenceKeys.externalBrowser) ??
      false;

  Future<void> set(bool external) async {
    await ref
        .read(preferencesStoreProvider)
        .write(PreferenceKeys.externalBrowser, external);
    state = AsyncData(external);
  }
}

abstract interface class ExternalLinkOpener {
  Future<bool> launch(Uri uri);
}

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>((ref) {
  return BrowserLinkOpener(
    externalBrowser: () => ref.read(externalBrowserPreferenceProvider.future),
    supportsTabs: () => supportsLaunchMode(LaunchMode.inAppBrowserView),
    open: (uri, mode) => launchUrl(uri, mode: mode),
  );
});

class BrowserLinkOpener implements ExternalLinkOpener {
  const BrowserLinkOpener({
    required this.externalBrowser,
    required this.supportsTabs,
    required this.open,
  });
  final Future<bool> Function() externalBrowser;
  final Future<bool> Function() supportsTabs;
  final Future<bool> Function(Uri, LaunchMode) open;

  @override
  Future<bool> launch(Uri uri) async {
    final web =
        {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    if (!web && uri.scheme != 'mailto') return false;
    if (web) {
      try {
        if (!await externalBrowser() &&
            await supportsTabs() &&
            await open(uri, LaunchMode.inAppBrowserView)) {
          return true;
        }
      } on Exception {
        // 系统浏览器仍可能接受普通打开意图。
      }
    }
    try {
      return await open(uri, LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
