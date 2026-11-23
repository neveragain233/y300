import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/forum_image_precache_service.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/reader_shared/data/reader_preferences/reader_preferences_snapshot_codec.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/engine/engine.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  const codec = ReaderPreferencesSnapshotCodec();

  Widget buildHost({required bool supportsPageTurnEffects, bool eInk = false}) {
    return EInkModeScope(
      enabled: eInk,
      child: ProviderScope(
        overrides: [
          forumImagePrecacheServiceProvider.overrideWithValue(
            _NoopForumImagePrecacheService(),
          ),
        ],
        child: LocalizedTestApp(
          home: ImageReaderEngine(
            pageKey: const Key('page-turn-test-page'),
            listKey: const Key('page-turn-test-list'),
            capability: _PageTurnTestCapability(
              supportsPageTurnEffects: supportsPageTurnEffects,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'wraps horizontal pages with ReaderSheetPageTransition when capability supports effects',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.imageReaderSnapshotV1.name: codec.encode(
          ReaderPreferences.defaults().copyWith(
            readerMode: ReaderModePreference.ltr,
            pageEffect: ReaderPageEffect.paper,
            pageSpeed: ReaderPageSpeed.brisk,
          ),
        ),
      });

      await tester.pumpWidget(buildHost(supportsPageTurnEffects: true));
      await tester.pumpAndSettle();

      final transitions = tester
          .widgetList<ReaderSheetPageTransition>(
            find.byType(ReaderSheetPageTransition),
          )
          .toList();
      expect(transitions, isNotEmpty);
      expect(transitions.first.effect, ReaderPageEffect.paper);
      final pageView = tester.widget<PageView>(
        find.byKey(const Key('page-turn-test-page')),
      );
      expect(pageView.pageSnapping, isFalse);
    },
  );

  testWidgets(
    'falls back to slide in E-ink mode even when capability supports effects',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.imageReaderSnapshotV1.name: codec.encode(
          ReaderPreferences.defaults().copyWith(
            readerMode: ReaderModePreference.ltr,
            pageEffect: ReaderPageEffect.paper,
          ),
        ),
      });

      await tester.pumpWidget(
        buildHost(supportsPageTurnEffects: true, eInk: true),
      );
      await tester.pumpAndSettle();

      final transitions = tester
          .widgetList<ReaderSheetPageTransition>(
            find.byType(ReaderSheetPageTransition),
          )
          .toList();
      expect(transitions, isNotEmpty);
      expect(transitions.first.effect, ReaderPageEffect.slide);
    },
  );

  testWidgets(
    'keeps fixed native slide for thread/blog viewers without page-turn effects',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.imageReaderSnapshotV1.name: codec.encode(
          ReaderPreferences.defaults().copyWith(
            readerMode: ReaderModePreference.ltr,
            pageEffect: ReaderPageEffect.paper,
          ),
        ),
      });

      await tester.pumpWidget(buildHost(supportsPageTurnEffects: false));
      await tester.pumpAndSettle();

      expect(find.byType(ReaderSheetPageTransition), findsNothing);
      final pageView = tester.widget<PageView>(
        find.byKey(const Key('page-turn-test-page')),
      );
      expect(pageView.pageSnapping, isTrue);
    },
  );
}

class _PageTurnTestCapability extends ReaderCapability {
  _PageTurnTestCapability({required this.supportsPageTurnEffects});

  final bool supportsPageTurnEffects;

  @override
  bool get supportsPagedPageTurnEffects => supportsPageTurnEffects;

  @override
  ReaderContent get content => ReaderContent(
    ownerId: 'owner-page-turn',
    items: List<ContinuousImageItem>.generate(2, (index) {
      return ContinuousImageItem(
        ownerId: 'owner-page-turn',
        id: 'img-$index',
        url: 'https://img.test/$index.jpg',
        cacheKey: 'img-$index',
        index: index,
        sourceKind: ContinuousImageSourceKind.threadImageReader,
        knownWidth: 100,
        knownHeight: 140,
      );
    }),
  );

  @override
  String? get imageReferer => null;

  @override
  ReaderTitleSpec titleFor(ReaderEngineContext context) {
    return const ReaderTitleSpec(title: 'page turn test');
  }

  @override
  Widget buildImageContent(BuildContext context, ReaderImageBuildSpec spec) {
    return ColoredBox(
      color: Colors.blueGrey,
      child: Center(child: Text('page-${spec.index}')),
    );
  }

  @override
  ImageCacheRequest cacheRequestFor(ContinuousImageItem item) {
    return ImageCacheRequest(
      cacheKey: item.cacheKey,
      sourceUrl: item.url,
      ownerType: ImageCacheOwnerType.thread,
      ownerId: item.ownerId,
      role: ImageCacheRole.threadInline,
    );
  }
}

class _NoopForumImagePrecacheService implements ForumImagePrecacheService {
  @override
  Future<ForumImagePrecacheResult> ensureDiskCached(
    ForumImageLoadSpec spec,
  ) async {
    return const ForumImagePrecacheResult(success: true, decoded: false);
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
