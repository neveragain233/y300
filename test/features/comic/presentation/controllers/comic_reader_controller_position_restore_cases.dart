part of 'comic_reader_controller_test.dart';

void _restoreProgressCases() {
  test('opening a chapter restores that chapter progress', () async {
    final repository = _ReaderRepoForControllerTest(
      readingProgresses: <ComicReadingProgress>[
        ComicReadingProgress(
          comicId: 'yamibo:100',
          episodeId: 'yamibo:100:101',
          imageIndex: 4,
          scrollOffset: 80,
          updatedAt: DateTime(2026, 7, 15, 12),
        ),
        ComicReadingProgress(
          comicId: 'yamibo:100',
          episodeId: 'yamibo:100:102',
          imageIndex: 2,
          scrollOffset: 35,
          updatedAt: DateTime(2026, 7, 14, 12),
        ),
      ],
    );
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
      episodeId: 'yamibo:100:102',
    );
    final state = await container.read(
      comicReaderControllerProvider(args).future,
    );

    expect(state.episodeId, 'yamibo:100:102');
    expect(state.currentImageIndex, 2);
    expect(state.lastScrollOffset, 35);
  });

  test('opening a read chapter starts at the first image', () async {
    final repository = _ReaderRepoForControllerTest(
      readingProgresses: <ComicReadingProgress>[
        ComicReadingProgress(
          comicId: 'yamibo:100',
          episodeId: 'yamibo:100:102',
          imageIndex: 4,
          scrollOffset: 180,
          updatedAt: DateTime(2026, 7, 15, 12),
        ),
      ],
    );
    final writer = _ReadingStateWriterSpy(repository)
      ..initiallyReadEpisodeIds.add('yamibo:100:102');
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
      episodeId: 'yamibo:100:102',
    );
    final state = await container.read(
      comicReaderControllerProvider(args).future,
    );

    expect(state.isCurrentEpisodeRead, isTrue);
    expect(state.currentImageIndex, 0);
    expect(state.lastScrollOffset, 0);
  });
}

void _scrollProgressCases() {
  test('onScrollProgress persists with debounce', () async {
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
    final subscription = container.listen<AsyncValue<ComicReaderViewState>>(
      comicReaderControllerProvider(args),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(comicReaderControllerProvider(args).future);

    final notifier = container.read(
      comicReaderControllerProvider(args).notifier,
    );
    await notifier.onScrollProgress(currentIndex: 1, scrollOffset: 30);
    await notifier.onScrollProgress(currentIndex: 2, scrollOffset: 60);
    await notifier.onScrollProgress(currentIndex: 3, scrollOffset: 90);

    // Allow debounce timer callback to run.
    await Future<void>.delayed(const Duration(milliseconds: 260));

    expect(repository.progressWrites, isNotEmpty);
    expect(repository.progressWrites.last.imageIndex, 3);
    expect(repository.progressWrites.last.scrollOffset, 90);
  });
}

void _visibilityRestoreCases() {
  test('last page visibility marks current episode completed once', () async {
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
    await notifier.onImageVisible(3);
    expect(writer.completedEpisodeIds, isEmpty);

    await notifier.onImageVisible(4);
    await notifier.onImageResolved(
      imageIndex: 4,
      imageUrl: 'https://img.test/101-5.jpg',
      width: 900,
      height: 1600,
    );
    await notifier.onImageVisible(4);

    expect(writer.completedEpisodeIds, <String>['yamibo:100:101']);
    expect(repository.progressWrites.last.imageIndex, 4);
  });
}

void _completionGateCases() {
  test(
    'last page visibility waits for image resolution before completion',
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
      await notifier.onImageVisible(4);
      expect(writer.completedEpisodeIds, isEmpty);

      await notifier.onImageResolved(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
        width: 900,
        height: 1600,
      );

      expect(writer.completedEpisodeIds, <String>['yamibo:100:101']);
      expect(repository.imageMetadataWrites.last.width, 900);
      expect(repository.imageMetadataWrites.last.height, 1600);
    },
  );

  test('persisted dimensions alone do not complete last page before display resolves', () async {
    final repository = _ReaderRepoForControllerTest(
      lastImageWidth: 900,
      lastImageHeight: 1600,
    );
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

    expect(writer.completedEpisodeIds, isEmpty);

    await notifier.onImageResolved(
      imageIndex: 4,
      imageUrl: 'https://img.test/101-5.jpg',
      width: 900,
      height: 1600,
    );

    expect(writer.completedEpisodeIds, <String>['yamibo:100:101']);
  });
}

void _lastPageCompletionCases() {
  test(
    'single page chapter completes only after image becomes visible',
    () async {
      final repository = _ReaderRepoForControllerTest(singlePage: true);
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
      expect(writer.completedEpisodeIds, isEmpty);

      final notifier = container.read(
        comicReaderControllerProvider(args).notifier,
      );
      await notifier.onImageVisible(0);
      await notifier.onImageResolved(
        imageIndex: 0,
        imageUrl: 'https://img.test/101-1.jpg',
        width: 900,
        height: 1600,
      );

      expect(writer.completedEpisodeIds, <String>['yamibo:100:101']);
    },
  );

  test('strict complete flag disabled allows last visible page without decode gate', () async {
    final repository = _ReaderRepoForControllerTest();
    final service = _ReaderServiceSpy();
    final writer = _ReadingStateWriterSpy(repository);
    final container = ProviderContainer(
      overrides: [
        comicRepositoryProvider.overrideWithValue(repository),
        comicReadingStateWriterProvider.overrideWithValue(writer),
        comicReaderFeatureFlagsProvider.overrideWithValue(
          ComicReaderFeatureFlags.defaults.copyWith(
            readerStrictCompleteRead: false,
          ),
        ),
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

    await container
        .read(comicReaderControllerProvider(args).notifier)
        .onImageVisible(4);

    expect(writer.completedEpisodeIds, <String>['yamibo:100:101']);
  });
}
