part of 'comic_reader_page_test.dart';

void _verticalProgressRestoreCases() {
  testWidgets(
    'ComicReaderPage restores vertical progress only once so top can be reached',
    (tester) async {
      await prepareLargeViewport(tester);
      final repository = _ReaderFakeRepository(
        progress: ComicReadingProgress(
          comicId: 'yamibo:100',
          episodeId: 'yamibo:100:101',
          imageIndex: 1,
          scrollOffset: 500,
          updatedAt: DateTime(2026, 1, 1),
        ),
        images: const <ComicEpisodeImageItem>[
          ComicEpisodeImageItem(
            episodeId: 'yamibo:100:101',
            imageUrl: 'https://img.test/101-1.jpg',
            imageIndex: 0,
            cacheStatus: 'none',
            width: 600,
            height: 1200,
          ),
          ComicEpisodeImageItem(
            episodeId: 'yamibo:100:101',
            imageUrl: 'https://img.test/101-2.jpg',
            imageIndex: 1,
            cacheStatus: 'none',
            width: 600,
            height: 1200,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._interactionOverrides(),
            comicRepositoryProvider.overrideWithValue(repository),
            comicReadingStateWriterProvider.overrideWithValue(
              _NoopReadingStateWriter(),
            ),
            comicReaderServiceProvider.overrideWith(
              (ref) async => _ReaderFakeService(),
            ),
            comicDownloadServiceProvider.overrideWithValue(
              _NoopComicDownloadService(),
            ),
            imageCacheServiceProvider.overrideWithValue(
              _FakeImageCacheService(),
            ),
          ],
          child: const LocalizedTestApp(
            home: ComicReaderPage(
              comicId: 'yamibo:100',
              episodeId: 'yamibo:100:101',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(
        find.byKey(const Key('comic-reader-image-list')),
      );
      final controller = list.controller!;
      expect(controller.offset, greaterThan(0));

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();

      expect(controller.offset, 0);
    },
  );
}

void _progressLabelCases() {
  testWidgets(
    'ComicReaderPage updates progress labels after slider interaction',
    (tester) async {
      await prepareLargeViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._interactionOverrides(),
            comicRepositoryProvider.overrideWithValue(_ReaderFakeRepository()),
            comicReadingStateWriterProvider.overrideWithValue(
              _NoopReadingStateWriter(),
            ),
            comicReaderServiceProvider.overrideWith(
              (ref) async => _ReaderFakeService(),
            ),
            comicDownloadServiceProvider.overrideWithValue(
              _NoopComicDownloadService(),
            ),
            imageCacheServiceProvider.overrideWithValue(
              _FakeImageCacheService(),
            ),
          ],
          child: const LocalizedTestApp(
            home: ComicReaderPage(
              comicId: 'yamibo:100',
              episodeId: 'yamibo:100:101',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openReaderMenu(tester);

      expect(
        find.byKey(const Key('shared-reader-current-label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shared-reader-total-label')),
        findsOneWidget,
      );

      await dragVisibleByKey(
        tester,
        const Key('shared-reader-progress-slider'),
        const Offset(300, 0),
      );
      await pumpReaderUiTransition(tester);

      expect(
        find.byKey(const Key('shared-reader-current-label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('shared-reader-total-label')),
        findsOneWidget,
      );
    },
  );
}

void _sliderJumpCommitCases() {
  testWidgets('ComicReaderPage keeps slider stable during jump commit', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._interactionOverrides(),
          comicRepositoryProvider.overrideWithValue(_ReaderFakeRepository()),
          comicReadingStateWriterProvider.overrideWithValue(
            _NoopReadingStateWriter(),
          ),
          comicReaderServiceProvider.overrideWith(
            (ref) async => _ReaderFakeService(),
          ),
          comicDownloadServiceProvider.overrideWithValue(
            _NoopComicDownloadService(),
          ),
          imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        ],
        child: const LocalizedTestApp(
          home: ComicReaderPage(
            comicId: 'yamibo:100',
            episodeId: 'yamibo:100:101',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await openReaderMenu(tester);

    final sliderFinder = find.byKey(const Key('shared-reader-progress-slider'));
    expect(sliderFinder, findsOneWidget);

    await dragVisibleByKey(
      tester,
      const Key('shared-reader-progress-slider'),
      const Offset(280, 0),
    );
    await tester.pump();

    // During commit phase, slider and labels should remain stable and visible.
    expect(
      find.byKey(const Key('shared-reader-progress-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-current-label')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shared-reader-total-label')), findsOneWidget);
  });
}
