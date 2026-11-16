import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/shared/widgets/shelf/library_cover_identity.dart';
import 'package:y300/shared/widgets/shelf/typographic_library_cover.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  const comic = LibraryCoverIdentity(source: 'comic', workId: 'yamibo:1');
  const novel = LibraryCoverIdentity(source: 'novel', workId: 'novel:1:2');

  test('identity hash uses stable FNV-1a over the source and work id', () {
    expect(comic.hash, 995659773);
    expect(novel.hash, 592381901);
    expect(comic.hash, LibraryCoverIdentity.hashOf('comic/yamibo:1'));
  });

  test('identity prefers the cover asset owner over the current module', () {
    final resolved = LibraryCoverIdentity.resolve(
      moduleKey: LibraryModuleKey.favorite,
      workId: 'favorite:42',
      coverAsset: const LibraryCoverAssetRef(
        assetId: 'comic/yamibo:9/source',
        revision: 1,
        kind: LibraryCoverAssetKind.source,
      ),
    );

    expect(
      resolved,
      const LibraryCoverIdentity(source: 'comic', workId: 'yamibo:9'),
    );
  });

  test('light and dark palettes keep the same hue with readable text', () {
    const resolver = LibraryCoverPaletteResolver();
    final light = resolver.resolve(theme: AppTheme.light(), identity: comic);
    final dark = resolver.resolve(theme: AppTheme.dark(), identity: comic);

    expect(
      HSLColor.fromColor(light.background).hue,
      closeTo(HSLColor.fromColor(dark.background).hue, 30),
    );
    expect(
      dark.background.computeLuminance(),
      lessThan(light.background.computeLuminance()),
    );
    expect(
      LibraryCoverPaletteResolver.contrastRatio(
        light.foreground,
        light.background,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      LibraryCoverPaletteResolver.contrastRatio(
        dark.foreground,
        dark.background,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('palette is deterministic across rebuilds and themes', () {
    const resolver = LibraryCoverPaletteResolver();
    final first = resolver.resolve(theme: AppTheme.light(), identity: comic);
    final second = resolver.resolve(theme: AppTheme.light(), identity: comic);
    final other = resolver.resolve(theme: AppTheme.light(), identity: novel);

    expect(first.background, second.background);
    expect(first.foreground, second.foreground);
    expect(other.background, isNot(first.background));
  });

  Future<void> pumpCover(
    WidgetTester tester, {
    required LibraryCoverLayout layout,
    String title = '排版封面标题',
    String? author = '作者甲',
  }) {
    return tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: layout == LibraryCoverLayout.detail ? 120 : 160,
            height: layout == LibraryCoverLayout.detail ? 168 : 240,
            child: TypographicLibraryCover(
              identity: comic,
              title: title,
              author: author,
              layout: layout,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('grid layout paints author above the title', (tester) async {
    await pumpCover(tester, layout: LibraryCoverLayout.grid);

    expect(find.byKey(const Key('typographic-cover-title')), findsOneWidget);
    expect(find.byKey(const Key('typographic-cover-author')), findsOneWidget);
    expect(find.text('排版封面标题'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('detail layout reuses the same title and author copy', (
    tester,
  ) async {
    await pumpCover(tester, layout: LibraryCoverLayout.detail);

    expect(find.text('排版封面标题'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
  });

  testWidgets('list layout keeps only a source icon', (tester) async {
    await pumpCover(tester, layout: LibraryCoverLayout.list);

    expect(
      find.byKey(const Key('typographic-cover-source-icon')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('typographic-cover-watermark')), findsNothing);
    expect(find.byKey(const Key('typographic-cover-title')), findsNothing);
    expect(find.byKey(const Key('typographic-cover-author')), findsNothing);
  });

  testWidgets('list layout falls back to a first character watermark', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 52,
            height: 52,
            child: TypographicLibraryCover(
              identity: LibraryCoverIdentity(
                source: 'favorite',
                workId: 'favorite:7',
              ),
              title: '收藏作品',
              layout: LibraryCoverLayout.list,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('typographic-cover-watermark')),
      findsOneWidget,
    );
    expect(find.text('收'), findsOneWidget);
  });

  testWidgets('missing author and empty title keep the cover stable', (
    tester,
  ) async {
    await pumpCover(
      tester,
      layout: LibraryCoverLayout.grid,
      title: '',
      author: null,
    );

    expect(find.byKey(const Key('typographic-cover-author')), findsNothing);
    expect(find.byKey(const Key('typographic-cover-title')), findsOneWidget);
  });

  testWidgets('large text scale keeps cover title and badges inside the slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        home: const Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 180,
                child: TypographicLibraryCover(
                  identity: comic,
                  title: '这是一个非常长的排版封面标题用于验证大字号排版',
                  author: '作者甲',
                  trailingBadge: Text('漫'),
                  reserveTopBadgeSpace: true,
                ),
              ),
              SizedBox(
                width: 120,
                height: 168,
                child: TypographicLibraryCover(
                  identity: novel,
                  title: '小说排版封面标题',
                  layout: LibraryCoverLayout.detail,
                ),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: TypographicLibraryCover(
                  identity: comic,
                  title: '短',
                  layout: LibraryCoverLayout.list,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('background color matches the identity palette in both layouts', (
    tester,
  ) async {
    final colors = const LibraryCoverPaletteResolver().resolve(
      theme: AppTheme.light(),
      identity: comic,
    );

    await pumpCover(tester, layout: LibraryCoverLayout.grid);
    final grid = tester.widget<ColoredBox>(
      find.byKey(const Key('typographic-cover-background')),
    );
    expect(grid.color, colors.background);

    await pumpCover(tester, layout: LibraryCoverLayout.detail);
    final detail = tester.widget<ColoredBox>(
      find.byKey(const Key('typographic-cover-background')),
    );
    expect(detail.color, colors.background);
  });
}
