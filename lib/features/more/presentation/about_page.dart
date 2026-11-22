import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:version/version.dart';
import 'package:y300/features/app_update/domain/services/app_version_codec.dart';
import 'package:y300/features/app_update/presentation/app_release_notes_page.dart';
import 'package:y300/features/app_update/presentation/widgets/app_update_check_tile.dart';
import 'package:y300/features/more/data/about_providers.dart';
import 'package:y300/features/more/domain/models/about_app_info.dart';
import 'package:y300/features/more/presentation/more_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  static final Uri githubRepositoryUri = Uri.parse(
    'https://github.com/QAQadws/y300',
  );

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  static const AppVersionCodec _versionCodec = AppVersionCodec();

  @override
  Widget build(BuildContext context) {
    final appInfo = ref.watch(aboutAppInfoProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppPageAppBar(title: l10n.moreAbout),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const Key('about-page-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _AboutHeader(appInfo: appInfo.value),
                AppGroupedSection(
                  title: l10n.moreAboutVersionSection,
                  children: [
                    const AppUpdateCheckTile(showVersionSubtitle: false),
                    AppGroupedRow(
                      key: const Key('about-release-notes-entry'),
                      leading: const Icon(Icons.history_outlined),
                      title: l10n.moreAboutReleaseNotes,
                      showChevron: true,
                      enabled: _installedVersion(appInfo.value) != null,
                      onTap: () => _openReleaseNotes(appInfo.value),
                    ),
                  ],
                ),
                AppGroupedSection(
                  title: l10n.moreAboutProjectSection,
                  children: [
                    AppGroupedRow(
                      key: const Key('about-github-entry'),
                      leading: const FaIcon(FontAwesomeIcons.github),
                      title: l10n.moreAboutGitHub,
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: _openGitHubRepository,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Version? _installedVersion(AboutAppInfo? appInfo) {
    if (appInfo == null) {
      return null;
    }
    return _versionCodec.parseVersionName(appInfo.version.trim());
  }

  void _openReleaseNotes(AboutAppInfo? appInfo) {
    final installedVersion = _installedVersion(appInfo);
    if (installedVersion == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppReleaseNotesPage(installedVersion: installedVersion),
      ),
    );
  }

  Future<void> _openGitHubRepository() async {
    var opened = false;
    try {
      opened = await ref
          .read(aboutExternalLinkLauncherProvider)
          .open(AboutPage.githubRepositoryUri);
    } on Object {
      opened = false;
    }
    if (!mounted || opened) {
      return;
    }
    showTransientSnackBar(
      context,
      AppLocalizations.of(context).moreAboutOpenGitHubFailed,
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.appInfo});

  final AboutAppInfo? appInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          Image.asset(
            'assets/app_icon_transparent.png',
            width: 88,
            height: 88,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: 14),
          Text('Y300', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            MoreTextResolver.aboutVersion(
              AppLocalizations.of(context),
              appInfo,
            ),
            key: const Key('about-version-label'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
