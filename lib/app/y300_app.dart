import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/clipboard/forum_clipboard_runtime.dart';
import 'package:y300/app/localization/app_locale_resolution.dart';
import 'package:y300/app/localization/app_prism_ui_localizations.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_edition.dart';
import 'package:y300/app/settings/bold_font_provider.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/startup/blacklist_sync_host.dart';
import 'package:y300/app/startup/message_attention_visibility_host.dart';
import 'package:y300/app/startup/message_attention_probe_host.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_dynamic_colors.dart';
import 'package:y300/features/app_update/presentation/widgets/app_update_alert_host.dart';
import 'package:y300/features/forum/presentation/webview/waf_challenge_recovery_host.dart';
import 'package:y300/features/startup/presentation/daily_sign_in_automation_host.dart';
import 'package:y300/features/startup/presentation/main_shell_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';

/// 应用根组件，仅负责主题与路由入口。
class Y300App extends ConsumerWidget {
  const Y300App({
    super.key,
    this.home = const DailySignInAutomationHost(child: MainShellPage()),
    this.enableAppUpdatePrompt = true,
  });

  final Widget home;
  final bool enableAppUpdatePrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipboard = ref.watch(forumClipboardRuntimeProvider);
    clipboard.configureUpdatePrompt(enableAppUpdatePrompt);
    final settings = ref
        .watch(appAppearanceControllerProvider)
        .maybeWhen(
          data: (settings) => settings,
          orElse: AppAppearanceSettings.defaults,
        );
    final boldFont = ref.watch(boldFontEnabledProvider).value ?? false;
    return AppDynamicColorBuilder(
      builder: (light, dark) => AppDynamicColors(
        light: light,
        dark: dark,
        child: MaterialApp(
          title: 'Y300',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            family: settings.themeFamily,
            brightness: Brightness.light,
            colorSource: settings.colorSource,
            dynamicScheme: light,
            boldFont: boldFont,
          ),
          darkTheme: AppTheme.build(
            family: settings.themeFamily,
            brightness: Brightness.dark,
            colorSource: settings.colorSource,
            dynamicScheme: dark,
            boldFont: boldFont,
          ),
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
            AppPrismUiLocalizations.delegate,
          ],
          locale: localeForAppLanguage(settings.languagePreference),
          localeListResolutionCallback: (locales, _) =>
              resolveAppLocale(locales),
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [
            ref.watch(forumClipboardRouteObserverProvider),
            ref.watch(messageAttentionRouteObserverProvider),
          ],
          builder: (context, child) => WafChallengeRecoveryHost(
            onBusyChanged: clipboard.setWafBusy,
            child: MessageAttentionProbeHost(
              child: BlacklistSyncHost(
                // 玻璃来源包住 Navigator，普通路由、根页菜单、模态和分栏
                // 详情共用同一宿主；WAF、消息与黑名单 host 仍是应用根职责。
                child: AppGlassEnvironment(
                  glassLevel: AppEdition.isEInk
                      ? AppGlassLevel.off
                      : settings.glassLevel,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          home: enableAppUpdatePrompt
              ? AppUpdateAlertHost(
                  onBlockedChanged: clipboard.setUpdateBlocked,
                  child: home,
                )
              : home,
        ),
      ),
    );
  }
}
