import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/profile/presentation/daily_sign_in_controller.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

/// Loads only the account preference; displaying this control never checks
/// remote sign-in status or starts an automatic attempt.
class DailyAutoSignInToggle extends ConsumerWidget {
  const DailyAutoSignInToggle({super.key, this.expand = false});

  /// Whether the toggle expands across the full row width with the switch
  /// anchored at the trailing edge.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(verifiedSessionOwnerProvider);
    final state = ref.watch(dailySignInControllerProvider);
    if (owner == null || state.owner != owner) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canChange =
        state.autoEnabled != null &&
        !state.isSavingAutoPreference &&
        !state.settingsUnavailable;
    final label = Text(
      l10n.dailyAutoSignInToggle,
      style: expand
          ? theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            )
          : theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
    return MergeSemantics(
      child: Tooltip(
        message: state.settingsUnavailable
            ? l10n.dailyAutoSignInStorageUnavailable
            : state.isSavingAutoPreference
            ? l10n.dailyAutoSignInSaving
            : l10n.dailyAutoSignInDescription,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (expand) Expanded(child: label) else Flexible(child: label),
            SizedBox(width: expand ? 8 : 4),
            if (state.autoEnabled == null && !state.settingsUnavailable)
              // Reserve the adaptive control's space without showing an
              // invented off state. Mount the real switch only when known,
              // so its first frame does not animate from disabled to enabled.
              const Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: AppSwitch(value: false, onChanged: null),
              )
            else
              AppSwitch(
                key: const Key('daily-auto-sign-in-toggle'),
                value: state.autoEnabled ?? false,
                onChanged: canChange
                    ? (value) => _setEnabled(context, ref, owner, value)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    VerifiedSessionOwner owner,
    bool value,
  ) async {
    if (ref.read(verifiedSessionOwnerProvider) != owner) return;
    await ref
        .read(dailySignInControllerProvider.notifier)
        .setAutomaticEnabled(value);
    if (!context.mounted || ref.read(verifiedSessionOwnerProvider) != owner) {
      return;
    }
    if (ref.read(dailySignInControllerProvider).settingsUnavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).dailyAutoSignInStorageUnavailable,
          ),
        ),
      );
    }
  }
}
