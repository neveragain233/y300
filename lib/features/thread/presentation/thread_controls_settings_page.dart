import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../domain/models/thread_controls_preferences.dart';
import 'thread_controls_preferences_controller.dart';

class ThreadControlsSettingsPage extends ConsumerWidget {
  const ThreadControlsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferences = ref
        .watch(threadControlsPreferencesControllerProvider)
        .value;
    Future<void> save(ThreadControlsPreferences next) async {
      final saved = await ref
          .read(threadControlsPreferencesControllerProvider.notifier)
          .savePreferences(next);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.threadControlsSaveFailed)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.threadControlsTitle)),
      body: preferences == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SwitchListTile(
                  key: const Key('thread-controls-compact-setting'),
                  title: Text(l10n.threadControlsCompact),
                  value: preferences.compact,
                  onChanged: (value) =>
                      save(preferences.copyWith(compact: value)),
                ),
                if (preferences.compact) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: DropdownButtonFormField<ThreadControlsSide>(
                      key: ValueKey(preferences.side),
                      initialValue: preferences.side,
                      decoration: InputDecoration(
                        labelText: l10n.threadControlsSide,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ThreadControlsSide.left,
                          child: Text(l10n.threadControlsLeft),
                        ),
                        DropdownMenuItem(
                          value: ThreadControlsSide.right,
                          child: Text(l10n.threadControlsRight),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          save(preferences.copyWith(side: value));
                        }
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: Text(l10n.threadControlsFavorite),
                    value: preferences.showFavorite,
                    onChanged: (value) =>
                        save(preferences.copyWith(showFavorite: value)),
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  title: Text(l10n.threadControlsNavigation),
                  value: preferences.navigationEnabled,
                  onChanged: (value) =>
                      save(preferences.copyWith(navigationEnabled: value)),
                ),
                if (preferences.navigationEnabled) ...[
                  SwitchListTile(
                    title: Text(l10n.threadControlsSingleNavigation),
                    value: preferences.singleNavigationButton,
                    onChanged: (value) => save(
                      preferences.copyWith(singleNavigationButton: value),
                    ),
                  ),
                  if (preferences.singleNavigationButton)
                    SwitchListTile(
                      title: Text(l10n.threadControlsHoldToFirst),
                      subtitle: Text(l10n.threadControlsHoldToFirstHint),
                      value: preferences.holdToFirstPost,
                      onChanged: (value) =>
                          save(preferences.copyWith(holdToFirstPost: value)),
                    ),
                ],
                const Divider(),
                SwitchListTile(
                  key: const Key('thread-controls-hide-on-scroll-setting'),
                  title: Text(l10n.threadControlsHideOnScroll),
                  subtitle: Text(l10n.threadControlsHideOnScrollHint),
                  value: preferences.hideOnScroll,
                  onChanged: (value) =>
                      save(preferences.copyWith(hideOnScroll: value)),
                ),
              ],
            ),
    );
  }
}
