part of 'comic_reader_controller_test.dart';

void _lateResolutionCases() {
  test(
    'preloaded last image resolution does not complete an unseen episode',
    () async {
      final repository = _ReaderRepoForControllerTest();
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
      await container.read(comicReaderControllerProvider(args).future);

      final notifier = container.read(
        comicReaderControllerProvider(args).notifier,
      );
      await notifier.onImageResolved(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
        width: 900,
        height: 1600,
      );

      expect(writer.completedEpisodeIds, isEmpty);
      expect(repository.progressWrites, isEmpty);
    },
  );
}

void _staleResolutionCases() {
  test('stale image resolution callback is ignored when url no longer matches slot', () async {
    final repository = _ReaderRepoForControllerTest();
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
    await container.read(comicReaderControllerProvider(args).future);

    final notifier = container.read(
      comicReaderControllerProvider(args).notifier,
    );
    await notifier.onImageVisible(4);
    await notifier.onImageResolved(
      imageIndex: 4,
      imageUrl: 'https://img.test/stale.jpg',
      width: 900,
      height: 1600,
    );
    await notifier.onImageVisible(4);

    expect(writer.completedEpisodeIds, isEmpty);
    expect(repository.imageMetadataWrites, isEmpty);
  });
}

void _lateBookmarkCases() {
  test(
    'late bookmark write cannot replace the chapter selected in the meantime',
    () async {
      final repository = _ReaderRepoForControllerTest();
      final writer = _AggregatedReadingStateWriterSpy(repository);
      final container = _marksContainer(repository, writer);
      addTearDown(container.dispose);
      const args = ComicReaderArgs(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:101',
      );
      await container.read(comicReaderControllerProvider(args).future);
      final controller = container.read(
        comicReaderControllerProvider(args).notifier,
      );
      writer.bookmarkGate = Completer<void>();
      final pending = controller.toggleBookmark();
      expect(await controller.openEpisode(episodeId: 'yamibo:100:102'), isTrue);
      writer.bookmarkGate!.complete();
      expect(await pending, isNull);
      final state = container.read(comicReaderControllerProvider(args)).value!;
      expect(state.episodeId, 'yamibo:100:102');
      expect(state.isBookmarked, isFalse);
      expect(state.chapters.first.isBookmarked, isTrue);
    },
  );
}

void _lateProgressCases() {
  test(
    'stale reader progress callbacks cannot update the new episode',
    () async {
      final repository = _ReaderRepoForControllerTest(
        episodes: const <ComicEpisodeItem>[
          ComicEpisodeItem(
            episodeId: 'yamibo:100:90',
            comicId: 'yamibo:100',
            episodeTitle: '第90话',
            sourceTid: '90',
            sourceUrl: 'thread-90-1-1.html',
            orderIndex: 0,
            publishTimeText: null,
          ),
          ComicEpisodeItem(
            episodeId: 'yamibo:100:105',
            comicId: 'yamibo:100',
            episodeTitle: '第105话',
            sourceTid: '105',
            sourceUrl: 'thread-105-1-1.html',
            orderIndex: 1,
            publishTimeText: null,
          ),
        ],
      );
      final writer = _ReadingStateWriterSpy(repository);
      final container = ProviderContainer(
        overrides: [
          comicRepositoryProvider.overrideWithValue(repository),
          comicReadingStateWriterProvider.overrideWithValue(writer),
          comicReaderServiceProvider.overrideWith(
            (ref) async => _ReaderServiceSpy(),
          ),
          comicDownloadServiceProvider.overrideWithValue(
            _NoopComicDownloadService(),
          ),
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        ],
      );
      addTearDown(container.dispose);

      const args = ComicReaderArgs(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:90',
      );
      await container.read(comicReaderControllerProvider(args).future);
      final controller = container.read(
        comicReaderControllerProvider(args).notifier,
      );

      expect(await controller.openEpisode(episodeId: 'yamibo:100:105'), isTrue);
      await controller.onScrollProgress(
        currentIndex: 4,
        scrollOffset: 240,
        expectedEpisodeId: 'yamibo:100:90',
      );

      final state = container.read(comicReaderControllerProvider(args)).value!;
      expect(state.episodeId, 'yamibo:100:105');
      expect(state.currentImageIndex, 0);
      expect(repository.progressWrites, isEmpty);
    },
  );
}

void _displayProbeCases() {
  test(
    'concurrent display failures share one automatic chapter probe',
    () async {
      final repository = _ReaderRepoForControllerTest();
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
      final subscription = container.listen(
        comicReaderControllerProvider(args),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(comicReaderControllerProvider(args).future);
      final controller = container.read(
        comicReaderControllerProvider(args).notifier,
      );
      service.fetchCompleter = Completer<ComicEpisodeImagesFetchResult>();

      final firstFailure = controller.onImageDisplayFailed(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );
      final secondFailure = controller.onImageDisplayFailed(
        imageIndex: 3,
        imageUrl: 'https://img.test/101-4.jpg',
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchEpisodeImagesCalls, <String>['101']);
      service.fetchCompleter!.complete(
        const ComicEpisodeImagesFetched(<String>['https://img.test/new.jpg']),
      );
      await Future.wait(<Future<void>>[firstFailure, secondFailure]);
      await Future<void>.delayed(Duration.zero);
      final state = container
          .read(comicReaderControllerProvider(args))
          .requireValue;
      expect(state.images[3].retryRevision, 1);
      expect(state.images[4].retryRevision, 1);
      expect(repository.replaceEpisodeImagesCallCount, 0);

      await controller.onImageDisplayFailed(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.fetchEpisodeImagesCalls, <String>['101']);
      expect(
        container
            .read(comicReaderControllerProvider(args))
            .requireValue
            .images[4]
            .retryRevision,
        1,
      );
    },
  );

  test('a later display failure can start a new automatic probe', () async {
    final repository = _ReaderRepoForControllerTest();
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
    final subscription = container.listen(
      comicReaderControllerProvider(args),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(comicReaderControllerProvider(args).future);
    final controller = container.read(
      comicReaderControllerProvider(args).notifier,
    );

    await controller.onImageDisplayFailed(
      imageIndex: 4,
      imageUrl: 'https://img.test/101-5.jpg',
    );
    await Future<void>.delayed(Duration.zero);
    await controller.onImageDisplayFailed(
      imageIndex: 3,
      imageUrl: 'https://img.test/101-4.jpg',
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.fetchEpisodeImagesCalls, <String>['101', '101']);
    final state = container
        .read(comicReaderControllerProvider(args))
        .requireValue;
    expect(state.images[3].retryRevision, 1);
    expect(state.images[4].retryRevision, 1);
  });

  test(
    'manual retry joins a failed automatic probe and can probe again afterward',
    () async {
      final repository = _ReaderRepoForControllerTest();
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
      final subscription = container.listen(
        comicReaderControllerProvider(args),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(comicReaderControllerProvider(args).future);
      final controller = container.read(
        comicReaderControllerProvider(args).notifier,
      );
      service.fetchCompleter = Completer<ComicEpisodeImagesFetchResult>();

      final displayFailure = controller.onImageDisplayFailed(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );
      final joinedManualRetry = controller.prepareImageRetry(
        expectedEpisodeId: 'yamibo:100:101',
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchEpisodeImagesCalls, <String>['101']);
      service.fetchCompleter!.completeError(StateError('probe failed'));
      await Future.wait(<Future<void>>[displayFailure, joinedManualRetry]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(comicReaderControllerProvider(args))
            .requireValue
            .images[4]
            .retryRevision,
        0,
      );

      service.fetchCompleter = Completer<ComicEpisodeImagesFetchResult>();
      final laterManualRetry = controller.prepareImageRetry(
        expectedEpisodeId: 'yamibo:100:101',
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.fetchEpisodeImagesCalls, <String>['101', '101']);
      service.fetchCompleter!.complete(
        const ComicEpisodeImagesFetched(<String>['https://img.test/new.jpg']),
      );
      await laterManualRetry;
    },
  );

  test('stale display failure does not start an automatic probe', () async {
    final repository = _ReaderRepoForControllerTest();
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
    final subscription = container.listen(
      comicReaderControllerProvider(args),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(comicReaderControllerProvider(args).future);
    final controller = container.read(
      comicReaderControllerProvider(args).notifier,
    );

    await controller.onImageDisplayFailed(
      imageIndex: 4,
      imageUrl: 'https://img.test/101-5.jpg',
      expectedEpisodeId: 'yamibo:100:102',
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.fetchEpisodeImagesCalls, isEmpty);
    expect(repository.cacheStatusWrites, isEmpty);
  });
}
