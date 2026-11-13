import 'package:y300/app/navigation/main_navigation_settings.dart';

enum MainNavigationGroup { forum, favorites, bookshelf, messages, my }

/// 只投影导航展示，旧枚举、顺序和隐藏快照继续作为偏好事实。
final class MainNavigationGrouping {
  MainNavigationGrouping(MainNavigationSettings settings)
    : startupPage = settings.startupPage,
      bookshelfDestinations = List.unmodifiable(
        settings.visibleManagedDestinations.where(isBookshelf),
      ),
      groups = List.unmodifiable({
        for (final destination in settings.visibleManagedDestinations)
          if (groupFor(destination) != MainNavigationGroup.my)
            groupFor(destination),
        MainNavigationGroup.my,
      });

  static List<MainNavigationGroup> configurableGroups(
    MainNavigationSettings settings,
  ) => List.unmodifiable({
    for (final destination in settings.managedOrder)
      if (groupFor(destination) != MainNavigationGroup.my)
        groupFor(destination),
  });

  static Iterable<MainShellDestination> members(MainNavigationGroup group) =>
      MainShellDestination.defaultManagedOrder.where(
        (value) => groupFor(value) == group,
      );

  final MainStartupPage startupPage;
  final List<MainNavigationGroup> groups;

  MainShellDestination get startupDestination {
    final candidates = startupPage == MainStartupPage.bookshelf
        ? [MainNavigationGroup.bookshelf, MainNavigationGroup.forum]
        : [MainNavigationGroup.forum, MainNavigationGroup.bookshelf];
    for (final group in candidates) {
      if (groups.contains(group)) return destinationFor(group);
    }
    return destinationFor(groups.first);
  }

  final List<MainShellDestination> bookshelfDestinations;

  static bool isBookshelf(MainShellDestination destination) =>
      destination == MainShellDestination.comic ||
      destination == MainShellDestination.novel;

  static MainNavigationGroup groupFor(MainShellDestination destination) =>
      switch (destination) {
        MainShellDestination.forum => MainNavigationGroup.forum,
        MainShellDestination.favorites => MainNavigationGroup.favorites,
        MainShellDestination.comic ||
        MainShellDestination.novel => MainNavigationGroup.bookshelf,
        MainShellDestination.messages => MainNavigationGroup.messages,
        MainShellDestination.history ||
        MainShellDestination.blogs ||
        MainShellDestination.more => MainNavigationGroup.my,
      };

  MainShellDestination destinationFor(
    MainNavigationGroup group, {
    MainShellDestination? preferredBookshelf,
  }) => switch (group) {
    MainNavigationGroup.forum => MainShellDestination.forum,
    MainNavigationGroup.favorites => MainShellDestination.favorites,
    MainNavigationGroup.messages => MainShellDestination.messages,
    MainNavigationGroup.my => MainShellDestination.more,
    MainNavigationGroup.bookshelf =>
      bookshelfDestinations.contains(preferredBookshelf)
          ? preferredBookshelf!
          : bookshelfDestinations.first,
  };
}
