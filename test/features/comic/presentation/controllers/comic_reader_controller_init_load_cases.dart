part of 'comic_reader_controller_test.dart';

void _initialLoadCases() {
  test('repository exposes the expected episode fixture order', () async {
    final repository = _ReaderRepoForControllerTest();
    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:100',
      descending: false,
    );

    expect(episodes.first.episodeId, 'yamibo:100:101');
    expect(episodes.last.episodeId, 'yamibo:100:103');
  });
}

void _loadStateCases() {
  test(
    'loadState prefers downloaded CBZ images before repository cache',
    () async {
      final repository = _ReaderRepoForControllerTest();
      final service = _ReaderServiceSpy();
      final writer = _ReadingStateWriterSpy(repository);
      final downloadService = _DownloadedComicServiceFake(
        const <ComicEpisodeImageItem>[
          ComicEpisodeImageItem(
            episodeId: 'yamibo:100:101',
            imageUrl: 'downloaded://001.jpg',
            imageIndex: 0,
            cacheStatus: 'downloaded',
            localPath: '/storage/001.jpg',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          comicRepositoryProvider.overrideWithValue(repository),
          comicReadingStateWriterProvider.overrideWithValue(writer),
          comicReaderServiceProvider.overrideWith((ref) async => service),
          comicDownloadServiceProvider.overrideWithValue(downloadService),
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        ],
      );
      addTearDown(container.dispose);

      const args = ComicReaderArgs(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:101',
      );
      final state = await container.read(
        comicReaderControllerProvider(args).future,
      );

      expect(state.images, hasLength(1));
      expect(state.images.first.localPath, '/storage/001.jpg');
      expect(service.cachedImageUrls, isEmpty);
    },
  );
}

void _imageStatusCases() {
  test(
    'display failed image writes failed status and blocks completion',
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
      await notifier.onImageDisplayFailed(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );

      expect(writer.completedEpisodeIds, isEmpty);
      expect(service.fetchEpisodeImagesCalls, <String>['101']);
      expect(repository.replaceEpisodeImagesCallCount, 0);
      expect(
        repository.cacheStatusWrites,
        contains(
          isA<_CacheStatusWrite>()
              .having(
                (item) => item.imageUrl,
                'imageUrl',
                'https://img.test/101-5.jpg',
              )
              .having((item) => item.cacheStatus, 'cacheStatus', 'failed'),
        ),
      );
      final state = await container.read(
        comicReaderControllerProvider(args).future,
      );
      expect(state.failedImageCount, greaterThanOrEqualTo(1));
      expect(state.imageSessionRevision, 0);
    },
  );

  test(
    'resolved image clears previous display failure and can complete episode',
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
      await notifier.onImageDisplayFailed(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
      );
      await notifier.onImageResolved(
        imageIndex: 4,
        imageUrl: 'https://img.test/101-5.jpg',
        width: 900,
        height: 1600,
      );

      expect(writer.completedEpisodeIds, <String>['yamibo:100:101']);
      expect(
        repository.cacheStatusWrites,
        contains(
          isA<_CacheStatusWrite>()
              .having(
                (item) => item.imageUrl,
                'imageUrl',
                'https://img.test/101-5.jpg',
              )
              .having((item) => item.cacheStatus, 'cacheStatus', 'none'),
        ),
      );
      final state = await container.read(
        comicReaderControllerProvider(args).future,
      );
      expect(state.failedImageCount, 0);
    },
  );
}

void _episodeImageFetchCases() {
  test(
    '_ensureEpisodeImages 在 fetch 失败时把 AsyncValue 推入 error 态而非"空列表"',
    () async {
      final repository = _ReaderRepoForControllerTest(
        emptyEpisodeIds: const <String>{'yamibo:100:101'},
      );
      final service = _ReaderServiceSpy()
        ..fetchResultBuilder = (_) => const ComicEpisodeImagesFetchFailed(
          reason: ComicEpisodeImagesFetchFailureReason.network,
          message: '模拟超时',
        );
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

      // 等待 AsyncValue 落定为 error；不要直接 await `.future`——
      // 那条路径在某些 riverpod 版本上对 build() 的 throw 不会立即 reject。
      await _waitForCondition(
        () => container.read(comicReaderControllerProvider(args)).hasError,
        label: 'reader controller surfaces fetch failure as AsyncError',
      );

      final asyncValue = container.read(comicReaderControllerProvider(args));
      final error = asyncValue.error;
      expect(error, isA<ComicEpisodeImagesUnavailable>());
      final unavailable = error as ComicEpisodeImagesUnavailable;
      expect(unavailable.reason, ComicEpisodeImagesFetchFailureReason.network);
      expect(unavailable.isRetryable, isTrue);
      expect(unavailable.message, '模拟超时');

      // 失败也得有源头记录，避免静默吞错。
      expect(service.fetchEpisodeImagesCalls, <String>['101']);
      // DB 没有写入，且不会留下脏数据。
      expect(repository.savedImageUrlsByEpisode, isEmpty);
    },
  );

  test('_ensureEpisodeImages 拉取成功时把图片落库且 AsyncData 携带新图', () async {
    const fetchedUrls = <String>[
      'https://img.test/101-network-1.jpg',
      'https://img.test/101-network-2.jpg',
    ];
    final repository = _ReaderRepoForControllerTest(
      emptyEpisodeIds: const <String>{'yamibo:100:101'},
    );
    final service = _ReaderServiceSpy()
      ..fetchResultBuilder = (_) =>
          const ComicEpisodeImagesFetched(fetchedUrls);
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

    final viewState = await container.read(
      comicReaderControllerProvider(args).future,
    );

    expect(
      viewState.images.map((image) => image.imageUrl).toList(),
      fetchedUrls,
    );
    // 关键点：落库不能跟 controller 生命周期耦合——这是 bug 修复的核心。
    expect(repository.savedImageUrlsByEpisode['yamibo:100:101'], fetchedUrls);
  });

  test('_ensureEpisodeImages 拉取成功但首楼真无图时 AsyncData 为空列表（不进 error 态）', () async {
    final repository = _ReaderRepoForControllerTest(
      emptyEpisodeIds: const <String>{'yamibo:100:101'},
    );
    final service = _ReaderServiceSpy()
      ..fetchResultBuilder = (_) => const ComicEpisodeImagesFetched(<String>[]);
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

    final viewState = await container.read(
      comicReaderControllerProvider(args).future,
    );

    // 这是合法空态——UI 仍然走"当前章节没有可阅读图片"的提示，但不会抛错。
    expect(viewState.images, isEmpty);
    // 真空时不应该有任何持久化写入（避免污染 DB）。
    expect(repository.savedImageUrlsByEpisode, isEmpty);
  });

  test(
    'image retry probes the current chapter once before direct retry',
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

      final first = controller.prepareImageRetry(
        expectedEpisodeId: 'yamibo:100:101',
      );
      final second = controller.prepareImageRetry(
        expectedEpisodeId: 'yamibo:100:101',
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchEpisodeImagesCalls, <String>['101']);
      service.fetchCompleter!.complete(
        const ComicEpisodeImagesFetched(<String>['https://img.test/new.jpg']),
      );
      await Future.wait(<Future<void>>[first, second]);
      expect(repository.replaceEpisodeImagesCallCount, 0);
    },
  );
}

void _refreshCases() {
  test('refresh replaces image URLs and preserves the current image', () async {
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
    final controller = container.read(
      comicReaderControllerProvider(args).notifier,
    );
    await controller.jumpToImageIndex(2, scrollOffset: 48);
    service.fetchResultBuilder = (_) =>
        const ComicEpisodeImagesFetched(<String>[
          'https://img.test/new-first.jpg',
          'https://img.test/101-3.jpg',
          'https://img.test/new-last.jpg',
        ]);

    final result = await controller.refreshCurrentEpisode();
    final refreshed = container
        .read(comicReaderControllerProvider(args))
        .requireValue;

    expect(result.status, ComicReaderEpisodeRefreshStatus.refreshed);
    expect(service.fetchEpisodeImagesCalls.last, '101');
    expect(repository.replaceEpisodeImagesCallCount, 1);
    expect(refreshed.currentImageIndex, 1);
    expect(refreshed.lastScrollOffset, 0);
    expect(refreshed.imageSessionRevision, 1);
    expect(refreshed.images[1].imageUrl, 'https://img.test/101-3.jpg');
  });

  test('empty refresh keeps the current chapter untouched', () async {
    final repository = _ReaderRepoForControllerTest();
    final service = _ReaderServiceSpy()
      ..fetchResultBuilder = (_) => const ComicEpisodeImagesFetched(<String>[]);
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
    final before = await container.read(
      comicReaderControllerProvider(args).future,
    );
    final controller = container.read(
      comicReaderControllerProvider(args).notifier,
    );

    final result = await controller.refreshCurrentEpisode();
    final after = container
        .read(comicReaderControllerProvider(args))
        .requireValue;

    expect(result.status, ComicReaderEpisodeRefreshStatus.noImages);
    expect(
      after.images.map((image) => image.imageUrl),
      before.images.map((image) => image.imageUrl),
    );
    expect(after.imageSessionRevision, before.imageSessionRevision);
    expect(repository.replaceEpisodeImagesCallCount, 0);
  });
}
