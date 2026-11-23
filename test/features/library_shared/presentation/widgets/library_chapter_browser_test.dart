import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
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
      expect(tester.widget<AppTextInput>(input).controller!.text, isEmpty);
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
    expect(tester.widget<AppTextInput>(input).controller!.text, isEmpty);
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
        tester.widget<AppTextInput>(find.byType(AppTextInput)).autofocus,
        isFalse,
      );
      await tester.enterText(find.byType(AppTextInput), '12');
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
    await tester.enterText(find.byType(AppTextInput), '1499');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chapter-1499')), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(AppTextInput)).dy,
      lessThan(tester.getCenter(find.byKey(const Key('chapter-1499'))).dy),
    );
  });

  testWidgets('search pill tints to theme surface in light/warm/dark/eink', (
    tester,
  ) async {
    Future<void> pumpTheme({
      required ThemeData theme,
      AppGlassLevel glassLevel = AppGlassLevel.standard,
      bool eInk = false,
    }) async {
      await tester.pumpWidget(
        AppGlassEnvironment(
          glassLevel: glassLevel,
          child: LocalizedTestApp(
            theme: theme,
            builder: eInk
                ? (_, child) => EInkModeScope(enabled: true, child: child!)
                : null,
            home: Scaffold(
              body: LibraryChapterBrowser<String>(
                workId: 'work-1',
                keyPrefix: 'theme-check',
                controlsInList: true,
                pinControls: true,
                entries: const [
                  ChapterSearchEntry(id: '1', title: '第1话', value: '1'),
                ],
                itemExtent: 48,
                rowBuilder: (_, item, _) => Text(item, key: Key('item-$item')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // 浅色开启玻璃：使用 surfaceContainerLowest 着色而非中性灰 0x93F4F4F4，
    // 且吸顶控制区背景色直接画在带 boxShadow 的同一层 BoxDecoration 上。
    final lightTheme = AppTheme.light();
    await pumpTheme(theme: lightTheme);
    final headerDecorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(LibraryChapterBrowser<String>),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (headerDecorated.decoration as BoxDecoration).color,
      lightTheme.scaffoldBackgroundColor,
    );
    final lightGlass = tester.widget<LiquidGlass>(
      find.descendant(
        of: find.byType(AppTextInput),
        matching: find.byType(LiquidGlass),
      ),
    );
    expect(
      lightGlass.style.tint,
      lightTheme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.82),
    );

    // 暖纸主题关闭玻璃：回退到暖纸高光表面 surfaceContainerLowest
    final warmTheme = AppTheme.build(
      family: AppThemeFamily.warmPaper,
      brightness: Brightness.light,
    );
    await pumpTheme(theme: warmTheme, glassLevel: AppGlassLevel.off);
    final warmMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppTextInput),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(warmMaterial.color, warmTheme.colorScheme.surfaceContainerLowest);

    // 深色模式开启玻璃：保留暗色 pill 玻璃风格
    final darkTheme = AppTheme.dark();
    await pumpTheme(theme: darkTheme);
    expect(
      find.descendant(
        of: find.byType(AppTextInput),
        matching: find.byType(LiquidGlass),
      ),
      findsOneWidget,
    );

    // 墨水屏模式：跳过玻璃并保留高对比实色表面与边框
    await pumpTheme(theme: lightTheme, eInk: true);
    expect(
      find.descendant(
        of: find.byType(AppTextInput),
        matching: find.byType(LiquidGlass),
      ),
      findsNothing,
    );
    final einkMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppTextInput),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(einkMaterial.color, lightTheme.colorScheme.surface);
  });

  testWidgets(
    'tapping pill search input once focuses immediately under glass',
    (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          AppGlassEnvironment(
            glassLevel: AppGlassLevel.standard,
            child: LocalizedTestApp(
              theme: theme,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 56,
                    child: AppTextInput(
                      key: const Key('single-tap-pill'),
                      focusNode: focusNode,
                      variant: AppTextInputVariant.pill,
                      pillBorderRadius: 28,
                      hintText: '搜索',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('single-tap-pill')));
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
      }
    },
  );
}
