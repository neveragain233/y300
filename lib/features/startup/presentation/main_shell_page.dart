import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/clipboard/forum_clipboard_link_host.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/main_destination_page.dart';
import 'package:y300/app/navigation/main_destination_stack.dart';
import 'package:y300/app/navigation/main_navigation_group_presentation.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/app/navigation/main_shell_bottom_inset.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/startup/main_shell_library_gate.dart';
import 'package:y300/app/startup/main_shell_startup_coordinator.dart';
import 'package:y300/app/startup/main_shell_startup_host.dart';
import 'package:y300/app/startup/main_shell_startup_providers.dart';
import 'package:y300/app/startup/message_attention_visibility_host.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_bottom_bar.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/messages/application/message_attention_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_attention_icon.dart';
import 'package:y300/features/more/presentation/more_page.dart';
import 'package:y300/l10n/app_localizations.dart';

/// 主壳保留可配置入口、独立页面状态与自适应详情导航。
///
/// 展示层只投影四入口分组；隐藏、排序与书架成员的偏好仍由原设置快照
/// 决定，切换底栏样式或书架成员不重建已有页面实例。
class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  /// 沉浸式底栏收起时正文底部仍按该高度避让，避免末项跳动。
  static const double _immersiveChromeFallbackHeight = 88;

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
  double? _chromeHeight;
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
    final grouping = MainNavigationGrouping(settings);
    final currentDestination = _resolveCurrentDestination(settings, grouping);
    _currentDestination = currentDestination;
    final activeBrowser = _browsers[currentDestination];
    _builtDestinations.add(currentDestination);
    final attentionState = ref.watch(messageAttentionStateProvider);
    final attention = attentionState.project(
      messagesVisible: settings.isVisible(MainShellDestination.messages),
    );
    final appearance =
        ref.watch(appAppearanceControllerProvider).value ??
        AppAppearanceSettings.defaults();
    // 墨水屏模式固定旧式底栏：常驻实色条比沉浸式透镜稳定，少一次整屏重绘。
    final isImmersive =
        !appearance.eInkMode &&
        appearance.navigationBarStyle == AppNavigationBarStyle.immersive;

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
                  eInkMode: appearance.eInkMode,
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
                final groups = grouping.groups;
                final selectedIndex = groups.indexOf(
                  MainNavigationGrouping.groupFor(currentDestination),
                );
                final l10n = AppLocalizations.of(context);
                MainNavigationItem navigationItem(MainNavigationGroup group) {
                  final showAttention = switch (group) {
                    MainNavigationGroup.messages =>
                      attention.messagesNavigationDot,
                    MainNavigationGroup.forum =>
                      !settings.isVisible(MainShellDestination.messages) &&
                          attentionState.hasAttention,
                    MainNavigationGroup.my =>
                      !settings.isVisible(MainShellDestination.forum) &&
                          attention.moreNavigationDot,
                    _ => false,
                  };
                  return MainNavigationItem(
                    id: group.name,
                    label: group.localizedLabel(l10n),
                    icon: _buildNavigationIcon(
                      group.icon,
                      showAttention: showAttention,
                    ),
                    selectedIcon: _buildNavigationIcon(
                      group.selectedIcon,
                      showAttention: showAttention,
                    ),
                  );
                }

                final items = [
                  for (final group in groups) navigationItem(group),
                ];
                void selectGroup(int index) {
                  _selectDestination(
                    _destinationForGroup(groups[index], grouping),
                  );
                }

                final content = Row(
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
                                      : selectGroup,
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
                );

                final showChrome =
                    !(activeBrowser?.hasDetail ?? false) &&
                    (media.viewInsets.bottom == 0 || selection.isActive);
                final showLegacyBar = !useRail && showChrome;
                final showImmersiveChrome =
                    isImmersive && !useRail && showChrome;
                // 沉浸式正文铺到屏幕底部，覆盖层高度只作为滚动尾部预留，
                // 不压缩视口，内容才能从底栏后方滚过。
                final overlayInset = showImmersiveChrome
                    ? _chromeHeight ??
                          media.padding.bottom + _immersiveChromeFallbackHeight
                    : 0.0;
                final contentBottomPadding = showImmersiveChrome
                    ? 0.0
                    : media.padding.bottom;
                // 正文容器在所有样式下保持同一层结构，切换样式、宽屏侧栏或
                // 键盘显隐时页面实例与滚动位置不因重新挂载而丢失。
                return TransientFeedbackLayout(
                  bottomOverlap: overlayInset,
                  child: Scaffold(
                    // 玻璃来源由应用根 AppGlassEnvironment 提供，主壳不再自建
                    // scope/host，菜单、面板与分栏详情共用同一捕获。
                    body: Stack(
                      children: [
                        Positioned.fill(
                          child: MediaQuery(
                            data: media.copyWith(
                              padding: media.padding.copyWith(
                                bottom: contentBottomPadding,
                              ),
                            ),
                            child: MainShellBottomInset(
                              bottom: overlayInset,
                              child: content,
                            ),
                          ),
                        ),
                        if (showImmersiveChrome)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _BottomChromeSizeReporter(
                              onHeight: _updateChromeHeight,
                              child: ShelfSelectionBottomBar(
                                fallback: MainNavigationCapsule(
                                  items: items,
                                  selectedIndex: selectedIndex,
                                  glassLevel: appearance.glassLevel,
                                  swipeEnabled:
                                      appearance.navigationSwipeEnabled &&
                                      !selection.isActive,
                                  dragFromSelection: appearance
                                      .navigationLensMotion
                                      .dragFromSelection,
                                  onSelected: selection.isActive
                                      ? null
                                      : selectGroup,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    bottomNavigationBar: useRail
                        ? const ShelfSelectionBottomBar()
                        : isImmersive
                        ? null
                        : ShelfSelectionBottomBar(
                            fallback: Offstage(
                              offstage: !showLegacyBar,
                              child: ExcludeFocus(
                                excluding: !showLegacyBar,
                                child: NavigationBar(
                                  key: const ValueKey<String>(
                                    'main-shell-navigation-bar',
                                  ),
                                  animationDuration:
                                      appearance.eInkMode ||
                                          media.disableAnimations
                                      ? Duration.zero
                                      : null,
                                  selectedIndex: selectedIndex,
                                  onDestinationSelected: selectGroup,
                                  destinations: [
                                    for (
                                      var index = 0;
                                      index < groups.length;
                                      index++
                                    )
                                      NavigationDestination(
                                        key: ValueKey<String>(
                                          'main-shell-destination-${groups[index].name}',
                                        ),
                                        icon: items[index].icon,
                                        selectedIcon: items[index].selectedIcon,
                                        label: groups[index].localizedLabel(
                                          l10n,
                                        ),
                                      ),
                                  ],
                                ),
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

  void _updateChromeHeight(double height) {
    if (!mounted) return;
    final current = _chromeHeight;
    if (current != null && (current - height).abs() < 0.5) return;
    setState(() {
      _chromeHeight = height;
    });
  }

  MainShellDestination _destinationForGroup(
    MainNavigationGroup group,
    MainNavigationGrouping grouping,
  ) {
    return grouping.destinationFor(group);
  }

  void _selectDestination(MainShellDestination destination) {
    if (destination == _currentDestination) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentDestination = destination;
      _builtDestinations.add(destination);
    });
  }

  MainShellDestination _resolveCurrentDestination(
    MainNavigationSettings settings,
    MainNavigationGrouping grouping,
  ) {
    final current = _currentDestination;
    if (current != null) {
      final group = MainNavigationGrouping.groupFor(current);
      if (group == MainNavigationGroup.my) {
        return MainShellDestination.more;
      }
      if (group == MainNavigationGroup.bookshelf) {
        if (grouping.bookshelfDestinations.isNotEmpty) {
          return grouping.bookshelfDestinations.first;
        }
      } else if (settings.isVisible(current)) {
        return current;
      }
    }
    if (current == null) return grouping.startupDestination;
    final firstGroup = grouping.groups.first;
    return grouping.destinationFor(firstGroup, preferredBookshelf: current);
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
          if (!_builtDestinations.contains(destination)) {
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

/// 覆盖层高度只在布局完成后上报，正文避让随实际尺寸更新一次。
class _BottomChromeSizeReporter extends SingleChildRenderObjectWidget {
  const _BottomChromeSizeReporter({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBottomChromeSize(onHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBottomChromeSize renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderBottomChromeSize extends RenderProxyBox {
  _RenderBottomChromeSize(this.onHeight);

  ValueChanged<double> onHeight;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_lastHeight == height) return;
    _lastHeight = height;
    final callback = onHeight;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback(height));
  }
}
