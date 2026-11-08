import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/library_shared/presentation/widgets/library_chapter_browser.dart';
import 'package:y300/features/recent_search/application/recent_searches_controller.dart';
import 'package:y300/features/recent_search/domain/models/recent_search_scope.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app({
    required ScrollController scroll,
    required ValueChanged<String> onOpen,
    double scale = 1,
    double topObstruction = 0,
    ProviderContainer? container,
  }) {
    final child = LocalizedTestApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: LibraryChapterBrowser<String>(
              workId: 'work-1',
              currentId: 'chapter-750',
              scrollController: scroll,
              itemExtent: 64 * scale,
              topObstruction: topObstruction,
              leadingSlivers: topObstruction == 0
                  ? const []
                  : const [SliverToBoxAdapter(child: SizedBox(height: 600))],
              trailingSlivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 320)),
              ],
              normalizeTexts: (texts) async => texts,
              entries: [
                for (var i = 0; i < 1500; i++)
                  ChapterSearchEntry(
                    id: 'chapter-$i',
                    title: '第$i章',
                    value: 'chapter-$i',
                  ),
              ],
              rowBuilder: (context, id, confirmSearch) => ListTile(
                key: Key(id),
                title: Text(id, maxLines: 1),
                onTap: () {
                  confirmSearch();
                  onOpen(id);
                },
              ),
            ),
          ),
        ),
      ),
    );
    return container == null
        ? ProviderScope(child: child)
        : UncontrolledProviderScope(container: container, child: child);
  }

  testWidgets(
    'long catalogs locate lazily, clear restores browse position and selection confirms once',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final opened = <String>[];
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        app(scroll: scroll, onOpen: opened.add, container: container),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chapter-750')), findsOneWidget);
      expect(find.byKey(const Key('chapter-0')), findsNothing);
      expect(find.byType(ListTile).evaluate().length, lessThan(30));
      final before = scroll.offset;
      final input = find.byKey(const Key('library-chapter-search-field'));
      await tester.enterText(input, '1499');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chapter-1499')), findsOneWidget);
      expect(
        container.read(
          recentSearchesProvider(RecentSearchScope.workChapters('work-1')!),
        ),
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('library-chapter-search-clear')));
      await tester.pumpAndSettle();
      expect(scroll.offset, before);
      await tester.tap(find.byKey(const Key('library-chapter-last')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chapter-1499')), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-chapter-first')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chapter-0')), findsOneWidget);
      await tester.enterText(input, 'does not exist');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('library-chapter-search-empty')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('library-chapter-current')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chapter-750')), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      await tester.enterText(input, '1499');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chapter-1499')));
      await tester.pumpAndSettle();
      expect(opened, ['chapter-1499']);
      expect(
        container
            .read(
              recentSearchesProvider(RecentSearchScope.workChapters('work-1')!),
            )
            .single
            .keyword,
        '1499',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long catalogs restore browse position under a fixed toolbar', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final opened = <String>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      app(
        scroll: scroll,
        onOpen: opened.add,
        container: container,
        topObstruction: 104,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-750')), findsOneWidget);
    expect(find.byKey(const Key('chapter-0')), findsNothing);
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    final before = scroll.offset;
    final input = find.byKey(const Key('library-chapter-search-field'));
    await tester.enterText(input, '1499');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-1499')), findsOneWidget);
    expect(
      container.read(
        recentSearchesProvider(RecentSearchScope.workChapters('work-1')!),
      ),
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('library-chapter-search-clear')));
    await tester.pumpAndSettle();
    expect(scroll.offset, before);
    await tester.tap(find.byKey(const Key('library-chapter-last')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-1499')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-chapter-first')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-0')), findsOneWidget);
    await tester.enterText(input, 'does not exist');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-chapter-search-empty')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('library-chapter-current')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-750')), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    await tester.enterText(input, '1499');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chapter-1499')));
    await tester.pumpAndSettle();
    expect(opened, ['chapter-1499']);
    expect(
      container
          .read(
            recentSearchesProvider(RecentSearchScope.workChapters('work-1')!),
          )
          .single
          .keyword,
      '1499',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow large text catalog keeps controls usable with keyboard and localizes labels',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(app(scroll: scroll, onOpen: (_) {}, scale: 2));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LibraryChapterBrowser<String>)),
      );
      expect(find.byTooltip(l10n.libraryChapterLocateCurrent), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isFalse,
      );
      await tester.enterText(find.byType(TextField), '12');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chapter-12')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('short keyboard viewport keeps query and results reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(app(scroll: scroll, onOpen: (_) {}, scale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '1499');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chapter-1499')), findsOneWidget);
    expect(tester.getBottomLeft(find.byType(TextField)).dy, lessThan(tester.getCenter(find.byKey(const Key('chapter-1499'))).dy));
  });
}
