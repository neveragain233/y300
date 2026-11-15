import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../test_support/localized_test_app.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/core/media/image_display_provider.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/presentation/services/default_forum_image_precache_service.dart';
import 'package:y300/features/cache/domain/services/forum_image_precache_service.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/domain/image_session/reader_image_session.dart';
import 'package:y300/features/reader_shared/presentation/services/reader_image_session_preload_coordinator.dart';
import 'package:y300/features/reader_shared/presentation/services/reader_image_session_store.dart';
import 'package:y300/features/reader_shared/presentation/widgets/reader_session_image.dart';

void main() {
  test('session entry upgrades from disk ready to decoded', () {
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 4,
      items: [item],
    );
    final binding = store.bindingFor(item);
    final changes = <ReaderImageSessionStatus>[];
    binding.addListener(() => changes.add(binding.value.status));

    expect(
      store.applyPreloadResult(
        readerOwnerId: item.ownerId,
        itemId: item.id,
        generation: 4,
        sourceUrl: item.url,
        cacheKey: item.cacheKey,
        kind: ReaderImageSessionPreloadKind.disk,
        result: const ForumImagePrecacheResult(
          success: true,
          cacheKey: 'reader-cache-0',
          localPath: 'C:/cache/page.jpg',
        ),
      ),
      isTrue,
    );
    expect(binding.value.status, ReaderImageSessionStatus.diskReady);
    expect(binding.value.localPath, 'C:/cache/page.jpg');

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 4,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: const ForumImagePrecacheResult(
        success: true,
        decoded: true,
        cacheKey: 'reader-cache-0',
        localPath: 'C:/cache/page.jpg',
      ),
    );

    expect(binding.value.status, ReaderImageSessionStatus.decoded);
    expect(binding.value.decoded, isTrue);
    expect(changes, <ReaderImageSessionStatus>[
      ReaderImageSessionStatus.diskReady,
      ReaderImageSessionStatus.decoded,
    ]);
  });

  test('a failed decode request never marks the entry decoded', () {
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    final binding = store.bindingFor(item);

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: const ForumImagePrecacheResult(
        success: false,
        failureReason: 'decode_failed',
      ),
    );

    expect(binding.value.status, ReaderImageSessionStatus.failed);
    expect(binding.value.decoded, isFalse);
    expect(binding.value.failureReason, 'decode_failed');
  });

  test('explicit retry success advances the generation for the same path', () {
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    final binding = store.bindingFor(item);

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: const ForumImagePrecacheResult(
        success: true,
        decoded: true,
        cacheKey: 'reader-cache-0',
        localPath: 'C:/cache/page.jpg',
      ),
    );
    final revisionBefore = binding.value.retryRevision;

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: const ForumImagePrecacheResult(
        success: true,
        decoded: true,
        cacheKey: 'reader-cache-0',
        localPath: 'C:/cache/page.jpg',
      ),
      explicitRetry: true,
    );

    expect(binding.value.retryRevision, revisionBefore + 1);
    expect(binding.value.localPath, 'C:/cache/page.jpg');
    expect(binding.value.status, ReaderImageSessionStatus.decoded);
  });

  test('a failed explicit retry keeps the display generation', () {
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    final binding = store.bindingFor(item);

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: const ForumImagePrecacheResult(
        success: false,
        failureReason: 'decode_failed',
      ),
      explicitRetry: true,
    );

    expect(binding.value.retryRevision, 0);
    expect(binding.value.status, ReaderImageSessionStatus.failed);
  });

  test('stale generation cannot promote a new owner entry', () {
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    store.startSession(
      readerOwnerId: 'new-owner',
      generation: 2,
      items: [item.copyWith(ownerId: 'new-owner', id: 'new-item')],
    );

    final applied = store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.disk,
      result: const ForumImagePrecacheResult(
        success: true,
        cacheKey: 'reader-cache-0',
        localPath: 'C:/old/page.jpg',
      ),
    );

    expect(applied, isFalse);
    expect(store.generation, 2);
    expect(store.readerOwnerId, 'new-owner');
  });

  test('display and decoded preload use the same local provider key', () {
    final display = resolveDownscaledFileImageProvider(
      localPath: 'C:/cache/page.jpg',
      fit: BoxFit.contain,
      displaySize: const Size(320, 640),
      devicePixelRatio: 1,
    );
    final precache = defaultForumPrecacheImageProviderBuilder(
      localPath: 'C:/cache/page.jpg',
      fit: BoxFit.contain,
      expectedDisplaySize: const Size(320, 640),
      devicePixelRatio: 1,
    );

    expect(display, equals(precache));
  });

  testWidgets('ReaderSessionImage consumes a promoted local path', (
    tester,
  ) async {
    final directory = io.Directory.systemTemp.createTempSync(
      'reader-session-image-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final localFile = io.File('${directory.path}/page.png')
      ..writeAsBytesSync(base64Decode(_onePixelPngBase64));
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    final binding = store.bindingFor(item);
    binding.promoteLocalPath(localFile.path);

    await tester.pumpWidget(
      LocalizedTestApp(
        home: ReaderSessionImage(
          sessionBinding: binding,
          cacheRequest: ImageCacheRequest(
            cacheKey: item.cacheKey,
            sourceUrl: item.url,
            ownerType: ImageCacheOwnerType.thread,
            ownerId: item.ownerId,
            role: ImageCacheRole.threadInline,
          ),
          fit: BoxFit.contain,
          expectedDisplaySize: const Size(320, 640),
          placeholder: const SizedBox(key: Key('session-placeholder')),
        ),
      ),
    );
    await tester.pump();

    final cachedImage = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage),
    );
    expect(cachedImage.showDelayedLoadingIndicator, isTrue);
    expect(
      cachedImage.loadingIndicatorDelay,
      const Duration(milliseconds: 300),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<ResizeImage>());
  });

  testWidgets('ReaderSessionImage restarts a same-path recovery', (
    tester,
  ) async {
    final directory = io.Directory.systemTemp.createTempSync(
      'reader-session-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final localFile = io.File('${directory.path}/page.png')
      ..writeAsBytesSync(base64Decode(_onePixelPngBase64));
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    final binding = store.bindingFor(item);
    binding.promoteLocalPath(localFile.path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(_NoopImageCacheService()),
        ],
        child: LocalizedTestApp(
          home: ReaderSessionImage(
            sessionBinding: binding,
            cacheRequest: ImageCacheRequest(
              cacheKey: item.cacheKey,
              sourceUrl: item.url,
              ownerType: ImageCacheOwnerType.thread,
              ownerId: item.ownerId,
              role: ImageCacheRole.threadInline,
            ),
            fit: BoxFit.contain,
            expectedDisplaySize: const Size(320, 640),
            placeholder: const SizedBox(key: Key('session-placeholder')),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage),
    );

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: ForumImagePrecacheResult(
        success: true,
        decoded: true,
        cacheKey: item.cacheKey,
        localPath: localFile.path,
      ),
      explicitRetry: true,
    );
    await tester.pump();

    final after = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage),
    );
    expect(after.preferredLocalPath, localFile.path);
    expect(after.retryToken, isNot(before.retryToken));
  });

  testWidgets('an explicit retry replaces a failed image stream', (
    tester,
  ) async {
    final directory = io.Directory.systemTemp.createTempSync(
      'reader-session-recover-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final corruptFile = io.File('${directory.path}/page.png')
      ..writeAsStringSync('invalid raster image');
    final recoveredFile = io.File('${directory.path}/page-recovered.png')
      ..writeAsBytesSync(base64Decode(_onePixelPngBase64));
    final store = ReaderImageSessionStore();
    addTearDown(store.dispose);
    final item = _item();
    store.startSession(
      readerOwnerId: item.ownerId,
      generation: 1,
      items: [item],
    );
    final binding = store.bindingFor(item);
    binding.promoteLocalPath(corruptFile.path);
    var failures = 0;

    // Resolve the real file provider in the async zone so the native decode
    // failure reaches the widget before the assertion.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(
              _NoopImageCacheService(),
            ),
          ],
          child: LocalizedTestApp(
            home: ReaderSessionImage(
              sessionBinding: binding,
              cacheRequest: ImageCacheRequest(
                cacheKey: item.cacheKey,
                sourceUrl: item.url,
                ownerType: ImageCacheOwnerType.thread,
                ownerId: item.ownerId,
                role: ImageCacheRole.threadInline,
              ),
              fit: BoxFit.contain,
              expectedDisplaySize: const Size(320, 640),
              placeholder: const SizedBox(key: Key('session-placeholder')),
              errorPlaceholder: const SizedBox(key: Key('session-error')),
              onImageFailed: () => failures++,
            ),
          ),
        ),
      );
      await tester.pump();
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final stream = provider.resolve(ImageConfiguration.empty);
      final failed = Completer<void>();
      final listener = ImageStreamListener((image, _) {
        image.dispose();
        failed.completeError(StateError('corrupt bytes decoded'));
      }, onError: (Object _, StackTrace? _) => failed.complete());
      stream.addListener(listener);
      try {
        await failed.future.timeout(const Duration(seconds: 5));
      } finally {
        stream.removeListener(listener);
      }
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-error')), findsOneWidget);
    expect(failures, 1);

    store.applyPreloadResult(
      readerOwnerId: item.ownerId,
      itemId: item.id,
      generation: 1,
      sourceUrl: item.url,
      cacheKey: item.cacheKey,
      kind: ReaderImageSessionPreloadKind.decoded,
      result: ForumImagePrecacheResult(
        success: true,
        decoded: true,
        cacheKey: item.cacheKey,
        localPath: recoveredFile.path,
      ),
      explicitRetry: true,
    );
    await tester.pump();

    expect(find.byKey(const Key('session-error')), findsNothing);
    final restored = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage),
    );
    expect(restored.preferredLocalPath, recoveredFile.path);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NoopImageCacheService extends Fake implements ImageCacheService {}

ContinuousImageItem _item({String ownerId = 'reader-owner'}) {
  return ContinuousImageItem(
    ownerId: ownerId,
    id: '$ownerId:item-0',
    url: 'https://img.test/page-0.jpg',
    cacheKey: 'reader-cache-0',
    index: 0,
    sourceKind: ContinuousImageSourceKind.threadImageReader,
  );
}

const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';
