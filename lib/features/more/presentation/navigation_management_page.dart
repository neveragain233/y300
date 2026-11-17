import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/app/navigation/main_destination_page.dart';
import 'package:y300/app/navigation/main_navigation_group_presentation.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

class NavigationManagementPage extends ConsumerWidget {
  const NavigationManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(mainNavigationSettingsControllerProvider);
    final currentState = asyncState.value;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      mainNavigationSettingsControllerProvider.notifier,
    );
    return Scaffold(
      key: const Key('navigation-management-page'),
      appBar: AppPageAppBar(
        title: l10n.moreNavigationManagement,
        actions: [
          IconButton(
            key: const Key('navigation-management-reset'),
            tooltip: l10n.moreNavigationRestoreDefault,
            onPressed: currentState == null || currentState.isSaving
                ? null
                : () => unawaited(
                    _runMutation(context, controller.resetToDefaults),
                  ),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            key: const Key('navigation-management-load-retry'),
            onPressed: () =>
                ref.invalidate(mainNavigationSettingsControllerProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.moreNavigationRetry),
          ),
        ),
        data: (state) {
          final order = MainNavigationGrouping.configurableGroups(
            state.settings,
          );
          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AppGroupedSection(
                      children: [
                        AppGroupedRow(
                          title: l10n.navigationStartupPage,
                          trailing: DropdownButton<MainStartupPage>(
                            key: const Key('navigation-startup-page'),
                            value: state.settings.startupPage,
                            items: [
                              DropdownMenuItem(
                                value: MainStartupPage.forum,
                                child: Text(l10n.appNavigationForum),
                              ),
                              DropdownMenuItem(
                                value: MainStartupPage.bookshelf,
                                child: Text(l10n.appNavigationBookshelf),
                              ),
                            ],
                            onChanged: state.isSaving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      unawaited(
                                        _runMutation(
                                          context,
                                          () =>
                                              controller.setStartupPage(value),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      key: const Key('navigation-management-list'),
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: order.length,
                      onReorderItem: state.isSaving
                          ? (_, _) {}
                          : (oldIndex, newIndex) => unawaited(
                              _runMutation(
                                context,
                                () =>
                                    controller.reorderGroup(oldIndex, newIndex),
                              ),
                            ),
                      itemBuilder: (context, index) {
                        final destination = order[index];
                        final visible = MainNavigationGrouping.members(
                          destination,
                        ).any(state.settings.isVisible);
                        return Padding(
                          key: ValueKey<String>(
                            'navigation-management-item-${destination.name}',
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: AppGroupedSection(
                            margin: EdgeInsets.zero,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppGroupedRow(
                                      key: ValueKey<String>(
                                        'navigation-management-open-${destination.name}',
                                      ),
                                      onTap: () => Navigator.of(context).push(
                                        ref.read(
                                          mainDestinationRouteFactoryProvider,
                                        )(
                                          MainNavigationGrouping.members(
                                            destination,
                                          ).first,
                                        ),
                                      ),
                                      leading: Icon(destination.icon),
                                      title: destination.localizedLabel(l10n),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 16,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          key: ValueKey<String>(
                                            'navigation-management-visible-${destination.name}',
                                          ),
                                          value: visible,
                                          onChanged: state.isSaving
                                              ? null
                                              : (nextVisible) => unawaited(
                                                  _runMutation(
                                                    context,
                                                    () => controller
                                                        .setGroupVisibility(
                                                          destination,
                                                          nextVisible,
                                                        ),
                                                  ),
                                                ),
                                        ),
                                        Tooltip(
                                          message:
                                              l10n.moreNavigationDragToReorder,
                                          child: ReorderableDragStartListener(
                                            key: ValueKey<String>(
                                              'navigation-management-drag-${destination.name}',
                                            ),
                                            index: index,
                                            enabled: !state.isSaving,
                                            child: const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Icon(Icons.drag_handle),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (state.isSaving)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    key: Key('navigation-management-saving'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runMutation(
    BuildContext context,
    Future<void> Function() mutation,
  ) async {
    try {
      await mutation();
    } on MainNavigationMinimumVisibleException {
      if (context.mounted) {
        showTransientSnackBar(
          context,
          AppLocalizations.of(context).moreNavigationMinimumOneRequired,
        );
      }
    } on MainNavigationMutationInProgressException {
      // Controls are disabled while saving; ignore a callback already queued
      // by the previous frame.
    } catch (_) {
      if (context.mounted) {
        showTransientSnackBar(
          context,
          AppLocalizations.of(context).moreNavigationSaveFailed,
        );
      }
    }
  }
}
