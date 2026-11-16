import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/forum_image_precache_service.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/presentation/engine/engine.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'reader_pref_mode': 'ltr',
    });
  });

  Future<void> pumpEngine(
    WidgetTester tester,
    _ThumbnailCapability capability,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          forumImagePrecacheServiceProvider.overrideWithValue(
            _NoopForumImagePrecacheService(),
          ),
        ],
        child: LocalizedTestApp(
          home: ImageReaderEngine(capability: capability),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('shared-reader-center-tap-zone'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'strip follows toolbar visibility, previews without progress and commits once',
    (tester) async {
      final capability = _ThumbnailCapability();
      await pumpEngine(tester, capability);

      expect(find.byKey(ReaderThumbnailStrip.listKey), findsNothing);

      await openMenu(tester);
      expect(find.byKey(ReaderThumbnailStrip.listKey), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('shared-reader-current-label')))
            .data,
        '3',
      );
      expect(
        tester.widget<Text>(find.byKey(ReaderThumbnailStrip.pageLabelKey)).data,
        '3 / 6',
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ReaderThumbnailStrip.listKey)),
      );
      await gesture.moveBy(const Offset(-128, 0));
      await tester.pump();

      expect(capability.seeks, isEmpty);
      expect(capability.progress, isEmpty);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('shared-reader-current-label')))
            .data,
        '5',
      );
      expect(
        tester.widget<Text>(find.byKey(ReaderThumbnailStrip.pageLabelKey)).data,
        '5 / 6',
      );
      expect(find.byKey(ReaderThumbnailStrip.previewKey), findsOneWidget);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(capability.seeks, <int>[4]);

      await openMenu(tester);
      expect(find.byKey(ReaderThumbnailStrip.listKey), findsNothing);
      expect(
        find.byKey(const Key('shared-reader-thumbnail-strip-slot')),
        findsNothing,
      );
    },
  );

  testWidgets('cancelling the drag keeps the confirmed page', (tester) async {
    final capability = _ThumbnailCapability();
    await pumpEngine(tester, capability);
    await openMenu(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ReaderThumbnailStrip.listKey)),
    );
    await gesture.moveBy(const Offset(-96, 0));
    await tester.pump();
    expect(capability.seeks, isEmpty);

    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(capability.seeks, isEmpty);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('shared-reader-current-label')))
          .data,
      '3',
    );
    expect(
      tester.widget<Text>(find.byKey(ReaderThumbnailStrip.pageLabelKey)).data,
      '3 / 6',
    );
  });

  testWidgets('single-image chapters never mount the strip', (tester) async {
    final capability = _ThumbnailCapability(itemCount: 1, initialIndex: 0);
    await pumpEngine(tester, capability);
    await openMenu(tester);

    expect(find.byKey(ReaderThumbnailStrip.listKey), findsNothing);
    expect(
      find.byKey(const Key('shared-reader-thumbnail-strip-slot')),
      findsNothing,
    );
  });
}

class _ThumbnailCapability extends ReaderCapability {
  _ThumbnailCapability({this.itemCount = 6, this.initialIndex = 2});

  final int itemCount;
  final int initialIndex;
  final List<int> seeks = <int>[];
  final List<int> progress = <int>[];

  @override
  bool get showsThumbnailStrip => true;

  @override
  ReaderContent get content => ReaderContent(
    ownerId: 'thumbnail-owner',
    initialIndex: initialIndex,
    items: List<ContinuousImageItem>.generate(
      itemCount,
      (index) => ContinuousImageItem(
        ownerId: 'thumbnail-owner',
        id: 'thumbnail-owner:$index',
        url: 'https://img.test/thumbnail-$index.jpg',
        cacheKey: 'reader/thumbnail-$index',
        index: index,
        sourceKind: ContinuousImageSourceKind.threadImageReader,
        knownWidth: 200,
        knownHeight: 300,
      ),
    ),
  );

  @override
  String? get imageReferer => null;

  @override
  ReaderTitleSpec titleFor(ReaderEngineContext context) {
    return ReaderTitleSpec(
      title: 'reader',
      subtitle: '${context.currentIndex + 1} / ${context.totalCount}',
    );
  }

  @override
  Widget buildImageContent(BuildContext context, ReaderImageBuildSpec spec) {
    return ColoredBox(
      color: Colors.black,
      child: Center(child: Text('${spec.index}')),
    );
  }

  @override
  Widget buildThumbnailStrip(
    BuildContext context,
    ReaderThumbnailStripSpec spec,
  ) {
    return ReaderThumbnailStrip(
      spec: spec,
      imageBuilder: (context, image) => ColoredBox(
        color: Colors.blue,
        child: Center(child: Text('${image.index + 1}')),
      ),
    );
  }

  @override
  void onScrollProgress({required int index, required double offset}) {
    progress.add(index);
  }

  @override
  Future<void> onSeek({required int index, required double offset}) async {
    seeks.add(index);
  }

  @override
  ImageCacheRequest cacheRequestFor(ContinuousImageItem item) {
    return ImageCacheRequest(
      cacheKey: item.cacheKey,
      sourceUrl: item.url,
      ownerType: ImageCacheOwnerType.thread,
      ownerId: item.ownerId,
      role: ImageCacheRole.threadInline,
      imageIndex: item.index,
      retentionClass: ImageRetentionClass.recentReader,
    );
  }
}

class _NoopForumImagePrecacheService implements ForumImagePrecacheService {
  @override
  Future<ForumImagePrecacheResult> ensureDiskCached(
    ForumImageLoadSpec spec,
  ) async {
    return const ForumImagePrecacheResult(success: true);
  }

  @override
  Future<ForumImagePrecacheResult> precacheDecoded({
    required BuildContext context,
    required ForumImageLoadSpec spec,
    Size? expectedDisplaySize,
  }) async {
    return const ForumImagePrecacheResult(success: true, decoded: true);
  }
}
