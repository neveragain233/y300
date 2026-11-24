import 'dart:async';

import 'package:flutter/material.dart';
import 'package:y300/app/startup/restore_active_reader.dart';
import 'package:y300/core/network/forum_availability.dart';
import 'package:y300/features/forum/presentation/forum_home_controller.dart';
import 'package:y300/features/reader_shared/application/active_reader_session.dart';
import 'package:y300/features/startup/presentation/widgets/forum_availability_banner.dart';
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
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/startup/main_shell_library_gate.dart';
import 'package:y300/app/startup/main_shell_startup_coordinator.dart';
import 'package:y300/app/startup/main_shell_startup_host.dart';
import 'package:y300/app/startup/main_shell_startup_providers.dart';
import 'package:y300/app/startup/message_attention_visibility_host.dart';
import 'package:y300/core/motion/app_motion.dart';
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
  double? _railBannerHeight;
  bool _interfacesReady = false;
  bool _restoreAttempted = false;
  int _navigationRevision = 0;
  late final MainShellStartupCoordinator _startup;
  final _libraryReadiness = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    ref.read(forumAvailabilityProvider).ready.then((_) {
      if (mounted) setState(() => _interfacesReady = true);
    });
    _forumBrowser.addListener(_forumDetailChanged);
    _startup = ref.read(mainShellStartupCoordinatorFactoryProvider).call();
    unawaited(
      _startup.start().then((_) {
        if (mounted) _libraryReadiness.value = true;
      }),
    );
  }

  void _forumDetailChanged() {
    if (_currentDestination == MainShellDestination.forum &&
        ref.read(forumAvailabilityProvider).mode == ForumAccessMode.offline) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _forumBrowser.removeListener(_forumDetailChanged);
    for (final browser in _browsers.values) {
      browser.dispose();
    }
    _startup.dispose();
    _libraryReadiness.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mainShellLibraryReadinessProvider.overrideWithValue(_libraryReadiness),
      ],
      child: MainShellStartupHost(
        child: ValueListenableBuilder<bool>(
          valueListenable: _libraryReadiness,
          builder: (context, libraryReady, _) {
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
    if (navigationState == null || !_interfacesReady) {
      return const Scaffold(
        body: SizedBox.expand(key: Key('main-shell-navigation-loading')),
      );
    }
    if (isReady && !_restoreAttempted) {
      _restoreAttempted = true;
      final revision = _navigationRevision;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _restoreReader(revision),
      );
    }
    final availability = ref.watch(forumAvailabilityProvider);
    final offline = availability.mode == ForumAccessMode.offline;
    final saved = navigationState.settings;
    final hidden = {...saved.hiddenDestinations};
    if (offline) hidden.add(MainShellDestination.forum);
    if (availability.blocked &&
        hidden.containsAll([
          MainShellDestination.comic,
          MainShellDestination.novel,
        ])) {
      hidden.remove(MainShellDestination.comic);
    }
    final settings = availability.blocked
        ? saved.copyWith(
            hiddenDestinations: hidden,
            startupPage: MainStartupPage.bookshelf,
          )
        : saved;
    final grouping = MainNavigationGrouping(settings);
    final offlineForum =
        offline && _currentDestination == MainShellDestination.forum;
    final keepForum =
        offlineForum &&
        (_forumBrowser.hasDetail ||
            (ref.exists(forumHomeControllerProvider) &&
                ref.read(forumHomeControllerProvider).hasValue));
    final currentDestination = keepForum
        ? MainShellDestination.forum
        : offlineForum
        ? grouping.startupDestination
        : _resolveCurrentDestination(settings, grouping);
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

                final onBookshelf =
                    currentDestination == MainShellDestination.forum
                    ? () => _selectDestination(
                        grouping.destinationFor(MainNavigationGroup.bookshelf),
                      )
                    : null;
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
                final immersiveChrome = isImmersive && !useRail
                    ? _AnimatedImmersiveBottomChrome(
                        visible: showImmersiveChrome,
                        child: _BottomChromeSizeReporter(
                          onHeight: _updateChromeHeight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (availability.blocked)
                                _ImmersiveFloatingAvailabilityBanner(
                                  glassLevel: appearance.glassLevel,
                                  bottomGap:
                                      selection.isActive || selectedIndex < 0
                                      ? 8
                                      : 0,
                                  onBookshelf: onBookshelf,
                                ),
                              ShelfSelectionBottomBar(
                                fallback: selectedIndex < 0
                                    ? MainLegacyNavigationBar(
                                        items: items,
                                        selectedIndex: selectedIndex,
                                        onSelected: selectGroup,
                                      )
                                    : MainNavigationCapsule(
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
                                        onReselected: selection.isActive
                                            ? null
                                            : selectGroup,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null;
                final chromeHeight =
                    _chromeHeight ??
                    media.padding.bottom + _immersiveChromeFallbackHeight;
                // 源页底部预留高度在打开详情页时保持稳定，避免退回主壳瞬间把书架 FAB 顶起；
                // 详情页内部在 AdaptiveDetailHost 中归零覆盖，提示条避让只看底栏当前可见性。
                final keepSourceImmersiveInset =
                    isImmersive &&
                    !useRail &&
                    (media.viewInsets.bottom == 0 || selection.isActive);
                final sourceOverlayInset = keepSourceImmersiveInset
                    ? chromeHeight
                    : 0.0;
                final fabBottomInset = useRail
                    ? 0.0
                    : (isImmersive
                          ? chromeHeight
                          : media.padding.bottom + 72.0);
                final feedbackBottomOverlap = useRail
                    ? (showChrome && availability.blocked
                          ? (_railBannerHeight ?? media.padding.bottom + 50.0)
                          : 0.0)
                    : (showImmersiveChrome ? chromeHeight : 0.0);
                final contentBottomPadding = showImmersiveChrome
                    ? 0.0
                    : media.padding.bottom;
                // 正文容器在所有样式下保持同一层结构，切换样式、宽屏侧栏或
                // 键盘显隐时页面实例与滚动位置不因重新挂载而丢失。
                return TransientFeedbackLayout(
                  bottomOverlap: feedbackBottomOverlap,
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
                              bottom: sourceOverlayInset,
                              fabBottom: fabBottomInset,
                              child: content,
                            ),
                          ),
                        ),
                        if (immersiveChrome != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: immersiveChrome,
                          ),
                        if (useRail && availability.blocked)
                          PositionedDirectional(
                            start: railWidth,
                            end: 0,
                            bottom: 0,
                            child: _AnimatedImmersiveBottomChrome(
                              visible: showChrome,
                              child: _BottomChromeSizeReporter(
                                onHeight: _updateRailBannerHeight,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom:
                                        (selection.isActive
                                            ? 0.0
                                            : media.padding.bottom) +
                                        12.0,
                                  ),
                                  child: Center(
                                    heightFactor: 1,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 560,
                                      ),
                                      child: ForumAvailabilityBanner(
                                        variant: ForumAvailabilityBannerVariant
                                            .floating,
                                        glassLevel: appearance.glassLevel,
                                        onBookshelf: onBookshelf,
                                      ),
                                    ),
                                  ),
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
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (availability.blocked)
                                Offstage(
                                  offstage: !showLegacyBar,
                                  child: ExcludeFocus(
                                    excluding: !showLegacyBar,
                                    child: ForumAvailabilityBanner(
                                      variant:
                                          ForumAvailabilityBannerVariant.docked,
                                      onBookshelf: onBookshelf,
                                    ),
                                  ),
                                ),
                              ShelfSelectionBottomBar(
                                fallback: Offstage(
                                  offstage: !showLegacyBar,
                                  child: ExcludeFocus(
                                    excluding: !showLegacyBar,
                                    child: MainLegacyNavigationBar(
                                      key: const ValueKey<String>(
                                        'main-shell-navigation-bar',
                                      ),
                                      items: items,
                                      selectedIndex: selectedIndex,
                                      onSelected: selectGroup,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  void _updateRailBannerHeight(double height) {
    if (!mounted) return;
    final current = _railBannerHeight;
    if (current != null && (current - height).abs() < 0.5) return;
    setState(() {
      _railBannerHeight = height;
    });
  }

  MainShellDestination _destinationForGroup(
    MainNavigationGroup group,
    MainNavigationGrouping grouping,
  ) {
    return grouping.destinationFor(group);
  }

  Future<void> _restoreReader(int revision) async {
    bool current() =>
        mounted &&
        _navigationRevision == revision &&
        ModalRoute.of(context)?.isCurrent != false &&
        !_browsers.values.any((item) => item.hasDetail);
    try {
      if (!current() ||
          !await ref.read(restoreReaderPreferenceProvider.future) ||
          !current()) {
        return;
      }
      final target = await ref.read(activeReaderSessionsProvider).consume();
      if (target == null || !current()) return;
      final page = await ref.read(readerRestorePageProvider)(target);
      if (!mounted ||
          page == null ||
          !current() ||
          ref.read(restoreReaderPreferenceProvider).value != true) {
        return;
      }
      if (ref.read(forumAvailabilityProvider).blocked) {
        setState(() => _currentDestination = MainShellDestination.comic);
      }
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
    } on Object {
      // 已消费的失效目标回到主壳。
    }
  }

  void _selectDestination(MainShellDestination destination) {
    _navigationRevision++;
    if (destination == _currentDestination) {
      _reselectDestination(destination);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentDestination = destination;
      _builtDestinations.add(destination);
    });
  }

  void _reselectDestination(MainShellDestination destination) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_browsers[destination]?.resetToRoot());
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

class _ImmersiveFloatingAvailabilityBanner extends StatelessWidget {
  const _ImmersiveFloatingAvailabilityBanner({
    required this.glassLevel,
    required this.bottomGap,
    required this.onBookshelf,
  });

  final AppGlassLevel glassLevel;
  final double bottomGap;
  final VoidCallback? onBookshelf;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final region = AppWindowLayout(
          size: Size(constraints.maxWidth, media.size.height),
          displayFeatures: media.displayFeatures,
        ).readingRegion;
        return Padding(
          padding: EdgeInsets.only(
            left: region.left + 16,
            right: (constraints.maxWidth - region.right) + 16,
            bottom: bottomGap,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ForumAvailabilityBanner(
                variant: ForumAvailabilityBannerVariant.floating,
                glassLevel: glassLevel,
                onBookshelf: onBookshelf,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 沉浸式底栏显隐过渡：进出详情页和键盘弹起时下沉淡出／上滑淡入，
/// 墨水屏或系统减动效时瞬时切换。隐藏完成后离台，不参与玻璃采样或测试命中。
class _AnimatedImmersiveBottomChrome extends StatefulWidget {
  const _AnimatedImmersiveBottomChrome({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<_AnimatedImmersiveBottomChrome> createState() =>
      _AnimatedImmersiveBottomChromeState();
}

class _AnimatedImmersiveBottomChromeState
    extends State<_AnimatedImmersiveBottomChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 190),
      value: widget.visible ? 1.0 : 0.0,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context) && _controller.isAnimating) {
      _controller.value = widget.visible ? 1.0 : 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedImmersiveBottomChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }
    if (AppMotion.reduceMotion(context)) {
      _controller.value = widget.visible ? 1.0 : 0.0;
      return;
    }
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: ExcludeSemantics(
          excluding: !widget.visible,
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(position: _offset, child: widget.child),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, animatedChild) =>
          Offstage(offstage: _controller.isDismissed, child: animatedChild),
      child: child,
    );
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
