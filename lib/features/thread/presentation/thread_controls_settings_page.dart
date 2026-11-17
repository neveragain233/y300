import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

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
      appBar: AppPageAppBar(title: l10n.threadControlsTitle),
      body: preferences == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const Key('thread-controls-settings-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppGroupedSection(
                  title: l10n.threadControlsGroupDisplay,
                  children: [
                    AppSwitchRow(
                      key: const Key('thread-controls-compact-setting'),
                      leading: const Icon(Icons.compress),
                      title: l10n.threadControlsCompact,
                      value: preferences.compact,
                      onChanged: (value) =>
                          save(preferences.copyWith(compact: value)),
                    ),
                    if (preferences.compact) ...[
                      AppGroupedRow(
                        leading: const Icon(Icons.swap_horiz),
                        title: l10n.threadControlsSide,
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<ThreadControlsSide>(
                            key: ValueKey(preferences.side),
                            value: preferences.side,
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
                      ),
                      AppSwitchRow(
                        leading: const Icon(Icons.star_outline),
                        title: l10n.threadControlsFavorite,
                        value: preferences.showFavorite,
                        onChanged: (value) =>
                            save(preferences.copyWith(showFavorite: value)),
                      ),
                    ],
                  ],
                ),
                AppGroupedSection(
                  title: l10n.threadControlsGroupNavigation,
                  children: [
                    AppSwitchRow(
                      leading: const Icon(Icons.unfold_more),
                      title: l10n.threadControlsNavigation,
                      value: preferences.navigationEnabled,
                      onChanged: (value) =>
                          save(preferences.copyWith(navigationEnabled: value)),
                    ),
                    if (preferences.navigationEnabled)
                      AppSwitchRow(
                        leading: const Icon(Icons.touch_app_outlined),
                        title: l10n.threadControlsSingleNavigation,
                        value: preferences.singleNavigationButton,
                        onChanged: (value) => save(
                          preferences.copyWith(singleNavigationButton: value),
                        ),
                      ),
                    if (preferences.navigationEnabled &&
                        preferences.singleNavigationButton)
                      AppSwitchRow(
                        leading: const Icon(Icons.timer_outlined),
                        title: l10n.threadControlsHoldToFirst,
                        subtitle: l10n.threadControlsHoldToFirstHint,
                        value: preferences.holdToFirstPost,
                        onChanged: (value) =>
                            save(preferences.copyWith(holdToFirstPost: value)),
                      ),
                  ],
                ),
                AppGroupedSection(
                  title: l10n.threadControlsGroupScrolling,
                  children: [
                    AppSwitchRow(
                      key: const Key('thread-controls-hide-on-scroll-setting'),
                      leading: const Icon(Icons.swipe_vertical_outlined),
                      title: l10n.threadControlsHideOnScroll,
                      subtitle: l10n.threadControlsHideOnScrollHint,
                      value: preferences.hideOnScroll,
                      onChanged: (value) =>
                          save(preferences.copyWith(hideOnScroll: value)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
