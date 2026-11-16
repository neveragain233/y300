import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/library_shared/data/providers/library_cover_providers.dart';
import 'package:y300/features/library_shared/data/services/library_cover_decode_scheduler.dart';
import 'package:y300/features/library_shared/data/services/library_cover_store.dart';
import 'package:y300/features/library_shared/data/services/library_cover_thumbnail_store.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/presentation/images/library_cover_image_provider.dart';
import 'package:y300/shared/widgets/library_cover_failure_placeholder.dart';
import 'package:y300/shared/widgets/library_cover_placeholder.dart';
import 'package:y300/shared/widgets/shelf/library_cover_identity.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_card.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';
import 'package:y300/shared/widgets/shelf/typographic_library_cover.dart';

import '../../../test_support/localized_test_app.dart';
import '../../../test_support/unavailable_library_cover_store.dart';

final Override _thumbnailStoreOverride = libraryCoverThumbnailStoreProvider
    .overrideWithValue(
      LibraryCoverThumbnailStore(
        // 缩略图目录在 widget 测试里不可用；lookup 会捕获并回落到原图。
        rootPath: () async => throw StateError('no thumbnail store in tests'),
      ),
    );

void main() {
  const identity = LibraryCoverIdentity(source: 'comic', workId: 'yamibo:1');

  Widget scoped(
    Widget child, {
    LibraryCoverStore coverStore = const UnavailableLibraryCoverStore(),
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: <Override>[
        libraryCoverStoreProvider.overrideWithValue(coverStore),
        libraryCoverDecodeSchedulerProvider.overrideWithValue(
          LibraryCoverDecodeScheduler(maxConcurrent: 3),
        ),
        _thumbnailStoreOverride,
        ...overrides,
      ],
      child: LocalizedTestApp(home: Scaffold(body: child)),
    );
  }

  Widget card({
    required String title,
    LibraryCoverAssetRef? coverAsset,
    String? coverImageUrl = 'https://example.com/cover.jpg',
    String? customCoverLocalPath,
    double? focusX,
    double? focusY,
    Widget? topLeftBadge,
    Widget? trailingBadge,
    bool showTwoLineCustomEllipsis = false,
    ShelfCoverLayerBuilder? coverLayerBuilder,
    LibraryCoverIdentity coverIdentity = identity,
  }) {
    return SizedBox(
      width: 120,
      height: 180,
      child: ShelfCoverCard(
        identity: coverIdentity,
        title: title,
        author: '作者甲',
        coverImageUrl: coverImageUrl,
        coverAsset: coverAsset,
        customCoverLocalPath: customCoverLocalPath,
        customCoverFocusX: focusX,
        customCoverFocusY: focusY,
        onTap: () {},
        topLeftBadge: topLeftBadge,
        trailingBadge: trailingBadge,
        showTwoLineCustomEllipsis: showTwoLineCustomEllipsis,
        coverLayerBuilder: coverLayerBuilder,
      ),
    );
  }

  testWidgets('no-cover card uses typographic cover with one title copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoped(
        card(
          title: '无封面标题',
          coverImageUrl: null,
          topLeftBadge: const Text('角标'),
        ),
      ),
    );

    expect(find.byType(TypographicLibraryCover), findsOneWidget);
    expect(find.text('无封面标题'), findsOneWidget);
    expect(find.text('作者甲'), findsOneWidget);
    expect(find.text('角标'), findsOneWidget);
    expect(find.byKey(const Key('typographic-cover-title')), findsOneWidget);
    expect(find.byType(LibraryCoverPlaceholder), findsNothing);
    expect(find.byType(LibraryCoverFailurePlaceholder), findsNothing);
  });

  testWidgets('configured cover keeps the bottom title overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoped(
        card(
          title: '有封面标题',
          coverAsset: const LibraryCoverAssetRef(
            assetId: 'comic/yamibo:1/source',
            revision: 1,
            kind: LibraryCoverAssetKind.source,
          ),
          trailingBadge: const Text('漫'),
        ),
        coverStore: _PendingCoverStore(),
      ),
    );
    await tester.pump();

    expect(find.byType(TypographicLibraryCover), findsNothing);
    expect(find.text('有封面标题'), findsOneWidget);
    expect(find.text('漫'), findsOneWidget);
    expect(find.byKey(const Key('shelf-cover-placeholder')), findsOneWidget);
  });

  testWidgets('cover title baseline matches typographic cover baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoped(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            card(
              title: '有封面标题',
              coverAsset: const LibraryCoverAssetRef(
                assetId: 'comic/yamibo:1/source',
                revision: 1,
                kind: LibraryCoverAssetKind.source,
              ),
            ),
            card(
              title: '无封面标题',
              coverImageUrl: null,
              coverIdentity: const LibraryCoverIdentity(
                source: 'novel',
                workId: 'novel:1:2',
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final coveredBottom = tester.getBottomLeft(find.text('有封面标题')).dy;
    final plainBottom = tester.getBottomLeft(find.text('无封面标题')).dy;
    expect(plainBottom, coveredBottom);
  });

  testWidgets('ShelfCoverCard uses compact shared cover geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoped(card(title: 'Compact Cover', coverImageUrl: null)),
    );

    final cardFinder = find.byType(ShelfCoverCard);
    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: cardFinder, matching: find.byType(AnimatedContainer)),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(8));

    final clip = tester.widget<ClipRRect>(
      find.descendant(of: cardFinder, matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(7));
  });

  testWidgets('cover provider uses the actual inner image size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      scoped(
        card(
          title: 'Sized Cover',
          coverAsset: const LibraryCoverAssetRef(
            assetId: 'comic/sized/source',
            revision: 1,
            kind: LibraryCoverAssetKind.source,
          ),
        ),
      ),
    );
    await tester.pump();

    final imageFinder = find.descendant(
      of: find.byType(ShelfCoverCard),
      matching: find.byType(Image),
    );
    final imageSize = tester.getSize(imageFinder);
    final provider = tester.widget<Image>(imageFinder).image;
    final coverProvider = provider as LibraryCoverImageProvider;

    expect(imageSize, const Size(112, 172));
    expect(coverProvider.decodeTarget.targetWidthPx, imageSize.width * 2);
    expect(coverProvider.decodeTarget.targetHeightPx, imageSize.height * 2);
    expect(coverProvider.decodeTarget.targetWidthPx, isNot(240));
    expect(coverProvider.decodeTarget.targetHeightPx, isNot(360));
  });

  testWidgets('ShelfCoverCard supports custom two-line ellipsis mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoped(
        card(
          title: '这是一个非常非常长的标题用于验证通用书架卡片的两行中文省略逻辑是否生效',
          coverAsset: const LibraryCoverAssetRef(
            assetId: 'comic/long/source',
            revision: 1,
            kind: LibraryCoverAssetKind.source,
          ),
          showTwoLineCustomEllipsis: true,
        ),
      ),
    );

    expect(find.textContaining('···'), findsOneWidget);
  });

  testWidgets('loading cover keeps a neutral surface without icons', (
    tester,
  ) async {
    final store = _PendingCoverStore();
    final theme = AppTheme.dark();
    final palette = const ShelfThemePaletteResolver().resolve(theme);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryCoverStoreProvider.overrideWithValue(store),
          libraryCoverDecodeSchedulerProvider.overrideWithValue(
            LibraryCoverDecodeScheduler(maxConcurrent: 3),
          ),
          _thumbnailStoreOverride,
        ],
        child: LocalizedTestApp(
          theme: theme,
          home: Scaffold(
            body: card(
              title: 'Loading Cover',
              coverAsset: const LibraryCoverAssetRef(
                assetId: 'comic/loading/source',
                revision: 1,
                kind: LibraryCoverAssetKind.source,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final fallback = tester.widget<LibraryCoverPlaceholder>(
      find.byKey(const Key('shelf-cover-placeholder')),
    );
    expect(fallback.color, palette.coverPlaceholderBackground);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(LibraryCoverFailurePlaceholder), findsNothing);
  });

  testWidgets('failed cover exposes retry and invalidates the asset', (
    tester,
  ) async {
    final store = _RecordingFailingCoverStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryCoverStoreProvider.overrideWithValue(store),
          libraryCoverDecodeSchedulerProvider.overrideWithValue(
            LibraryCoverDecodeScheduler(maxConcurrent: 3),
          ),
          _thumbnailStoreOverride,
        ],
        child: LocalizedTestApp(
          home: Scaffold(
            body: card(
              title: 'Failed Cover',
              coverAsset: const LibraryCoverAssetRef(
                assetId: 'comic/failed/source',
                revision: 1,
                kind: LibraryCoverAssetKind.source,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LibraryCoverFailurePlaceholder), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('Failed Cover'), findsOneWidget);

    await tester.tap(find.byType(LibraryCoverFailurePlaceholder));
    await tester.pumpAndSettle();

    expect(store.invalidatedAssetIds, <String>['comic/failed/source']);
    // 重试清理缓存后重新走一次解码请求。
    expect(store.ensureCalls, 2);
    // 资源仍然不可用，重试后继续显示可重试失败态而不是空白。
    expect(find.byType(LibraryCoverFailurePlaceholder), findsOneWidget);
  });

  testWidgets('ShelfCoverCard applies focus only to custom covers', (
    tester,
  ) async {
    final alignments = <AlignmentGeometry>[];

    Future<void> pumpCard({
      String? customCoverLocalPath,
      double? focusX,
      double? focusY,
    }) {
      return tester.pumpWidget(
        scoped(
          card(
            title: 'Focused Cover',
            customCoverLocalPath: customCoverLocalPath,
            focusX: focusX,
            focusY: focusY,
            coverLayerBuilder: (context, config) {
              alignments.add(config.alignment);
              return config.placeholder;
            },
          ),
        ),
      );
    }

    await pumpCard(
      customCoverLocalPath: 'cache/custom-cover.jpg',
      focusX: 0.75,
      focusY: -0.5,
    );
    expect(alignments.last, const Alignment(0.75, -0.5));

    await pumpCard(focusX: 0.75, focusY: -0.5);
    expect(alignments.last, Alignment.center);

    await pumpCard(customCoverLocalPath: 'cache/custom-cover.jpg', focusX: 1);
    expect(alignments.last, Alignment.center);
  });
}

class _PendingCoverStore implements LibraryCoverStore {
  final Completer<io.File> _pending = Completer<io.File>();

  @override
  Future<int> calculateUsageBytes() async => 0;

  @override
  Future<void> deleteAsset(String assetId) async {}

  @override
  Future<void> deleteOlderRevisions(LibraryCoverAssetRef asset) async {}

  @override
  Future<io.File> ensureAvailable(LibraryCoverAssetRef asset) =>
      _pending.future;

  @override
  Future<io.File> fileFor(LibraryCoverAssetRef asset) => _pending.future;

  @override
  Future<void> installLocalFile({
    required LibraryCoverAssetRef asset,
    required String sourcePath,
  }) async {}

  @override
  Future<void> invalidate(LibraryCoverAssetRef asset) async {}
}

class _RecordingFailingCoverStore implements LibraryCoverStore {
  final List<String> invalidatedAssetIds = <String>[];
  int ensureCalls = 0;

  @override
  Future<int> calculateUsageBytes() async => 0;

  @override
  Future<void> deleteAsset(String assetId) async {}

  @override
  Future<void> deleteOlderRevisions(LibraryCoverAssetRef asset) async {}

  @override
  Future<io.File> ensureAvailable(LibraryCoverAssetRef asset) async {
    ensureCalls += 1;
    throw StateError('cover unavailable');
  }

  @override
  Future<io.File> fileFor(LibraryCoverAssetRef asset) async {
    throw StateError('cover unavailable');
  }

  @override
  Future<void> installLocalFile({
    required LibraryCoverAssetRef asset,
    required String sourcePath,
  }) async {}

  @override
  Future<void> invalidate(LibraryCoverAssetRef asset) async {
    invalidatedAssetIds.add(asset.assetId);
  }
}
