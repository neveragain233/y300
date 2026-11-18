part of 'comic_reader_controller_test.dart';

void _bookmarkCases() {
  test('toggleBookmark persists bookmark state', () async {
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

    final notice = await container
        .read(comicReaderControllerProvider(args).notifier)
        .toggleBookmark();

    final state = container.read(comicReaderControllerProvider(args)).value!;
    expect(state.isBookmarked, isTrue);
    expect(
      state.chapters
          .singleWhere((chapter) => chapter.episodeId == state.episodeId)
          .isBookmarked,
      isTrue,
    );
    expect(writer.bookmarkedEpisodeIds, contains('yamibo:100:101'));
    expect(notice, ComicReaderNoticeCode.bookmarkAdded);
  });

  test(
    'catalog reads chapter marks once and keeps bookmarks for every chapter',
    () async {
      final repository = _ReaderRepoForControllerTest();
      final writer = _AggregatedReadingStateWriterSpy(repository)
        ..bookmarkedEpisodeIds.add('yamibo:100:102');
      final container = _marksContainer(repository, writer);
      addTearDown(container.dispose);
      const args = ComicReaderArgs(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:101',
      );
      final state = await container.read(
        comicReaderControllerProvider(args).future,
      );
      expect(writer.reads, [
        'yamibo:100:101',
        'yamibo:100:102',
        'yamibo:100:103',
      ]);
      expect(
        state.chapters
            .where((chapter) => chapter.isBookmarked)
            .map((chapter) => chapter.episodeId),
        ['yamibo:100:102'],
      );
    },
  );
}

void _episodeReadCases() {
  test('setCurrentEpisodeRead updates current chapter state', () async {
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

    final notice = await container
        .read(comicReaderControllerProvider(args).notifier)
        .setCurrentEpisodeRead(true);

    final state = container.read(comicReaderControllerProvider(args)).value!;
    expect(state.isCurrentEpisodeRead, isTrue);
    expect(state.chapters.first.isRead, isTrue);
    expect(notice, ComicReaderNoticeCode.episodeMarkedRead);
  });
}

void _episodeSwitchCases() {
  test(
    'openEpisode switches reader state without rebuilding provider args',
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
      final subscription = container.listen<AsyncValue<ComicReaderViewState>>(
        comicReaderControllerProvider(args),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(comicReaderControllerProvider(args).future);

      final switched = await container
          .read(comicReaderControllerProvider(args).notifier)
          .openEpisode(episodeId: 'yamibo:100:102');

      final state = container.read(comicReaderControllerProvider(args)).value!;
      expect(switched, isTrue);
      expect(state.episodeId, 'yamibo:100:102');
      expect(state.episodeTitle, '第2话');
      expect(state.images.first.imageUrl, 'https://img.test/102-1.jpg');
      expect(
        state.chapters
            .singleWhere((chapter) => chapter.episodeId == 'yamibo:100:102')
            .isCurrent,
        isTrue,
      );
      expect(state.noticeCode, isNull);
    },
  );

  test('reader navigation uses numeric source tid order', () async {
    final repository = _ReaderRepoForControllerTest(
      episodes: const <ComicEpisodeItem>[
        ComicEpisodeItem(
          episodeId: 'yamibo:100:120',
          comicId: 'yamibo:100',
          episodeTitle: '第120话',
          sourceTid: '120',
          sourceUrl: 'thread-120-1-1.html',
          orderIndex: 0,
          publishTimeText: null,
        ),
        ComicEpisodeItem(
          episodeId: 'yamibo:100:90',
          comicId: 'yamibo:100',
          episodeTitle: '第90话',
          sourceTid: '90',
          sourceUrl: 'thread-90-1-1.html',
          orderIndex: 1,
          publishTimeText: null,
        ),
        ComicEpisodeItem(
          episodeId: 'yamibo:100:105',
          comicId: 'yamibo:100',
          episodeTitle: '第105话',
          sourceTid: '105',
          sourceUrl: 'thread-105-1-1.html',
          orderIndex: 2,
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
    final state = await container.read(
      comicReaderControllerProvider(args).future,
    );
    final controller = container.read(
      comicReaderControllerProvider(args).notifier,
    );

    expect(state.chapters.map((chapter) => chapter.sourceTid), <String>[
      '90',
      '105',
      '120',
    ]);
    expect(state.nextChapter?.sourceTid, '105');
    expect(
      await controller.openAdjacentEpisode(
        sourceEpisodeId: 'yamibo:100:90',
        direction: ComicEpisodeDirection.previous,
      ),
      isFalse,
    );
    expect(
      await controller.openAdjacentEpisode(
        sourceEpisodeId: 'yamibo:100:90',
        direction: ComicEpisodeDirection.next,
      ),
      isTrue,
    );
    expect(
      container.read(comicReaderControllerProvider(args)).value?.episodeId,
      'yamibo:100:105',
    );

    expect(await controller.openEpisode(episodeId: 'yamibo:100:120'), isTrue);
    expect(
      container.read(comicReaderControllerProvider(args)).value?.noticeCode,
      isNull,
    );
  });

  test(
    'comment tail opens the validated TID successor at its first image',
    () async {
      final repository = _ReaderRepoForControllerTest(
        episodes: const <ComicEpisodeItem>[
          ComicEpisodeItem(
            episodeId: 'yamibo:100:120',
            comicId: 'yamibo:100',
            episodeTitle: '第120话',
            sourceTid: '120',
            sourceUrl: 'thread-120-1-1.html',
            orderIndex: 0,
            publishTimeText: null,
          ),
          ComicEpisodeItem(
            episodeId: 'yamibo:100:90',
            comicId: 'yamibo:100',
            episodeTitle: '第90话',
            sourceTid: '90',
            sourceUrl: 'thread-90-1-1.html',
            orderIndex: 1,
            publishTimeText: null,
          ),
          ComicEpisodeItem(
            episodeId: 'yamibo:100:105',
            comicId: 'yamibo:100',
            episodeTitle: '第105话',
            sourceTid: '105',
            sourceUrl: 'thread-105-1-1.html',
            orderIndex: 2,
            publishTimeText: null,
          ),
        ],
        readingProgresses: <ComicReadingProgress>[
          ComicReadingProgress(
            comicId: 'yamibo:100',
            episodeId: 'yamibo:100:105',
            imageIndex: 3,
            scrollOffset: 240,
            updatedAt: DateTime(2026, 7, 20),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          comicRepositoryProvider.overrideWithValue(repository),
          comicReadingStateWriterProvider.overrideWithValue(
            _ReadingStateWriterSpy(repository),
          ),
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

      expect(
        await controller.openAdjacentEpisode(
          sourceEpisodeId: 'yamibo:100:90',
          direction: ComicEpisodeDirection.next,
        ),
        isTrue,
      );

      final state = container.read(comicReaderControllerProvider(args)).value!;
      expect(state.episodeId, 'yamibo:100:105');
      expect(state.currentImageIndex, 0);
      expect(state.lastScrollOffset, 0);

      // A late callback from the old chapter cannot navigate again after the
      // controller has committed the new owner.
      expect(
        await controller.openAdjacentEpisode(
          sourceEpisodeId: 'yamibo:100:90',
          direction: ComicEpisodeDirection.next,
        ),
        isFalse,
      );
    },
  );
}
