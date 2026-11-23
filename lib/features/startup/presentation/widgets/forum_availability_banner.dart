import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/network/forum_availability.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/l10n/app_localizations.dart';

class ForumAvailabilityBanner extends ConsumerWidget {
  const ForumAvailabilityBanner({super.key, this.onBookshelf});
  final VoidCallback? onBookshelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(forumAvailabilityProvider);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final eInk = EInkModeScope.of(context);
    final style = eInk
        ? TextButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            animationDuration: Duration.zero,
          )
        : null;
    return SafeArea(
      bottom: false,
      child: Material(
        color: eInk ? scheme.surface : scheme.surfaceContainer,
        shape: eInk
            ? Border(
                bottom: BorderSide(
                  color: AppTheme.eInkBorderColor(scheme.brightness),
                ),
              )
            : null,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(switch (availability.mode) {
                  ForumAccessMode.offline => l10n.networkOffline,
                  ForumAccessMode.manual => l10n.networkForceCache,
                  _ => l10n.networkMaintenance,
                }),
                TextButton(
                  style: style,
                  onPressed: () => availability.retry(
                    ref.read(yamiboHttpGatewayProvider).probeAvailability,
                  ),
                  child: Text(l10n.networkRetry),
                ),
                if (availability.connected)
                  TextButton(
                    style: style,
                    onPressed: () => availability.setManual(false),
                    child: Text(l10n.networkLeave),
                  ),
                if (onBookshelf != null)
                  TextButton(
                    style: style,
                    onPressed: onBookshelf,
                    child: Text(l10n.appNavigationBookshelf),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
