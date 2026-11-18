part of 'comic_reader_page_test.dart';

void _verticalSpacingAndPreloadCases() {
  testWidgets('ComicReaderPage applies shared vertical page spacing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'reader_pref_mode': 'vertical',
      'reader_pref_page_spacing': 24.0,
    });
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

    final reader = tester.widget<ContinuousImageReaderView>(
      find.byType(ContinuousImageReaderView),
    );
    expect(reader.items.map((item) => item.spacingAfter), everyElement(24));
  });

  testWidgets('ComicReaderPage records preload tasks without duplicates', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    final recorder = _RecordingContinuousImageDiagnosticRecorder();
    final precacheService = _RecordingForumImagePrecacheService();
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
          forumImagePrecacheServiceProvider.overrideWithValue(precacheService),
        ],
        child: LocalizedTestApp(
          home: ComicReaderPage(
            comicId: 'yamibo:100',
            episodeId: 'yamibo:100:101',
            diagnosticRecorder: recorder,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump();

    final scheduled = recorder.events
        .where(
          (event) =>
              event.type ==
              ContinuousImageDiagnosticEventType.prefetchScheduled,
        )
        .toList(growable: false);
    final completed = recorder.events
        .where(
          (event) =>
              event.type ==
              ContinuousImageDiagnosticEventType.prefetchCompleted,
        )
        .toList(growable: false);
    final taskIdentities = scheduled
        .map((event) => '${event.itemId}:${event.preloadKind}')
        .toSet();

    expect(scheduled, hasLength(2));
    expect(completed, hasLength(2));
    expect(scheduled.length - taskIdentities.length, 0);
    expect(scheduled.map((event) => event.readerKind).toSet(), <String>{
      'comic',
    });
    expect(scheduled.map((event) => event.ownerId).toSet(), <String>{
      'yamibo:100:101',
    });
    expect(completed.every((event) => event.applied == true), isTrue);
  });
}

void _verticalZoomLongImageCases() {
  testWidgets('ComicReaderPage coordinates vertical scrolling with zoom', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
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

    final zoomSurface = find.byKey(
      const Key('image-reader-engine-vertical-zoom-surface'),
    );
    final readerListFinder = find.byKey(const Key('comic-reader-image-list'));
    expect(find.byType(ReaderZoomableImage), findsOneWidget);
    expect(zoomSurface, findsOneWidget);
    expect(
      find.ancestor(
        of: readerListFinder,
        matching: find.byType(ReaderZoomableImage),
      ),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsNothing);

    ListView readerList() => tester.widget<ListView>(readerListFinder);
    Transform zoomTransform() => tester.widget<Transform>(
      find.byKey(const Key('reader-continuous-zoom-transform')),
    );

    expect(readerList().physics, isNull);
    expect(zoomTransform().transform.getMaxScaleOnAxis(), closeTo(1, 0.001));

    final surfaceCenter = tester.getCenter(zoomSurface);
    await tester.tapAt(surfaceCenter);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(surfaceCenter);
    await pumpReaderUiTransition(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(zoomTransform().transform.getMaxScaleOnAxis(), greaterThan(1));
    expect(readerList().physics, isNull);

    final previousOffset = readerList().controller!.offset;
    await tester.dragFrom(surfaceCenter, const Offset(0, -160));
    await pumpReaderUiTransition(tester);
    expect(readerList().controller!.offset, greaterThan(previousOffset));

    readerList().controller!.jumpTo(0);
    await pumpReaderUiTransition(tester);
    final viewport = tester.getRect(zoomSurface);
    for (var drag = 0; drag < 2; drag += 1) {
      await tester.dragFrom(viewport.center, Offset(0, viewport.height * 0.4));
      await pumpReaderUiTransition(tester);
    }
    expect(
      tester.getTopLeft(find.byKey(const Key('comic-reader-image-slot-0'))).dy,
      closeTo(viewport.top, 0.5),
    );

    await tester.tapAt(surfaceCenter);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(surfaceCenter);
    await pumpReaderUiTransition(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(readerList().physics, isNull);
    expect(zoomTransform().transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
  });

  testWidgets('ComicReaderPage reserves stable slots for vertical images', (
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

    expect(
      find.byKey(const ValueKey<String>('comic-reader-image-slot-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('comic-reader-image-slot-1')),
      findsOneWidget,
    );
    final slot = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('comic-reader-image-slot-0')),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(slot.constraints.minHeight, greaterThan(0));
  });

  testWidgets(
    'ComicReaderPage uses decoded dimensions for vertical slot reservation',
    (tester) async {
      await prepareLargeViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._interactionOverrides(),
            comicRepositoryProvider.overrideWithValue(
              _ReaderFakeRepository(
                images: const <ComicEpisodeImageItem>[
                  ComicEpisodeImageItem(
                    episodeId: 'yamibo:100:101',
                    imageUrl: 'https://img.test/tall.jpg',
                    imageIndex: 0,
                    cacheStatus: 'none',
                    width: 600,
                    height: 1800,
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

      final slot = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('comic-reader-image-slot-0'),
              ),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(slot.constraints.minHeight, 2880);
    },
  );
}
