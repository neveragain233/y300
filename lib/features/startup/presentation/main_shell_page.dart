import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/clipboard/forum_clipboard_link_host.dart';
import 'package:y300/app/navigation/main_destination_page.dart';
import 'package:y300/app/navigation/main_destination_stack.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/app/navigation/main_shell_destination_presentation.dart';
import 'package:y300/app/startup/main_shell_startup_coordinator.dart';
import 'package:y300/app/startup/main_shell_startup_host.dart';
import 'package:y300/app/startup/main_shell_library_gate.dart';
import 'package:y300/app/startup/main_shell_startup_providers.dart';
import 'package:y300/app/startup/message_attention_visibility_host.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_bottom_bar.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/more/presentation/more_page.dart';
import 'package:y300/features/messages/application/message_attention_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_attention_icon.dart';
import 'package:y300/l10n/app_localizations.dart';

/// 主壳保留可配置入口、独立页面状态与自适应详情导航。
class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  final _browsers = <MainShellDestination, AdaptiveDetailController>{
    for (final destination in [
      MainShellDestination.forum,
      MainShellDestination.favorites,
      MainShellDestination.comic,
      MainShellDestination.novel,
      MainShellDestination.history,
    ])
      destination: AdaptiveDetailController(),
  };
  AdaptiveDetailController get _forumBrowser =>
      _browsers[MainShellDestination.forum]!;
  Offset _contentGlobalOrigin = Offset.zero;
  MainShellDestination? _currentDestination;
  final Set<MainShellDestination> _builtDestinations = <MainShellDestination>{};
  late final MainShellStartupCoordinator _startup;
  late final Future<void> _coverMigrationReady;

  @override
  void initState() {
    super.initState();
    _startup = ref.read(mainShellStartupCoordinatorFactoryProvider).call();
    _coverMigrationReady = _startup.start();
  }

  @override
  void dispose() {
    for (final browser in _browsers.values) {
      browser.dispose();
    }
    _startup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mainShellLibraryReadinessProvider.overrideWithValue(
          _coverMigrationReady,
        ),
      ],
      child: MainShellStartupHost(
        child: FutureBuilder<void>(
          future: _coverMigrationReady,
          builder: (context, snapshot) {
            final libraryReady =
                snapshot.connectionState == ConnectionState.done;
            return MainShellReadyTaskHost(
              isReady: libraryReady,
              child: _buildReadyShell(context, isReady: libraryReady),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadyShell(BuildContext context, {required bool isReady}) {
    final navigationState = ref
        .watch(mainNavigationSettingsControllerProvider)
        .value;
    if (navigationState == null) {
      return const Scaffold(
        body: SizedBox.expand(key: Key('main-shell-navigation-loading')),
      );
    }
    final settings = navigationState.settings;
    final visibleDestinations = settings.visibleDestinations;
    final visibleSet = visibleDestinations.toSet();
    _builtDestinations.removeWhere(
      (destination) => !visibleSet.contains(destination),
    );
    final currentDestination = _resolveCurrentDestination(settings);
    _currentDestination = currentDestination;
    final activeBrowser = _browsers[currentDestination];
    _builtDestinations.add(currentDestination);
    final attention = ref
        .watch(messageAttentionStateProvider)
        .project(
          messagesVisible: settings.isVisible(MainShellDestination.messages),
        );

    final selection = ref.watch(shelfSelectionHostControllerProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([selection, ..._browsers.values]),
      builder: (context, _) => AdaptiveDetailDispatchScope(
        controller: activeBrowser ?? _forumBrowser,
        enabled: activeBrowser != null,
        child: ForumClipboardLinkHost(
          isReady: isReady,
          allowPrompt: !selection.isActive,
          builder: (context) => MessageAttentionVisibilityHost(
            isMoreSelected: currentDestination == MainShellDestination.more,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final media = MediaQuery.of(context);
                final useRail = AppWindowLayout(
                  size: Size(
                    constraints.maxWidth - media.padding.horizontal,
                    constraints.maxHeight -
                        media.viewInsets.bottom -
                        media.padding.vertical,
                  ),
                  displayFeatures: media.displayFeatures,
                ).useNavigationRail;
                final railWidth = 80 + media.viewPadding.left;
                _contentGlobalOrigin = Offset(useRail ? railWidth : 0, 0);
                final showBottom =
                    !useRail &&
                    media.viewInsets.bottom == 0 &&
                    !(activeBrowser?.hasDetail ?? false);
                void select(int index) {
                  final destination = visibleDestinations[index];
                  if (destination == _currentDestination) return;
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _currentDestination = destination;
                    _builtDestinations.add(destination);
                  });
                }

                final selectedIndex = visibleDestinations.indexOf(
                  currentDestination,
                );

                bool needsAttention(MainShellDestination destination) =>
                    switch (destination) {
                      MainShellDestination.messages =>
                        attention.messagesNavigationDot,
                      MainShellDestination.more => attention.moreNavigationDot,
                      _ => false,
                    };
                final items = [
                  for (final destination in visibleDestinations)
                    MainNavigationItem(
                      id: destination.name,
                      label: destination.localizedLabel(
                        AppLocalizations.of(context),
                      ),
                      icon: _buildNavigationIcon(
                        destination.icon,
                        showAttention: needsAttention(destination),
                      ),
                      selectedIcon: _buildNavigationIcon(
                        destination.selectedIcon,
                        showAttention: needsAttention(destination),
                      ),
                    ),
                ];
                return Scaffold(
                  body: Row(
                    children: [
                      Offstage(
                        offstage: !useRail,
                        child: SizedBox(
                          width: railWidth,
                          child: ExcludeFocus(
                            excluding: selection.isActive,
                            child: items.length < 2
                                ? const SizedBox.shrink()
                                : MainNavigationRail(
                                    items: items,
                                    selectedIndex: selectedIndex,
                                    onSelected: selection.isActive
                                        ? null
                                        : select,
                                  ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: MainDestinationStack(
                          index: MainShellDestination.values.indexOf(
                            currentDestination,
                          ),
                          children: _buildIndexedPages(
                            settings,
                            currentDestination: currentDestination,
                          ),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: ShelfSelectionBottomBar(
                    fallback: Offstage(
                      offstage: !showBottom,
                      child: ExcludeFocus(
                        excluding: !showBottom,
                        child: NavigationBar(
                          key: const ValueKey<String>(
                            'main-shell-navigation-bar',
                          ),
                          selectedIndex: selectedIndex,
                          onDestinationSelected: select,
                          destinations: [
                            for (final destination in visibleDestinations)
                              _buildNavigationDestination(
                                destination,
                                showAttention: needsAttention(destination),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  MainShellDestination _resolveCurrentDestination(
    MainNavigationSettings settings,
  ) {
    final current = _currentDestination;
    if (current != null && settings.visibleDestinations.contains(current)) {
      return current;
    }
    return settings.visibleManagedDestinations.first;
  }

  NavigationDestination _buildNavigationDestination(
    MainShellDestination destination, {
    required bool showAttention,
  }) {
    return NavigationDestination(
      key: ValueKey<String>('main-shell-destination-${destination.name}'),
      icon: _buildNavigationIcon(
        destination.icon,
        showAttention: showAttention,
      ),
      selectedIcon: _buildNavigationIcon(
        destination.selectedIcon,
        showAttention: showAttention,
      ),
      label: destination.localizedLabel(AppLocalizations.of(context)),
    );
  }

  Widget _buildNavigationIcon(IconData icon, {required bool showAttention}) {
    return MessageAttentionIcon(icon: icon, showAttention: showAttention);
  }

  List<Widget> _buildIndexedPages(
    MainNavigationSettings settings, {
    required MainShellDestination currentDestination,
  }) {
    return MainShellDestination.values
        .map((destination) {
          if (!settings.isVisible(destination) ||
              !_builtDestinations.contains(destination)) {
            return SizedBox.shrink(
              key: ValueKey<String>('main-shell-empty-${destination.name}'),
            );
          }
          final isActive = destination == currentDestination;
          return KeyedSubtree(
            key: ValueKey<String>('main-shell-page-${destination.name}'),
            child: TickerMode(
              enabled: isActive,
              child: _buildPage(destination, isActive: isActive),
            ),
          );
        })
        .toList(growable: false);
  }

  Widget _buildPage(
    MainShellDestination destination, {
    required bool isActive,
  }) {
    return switch (destination) {
      MainShellDestination.more => const MorePage(),
      _ => MainDestinationPage(
        destination: destination,
        isActive: isActive,
        browserController: _browsers[destination],
        globalOrigin: _contentGlobalOrigin,
      ),
    };
  }
}
