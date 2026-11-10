import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_theme.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/search/presentation/widgets/forum_search_result_card.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('renders compact forum metadata and shared surface geometry', (
    tester,
  ) async {
    final theme = AppTheme.light();
    var tapped = false;

    await tester.pumpWidget(
      LocalizedTestApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ForumSearchResultCard(
              item: const ForumSearchTopicSummary(
                tid: '571160',
                title: '搜索结果标题',
                forumId: '30',
                authorName: '测试作者',
                publishedAtText: '2026-08-11',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('搜索结果标题'), findsOneWidget);
    expect(find.text('测试作者 · 2026-08-11'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.text('搜索结果标题')));
    expect(find.text(l10n.searchResultTid('571160')), findsOneWidget);

    final card = find.byType(ForumSearchResultCard);
    final surface = tester.widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)).first,
    );
    expect(
      surface.color,
      ForumDisplayThemePalette.resolve(theme).surfaceContainerLow,
    );
    expect(surface.borderRadius, BorderRadius.circular(12));

    final title = tester.widget<Text>(find.text('搜索结果标题'));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style?.fontWeight, FontWeight.w700);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('omits missing metadata without empty separators', (
    tester,
  ) async {
    Future<void> pumpItem(ForumSearchTopicSummary item) {
      return tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ForumSearchResultCard(item: item, onTap: () {}),
            ),
          ),
        ),
      );
    }

    await pumpItem(
      const ForumSearchTopicSummary(
        tid: '1',
        title: '仅作者',
        forumId: '30',
        authorName: '作者',
      ),
    );
    expect(find.text('作者'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);

    await pumpItem(const ForumSearchTopicSummary(tid: '2', title: '无元信息'));
    expect(
      find.byKey(const Key('forum-search-result-metadata-2')),
      findsNothing,
    );
    final l10n = AppLocalizations.of(tester.element(find.text('无元信息')));
    expect(find.text(l10n.searchResultTid('2')), findsOneWidget);
  });

  testWidgets('keeps TID visible on a narrow large-text surface', (
    tester,
  ) async {
    final theme = AppTheme.dark();
    var opened = false;
    var actionTapped = false;
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 600),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: ForumSearchResultCard(
                item: const ForumSearchTopicSummary(
                  tid: '571160',
                  title: '这是一个很长的搜索结果标题用于验证窄屏布局',
                  forumId: '30',
                  authorName: '这是一个非常长的作者名称',
                  publishedAtText: '2026-08-11 10:33',
                ),
                onTap: () => opened = true,
                action: IconButton(
                  key: const Key('search-card-action'),
                  onPressed: () => actionTapped = true,
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('forum-search-result-tid-571160')),
      findsOneWidget,
    );
    final card = find.byType(ForumSearchResultCard);
    final surface = tester.widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)).first,
    );
    expect(
      surface.color,
      ForumDisplayThemePalette.resolve(theme).surfaceContainerLow,
    );
    final action = find.byKey(const Key('search-card-action'));
    final title = find.byKey(const Key('forum-search-result-title-571160'));
    final metadata = find.byKey(
      const Key('forum-search-result-metadata-571160'),
    );
    expect(tester.getRect(action).overlaps(tester.getRect(title)), isFalse);
    expect(
      tester.getBottomRight(action).dy,
      lessThan(tester.getTopLeft(metadata).dy),
    );
    await tester.tap(action);
    expect(actionTapped, isTrue);
    expect(opened, isFalse);
    expect(tester.takeException(), isNull);
  });
}
