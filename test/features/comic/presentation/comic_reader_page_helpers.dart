part of 'comic_reader_page_test.dart';

Future<void> prepareLargeViewport(WidgetTester tester) async {
  // Keep a very tall viewport to make bottom reader controls consistently
  // hittable across different test environments and frame timings.
  tester.view.physicalSize = const Size(960, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> openReaderMenu(WidgetTester tester) async {
  // The tap-zone keys are geometry anchors; tapping coordinates keeps the
  // test aligned with the pass-through gesture layer.
  final center = tester.getCenter(
    find.byKey(const Key('shared-reader-center-tap-zone')),
  );
  await tester.tapAt(center);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 360));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> pumpReaderUiTransition(WidgetTester tester) async {
  // Reader images may intentionally keep a loading indicator animating while
  // the surrounding menu/sheet transition has already completed. Waiting
  // for the whole tree to settle would therefore couple unrelated UI tests
  // to network-image completion.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> revealNextChapterTransition(WidgetTester tester) async {
  final listFinder = find.byKey(const Key('comic-reader-image-list'));
  for (var i = 0; i < 4; i++) {
    if (find
        .byKey(const Key('comic-reader-next-chapter-transition'))
        .evaluate()
        .isNotEmpty) {
      return;
    }
    await tester.drag(listFinder, const Offset(0, -1000));
    await tester.pump();
  }
}

ScrollController readerScroll(WidgetTester tester) => tester
    .widget<ListView>(find.byKey(const Key('comic-reader-image-list')))
    .controller!;

Future<void> pumpSwitchUi(WidgetTester tester) async {
  // Image placeholders can animate indefinitely; wait for the reader's
  // async state/layout work without waiting for network images to finish.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpSwitchReader(
  WidgetTester tester,
  _ReaderFakeRepository repository, {
  ComicCommentLoadStatus? commentStatus,
}) async {
  await prepareLargeViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._interactionOverrides(commentStatus: commentStatus),
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
        imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        forumImagePrecacheServiceProvider.overrideWithValue(
          _RecordingForumImagePrecacheService(),
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
}

Future<void> tapVisibleByKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  final center = tester.getCenter(finder);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(
    Rect.fromLTWH(0, 0, size.width, size.height).contains(center),
    isTrue,
    reason: '$key should be inside the test viewport before tapping',
  );
  await tester.tapAt(center);
}

Future<void> dragVisibleByKey(
  WidgetTester tester,
  Key key,
  Offset offset,
) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  final center = tester.getCenter(finder);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(
    Rect.fromLTWH(0, 0, size.width, size.height).contains(center),
    isTrue,
    reason: '$key should be inside the test viewport before dragging',
  );
  await tester.dragFrom(center, offset);
}
