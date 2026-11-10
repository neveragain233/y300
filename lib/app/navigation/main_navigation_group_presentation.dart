import 'package:flutter/material.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/l10n/app_localizations.dart';

extension MainNavigationGroupPresentation on MainNavigationGroup {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    MainNavigationGroup.forum => l10n.appNavigationForum,
    MainNavigationGroup.favorites => l10n.appNavigationFavorites,
    MainNavigationGroup.bookshelf => l10n.appNavigationBookshelf,
    MainNavigationGroup.messages => l10n.appNavigationMessages,
    MainNavigationGroup.my => l10n.appNavigationMy,
  };

  IconData get icon => switch (this) {
    MainNavigationGroup.forum => Icons.forum_outlined,
    MainNavigationGroup.favorites => Icons.star_border,
    MainNavigationGroup.bookshelf => Icons.auto_stories_outlined,
    MainNavigationGroup.messages => Icons.mail_outline,
    MainNavigationGroup.my => Icons.person_outline,
  };

  IconData get selectedIcon => switch (this) {
    MainNavigationGroup.forum => Icons.forum,
    MainNavigationGroup.favorites => Icons.star,
    MainNavigationGroup.bookshelf => Icons.auto_stories,
    MainNavigationGroup.messages => Icons.mail,
    MainNavigationGroup.my => Icons.person,
  };
}
