import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/more/presentation/about_page.dart';
import 'package:y300/features/more/presentation/appearance_page.dart';
import 'package:y300/features/more/presentation/more_debug_tools.dart';
import 'package:y300/features/more/presentation/navigation_management_page.dart';
import 'package:y300/features/more/presentation/settings_page.dart';
import 'package:y300/features/thread/presentation/thread_controls_settings_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('settings page groups the migrated entries once', (tester) async {
    await _pumpSettings(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('settings-page'))),
    );

    final searchEntry = find.byKey(const Key('settings-search-entry'));
    expect(searchEntry, findsOneWidget);
    expect(tester.getSize(searchEntry).height, greaterThanOrEqualTo(48));
    expect(
      tester.widget<IconButton>(searchEntry).tooltip,
      l10n.settingsSearchTooltip,
    );

    for (final title in [
      l10n.settingsSectionAppearanceNavigation,
      l10n.settingsSectionBrowsingPosts,
      l10n.settingsSectionStorageAbout,
      l10n.settingsSectionDebug,
    ]) {
      await _scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
    }

    for (final key in [
      'more-appearance-entry',
      'more-navigation-management-entry',
      'more-content-filter-entry',
      'more-thread-controls-entry',
      'more-data-storage-entry',
      'more-about-entry',
      'more-composer-quill-prototype-entry',
      'more-html-renderer-prototype-entry',
    ]) {
      final entry = find.byKey(Key(key));
      await _scrollTo(tester, entry);
      expect(entry, findsOneWidget, reason: key);
    }
  });

  testWidgets('only pushed rows show a chevron', (tester) async {
    await _pumpSettings(tester);

    for (final key in [
      'more-appearance-entry',
      'more-navigation-management-entry',
      'more-content-filter-entry',
      'more-thread-controls-entry',
      'more-data-storage-entry',
      'more-about-entry',
    ]) {
      final row = find.byKey(Key(key));
      await _scrollTo(tester, row);
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
        reason: key,
      );
    }
  });

  testWidgets('settings rows open the original pages', (tester) async {
    await _pumpSettings(tester);

    Future<void> openAndReturn(Finder row, Finder page) async {
      await _scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(page, findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-page')), findsOneWidget);
    }

    await openAndReturn(
      find.byKey(const Key('more-appearance-entry')),
      find.byType(AppearancePage),
    );
    await openAndReturn(
      find.byKey(const Key('more-navigation-management-entry')),
      find.byType(NavigationManagementPage),
    );
    await openAndReturn(
      find.byKey(const Key('more-thread-controls-entry')),
      find.byType(ThreadControlsSettingsPage),
    );

    // 内容过滤与关于沿用原页面；数据与存储仍是弹层入口。
    for (final key in [
      'more-content-filter-entry',
      'more-about-entry',
      'more-data-storage-entry',
    ]) {
      final row = find.byKey(Key(key));
      await _scrollTo(tester, row);
      expect(tester.widget<AppGroupedRow>(row).onTap, isNotNull, reason: key);
    }
    expect(find.byType(AboutPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('debug group disappears when debug tools provide no rows', (
    tester,
  ) async {
    await _pumpSettings(tester, debugTools: const _NoDebugTools());
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('settings-page'))),
    );

    expect(find.text(l10n.settingsSectionDebug), findsNothing);
    expect(
      find.byKey(const Key('more-composer-quill-prototype-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('more-html-renderer-prototype-entry')),
      findsNothing,
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  MoreDebugTools debugTools = const MoreDebugTools(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: LocalizedTestApp(home: SettingsPage(debugTools: debugTools)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('settings-page-list')),
        matching: find.byType(Scrollable),
      ),
    );
  } else {
    await Scrollable.ensureVisible(tester.element(finder));
  }
  await tester.pumpAndSettle();
}

class _NoDebugTools extends MoreDebugTools {
  const _NoDebugTools();

  @override
  List<Widget> buildTiles(BuildContext context, AppLocalizations l10n) =>
      const <Widget>[];
}
