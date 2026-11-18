part of 'unified_shelf_page_test.dart';

void _coverStatusCases() {
  testWidgets('cached grid cover keeps its exact key when it becomes visible', (
    tester,
  ) async {
    final items = List<LibraryWorkItem>.generate(
      40,
      (index) => _item(
        workId: 'cached-$index',
        title: 'Cached $index',
        coverAsset: LibraryCoverAssetRef(
          assetId: 'comic/cached-$index/source',
          revision: 1,
          kind: LibraryCoverAssetKind.source,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryCoverStoreProvider.overrideWithValue(
            const UnavailableLibraryCoverStore(),
          ),
          libraryCoverDecodeSchedulerProvider.overrideWithValue(
            LibraryCoverDecodeScheduler(maxConcurrent: 3),
          ),
        ],
        child: LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.grid,
              itemsByCategory: {'default': items},
            ),
            onOpenWork: (context, workId) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gridRect = tester.getRect(
      find.byKey(const Key('unified-shelf-grid-view')),
    );
    final cachedIndex = List<int>.generate(items.length, (index) => index)
        .where((index) {
          final item = find.byKey(
            ValueKey<String>('unified-shelf-grid-item-cached-$index'),
            skipOffstage: false,
          );
          return item.evaluate().isNotEmpty &&
              tester.getTopLeft(item).dy >= gridRect.bottom;
        })
        .first;
    final cachedItem = find.byKey(
      ValueKey<String>('unified-shelf-grid-item-cached-$cachedIndex'),
      skipOffstage: false,
    );
    expect(
      tester.getTopLeft(cachedItem).dy,
      greaterThanOrEqualTo(gridRect.bottom),
    );

    LibraryCoverImageProvider providerForCachedItem() {
      final image = tester.widget<Image>(
        find.descendant(
          of: cachedItem,
          matching: find.byType(Image, skipOffstage: false),
        ),
      );
      return image.image as LibraryCoverImageProvider;
    }

    final cachedKey = providerForCachedItem().cacheKey;
    await tester.ensureVisible(cachedItem);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(cachedItem).dy,
      inInclusiveRange(gridRect.top, gridRect.bottom),
    );
    expect(providerForCachedItem().cacheKey, cachedKey);
  });

  testWidgets('cover image feature flag can fall back to LibraryCachedImage', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.grid,
            itemsByCategory: {
              'default': [
                _item(
                  workId: '1',
                  title: 'Comic A',
                  coverImageUrl: 'https://example.com/comic-a.jpg',
                ),
              ],
            },
          ),
          featureFlags: ShelfFeatureFlags.defaults.copyWith(
            useShelfCoverImage: false,
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LibraryCachedImage), findsOneWidget);
    expect(find.byType(ShelfCoverImage), findsNothing);
  });

  testWidgets(
    'list mode hides cover placeholder when item has no cover source',
    (tester) async {
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.list,
            ),
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listItem = find.byKey(
        const ValueKey<String>('unified-shelf-list-item-1'),
      );
      expect(
        find.descendant(
          of: listItem,
          matching: find.byIcon(Icons.image_not_supported_outlined),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: listItem, matching: find.byType(ShelfCoverImage)),
        findsNothing,
      );
    },
  );

  testWidgets('list mode keeps leading cover when item has cover source', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.list,
              onQuery:
                  ({
                    required List<LibraryCategory> categories,
                    required LibraryFilterSet filters,
                    required LibraryShelfSortOption sortOption,
                    required String keyword,
                  }) async {
                    return {
                      'default': [
                        _item(
                          workId: 'covered',
                          title: 'Covered Comic',
                          coverImageUrl: 'https://example.com/covered.jpg',
                        ),
                      ],
                    };
                  },
            ),
            onOpenWork: (context, workId) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('unified-shelf-list-item-covered'),
        ),
        matching: find.byType(ShelfCoverImage),
      ),
      findsOneWidget,
    );
    final coverImage = tester.widget<ShelfCoverImage>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('unified-shelf-list-item-covered'),
        ),
        matching: find.byType(ShelfCoverImage),
      ),
    );
    expect(coverImage.placeholder, isA<LibraryCoverPlaceholder>());
    expect(
      (coverImage.placeholder as LibraryCoverPlaceholder).color,
      const ShelfThemePaletteResolver()
          .resolve(Theme.of(tester.element(find.byType(UnifiedShelfPage))))
          .coverPlaceholderBackground,
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });

  testWidgets('grid and list covers use the custom focal alignment', (
    tester,
  ) async {
    Future<void> pumpShelf(LibraryDisplayMode displayMode) async {
      await tester.pumpWidget(
        ProviderScope(
          child: LocalizedTestApp(
            home: UnifiedShelfPage(
              adapter: _FakeShelfAdapter(
                initialDisplayMode: displayMode,
                itemsByCategory: {
                  'default': [
                    _item(
                      workId: 'focused',
                      title: 'Focused Comic',
                      customCoverLocalPath: 'cache/custom-cover.jpg',
                      customCoverFocusX: 0.75,
                      customCoverFocusY: -0.5,
                    ),
                  ],
                },
              ),
              onOpenWork: (context, workId) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<ShelfCoverImage>(find.byType(ShelfCoverImage)).alignment,
        const Alignment(0.75, -0.5),
      );
    }

    await pumpShelf(LibraryDisplayMode.grid);
    await pumpShelf(LibraryDisplayMode.list);
  });

  testWidgets('unread badge renders shelf aggregate count', (tester) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            onQuery:
                ({
                  required List<LibraryCategory> categories,
                  required LibraryFilterSet filters,
                  required LibraryShelfSortOption sortOption,
                  required String keyword,
                }) async {
                  return {
                    'default': [
                      LibraryWorkItem(
                        workId: 'badge-work',
                        categoryId: 'default',
                        title: 'Badge Comic',
                        unreadCount: 7,
                        totalChapterCount: 10,
                        readChapterCount: 3,
                        addedAt: DateTime(2026, 1, 1),
                      ),
                    ],
                  };
                },
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('unified-shelf-list-item-badge-work'),
        ),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
  });

  for (final supportsReadState in [true, false]) {
    testWidgets(
      'list badge space follows read state capability $supportsReadState',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final host = ShelfSelectionHostController();
        addTearDown(host.dispose);
        const longTitle = '【受祝福的因果律协会汉化组】[中村汚濁]圣少女默示录 DEATHPAIR 第30话';
        await tester.pumpWidget(
          ProviderScope(
            child: LocalizedTestApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: UnifiedShelfPage(
                adapter: _FakeSelectableShelfAdapter(
                  initialDisplayMode: LibraryDisplayMode.list,
                  capabilities: ShelfModuleCapabilities(
                    supportsReadState: supportsReadState,
                  ),
                  itemsByCategory: {
                    'default': [
                      _item(
                        workId: 'covered',
                        title: longTitle,
                        customCoverLocalPath: 'cache/missing-cover.jpg',
                        unreadCount: 0,
                      ),
                      _item(
                        workId: 'coverless',
                        title: longTitle,
                        unreadCount: 0,
                      ),
                    ],
                  },
                ),
                selectionHost: host,
                onOpenWork: (_, _) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final workId in ['covered', 'coverless']) {
          final tile = find.byKey(
            ValueKey<String>('unified-shelf-list-tile-$workId'),
          );
          final title = find.descendant(
            of: tile,
            matching: find.text(longTitle),
          );
          // Keep the comic badge column aligned even when fully read. Shelves
          // without read state should use the entire title width instead.
          expect(
            tester.getRect(tile).right - tester.getRect(title).right,
            closeTo(supportsReadState ? 56 : 24, 0.01),
          );
        }

        final coveredTile = find.byKey(
          const ValueKey<String>('unified-shelf-list-tile-covered'),
        );
        final coveredTitle = find.descendant(
          of: coveredTile,
          matching: find.text(longTitle),
        );
        final titleWidth = tester.getSize(coveredTitle).width;
        await tester.longPress(coveredTile);
        await tester.pumpAndSettle();

        expect(tester.widget<ListTile>(coveredTile).selected, isTrue);
        expect(tester.getSize(coveredTitle).width, titleWidth);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'category pages keep stable PageStorage keys for scroll restoration',
    (tester) async {
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.grid,
            ),
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const PageStorageKey<String>('unified-shelf-category-page-default'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const PageStorageKey<String>('unified-shelf-grid-storage-default'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('optional task progress renders above shelf content', (
    tester,
  ) async {
    final progress = ValueNotifier<LibraryShelfTaskProgress?>(
      const LibraryShelfTaskProgress(
        code: LibraryShelfTaskProgressCode.favoriteSyncLoadingDetails,
        subject: '收藏帖',
        current: 3,
        total: 10,
      ),
    );
    await tester.pumpWidget(
      LocalizedTestApp(
        home: UnifiedShelfPage(
          adapter: _FakeShelfAdapter(
            initialDisplayMode: LibraryDisplayMode.list,
            taskProgress: progress,
          ),
          onOpenWork: (context, workId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-shelf-task-progress-bar')),
      findsOneWidget,
    );
    expect(find.text('正在读取《收藏帖》'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);

    progress.value = null;
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-shelf-task-progress-bar')),
      findsNothing,
    );
  });

  testWidgets(
    'failed parsing shows localized retry guidance and counts without an active progress bar',
    (tester) async {
      final l10n = AppLocalizationsZh();
      final progress = ValueNotifier<LibraryShelfTaskProgress?>(
        const LibraryShelfTaskProgress(
          code: LibraryShelfTaskProgressCode.favoriteParseNeedsAttention,
          active: false,
          needsAttention: true,
          foregroundQueued: 0,
          failedCount: 2,
        ),
      );
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeShelfAdapter(
              initialDisplayMode: LibraryDisplayMode.list,
              taskProgress: progress,
            ),
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryTaskFavoriteParseRetry), findsOneWidget);
      expect(
        find.text(l10n.libraryTaskFavoriteQueueSummary(0, 0, 2)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-shelf-task-progress-bar')),
        findsNothing,
      );
    },
  );
}
