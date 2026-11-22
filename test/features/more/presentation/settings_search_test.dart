import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/more/presentation/appearance_page.dart';
import 'package:y300/features/more/presentation/navigation_management_page.dart';
import 'package:y300/features/more/presentation/settings_page.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_index.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('settings page exposes the search entry and common settings', (
    tester,
  ) async {
    await _pumpSettings(tester);

    final entry = find.byKey(const Key('settings-search-entry'));
    expect(entry, findsOneWidget);
    final l10n = _l10n(tester);
    expect(
      tester.widget<IconButton>(entry).tooltip,
      l10n.settingsSearchTooltip,
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-search-page')), findsOneWidget);
    expect(find.text(l10n.settingsSearchRecommendedTitle), findsOneWidget);
    for (final id in settingsSearchRecommendedIds) {
      expect(
        find.byKey(Key('settings-search-result-$id')),
        findsOneWidget,
        reason: id,
      );
    }
    expect(find.byKey(const Key('settings-search-results')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-search-back-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('index keeps settings groups then appearance groups in order', (
    tester,
  ) async {
    await _pumpSettings(tester);
    final l10n = _l10n(tester);

    final index = buildSettingsSearchIndex(l10n, includeDebug: true);
    expect(index.map((entry) => entry.target).toList(), const [
      SettingsSearchTarget.settingsAppearanceNavigation,
      SettingsSearchTarget.appearanceTop,
      SettingsSearchTarget.navigationManagement,
      SettingsSearchTarget.settingsBrowsingPosts,
      SettingsSearchTarget.contentFilter,
      SettingsSearchTarget.threadControls,
      SettingsSearchTarget.settingsStorageAbout,
      SettingsSearchTarget.dataStorage,
      SettingsSearchTarget.about,
      SettingsSearchTarget.settingsDebug,
      SettingsSearchTarget.appearanceThemeMode,
      SettingsSearchTarget.appearanceColorTheme,
      SettingsSearchTarget.appearanceBoldFont,
      SettingsSearchTarget.appearanceGlass,
      SettingsSearchTarget.appearanceEInk,
      SettingsSearchTarget.appearanceNavigation,
      SettingsSearchTarget.appearanceLanguage,
      SettingsSearchTarget.appearanceReset,
    ]);
    expect(
      buildSettingsSearchIndex(l10n).map((entry) => entry.target),
      isNot(contains(SettingsSearchTarget.settingsDebug)),
    );
  });

  testWidgets('keyword search filters locally and keeps the group order', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _openSearch(tester);

    Future<List<String>> search(String query) async {
      await tester.enterText(
        find.byKey(const Key('settings-search-input')),
        query,
      );
      await tester.pumpAndSettle();
      return [
        for (final row in tester.widgetList<AppGroupedRow>(
          find.descendant(
            of: find.byKey(const Key('settings-search-results')),
            matching: find.byType(AppGroupedRow),
          ),
        ))
          (row.key! as ValueKey<String>).value,
      ];
    }

    expect(await search('缓存'), ['settings-search-result-data-storage']);
    expect(await search('黑名单'), ['settings-search-result-content-filter']);
    expect(await search('评分'), [
      'settings-search-result-settings-section-browsing-posts',
    ]);
    expect(await search('浅色'), [
      'settings-search-result-appearance',
      'settings-search-result-appearance-theme-mode',
    ]);
    expect(await search('墨水屏'), ['settings-search-result-appearance-eink']);

    final l10n = _l10n(tester, searchPage: true);
    await tester.enterText(
      find.byKey(const Key('settings-search-input')),
      '不存在的设置项',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-search-empty')), findsOneWidget);
    expect(find.text(l10n.settingsSearchNoResults), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-search-clear-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-search-recommended')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search result opens the target sub page and keeps the stack', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _openSearch(tester);
    await _search(tester, '启动页');

    await tester.tap(
      find.byKey(const Key('settings-search-result-navigation-management')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationManagementPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings group result scrolls back and highlights the group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSettings(tester);
    await _openSearch(tester);
    await _search(tester, '存储与关于');
    await tester.tap(
      find.byKey(
        const Key('settings-search-result-settings-section-storage-about'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(
      _listOffset(tester, const Key('settings-page-list')),
      greaterThan(0),
    );
    final highlight = find.byKey(
      const Key('settings-search-highlight-settingsStorageAbout'),
    );
    expect(_highlightOpacity(tester, highlight), 1);

    // 高亮短暂停留后淡出，不留下持续遮罩。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_highlightOpacity(tester, highlight), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance result opens the appearance page at the group', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _openSearch(tester);
    await _search(tester, '玻璃');
    await tester.tap(
      find.byKey(const Key('settings-search-result-appearance-glass')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppearancePage), findsOneWidget);
    expect(
      _listOffset(tester, const Key('appearance-page-list')),
      greaterThan(0),
    );
    final highlight = find.byKey(
      const Key('settings-search-highlight-appearanceGlass'),
    );
    expect(_highlightOpacity(tester, highlight), 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_highlightOpacity(tester, highlight), 0);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('e-ink search result reveals the new appearance group', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _openSearch(tester);
    await _search(tester, '墨水屏');
    await tester.tap(
      find.byKey(const Key('settings-search-result-appearance-eink')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppearancePage), findsOneWidget);
    expect(
      find.byKey(const Key('appearance-eink-mode-switch')),
      findsOneWidget,
    );
    expect(
      _highlightOpacity(
        tester,
        find.byKey(const Key('settings-search-highlight-appearanceEInk')),
      ),
      1,
    );
    expect(tester.takeException(), isNull);
  });
}

AppLocalizations _l10n(WidgetTester tester, {bool searchPage = false}) {
  final key = Key(searchPage ? 'settings-search-page' : 'settings-page');
  return AppLocalizations.of(tester.element(find.byKey(key)));
}

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: LocalizedTestApp(home: SettingsPage())),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('settings-search-entry')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('settings-search-page')), findsOneWidget);
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const Key('settings-search-input')), query);
  await tester.pumpAndSettle();
}

double _listOffset(WidgetTester tester, Key listKey) {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byKey(listKey), matching: find.byType(Scrollable)),
  );
  return scrollable.position.pixels;
}

double _highlightOpacity(WidgetTester tester, Finder finder) {
  return tester.widget<AnimatedOpacity>(finder).opacity;
}
