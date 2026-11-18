part of 'comic_reader_controller_test.dart';

void _readerModeCases() {
  test(
    'page visibility and jumps leave image preparation to shared engine',
    () async {
      final repository = _ReaderRepoForControllerTest(imageCount: 10);
      final service = _ReaderServiceSpy();
      final writer = _ReadingStateWriterSpy(repository);
      final container = ProviderContainer(
        overrides: [
          comicRepositoryProvider.overrideWithValue(repository),
          comicReadingStateWriterProvider.overrideWithValue(writer),
          comicReaderServiceProvider.overrideWith((ref) async => service),
          comicDownloadServiceProvider.overrideWithValue(
            _NoopComicDownloadService(),
          ),
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        ],
      );
      addTearDown(container.dispose);

      const args = ComicReaderArgs(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:101',
      );
      final subscription = container.listen<AsyncValue<ComicReaderViewState>>(
        comicReaderControllerProvider(args),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final initialState = await container.read(
        comicReaderControllerProvider(args).future,
      );

      final controller = container.read(
        comicReaderControllerProvider(args).notifier,
      );
      await controller.onImageVisible(3);
      await controller.jumpToImageIndex(6, scrollOffset: 120);

      expect(service.cachedImageUrls, isEmpty);
      expect(service.fetchEpisodeImagesCalls, isEmpty);
      expect(repository.cacheStatusWrites, isEmpty);
      expect(repository.progressWrites.last.imageIndex, 6);
      expect(initialState.nextChapter?.episodeId, 'yamibo:100:102');
    },
  );
}

void _coverActionCases() {
  test(
    'setCurrentImageAsCover installs current page into the cover store',
    () async {
      final repository = _ReaderRepoForControllerTest();
      final service = _ReaderServiceSpy();
      final writer = _ReadingStateWriterSpy(repository);
      final imageCache = _FakeImageCacheService();
      final coverStore = _ControllerCoverStoreFake();
      final container = ProviderContainer(
        overrides: [
          comicRepositoryProvider.overrideWithValue(repository),
          comicReadingStateWriterProvider.overrideWithValue(writer),
          comicReaderServiceProvider.overrideWith((ref) async => service),
          comicDownloadServiceProvider.overrideWithValue(
            _NoopComicDownloadService(),
          ),
          imageCacheServiceProvider.overrideWithValue(imageCache),
          libraryCoverStoreProvider.overrideWithValue(coverStore),
        ],
      );
      addTearDown(container.dispose);

      const args = ComicReaderArgs(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:101',
      );
      await container.read(comicReaderControllerProvider(args).future);

      final notice = await container
          .read(comicReaderControllerProvider(args).notifier)
          .setCurrentImageAsCover();

      expect(coverStore.installedSourcePath, '/cache/mock.jpg');
      expect(coverStore.installedAsset?.assetId, 'comic/yamibo:100/custom');
      expect(coverStore.installedAsset?.revision, 1);
      expect(coverStore.installedAsset?.kind, LibraryCoverAssetKind.custom);
      expect(repository.lastActivatedCustomCoverRevision, 1);
      expect(notice, ComicReaderNoticeCode.coverUpdated);
    },
  );
}
