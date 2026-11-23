part of 'comic_reader_page_test.dart';

void _savedProgressChapterSwitchCases() {
  for (final entry in ['card', 'menu', 'catalog']) {
    for (final count in [1, 3]) {
      testWidgets(
        '$entry switches to $count images from the top despite saved target progress',
        (tester) async {
          final repository = _ReaderFakeRepository(
            includeNextEpisode: true,
            progress: ComicReadingProgress(
              comicId: 'yamibo:100',
              episodeId: 'yamibo:100:102',
              imageIndex: count - 1,
              scrollOffset: 1000,
              updatedAt: DateTime(2026),
            ),
          );
          for (final tid in ['101', '102']) {
            repository._episodeImages['yamibo:100:$tid'] = List.generate(
              tid == '101' ? 2 : count,
              (index) => ComicEpisodeImageItem(
                episodeId: 'yamibo:100:$tid',
                imageUrl: 'https://img.test/$tid-$index.jpg',
                imageIndex: index,
                cacheStatus: 'none',
                width: 600,
                height: 2400,
              ),
            );
          }
          await _pumpSwitchReader(tester, repository);
          final oldScroll = readerScroll(tester);
          if (entry == 'card' || count == 1) {
            for (var i = 0; i < 3; i++) {
              oldScroll.jumpTo(oldScroll.position.maxScrollExtent);
              await pumpSwitchUi(tester);
            }
          } else {
            oldScroll.jumpTo(5000);
            await pumpSwitchUi(tester);
          }
          expect(oldScroll.offset, greaterThan(0));
          if (entry == 'card') {
            await tester.tap(
              find.byKey(
                const Key('comic-reader-next-chapter-transition-button'),
              ),
            );
          } else {
            await openReaderMenu(tester);
            if (entry == 'menu') {
              await tester.tap(
                find.byKey(const Key('shared-reader-next-button')),
              );
            } else {
              await tester.tap(
                find.byKey(const Key('shared-reader-bottom-action-catalog')),
              );
              await pumpReaderUiTransition(tester);
              await tester.tap(
                find.byKey(const Key('comic-reader-chapter-yamibo:100:102')),
              );
            }
          }
          await pumpSwitchUi(tester);
          expect(
            tester
                .widget<ContinuousImageReaderView>(
                  find.byType(ContinuousImageReaderView),
                )
                .items
                .first
                .ownerId,
            'yamibo:100:102',
          );
          expect(identical(readerScroll(tester), oldScroll), isFalse);
          expect(readerScroll(tester).offset, 0);
          expect(
            tester
                .getTopLeft(find.byKey(const Key('comic-reader-image-slot-0')))
                .dy,
            0,
          );

          if (entry == 'menu') {
            // Returning to the previous chapter opens its final image.
            readerScroll(tester).jumpTo(1000);
            await pumpSwitchUi(tester);
            await openReaderMenu(tester);
            await tester.tap(
              find.byKey(const Key('shared-reader-prev-button')),
            );
            await pumpSwitchUi(tester);
            expect(readerScroll(tester).offset, greaterThan(0));
            expect(
              tester
                  .getTopLeft(
                    find.byKey(const Key('comic-reader-image-slot-1')),
                  )
                  .dy,
              closeTo(0, 1),
            );
            expect(
              tester
                  .widget<ContinuousImageReaderView>(
                    find.byType(ContinuousImageReaderView),
                  )
                  .items
                  .first
                  .ownerId,
              'yamibo:100:101',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _commentTailNextChapterCases() {
  for (final status in [
    null,
    ComicCommentLoadStatus.empty,
    ComicCommentLoadStatus.failure,
    ComicCommentLoadStatus.success,
  ]) {
    for (final hasNext in [false, true]) {
      testWidgets(
        'comment tail $status with next $hasNext has no intermediate action-bar gap',
        (tester) async {
          await _pumpSwitchReader(
            tester,
            _ReaderFakeRepository(includeNextEpisode: hasNext),
            commentStatus: status,
          );
          final scroll = readerScroll(tester);
          for (var i = 0; i < 3; i++) {
            scroll.jumpTo(scroll.position.maxScrollExtent);
            await pumpSwitchUi(tester);
          }
          if (status != null) {
            final open = find.byKey(
              const Key('comic-comment-tail-load-button'),
            );
            if (open.evaluate().isNotEmpty) {
              await tester.tap(open);
              await pumpSwitchUi(tester);
            }
            for (var i = 0; i < 3; i++) {
              scroll.jumpTo(scroll.position.maxScrollExtent);
              await pumpSwitchUi(tester);
            }
          }
          final tail = status == ComicCommentLoadStatus.success
              ? find.byKey(const Key('comic-comment-tail-item-2'))
              : find.byType(ComicCommentFeedbackSurface);
          expect(tail, findsOneWidget);
          final tailRect = tester.getRect(tail);
          final bar = tester.getRect(
            find.byKey(const Key('comic-comment-action-bar')),
          );
          if (hasNext) {
            final card = tester.getRect(
              find.byKey(
                const Key('comic-reader-next-chapter-transition-button'),
              ),
            );
            expect(card.top - tailRect.bottom, closeTo(12, 0.5));
            expect(bar.top - card.bottom, closeTo(12, 0.5));
          } else {
            expect(
              find.byKey(const Key('comic-reader-next-chapter-transition')),
              findsNothing,
            );
            expect(tailRect.bottom, closeTo(bar.top, 0.5));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'eink pageUp at first image opens previous chapter comments in paged mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({'reader_pref_mode': 'ltr'});
      final repository = _ReaderFakeRepository(includeNextEpisode: true);
      for (final tid in ['101', '102']) {
        repository._episodeImages['yamibo:100:$tid'] = List.generate(
          2,
          (index) => ComicEpisodeImageItem(
            episodeId: 'yamibo:100:$tid',
            imageUrl: 'https://img.test/$tid-$index.jpg',
            imageIndex: index,
            cacheStatus: 'none',
            width: 600,
            height: 2400,
          ),
        );
      }
      await prepareLargeViewport(tester);
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
            forumImagePrecacheServiceProvider.overrideWithValue(
              _RecordingForumImagePrecacheService(),
            ),
          ],
          child: const EInkModeScope(
            enabled: true,
            child: LocalizedTestApp(
              home: ComicReaderPage(
                comicId: 'yamibo:100',
                episodeId: 'yamibo:100:102',
              ),
            ),
          ),
        ),
      );
      await pumpSwitchUi(tester);

      tester
          .stateList<State>(
            find.descendant(
              of: find.byType(ImageReaderEngine),
              matching: find.bySubtype<StatefulWidget>(),
            ),
          )
          .whereType<EInkPageHandler>()
          .single
          .pageUp();
      await pumpSwitchUi(tester);

      expect(
        tester
            .widget<ContinuousImageReaderView>(
              find.byType(ContinuousImageReaderView),
            )
            .items
            .first
            .ownerId,
        'yamibo:100:101',
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller?.page,
        2,
      );
      expect(find.byKey(const Key('comic-comment-action-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'eink pageUp at top opens previous chapter last image in vertical mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({'reader_pref_mode': 'vertical'});
      final repository = _ReaderFakeRepository(includeNextEpisode: true);
      for (final tid in ['101', '102']) {
        repository._episodeImages['yamibo:100:$tid'] = List.generate(
          2,
          (index) => ComicEpisodeImageItem(
            episodeId: 'yamibo:100:$tid',
            imageUrl: 'https://img.test/$tid-$index.jpg',
            imageIndex: index,
            cacheStatus: 'none',
            width: 600,
            height: 2400,
          ),
        );
      }
      await prepareLargeViewport(tester);
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
            forumImagePrecacheServiceProvider.overrideWithValue(
              _RecordingForumImagePrecacheService(),
            ),
          ],
          child: const EInkModeScope(
            enabled: true,
            child: LocalizedTestApp(
              home: ComicReaderPage(
                comicId: 'yamibo:100',
                episodeId: 'yamibo:100:102',
              ),
            ),
          ),
        ),
      );
      await pumpSwitchUi(tester);

      tester
          .stateList<State>(
            find.descendant(
              of: find.byType(ImageReaderEngine),
              matching: find.bySubtype<StatefulWidget>(),
            ),
          )
          .whereType<EInkPageHandler>()
          .single
          .pageUp();
      await pumpSwitchUi(tester);

      expect(
        tester
            .widget<ContinuousImageReaderView>(
              find.byType(ContinuousImageReaderView),
            )
            .items
            .first
            .ownerId,
        'yamibo:100:101',
      );
      expect(readerScroll(tester).offset, greaterThan(0));
      expect(
        tester
            .getTopLeft(find.byKey(const Key('comic-reader-image-slot-1')))
            .dy,
        closeTo(0, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _nextChapterTransitionCases() {
  testWidgets(
    'ComicReaderPage shows next chapter transition for vertical mode',
    (tester) async {
      await prepareLargeViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._interactionOverrides(),
            comicRepositoryProvider.overrideWithValue(
              _ReaderFakeRepository(includeNextEpisode: true),
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

      await revealNextChapterTransition(tester);

      expect(
        find.byKey(const Key('comic-reader-next-chapter-transition')),
        findsOneWidget,
      );
      expect(find.textContaining('下一章：第2话'), findsOneWidget);
    },
  );
}
