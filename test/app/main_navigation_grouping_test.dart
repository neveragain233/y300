import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_navigation_settings_snapshot_codec.dart';

void main() {
  test(
    'startup falls back between visible candidates, then to actual first group',
    () {
      for (final page in MainStartupPage.values) {
        for (final forumVisible in [false, true]) {
          for (final bookshelfVisible in [false, true]) {
            final settings = MainNavigationSettings(
              startupPage: page,
              managedOrder: const [
                MainShellDestination.favorites,
                MainShellDestination.novel,
              ],
              hiddenDestinations: {
                if (!forumVisible) MainShellDestination.forum,
                if (!bookshelfVisible) ...[
                  MainShellDestination.comic,
                  MainShellDestination.novel,
                ],
              },
            );
            final grouping = MainNavigationGrouping(settings);
            final expected =
                (page == MainStartupPage.forum && forumVisible ||
                    !bookshelfVisible && forumVisible)
                ? MainShellDestination.forum
                : bookshelfVisible
                ? MainShellDestination.novel
                : MainShellDestination.favorites;
            expect(grouping.startupDestination, expected);
            expect(settings.startupPage, page);
          }
        }
      }
    },
  );

  test(
    'default settings project to four groups without rewriting preferences',
    () {
      final settings = MainNavigationSettings.defaults();
      final encoded = MainNavigationSettingsSnapshotCodec.encode(settings);
      final groups = MainNavigationGrouping(settings);
      expect(groups.groups, [
        MainNavigationGroup.forum,
        MainNavigationGroup.favorites,
        MainNavigationGroup.bookshelf,
        MainNavigationGroup.my,
      ]);
      expect(groups.bookshelfDestinations, [MainShellDestination.comic]);
      expect(settings, MainNavigationSettings.defaults());
      expect(MainNavigationSettingsSnapshotCodec.encode(settings), encoded);
      expect(MainNavigationSettingsSnapshotCodec.decode(encoded), settings);
    },
  );

  test(
    'first visible group member determines order and hidden books stay hidden',
    () {
      final groups = MainNavigationGrouping(
        MainNavigationSettings(
          managedOrder: const [
            MainShellDestination.novel,
            MainShellDestination.messages,
            MainShellDestination.history,
            MainShellDestination.comic,
          ],
          hiddenDestinations: const {
            MainShellDestination.comic,
            MainShellDestination.forum,
          },
        ),
      );
      expect(groups.groups, [
        MainNavigationGroup.bookshelf,
        MainNavigationGroup.messages,
        MainNavigationGroup.favorites,
        MainNavigationGroup.my,
      ]);
      expect(
        groups.destinationFor(
          MainNavigationGroup.bookshelf,
          preferredBookshelf: MainShellDestination.comic,
        ),
        MainShellDestination.novel,
      );
      expect(
        groups.destinationFor(MainNavigationGroup.my),
        MainShellDestination.more,
      );
    },
  );

  test('first visible bookshelf member is the only projected entry', () {
    final groups = MainNavigationGrouping(
      MainNavigationSettings(
        managedOrder: const [
          MainShellDestination.novel,
          MainShellDestination.comic,
          MainShellDestination.forum,
        ],
        hiddenDestinations: const {},
      ),
    );
    expect(groups.bookshelfDestinations, [MainShellDestination.novel]);
    expect(
      groups.destinationFor(
        MainNavigationGroup.bookshelf,
        preferredBookshelf: MainShellDestination.comic,
      ),
      MainShellDestination.novel,
    );
  });

  test('history-only legacy configuration keeps My reachable', () {
    final groups = MainNavigationGrouping(
      MainNavigationSettings(
        managedOrder: MainShellDestination.defaultManagedOrder,
        hiddenDestinations: MainShellDestination.defaultManagedOrder.where(
          (destination) => destination != MainShellDestination.history,
        ),
      ),
    );
    expect(groups.groups, [MainNavigationGroup.my]);
  });
}
