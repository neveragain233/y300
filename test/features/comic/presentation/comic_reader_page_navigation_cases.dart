part of 'comic_reader_page_test.dart';

void _readerPageBaselineCases() {
  testWidgets('ComicReaderPage renders images and shared reader actions', (
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

    expect(find.byKey(const Key('comic-reader-image-list')), findsOneWidget);
    expect(find.byType(ReaderSessionImage), findsWidgets);
    final listView = tester.widget<ListView>(
      find.byKey(const Key('comic-reader-image-list')),
    );
    // viewportCacheExtentFactor 1.5 × 测试视口高度。
    expect(listView.scrollCacheExtent, const ScrollCacheExtent.pixels(3600));
    expect(
      find.byKey(const Key('shared-reader-center-tap-zone')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shared-reader-top-overlay')), findsOneWidget);
    expect(
      find.byKey(const Key('shared-reader-bottom-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-persistent-status-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('comic-reader-next-chapter-transition')),
      findsNothing,
    );

    await openReaderMenu(tester);

    expect(find.byKey(const Key('shared-reader-top-title')), findsOneWidget);
    expect(
      find.byKey(const Key('shared-reader-top-action-bookmark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-top-action-open-thread')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shared-reader-prev-button')), findsOneWidget);
    expect(find.byKey(const Key('shared-reader-next-button')), findsOneWidget);
    expect(
      find.byKey(const Key('shared-reader-bottom-action-mode')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-catalog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-display')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-export-current-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-cache')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('shared-reader-progress-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-reader-current-label')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shared-reader-total-label')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('shared-reader-top-action-bookmark')),
    );
    await pumpReaderUiTransition(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('已添加书签'), findsOneWidget);
  });

  testWidgets('ComicReaderPage no-image state offers source thread entries', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._interactionOverrides(),
          comicRepositoryProvider.overrideWithValue(
            _ReaderFakeRepository(images: const <ComicEpisodeImageItem>[]),
          ),
          comicReadingStateWriterProvider.overrideWithValue(
            _NoopReadingStateWriter(),
          ),
          comicReaderServiceProvider.overrideWith(
            (ref) async => _ReaderFakeService(imageUrls: const <String>[]),
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

    expect(
      find.byKey(const Key('comic-reader-no-images-source-tags')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('comic-reader-no-images-source-thread')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('comic-reader-no-images-source-tags')),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看原帖标签'), findsWidgets);
  });

  testWidgets('ComicReaderPage failure state keeps source thread entries', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ..._interactionOverrides(),
          comicRepositoryProvider.overrideWithValue(
            _ReaderFakeRepository(images: const <ComicEpisodeImageItem>[]),
          ),
          comicReadingStateWriterProvider.overrideWithValue(
            _NoopReadingStateWriter(),
          ),
          comicReaderServiceProvider.overrideWith(
            (ref) async => _FailingReaderService(),
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

    expect(
      find.byKey(const Key('comic-reader-error-source-tags')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('comic-reader-error-source-thread')),
      findsOneWidget,
    );
  });
}

void _readerOpeningSnapshotCases() {
  testWidgets(
    'ComicReaderPage does not flash image loading copy while opening',
    (tester) async {
      await prepareLargeViewport(tester);
      final repository = _ReaderBlockingRepository();
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

      await tester.pump();

      expect(
        find.byKey(const Key('comic-reader-page-opening')),
        findsOneWidget,
      );
      expect(find.text('图片加载中'), findsNothing);

      await tester.pump(const Duration(milliseconds: 161));

      expect(find.text('正在打开章节'), findsOneWidget);
    },
  );

  testWidgets('ComicReaderPage uses the shared default LTR snapshot', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._interactionOverrides(),
          comicRepositoryProvider.overrideWithValue(
            _ReaderFakeRepository(
              images: const <ComicEpisodeImageItem>[
                ComicEpisodeImageItem(
                  episodeId: 'yamibo:100:101',
                  imageUrl: 'https://img.test/101-1.jpg',
                  imageIndex: 0,
                  cacheStatus: 'none',
                ),
                ComicEpisodeImageItem(
                  episodeId: 'yamibo:100:101',
                  imageUrl: 'https://img.test/101-2.jpg',
                  imageIndex: 1,
                  cacheStatus: 'none',
                ),
                ComicEpisodeImageItem(
                  episodeId: 'yamibo:100:101',
                  imageUrl: 'https://img.test/101-3.jpg',
                  imageIndex: 2,
                  cacheStatus: 'none',
                ),
              ],
            ),
          ),
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

    expect(find.byKey(const Key('comic-reader-page-view')), findsOneWidget);
    expect(find.byKey(const Key('comic-reader-image-list')), findsNothing);
    expect(find.byType(ReaderZoomableImage), findsWidgets);
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('comic-reader-page-view')))
          .reverse,
      isFalse,
    );

    final pageController = tester
        .widget<PageView>(find.byKey(const Key('comic-reader-page-view')))
        .controller!;
    expect(pageController.page, closeTo(0, 0.01));
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('shared-reader-right-tap-zone'))),
    );
    await tester.pump(const Duration(milliseconds: 219));
    expect(pageController.page, closeTo(0, 0.01));

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 170));
    expect(pageController.page, closeTo(1, 0.01));
  });
}
