import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_navigation_settings_snapshot_codec.dart';

void main() {
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
      expect(groups.bookshelfDestinations, [
        MainShellDestination.comic,
        MainShellDestination.novel,
      ]);
      expect(groups.myDestinations, [MainShellDestination.history]);
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
    expect(groups.myDestinations, [MainShellDestination.history]);
  });
}
