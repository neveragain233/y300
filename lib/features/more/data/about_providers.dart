import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:y300/core/links/external_link_opener.dart';
import 'package:y300/features/more/domain/models/about_app_info.dart';
import 'package:y300/features/more/domain/services/about_external_link_launcher.dart';

final aboutAppInfoProvider = FutureProvider<AboutAppInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AboutAppInfo(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
});

final aboutExternalLinkLauncherProvider = Provider<AboutExternalLinkLauncher>((
  ref,
) {
  return _UrlLauncherAboutExternalLinkLauncher(
    ref.watch(externalLinkOpenerProvider),
  );
});

final class _UrlLauncherAboutExternalLinkLauncher
    implements AboutExternalLinkLauncher {
  const _UrlLauncherAboutExternalLinkLauncher(this.opener);
  final ExternalLinkOpener opener;

  @override
  Future<bool> open(Uri uri) {
    return opener.launch(uri);
  }
}
