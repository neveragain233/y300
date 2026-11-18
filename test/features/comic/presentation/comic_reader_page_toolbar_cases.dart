part of 'comic_reader_page_test.dart';

void _readerToolbarCases() {
  testWidgets('ComicReaderPage cycles reader mode from the bottom menu', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    final repository = _ReaderFakeRepository(
      progress: ComicReadingProgress(
        comicId: 'yamibo:100',
        episodeId: 'yamibo:100:101',
        imageIndex: 1,
        scrollOffset: 0,
        updatedAt: DateTime(2026, 1, 1),
      ),
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

    // Mode controls do not depend on the file image decoder settling.
    await pumpReaderUiTransition(tester);
    expect(find.byKey(const Key('comic-reader-image-list')), findsOneWidget);

    await openReaderMenu(tester);
    await tapVisibleByKey(
      tester,
      const Key('shared-reader-bottom-action-mode'),
    );
    await pumpReaderUiTransition(tester);

    expect(find.byKey(const Key('comic-reader-page-view')), findsOneWidget);
    expect(
      tester
          .widget<PageView>(find.byKey(const Key('comic-reader-page-view')))
          .reverse,
      isFalse,
    );
    expect(
      find.byKey(const Key('shared-reader-bottom-action-mode')),
      findsOneWidget,
    );
    await tapVisibleByKey(
      tester,
      const Key('shared-reader-bottom-action-mode'),
    );
    await pumpReaderUiTransition(tester);

    final rtlPageView = tester.widget<PageView>(
      find.byKey(const Key('comic-reader-page-view')),
    );
    expect(rtlPageView.reverse, isTrue);

    await tapVisibleByKey(
      tester,
      const Key('shared-reader-bottom-action-mode'),
    );
    await pumpReaderUiTransition(tester);

    expect(find.byKey(const Key('comic-reader-image-list')), findsOneWidget);
  });

  testWidgets(
    'ComicReaderPage opens chapter list and display settings sheets',
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
      await tapVisibleByKey(
        tester,
        const Key('shared-reader-bottom-action-catalog'),
      );
      await pumpReaderUiTransition(tester);

      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(ComicReaderPage)))
              .readerCatalog,
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('comic-reader-chapter-yamibo:100:101'),
        ),
      );
      await pumpReaderUiTransition(tester);
      await openReaderMenu(tester);
      await tester.tap(
        find.byKey(const Key('shared-reader-bottom-action-display')),
      );
      await pumpReaderUiTransition(tester);

      expect(
        find.byKey(const Key('comic-reader-display-settings-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('comic-reader-page-indicator-switch')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ComicReaderPage more menu can set current page as cover', (
    tester,
  ) async {
    await prepareLargeViewport(tester);
    final repository = _ReaderFakeRepository();
    final imageCache = _FakeImageCacheService();
    final coverStore = _ReaderCoverStoreFake();
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
          imageCacheServiceProvider.overrideWithValue(imageCache),
          libraryCoverStoreProvider.overrideWithValue(coverStore),
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
    await tapVisibleByKey(tester, const Key('shared-reader-top-action-more'));
    await pumpReaderUiTransition(tester);
    expect(
      find.byKey(const Key('shared-reader-action-cache-episode')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('shared-reader-action-cache-unread')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('shared-reader-action-clear-cache')),
      findsNothing,
    );
    final refreshAction = find.byKey(
      const Key('shared-reader-action-refresh-episode'),
    );
    final markReadAction = find.byKey(
      const Key('shared-reader-action-mark-read-toggle'),
    );
    expect(refreshAction, findsOneWidget);
    expect(markReadAction, findsOneWidget);
    expect(
      tester.getTopLeft(refreshAction).dy,
      lessThan(tester.getTopLeft(markReadAction).dy),
    );
    await tester.tap(find.byKey(const Key('shared-reader-action-set-cover')));
    // 选区器打开后会显示加载中的图片（测试环境图片不会解析完成，故不能
    // pumpAndSettle——加载圈是常驻动画）。“确定”按钮始终可见，直接确认默认焦点。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      coverStore.installedSourcePath,
      io.File('assets/noavatar.png').absolute.path,
    );
    expect(coverStore.installedAsset?.assetId, 'comic/yamibo:100/custom');
    expect(coverStore.installedAsset?.revision, 1);
    expect(coverStore.installedAsset?.kind, LibraryCoverAssetKind.custom);
    expect(repository.lastActivatedCustomCoverRevision, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('封面已更新'), findsOneWidget);
  });
}

void _readerChromePaletteCases() {
  testWidgets(
    'ComicReaderPage reader chrome uses shared palette in dark theme',
    (tester) async {
      await prepareLargeViewport(tester);
      final theme = AppTheme.dark();
      final palette = const ReaderChromePaletteResolver().resolve(theme);
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
          child: LocalizedTestApp(
            theme: theme,
            home: const ComicReaderPage(
              comicId: 'yamibo:100',
              episodeId: 'yamibo:100:101',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openReaderMenu(tester);

      final topBar = tester.widget<Material>(
        find.byKey(const Key('shared-reader-top-overlay-bar')),
      );
      final bottomPanel = tester.widget<Material>(
        find.byKey(const Key('shared-reader-bottom-overlay-panel')),
      );

      expect(topBar.color, palette.chromeBackground);
      expect(bottomPanel.color, palette.chromeBackground);
    },
  );
}
