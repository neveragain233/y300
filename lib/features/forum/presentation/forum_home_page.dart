import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/eink_paging.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:y300/app/navigation/main_shell_bottom_inset.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/navigation/forum_link_opener.dart';
import 'package:y300/app/navigation/main_destination_page.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/features/messages/application/message_attention_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_attention_icon.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/document_cache_models.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/domain/services/thread_block_identity.dart';
import 'package:y300/features/favorites/data/providers/favorite_directory_providers.dart';
import 'package:y300/features/forum/data/models/forum_home_chrome_models.dart';
import 'package:y300/features/forum/data/services/forum_home_request_profile_resolver.dart';
import 'package:y300/features/forum/presentation/forum_display_page.dart';
import 'package:y300/features/forum/presentation/forum_content_projection_providers.dart';
import 'package:y300/features/forum/presentation/forum_home_content_projection.dart';
import 'package:y300/features/forum/presentation/forum_home_content_projector.dart';
import 'package:y300/features/forum/presentation/forum_home_controller.dart';
import 'package:y300/features/forum/presentation/forum_home_state.dart';
import 'package:y300/features/forum/presentation/forum_text_resolver.dart';
import 'package:y300/features/forum/presentation/widgets/forum_home_widgets.dart';
import 'package:y300/features/forum/presentation/widgets/forum_favorite_forum_picker.dart';
import 'package:y300/features/search/presentation/forum_search_page.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/thread/domain/services/thread_post_navigation_session.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:y300/shared/widgets/y300_page_scaffold.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/app/localization/app_server_content_conversion_provider.dart';

const Duration _forumHomeSilentRefreshThreshold = Duration(seconds: 60);

class ForumHomePage extends ConsumerStatefulWidget {
  const ForumHomePage({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends ConsumerState<ForumHomePage>
    with WidgetsBindingObserver {
  static const String _refreshPageAction = 'refresh-page';
  static const String _unfavoriteAction = 'unfavorite';
  ProviderSubscription<AsyncValue<AuthSessionViewState>>? _authSubscription;
  String? _lastResolvedAuthContextKey;
  bool _isHandlingAuthContextChange = false;
  bool _isSwitchingAuthContext = false;
  int _authContextGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual<AsyncValue<AuthSessionViewState>>(
      authSessionControllerProvider,
      (previous, next) {
        final nextState = next.asData?.value;
        if (nextState == null) {
          return;
        }
        unawaited(_reconcileAuthContext(nextState));
      },
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant ForumHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_triggerSilentRefreshIfNeeded());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_triggerSilentRefreshIfNeeded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.close();
    _authSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final imageReferer = ref.watch(forumImageRefererProvider);

    return Y300PageScaffold(
      appBar: AppRootPageAppBar(
        title: l10n.forumHomeTitle,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ForumHomeSearchEntry(
                    key: const Key('forum-home-search-button'),
                    label: l10n.forumHomeSearch,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ForumSearchPage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('forum-home-messages-button'),
            tooltip: l10n.moreMyMessages,
            icon: MessageAttentionIcon(
              icon: Icons.mail_outline,
              showAttention: ref
                  .watch(messageAttentionStateProvider)
                  .hasAttention,
            ),
            onPressed: () => Navigator.of(context).push(
              ref.read(mainDestinationRouteFactoryProvider)(
                MainShellDestination.messages,
              ),
            ),
          ),
          IconButton(
            key: const Key('forum-home-history-button'),
            tooltip: l10n.appNavigationHistory,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              ref.read(mainDestinationRouteFactoryProvider)(
                MainShellDestination.history,
              ),
            ),
          ),
          AppPopupMenuButton<String>(
            key: const Key('forum-home-more-button'),
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              unawaited(_handleMoreMenuSelected(context, value));
            },
            itemBuilder: (context) => [
              AppPopupMenuItem<String>(
                key: const Key('forum-home-refresh-action'),
                value: _refreshPageAction,
                label: l10n.forumRefreshPage,
                icon: const Icon(Icons.refresh),
              ),
              AppPopupMenuItem<String>(
                key: const Key('forum-home-unfavorite-action'),
                value: _unfavoriteAction,
                label: l10n.forumUnfavoriteForum,
                icon: const Icon(Icons.star_border),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: LayoutBuilder(
            builder: (context, constraints) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: Size(
                  constraints.maxWidth,
                  MediaQuery.sizeOf(context).height,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage: _isSwitchingAuthContext,
                    child: _ResolvedForumHomeBody(
                      imageReferer: imageReferer,
                      isActive: widget.isActive,
                    ),
                  ),
                  if (_isSwitchingAuthContext) const _ForumHomeBlankBody(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reconcileAuthContext(AuthSessionViewState authState) async {
    final generation = ++_authContextGeneration;
    final localProfile = await ref
        .read(forumHomeRequestProfileResolverProvider)
        .resolve();
    if (!mounted || generation != _authContextGeneration) {
      return;
    }

    final effectiveProfile = authState.isLoggedIn
        ? DocumentRequestProfile.loggedIn
        : localProfile;
    final nextResolvedKey = authState.isLoggedIn
        ? _authContextKey(authState)
        : localProfile == DocumentRequestProfile.anonymous
        ? 'anonymous'
        : null;
    final previousKey = _lastResolvedAuthContextKey;
    final currentProfile = ref
        .read(forumHomeControllerProvider)
        .asData
        ?.value
        .requestProfile;

    var shouldSwitch =
        currentProfile != null && currentProfile != effectiveProfile;
    if (previousKey == null) {
      if (nextResolvedKey != null) {
        _lastResolvedAuthContextKey = nextResolvedKey;
      }
    } else if (nextResolvedKey != null && previousKey != nextResolvedKey) {
      _lastResolvedAuthContextKey = nextResolvedKey;
      shouldSwitch = true;
    }

    // A failed profile probe is not proof of logout while a persisted auth
    // cookie still exists. Keep the verified UID and cached logged-in page;
    // an explicit logout clears the cookie and resolves to anonymous above.
    if (!authState.isLoggedIn &&
        localProfile == DocumentRequestProfile.loggedIn) {
      shouldSwitch = currentProfile == DocumentRequestProfile.anonymous;
    }
    if (!shouldSwitch || _isHandlingAuthContextChange) {
      return;
    }
    await _handleAuthContextChanged();
  }

  Future<void> _handleAuthContextChanged() async {
    if (!mounted || _isHandlingAuthContextChange) {
      return;
    }
    _isHandlingAuthContextChange = true;
    setState(() => _isSwitchingAuthContext = true);
    try {
      await ref
          .read(nativePageCacheInvalidationServiceProvider)
          .invalidateForumHome();
      ref.invalidate(forumHomeControllerProvider);
      // Keep the old account's content hidden until the replacement profile
      // has produced its own cache or network result.
      try {
        await ref.read(forumHomeControllerProvider.future);
      } catch (_) {
        // AsyncNotifier retains the failure for the normal error view.
      }
    } finally {
      _isHandlingAuthContextChange = false;
      if (mounted) {
        setState(() {
          _isSwitchingAuthContext = false;
        });
      }
    }
  }

  Future<void> _handleMoreMenuSelected(
    BuildContext context,
    String action,
  ) async {
    switch (action) {
      case _refreshPageAction:
        await ref
            .read(forumHomeControllerProvider.notifier)
            .refresh(forceNetwork: true);
        return;
      case _unfavoriteAction:
        await _openFavoriteForumPicker(context);
        return;
    }
  }

  Future<void> _openFavoriteForumPicker(BuildContext context) {
    final directoryRepository = ref.read(
      favoriteForumDirectoryRepositoryProvider,
    );
    final favoriteCommand = ref.read(favoriteForumCommandProvider);
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ForumFavoriteForumPicker(
        loadFavoriteForums: () =>
            directoryRepository.load(const FavoriteForumDirectoryQuery()),
        onUnfavorite: (forum) => favoriteCommand.execute(
          SetForumFavoriteRequest(
            fid: forum.fid,
            targetState: FavoriteTargetState.unfavorited,
            knownRemoteFavoriteId: forum.remoteFavoriteId,
          ),
        ),
        onSuccess: (_, _) async {
          if (!mounted) {
            return;
          }
          showTransientSnackBar(context, l10n.forumUnfavoriteSuccess);
          await ref
              .read(forumHomeControllerProvider.notifier)
              .refresh(forceNetwork: true);
        },
      ),
    );
  }

  Future<void> _triggerSilentRefreshIfNeeded() async {
    if (!mounted) {
      return;
    }
    final state = ref.read(forumHomeControllerProvider);
    final current = state.asData?.value;
    if (current == null || current.isRefreshing) {
      return;
    }
    final now = ref.read(forumHomeNowProvider).call();
    final elapsed = now.difference(current.lastUpdatedAt);
    if (elapsed < _forumHomeSilentRefreshThreshold) {
      return;
    }
    await ref
        .read(forumHomeControllerProvider.notifier)
        .refresh(forceNetwork: true);
  }

  String _authContextKey(AuthSessionViewState state) {
    if (!state.isLoggedIn) {
      return 'anonymous';
    }
    return 'logged_in:${state.uid.trim()}';
  }
}

class _ResolvedForumHomeBody extends ConsumerWidget {
  const _ResolvedForumHomeBody({
    required this.imageReferer,
    required this.isActive,
  });

  final String imageReferer;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.listen<AsyncValue<ForumHomePageState>>(forumHomeControllerProvider, (
      previous,
      next,
    ) {
      final previousNotice = previous?.asData?.value.refreshNotice;
      final nextNotice = next.asData?.value.refreshNotice;
      if (nextNotice == null ||
          (nextNotice.code == previousNotice?.code &&
              nextNotice.detail == previousNotice?.detail)) {
        return;
      }
      showTransientSnackBar(
        context,
        ForumTextResolver.homeNotice(l10n, nextNotice),
      );
    });

    final state = ref.watch(forumHomeControllerProvider);
    final mode = ref.watch(appServerContentConversionModeProvider);
    final projectionAsync = ref.watch(forumHomeContentProjectionProvider);
    return state.when(
      loading: () => AppLoadingState(
        key: const Key('forum-home-loading'),
        label: l10n.commonLoading,
      ),
      error: (error, _) => AppErrorState(
        message: ForumTextResolver.homeLoadFailure(l10n, error),
        retryLabel: l10n.commonRetry,
        retryKey: const Key('forum-home-retry-button'),
        onRetry: () => ref
            .read(forumHomeControllerProvider.notifier)
            .refresh(forceNetwork: true),
      ),
      data: (data) => _ForumHomeContent(
        state: data,
        projection: _projectionOrRaw(
          data.viewData,
          mode: mode,
          candidate: projectionAsync.asData?.value,
        ),
        imageReferer: imageReferer,
        isActive: isActive,
      ),
    );
  }

  ForumHomeContentProjection _projectionOrRaw(
    ForumHomeViewData source, {
    required TextConversionMode mode,
    required ForumHomeContentProjection? candidate,
  }) {
    final revision = ForumHomeContentProjector.sourceRevisionFor(source);
    if (candidate != null &&
        candidate.mode == mode &&
        candidate.sourceRevision == revision) {
      return candidate;
    }
    return ForumHomeContentProjection.raw(source, mode: mode);
  }
}

class _ForumHomeContent extends ConsumerStatefulWidget {
  const _ForumHomeContent({
    required this.state,
    required this.projection,
    required this.imageReferer,
    required this.isActive,
  });

  final ForumHomePageState state;
  final ForumHomeContentProjection projection;
  final String imageReferer;
  final bool isActive;

  @override
  ConsumerState<_ForumHomeContent> createState() => _ForumHomeContentState();
}

class _ForumHomeContentState extends ConsumerState<_ForumHomeContent> {
  final Set<String> _collapsedSectionKeys = <String>{};
  final _carouselNavigation = ThreadPostNavigationSession();
  int _carouselNavigationGeneration = 0;

  @override
  void didUpdateWidget(covariant _ForumHomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        !identical(oldWidget.state.viewData, widget.state.viewData)) {
      _carouselNavigationGeneration++;
      _carouselNavigation.invalidate();
    }
    final activeKeys = {
      for (final section in widget.projection.sections) _sectionKey(section),
    };
    _collapsedSectionKeys.removeWhere((key) => !activeKeys.contains(key));
  }

  @override
  void dispose() {
    _carouselNavigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(verifiedSessionOwnerProvider, (previous, next) {
      if (previous != next) {
        _carouselNavigationGeneration++;
        _carouselNavigation.invalidate();
      }
    });
    final l10n = AppLocalizations.of(context);
    final palette = ForumHomeNativePalette.resolve(Theme.of(context));
    final blockedThreadIds = ref.watch(blockedThreadIdsProvider);
    final carouselItems = [
      for (final item in widget.state.viewData.carouselItems)
        if (!_isBlockedCarouselItem(item, blockedThreadIds)) item,
    ];
    final isEmpty =
        widget.state.viewData.sections.isEmpty && carouselItems.isEmpty;
    // 空态要占满可视区又保留下拉刷新，因此按视口高度放在列表里滚动。
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: () => ref
            .read(forumHomeControllerProvider.notifier)
            .refresh(forceNetwork: true),
        child: Stack(
          children: [
            ColoredBox(
              color: palette.background,
              child: EInkScrollablePager(
                padding: EdgeInsets.only(
                  right: 12,
                  bottom: 16 + mainShellBottomScrollInset(context),
                ),
                builder: (context, scrollController) => ListView(
                  controller: scrollController,
                  key: const Key('forum-home-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: 10 + mainShellBottomScrollInset(context),
                  ),
                  children: [
                    for (final section in widget.projection.sections.where(
                      (section) =>
                          section.source.type == ForumSectionType.favorite,
                    ))
                      _buildSection(context, section, l10n),
                    ForumHomeCarousel(
                      items: carouselItems,
                      imageReferer: widget.imageReferer,
                      onOpen: (item) => _openCarouselTarget(context, ref, item),
                      isActive: widget.isActive,
                    ),
                    if (isEmpty)
                      SizedBox(
                        height: constraints.maxHeight,
                        child: AppEmptyState(
                          key: const Key('forum-home-empty-state'),
                          title: l10n.forumHomeEmpty,
                        ),
                      ),
                    for (final section in widget.projection.sections.where(
                      (section) =>
                          section.source.type != ForumSectionType.favorite,
                    ))
                      _buildSection(context, section, l10n),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSection(ForumHomeSectionProjection section) {
    final key = _sectionKey(section);
    setState(() {
      if (!_collapsedSectionKeys.add(key)) {
        _collapsedSectionKeys.remove(key);
      }
    });
  }

  Widget _buildSection(
    BuildContext context,
    ForumHomeSectionProjection section,
    AppLocalizations l10n,
  ) => ForumHomeSectionCard(
    sectionKey: _sectionKey(section),
    title:
        section.displayTitle ??
        ForumTextResolver.sectionTitle(l10n, section.source),
    isCollapsed: _collapsedSectionKeys.contains(_sectionKey(section)),
    onToggle: () => _toggleSection(section),
    children: _buildRows(context, section, l10n),
  );

  String _sectionKey(ForumHomeSectionProjection section) {
    return section.source.sourceIdentity;
  }

  List<Widget> _buildRows(
    BuildContext context,
    ForumHomeSectionProjection section,
    AppLocalizations l10n,
  ) {
    final rows = <_ForumHomeRowData>[
      for (final forum in section.items)
        _ForumHomeRowData(
          key: Key(
            section.source.type == ForumSectionType.favorite
                ? 'forum-favorite-card-${forum.source.fid}'
                : 'forum-card-${forum.source.fid}',
          ),
          title: forum.displayTitle,
          description: forum.displayDescription,
          todayPosts: forum.source.todayPosts,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ForumDisplayPage(
                  fid: forum.source.fid,
                  title: forum.source.title,
                ),
              ),
            );
          },
        ),
    ];

    return [
      for (var index = 0; index < rows.length; index++)
        ForumHomeForumRow(
          key: rows[index].key,
          title: rows[index].title,
          description: rows[index].description,
          todayPosts: rows[index].todayPosts,
          todayLabel: l10n.forumDisplayToday,
          isLast: index == rows.length - 1,
          onTap: rows[index].onTap,
        ),
    ];
  }

  bool _isBlockedCarouselItem(
    ForumHomeCarouselItem item,
    Set<String> blockedThreadIds,
  ) {
    if (blockedThreadIds.isEmpty) {
      return false;
    }
    const parser = ForumReferenceResolver();
    final normalized = parser.normalizeHref(item.targetUrl);
    if (normalized == null) {
      return false;
    }
    final tid = ThreadBlockIdentity.normalizeTid(parser.extractTid(normalized));
    return tid != null && blockedThreadIds.contains(tid);
  }

  Future<void> _openCarouselTarget(
    BuildContext context,
    WidgetRef ref,
    ForumHomeCarouselItem item,
  ) async {
    final owner = ref.read(verifiedSessionOwnerProvider);
    final source = widget.state.viewData;
    final generation = _carouselNavigationGeneration;
    await ref
        .read(forumLinkOpenerProvider)
        .open(
          context: context,
          url: item.targetUrl,
          session: _carouselNavigation,
          isCurrent: () =>
              mounted &&
              widget.isActive &&
              generation == _carouselNavigationGeneration &&
              identical(widget.state.viewData, source) &&
              ref.read(verifiedSessionOwnerProvider) == owner,
        );
  }
}

class _ForumHomeBlankBody extends StatelessWidget {
  const _ForumHomeBlankBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(key: Key('forum-home-blank-body'));
  }
}

class _ForumHomeRowData {
  const _ForumHomeRowData({
    required this.key,
    required this.title,
    required this.description,
    required this.todayPosts,
    required this.onTap,
  });

  final Key key;
  final String title;
  final String description;
  final int? todayPosts;
  final VoidCallback onTap;
}
